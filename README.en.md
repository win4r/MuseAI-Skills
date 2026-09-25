# Muse / Hatch Skills & Runtime Snapshot

[简体中文](README.md) · [Technical analysis (Chinese)](PROJECT_ANALYSIS.md) · [File checksums](SHA256SUMS)

This repository archives **a partial filesystem snapshot of a Muse / Hatch personal AI agent environment**. It contains product documentation, skill definitions, connector permission manifests, Linux runtime scripts, and bundled executables and dependencies for inspection and technical analysis.

**This is neither a complete source repository nor a one-command deployment package.** Most core programs are Linux x86-64 ELF binaries. Their source code, complete host configuration, root filesystem, and some runtime resources are absent. The supplied materials use the names Muse, Hatch, and Jarvis; this archive does not represent an official release or endorsement, and its provenance and product claims have not been independently verified.

## Skills: the main reading collection

The skill texts are a particularly useful part of this snapshot for studying agent workflow design: they describe **when to trigger, how to route tasks, which tools to use, how to handle authorization and failure, and how to verify deliverables**. They can be inspected without downloading the large executables.

There are **72 `SKILL.md` paths: 68 distinct skill files plus 4 symlink aliases**. The tables below cover all 68 distinct files; the aliases are listed separately. Names are directory paths, which can differ from frontmatter names. “Bundled skills” describes their location in the snapshot, not independently authenticated official provenance or a verified open-source release.

### Suggested reading path

These selections emphasize workflow design that is useful to examine, not proven execution quality or drop-in compatibility.

| Skill | What to study |
|---|---|
| [wide-research](opt/hatch/skills/wide-research/SKILL.md) | Coordinator/worker boundaries, consistent output contracts, and failure coverage. |
| [skill-creator](opt/hatch/skills/skill-creator/SKILL.md) | Clear triggers, concise operational files, and on-demand references. |
| [artifacts/testing](opt/hatch/skills/artifacts/testing/SKILL.md) | Separate successful generation from usable, visually verified deliverables. |
| [goals](opt/hatch/skills/goals/SKILL.md) | Separate initial goal intake from ongoing support by life domain. |
| [forget](opt/hatch/skills/forget/SKILL.md) | Account for copies, derived state, and background work that can recreate information. |
| [travel-planning](opt/hatch/skills/travel-planning/SKILL.md) | Route itinerary research separately from live availability and transactions. |
| [magic-moment](opt/hatch/skills/magic-moment/SKILL.md) | Organize facts, narrative, visuals, timelines, and pre-render review. |
| [gmail](opt/hatch/skills/gmail/SKILL.md) | Read instructions together with method-level permissions and evaluation scenarios. |

### Agent workflows and memory（6）

| Skill | Documented purpose | Supporting files |
|---|---|---|
| [wide-research](opt/hatch/skills/wide-research/SKILL.md) | Research many independent inputs with a shared output schema, coverage counts, and failure reporting. | — |
| [goals](opt/hatch/skills/goals/SKILL.md) | Create goals by life domain, record commitments, and follow progress. | [Creation](opt/hatch/skills/goals/creation) · [Guides](opt/hatch/skills/goals/guides) |
| [skill-creator](opt/hatch/skills/skill-creator/SKILL.md) | Author skill triggers, resource layout, tooling/auth sections, and validation checks. | [References](opt/hatch/skills/skill-creator/references) |
| [self-awareness](opt/hatch/skills/self-awareness/SKILL.md) | Ground answers about agent capabilities, memory, and past work in observed state. | [References](opt/hatch/skills/self-awareness/references) |
| [forget](opt/hatch/skills/forget/SKILL.md) | Plan, confirm, and verify forgetting across memory and derived content. | [References](opt/hatch/skills/forget/references) |
| [muse_db](opt/hatch/skills/muse_db/SKILL.md) | Use bounded read-only database queries to trace execution and delivery records. | [References](opt/hatch/skills/muse_db/references) |

### Documents, spreadsheets, and artifact verification（6）

| Skill | Documented purpose | Supporting files |
|---|---|---|
| [artifacts/document](opt/hatch/skills/artifacts/document/SKILL.md) | Create and edit Word documents/templates, OOXML, tracked changes, and rendered output. | [References](opt/hatch/skills/artifacts/document/references) |
| [artifacts/markdown](opt/hatch/skills/artifacts/markdown/SKILL.md) | Produce Markdown files, READMEs, notes, and read-back verification. | — |
| [artifacts/pdf](opt/hatch/skills/artifacts/pdf/SKILL.md) | Author and manipulate PDFs, fill forms, and validate page geometry. | [References](opt/hatch/skills/artifacts/pdf/references) |
| [artifacts/presentation](opt/hatch/skills/artifacts/presentation/SKILL.md) | Build slides from per-slide HTML, theme plans, assembly, and PPTX export. | [References](opt/hatch/skills/artifacts/presentation/references) |
| [artifacts/spreadsheet](opt/hatch/skills/artifacts/spreadsheet/SKILL.md) | Create and clean spreadsheets, recalculate formulas, and validate workbooks. | [References](opt/hatch/skills/artifacts/spreadsheet/references) |
| [artifacts/testing](opt/hatch/skills/artifacts/testing/SKILL.md) | Apply per-format checks, fresh rendering, visual inspection, and placeholder scans. | — |

### Travel, local discovery, and booking（7）

| Skill | Documented purpose | Supporting files |
|---|---|---|
| [travel-planning](opt/hatch/skills/travel-planning/SKILL.md) | Plan itineraries, feasibility, entry/transit requirements, and ground logistics. | [Eval](opt/hatch/skills/travel-planning/eval) · [References](opt/hatch/skills/travel-planning/references) |
| [booking](opt/hatch/skills/booking/SKILL.md) | Route live availability and transactions for flights, hotels, restaurants, and tickets. | [Eval](opt/hatch/skills/booking/eval) · [References](opt/hatch/skills/booking/references) |
| [places-search](opt/hatch/skills/places-search/SKILL.md) | Find and compare venues, attractions, and local services by location. | [Eval](opt/hatch/skills/places-search/eval) |
| [duffel](opt/hatch/skills/duffel/SKILL.md) | Search, book, pay for, and manage flights; monitor booked fares when requested. | [Manifest](opt/hatch/skills/duffel/manifest.yaml) · [Eval](opt/hatch/skills/duffel/eval) |
| [flightaware](opt/hatch/skills/flightaware/SKILL.md) | Verify dated flight schedules, delays, cancellations, and operational changes. | [Manifest](opt/hatch/skills/flightaware/manifest.yaml) · [Eval](opt/hatch/skills/flightaware/eval) |
| [opentable](opt/hatch/skills/opentable/SKILL.md) | Find restaurant availability and create, change, or cancel reservations. | [Manifest](opt/hatch/skills/opentable/manifest.yaml) · [Eval](opt/hatch/skills/opentable/eval) |
| [ticketmaster](opt/hatch/skills/ticketmaster/SKILL.md) | Search events, seats, and prices; return checkout links without completing purchases. | [Manifest](opt/hatch/skills/ticketmaster/manifest.yaml) |

### Productivity, email, and knowledge tools（16）

| Skill | Documented purpose | Supporting files |
|---|---|---|
| [gmail](opt/hatch/skills/gmail/SKILL.md) | Search/read mail, draft/send/reply, manage labels, and unsubscribe. | [Manifest](opt/hatch/skills/gmail/manifest.yaml) · [Eval](opt/hatch/skills/gmail/eval) |
| [google-calendar](opt/hatch/skills/google-calendar/SKILL.md) | Inspect agendas and events and change schedules. | [Manifest](opt/hatch/skills/google-calendar/manifest.yaml) · [Eval](opt/hatch/skills/google-calendar/eval) |
| [google-contacts](opt/hatch/skills/google-contacts/SKILL.md) | Search, create, update, and delete contacts. | [Manifest](opt/hatch/skills/google-contacts/manifest.yaml) · [Eval](opt/hatch/skills/google-contacts/eval) |
| [google-docs](opt/hatch/skills/google-docs/SKILL.md) | Read, create, and edit Google Docs. | [Manifest](opt/hatch/skills/google-docs/manifest.yaml) |
| [google-drive](opt/hatch/skills/google-drive/SKILL.md) | Manage files/folders, uploads, downloads, and sharing. | [Manifest](opt/hatch/skills/google-drive/manifest.yaml) · [Eval](opt/hatch/skills/google-drive/eval) |
| [google-forms](opt/hatch/skills/google-forms/SKILL.md) | Read, create, and update forms and read responses. | [Manifest](opt/hatch/skills/google-forms/manifest.yaml) |
| [google-sheets](opt/hatch/skills/google-sheets/SKILL.md) | Read, write, and manage Google Sheets. | [Manifest](opt/hatch/skills/google-sheets/manifest.yaml) |
| [google-slides](opt/hatch/skills/google-slides/SKILL.md) | Read, create, and edit Google Slides. | [Manifest](opt/hatch/skills/google-slides/manifest.yaml) |
| [google-tasks](opt/hatch/skills/google-tasks/SKILL.md) | Manage task lists, create/update tasks, and mark completion. | [Manifest](opt/hatch/skills/google-tasks/manifest.yaml) · [Eval](opt/hatch/skills/google-tasks/eval) |
| [outlook-calendar](opt/hatch/skills/outlook-calendar/SKILL.md) | Read, create, update, and delete Outlook events. | [Manifest](opt/hatch/skills/outlook-calendar/manifest.yaml) |
| [outlook-contacts](opt/hatch/skills/outlook-contacts/SKILL.md) | Read, search, and manage Outlook contacts. | [Manifest](opt/hatch/skills/outlook-contacts/manifest.yaml) |
| [outlook-mail](opt/hatch/skills/outlook-mail/SKILL.md) | Read, search, send, reply to, and delete Outlook mail. | [Manifest](opt/hatch/skills/outlook-mail/manifest.yaml) |
| [notion](opt/hatch/skills/notion/SKILL.md) | Search, read, create, and update pages through Notion MCP. | [Manifest](opt/hatch/skills/notion/manifest.yaml) |
| [granola](opt/hatch/skills/granola/SKILL.md) | Search/read meeting notes and transcripts through an OAuth-backed MCP server. | [Manifest](opt/hatch/skills/granola/manifest.yaml) |
| [muse-mail](opt/hatch/skills/muse-mail/SKILL.md) | Operate Muse Mail mailboxes, forwarded messages, and intake workflows. | [References](opt/hatch/skills/muse-mail/references) |
| [calendly](opt/hatch/skills/calendly/SKILL.md) | Inspect Calendly events/event types and manage scheduling data. | [Manifest](opt/hatch/skills/calendly/manifest.yaml) |

### Social networks and messaging（6）

| Skill | Documented purpose | Supporting files |
|---|---|---|
| [facebook-cli](opt/hatch/skills/facebook-cli/SKILL.md) | Read Facebook content and social context; manage own Marketplace listings. | [Manifest](opt/hatch/skills/facebook-cli/manifest.yaml) · [References](opt/hatch/skills/facebook-cli/references) |
| [instagram](opt/hatch/skills/instagram/SKILL.md) | Read content, account information, and insights; publish posts/media on request. | [Manifest](opt/hatch/skills/instagram/manifest.yaml) · [References](opt/hatch/skills/instagram/references) |
| [instagram-messages](opt/hatch/skills/instagram-messages/SKILL.md) | Read inboxes/threads, search DMs, and send messages. | [Manifest](opt/hatch/skills/instagram-messages/manifest.yaml) |
| [messenger](opt/hatch/skills/messenger/SKILL.md) | Read contacts/calls/conversations and send, edit, unsend, or react to messages. | [Manifest](opt/hatch/skills/messenger/manifest.yaml) |
| [threads](opt/hatch/skills/threads/SKILL.md) | Inspect accounts, posts, feeds, and insights; search and publish on request. | [Manifest](opt/hatch/skills/threads/manifest.yaml) |
| [threads-messages](opt/hatch/skills/threads-messages/SKILL.md) | Read Threads inboxes and message threads and send messages. | [Manifest](opt/hatch/skills/threads-messages/manifest.yaml) |

### Shopping, merchandise, and financial data（3）

| Skill | Documented purpose | Supporting files |
|---|---|---|
| [shopping](opt/hatch/skills/shopping/SKILL.md) | Route product discovery, reverse-image shopping, comparisons, presentation, and purchases. | [References](opt/hatch/skills/shopping/references) |
| [printify](opt/hatch/skills/printify/SKILL.md) | Inspect catalogs and manage shops, products, and orders. | [Manifest](opt/hatch/skills/printify/manifest.yaml) |
| [plaid](opt/hatch/skills/plaid/SKILL.md) | Read connected accounts, balances, transactions, liabilities, and investments. | [Manifest](opt/hatch/skills/plaid/manifest.yaml) · [Eval](opt/hatch/skills/plaid/eval) |

### Health and fitness data（6）

| Skill | Documented purpose | Supporting files |
|---|---|---|
| [apple-healthkit](opt/hatch/skills/apple-healthkit/SKILL.md) | Read synced Apple Health metrics, sleep, and workout records. | [Manifest](opt/hatch/skills/apple-healthkit/manifest.yaml) |
| [google-health-connect](opt/hatch/skills/google-health-connect/SKILL.md) | Read synced Android health metrics, sleep, and workout records. | [Manifest](opt/hatch/skills/google-health-connect/manifest.yaml) |
| [function-health](opt/hatch/skills/function-health/SKILL.md) | Retrieve lab biomarker results and clinician notes. | [Manifest](opt/hatch/skills/function-health/manifest.yaml) |
| [healthex](opt/hatch/skills/healthex/SKILL.md) | Connect HealthEx and query medications, labs, and health records. | [Manifest](opt/hatch/skills/healthex/manifest.yaml) |
| [peloton](opt/hatch/skills/peloton/SKILL.md) | Browse fitness classes, schedules, and workout bookings. | [Manifest](opt/hatch/skills/peloton/manifest.yaml) |
| [withings](opt/hatch/skills/withings/SKILL.md) | Connect Withings and read body, activity, sleep, workout, and heart data. | [Manifest](opt/hatch/skills/withings/manifest.yaml) · [References](opt/hatch/skills/withings/references) |

### Image, audio, and video workflows（8）

| Skill | Documented purpose | Supporting files |
|---|---|---|
| [image-search](opt/hatch/skills/image-search/SKILL.md) | Search images and source pages by text query. | — |
| [media-library](opt/hatch/skills/media-library/SKILL.md) | Search and inspect the user photo library and connected device galleries. | — |
| [spotify](opt/hatch/skills/spotify/SKILL.md) | Discover music/podcasts and manage playlists and related content. | [Manifest](opt/hatch/skills/spotify/manifest.yaml) |
| [generate_podcast](opt/hatch/skills/generate_podcast/SKILL.md) | Compose single/multi-voice podcasts, briefings, or narrated summaries as MP3. | [References](opt/hatch/skills/generate_podcast/references) |
| [tts](opt/hatch/skills/tts/SKILL.md) | Convert supplied text to single- or multi-speaker speech. | [Manifest](opt/hatch/skills/tts/manifest.yaml) |
| [voice-design](opt/hatch/skills/voice-design/SKILL.md) | Choose or design a new speaking voice at the user request. | — |
| [voice-selector](opt/hatch/skills/voice-selector/SKILL.md) | Provide the static system voice catalog, not a standalone user workflow. | — |
| [magic-moment](opt/hatch/skills/magic-moment/SKILL.md) | Turn talking-head footage and real agent work into a synchronized vertical story. | [Guides](opt/hatch/skills/magic-moment/guide) · [Design refs](opt/hatch/skills/magic-moment/reference) |

### Devices, communications, and networking（6）

| Skill | Documented purpose | Supporting files |
|---|---|---|
| [device-data](opt/hatch/skills/device-data/SKILL.md) | Read cached contacts/calendars and remove Muse-local copies. | — |
| [wearable-device-skills](opt/hatch/skills/wearable-device-skills/SKILL.md) | Discover, inspect, and invoke capabilities exposed by paired phones/wearables. | — |
| [wearables-comms](opt/hatch/skills/wearables-comms/SKILL.md) | Handle wearable-originated calls/texts with contact and phone-number disambiguation. | — |
| [philips-hue](opt/hatch/skills/philips-hue/SKILL.md) | Control smart lights, rooms, scenes, and devices. | [Manifest](opt/hatch/skills/philips-hue/manifest.yaml) |
| [tessie](opt/hatch/skills/tessie/SKILL.md) | Inspect Tesla state and invoke explicit vehicle command endpoints. | [Manifest](opt/hatch/skills/tessie/manifest.yaml) |
| [tailscale](opt/hatch/skills/tailscale/SKILL.md) | Join Tailnet/Headscale, inspect connectivity, and access private machines through a TCP proxy. | — |

### Muse product operations（4）

| Skill | Documented purpose | Supporting files |
|---|---|---|
| [muse-early-access](opt/hatch/skills/muse-early-access/SKILL.md) | Submit, inspect, or withdraw early-access requests. | — |
| [muse-feedback](opt/hatch/skills/muse-feedback/SKILL.md) | Submit, inspect, or withdraw feedback and feature requests with user authorization. | — |
| [share-ideas](opt/hatch/skills/share-ideas/SKILL.md) | Publish reusable native Muse Ideas on explicit request. | — |
| [subscription-status](opt/hatch/skills/subscription-status/SKILL.md) | Inspect plans, quota, usage, reset times, and billing-related status. | — |

### Aliases and additional resources

| Alias | Actual target |
|---|---|
| [facebook](opt/hatch/skills/facebook/SKILL.md) | [facebook-cli](opt/hatch/skills/facebook-cli/SKILL.md) |
| [meta-threads](opt/hatch/skills/meta-threads/SKILL.md) | [threads](opt/hatch/skills/threads/SKILL.md) |
| [podcast](opt/hatch/skills/podcast/SKILL.md) | [generate_podcast](opt/hatch/skills/generate_podcast/SKILL.md) |
| [voice-calls](opt/hatch/skills/voice-calls/SKILL.md) | [voice-selector](opt/hatch/skills/voice-selector/SKILL.md) |

`voice-calls` points to a static voice catalog; its name does not establish an agent-operated calling capability. The [Spaces directory](opt/hatch/skills/spaces) includes runtime documentation and templates but has no top-level `SKILL.md`, so it is not counted as a separate skill here. The [shared Artifact references](opt/hatch/skills/artifacts/references) contain guidance for charts, maps, live data, Markdown, and related output. There are 40 manifest paths and 12 eval YAML files across the tree; these are resource counts, not extra skill counts or evidence of passing tests.

### Reading and adapting the skills

- Start with the skill's trigger, boundaries, and output contract; follow its local references and manifest where present.
- Workflow patterns can inform your own agent instructions. Adapt tool names, workspace paths, authorization rules, and validation steps to the target environment.
- Connector skills depend on the corresponding CLI/MCP, account connections, OAuth scopes, and runtime authorization. A copied Markdown file does not provide these capabilities.
- Some referenced helpers are absent: the Artifact validation scripts, the skill-creator connector scaffold helper, and Magic Moment's `mm` executable are not included. Spaces also lacks its SDK/build resources. The documentation is readable, but these execution pipelines are not complete.
- Keep source attribution and applicable licensing terms. “Available in this archive” does not mean “officially verified, independently runnable, or freely relicensable.”

To inspect all skills without downloading LFS binaries:

```bash
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/win4r/muse-file.git
cd muse-file
```

Open `opt/hatch/skills/` or follow the links above. No bundled binary needs to be executed for this reading workflow.

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
