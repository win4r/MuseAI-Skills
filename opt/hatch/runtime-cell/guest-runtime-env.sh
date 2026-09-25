#!/bin/sh

# guest-runtime-env.sh — shared runtime environment exports for runtime-cell
# entrypoints on both the host and guest side. Source this file; it only
# computes environment and does not exec.

runtime_cell_proxy_host=hatch-egress-proxy
no_proxy_hosts="localhost,127.0.0.1,::1,[::1],198.19.0.1,198.19.0.2,fd8b:4f84:7d32:99::1,[fd8b:4f84:7d32:99::1],fd8b:4f84:7d32:99::2,[fd8b:4f84:7d32:99::2]"

env_value_or_empty() {
    printenv "$1" 2>/dev/null || true
}

umask 0007

# control-daemon.sh applies the host env files before nsenter. Preserve this
# inherited value because the guest copy of /etc/hatch/env contains the generated
# default and would otherwise erase a host-side socket override before the
# daemon starts.
inherited_sandbox_api_sock="$(env_value_or_empty JARVIS_SANDBOX_API_SOCK)"

if [ -r "/etc/hatch/env" ]; then
    . "/etc/hatch/env"
fi
if [ -r "/etc/hatch/env.override" ]; then
    . "/etc/hatch/env.override"
fi

if [ -n "$inherited_sandbox_api_sock" ]; then
    JARVIS_SANDBOX_API_SOCK="$inherited_sandbox_api_sock"
fi
if [ -n "${JARVIS_SANDBOX_API_SOCK:-}" ]; then
    export JARVIS_SANDBOX_API_SOCK
fi

export JARVIS_HOME="/home/hatch"
export JARVIS_BIN_DIR="/opt/hatch/bin"
export JARVIS_AUTHD_SOCK="/run/hatch/auth/authd.sock"
export JARVIS_STEFI_PROXY_SOCK="/run/hatch/proxy/stefi.sock"
export HOME="/home/hatch"
export TMPDIR="/var/tmp"
export TMP="/var/tmp"
export TEMP="/var/tmp"
export XDG_CONFIG_HOME="/home/hatch/.config"
export XDG_CACHE_HOME="/home/hatch/.cache"
export XDG_STATE_HOME="/home/hatch/.local/state"
export HTTP_PROXY="http://$runtime_cell_proxy_host:3128"
export HTTPS_PROXY="http://$runtime_cell_proxy_host:3128"
export ALL_PROXY="http://$runtime_cell_proxy_host:3128"
export NO_PROXY="$no_proxy_hosts"
export http_proxy="http://$runtime_cell_proxy_host:3128"
export https_proxy="http://$runtime_cell_proxy_host:3128"
export all_proxy="http://$runtime_cell_proxy_host:3128"
export no_proxy="$NO_PROXY"
export SSL_CERT_FILE="/run/hatch/egress-tls/ca-bundle.pem"
export REQUESTS_CA_BUNDLE="/run/hatch/egress-tls/ca-bundle.pem"
export CURL_CA_BUNDLE="/run/hatch/egress-tls/ca-bundle.pem"
export WGETRC="/opt/hatch/runtime-cell/etc/wgetrc"
export AWS_CA_BUNDLE="/run/hatch/egress-tls/ca-bundle.pem"
export NODE_EXTRA_CA_CERTS="/run/hatch/egress-tls/ca-bundle.pem"
# Parity with guest.env: make Node's built-in fetch honor the proxy env.
export NODE_USE_ENV_PROXY=1
export GIT_SSL_CAINFO="/run/hatch/egress-tls/ca-bundle.pem"
if [ -z "$PATH" ]; then
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fi
export PATH="/opt/hatch/bin:/opt/hatch-image/bin:$PATH"
