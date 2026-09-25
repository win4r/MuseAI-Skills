#!/bin/sh
# Is /hatch a loopback-backed stand-in for a real Reliable Volume?
#
# Extracted so the two callers cannot drift apart: resolve-rootfs-path.sh uses it
# to decide whether to hand out the RV rootfs path or the host-local one, and
# ensure-rootfs.sh uses it as the corroborating half of the check that decides
# whether a btrfs snapshot is possible. Two copies of a predicate that must agree
# is a latent bug -- if one drifts, the other's refusal branch fires on healthy VMs.
#
# These scripts do not source anything; they exec each other. So this is a
# standalone program with an exit status rather than a sourced function.
#
# Usage: is-loopback-rv.sh
# Exit:  0 = /hatch is a loopback mount standing in for an RV
#        1 = /hatch is a real RV mount
#        2 = there is no RV of any kind (/hatch absent, or provably not a mount)
#        3 = indeterminate: /hatch is on another filesystem but no mount for it
#            exists, so there was nothing to classify
#
# Every non-zero code means "not loopback", so callers only need to test for
# zero. The codes stay distinct because they are the machine-readable answer
# and they point at different bugs: 1 is a healthy production host, 2 is the
# expected state on a host with no RV, 3 means something structurally odd. 2 is
# a positive determination; 3 is the absence of evidence.
#
# The HUMAN answer is printed here rather than reconstructed by the caller from
# the code. A caller mapping numbers back to explanations is duplicating this
# script's reasoning, and it drifts: an earlier version of ensure-rootfs.sh
# blamed code 3 on a symlinked /hatch, which is the one thing that cannot
# produce it. Only this script knows why it decided, and it can name the actual
# device it saw, which no exit code can carry.
set -eu

# Report the finding, then exit with its code.
#
# STDERR, never stdout: resolve-rootfs-path.sh returns the resolved rootfs path
# on ITS stdout and calls us uncaptured, so anything printed on stdout here
# would be concatenated into that path and silently corrupt it.
verdict() {
    echo "is-loopback-rv: $2" >&2
    exit "$1"
}

# No /hatch at all -> no RV of any kind, loopback included.
[ -d /hatch ] || verdict 2 "/hatch does not exist; no RV of any kind"

# Same device as / means /hatch is a plain directory on the root filesystem, not
# a mount -- so again there is no RV here, real or simulated. Cheap pre-filter
# before reading /proc/mounts. %d is the device number of the file, so equal
# numbers mean "same filesystem".
hatch_dev="$(stat -c '%d' /hatch)"
root_dev="$(stat -c '%d' /)"
[ "$hatch_dev" != "$root_dev" ] || verdict 2 \
    "/hatch is a plain directory on the root filesystem (device $root_dev), not a mount; no RV of any kind"

# It is a distinct mount: loopback only if the backing device is a loop device.
while IFS=' ' read -r _dev _mp _rest; do
    if [ "$_mp" = "/hatch" ]; then
        case "$_dev" in
            /dev/loop*) verdict 0 "/hatch is a loopback mount backed by $_dev" ;;
        esac
        verdict 1 "/hatch is a real RV mount backed by $_dev"
    fi
done < /proc/mounts

# /hatch is on another device, yet /proc/mounts lists no mount for it -- the
# two sources of truth disagree and there was nothing to classify. Reaching
# here means /proc/mounts is missing, unreadable, or describes a different
# mount namespace than the one we are in; a plain misconfiguration does not
# get here. (Note a SYMLINKED /hatch does NOT: `stat` defaults to lstat, so it
# reports the link's own device, which equals /, and the check above answers 2
# before we get here. `test -d` does follow the link -- the two disagree.)
#
# Deliberately neither 1 nor 2. 1 would assert "this is a real RV", a positive
# claim built from a lookup that found nothing, which the caller prints
# verbatim. 2 would claim we established there is no mount, when we only
# failed to find one. Say what actually happened.
verdict 3 \
    "/hatch is on device $hatch_dev (/ is $root_dev) yet /proc/mounts lists no mount for it; nothing to classify"
