#!/bin/sh
set -eu

ready_file=/run/hatch/runtime-cell/runtime-cell.ready
spawnd_bin="/opt/hatch/bin/spawnd"

emit_mount_stop_lifecycle_event() {
    "$spawnd_bin" emit-mount-stop-lifecycle --phase "$1" --event "$2" --timestamp-ms "$3" || true
}

emit_mount_stop_lifecycle_event runtime_cell_post_stop started "$(date +%s%3N)"
rm -f "$ready_file"

# pre-start creates the whole-home propagation anchor in PID 1's mount
# namespace, so the runtime-cell lifecycle owns its teardown too. Releasing it
# only after stop.sh has removed the machine preserves the peer across a
# standalone rv-graft restart while still dropping every RV reference before
# the mount stop continues. ReadWritePaths= gives this ExecStopPost its own
# mount namespace, hence the explicit nsenter.
/usr/bin/nsenter --target 1 --mount -- \
    "$spawnd_bin" rv-graft --teardown-cell-home || true

# pre-start.sh already removes any stale runtime-cell veth before the next boot.
# Avoid blocking service shutdown on kernel link teardown here; this path has
# hung on live hosts after forced nspawn termination.
if command -v timeout >/dev/null 2>&1; then
    timeout 5 sh -c 'ip link delete "$1" 2>/dev/null || true' sh ve-htch-runtime || true
fi
emit_mount_stop_lifecycle_event runtime_cell_post_stop completed "$(date +%s%3N)"
