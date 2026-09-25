#!/bin/sh
# Resolve the runtime-cell rootfs path at runtime.
#
# The cell ALWAYS boots from the image-local, digest-keyed base tree —
# /var/lib/hatch-runtime/rootfs, a btrfs snapshot of
# /var/lib/hatch-runtime/rootfs-base kept fresh by ensure-rootfs.sh against
# /opt/hatch-image/cell-base.digest — on RV hosts and eval/dev/standalone hosts
# alike. The retired serving-tree-on-RV mode (/hatch/runtime-cell/rootfs) is
# deliberately left untouched on disk for rollback/forensics (the hatch-image
# one-time converter classifies it into the /var/lib/hatch/os-intent ledger)
# but is never resolved here. Per-VM OS packages replay from that ledger via
# hatch-preflight-opportunistic instead of riding a persistent rootfs.
# `spawnd install` asserts the image-side contract
# (/opt/hatch-image/contracts/resume-architecture.v1 + cell-base.digest), so
# this script carries no old-image fallback.
#
# Usage: resolve-rootfs-path.sh <default-rootfs-path>
# Output: resolved rootfs path on stdout -- and NOTHING ELSE, EVER.
#
# All three callers capture this script with $(...) : pre-start.sh,
# launch-daemon.sh and ensure-rootfs.sh. Every byte written to stdout here,
# including by anything this script runs without redirecting, is concatenated
# into the path they then use. There is no validation downstream to catch it;
# the cell would simply be started against a garbage rootfs path.
# Diagnostics go to stderr.
set -eu

# The rendered default is retained for caller compatibility; resolution does
# not depend on it (it renders to the image-local path everywhere).
_default_rootfs="${1:?usage: resolve-rootfs-path.sh <default-rootfs-path>}"

echo "/var/lib/hatch-runtime/rootfs"
