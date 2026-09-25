#!/bin/sh
set -eu

rootfs=/var/lib/hatch-runtime/rootfs
gateway_ip=198.19.0.1
cell_ip=198.19.0.2
gateway_ipv6=fd8b:4f84:7d32:99::1
cell_ipv6=fd8b:4f84:7d32:99::2
address_cidr=198.19.0.2/30
address_ipv6_cidr=fd8b:4f84:7d32:99::2/64
proxy_host=hatch-egress-proxy
no_proxy_hosts="localhost,127.0.0.1,::1,[::1],$gateway_ip,$cell_ip,$gateway_ipv6,[$gateway_ipv6],$cell_ipv6,[$cell_ipv6]"
requested_mode="${1:-}"

# Two modes. No argument runs the full rootfs bootstrap. --repair-hosts-only is a
# lightweight per-start pass (invoked by pre-start.sh) that only guarantees
# /etc/hosts and /etc/resolv.conf are regular files (not the systemd-resolved
# stub symlink) with correct perms, so nspawn's BindReadOnly of the static
# /opt/hatch/runtime-cell/etc files always lands on a real target. It writes no
# hosts content (the static bind supplies it). The former --bootstrap-only alias
# is gone; spawnd is the only caller, so there is no compat flag surface.
repair_hosts_only=0
case "$requested_mode" in
    "")
        ;;
    --repair-hosts-only)
        repair_hosts_only=1
        ;;
    *)
        echo "usage: $0 [--repair-hosts-only]" >&2
        exit 2
        ;;
esac

set -a
if [ -f "/etc/hatch/env" ]; then
    . "/etc/hatch/env"
fi
if [ -f "/etc/hatch/env.override" ]; then
    . "/etc/hatch/env.override"
fi
set +a

# Guest `root` inside the cell is host uid/gid
# 131072 (systemd-nspawn PrivateUsers over a 64K
# window). Paths THIS script creates in the rootfs are chowned to it via
# guest_root_chown; the rest of the tree carries it from the image, asserted
# by assert_rootfs_ownership_is_baked below.
guest_root_uid="131072"
guest_root_gid="131072"
guest_root_owner="$guest_root_uid:$guest_root_gid"

# --- Symlink-safe rootfs traversal ---
# The rootfs is untrusted: a prior guest may have planted symlinks that,
# when followed by host root, redirect operations outside the rootfs tree.
# canonical_rootfs is derived from the resolved rootfs parent path before
# rootfs creation; all safe traversal functions require it.
canonical_rootfs=""

# Walk each component of a rootfs-relative path (e.g. "etc/hostname").
# If any component is a symlink, remove it. All safe_* wrappers pass
# relative paths and prepend canonical_rootfs internally.
ensure_not_symlink() {
    _ens_cur="$canonical_rootfs"
    _ens_rem="$1"
    while [ -n "$_ens_rem" ]; do
        _ens_comp="${_ens_rem%%/*}"
        if [ "$_ens_comp" = "$_ens_rem" ]; then
            _ens_rem=""
        else
            _ens_rem="${_ens_rem#*/}"
        fi
        [ -z "$_ens_comp" ] && continue
        _ens_next="$_ens_cur/$_ens_comp"
        if [ -L "$_ens_next" ]; then
            echo "runtime-cell bootstrap: SECURITY: removing symlink at $_ens_next -> $(readlink "$_ens_next")" >&2
            rm -f "$_ens_next"
        fi
        _ens_cur="$_ens_next"
    done
}

# --- Safe rootfs operation wrappers ---
# All paths are rootfs-relative (e.g. "etc/hostname").
#
# RT-11: the MUTATING wrappers (mkdir/write/append/touch/chmod/chown/install)
# delegate to `spawnd fsop`, which resolves the relative path beneath a held
# rootfs dirfd with openat2(RESOLVE_BENEATH|RESOLVE_NO_SYMLINKS) and acts on
# the returned descriptor. The old shape — ensure_not_symlink walking the
# path, then a second path-based chmod/chown/redirect — left the classic
# check/act gap: guest root owns every rootfs component and could re-plant a
# symlink between the walk and the act, turning these root operations into
# arbitrary host-path writes. ensure_not_symlink is retained as the REPAIR
# pass (it deletes planted links so the fd-safe op then succeeds on a fresh
# regular path) and as the guard for the residual name-ops (rm/rmdir/ln)
# fsop does not cover.

fsop() {
    /opt/hatch/bin/spawnd fsop "$@"
}

safe_mkdir() {
    _mode="$1"; shift
    for _p; do
        ensure_not_symlink "$_p"
        fsop mkdir --root "$canonical_rootfs" --path "$_p" --mode "$_mode"
    done
}

safe_write() {
    ensure_not_symlink "$1"
    fsop write --root "$canonical_rootfs" --path "$1" --mode 0644
}

safe_append() {
    _sap="$1"
    ensure_not_symlink "$_sap"
    # Append = snapshot-read + create-new-rename write. The read happens right
    # after the link repair; the WRITE is fully fd-anchored, so the worst a
    # rebuilt race can do is read (not write) through a re-planted link.
    { cat -- "$canonical_rootfs/$_sap" 2>/dev/null || true; cat; } |
        fsop write --root "$canonical_rootfs" --path "$_sap" --mode 0644
}

safe_touch() {
    for _p; do
        ensure_not_symlink "$_p"
        printf '' | fsop write --root "$canonical_rootfs" --path "$_p" --mode 0644
    done
}

safe_chmod() {
    _mode="$1"; shift
    for _p; do
        ensure_not_symlink "$_p"
        fsop chmod --root "$canonical_rootfs" --path "$_p" --mode "$_mode"
    done
}

safe_rm() {
    for _p; do
        ensure_not_symlink "$_p"
        rm -f "$canonical_rootfs/$_p"
    done
}

safe_rmdir() {
    for _p; do
        ensure_not_symlink "$_p"
        rm -rf "$canonical_rootfs/$_p"
    done
}

safe_ln() {
    _sln_parent="${2%/*}"
    if [ "$_sln_parent" != "$2" ] && [ -n "$_sln_parent" ]; then
        ensure_not_symlink "$_sln_parent"
    fi
    ln -sfn "$1" "$canonical_rootfs/$2"
}

safe_install() {
    _mode="$1"; _src="$2"; _dst="$3"
    ensure_not_symlink "$_dst"
    fsop install --root "$canonical_rootfs" --path "$_dst" --source "$_src" --mode "$_mode"
}

guest_root_chown() {
    if [ -n "$guest_root_owner" ]; then
        for _p; do
            ensure_not_symlink "$_p"
            fsop chown --root "$canonical_rootfs" --path "$_p" --owner "$guest_root_owner"
        done
    fi
}

# Guarantee /etc/hosts and /etc/resolv.conf are regular files (not the
# systemd-resolved stub symlink some rootfs-base snapshots ship) with 0644
# root-owned perms. nspawn's BindReadOnly of the static
# /opt/hatch/runtime-cell/etc files follows a symlink at the target and would
# land the bind on the symlink's /run/... target instead of /etc, so the guest
# would boot with no resolver. This writes no content — the static bind
# overmounts these files at start — and never truncates an existing regular
# file, so it is safe to run on every start via --repair-hosts-only.
ensure_resolver_files_are_regular() {
    for _rf in "etc/hosts" "etc/resolv.conf"; do
        ensure_not_symlink "$_rf"
        if [ -e "$canonical_rootfs/$_rf" ] && [ ! -f "$canonical_rootfs/$_rf" ]; then
            safe_rmdir "$_rf"
        fi
        if [ ! -f "$canonical_rootfs/$_rf" ]; then
            safe_touch "$_rf"
        fi
    done
    safe_chmod 0644 "etc/hosts" "etc/resolv.conf"
    guest_root_chown "etc/hosts" "etc/resolv.conf"
}

# Guest-side CA trust refresh. The host publishes the two hatch anchors into the
# read-only /run/hatch/cell-anchors bind and owns nothing else here: /etc/ssl/certs
# is the CELL's, so the guest's own update-ca-certificates keeps it current. That
# is what lets an in-cell apt ca-certificates upgrade succeed, and it keeps every
# host-side path operation out of this cell-owned tree.
#
# Installed from BOTH modes, because --repair-hosts-only is the only one that
# runs on a healthy rootfs: the full bootstrap fires only when rootfs_is_ready
# fails, so an existing VM would otherwise never receive these units and would
# boot with stock roots and no Sentinel MITM anchor. The writes are idempotent
# and cheap, so running them every start is the correct amount.
#
# The anchor set is fixed at exactly these two names, so no shell is needed: each
# step is a plain ExecStart. A retired anchor leaves a dangling link, which is
# harmless — update-ca-certificates enumerates the drop directory with
# `find -L ... -type f`, so a broken link is silently skipped, and its own orphan
# sweep then drops the retired CA from /etc/ssl/certs.
#
# The .path watches the anchors directory (a DIRECTORY bind, so the host's
# republish-by-rename is visible here) and re-runs on every rotation; Sentinel
# regenerates its egress CA per boot, and yolk rotates the ingress chain.
install_guest_ca_trust_units() {
    # default.target, NOT multi-user.target. This script writes the guest a
    # minimal `default.target` (see the bottom of this file) precisely so the
    # cell does not boot the distro graph, and multi-user.target is therefore
    # never reached: units wired to it load, show `enabled`, and silently never
    # run. Verified on the VM — multi-user.target is inactive in a healthy cell.
    #
    # Repair mode reaches here having created only etc/, so make the unit dirs.
    safe_mkdir 0755 "etc/systemd/system" "etc/systemd/system/default.target.wants"
    guest_root_chown "etc/systemd/system" "etc/systemd/system/default.target.wants"
    safe_write "etc/systemd/system/hatch-ca-trust.service" <<'CATRUSTSVC'
[Unit]
Description=Refresh guest CA trust from host-published hatch anchors
ConditionPathIsDirectory=/run/hatch/cell-anchors

[Service]
Type=oneshot
ExecStart=/usr/bin/mkdir -p /usr/local/share/ca-certificates
ExecStart=/usr/bin/ln -sfn /run/hatch/cell-anchors/hatch-egress-ca.pem /usr/local/share/ca-certificates/hatch-egress-ca.crt
ExecStart=/usr/bin/ln -sfn /run/hatch/cell-anchors/hatch-ingress-ca.pem /usr/local/share/ca-certificates/hatch-ingress-ca.crt
ExecStart=/usr/sbin/update-ca-certificates
TimeoutStartSec=120

[Install]
WantedBy=default.target
CATRUSTSVC
    guest_root_chown "etc/systemd/system/hatch-ca-trust.service"

    safe_write "etc/systemd/system/hatch-ca-trust.path" <<'CATRUSTPATH'
[Unit]
Description=Watch host-published hatch anchors for rotation

[Path]
PathChanged=/run/hatch/cell-anchors
Unit=hatch-ca-trust.service

[Install]
WantedBy=default.target
CATRUSTPATH
    guest_root_chown "etc/systemd/system/hatch-ca-trust.path"

    # Enable both without needing systemctl in the guest: the .wants dir is
    # already created above, and this is how the rootfs bootstrap enables units.
    #
    # BOTH, not just the .path: PathChanged= arms an inotify watch when the unit
    # starts and fires only on a change after that, so anchors already published
    # when the cell boots (any cell restart against a converged trust store)
    # would never trigger it. The .service link makes boot itself the first
    # trigger; the .path covers rotations from then on. The service is
    # idempotent, so running it both ways costs nothing.
    safe_ln ../hatch-ca-trust.service \
    "etc/systemd/system/default.target.wants/hatch-ca-trust.service"
    safe_ln ../hatch-ca-trust.path \
    "etc/systemd/system/default.target.wants/hatch-ca-trust.path"
}

# Reclaim stale scratch files without relying on a runtime-cell restart. The
# guest boots a deliberately minimal default.target, so its distro-provided
# timers.target.wants link is never reached; enable the stock tmpfiles timer
# directly here and shorten its daily cadence. The empty local tmp.conf uses
# the distro filename intentionally: it masks Ubuntu's 10d/30d policy so the
# runtime-cell policy can own the same paths without logging a conflict on every
# cleanup pass. One day keeps deliberately retained output and long-running
# build inputs available; the 15-minute sweep bounds how long eligible OOM
# residue waits for reclamation.
#
# Installed from BOTH modes for the same reason as the CA units above: repair
# mode is the only path guaranteed to run against an already-healthy rootfs.
install_guest_scratch_cleanup() {
    safe_mkdir 0755 \
        "etc/tmpfiles.d" \
        "etc/systemd/system" \
        "etc/systemd/system/default.target.wants" \
        "etc/systemd/system/systemd-tmpfiles-clean.timer.d" \
        "usr/lib/tmpfiles.d"
    guest_root_chown \
        "etc/tmpfiles.d" \
        "etc/systemd/system" \
        "etc/systemd/system/default.target.wants" \
        "etc/systemd/system/systemd-tmpfiles-clean.timer.d" \
        "usr/lib/tmpfiles.d"

    safe_write "usr/lib/tmpfiles.d/hatch-runtime-cell.conf" <<'TMPFILES'
d /run/hatch 0755 root root -
d /tmp 1777 root root 1d
d /var/tmp 1777 root root 1d
TMPFILES
    safe_write "etc/tmpfiles.d/tmp.conf" <<'TMPFILES'
# Scratch cleanup is owned by /usr/lib/tmpfiles.d/hatch-runtime-cell.conf.
TMPFILES
    safe_write "etc/systemd/system/systemd-tmpfiles-clean.timer.d/10-hatch-runtime-cell.conf" <<'UNIT'
[Timer]
OnUnitActiveSec=
OnUnitActiveSec=15min
UNIT
    safe_chmod 0644 \
        "usr/lib/tmpfiles.d/hatch-runtime-cell.conf" \
        "etc/tmpfiles.d/tmp.conf" \
        "etc/systemd/system/systemd-tmpfiles-clean.timer.d/10-hatch-runtime-cell.conf"
    guest_root_chown \
        "usr/lib/tmpfiles.d/hatch-runtime-cell.conf" \
        "etc/tmpfiles.d/tmp.conf" \
        "etc/systemd/system/systemd-tmpfiles-clean.timer.d/10-hatch-runtime-cell.conf"

    safe_ln /usr/lib/systemd/system/systemd-tmpfiles-clean.timer \
        "etc/systemd/system/default.target.wants/systemd-tmpfiles-clean.timer"
}

# Chrome enterprise policy for every Chromium launched inside the cell:
# argv-independent suppression of the startup phone-home (updater, metrics,
# GAIA check, telemetry hosts) that a raw exec launch would otherwise emit
# (T286974527; rationale in the landing commit). One directory per brand,
# each pinned by the live binary's policy loader: /etc/chromium
# (/opt/meta-chromium), /etc/opt/chrome_for_testing (Playwright/Puppeteer
# downloads), /etc/opt/chrome (installed Google Chrome). headless-shell
# reads none (verified); the Sentinel deny covers it. Installed from BOTH
# modes, same reason as the CA units above.
install_guest_chromium_policy() {
    safe_mkdir 0755 \
        "etc/chromium" \
        "etc/chromium/policies" \
        "etc/chromium/policies/managed" \
        "etc/opt" \
        "etc/opt/chrome" \
        "etc/opt/chrome/policies" \
        "etc/opt/chrome/policies/managed" \
        "etc/opt/chrome_for_testing" \
        "etc/opt/chrome_for_testing/policies" \
        "etc/opt/chrome_for_testing/policies/managed"
    guest_root_chown \
        "etc/chromium" \
        "etc/chromium/policies" \
        "etc/chromium/policies/managed" \
        "etc/opt" \
        "etc/opt/chrome" \
        "etc/opt/chrome/policies" \
        "etc/opt/chrome/policies/managed" \
        "etc/opt/chrome_for_testing" \
        "etc/opt/chrome_for_testing/policies" \
        "etc/opt/chrome_for_testing/policies/managed"

    for _policy_file in \
        "etc/chromium/policies/managed/policy.json" \
        "etc/opt/chrome/policies/managed/policy.json" \
        "etc/opt/chrome_for_testing/policies/managed/policy.json"; do
        safe_write "$_policy_file" <<'CHROMEPOLICY'
{
  "ComponentUpdatesEnabled": false,
  "MetricsReportingEnabled": false,
  "BrowserSignin": 0,
  "URLBlocklist": [
    "gvt1.com",
    "update.googleapis.com",
    "clients2.google.com",
    "optimizationguide-pa.googleapis.com",
    "content-autofill.googleapis.com",
    "android.clients.google.com"
  ]
}
CHROMEPOLICY
        safe_chmod 0644 "$_policy_file"
        guest_root_chown "$_policy_file"
    done
}

normalize_rootfs_relpath() {
    _norm_input="$1"
    _norm_output=""
    while :; do
        case "$_norm_input" in
            "")
                break
                ;;
            /*)
                _norm_input="${_norm_input#/}"
                continue
                ;;
            */*)
                _norm_comp="${_norm_input%%/*}"
                _norm_input="${_norm_input#*/}"
                ;;
            *)
                _norm_comp="$_norm_input"
                _norm_input=""
                ;;
        esac

        case "$_norm_comp" in
            ""|.)
                ;;
            ..)
                if [ -n "$_norm_output" ]; then
                    case "$_norm_output" in
                        */*)
                            _norm_output="${_norm_output%/*}"
                            ;;
                        *)
                            _norm_output=""
                            ;;
                    esac
                fi
                ;;
            *)
                if [ -n "$_norm_output" ]; then
                    _norm_output="$_norm_output/$_norm_comp"
                else
                    _norm_output="$_norm_comp"
                fi
                ;;
        esac
    done

    printf '%s\n' "$_norm_output"
}

# Resolve a guest path under rootfs semantics rather than host mount semantics:
# relative symlink targets are interpreted against the guest root, and absolute
# symlink targets stay inside the guest root instead of escaping to the host.
resolve_rootfs_existing_relpath() {
    _rootfs_rel_original="$1"
    _rootfs_expect_kind="$2"
    _rootfs_remaining="$(normalize_rootfs_relpath "$_rootfs_rel_original")"
    _rootfs_resolved=""
    _rootfs_symlink_hops=0

    while :; do
        if [ -z "$_rootfs_remaining" ]; then
            if [ -n "$_rootfs_resolved" ]; then
                _rootfs_candidate="$canonical_rootfs/$_rootfs_resolved"
            else
                _rootfs_candidate="$canonical_rootfs"
            fi

            if [ "$_rootfs_expect_kind" = dir ] && [ ! -d "$_rootfs_candidate" ]; then
                return 1
            fi
            if [ "$_rootfs_expect_kind" = path ] && [ ! -e "$_rootfs_candidate" ] && [ ! -L "$_rootfs_candidate" ]; then
                return 1
            fi

            printf '%s\n' "$_rootfs_candidate"
            return 0
        fi

        case "$_rootfs_remaining" in
            */*)
                _rootfs_comp="${_rootfs_remaining%%/*}"
                _rootfs_tail="${_rootfs_remaining#*/}"
                ;;
            *)
                _rootfs_comp="$_rootfs_remaining"
                _rootfs_tail=""
                ;;
        esac

        [ -n "$_rootfs_resolved" ] && _rootfs_candidate="$canonical_rootfs/$_rootfs_resolved/$_rootfs_comp" || _rootfs_candidate="$canonical_rootfs/$_rootfs_comp"
        if [ -L "$_rootfs_candidate" ]; then
            _rootfs_symlink_hops=$((_rootfs_symlink_hops + 1))
            if [ "$_rootfs_symlink_hops" -gt 40 ]; then
                return 1
            fi

            _rootfs_link_target="$(readlink "$_rootfs_candidate")"
            case "$_rootfs_link_target" in
                /*)
                    _rootfs_replacement="$(normalize_rootfs_relpath "$_rootfs_link_target")"
                    ;;
                *)
                    if [ -n "$_rootfs_resolved" ]; then
                        _rootfs_replacement="$(normalize_rootfs_relpath "$_rootfs_resolved/$_rootfs_link_target")"
                    else
                        _rootfs_replacement="$(normalize_rootfs_relpath "$_rootfs_link_target")"
                    fi
                    ;;
            esac

            if [ -n "$_rootfs_tail" ]; then
                if [ -n "$_rootfs_replacement" ]; then
                    _rootfs_remaining="$_rootfs_replacement/$_rootfs_tail"
                else
                    _rootfs_remaining="$_rootfs_tail"
                fi
            else
                _rootfs_remaining="$_rootfs_replacement"
            fi
            _rootfs_resolved=""
            continue
        fi

        if [ -n "$_rootfs_tail" ]; then
            [ -d "$_rootfs_candidate" ] || return 1
            if [ -n "$_rootfs_resolved" ]; then
                _rootfs_resolved="$_rootfs_resolved/$_rootfs_comp"
            else
                _rootfs_resolved="$_rootfs_comp"
            fi
            _rootfs_remaining="$_rootfs_tail"
            continue
        fi

        if [ "$_rootfs_expect_kind" = dir ]; then
            [ -d "$_rootfs_candidate" ] || return 1
        else
            [ -e "$_rootfs_candidate" ] || return 1
        fi

        printf '%s\n' "$_rootfs_candidate"
        return 0
    done
}

rootfs_path_is_executable() {
    _rootfs_exec_path="$(resolve_rootfs_existing_relpath "$1" path || true)"
    [ -n "$_rootfs_exec_path" ] && [ -x "$_rootfs_exec_path" ]
}

# Cheap invariant check, NOT a repair. On-disk ownership is load-bearing:
# nspawn runs the cell with --private-users-ownership=map, an idmapped mount
# that translates ids for the running container but never repairs what is on
# disk, so a tree owned outside the PrivateUsers window boots a cell whose
# root cannot read its own /etc.
#
# Getting the tree into that window is a BUILD-TIME property of the image now.
# hatch-image's mkosi.finalize runs scripts/heal-rootfs-ownership.sh against
# /var/lib/hatch-runtime/rootfs-base and only then computes
# /opt/hatch-image/cell-base.digest, and every serving rootfs is derived from
# that base by a path that preserves ownership exactly: `btrfs subvolume
# snapshot` inherits it, and on the overlayfs arm the rootfs IS the base.
# Steady-state guest writes are in-window by construction, because the cell
# only ever writes through the idmapped mount.
#
# The tree-walking heal that used to live here therefore re-derived, on the
# blocking cell-start path, a property the artifact already carries: `find
# -printf` passes over a whole rootfs, costing real seconds on a cold start
# for zero change.
#
# What replaced it is a CHECK rather than nothing, because the digest gate
# above does not cover this. compute-cell-base-digest.py deliberately excludes
# uid/gid -- "consumers must derive ownership and must not expect the digest to
# pin per-file security state" -- so a digest match proves the base's content
# provenance, not that the heal ran. The rootfs root is the cheap sentinel for
# that: the build heal shifts the whole tree in one pass, so a root carrying
# the window means the pass ran. One stat, no walk. A base that arrives
# unhealed fails loudly here instead of failing incomprehensibly deep inside
# the booted cell.
#
# Both failure arms exit 78, which the unit's RestartPreventExitStatus=78
# honours. Plain `set -e` on a failing stat would surface as exit 1 instead,
# and exit 1 under Restart=always/RestartSec=1 is a once-per-second restart
# loop -- so the unstattable case is handled explicitly rather than left to
# errexit. Neither arm is fixable by retrying.
#
# `stat -L`, NOT bare `stat`: GNU stat lstats by default. On the overlayfs arm
# $rootfs is a SYMLINK to rootfs-base, created here by `ln -sfn` running as
# root, so a bare stat reads the link's own 0:0 and fails every first boot on
# a read-only-root image -- the production path on real-RV hosts. The link's
# ownership is meaningless; the tree it points at is what the guest reads.
assert_rootfs_ownership_is_baked() {
    if ! _rootfs_owner="$(stat -L -c '%u:%g' "$rootfs" 2>/dev/null)"; then
        echo "runtime-cell bootstrap: FATAL: cannot stat the rootfs at $rootfs after materialization (missing, or a dangling symlink to a removed base); refusing to start the cell" >&2
        exit 78
    fi
    if [ "$_rootfs_owner" = "$guest_root_owner" ]; then
        return 0
    fi
    echo "runtime-cell bootstrap: FATAL: rootfs at $rootfs is owned $_rootfs_owner, not the guest-root owner $guest_root_owner baked into rootfs-base by hatch-image; refusing to boot a cell whose root cannot read its own /etc" >&2
    exit 78
}

remove_retired_browser_aliases() {
    safe_rm \
        "usr/local/bin/google-chrome" \
        "usr/local/bin/google-chrome-stable"
}

rootfs=$("/opt/hatch/runtime-cell/resolve-rootfs-path.sh" "$rootfs")
echo "runtime-cell bootstrap: using rootfs at $rootfs" >&2
rootfs_parent="$(dirname "$rootfs")"
mkdir -p "$rootfs_parent"

# T286632428: the rootfs trees under this parent are guest-owned (the cell's
# host uid window) and carry setuid files — rootfs-base ships the stock dpkg
# setuid set as uid-131072-owned binaries, and cell root can mint more in
# its writable snapshot. Executing one as ANY traversing host uid yields
# euid 131072: the universal cell->host-uid bridge. Root-only traversal on
# the parent kills the host-side exec lane while leaving the CELL's view
# untouched (in-cell resolution starts at the container root, so in-cell
# setuid helpers like sudo keep working — a deliberate requirement; a
# nosuid mount here would propagate into the container root and break
# them). chown/chmod act on the inode, so this holds from any mount
# namespace and re-asserts on every start; the path chain (/var, /var/lib,
# the parent itself) is root-owned, so this is not a symlink-followable
# write. The image bakes the same mode; this covers already-shipped images
# and drift.
chown root:root "$rootfs_parent"
chmod 0700 "$rootfs_parent"

canonical_rootfs="$(realpath "$rootfs_parent")/$(basename "$rootfs")"
rootfs="$canonical_rootfs"

if [ "$repair_hosts_only" -eq 1 ]; then
    if [ ! -d "$rootfs" ]; then
        echo "runtime-cell bootstrap: cannot repair resolver files; rootfs missing at $rootfs" >&2
        exit 78
    fi
    safe_mkdir 0755 "etc"
    guest_root_chown "etc"
    ensure_resolver_files_are_regular
    install_guest_ca_trust_units
    install_guest_scratch_cleanup
    install_guest_chromium_policy
    exit 0
fi

# arch/release detection lives BELOW the --repair-hosts-only branch: that
# mode runs on every cell start (pre-start.sh) and needs neither, so the
# dpkg/os-release forks (~20-40ms) stay off the per-start path.
arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
default_release=""
if [ -r /etc/os-release ]; then
    default_release="$(sed -n 's/^VERSION_CODENAME=//p' /etc/os-release | head -n1 | tr -d '\"')"
    if [ -z "$default_release" ]; then
        default_release="$(sed -n 's/^UBUNTU_CODENAME=//p' /etc/os-release | head -n1 | tr -d '\"')"
    fi
fi
release="$default_release"
if [ -z "$release" ]; then
    release=noble
fi

# Rootfs-relative versions of template-rendered absolute guest paths.
# safe_* wrappers take relative paths; these strip the leading /.
rel_jarvis_home=$(echo "/home/hatch" | sed 's|^/||')
rel_jarvis_home_parent=$(dirname "$rel_jarvis_home")
rel_env_file=$(echo "/etc/hatch/env" | sed 's|^/||')
rel_env_override_file=$(echo "/etc/hatch/env.override" | sed 's|^/||')

# --- Image-local, digest-keyed base ---
# The cell boots from a LOCAL btrfs snapshot of the image base every boot:
# /var/lib/hatch-runtime/rootfs is a snapshot of
# /var/lib/hatch-runtime/rootfs-base, keyed by the image's
# /opt/hatch-image/cell-base.digest. When the image base digest changes (a new
# image), the local snapshot is discarded and re-cloned so no persistent upper
# ever crosses image versions; per-VM OS packages replay from the
# /var/lib/hatch/os-intent ledger via com.hatch.preflight-opportunistic
# instead. The retired serving-tree-on-RV rootfs is kept on disk untouched
# for rollback/forensics only. `spawnd install` fail-closed asserts the image
# contract, so a missing digest file here is an invariant violation, not a
# supported old-image mode: fail loudly with the no-restart exit (78) rather
# than booting a cell from an unverifiable base.
image_digest_file="/opt/hatch-image/cell-base.digest"
rootfs_digest_stamp="$rootfs_parent/rootfs.cell-base.digest"
base_subvol="$rootfs_parent/rootfs-base"

if [ ! -f "$image_digest_file" ]; then
    echo "runtime-cell bootstrap: FATAL: cell-base digest missing at $image_digest_file — this image predates the resume-architecture v1 contract that spawnd install asserts; refusing to boot the cell from an unverifiable base" >&2
    exit 78
fi
image_digest="$(tr -d '[:space:]' < "$image_digest_file")"
if [ -z "$image_digest" ]; then
    echo "runtime-cell bootstrap: FATAL: cell-base digest at $image_digest_file is empty; refusing to boot the cell from an unverifiable base" >&2
    exit 78
fi

if [ -d "$rootfs" ]; then
    recorded_digest=""
    if [ -f "$rootfs_digest_stamp" ]; then
        recorded_digest="$(tr -d '[:space:]' < "$rootfs_digest_stamp" 2>/dev/null || true)"
    fi
    if [ "$recorded_digest" != "$image_digest" ]; then
        echo "runtime-cell bootstrap: image cell-base digest changed (${recorded_digest:-<unstamped>} -> $image_digest); discarding local rootfs snapshot for re-clone (per-VM packages replay from the os-intent ledger)" >&2
        btrfs subvolume delete "$rootfs" 2>/dev/null || rm -rf -- "$rootfs"
        rm -f "$rootfs_digest_stamp"
    fi
fi

if ! rootfs_path_is_executable "bin/sh"; then
    if [ ! -x "$base_subvol/bin/sh" ]; then
        echo "runtime-cell bootstrap: rootfs-base missing at $base_subvol (expected from hatch-image)" >&2
        exit 78
    fi
    if [ -d "$rootfs" ]; then
        btrfs subvolume delete "$rootfs" 2>/dev/null || rm -rf -- "$rootfs"
    fi
    # A snapshot needs a writable btrfs at the DESTINATION. A no-RV/loopback VM on a
    # read-only overlay root has none, so point rootfs at the base and let the /
    # overlay be the CoW layer -- a pristine read-only lower plus a writable upper
    # is exactly what the base->rootfs snapshot provides.
    #
    # Keyed on the capability that decides the outcome -- the filesystem type
    # of the MOUNT holding the destination parent (%T: "btrfs", "overlayfs",
    # ...), which is what determines whether a subvolume snapshot is even
    # possible here. Three topologies:
    #   * btrfs: an image generation with a real writable btrfs at this path.
    #     Snapshot: rootfs-base is PERSISTENT there and must not be mutated
    #     by cell writes.
    #   * overlayfs: the overlay-root image generations (read-only root +
    #     per-VM encrypted writable upper) serve this path through the /
    #     overlay on EVERY host class -- real-RV production included -- and
    #     reject btrfs ioctls through it. The symlink is the correct
    #     production path there: the overlay upper (per-VM, encrypted) is the
    #     CoW layer, so cell writes never reach the image lower and never
    #     mutate rootfs-base. An earlier revision gated this arm on a
    #     loopback /hatch, which restart-looped every real-RV boot on these
    #     images; the loopback probe is diagnostics now, never a gate here.
    #   * anything else is unanticipated: accept it only with the loopback-RV
    #     corroboration (dev shapes), otherwise fail loudly here rather than
    #     deep inside the booted cell.
    rootfs_parent_fstype="$(stat -f -c %T "$rootfs_parent")"
    if [ "$rootfs_parent_fstype" != btrfs ]; then
        if [ "$rootfs_parent_fstype" = overlayfs ]; then
            # Diagnostics only (prints the backing device it saw on stderr);
            # the overlay verdict above already decides the strategy.
            "/opt/hatch/runtime-cell/is-loopback-rv.sh" || true
            echo "runtime-cell bootstrap: $rootfs_parent is overlayfs (read-only-root image; per-VM overlay upper is the CoW layer); linking rootfs -> rootfs-base" >&2
        else
            # Only the zero/non-zero answer is ours to interpret.
            # is-loopback-rv.sh prints WHY on stderr immediately above this
            # line, including the device it saw, so re-deriving an explanation
            # from its exit code here would just be a second copy of its
            # reasoning -- and that copy drifts: it once blamed code 3 on a
            # symlinked /hatch, the one thing that cannot produce it.
            #
            # "did not confirm" rather than "is not a loopback RV" on purpose:
            # a non-zero status also covers the probe never running at all
            # (127 if it is missing, 126 if not executable -- live risks,
            # since it ships into /opt/hatch separately from this image).
            # Claiming a finding there would be asserting something we did
            # not establish.
            if ! "/opt/hatch/runtime-cell/is-loopback-rv.sh"; then
                echo "runtime-cell bootstrap: $rootfs_parent is neither btrfs nor overlayfs ($rootfs_parent_fstype) and is-loopback-rv.sh did not confirm a loopback RV (reason above); refusing to link rootfs -> rootfs-base" >&2
                exit 1
            fi
            echo "runtime-cell bootstrap: $rootfs_parent is $rootfs_parent_fstype and /hatch is a loopback RV; linking rootfs -> rootfs-base (overlay provides CoW)" >&2
        fi
        ln -sfn "$(basename "$base_subvol")" "$rootfs"
        # The LINK NODE's own ownership is a separate contract from the tree's,
        # and this is the one node hatch-image cannot bake -- the link does not
        # exist until this line runs. `ln` mints it 0:0 (we are root), but
        # spawnd's cutover verifier
        # (ops::verify_runtime_cell_rootfs_path_owner) lstats exactly this path
        # and requires guest-root ownership, so leaving it 0:0 boots a perfectly
        # healthy cell and then aborts the NEXT asset-changing install -- before
        # WriteInstallState, so every retry fails identically until someone
        # chowns it by hand. The btrfs arm needs no equivalent: a subvolume
        # snapshot inherits the base's ownership.
        #
        # --no-dereference so this lands on the link, not on rootfs-base (which
        # is image-owned and already correct). This is what the retired heal's
        # force_critical_guest_root_paths did incidentally.
        chown --no-dereference "$guest_root_owner" "$rootfs"
        # Superseded-generation GC (forward-compat with the digest-keyed
        # base layout): when the image ships rootfs-base as a symlink to
        # rootfs-base-<digest>, cell writes shadow the resolved digest path
        # in the persistent overlay upper, and each image roll strands the
        # previous generation's shadows as unreachable dead weight there
        # (stale dpkg/apt state was exactly the S698078 phantom-reinstall
        # trigger). Remove every sibling generation except the one the
        # current base resolves to: through the overlay this whiteouts and
        # frees stale UPPER data only — the live lower ships nothing but
        # the current generation. Plain-layout images have no siblings, so
        # this is a no-op there. Best-effort: GC failure costs disk space,
        # never the cell start.
        current_base_real="$(readlink -f "$base_subvol" 2>/dev/null || echo "$base_subvol")"
        for gen in "$rootfs_parent"/rootfs-base-*; do
            [ -e "$gen" ] || continue
            gen_real="$(readlink -f "$gen" 2>/dev/null || echo "$gen")"
            [ "$gen_real" = "$current_base_real" ] && continue
            echo "runtime-cell bootstrap: removing superseded cell-base generation $(basename "$gen") (shadow GC)" >&2
            rm -rf -- "$gen" 2>/dev/null || true
        done
    else
        btrfs subvolume snapshot "$base_subvol" "$rootfs"
        # $base_subvol may now be READ-ONLY (it is, when seeded by btrfs receive).
        # A snapshot of a read-only subvolume is read-WRITE by default, and the cell
        # requires that -- but say so explicitly rather than resting on the default,
        # because the source's ro flag is load-bearing now and a silently read-only
        # rootfs would fail deep inside the booted cell instead of here.
        btrfs property set "$rootfs" ro false
        # Migration completeness for non-apt rootfs installs: carry /usr/local
        # over from the retired serving-tree rootfs (frozen on the RV at
        # cutover). apt state replays from the os-intent ledger, but pip
        # --break-system-packages and curl|bash-style binary installs live only
        # under /usr/local and would otherwise vanish from the cell. No-clobber:
        # the image base always wins on conflicts, so a stale copy can never
        # shadow image-provided binaries. Runs at every fresh materialization
        # (cutover AND image-upgrade re-clones), so cutover-era tools persist at
        # their frozen versions; /usr/local additions made AFTER the cutover are
        # snapshot-ephemeral by design (OS packages belong to apt + the ledger;
        # everything else belongs in the home). Best-effort by contract: a copy
        # failure must never cost the cell start.
        retired_rootfs="/hatch/runtime-cell/rootfs"
        # The retired tree is guest-written: host root must never resolve a
        # guest-planted symlink at usr or usr/local (the source path components
        # above the copy), or this seed would pull an attacker-chosen HOST tree
        # into the new cell. Contents below are copied with -a (no dereference),
        # so these two components are the whole resolution surface; refuse
        # loudly and skip the seed on tampering.
        if [ -L "$retired_rootfs/usr" ] || [ -L "$retired_rootfs/usr/local" ]; then
            echo "runtime-cell bootstrap: REFUSING /usr/local seed: retired rootfs plants a symlink at usr or usr/local" >&2
        elif [ -d "$retired_rootfs/usr/local" ]; then
            # RT-11: the retired tree is GUEST-AUTHORED. --no-preserve strips
            # its modes/ownership at copy (a guest-minted setuid-root binary or
            # guest-chosen owner must not survive the import), specials are
            # deleted outright (device nodes/FIFOs/sockets have no place in a
            # /usr/local seed), and the fd-anchored chmod-tree normalizes the
            # imported tree to 0755/0644(+preserved execute) — stripping any
            # setuid/setgid that slipped through — before the cell ever runs.
            if cp -Rn --no-dereference --no-preserve=mode,ownership -- "$retired_rootfs/usr/local/." "$rootfs/usr/local/" 2>/dev/null; then
                find "$rootfs/usr/local" \( -type b -o -type c -o -type p -o -type s \) -delete 2>/dev/null || true
                if ! fsop chmod-tree --root "$rootfs/usr/local" --dir-mode 0755 --file-mode 0644 --keep-execute; then
                    echo "runtime-cell bootstrap: /usr/local seed mode normalization failed; discarding the seed rather than booting it" >&2
                    rm -rf -- "$rootfs/usr/local" 2>/dev/null || true
                    mkdir -p -- "$rootfs/usr/local"
                fi
                echo "runtime-cell bootstrap: seeded /usr/local from the retired serving rootfs (size not measured: a du walk of a pip-heavy tree costs seconds on the blocking start path)"
            else
                echo "runtime-cell bootstrap: /usr/local seed from the retired rootfs incomplete (best-effort; continuing)" >&2
            fi
        fi
    fi
fi
# Stamp the snapshot with the base digest it was cloned from so the refresh
# check above stays cheap and exact on every later boot.
printf '%s\n' "$image_digest" > "$rootfs_digest_stamp"
chmod 0644 "$rootfs_digest_stamp"

assert_rootfs_ownership_is_baked

safe_mkdir 0755 "etc/apt" "etc/apt/sources.list.d"
case "$arch" in
    amd64|i386)
        safe_write "etc/apt/sources.list.d/ubuntu.sources" <<EOF
Types: deb
URIs: http://azure.archive.ubuntu.com/ubuntu http://mirror.cogentco.com/pub/linux/ubuntu
Suites: $release $release-updates $release-backports $release-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
        ;;
    *)
        safe_write "etc/apt/sources.list.d/ubuntu.sources" <<EOF
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports
Suites: $release $release-updates $release-backports $release-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
        ;;
esac
safe_touch "etc/apt/sources.list"

safe_mkdir 0755 \
    "etc" \
    "etc/hatch" \
    "etc/hatch/credentials" \
    "etc/environment.d" \
    "etc/profile.d" \
    "etc/apt/apt.conf.d" \
    "etc/systemd/nspawn" \
    "etc/ssh" \
    "etc/credstore" \
    "etc/credstore.encrypted" \
    "etc/systemd/system" \
    "etc/systemd/system/multi-user.target.wants" \
    "etc/systemd/system/sockets.target.wants" \
    "$rel_jarvis_home_parent" \
    "$rel_jarvis_home" \
    "$rel_jarvis_home/update" \
    "opt/hatch/bin" \
    "opt/hatch-image/bin" \
    "opt/hatch-image/models" \
    "usr/lib/tmpfiles.d" \
    "var" \
    "var/tmp" \
    "usr/local/bin" \
    "usr/sbin"
safe_chmod 1777 "var/tmp"
guest_root_chown \
    "etc/hatch" \
    "etc/hatch/credentials" \
    "etc/environment.d" \
    "etc/profile.d" \
    "etc/apt/apt.conf.d" \
    "etc/systemd/nspawn" \
    "etc/ssh" \
    "etc/credstore" \
    "etc/credstore.encrypted" \
    "$rel_jarvis_home/update" \
    "opt/hatch/bin" \
    "opt/hatch-image/bin" \
    "opt/hatch-image/models" \
    "var/tmp"

remove_retired_browser_aliases

safe_touch \
    "etc/hostname" \
    "etc/machine-id" \
    "etc/fstab" \
    "opt/hatch/bin/spawnd"
guest_root_chown \
    "etc/hostname" \
    "etc/machine-id" \
    "etc/fstab" \
    "opt/hatch/bin/spawnd"

# Guarantee /etc/hosts and /etc/resolv.conf are regular files with correct perms
# so nspawn's BindReadOnly static-file targets are valid (shared with the
# per-start --repair-hosts-only pass).
ensure_resolver_files_are_regular

safe_write "usr/sbin/policy-rc.d" <<'POLICY'
#!/bin/sh
exit 101
POLICY
safe_chmod 0755 "usr/sbin/policy-rc.d"

if [ -f "/etc/hatch/env" ]; then
    safe_install 0644 "/etc/hatch/env" "$rel_env_file"
else
    safe_touch "$rel_env_file"
fi
if [ -f "/etc/hatch/env.override" ]; then
    # The override copy that enters the CELL is 0644 and cell-readable, so it
    # is scrubbed by the SAME Rust predicate the base env file gets
    # spawnd-side (runtime_env_key_forbidden), through `spawnd
    # scrub-env-override` (environment/cell_copy_scrub.rs) — the awk that
    # previously lived here judged one PHYSICAL line at a time and shipped
    # every body line of a multiline value (a quoted PEM private key, a
    # backslash continuation) into the cell verbatim; the Rust scrub groups
    # sh logical lines and drops the whole value. The HOST file is untouched:
    # operators may park secret-shaped emergency keys there (0600,
    # host-only); they must never ship verbatim into an attacker-readable
    # rootfs on the next cell start. A scrubbed assignment is replaced by a
    # comment naming only the key so in-cell debugging sees the removal.
    # Command substitution rather than a pipe into the write: this script is
    # `set -eu` with no pipefail, so a piped scrub failure would be swallowed
    # by the succeeding write and install an EMPTY override — silently
    # dropping the operator's emergency settings — where the old awk form
    # aborted the bootstrap. The content stays in memory (no world-readable
    # temp file) and the write still goes through fsop's rooted openat2.
    scrubbed_override=$(/opt/hatch/bin/spawnd scrub-env-override --source "/etc/hatch/env.override")
    printf '%s\n' "$scrubbed_override" | safe_write "$rel_env_override_file"
else
    # Empty placeholder, same idiom as the env-file branch above: fsop
    # install refuses non-regular sources (/dev/null is a chardev), and this
    # absent-override state is the SUPPORTED first-boot/rebuild path, so it
    # must keep producing an empty 0644 file rather than aborting the cell
    # bootstrap under set -e.
    safe_touch "$rel_env_override_file"
fi

nspawn_run_counter=0
nspawn_supports_private_users_ownership_map=0
if systemd-nspawn --help 2>&1 | grep -q -- '--private-users-ownership'; then
    nspawn_supports_private_users_ownership_map=1
else
    echo "systemd-nspawn lacks --private-users-ownership support; runtime-cell bootstrap ownership would be broken" >&2
    exit 1
fi

nspawn_run() {
    attempt=0
    while :; do
        nspawn_run_counter=$((nspawn_run_counter + 1))
        machine="hatch-rootfs-bootstrap-$$-$nspawn_run_counter"
        set +e
        output="$(
            systemd-nspawn \
                --quiet \
                --register=no \
                --machine="$machine" \
                --directory="$rootfs" \
                --private-users="131072" \
                "$@" 2>&1
        )"
        status=$?
        set -e
        if [ "$status" -eq 0 ]; then
            if [ -n "$output" ]; then
                printf '%s\n' "$output"
            fi
            return 0
        fi
        case "$output" in
            *"Directory tree $rootfs is currently busy."*)
                attempt=$((attempt + 1))
                if [ "$attempt" -ge 30 ]; then
                    printf '%s\n' "$output" >&2
                    return "$status"
                fi
                sleep 1
                ;;
            *)
                printf '%s\n' "$output" >&2
                return "$status"
                ;;
        esac
    done
}

preseed_rootfs_timezone() {
    safe_mkdir 0755 "etc"
    safe_write "etc/timezone" <<TZEOF
Etc/UTC
TZEOF
    safe_ln /usr/share/zoneinfo/Etc/UTC "etc/localtime"
}

# Remove stale proxy config that points at the runtime-cell gateway. Bootstrap
# and installer-time nspawn runs use host networking before the runtime-cell
# veth exists, so they must not inherit the guest's steady-state gateway proxy.
# The steady-state configs are written back unconditionally after package
# reconciliation below.
safe_rm \
    "etc/apt/apt.conf.d/80hatch-egress-proxy" \
    "etc/environment" \
    "etc/environment.d/80-hatch-egress.conf" \
    "etc/profile.d/hatch-egress.sh"

preseed_rootfs_timezone

# Package reconciliation (hatch-manifest maybe-apply) is NOT done here anymore.
# It was lifted out of this blocking pre-start path into
# com.hatch.preflight-opportunistic.service, which runs post-boot INSIDE the live
# cell (through the cell's steady-state Sentinel egress), so a manifest change no
# longer blocks the cell or the daemon from starting.
#
# Write the guest's steady-state proxy config (Sentinel egress) below.
safe_write "etc/environment" <<EOF
HTTP_PROXY=http://$proxy_host:3128
HTTPS_PROXY=http://$proxy_host:3128
ALL_PROXY=http://$proxy_host:3128
NO_PROXY=$no_proxy_hosts
http_proxy=http://$proxy_host:3128
https_proxy=http://$proxy_host:3128
all_proxy=http://$proxy_host:3128
no_proxy=$no_proxy_hosts
SSL_CERT_FILE=/run/hatch/egress-tls/ca-bundle.pem
REQUESTS_CA_BUNDLE=/run/hatch/egress-tls/ca-bundle.pem
CURL_CA_BUNDLE=/run/hatch/egress-tls/ca-bundle.pem
AWS_CA_BUNDLE=/run/hatch/egress-tls/ca-bundle.pem
NODE_EXTRA_CA_CERTS=/run/hatch/egress-tls/ca-bundle.pem
NODE_USE_ENV_PROXY=1
GIT_SSL_CAINFO=/run/hatch/egress-tls/ca-bundle.pem
EOF
guest_root_chown "etc/environment"

safe_write "etc/environment.d/80-hatch-egress.conf" <<EOF
HTTP_PROXY=http://$proxy_host:3128
HTTPS_PROXY=http://$proxy_host:3128
ALL_PROXY=http://$proxy_host:3128
NO_PROXY=$no_proxy_hosts
http_proxy=http://$proxy_host:3128
https_proxy=http://$proxy_host:3128
all_proxy=http://$proxy_host:3128
no_proxy=$no_proxy_hosts
SSL_CERT_FILE=/run/hatch/egress-tls/ca-bundle.pem
REQUESTS_CA_BUNDLE=/run/hatch/egress-tls/ca-bundle.pem
CURL_CA_BUNDLE=/run/hatch/egress-tls/ca-bundle.pem
AWS_CA_BUNDLE=/run/hatch/egress-tls/ca-bundle.pem
NODE_EXTRA_CA_CERTS=/run/hatch/egress-tls/ca-bundle.pem
NODE_USE_ENV_PROXY=1
GIT_SSL_CAINFO=/run/hatch/egress-tls/ca-bundle.pem
EOF
guest_root_chown "etc/environment.d/80-hatch-egress.conf"

safe_write "etc/profile.d/hatch-egress.sh" <<EOF
export HTTP_PROXY=http://$proxy_host:3128
export HTTPS_PROXY=http://$proxy_host:3128
export ALL_PROXY=http://$proxy_host:3128
export NO_PROXY=$no_proxy_hosts
export http_proxy=\$HTTP_PROXY
export https_proxy=\$HTTPS_PROXY
export all_proxy=\$ALL_PROXY
export no_proxy=\$NO_PROXY
export SSL_CERT_FILE=/run/hatch/egress-tls/ca-bundle.pem
export REQUESTS_CA_BUNDLE=/run/hatch/egress-tls/ca-bundle.pem
export CURL_CA_BUNDLE=/run/hatch/egress-tls/ca-bundle.pem
export AWS_CA_BUNDLE=/run/hatch/egress-tls/ca-bundle.pem
export NODE_EXTRA_CA_CERTS=/run/hatch/egress-tls/ca-bundle.pem
export NODE_USE_ENV_PROXY=1
export GIT_SSL_CAINFO=/run/hatch/egress-tls/ca-bundle.pem
EOF
guest_root_chown "etc/profile.d/hatch-egress.sh"

safe_write "etc/apt/apt.conf.d/80hatch-egress-proxy" <<EOF
Acquire::http::Proxy "http://$proxy_host:3128";
Acquire::https::Proxy "http://$proxy_host:3128";
EOF
guest_root_chown "etc/apt/apt.conf.d/80hatch-egress-proxy"

install_guest_ca_trust_units

safe_mkdir 0755 "etc/systemd/system/apt-daily-upgrade.timer.d"
safe_write "etc/systemd/system/apt-daily-upgrade.timer.d/99hatch-spread.conf" <<'EOF'
[Timer]
RandomizedDelaySec=24h
EOF
guest_root_chown "etc/systemd/system/apt-daily-upgrade.timer.d"
guest_root_chown "etc/systemd/system/apt-daily-upgrade.timer.d/99hatch-spread.conf"

# Disable host-only units in the guest rootfs. The guest inherits the
# host's /etc/systemd/system/ via btrfs snapshot. Host-only socket units
# that bind to paths shared via Bind= (e.g. /run/hatch/auth/,
# /run/hatch/privsep/) will conflict: the guest's systemd starts them,
# they fail, and RemoveOnStop=true deletes the host's socket files through
# the bind mount. Removing .wants/ symlinks prevents auto-start without
# deleting the unit files.
find "$rootfs/etc/systemd/system/sockets.target.wants" -name 'com.hatch.*' -delete 2>/dev/null || true
find "$rootfs/etc/systemd/system/multi-user.target.wants" -name 'com.hatch.*' -delete 2>/dev/null || true
safe_rmdir \
    "etc/systemd/system/hatch-rv.target.wants" \
    "etc/systemd/system/home-hatch.mount.wants"

safe_rm "etc/systemd/system/multi-user.target.wants/nginx.service"
# Clean up the retired guest-owned daemon unit. The host-side
# com.hatch.daemon.service controller is now the sole daemon owner.
safe_rm \
    "etc/systemd/system/hatch-daemon.service" \
    "etc/systemd/system/multi-user.target.wants/hatch-daemon.service"

# Clean up stale guest-side WAI units from prior installs.
safe_rm \
    "etc/systemd/system/hatch-wai.service" \
    "etc/systemd/system/multi-user.target.wants/hatch-wai.service" \
    "etc/systemd/system/hatch-wai-privsep.socket" \
    "etc/systemd/system/sockets.target.wants/hatch-wai-privsep.socket" \
    "etc/systemd/system/hatch-wai-privsep@.service"

# Clean up any stale host-side execd unit references inside the guest. Both
# socket units now bind under the host-only /run/hatch/exec, which the guest
# does not share, so a guest-started copy would bind a cell-local decoy rather
# than clobbering the host socket through a bind mount — but it would still be
# a listener at the execd path inside the cell, which is precisely what moving
# the sockets out of /run/hatch/daemon exists to prevent.
safe_rm \
    "etc/systemd/system/com.hatch.execd.service" \
    "etc/systemd/system/multi-user.target.wants/com.hatch.execd.service" \
    "etc/systemd/system/com.hatch.execd.socket" \
    "etc/systemd/system/sockets.target.wants/com.hatch.execd.socket" \
    "etc/systemd/system/com.hatch.execd-taint.socket" \
    "etc/systemd/system/sockets.target.wants/com.hatch.execd-taint.socket"

# Remove stale WAI data directories from inside the sandbox. WAI now runs
# on the host with its store at /var/lib/hatch/wai; any leftover session
# material inside the guest rootfs is a security liability.
safe_rmdir \
    "var/lib/hatch-wai" \
    "var/log/hatch-wai" \
    "var/log/hatch-wai-privsep"

# The guest daemon now logs to stderr, which the host com.hatch.daemon.service
# captures into the journal via control-daemon.sh's nsenter. Drop the stale
# guest file-log directory from existing installs.
safe_rmdir \
    "var/log/hatch-daemon"

# systemd-nspawn requires Inaccessible= targets to exist in the guest rootfs.
# The real PostgreSQL data directory stays host-only; the runtime cell sees only
# the socket bind under /run/hatch/postgres.
safe_mkdir 0755 "var/lib/hatch/postgres"
guest_root_chown "var/lib/hatch" "var/lib/hatch/postgres"

# Disable dynamic MOTD scripts inside the guest. PAM runs everything in
# /etc/update-motd.d/ on each login shell, generating outbound network
# traffic (apt checks, release info fetches) that is pure noise.
safe_rmdir "etc/update-motd.d"
safe_mkdir 0755 "etc/update-motd.d"
guest_root_chown "etc/update-motd.d"

# The runtime cell is a Hatch execution namespace, not a general-purpose booted
# Ubuntu session. The host starts the daemon through nsenter; the guest PID 1
# only needs sysinit plus the execd socket anchor. Booting the distro default
# target starts snap, udisks, polkit, apt/man-db timers, gettys, and sometimes
# graphical.target, all of which contend with the daemon during replacement VM
# startup without making Hatch more ready to serve.
safe_write "etc/systemd/system/default.target" <<'UNIT'
[Unit]
Description=Hatch runtime-cell minimal boot target
DefaultDependencies=no
AllowIsolate=yes
UNIT
guest_root_chown "etc/systemd/system/default.target"
install_guest_scratch_cleanup
install_guest_chromium_policy

# Propagate git safe.directory into the guest so the daemon can operate on
# the bind-mounted jarvis_home without "dubious ownership" errors.
guest_gitconfig="etc/gitconfig"
ensure_not_symlink "$guest_gitconfig"
if ! grep -qF "directory = /home/hatch" "$canonical_rootfs/$guest_gitconfig" 2>/dev/null; then
    safe_append "$guest_gitconfig" <<GITCFG
[safe]
	directory = /home/hatch
GITCFG
fi
safe_chmod 0644 "$guest_gitconfig"

# /etc/hosts and /etc/resolv.conf are no longer materialized in the rootfs: they
# are static files under /opt/hatch/runtime-cell/etc, bind-mounted read-only over
# the cell's /etc by htch-runtime.nspawn. nspawn creates the bind targets on
# start, so whatever rootfs-base ships at those paths is simply overmounted.

safe_mkdir 0755 "etc/systemd/network"
guest_root_chown "etc/systemd/network"
safe_write "etc/systemd/network/80-container-host0.network" <<EOF
[Match]
Name=host0

[Network]
Address=$address_cidr
Address=$address_ipv6_cidr
Gateway=$gateway_ip
Gateway=$gateway_ipv6
DNS=$gateway_ip
DNS=$gateway_ipv6
DHCP=no
LinkLocalAddressing=no
IPv6AcceptRA=no
EOF
guest_root_chown "etc/systemd/network/80-container-host0.network"
