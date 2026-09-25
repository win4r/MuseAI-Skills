#!/bin/sh
set -eu

# Blacklist modules that are not needed and expand kernel attack surface.
# "install <mod> /bin/false" is stronger than "blacklist": it prevents both
# autoloading and explicit modprobe.
cat > /etc/modprobe.d/hatch-blacklist.conf <<'BLACKLIST'
# AF_ALG crypto userspace socket interface — no legitimate use on Hatch VMs,
# historically exploited (e.g. algif_aead in CVE-2023-21400 / copy.fail).
install algif_aead /bin/false
install algif_hash /bin/false
install algif_skcipher /bin/false
install algif_rng /bin/false
install af_alg /bin/false
# No IPsec or AFS/Kerberos transport.
install esp4 /bin/false
install esp6 /bin/false
install rxrpc /bin/false
BLACKLIST

# Pre-load kernel modules required by the runtime cell that will not
# be implicitly loaded by the front half of the ensure-rootfs.sh script.
runtime_cell_run_dir=/run/hatch/runtime-cell
modules_ready_file="$runtime_cell_run_dir/modules-preloaded-ok"
browser_cell_run_dir=/run/hatch/browser-cell
browser_cell_nat_modules_ready_file="$browser_cell_run_dir/nat-modules-preloaded-ok"
mkdir -p "$runtime_cell_run_dir"
mkdir -p "$browser_cell_run_dir"
rm -f "$modules_ready_file"
rm -f "$browser_cell_nat_modules_ready_file"
runtime_modules_failed=0
browser_modules_failed=0

require_runtime_module() {
    # Succeeds if already loaded or compiled in.
    if ! modprobe "$1" 2>/dev/null; then
        echo "runtime-cell module preload failed: $1" >&2
        runtime_modules_failed=1
    fi
}

require_browser_module() {
    # Succeeds if already loaded or compiled in.
    if ! modprobe "$1" 2>/dev/null; then
        echo "browser-cell NAT module preload failed: $1" >&2
        browser_modules_failed=1
    fi
}

require_runtime_module veth
require_runtime_module btrfs

# The co-located browser cell installs an explicit nft masquerade rule on its
# veth. The runtime-cell post-start script disables future module loading, so
# preload the NAT backends nft needs before that one-way lock when the HBI rootfs
# is present. The dev force marker lives under /var/lib/hatch, which may not be
# mounted yet when this early boot service runs.
if grep -qw 'jarvis_cvm=true' /proc/cmdline 2>/dev/null || [ -e /var/lib/hatch-browser/rootfs-base/usr/local/bin/entrypoint.sh ]; then
    require_browser_module nf_tables
    require_browser_module nf_conntrack
    require_browser_module nf_nat
    require_browser_module nft_chain_nat
    require_browser_module nft_nat
    require_browser_module nft_masq

    if [ "$browser_modules_failed" -eq 0 ]; then
        touch "$browser_cell_nat_modules_ready_file"
    else
        echo "browser-cell NAT module preload incomplete; browser cell will stay disabled for this boot" >&2
    fi
fi

if [ "$runtime_modules_failed" -eq 0 ]; then
    touch "$modules_ready_file"
else
    echo "runtime-cell module preload incomplete; leaving module loading enabled" >&2
fi
