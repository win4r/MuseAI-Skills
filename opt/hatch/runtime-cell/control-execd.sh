#!/bin/sh
set -eu

# Shared runtime-cell launcher helpers (guest.env sourcing, ready/leader wait).
. "/opt/hatch/runtime-cell/runtime-cell-entry.sh"

# Export the trusted cell runtime env (egress proxy + TLS CA bundle) from the
# host-rendered, root-owned guest.env so execd's tool subprocesses get
# Sentinel-routed egress and TLS verification. Use guest.env (NOT the
# cell-writable guest-runtime-env.sh, which this privileged launcher must not
# trust). The host env (/etc/hatch/env) and ops override (/etc/hatch/env.override)
# are already loaded by the unit's EnvironmentFile= directives, so we do not
# re-source them here; and host overrides do not apply to execd, which
# immediately enters the runtime cell — the guest env is what governs in-cell
# execution.
rce_source_guest_env

# Wait for the runtime cell to be ready and resolve its leader PID.
leader="$(rce_wait_for_ready_leader)" || exit 1

# Keep the systemd LISTEN_* socket-activation env: hatch-execd consumes the
# activation fd via the sd_listen_fds protocol (and rewrites LISTEN_PID in its
# post-fork in-cell child). It enters the runtime-cell namespaces directly (no
# nsenter wrapper, no ptrace/seccomp supervisor — that is daemon-owned). The
# host-side parent (anchor) stays in this execd.service cgroup as systemd's
# MainPID; only the in-cell child joins the runtime-cell cgroup and runs the
# server. See hatch_os::namespace::enter_runtime_cell_unsupervised.
exec /opt/hatch/bin/hatch-execd \
    --runtime-cell-leader="$leader"
