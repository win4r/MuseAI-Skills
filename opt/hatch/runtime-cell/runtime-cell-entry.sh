#!/bin/sh
# runtime-cell-entry.sh — shared helpers for entering the Hatch runtime cell from
# the host. Source this file; it defines functions and does not exec on its own.
#
# Installed root-owned at /opt/hatch/runtime-cell/runtime-cell-entry.sh and rendered
# by spawnd (RUNTIME_CELL_SCRIPTS), so the only template var is the render-time
# htch-runtime; every other ${...} would be flagged as an unresolved
# template var, so runtime shell variables use the unbraced "$var" form.

# Resolve the runtime cell's nspawn leader PID (the cell's PID 1). Echoes the PID
# on success; prints an error and returns 1 if the cell is not running.
rce_runtime_cell_leader() {
    _leader="$(
        /usr/bin/machinectl show "htch-runtime" -p Leader --value 2>/dev/null || true
    )"
    if [ -z "$_leader" ] || [ "$_leader" = "0" ]; then
        echo "runtime cell 'htch-runtime' is not running" >&2
        return 1
    fi
    printf '%s\n' "$_leader"
}

# Wait for the runtime cell to become ready and resolve its leader PID, for the
# host-side launchers (control-daemon.sh, control-execd.sh) that start before the
# cell is up. The ready file signals network readiness; machinectl confirms the
# machine is registered and yields the leader PID for namespace entry. Polls for
# ~20s (200 * 0.1s). Echoes the leader PID on success; prints an error and
# returns 1 if the cell never became ready.
rce_wait_for_ready_leader() {
    _ready_file="/run/hatch/runtime-cell/runtime-cell.ready"
    _leader=
    for _i in $(seq 1 200); do
        if [ -f "$_ready_file" ]; then
            _leader="$(
                /usr/bin/machinectl show "htch-runtime" -p Leader --value 2>/dev/null || true
            )"
            if [ -n "$_leader" ]; then
                break
            fi
        fi
        sleep 0.1
    done
    if [ ! -f "$_ready_file" ] || [ -z "$_leader" ]; then
        echo "runtime-cell did not become ready" >&2
        return 1
    fi
    printf '%s\n' "$_leader"
}

# Export the trusted cell runtime env (egress proxy + TLS CA bundle) from the
# host-rendered, root-owned guest.env so the host-side launchers' subprocesses
# get Sentinel-routed egress and TLS verification. Use guest.env, NOT the
# cell-writable guest-runtime-env.sh, which these privileged launchers must not
# trust. set -a so every assignment in guest.env is exported into the launched
# process; missing file is tolerated (best-effort).
rce_source_guest_env() {
    set -a
    if [ -r "/opt/hatch/runtime-cell/guest.env" ]; then
        . "/opt/hatch/runtime-cell/guest.env"
    fi
    set +a
}

# Join the runtime cell's cgroup so authd authenticates the caller as an in-cell
# tool. authd gates credential requests on SO_PEERCRED uid + the caller's cgroup
# unit; a caller left in its login-session cgroup is rejected and is not treated
# as a cell caller. Entering namespaces does not change cgroup membership, so the
# join is explicit. The cell cgroup is the leader's own cgroup, resolved from
# /proc/<leader>/cgroup (cgroup v2: "0::/path"; the path is the 3rd colon-field),
# exactly as execd's join_cell_cgroup_and_enter_namespaces does. Must run in the
# process that will exec nsenter (it writes $$), before namespace entry.
rce_join_cell_cgroup() {
    _leader="$1"
    _rel="$(cut -d: -f3- < "/proc/$_leader/cgroup" | head -n1)"
    if [ -z "$_rel" ]; then
        echo "could not resolve runtime cell cgroup for leader $_leader" >&2
        return 1
    fi
    _procs="/sys/fs/cgroup$_rel/cgroup.procs"
    if [ ! -f "$_procs" ]; then
        echo "runtime cell cgroup.procs not found: $_procs" >&2
        return 1
    fi
    echo $$ > "$_procs"
}

# Enter ALL of the cell's namespaces (nsenter handles user-namespace ordering)
# and become guest root via setpriv, then exec the given command. Replaces the
# current process.
#
# --all enters every namespace of the leader, crucially including the cgroup
# namespace that execd's tool launch enters (hatch_os::namespace::
# join_cell_cgroup_and_enter_namespaces: Mount/Uts/Ipc/Net/Cgroup/User). The
# prior explicit list omitted the cgroup namespace, so the reproduction was not
# faithful. Note this is only the namespace *view*; the cgroup membership *join*
# (rce_join_cell_cgroup, what authd authenticates on) is separate and remains
# the caller's choice — enter-tool-environment joins, sandbox-shell does not.
rce_enter_guest_root() {
    _leader="$1"
    shift
    # --preserve-credentials must never cross the cell boundary: nsenter
    # execvp()s its argv out of the CELL rootfs after setns — a tree cell
    # root owns — so host-credentialed execution there is host-root execution
    # of a cell-owned binary (mirrors hatch-rescue-enter-runtime.sh's guard).
    case "$*" in
        *--preserve-credentials*)
            echo "refusing: --preserve-credentials must never cross the cell boundary" >&2
            return 1
            ;;
    esac
    # --all includes --user: joining the guest USER namespace is the
    # load-bearing privilege drop before the cell-rootfs exec below.
    exec /usr/bin/nsenter \
        --target "$_leader" \
        --all \
        -- setpriv --reuid=0 --regid=0 --clear-groups -- "$@"
}
