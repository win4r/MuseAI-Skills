# Muse / Hatch Runtime Snapshot

[简体中文](README.md) · [Technical analysis (Chinese)](PROJECT_ANALYSIS.md) · [File checksums](SHA256SUMS)

This repository archives **a partial filesystem snapshot of a Muse / Hatch personal AI agent environment**. It contains product documentation, skill definitions, connector permission manifests, Linux runtime scripts, and bundled executables and dependencies for inspection and technical analysis.

**This is neither a complete source repository nor a one-command deployment package.** Most core programs are Linux x86-64 ELF binaries. Their source code, complete host configuration, root filesystem, and some runtime resources are absent. The supplied materials use the names Muse, Hatch, and Jarvis; this archive does not represent an official release or endorsement, and its provenance and product claims have not been independently verified.

## Start here

- For architecture, capability boundaries, missing components, and evidence references, read the [Chinese analysis report](PROJECT_ANALYSIS.md).
- For product design, start with the [overview](home/hatch/docs/muse.md), [goals](home/hatch/docs/goals.md), [scheduling](home/hatch/docs/scheduling-and-watching.md), and [background maintenance](home/hatch/docs/self_improvement.md).
- For tools and authorization, read the [connector guide](home/hatch/docs/connectors.md), [Gmail skill](opt/hatch/skills/gmail/SKILL.md), and its [permission manifest](opt/hatch/skills/gmail/manifest.yaml).
- For runtime architecture, inspect the [runtime-cell launcher](opt/hatch/runtime-cell/launch-daemon.sh), [daemon controller](opt/hatch/runtime-cell/control-daemon.sh), and [database schema guide](opt/hatch/skills/muse_db/references/schema.md).
- For generated applications, compare the [Artifacts guide](home/hatch/docs/artifacts.md) with the [TypeScript runtime README](opt/hatch/skills/spaces/ts-runtime/README.md). Their descriptions of publication capabilities differ.

## Repository layout

```text
.
├── README.md                    # Chinese overview
├── README.en.md                 # English overview
├── PROJECT_ANALYSIS.md          # Technical analysis in Chinese
├── SHA256SUMS                   # SHA-256 checksums for regular files
├── .gitattributes               # Git LFS tracking rules for binaries
├── .gitignore                  # Local metadata exclusions
├── home/hatch/
│   ├── config/                  # Local configuration declarations
│   ├── docs/                    # Product, channel, device, and capability guides
│   ├── assets/                  # Resource documents included in this snapshot
│   ├── PROACTIVE_PREFERENCES.md
│   └── workspace/               # Historical review material
└── opt/
    ├── hatch/
    │   ├── bin/                 # Core programs and connector CLIs
    │   ├── runtime-cell/        # Linux environment lifecycle scripts
    │   └── skills/              # Skills, manifests, references, and eval scenarios
    └── hatch-image/bin/         # Bun, Codex, npm, RTC, and related resources
```

Snapshot inventory, excluding `.DS_Store` and newly added repository documents and checksums:

| Item | Count |
|---|---:|
| Original snapshot file paths | 2,652 |
| Product and device documents | 26 |
| Top-level skill directories / `SKILL.md` files | 68 / 72 |
| `manifest.yaml` files | 40 |
| Evaluation YAML files | 12 |
| Entries in `opt/hatch/bin` | 77 |
| Documented database namespaces / relations | 17 / 195 |

Use the Git tree and `SHA256SUMS` for the exact published file set. Database counts describe the supplied documentation, not a live database query.

## Design overview

The materials describe an agent that receives user requests, consults personal context, works with goals and memory, invokes tools, delivers messages or artifacts, and maintains contextual knowledge and suggestions in background workflows.

| Layer | Visible materials |
|---|---|
| Product and personal context | Goals, Feed, Ideas, Memory, Relationships |
| Agent execution | Hatch daemon, execution service, connector CLIs, browser and device tools |
| Capability contracts | Skills and manifests with method-level permissions and OAuth scopes |
| Persistence and observability | PostgreSQL schema documentation and execution/delivery record designs |
| Runtime isolation | systemd-nspawn, host/guest lifecycle, proxy and trust configuration |
| Generated applications | Artifact, Spaces, TypeScript SDK, and database migration documentation |

The files provide evidence of design intent and parts of the implementation structure. They do not establish that a feature is currently operational, an account is connected, permissions are granted, or tests have passed.

## Download and verify

### Full checkout, including binaries

Install [Git LFS](https://git-lfs.com/) first:

```bash
git lfs install
git clone https://github.com/win4r/muse-file.git
cd muse-file
git lfs pull
git lfs fsck
```

Executables and shared libraries are tracked through Git LFS. Without LFS, or when downloads are skipped, those paths may contain small pointer files. Do not assume a standard ZIP download contains all LFS objects; prefer the commands above.

The original files total approximately 2.02 GB when counted by path, or 1.55 GB when deduplicated by local inode. Git does not preserve hardlink relationships, so multiple names for a shared executable will generally become separate files after checkout. Allow roughly 2 GB for the working tree plus additional Git/LFS cache space.

### Documentation-only checkout

```bash
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/win4r/muse-file.git
cd muse-file
```

Run `git lfs pull` later if you need the binaries.

### Content checksums

After downloading LFS objects, run from the repository root:

```bash
# Linux
sha256sum --check SHA256SUMS

# macOS
shasum -a 256 --check SHA256SUMS
```

The manifest covers published regular files, excluding itself, `.git`, and ignored local metadata. Symlinks are tracked by Git and excluded from this regular-file manifest. Checksums establish content consistency, not provenance or executable safety.

## Runtime limitations and missing components

This snapshot cannot boot independently. The download instructions are not installation or deployment instructions.

- Core programs target **Linux x86-64**, not native macOS execution.
- Core source code and complete build definitions are missing.
- Complete host services, rootfs, database migrations, and control-plane dependencies are missing.
- The Web Artifact README references `build.mjs`, `sdk/`, and `dist/space-sdk.tgz`, none of which is included.
- The evaluation YAML files reference a missing `spawn-eval-instructions.md`.
- `runtime-cell.kdl` references a missing `run-execd.sh`; a complete image might generate it separately.
- `opt/hatch-image/bin/gws` is empty. This does not establish that other Google CLI entry points are broken.
- Product documentation limits publication to static artifacts, while technical documentation describes Cloudflare export with database state. The applicable versions and enabled channels are unconfirmed.

The bundled lifecycle scripts contain absolute paths, mounts, permission changes, and system service operations. They target their original Linux environment and are not generic workstation installers.

## Validation scope

The local analysis included inventory and hardlink checks, selected executable format inspection, documentation cross-checks, and `sh -n` checks of 15 runtime-cell shell scripts. All 15 passed syntax validation.

Service startup, core compilation, database connectivity, live connectors, paired devices, full application builds, and dynamic security testing were not performed. The historical [security review](home/hatch/workspace/muse-security-audit.md) is preserved with its original scope and wording; it is not a system-wide security endorsement.

## Copyright and licensing

This is a public archive. **Public availability does not establish a uniform open-source license for all included content.** No repository-wide MIT, Apache, or similar license has been assigned to this snapshot. Existing component copyrights, trademarks, and licenses remain applicable. Bundled npm and dependency license files are retained, including [npm's LICENSE](opt/hatch-image/bin/npm-package/LICENSE).

The snapshot does not include a verified redistribution license covering all Muse/Hatch content. This repository grants no additional rights on behalf of the original rights holders; applicable terms must be checked for each component and file.
