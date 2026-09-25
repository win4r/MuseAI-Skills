#!/bin/sh
# build-cell-trust-store.sh — host-side producer for the runtime cell's trust
# anchors and NSS databases.
#
# STRUCTURAL CONTRACT: this script never reads or writes the cell's rootfs, and
# never enters the cell. It publishes exactly what the cell cannot derive for
# itself, into three directories htch-runtime.nspawn binds read-only:
#
#   /run/hatch/cell-anchors     -> /run/hatch/cell-anchors  (the two hatch CAs)
#   /run/hatch/cell-nssdb       -> /etc/pki/nssdb
#   /run/hatch/cell-user-nssdb  -> /home/hatch/.pki/nssdb
#
# The cell's own PEM trust store (/etc/ssl/certs) is the CELL's to manage. The
# guest runs hatch-ca-trust.path/.service (installed by ensure-rootfs.sh), which
# links the anchors above into /usr/local/share/ca-certificates and runs the
# guest's own update-ca-certificates. Two consequences, both deliberate:
#
#   1. Nothing host-side touches the rootfs, so "a privileged context resolving
#      a name inside an attacker-controlled namespace" is gone by construction
#      rather than guarded. The host-side copy of the guest's ~295-entry CA
#      farm is deleted along with its snapshot, its seed mode, and its cost on
#      the cell's boot path.
#   2. An in-cell `update-ca-certificates` WORKS again — /etc/ssl/certs is no
#      longer overmounted — so an apt ca-certificates upgrade under
#      hatch-preflight-opportunistic no longer leaves that package half
#      configured. The cell can also subvert its own PEM trust, which is
#      self-harm: Sentinel still MITMs egress and remains the policy authority,
#      and no host process reads that tree.
#
# The NSS DBs stay host-built and read-only, and that asymmetry is the point:
# opening an NSS DB dlopen()s every PKCS#11 module named in its pkcs11.txt, so a
# cell-writable DB is a code-execution primitive against anything that opens it.
# PEM files carry no such hazard. Building the DBs needs no cell input at all —
# each is an empty DB plus the two anchors.

set -eu

case "${1:-}" in
    "") ;;
    *)
        echo "usage: build-cell-trust-store.sh" >&2
        exit 2
        ;;
esac

# Inputs. Both are host-owned and neither is writable from the cell: the egress
# CA is published by Sentinel, the ingress chain by yolk.
egress_ca_src=/run/hatch/egress-tls/hatch-egress-ca.pem
ingress_fullchain=/etc/tls/credentials/fullchain.pem

# Published outputs. DIRECTORY binds, not file binds: a file bind pins the
# source inode, so a rotation republished by rename would be invisible inside
# the cell. Binding the directory lets this producer republish by rename and
# have the cell observe it — which is also what lets the guest's .path unit
# notice a rotation and re-run update-ca-certificates.
anchors_dir=/run/hatch/cell-anchors
nssdb_dir=/run/hatch/cell-nssdb
user_nssdb_dir=/run/hatch/cell-user-nssdb

# Staging deliberately carries no /run/hatch/cell-* prefix, so it is not one of
# the bound directories and the cell cannot name it. Root-owned 0700: the cell
# can neither read a half-built store nor influence one mid-build.
staging=/run/hatch/.cell-trust-store.staging
inputs_marker=/run/hatch/.cell-trust-store.inputs

log() {
    echo "cell-trust-store: $*" >&2
}

# Auto-heal the bind SOURCES. nspawn fails the container start outright if a
# BindReadOnly= source is missing, and host-path-setup.service is a oneshot that
# does NOT re-run when a live install restarts the cell — so an upgraded VM would
# otherwise reach the new nspawn config with no /run/hatch/cell-* directories and
# fail to boot the cell. Runs before every early exit below.
ensure_bind_sources() {
    install -d -m 0755 -o root -g root \
        "$anchors_dir" "$nssdb_dir" "$user_nssdb_dir"
}

ensure_bind_sources

inputs_digest() {
    for f in "$egress_ca_src" "$ingress_fullchain"; do
        if [ -s "$f" ]; then
            sha256sum "$f"
        else
            echo "absent $f"
        fi
    done | sha256sum | awk '{print $1}'
}

published_looks_complete() {
    [ -s "$anchors_dir/hatch-egress-ca.pem" ] \
        && [ -s "$anchors_dir/hatch-ingress-ca.pem" ] \
        && [ -f "$nssdb_dir/cert9.db" ] \
        && [ -f "$user_nssdb_dir/cert9.db" ]
}

# Build one NSS DB in staging. It is then published to /run/hatch/cell-*nssdb
# and opened in the cell at a THIRD path (/etc/pki/nssdb or ~/.pki/nssdb), so
# the DB is deliberately built at a path none of its readers will use.
#
# That is safe, though it does not look it: `certutil -N` records
# `configdir='sql:<the -d path>'` in pkcs11.txt, so the published DBs carry a
# reference to this staging dir, which is deleted at the end of every run. NSS
# does not honour it — `NSS_Initialize(configdir)` supplies the caller's own
# configdir to the internal module at load time, and the recorded value is
# inert. Verified on the VM image (NSS 3.98) end to end in the exact production
# shape: build at A, publish to B, open at C with A deleted and C read-only —
# `certutil -L` lists the anchors and `certutil -V` validates against them, for
# both the system and the per-user path. Do not "fix" this by rewriting
# configdir or building at the final path; the mismatch is unavoidable anyway
# (the publish path is not the in-cell mount path either).
build_nssdb() {
    _db="$1"
    install -d -m 0755 -o root -g root "$_db"
    if ! certutil -d "sql:$_db" -N --empty-password; then
        log "failed to initialize NSS trust store at $_db"
        return 1
    fi
    if [ "$have_egress" -eq 1 ] \
        && ! certutil -d "sql:$_db" -A -t "C,," -n hatch-egress \
            -i "$staging/anchors/hatch-egress-ca.pem"; then
        log "failed to import egress CA into $_db"
        return 1
    fi
    if [ "$have_ingress" -eq 1 ] \
        && ! certutil -d "sql:$_db" -A -t "C,," -n hatch-ingress \
            -i "$staging/anchors/hatch-ingress-ca.pem"; then
        log "failed to import ingress CA into $_db"
        return 1
    fi
    # World-readable: the cell reads these across the PrivateUsers map, where
    # neither owner nor group match, so the other bits are what grant access.
    chmod 0644 "$_db"/* 2>/dev/null || true
}

# Publish one staged directory into its live bind source. The destination is a
# live bind SOURCE, so it must be updated in place — replacing the directory
# itself would swap the inode out from under the cell's mount. rename(2) of
# entries INSIDE it is visible in the cell (the mount pins the directory, not
# its entries), so each file lands atomically: a reader sees the old file or the
# new one, never a partial write.
publish_dir() {
    _src="$1"
    _dst="$2"
    install -d -m 0755 -o root -g root "$_dst"
    for _p in "$_src"/* "$_src"/.[!.]*; do
        if [ ! -e "$_p" ] && [ ! -L "$_p" ]; then
            continue
        fi
        _n="$(basename "$_p")"
        # ${var:?} on every interpolated rm -rf path: this runs as root against
        # a directory the cell has mounted, so an empty expansion must abort the
        # script rather than widen the delete.
        rm -rf "${_dst:?}/.publishing.${_n:?}"
        cp -a "$_p" "$_dst/.publishing.$_n"
        # mv -T cannot replace a non-empty directory; drop the old one first.
        if [ -d "$_dst/$_n" ] && [ ! -L "$_dst/$_n" ]; then
            rm -rf "${_dst:?}/${_n:?}"
        fi
        mv -fT "$_dst/.publishing.$_n" "$_dst/$_n"
    done
    # Prune entries this build no longer produces (a rotated-out CA, or a
    # half-written temp left by an interrupted publish).
    for _p in "$_dst"/* "$_dst"/.[!.]*; do
        if [ ! -e "$_p" ] && [ ! -L "$_p" ]; then
            continue
        fi
        _n="$(basename "$_p")"
        case "$_n" in
            .publishing.*)
                rm -rf "${_p:?}"
                continue
                ;;
        esac
        if [ ! -e "$_src/$_n" ] && [ ! -L "$_src/$_n" ]; then
            rm -rf "${_p:?}"
        fi
    done
}

digest="$(inputs_digest)"
if [ "$digest" = "$(cat "$inputs_marker" 2>/dev/null || true)" ] && published_looks_complete; then
    exit 0
fi

rm -rf "$staging"
install -d -m 0700 -o root -g root "$staging"
install -d -m 0755 -o root -g root "$staging/anchors"

have_egress=0
if [ -s "$egress_ca_src" ]; then
    install -m 0644 "$egress_ca_src" "$staging/anchors/hatch-egress-ca.pem"
    have_egress=1
else
    log "egress CA not published yet: $egress_ca_src"
fi

have_ingress=0
if [ -s "$ingress_fullchain" ]; then
    # Everything after the leaf is the CA chain. Only the public chain is ever
    # extracted; the private key beside it is never read, and that directory is
    # never bound into the cell precisely because the key sits in it.
    awk 'BEGIN{c=0} /-----BEGIN CERTIFICATE-----/{c++} c>=2{print}' \
        "$ingress_fullchain" >"$staging/ingress-ca.pem"
    if [ -s "$staging/ingress-ca.pem" ]; then
        install -m 0644 "$staging/ingress-ca.pem" "$staging/anchors/hatch-ingress-ca.pem"
        have_ingress=1
    else
        log "no intermediate CA found in $ingress_fullchain"
    fi
else
    log "ingress TLS fullchain not ready yet: $ingress_fullchain"
fi

nss_ok=1
if ! command -v certutil >/dev/null 2>&1; then
    # certutil comes from libnss3-tools. It is a HOST package requirement of
    # this producer, so a host image without it cannot give Chromium the
    # Sentinel-MITM or ingress trust anchors. Fail loudly rather than quietly
    # shipping an empty NSS DB.
    log "certutil missing on the host; install libnss3-tools in the VM image"
    nss_ok=0
else
    build_nssdb "$staging/nssdb" || nss_ok=0
fi

publish_dir "$staging/anchors" "$anchors_dir"
if [ "$nss_ok" -eq 1 ]; then
    publish_dir "$staging/nssdb" "$nssdb_dir"
    publish_dir "$staging/nssdb" "$user_nssdb_dir"
fi
rm -rf "$staging"

if [ "$nss_ok" -eq 1 ] && [ "$have_egress" -eq 1 ] && [ "$have_ingress" -eq 1 ]; then
    printf '%s\n' "$digest" >"$inputs_marker"
    chmod 0600 "$inputs_marker"
    log "published trust anchors + NSS stores (egress + ingress)"
    exit 0
fi

# Incomplete. Never mark the inputs converged, so the next trigger rebuilds.
# What was already published stays in place, so the cell keeps whatever trust
# this run could build.
rm -f "$inputs_marker"

if [ "$nss_ok" -eq 1 ]; then
    # Inputs pending, build machinery healthy. Expected, twice over:
    # (1) the resume boot pulls this unit (via runtime-cell, a
    # multi-user.target member since the pre-RV park design) in the INITIAL
    # boot transaction, where Sentinel is not even scheduled — Sentinel is
    # WantedBy=hatch-rv.target, and the control plane attaches the volume
    # only after the boot health gate passes — so the egress CA cannot
    # exist yet on this first run; (2) at attach, sentinel.service re-pulls
    # this unit when sentinel STARTS, which can still precede the async CA
    # publish, and yolk lands the ingress chain on its own schedule
    # entirely. Neither is a failure: the paired .path watchers re-trigger
    # this unit the moment either input file lands. Exiting nonzero here
    # instead marks the unit failed, and `systemctl is-system-running`
    # then reads "degraded" — but the control plane waits for exactly
    # "running" before it attaches the RV, so a pre-RV failure BLOCKS the
    # attach that would deliver the missing input, and the boot proceeds
    # only when a health poll happens to land in an auto-restart limbo
    # window between retries (measured ~13s of STARTING dwell per boot,
    # every boot). Reserve the failure exit for real build errors below,
    # where the Restart ladder can actually help.
    log "inputs pending (egress=$have_egress ingress=$have_ingress); path watchers will converge"
    exit 0
fi

# A real build error: certutil absent, or an NSS database that failed to
# build. Here the unit's Restart=on-failure ladder can actually help.
exit 1
