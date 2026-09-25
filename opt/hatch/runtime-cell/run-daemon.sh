#!/bin/sh
set -eu

ready_file="/run/hatch/runtime-cell/runtime-cell.ready"

# control-daemon.sh already gates readiness host-side: it waits for the
# ready_file (and the cell Leader) and exits before nsenter if either is
# missing. This script runs after nsenter, inside the runtime-cell mount
# namespace, where the host-side ready marker is not always visible (the
# host-created file can lag propagation into the cell's mount namespace,
# especially right after a cell restart). Treat its absence here as a
# non-fatal diagnostic rather than exiting: a hard exit makes systemd restart
# the daemon in a tight loop until StartLimitBurst is exhausted ("Start request
# repeated too quickly") and the daemon never comes up, even though the cell is
# actually ready.
if [ ! -f "$ready_file" ]; then
    echo "note: run-daemon.sh: ready_file not visible inside cell namespace ($ready_file); control-daemon.sh already confirmed readiness host-side" >&2
fi

. "/opt/hatch/runtime-cell/guest-runtime-env.sh"

# RT-3: the daemon-lifecycle-env.sh sourcing block is deleted outright. This
# script runs INSIDE the cell mount namespace, where any same-named file is
# cell-authored by definition; lifecycle env now arrives as plain environment
# variables from the root invoker (control-daemon.sh's allowlisted exports).

# control-daemon.sh reaches this point after entering the runtime-cell user
# namespace. Drop PTRACE here so the daemon, hatch-execd, and their tool
# children cannot attach to or read arbitrary peer processes in the cell.
exec /usr/bin/setpriv \
    --bounding-set=-sys_ptrace \
    --inh-caps=-sys_ptrace \
    --ambient-caps=-sys_ptrace \
    -- "/opt/hatch/bin/hatch" daemon
