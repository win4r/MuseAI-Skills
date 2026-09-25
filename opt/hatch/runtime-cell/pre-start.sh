#!/bin/sh
set -eu

machine=htch-runtime
veth=ve-htch-runtime
ready_file=/run/hatch/runtime-cell/runtime-cell.ready
draining_file=/run/hatch/ingress/runtime-cell-draining
service_unit=com.hatch.runtime-cell.service
machine_state_file="/run/systemd/machines/$machine"
machine_unit_link="/run/systemd/machines/unit:$service_unit"
machine_propagate_dir="/run/systemd/nspawn/propagate/$machine"
bootstrap_identity_file="/run/hatch/runtime-cell/jarvis-runtime-cell-bootstrap-identity.json"
bootstrap_queue_dir="/run/hatch/runtime-cell/runtime-cell-bootstrap-events"
runtime_cell_handoff_dir="$(dirname "$ready_file")"
daemon_lifecycle_identity_file="$runtime_cell_handoff_dir/shellworks-daemon-lifecycle-identity.json"
# RT-3: lifecycle handoff state lives in root-owned /run/hatch/daemon-ctl.
# /run/hatch/daemon (hatch-daemon-owned == cell-root-forgeable) is the daemon
# socket dir only. The legacy vars below name the two retired env-file
# generations, swept from upgraded VMs further down.
daemon_ctl_dir="/run/hatch/daemon-ctl"
daemon_pre_start_marker_file="$daemon_ctl_dir/runtime-cell-pre-start-started-at-ms"
daemon_post_hatch_mount_boundaries_file="$daemon_ctl_dir/post-hatch-mount-boundaries.json"
legacy_daemon_handoff_dir="/run/hatch/daemon"
legacy_daemon_lifecycle_env_file="/run/hatch/daemon-lifecycle/daemon-lifecycle-env.sh"
phase_started_at_ms="$(date +%s%3N)"

# A new cell generation must retain access to pre-daemon Noise lanes (Vault
# unlock and recovery). Clear only the positive prior-generation drain fence;
# absence is not interpreted as readiness.
rm -f "$draining_file"

queue_runtime_cell_bootstrap_phase() {
    phase_failure_reason="${5:-}"
    if [ -n "$phase_failure_reason" ]; then
        "/opt/hatch/bin/spawnd" queue-runtime-cell-bootstrap \
            --jarvis-home "/home/hatch" \
            --phase "$1" \
            --status "$2" \
            --started-at-ms "$3" \
            --completed-at-ms "$4" \
            --failure-reason "$phase_failure_reason" || true
    else
        "/opt/hatch/bin/spawnd" queue-runtime-cell-bootstrap \
            --jarvis-home "/home/hatch" \
            --phase "$1" \
            --status "$2" \
            --started-at-ms "$3" \
            --completed-at-ms "$4" || true
    fi
}

queue_pre_start_failure() {
    status="$1"
    if [ "$status" -ne 0 ]; then
        phase_completed_at_ms="$(date +%s%3N)"
        queue_runtime_cell_bootstrap_phase \
            runtime_cell_pre_start \
            failure \
            "$phase_started_at_ms" \
            "$phase_completed_at_ms"
    fi
    exit "$status"
}

trap 'queue_pre_start_failure $?' EXIT

fail_rootfs_not_ready() {
    echo "runtime-cell rootfs readiness: $*" >&2
    exit 78
}

rootfs_readiness_error=""

# RT-4b: (re)attach the spawnd-owned fail-closed cell egress gate. The cell
# service cgroup is recreated on every start, which is exactly why this runs
# here (root, every start, pre-RV included) rather than once at install. The
# gate is the floor UNDER Sentinel: with BPF_F_ALLOW_MULTI-composed cgroup
# hooks every program must allow, so a dead/held-down Sentinel no longer
# means ungoverned link-local/RFC1918/CGNAT reach. Failure is fatal to the
# cell start on purpose: an ungated cell is the exact posture this wave
# removes.
"/opt/hatch/bin/spawnd" attach-cell-gate \
    --gateway-ip "198.19.0.1" \
    --gateway-ip6 "fd8b:4f84:7d32:99::1"

rootfs_is_ready() {
    rootfs="$("/opt/hatch/runtime-cell/resolve-rootfs-path.sh" "/var/lib/hatch-runtime/rootfs")" || {
        rootfs_readiness_error="failed to resolve rootfs path"
        return 2
    }
    rootfs_parent="$(dirname "$rootfs")"

    if [ -e "$rootfs.incoming" ]; then
        rootfs_readiness_error="rootfs swap is still in progress at $rootfs.incoming"
        return 1
    fi

    if [ ! -d "$rootfs" ]; then
        rootfs_readiness_error="rootfs is missing at $rootfs"
        return 1
    fi

    if [ ! -x "$rootfs/bin/sh" ] && [ ! -x "$rootfs/usr/bin/sh" ]; then
        rootfs_readiness_error="rootfs is not bootable: missing executable shell"
        return 1
    fi

    for rel in etc var opt usr; do
        if [ ! -d "$rootfs/$rel" ]; then
            rootfs_readiness_error="rootfs is incomplete: missing /$rel"
            return 1
        fi
    done

    return 0
}

assert_rootfs_ready() {
    status=0
    rootfs_is_ready || status="$?"
    if [ "$status" -eq 0 ]; then
        echo "runtime-cell rootfs readiness: fast path ok at $rootfs" >&2
        return
    fi

    if [ "$status" -eq 2 ]; then
        fail_rootfs_not_ready "$rootfs_readiness_error"
    fi

    echo "runtime-cell rootfs readiness: $rootfs_readiness_error; attempting rootfs bootstrap" >&2
    "/opt/hatch/runtime-cell/ensure-rootfs.sh"

    if ! rootfs_is_ready; then
        fail_rootfs_not_ready "rootfs still not ready after repair: $rootfs_readiness_error"
    fi

    echo "runtime-cell rootfs readiness: fast path ok at $rootfs" >&2
}

machine_exists() {
    machinectl show "$machine" >/dev/null 2>&1
}

machine_leader() {
    machinectl show "$machine" -p Leader --value 2>/dev/null || true
}

machine_leader_is_live() {
    leader="$(machine_leader)"
    [ -n "$leader" ] && [ "$leader" != "0" ] && kill -0 "$leader" >/dev/null 2>&1
}

wait_for_machine_gone() {
    attempts="$1"
    for i in $(seq 1 "$attempts"); do
        if ! machine_exists; then
            return 0
        fi
        if ! machine_leader_is_live; then
            clear_stale_machine_state
            if ! machine_exists; then
                return 0
            fi
        fi
        sleep 0.1
    done
    return 1
}

clear_stale_machine_state() {
    if command -v busctl >/dev/null 2>&1; then
        busctl call \
            org.freedesktop.machine1 \
            /org/freedesktop/machine1 \
            org.freedesktop.machine1.Manager \
            UnregisterMachine s "$machine" >/dev/null 2>&1 || true
    fi
    rm -f "$machine_state_file" "$machine_unit_link"
    rm -rf "$machine_propagate_dir"
}

assert_rootfs_ready

if machine_exists; then
    if machine_leader_is_live; then
        machinectl terminate "$machine" 2>/dev/null || true
        if ! wait_for_machine_gone 100; then
            echo "runtime-cell machine still registered after graceful terminate; forcing kill: $machine" >&2
            machinectl kill --signal=KILL --kill-whom=all "$machine" 2>/dev/null || true
        fi
    else
        clear_stale_machine_state
    fi
fi
if ! wait_for_machine_gone 200; then
    echo "stale runtime-cell machine did not terminate: $machine" >&2
    exit 1
fi
# /etc/hosts and /etc/resolv.conf content is supplied by nspawn's BindReadOnly of
# the static /opt/hatch/runtime-cell/etc files. Run the lightweight repair pass
# every start so the bind targets are guaranteed to be regular files (not the
# systemd-resolved stub symlink) with correct perms, even on an existing rootfs
# a full bootstrap would skip.
"/opt/hatch/runtime-cell/ensure-rootfs.sh" --repair-hosts-only
# --- Pre-RV bind sources ---
# The cell starts at multi-user.target, before the reliable volume attaches, so
# every host path htch-runtime.nspawn Bind='s must already exist. Pre-RV these
# are plain root-fs directories; when the RV attaches, home-hatch.mount /
# var-lib-hatch.mount overmount them on the host and host->cell mount
# propagation delivers the RV view into the RUNNING cell — no cell restart at
# mount time.
#
# /home/hatch (/home/hatch): owner/mode mirror the post-mount contract
# (hatch-seed.sh TARGET_OWNER=hatch-daemon:hatch-shared TARGET_MODE=2770).
# Never touch it when it is already a mountpoint — the RV home is
# persistent user state, while hatch-seed.sh manages only its bind-source root.
if ! mountpoint -q "/home/hatch"; then
    install -d -m 2770 -o hatch-daemon -g hatch-shared "/home/hatch"
fi
# Read-only publication mount points INSIDE the home (today: assets, .pki/nssdb)
# must exist on whichever home this start sees: the pre-RV stub or mounted RV.
# Every component below /home/hatch is guest-owned, so spawnd uses mkdirat +
# openat2/RESOLVE_NO_SYMLINKS instead of a path-based shell mkdir/chown.
#
# The same command refreshes the cell-home and assets bridges in PID 1's mount
# namespace before inspecting the home. ReadWritePaths= gives this ExecStartPre
# a private mount namespace whose mount events cannot reach the host, while
# launch-daemon's later namespace is cloned from the host. The cell always binds
# its home from /home/.hatch-runtime-cell-home. That root-owned sibling stays
# hidden by ProtectHome in sandboxed host services. The bridge is shared-slave:
# an active or later-attached RV flows toward the cell, while cell mount events
# cannot flow back below /home/hatch. The command also retires the exact legacy
# assets and per-user NSS DB grafts below /home/hatch and /hatch/home/hatch
# while the previous cell is fully stopped. post-stop.sh releases the bridge
# after the machine exits; rv-graft restarts preserve it while this cell lives.
# Run this before the mountpoint ensure: removing the old read-only cover can
# reveal a guest-planted path that the kernel-fenced ensure must reject. The
# command prints a bounded assets-publication verdict. Publication failures are
# fail-open for cell availability, but are recorded separately from the overall
# pre-start result so an empty assets view never looks like a fully successful
# boot. pre-start always attempts the boot-time /run bridge publication, even
# on pre-RV starts; rv-graft later republishes assets as a locked child of the
# replacement RV-backed home tree.
assets_publish_started_at_ms="$(date +%s%3N)"
assets_publish_verdict="$(
    /usr/bin/nsenter --target 1 --mount -- \
        "/opt/hatch/bin/spawnd" ensure-guest-home-mountpoints --jarvis-home "/home/hatch"
)"
assets_publish_completed_at_ms="$(date +%s%3N)"
assets_publish_status=
assets_publish_failure_reason=
case "$assets_publish_verdict" in
    published)
        assets_publish_status=success
        ;;
    installed_assets_missing|read_only_bind_failed)
        assets_publish_status=failure
        assets_publish_failure_reason="$assets_publish_verdict"
        ;;
    "")
        # Empty is mixed-version compatibility with an older spawnd, which did
        # not print a verdict.
        ;;
    *)
        echo "unexpected assets publication verdict: $assets_publish_verdict" >&2
        exit 1
        ;;
esac
# Mixed-version rollback safety: the command name predates both bridges. An
# older spawnd can create the retired /run alias but not the protected source.
# Remove that alias child-first, then prepare the new source in PID 1's
# namespace so nspawn never starts with an empty home while binaries and
# templates straddle a live update.
for legacy_cell_home_mount in \
    /run/hatch/cell-home/assets \
    /run/hatch/cell-home/.pki/nssdb \
    /run/hatch/cell-home; do
    while /usr/bin/nsenter --target 1 --mount -- mountpoint -q "$legacy_cell_home_mount"; do
        /usr/bin/nsenter --target 1 --mount -- umount -l "$legacy_cell_home_mount"
    done
done
if ! /usr/bin/nsenter --target 1 --mount -- mountpoint -q /home/.hatch-runtime-cell-home; then
    /usr/bin/nsenter --target 1 --mount -- \
        install -d -m 0755 -o root -g root /home/.hatch-runtime-cell-home
    /usr/bin/nsenter --target 1 --mount -- \
        mount --bind "/home/hatch" /home/.hatch-runtime-cell-home
    /usr/bin/nsenter --target 1 --mount -- \
        mount --make-slave /home/.hatch-runtime-cell-home
    /usr/bin/nsenter --target 1 --mount -- \
        mount --make-shared /home/.hatch-runtime-cell-home
fi
if ! /usr/bin/nsenter --target 1 --mount -- mountpoint -q /run/hatch/cell-assets; then
    /usr/bin/nsenter --target 1 --mount -- \
        install -d -m 0755 -o root -g root /run/hatch/cell-assets
fi
# /run/hatch/cell-state/os-intent: bridge SOURCE for the package-intent
# ledger bind (nspawn Bind= has no optional `-` marker, so the source must
# exist or the cell start fails). Pre-RV an empty tmpfs dir; at mount time
# rv-graft bind-mounts the RV's /var/lib/hatch/os-intent onto it and the
# mount (at the bind source root) propagates into the running cell. Owned by
# hatch-daemon (the cell-root host uid) so pre-RV in-cell writes cannot
# error — they land in the discardable tmpfs view by design.
install -d -m 0755 -o root -g root /run/hatch/cell-state
# Mountpoint guards: a cell RESTART runs this script again after rv-graft
# has overmounted the bridges with the real RV dirs. install -d on an
# overmounted bridge would chown/chmod RV state (and EROFS-fail outright on
# the read-only worker-state bridges); the grafted state is rv-graft's to
# own, so the ensure applies strictly to the pre-graft tmpfs dirs.
if ! mountpoint -q /run/hatch/cell-state/os-intent; then
    install -d -m 0750 -o hatch-daemon -g hatch-shared /run/hatch/cell-state/os-intent
fi
# /run/hatch/cell-state/apt-archives: bridge SOURCE for the cell's
# /var/cache/apt/archives bind — the persistent apt package cache (same
# propagation pattern as os-intent above; rv-graft overmounts it with the
# RV-backed /var/lib/hatch/apt-archives at mount time). Persisting the .deb
# cache makes the os-intent replay after a cell-base digest change — a
# fleet-correlated event: every VM's rootfs rebuilds on the same rollout —
# mostly local-disk reads instead of a fleet-wide mirror thundering herd.
# 0755 so apt's sandboxed _apt fetch user can traverse; apt re-verifies
# cached .debs against the signed index hashes before unpacking, so a stale
# or cell-tampered cache entry is re-fetched, never trusted.
if ! mountpoint -q /run/hatch/cell-state/apt-archives; then
    install -d -m 0755 -o hatch-daemon -g hatch-shared /run/hatch/cell-state/apt-archives
fi
# /run/hatch/resume: the resume-state bridge bind source (see the Bind= comment
# in htch-runtime.nspawn). Pre-RV an empty tmpfs dir; at mount time rv-graft
# bind-mounts /hatch/data/resume onto it and the mount propagates into the running
# cell. hatch-daemon is the cell-root host uid, so the in-cell daemon can
# write the handoff marker + resume index through the bridge.
if ! mountpoint -q /run/hatch/resume; then
    install -d -m 0770 -o hatch-daemon -g hatch-shared /run/hatch/resume
fi
# Plain nspawn Bind= sources that host-path-setup.sh only creates AFTER the
# RV attaches. The cell now boots pre-RV, and nspawn Bind= has no optional
# marker, so a missing source fails the whole cell start on a fresh boot
# (masked on testbeds whose RV is present at boot: host-path-setup wins the
# race there). Ownership/mode mirror host-path-setup.sh, whose post-mount
# install -d re-applies the same values idempotently. Any new Bind= source
# in htch-runtime.nspawn MUST be created here too, not only post-mount.
if ! mountpoint -q /run/hatch/egress-tz; then
    install -d -m 0755 -o hatch-daemon -g hatch-daemon /run/hatch/egress-tz
fi
if ! mountpoint -q /run/hatch/egress-tls; then
    install -d -m 0755 -o hatch-sentinel -g hatch-sentinel /run/hatch/egress-tls
fi
if ! mountpoint -q /run/hatch/runtime-cell; then
    install -d -m 0750 -o root -g root /run/hatch/runtime-cell
fi
if ! mountpoint -q /run/hatch/privsep; then
    install -d -m 0755 -o root -g root /run/hatch/privsep
fi

# The cell-* BindReadOnly sources, same rule as the group above. Both creators
# that would otherwise cover them cannot: host-path-setup.service is a oneshot
# that does NOT re-run when a live install restarts the cell, and the
# trust-store producer's own ensure_bind_sources runs After= this unit. nspawn
# fails the container start outright on a missing bind source. Directories only
# — the contents are the producer's, published asynchronously once Sentinel and
# yolk have their CAs. No mountpoint guard: nothing overmounts these, unlike the
# rv-graft bridges above.
install -d -m 0755 -o root -g root \
    /run/hatch/cell-anchors \
    /run/hatch/cell-nssdb \
    /run/hatch/cell-user-nssdb

ip link delete "$veth" 2>/dev/null || true
rm -f "$ready_file" "$daemon_lifecycle_identity_file"
# rv-graft temporarily grants the mapped cell-root group exact-path access to
# the sanitized lifecycle projection. Revoke that grant for this generation
# before recreating any runtime-cell handoff state.
chown root:root "$runtime_cell_handoff_dir"
chmod 0750 "$runtime_cell_handoff_dir"
install -d -m 0755 -o root -g root "$daemon_ctl_dir"
rm -rf "$daemon_ctl_dir/env"
# Legacy entries: a VM upgraded into this build still has the retired
# env-file generations (/run/hatch/daemon, then /run/hatch/daemon-lifecycle)
# and the pre-move markers under /run/hatch/daemon; nothing else removes them.
rm -f \
    "$legacy_daemon_lifecycle_env_file" \
    "$legacy_daemon_handoff_dir/daemon-lifecycle-env.sh" \
    "$legacy_daemon_handoff_dir/runtime-cell-pre-start-started-at-ms" \
    "$legacy_daemon_handoff_dir/post-hatch-mount-boundaries.json" \
    "$daemon_pre_start_marker_file" \
    "$daemon_post_hatch_mount_boundaries_file"

install -d -m 0755 -o root -g root /opt/hatch/runtime-cell
# Public readiness state lives here and must be visible from the runtime-cell
# user namespace. Sensitive handoff payloads stay protected by file/subdir mode.
install -d -m 0755 -o root -g root "$runtime_cell_handoff_dir"
rm -f "$bootstrap_identity_file"
rm -rf "$bootstrap_queue_dir"
# Daemon socket directories (/run/hatch/daemon, /run/hatch/sandbox-api)
# are created by the daemon itself after entering the cell's user namespace
# and chroot (see entry.rs). They live on the cell's tmpfs and are not
# bind-mounted from the host, so the sandbox API's no-auth allowlist is
# reachable from in-cell processes only (a prior comment here claimed a
# host<->cell bind and a host-UID exposure; no such bind exists). Each new
# entry in the sandbox allowlist is still audited as an unauthenticated
# endpoint — every in-cell caller is admitted — and the presentation writers
# additionally bind to a live execution server-side (see
# `build_sandbox_api_router` and `resolve_presentation_execution` in
# hatch-server). The postgres socket is proxied by the seccomp
# supervisor and does not need a cell-local directory.

# Snapshot install/version state (current.json) into jarvis_home for in-sandbox
# readers (fileserver version endpoint, healthd). The canonical copy lives in
# /opt/hatch/update/ which is not bind-mounted into the container.
#
# Guard against symlink attacks: if /home/hatch/update exists and is not a
# real directory, remove it before recreating. An attacker with sandbox write
# access could replace it with a symlink to redirect the privileged write.
opt_hatch_update="/opt/hatch/update"
home_update="/home/hatch/update"
if [ -d "$opt_hatch_update" ]; then
    if [ -L "$home_update" ]; then
        rm -f "$home_update"
    fi
    if [ -e "$home_update" ] && [ ! -d "$home_update" ]; then
        rm -f "$home_update"
    fi
    install -d -m 0755 "$home_update"
    for f in current.json; do
        target="$home_update/$f"
        # Reject any non-regular-file at the target path: symlinks,
        # directories, or other special files could redirect the
        # privileged install outside jarvis_home.
        if [ -L "$target" ] || { [ -e "$target" ] && [ ! -f "$target" ]; }; then
            rm -rf "$target"
        fi
        if [ -f "$opt_hatch_update/$f" ]; then
            install -m 0644 "$opt_hatch_update/$f" "$target"
        fi
    done
fi

trap - EXIT
printf '%s\n' "$phase_started_at_ms" > "$daemon_pre_start_marker_file"
if [ -n "$assets_publish_status" ]; then
    queue_runtime_cell_bootstrap_phase \
        runtime_cell_assets_publish \
        "$assets_publish_status" \
        "$assets_publish_started_at_ms" \
        "$assets_publish_completed_at_ms" \
        "$assets_publish_failure_reason"
fi
phase_completed_at_ms="$(date +%s%3N)"
queue_runtime_cell_bootstrap_phase \
    runtime_cell_pre_start \
    success \
    "$phase_started_at_ms" \
    "$phase_completed_at_ms"
