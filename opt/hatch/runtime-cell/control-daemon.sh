#!/bin/sh
set -eu

# The interactive `hatch` launcher was retired. Older OS images baked this
# wrapper outside the versioned /opt/hatch tree, so try to remove it before
# every daemon start as well as during live bundle installation. This cleanup
# must never prevent the daemon from booting; the installer is the durable,
# fail-closed owner of removing the retired path.
retired_global_hatch_launcher="/usr/local/bin/hatch"
if ! rm -f -- "$retired_global_hatch_launcher"; then
    echo "WARN: could not remove retired hatch launcher: $retired_global_hatch_launcher" >&2
fi

# RT-3: lifecycle handoff state lives in root-owned /run/hatch/daemon-ctl,
# NEVER /run/hatch/daemon — that dir is owned by hatch-daemon (uid 131072,
# the cell's root), so any file there can be replaced by cell root between a
# root write and a root read. daemon-ctl is created root:root 0755 by
# host-path-setup/pre-start; recreate here as the pre-RV belt.
daemon_ctl_dir="/run/hatch/daemon-ctl"
install -d -m 0755 -o root -g root "$daemon_ctl_dir"
daemon_controller_entered_at_ms_file="$daemon_ctl_dir/daemon-controller-entered-at-ms"
daemon_controller_entered_at_ms="$(date +%s%3N)"
if ! printf '%s\n' "$daemon_controller_entered_at_ms" > "$daemon_controller_entered_at_ms_file"; then
    echo "WARN: failed to write daemon controller marker: $daemon_controller_entered_at_ms_file" >&2
fi

# Shared runtime-cell launcher helpers (guest.env sourcing, ready/leader wait).
. "/opt/hatch/runtime-cell/runtime-cell-entry.sh"

if [ -r "/etc/hatch/env" ]; then
    . "/etc/hatch/env"
fi
if [ -r "/etc/hatch/env.override" ]; then
    . "/etc/hatch/env.override"
fi

# The daemon now enters the runtime cell directly instead of via a wrapper that
# sourced the in-cell guest-runtime-env.sh, so without this it would launch
# without the cell egress proxy + TLS CA bundle env and its Sentinel-routed
# egress (and TLS verification) would break. Export the cell runtime env from
# the host-rendered, root-owned guest.env (NOT the cell-writable
# guest-runtime-env.sh, which this privileged launcher must not trust). Source
# env.override last so ops overrides still win over guest.env defaults.
rce_source_guest_env
set -a
if [ -r "/etc/hatch/env.override" ]; then
    . "/etc/hatch/env.override"
fi
set +a

emit_daemon_lifecycle_event() {
    "/opt/hatch/bin/spawnd" emit-daemon-lifecycle --phase "$1" || true
}

drain_shutdown_observability_async() {
    # Best-effort next-boot drain must not hold daemon startup behind a slow or
    # wedged telemetry-proxy.
    "/opt/hatch/bin/spawnd" drain-shutdown-observability --jarvis-home "/home/hatch" || true
}

# Wait for the runtime cell to be ready and resolve its leader PID.
leader="$(rce_wait_for_ready_leader)" || exit 1

drain_shutdown_observability_async &
emit_daemon_lifecycle_event start-observed

# RT-3: the retired daemon-lifecycle-env.sh `source` was a uid-131072→root
# code-execution race (cell root owned its directory and could swap the file
# for arbitrary shell between spawnd's write and this source). The handoff is
# now ONE FILE PER KEY under root-owned /run/hatch/daemon-ctl/env/, and this
# loop exports an EXPLICIT ALLOWLIST with the raw file body as the value —
# no eval, no source, no path component any non-root identity can influence.
#
# Why not systemd LoadCredential=: credentials materialize once, when the
# unit's first process is spawned — but every one of these keys is produced
# DURING this very start (`spawnd emit-daemon-lifecycle start-observed`, a
# few lines up), and all of them are optional per boot path (pre-RV first
# start has no boundary markers at all), so `LoadCredential=id:path` would
# either read stale/absent values or fail the unit closed on a healthy boot.
# Reading the root-owned dir directly in this root ExecStart is the
# systemd-native shape that actually fits the producer's timing.
daemon_lifecycle_env_dir="$daemon_ctl_dir/env"
for lifecycle_key in \
    HATCH_DAEMON_LIFECYCLE_COMMAND \
    HATCH_DAEMON_LIFECYCLE_OPERATION \
    HATCH_DAEMON_LIFECYCLE_SHELLWORKS_REQUEST_ID \
    HATCH_DAEMON_LIFECYCLE_BOOTSTRAP_REQUEST_ID \
    HATCH_DAEMON_LIFECYCLE_HATCHLING_ID \
    HATCH_DAEMON_LIFECYCLE_VM_ID \
    HATCH_DAEMON_LIFECYCLE_VM_WORKFLOW_ID \
    HATCH_DAEMON_LIFECYCLE_IS_FIRST_DAEMON_ATTEMPT_IN_BOOT \
    HATCH_DAEMON_LIFECYCLE_IS_IMAGE_BOOT \
    HATCH_DAEMON_LIFECYCLE_RUNTIME_CELL_PRE_START_STARTED_AT_MS \
    HATCH_DAEMON_LIFECYCLE_HATCH_MOUNT_READY_AT_MS \
    HATCH_DAEMON_LIFECYCLE_HATCH_MOUNT_ATTACH_STARTED_AT_MS \
    HATCH_DAEMON_LIFECYCLE_HATCH_SEED_READY_AT_MS \
    HATCH_DAEMON_LIFECYCLE_HOME_HATCH_MOUNT_READY_AT_MS \
    HATCH_DAEMON_LIFECYCLE_HOST_PATH_SETUP_FINISHED_AT_MS \
    HATCH_DAEMON_LIFECYCLE_AUTHD_RV_REBIND_STARTED_AT_MS \
    HATCH_DAEMON_LIFECYCLE_AUTHD_RV_REBIND_READY_AT_MS \
    HATCH_DAEMON_LIFECYCLE_DB_CLUSTER_READY_AT_MS \
    HATCH_DAEMON_LIFECYCLE_POSTGRESQL_STARTED_AT_MS \
    HATCH_DAEMON_LIFECYCLE_POSTGRESQL_READY_AT_MS \
    HATCH_DAEMON_LIFECYCLE_DB_PREFLIGHT_READY_AT_MS \
    HATCH_DAEMON_LIFECYCLE_DAEMON_SERVICE_START_REQUESTED_AT_MS
do
    lifecycle_key_file="$daemon_lifecycle_env_dir/$lifecycle_key"
    if [ -f "$lifecycle_key_file" ] && [ -r "$lifecycle_key_file" ]; then
        # Value passed as-is (first line, no interpretation).
        lifecycle_value=""
        IFS= read -r lifecycle_value < "$lifecycle_key_file" || true
        export "$lifecycle_key=$lifecycle_value"
    fi
done
unset lifecycle_key lifecycle_key_file lifecycle_value

export HATCH_DAEMON_LIFECYCLE_STARTED_AT_MS="$(date +%s%3N)"
export HATCH_DAEMON_LIFECYCLE_DAEMON_CONTROLLER_ENTERED_AT_MS="$daemon_controller_entered_at_ms"

# Host boot id for the AwaitRvIdentity barrier: read here, while still in the
# host mount namespace, because the in-cell daemon's /proc carries an
# nspawn-synthesized per-container boot id that never equals the host value
# `spawnd rv-graft` stamps into the rv-identity-ready marker. Missing/empty
# degrades in the daemon to accept-any (stale-boot filtering off), never a
# parked-forever barrier.
HATCH_HOST_BOOT_ID="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || true)"
export HATCH_HOST_BOOT_ID

exec "/opt/hatch/bin/hatch" daemon --runtime-cell-leader="$leader"
