#!/bin/sh
set -eu

machine=htch-runtime
bootstrap_watcher_pid=

queue_runtime_cell_bootstrap_phase() {
    "/opt/hatch/bin/spawnd" queue-runtime-cell-bootstrap \
        --jarvis-home "/home/hatch" \
        --phase "$1" \
        --status "$2" \
        --started-at-ms "$3" \
        --completed-at-ms "$4" || true
}

start_runtime_cell_bootstrap_watcher() {
    "/opt/hatch/bin/spawnd" watch-runtime-cell-bootstrap \
        --jarvis-home "/home/hatch" >/dev/null 2>&1 &
    bootstrap_watcher_pid=$!
}

stop_launch_watchers() {
    if [ -n "$bootstrap_watcher_pid" ]; then
        kill "$bootstrap_watcher_pid" >/dev/null 2>&1 || true
        wait "$bootstrap_watcher_pid" >/dev/null 2>&1 || true
        bootstrap_watcher_pid=
    fi
}

trap 'stop_launch_watchers' EXIT INT TERM

start_runtime_cell_bootstrap_watcher

rootfs=$("/opt/hatch/runtime-cell/resolve-rootfs-path.sh" "/var/lib/hatch-runtime/rootfs")
echo "runtime-cell launch: using rootfs at $rootfs" >&2

set -- \
    /usr/bin/systemd-nspawn \
    --quiet \
    --boot \
    --keep-unit \
    --settings=override \
    --directory="$rootfs" \
    --machine=htch-runtime

if /usr/bin/systemd-nspawn --help 2>&1 | grep -q -- '--private-users-ownership'; then
    # Use 'map' (ID-mapped mount) instead of 'auto' (recursive chown).
    # 'auto' recursively chowns the rootfs tree. The runtime cell instead keeps
    # a fixed PrivateUsers range and heals rootfs ownership explicitly before
    # boot, so 'map' preserves the guest view without mutating the on-disk tree
    # during every start. Requires systemd >= 252.
    set -- "$@" --private-users-ownership=map
else
    echo "systemd-nspawn lacks --private-users-ownership support; runtime cell rootfs ownership would be broken" >&2
    exit 1
fi

# --- Per-channel scoped-SKILL visibility (merged into /opt/hatch/skills via overlay) ----
# All skills live in one runtime tree the cell reads: /opt/hatch/skills. There is NO separate
# scoped root and the cell does not distinguish scoped from base -- "present under
# /opt/hatch/skills => usable" is the invariant.
#
# Gated ("scoped") skills ship their SOURCES at the host-only /opt/hatch/skills-scoped, which
# is NOT under runtime-cell-exposed and is bound nowhere into the cell, so the cell cannot
# name them. For the VM's JARVIS_CD_CHANNEL, skill-scopes.conf lists which to reveal, by
# DIRECTORY name (not always the skill's SKILL.md name; the build stages to match):
#     <channel> <scoped-skill-dir> <scoped-skill-dir> ...
# This launcher (host, root, ExecStart=+, before the cell's mount namespace exists) copies
# ONLY the revealed skills into an overlay UPPER and overlays them onto the base skills bind
# SOURCE (runtime-cell-exposed/skills, read-only lower). The recursive /opt/hatch bind then
# serves one merged /opt/hatch/skills = base + revealed scoped. A revealed scoped skill still
# needs its extensions_scoped.toml acceptance entry to load, like any skill.
#
# Fail CLOSED: nothing revealed, a missing conf, or an overlay failure all leave the base
# skills untouched (the overlay lower is read-only and never modified), so non-revealed scoped
# skills simply never appear. (# and blank lines are ignored; a trailing # on a line stripped.)
#
# MECHANISM (why overlay the source): the cell's whole /opt/hatch is a single bind of
# runtime-cell-exposed, so a mount *under* /opt/hatch is shadowed by that wholesale bind. We
# instead overlay the bind SOURCE before the bind; the recursive bind carries it in.
#
# Trust: JARVIS_CD_CHANNEL is injected per-VM into /etc/hatch/env by hatch-init (on
# hatch-image's STRICT_ALLOWED_KEYS allowlist), reaching this launcher via the runtime-cell
# unit's EnvironmentFile=; that file is root-owned 0600, so an in-cell guest cannot forge it.
scoped_src_dir="/opt/hatch/skills-scoped"                 # host-only sources
base_skills_dir="/opt/hatch/runtime-cell-exposed/skills"  # bind source + overlay target
scoped_upper="/run/hatch/skills-scoped-upper"
scoped_work="/run/hatch/skills-scoped-work"
base_lower="/run/hatch/skills-base-lower"

# No stale-overlay cleanup is needed. This unit gets a PRIVATE mount namespace
# per Exec* invocation (forced by ReadWritePaths= on the service), so a previous
# boot's overlay died with its namespace and is not visible here -- verified on a
# live VM: with the overlay active in the cell, host /proc/1/mounts has zero
# entries for runtime-cell-exposed/skills. Only the /run upper/work dirs can
# survive, and they are recreated from scratch below.

# _extras = this channel's revealed scoped skills (empty by default). ACCUMULATE across every
# matching line (union) so a channel spread over multiple lines reveals all of them.
_extras=""
if [ -s "/opt/hatch/runtime-cell/skill-scopes.conf" ]; then
    while read -r _chan _rest; do
        case "$_chan" in
            ''|'#'*) continue ;;
        esac
        if [ "$_chan" = "${JARVIS_CD_CHANNEL:-}" ]; then
            _extras="$_extras ${_rest%%#*}"
        fi
    done < "/opt/hatch/runtime-cell/skill-scopes.conf"
fi

# Assemble the overlay UPPER (copies of only the revealed skills) and overlay it onto the base
# skills bind source. This whole path runs under `set -eu`, so an UNGUARDED mutation failure --
# e.g. /run (a tmpfs) hitting ENOSPC, or EIO, while copying a revealed skill -- would abort this
# launcher before `exec "$@"`. That exit status is not RestartPreventExitStatus, so Restart=always
# would crash-loop the cell agent-less, violating the fail-OPEN-boot contract. So run the reveal
# in a helper whose every mutation is `|| return 1` guarded (invoking it in the `if` below also
# disables `set -e` inside it): on ANY failure we abandon the reveal, tear down partial state, and
# let the cell boot on the untouched base skills tree.
_reveal_scoped_skills() {
    rm -rf "$scoped_upper" "$scoped_work" || return 1
    mkdir -p "$scoped_upper" "$scoped_work" || return 1
    for _skill in $_extras; do
        if [ -d "$scoped_src_dir/$_skill" ]; then
            cp -a "$scoped_src_dir/$_skill" "$scoped_upper/$_skill" || return 1
            echo "runtime-cell launch: channel '${JARVIS_CD_CHANNEL:-<unset>}' reveals scoped skill '$_skill'" >&2
        else
            echo "runtime-cell launch: channel lists unknown scoped skill '$_skill'; ignoring" >&2
        fi
    done
    chmod 0755 "$scoped_upper" || return 1
    # Nothing actually copied (e.g. every listed skill was unknown), or no base tree to overlay:
    # serve base rather than mount an empty overlay.
    [ -n "$(ls -A "$scoped_upper" 2>/dev/null)" ] || return 1
    [ -d "$base_skills_dir" ] || return 1
    mkdir -p "$base_lower" || return 1
    mount --bind "$base_skills_dir" "$base_lower" || return 1
    mount -t overlay overlay \
        -o "lowerdir=$base_lower,upperdir=$scoped_upper,workdir=$scoped_work" \
        "$base_skills_dir" || return 1
    echo "runtime-cell launch: merged $(ls -1 "$scoped_upper" | wc -l) scoped skill(s) into /opt/hatch/skills for channel '${JARVIS_CD_CHANNEL:-<unset>}'" >&2
    return 0
}

if [ -z "$_extras" ]; then
    echo "runtime-cell launch: no scoped skills revealed for channel '${JARVIS_CD_CHANNEL:-<unset>}'" >&2
elif ! _reveal_scoped_skills; then
    echo "runtime-cell launch: scoped skill reveal failed; serving base skills unchanged (fail-closed)" >&2
    # Tear down any partial overlay/stash so the base tree is served clean, then boot on base.
    while umount "$base_skills_dir" 2>/dev/null; do :; done
    umount "$base_lower" 2>/dev/null || true
    rm -rf "$scoped_upper" "$scoped_work" 2>/dev/null || true
fi
# ----------------------------------------------------------------------------

# --- Per-channel scoped-BINARY visibility (merged into /opt/hatch/bin via overlay) --
# INDEPENDENT of skills: bin-scopes.conf lists, per channel, which extension-CLI binaries to
# reveal (this does NOT read skill-scopes.conf and is not tied to any skill's visibility).
# Gated binaries ship host-only, FLAT, at /opt/hatch/bin-scoped/<binary> (bound nowhere into
# the cell). For the VM's JARVIS_CD_CHANNEL, copy the listed binaries into an overlay UPPER and
# overlay them onto the cell bin bind SOURCE (runtime-cell-exposed/bin, read-only lower); the
# recursive /opt/hatch bind then serves one merged /opt/hatch/bin = core + revealed. Merged
# into the SINGLE bin (not a second PATH dir) so the daemon's hardcoded /opt/hatch/bin/<name>
# resolution and a bare-name exec both keep working.
#
# Fail CLOSED: nothing revealed, no bin-scoped tree, or an overlay failure all leave the core
# bin untouched. Add-only (no whiteout). The build guard (_bin_scoped_plan.py) only checks that a
# gated name is a real staged extension CLI -- that is what keeps a core binary
# (hatch/spawnd/hatch-execd) from being gated and shadowed here. It deliberately does NOT
# cross-check whether a skill or jarvis-core path still uses the binary; carving one removes it
# on every non-revealing channel, so only newly-introduced CLIs should be gated.
#
# SCOPE: reveals binaries to the CELL for exec/PATH invocation. Privsep host-slice workers
# resolve their binary on the HOST via their systemd ExecStart and are provisioned separately.
scoped_bin_src_dir="/opt/hatch/bin-scoped"             # host-only, flat sources
base_bin_dir="/opt/hatch/runtime-cell-exposed/bin"     # bind source + overlay target
scoped_bin_upper="/run/hatch/bin-scoped-upper"
scoped_bin_work="/run/hatch/bin-scoped-work"
base_bin_lower="/run/hatch/bin-base-lower"

# No stale-overlay cleanup is needed, for the same reason as the skill reveal above:
# this unit gets a PRIVATE mount namespace per Exec* invocation, so a previous boot's
# overlay died with its namespace and is not visible here. Only the /run upper/work
# dirs can survive, and they are recreated from scratch below.

# _bin_extras = this channel's revealed binaries (empty by default), from bin-scopes.conf.
# ACCUMULATE across every matching line (union) -- mirroring the build planner
# (_bin_scoped_plan.py), which unions a channel's lines.
_bin_extras=""
if [ -s "/opt/hatch/runtime-cell/bin-scopes.conf" ]; then
    while read -r _chan _rest; do
        case "$_chan" in
            ''|'#'*) continue ;;
        esac
        if [ "$_chan" = "${JARVIS_CD_CHANNEL:-}" ]; then
            _bin_extras="$_bin_extras ${_rest%%#*}"
        fi
    done < "/opt/hatch/runtime-cell/bin-scopes.conf"
fi
_bin_extras="$(echo $_bin_extras)"   # collapse whitespace; a channel with no entries => empty

# Assemble the overlay UPPER (copies of only the revealed binaries) and overlay it onto the core
# cell bin. Same `set -eu` boot-safety concern as the skill reveal above: an unguarded mutation
# failure (rm/mkdir/cp/chmod on the /run tmpfs -- ENOSPC or EIO -- or the mount) would abort this
# launcher before `exec "$@"`, and since that exit status is not RestartPreventExitStatus,
# Restart=always would crash-loop the cell agent-less. Run the reveal in a helper whose every
# mutation is `|| return 1` guarded (invoked in the `if` below, which also disables `set -e`
# inside it): on ANY failure abandon the reveal, tear down partial state, and boot on the
# untouched core bin.
_reveal_scoped_binaries() {
    rm -rf "$scoped_bin_upper" "$scoped_bin_work" || return 1
    mkdir -p "$scoped_bin_upper" "$scoped_bin_work" || return 1
    for _bin in $_bin_extras; do
        if [ -e "$scoped_bin_src_dir/$_bin" ]; then
            if [ ! -e "$scoped_bin_upper/$_bin" ]; then
                cp -a "$scoped_bin_src_dir/$_bin" "$scoped_bin_upper/$_bin" || return 1
            fi
            echo "runtime-cell launch: channel '${JARVIS_CD_CHANNEL:-<unset>}' reveals scoped binary '$_bin'" >&2
        else
            echo "runtime-cell launch: channel lists unknown scoped binary '$_bin'; ignoring" >&2
        fi
    done
    chmod 0755 "$scoped_bin_upper" || return 1
    # Nothing actually copied (e.g. every listed binary was unknown), or no core bin to overlay:
    # serve the core bin rather than mount an empty overlay.
    [ -n "$(ls -A "$scoped_bin_upper" 2>/dev/null)" ] || return 1
    [ -d "$base_bin_dir" ] || return 1
    mkdir -p "$base_bin_lower" || return 1
    mount --bind "$base_bin_dir" "$base_bin_lower" || return 1
    mount -t overlay overlay \
        -o "lowerdir=$base_bin_lower,upperdir=$scoped_bin_upper,workdir=$scoped_bin_work" \
        "$base_bin_dir" || return 1
    echo "runtime-cell launch: merged $(ls -1 "$scoped_bin_upper" | wc -l) scoped binary(ies) into /opt/hatch/bin for channel '${JARVIS_CD_CHANNEL:-<unset>}'" >&2
    return 0
}

if [ -z "$_bin_extras" ]; then
    echo "runtime-cell launch: no scoped binaries revealed for channel '${JARVIS_CD_CHANNEL:-<unset>}'" >&2
elif ! _reveal_scoped_binaries; then
    echo "runtime-cell launch: scoped bin reveal failed; core bin unchanged (fail-closed)" >&2
    # Tear down any partial overlay/stash so the core bin is served clean, then boot on core.
    while umount "$base_bin_dir" 2>/dev/null; do :; done
    umount "$base_bin_lower" 2>/dev/null || true
    rm -rf "$scoped_bin_upper" "$scoped_bin_work" 2>/dev/null || true
fi
# ----------------------------------------------------------------------------

exec "$@"
