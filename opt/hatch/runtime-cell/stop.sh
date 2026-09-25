#!/bin/sh
set -eu

machine=htch-runtime
ready_file=/run/hatch/runtime-cell/runtime-cell.ready
draining_file=/run/hatch/ingress/runtime-cell-draining
keep_services_down_file=/var/lib/hatch-dev-controls/keep-services-down
handoff_dir="/run/hatch/runtime-cell"
machine_state_file="/run/systemd/machines/$machine"
machine_unit_link="/run/systemd/machines/unit:com.hatch.runtime-cell.service"
machine_propagate_dir="/run/systemd/nspawn/propagate/$machine"
daemon_ctl_dir="/run/hatch/daemon-ctl"
postgres_unit="postgresql@18-hatch.service"
clean_stop_proof_unit="com.hatch.clean-stop-proof.service"
rv_target_unit="hatch-rv.target"
# These phases share the runtime-cell unit's 20-second stop budget. Give the
# guest five seconds to power off before bounded terminate and kill fallbacks.
graceful_poweroff_budget_ms="${runtime_cell_stop_poweroff_budget_ms:-5000}"
postgres_stopped_grace_ms="${runtime_cell_stop_postgres_grace_ms:-1000}"
database_check_interval_ms="${runtime_cell_stop_database_check_interval_ms:-500}"
terminate_budget_ms="${runtime_cell_stop_terminate_budget_ms:-1000}"
kill_budget_ms="${runtime_cell_stop_kill_budget_ms:-500}"
spawnd_bin="/opt/hatch/bin/spawnd"
machinectl_request_pid=""
database_stop_shortcut_armed=0
database_was_clean=0

# The daemon unit calls the publish-only mode before systemd sends SIGTERM, so
# reconnects triggered by service.notice are fenced before that notice is
# enqueued. A full runtime-cell stop republishes the marker as defense in depth.
# This lives on host tmpfs outside the runtime cell, so the draining cell cannot
# forge or clear it and ingress keeps seeing it after the cell exits. An
# operator brake deliberately keeps the cell down while retaining recovery
# access, so it must suppress and clear this short-lived replacement fence.
if [ -e "$keep_services_down_file" ]; then
    rm -f "$draining_file"
else
    install -d -m 0755 -o root -g root "$(dirname "$draining_file")"
    install -m 0444 -o root -g root /dev/null "$draining_file"
fi

if [ "${1:-}" = "--publish-drain-fence-only" ]; then
    exit 0
fi
if [ "$#" -ne 0 ]; then
    echo "usage: $0 [--publish-drain-fence-only]" >&2
    exit 2
fi

log_stop() {
    echo "runtime-cell stop: $*" >&2
}

emit_mount_stop_lifecycle_event() {
    phase="$1"
    event="$2"
    timestamp_ms="$3"
    status="${4:-}"
    if [ -n "$status" ]; then
        "$spawnd_bin" emit-mount-stop-lifecycle \
            --phase "$phase" \
            --event "$event" \
            --timestamp-ms "$timestamp_ms" \
            --status "$status" || true
    else
        "$spawnd_bin" emit-mount-stop-lifecycle \
            --phase "$phase" \
            --event "$event" \
            --timestamp-ms "$timestamp_ms" || true
    fi
}

emit_daemon_lifecycle_event() {
    "$spawnd_bin" emit-daemon-lifecycle --phase "$1" || true
}

read_machine_leader() {
    machine_leader="$(machinectl show "$machine" -p Leader --value 2>/dev/null)"
}

machine_leader_is_live() {
    [ -n "$machine_leader" ] && [ "$machine_leader" != "0" ] \
        && kill -0 "$machine_leader" >/dev/null 2>&1
}

# machinectl poweroff/terminate wait for the machine operation to finish. Run
# each request beside the phase poll so a wedged client cannot hide the next
# escalation until systemd's outer TimeoutStopSec kills the whole unit.
start_machinectl_request() {
    machinectl "$@" 2>/dev/null &
    machinectl_request_pid=$!
}

finish_machinectl_request() {
    if [ -z "$machinectl_request_pid" ]; then
        return
    fi
    if kill -0 "$machinectl_request_pid" >/dev/null 2>&1; then
        # This kills only the local machinectl client. The machine1 request was
        # already dispatched and the phase poll observed its durable effect.
        kill -KILL "$machinectl_request_pid" >/dev/null 2>&1 || true
    fi
    wait "$machinectl_request_pid" 2>/dev/null || true
    machinectl_request_pid=""
}

trap finish_machinectl_request EXIT

clear_stale_machine_state() {
    if command -v busctl >/dev/null 2>&1; then
        busctl call \
            org.freedesktop.machine1 \
            /org/freedesktop/machine1 \
            org.freedesktop.machine1.Manager \
            UnregisterMachine s "$machine" >/dev/null 2>&1 || true
    fi
    rm -f "$machine_state_file" "$machine_unit_link" || true
    rm -rf "$machine_propagate_dir" || true
}

wait_for_machine_gone_until() {
    deadline_ms="$1"
    while [ "$(date +%s%3N)" -lt "$deadline_ms" ]; do
        if ! read_machine_leader; then
            return 0
        fi
        if ! machine_leader_is_live; then
            clear_stale_machine_state
            if ! read_machine_leader; then
                return 0
            fi
        fi
        sleep 0.1
    done
    return 1
}

unit_active_state() {
    unit="$1"
    systemctl show "$unit" --property=ActiveState --value 2>/dev/null || true
}

unit_monotonic_timestamp() {
    unit="$1"
    property="$2"
    value="$(systemctl show "$unit" --property="$property" --value 2>/dev/null || true)"
    case "$value" in
        ''|*[!0-9]*) printf '0\n' ;;
        *) printf '%s\n' "$value" ;;
    esac
}

unit_is_running_or_stopping() {
    state="$(unit_active_state "$1")"
    case "$state" in
        active|activating|reloading|deactivating) return 0 ;;
        *) return 1 ;;
    esac
}

unit_is_inactive() {
    [ "$(unit_active_state "$1")" = "inactive" ]
}

unit_was_active_in_current_cell() {
    unit_exit_us="$(unit_monotonic_timestamp "$1" ActiveExitTimestampMonotonic)"
    [ "$runtime_cell_active_enter_us" -gt 0 ] \
        && [ "$unit_exit_us" -ge "$runtime_cell_active_enter_us" ]
}

unit_is_current_or_running() {
    unit_is_running_or_stopping "$1" \
        || { unit_is_inactive "$1" && unit_was_active_in_current_cell "$1"; }
}

arm_database_stop_shortcut() {
    if [ "$database_stop_shortcut_armed" -eq 1 ]; then
        return
    fi
    if unit_is_running_or_stopping "$postgres_unit" \
        && unit_is_running_or_stopping "$clean_stop_proof_unit"; then
        database_stop_shortcut_armed=1
        return
    fi

    # RV members stop concurrently, so either unit may already be inactive by
    # the time this ExecStop gets CPU. Fence inactive timestamps to both the
    # current runtime-cell activation and a target stop from that activation;
    # a pre-RV cell or a timestamp left by the previous cell cannot arm this.
    rv_target_exit_us="$(unit_monotonic_timestamp "$rv_target_unit" ActiveExitTimestampMonotonic)"
    if [ "$runtime_cell_active_enter_us" -gt 0 ] \
        && [ "$rv_target_exit_us" -ge "$runtime_cell_active_enter_us" ] \
        && unit_is_current_or_running "$postgres_unit" \
        && unit_is_current_or_running "$clean_stop_proof_unit"; then
        database_stop_shortcut_armed=1
    fi
}

database_stop_is_complete() {
    # The proof unit is ordered after PostgreSQL on stop. Requiring both states
    # means the daemon has exited, PostgreSQL has stopped, and the proof writer
    # has finished syncing the RV before we terminate a wedged guest shutdown.
    [ "$database_stop_shortcut_armed" -eq 1 ] \
        && unit_is_inactive "$postgres_unit" \
        && unit_is_inactive "$clean_stop_proof_unit"
}

wait_for_graceful_machine_stop() {
    deadline_ms="$1"
    next_database_check_ms="$(date +%s%3N)"
    database_stopped_at_ms=""
    while [ "$(date +%s%3N)" -lt "$deadline_ms" ]; do
        if ! read_machine_leader; then
            return 0
        fi
        if ! machine_leader_is_live; then
            clear_stale_machine_state
            if ! read_machine_leader; then
                return 0
            fi
        fi
        now_ms="$(date +%s%3N)"
        if [ "$now_ms" -ge "$next_database_check_ms" ]; then
            arm_database_stop_shortcut
            if database_stop_is_complete; then
                if [ -z "$database_stopped_at_ms" ]; then
                    database_stopped_at_ms="$now_ms"
                elif [ $((now_ms - database_stopped_at_ms)) -ge "$postgres_stopped_grace_ms" ]; then
                    return 2
                fi
            else
                database_stopped_at_ms=""
            fi
            next_database_check_ms=$((now_ms + database_check_interval_ms))
        fi
        sleep 0.1
    done
    return 1
}

attempt_machine_terminate() {
    log_stop "sending terminate to machine=$machine"
    deadline_ms=$(( $(date +%s%3N) + terminate_budget_ms ))
    start_machinectl_request terminate "$machine"
    if wait_for_machine_gone_until "$deadline_ms"; then
        finish_machinectl_request
        return 0
    fi
    finish_machinectl_request
    return 1
}

attempt_machine_kill() {
    log_stop "sending kill to machine=$machine"
    deadline_ms=$(( $(date +%s%3N) + kill_budget_ms ))
    start_machinectl_request kill --signal=KILL --kill-whom=all "$machine"
    if wait_for_machine_gone_until "$deadline_ms"; then
        finish_machinectl_request
        return 0
    fi
    finish_machinectl_request
    return 1
}

fast_cleanup_machine() {
    reason="$1"
    log_stop "skipping graceful poweroff: machine=$machine reason=$reason"
    clear_stale_machine_state
    if attempt_machine_terminate; then
        return 0
    fi
    if attempt_machine_kill; then
        return 0
    fi
    log_stop "machine still registered after forced cleanup; clearing stale state before retry: machine=$machine"
    clear_stale_machine_state
    wait_for_machine_gone_until "$(( $(date +%s%3N) + 100 ))" || true
    return 0
}

emit_daemon_lifecycle_event stop-observed

rm -f "$ready_file"
# RT-3: lifecycle handoff files live in root-owned /run/hatch/daemon-ctl now;
# /run/hatch/daemon is the daemon SOCKET dir only and holds nothing to clean.
rm -f \
    "$handoff_dir/shellworks-daemon-lifecycle-context.json" \
    "$handoff_dir/shellworks-daemon-lifecycle-identity.json" \
    "$handoff_dir/shellworks-wake-bootstrap-context.json" \
    "$handoff_dir/jarvis-runtime-cell-bootstrap-identity.json" \
    "$daemon_ctl_dir/runtime-cell-pre-start-started-at-ms" \
    "$daemon_ctl_dir/post-hatch-mount-boundaries.json" \
    "$daemon_ctl_dir/db-preflight-failed-before-daemon-start-at-ms"
rm -rf "$daemon_ctl_dir/env"
rm -rf "$handoff_dir/runtime-cell-bootstrap-events"
# The sanitized lifecycle projection is gone, so revoke rv-graft's temporary
# mapped-cell group traversal grant even when this directory is a persistent bind path.
# A missing/non-directory path has no grant to revoke and must not abort the
# machine shutdown escalation below.
if [ -d "$handoff_dir" ] && [ ! -L "$handoff_dir" ]; then
    chown root:root "$handoff_dir"
    chmod 0750 "$handoff_dir"
fi

emit_mount_stop_lifecycle_event runtime_cell_stop started "$(date +%s%3N)"

if ! read_machine_leader; then
    fast_cleanup_machine "machine_missing_or_unregistered"
    emit_mount_stop_lifecycle_event runtime_cell_stop completed "$(date +%s%3N)" machine_missing_or_unregistered
    exit 0
fi

if ! machine_leader_is_live; then
    fast_cleanup_machine "machine_leader_missing_or_dead"
    emit_mount_stop_lifecycle_event runtime_cell_stop completed "$(date +%s%3N)" machine_leader_missing_or_dead
    exit 0
fi

log_stop "requesting graceful poweroff: machine=$machine timeout_ms=$graceful_poweroff_budget_ms"
runtime_cell_active_enter_us="$(unit_monotonic_timestamp "com.hatch.runtime-cell.service" ActiveEnterTimestampMonotonic)"
arm_database_stop_shortcut
graceful_deadline_ms=$(( $(date +%s%3N) + graceful_poweroff_budget_ms ))
start_machinectl_request poweroff "$machine"
if wait_for_graceful_machine_stop "$graceful_deadline_ms"; then
    finish_machinectl_request
    emit_mount_stop_lifecycle_event runtime_cell_stop completed "$(date +%s%3N)" clean
    exit 0
else
    graceful_result=$?
fi
finish_machinectl_request

if [ "$graceful_result" -eq 2 ]; then
    database_was_clean=1
    log_stop "PostgreSQL clean stop completed but guest remains; escalating to terminate: machine=$machine"
else
    log_stop "graceful poweroff timed out; escalating to terminate: machine=$machine"
fi
if attempt_machine_terminate; then
    terminate_status=terminated
    if [ "$database_was_clean" -eq 1 ]; then
        terminate_status=terminated_after_clean_db
    fi
    emit_mount_stop_lifecycle_event runtime_cell_stop completed "$(date +%s%3N)" "$terminate_status"
    exit 0
fi

log_stop "terminate timed out; escalating to kill: machine=$machine"
if attempt_machine_kill; then
    kill_status=killed
    if [ "$database_was_clean" -eq 1 ]; then
        kill_status=killed_after_clean_db
    fi
    emit_mount_stop_lifecycle_event runtime_cell_stop completed "$(date +%s%3N)" "$kill_status"
    exit 0
fi

log_stop "machine still registered after kill; clearing stale state before retry: machine=$machine"
clear_stale_machine_state
emit_mount_stop_lifecycle_event runtime_cell_stop completed "$(date +%s%3N)" stale_cleanup
exit 0
