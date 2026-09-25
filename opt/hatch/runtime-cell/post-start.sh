#!/bin/sh
set -eu

machine=htch-runtime
veth=ve-htch-runtime
gateway_ip=198.19.0.1
gateway_cidr=198.19.0.1/30
gateway_ipv6=fd8b:4f84:7d32:99::1
gateway_ipv6_cidr=fd8b:4f84:7d32:99::1/64
address_cidr=198.19.0.2/30
address_ipv6_cidr=fd8b:4f84:7d32:99::2/64
ready_file=/run/hatch/runtime-cell/runtime-cell.ready
post_start_started_at_ms="$(date +%s%3N)"
post_start_failure_reason=""
ready_failure_reason="ready_marker_write_failed"

queue_runtime_cell_bootstrap_phase() {
    phase_name="$1"
    phase_status="$2"
    phase_started_at_ms="$3"
    phase_completed_at_ms="$4"
    phase_failure_reason="${5:-}"
    set -- \
        "/opt/hatch/bin/spawnd" queue-runtime-cell-bootstrap \
        --jarvis-home "/home/hatch" \
        --phase "$phase_name" \
        --status "$phase_status" \
        --started-at-ms "$phase_started_at_ms" \
        --completed-at-ms "$phase_completed_at_ms"
    if [ -n "$phase_failure_reason" ]; then
        set -- "$@" --failure-reason "$phase_failure_reason"
    fi
    "$@" || true
}

log_post_start() {
    echo "runtime-cell post-start: $*" >&2
}

queue_post_start_failure() {
    exit_status="$1"
    if [ "$exit_status" -ne 0 ]; then
        completed_at_ms="$(date +%s%3N)"
        queue_runtime_cell_bootstrap_phase \
            runtime_cell_post_start_network \
            failure \
            "$post_start_started_at_ms" \
            "$completed_at_ms" \
            "${post_start_failure_reason:-post_start_failed}"
    fi
    exit "$exit_status"
}

queue_ready_failure() {
    exit_status="$1"
    if [ "$exit_status" -ne 0 ]; then
        completed_at_ms="$(date +%s%3N)"
        queue_runtime_cell_bootstrap_phase \
            runtime_cell_ready \
            failure \
            "$ready_started_at_ms" \
            "$completed_at_ms" \
            "${ready_failure_reason:-ready_marker_write_failed}"
    fi
    exit "$exit_status"
}

wait_for_runtime_cell_leader() {
    attempts="$1"
    last_reason=""
    for i in $(seq 1 "$attempts"); do
        leader="$(machinectl show "$machine" -p Leader --value 2>/dev/null || true)"
        if ! machinectl show "$machine" >/dev/null 2>&1; then
            reason="machine_not_registered_yet"
        elif [ -z "$leader" ] || [ "$leader" = "0" ]; then
            reason="machine_leader_missing"
        elif ! nsenter --target "$leader" --net -- true >/dev/null 2>&1; then
            reason="machine_leader_not_enterable"
        else
            log_post_start "leader became available: machine=$machine leader=$leader"
            RUNTIME_CELL_LEADER="$leader"
            export RUNTIME_CELL_LEADER
            return 0
        fi
        if [ "$reason" != "$last_reason" ]; then
            log_post_start "waiting for leader: machine=$machine reason=$reason"
            last_reason="$reason"
        fi
        sleep "$post_start_retry_sleep_secs"
    done
    post_start_failure_reason="$last_reason"
    log_post_start "leader wait exhausted: machine=$machine reason=$post_start_failure_reason"
    return 1
}

wait_for_guest_host0() {
    attempts="$1"
    last_reason=""
    for i in $(seq 1 "$attempts"); do
        if nsenter --target "$RUNTIME_CELL_LEADER" --net -- ip link show host0 >/dev/null 2>&1; then
            log_post_start "guest host0 became visible: machine=$machine leader=$RUNTIME_CELL_LEADER"
            return 0
        fi
        reason="guest_host0_missing"
        if [ "$reason" != "$last_reason" ]; then
            log_post_start "waiting for guest network: machine=$machine reason=$reason"
            last_reason="$reason"
        fi
        sleep "$post_start_retry_sleep_secs"
    done
    post_start_failure_reason="$last_reason"
    log_post_start "guest network wait exhausted: machine=$machine reason=$post_start_failure_reason"
    return 1
}

trap 'queue_post_start_failure $?' EXIT

if [ -f "/etc/hatch/env" ]; then
    . "/etc/hatch/env"
fi
if [ -f "/etc/hatch/env.override" ]; then
    . "/etc/hatch/env.override"
fi

post_start_retry_attempts="${runtime_cell_post_start_retry_attempts:-100}"
post_start_retry_sleep_secs="${runtime_cell_post_start_retry_sleep_secs:-0.1}"
log_post_start "begin machine=$machine veth=$veth"

for i in $(seq 1 100); do
    if ip link show "$veth" >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done

if ! ip link show "$veth" >/dev/null 2>&1; then
    echo "runtime-cell veth did not appear: $veth" >&2
    exit 1
fi

log_post_start "host veth visible: veth=$veth"
ip addr replace "$gateway_cidr" dev "$veth"
ip -6 addr replace "$gateway_ipv6_cidr" dev "$veth"
ip link set "$veth" up

# RT-19: attach the spawnd-owned tc ingress classifier on the HOST side of
# the cell veth — the layer that still stands if in-cell root evades the
# cgroup hooks (raw sockets, nested netns). The veth (and its qdisc) is
# recreated per cell start, so this attaches fresh every time; the subcommand
# is replace-idempotent on its fixed tc handle/priority. Fatal on failure for
# the same reason as attach-cell-gate in pre-start.sh: an unfiltered veth is
# the posture this wave removes.
# Name the failing step in the runtime_cell_post_start_network failure row
# instead of the generic post_start_failed fallback.
post_start_failure_reason="veth_filter_attach_failed"
"/opt/hatch/bin/spawnd" attach-veth-filter \
    --veth "$veth" \
    --gateway-ip "$gateway_ip" \
    --gateway-ip6 "$gateway_ipv6"
post_start_failure_reason=""

wait_for_runtime_cell_leader "$post_start_retry_attempts"
wait_for_guest_host0 "$post_start_retry_attempts"

# Configure the guest host0 addressing/routes in its network namespace only
# (--net, NOT --mount). /etc/resolv.conf and /etc/hosts (egress-proxy aliases +
# the machine-name loopback entries) are static files under
# /opt/hatch/runtime-cell/etc, bind-mounted read-only into the cell by
# htch-runtime.nspawn, so we never enter the cell's mount namespace here.
# Dropping --mount removes the wait on the nspawn root-pivot/PID1 from the boot
# critical path. The cell addressing is static, so these files are correct every
# boot.
nsenter --target "$RUNTIME_CELL_LEADER" --net -- sh -ceu '
ip addr replace "$1" dev host0 2>/dev/null || true
ip -6 addr replace "$2" dev host0 2>/dev/null || true
ip link set host0 up
ip route replace default via "$3"
ip -6 route replace default via "$4"
' sh "$address_cidr" "$address_ipv6_cidr" "$gateway_ip" "$gateway_ipv6"

trap - EXIT
post_start_completed_at_ms="$(date +%s%3N)"
log_post_start "guest network configured: machine=$machine"
queue_runtime_cell_bootstrap_phase \
    runtime_cell_post_start_network \
    success \
    "$post_start_started_at_ms" \
    "$post_start_completed_at_ms"

# runtime-cell.ready now means the guest network is configured and the daemon
# may start; CA/NSS trust convergence remains asynchronous in its own systemd
# unit and is not part of readiness.
ready_started_at_ms="$(date +%s%3N)"
trap 'queue_ready_failure $?' EXIT
# The ready marker is read by host-side controllers and in-cell scripts running
# through nspawn's user namespace. Keep the directory traversable; sensitive
# handoff payloads are protected elsewhere by file/subdir permissions.
log_post_start "writing ready marker: path=$ready_file"
install -d -m 0755 -o root -g root "$(dirname "$ready_file")"
touch "$ready_file"
ready_completed_at_ms="$(date +%s%3N)"
log_post_start "ready marker written: path=$ready_file"
queue_runtime_cell_bootstrap_phase \
    runtime_cell_ready \
    success \
    "$ready_started_at_ms" \
    "$ready_completed_at_ms"
trap - EXIT

# All kernel modules required by the runtime cell and container networking
# must be proven loaded by require-modules.sh before we disable future module
# loading. If preload was incomplete, keep module loading enabled so a
# transient or kernel-version mismatch does not become a permanent boot-time
# lockout. This is a one-way operation; only a reboot resets it.
if [ -f /run/hatch/runtime-cell/modules-preloaded-ok ] && [ -w /proc/sys/kernel/modules_disabled ]; then
    echo 1 > /proc/sys/kernel/modules_disabled
fi
