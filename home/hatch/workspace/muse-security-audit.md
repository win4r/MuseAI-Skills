# Muse security audit

**Date:** 2026-09-25
**Scope:** Files whose names contain `muse` under `/home/hatch`, `/opt`, `/usr/local/bin`, and `/tmp`, plus file contents matching `muse` in scripts and configs under `/home/hatch`.
**Overall verdict:** **Clean.** No reverse shell, data-exfiltration implant, credential harvester, obfuscated payload, suspicious standalone network caller, or persistence mechanism was found in the muse-related files. Matches are shipped Muse product docs, skill instructions, brand assets, or the shared Hatch multicall binary that also provides the `muse-mail` CLI.

The 29 MB binary was reviewed with metadata and strings, not full disassembly. Credential-related strings inside it belong to other applets in the same hardlinked image (auth and browser tools), not to a muse-mail-only backdoor.

## Method

1. **Filename search.** `list_dir` on `/home/hatch`, `/opt`, `/usr/local/bin`, and `/tmp`, plus `find -iname '*muse*'` on those four roots. Skill directories were listed individually.
2. **Content search.** `grep`/`rg` for `muse` under `/home/hatch` in scripts and configs (`sh`, `py`, `js`, `mjs`, `ts`, `json`, `yaml`, `yml`, `conf`, `service`, `cron`, `toml`, `env`, and markdown). `node_modules` and binary asset types (webp, png, mp4, bin, fst) were skipped. A second case-insensitive pass listed every remaining text hit.
3. **Per-file audit.** Text candidates were read (the 4,157-line schema was read through its security preamble and then scanned for indicators). Each candidate was checked for:
   - reverse shells (`/dev/tcp`, `bash -i`, `nc -e`, `ncat`, `socat`)
   - exfiltration and odd hosts (pastebin, ngrok, Discord webhooks, raw GitHub pipes)
   - credential or token harvesting
   - obfuscation (`eval`, `base64 -d`, packed script)
   - unexpected network calls
   - persistence (cron, systemd, rc files, hooks)
   - privilege escalation (setuid/setgid)
4. **Binary.** `file`/`stat`/`readelf`, hardlink identity, and `strings` for the indicators above and for muse-mail endpoints. The binary was not executed.
5. **Persistence sweep.** User crontab (command absent), user systemd (no bus), `/home/hatch/.bashrc`, `/home/hatch/hooks`, `/home/hatch/workspace/cron.d`, and `/etc/cron.d`.

## Files scanned

### Filename hits (11)

| Path | Type | Verdict |
|---|---|---|
| `/home/hatch/docs/muse.md` | Product doc | Clean |
| `/home/hatch/assets/ideas/icons/museum-building.webp` | WebP icon | Clean (name collision: "museum") |
| `/opt/hatch/assets/ideas/icons/museum-building.webp` | WebP icon | Clean (same) |
| `/opt/hatch-image/icons/front_view/entertainment-media/08_entertainment-media_museum-building-front-view.webp` | WebP icon | Clean (same) |
| `/opt/hatch/skills/magic-moment/assets/brand/muse-lockup-1x1.mp4` | MP4 brand asset | Clean (media, not code) |
| `/opt/hatch/skills/magic-moment/reference/design-system/muse-moments-kit.html` | Static HTML | Clean |
| `/opt/hatch/skills/muse-early-access/SKILL.md` | Skill instructions | Clean |
| `/opt/hatch/skills/muse-feedback/SKILL.md` | Skill instructions | Clean |
| `/opt/hatch/skills/muse-mail/SKILL.md` | Skill instructions | Clean |
| `/opt/hatch/skills/muse-mail/references/advanced.md` | Skill reference | Clean |
| `/opt/hatch/skills/muse_db/SKILL.md` | Skill instructions | Clean |
| `/opt/hatch/skills/muse_db/references/schema.md` | Generated schema guide | Clean |
| `/opt/hatch/bin/muse-mail` | ELF multicall binary | Clean as a product CLI; see notes |

`/usr/local/bin` and `/tmp` had **zero** filename matches. No setuid/setgid bit on `muse-mail`.

### Content hits under `/home/hatch`

No shell, Python, or JavaScript file under `/home/hatch` contains `muse`. Content hits are documentation, a hash manifest, an idea catalog, and session transcripts.

| Path | What the match is | Verdict |
|---|---|---|
| `/home/hatch/docs/muse.md` | Product overview (muse.ai, Muse Spark) | Clean |
| `/home/hatch/docs/client-surfaces.md`, `data-handling.md`, `feed.md`, `files-and-library.md`, `privacy-and-credentials.md`, `referrals.md` | Navigation notes pointing at the Muse app or muse.ai | Clean |
| `/home/hatch/docs/self_improvement.md` | Tells the agent to use read-only `muse.db` | Clean |
| `/home/hatch/docs/devices/tailscale.md` | Device requests the Tailscale name `muse` | Clean |
| `/home/hatch/docs/devices/home_link.md` | Names the `muse.skill_search` tool | Clean |
| Other docs that mention Muse (`goals.md`, `media.md`, `connectors.md`, `browser.md`, `artifacts.md`, `payments-and-purchases.md`, `channel-availability.md`, `calls-texts-notifications.md`, `channels/whatsapp.md`, `devices/mac_app.md`) | Product language | Clean |
| `/home/hatch/PROACTIVE_PREFERENCES.md` | "Muse reads this whole file…" | Clean |
| `/home/hatch/assets/onboarding_tour/memory_import.md` | Product wording | Clean |
| `/home/hatch/assets/ideas/icon-descriptions.json` | Key `museum-building` | Clean |
| `/home/hatch/assets/ideas/new-user/catalog.json` | Idea copy: nudges "inside Muse" or as Muse chat | Clean |
| `/home/hatch/config/filesystem_watch_hashes.json` | SHA-256 entries for the four `muse*` skill files | Clean (integrity manifest, not code) |
| 11 files under `/home/hatch/agents/*/sessions/*.jsonl` | Runtime transcripts that mention Muse | Clean on indicator scan (not executable) |

Indicator scan of every home file that mentions `muse` found no `/dev/tcp`, `bash -i`, `nc -e`, `socat`, `base64 -d`, `LD_PRELOAD`, curl/wget-to-shell, pastebin, ngrok, or Discord webhook.

### Persistence

| Location | Result |
|---|---|
| `/home/hatch/.bashrc` | No `muse`. No `.profile`, `.bash_profile`, or `.zshrc`. |
| `/home/hatch/hooks/runtime/hatch_hook_runtime.sh` | No `muse`. |
| `/home/hatch/workspace/cron.d/` | Jobs present (`heartbeat`, feature tour). No `muse`. |
| `/etc/cron.d/e2scrub_all` | No `muse`. No `/etc/crontab` or `/etc/rc.local`. |
| User crontab | `crontab` is not installed. |
| User systemd | No user bus (`Failed to connect to bus`). |
| `/home/hatch/workspace/muse-mail/` | Does not exist (preferences file is created only on an explicit user request). |

## Findings per file

### `/home/hatch/docs/muse.md` — clean

88-line product description: Muse as Meta's personal agent, web app `https://muse.ai`, pointers to other docs. No commands, sockets, or encoded payloads.

### Museum icons and `muse-lockup-1x1.mp4` — clean

Image and video assets. The three WebP files match the word "museum", not a Muse implant. Not executed or treated as code.

### `muse-moments-kit.html` — clean

1,320-line static design-system page ("Muse Moments Kit"). Styles and local `@font-face` URLs under `../../assets/fonts/`. No `<script>`, iframe, `javascript:`, `eval`, `fetch`, or WebSocket.

### `muse-early-access/SKILL.md` — clean

Instructions to file or withdraw an early-access request through `/opt/hatch/bin/feature-request`. No network code, obfuscation, or privilege change. Explicitly says not to refile on errors or promise admission.

### `muse-feedback/SKILL.md` — clean

Instructions for the same `feature-request` CLI (`draft`, `file`, `show`, `list`, `delete`). Example shell blocks are local CLI invocations with quoted summaries. Reports are described as private notes to the Muse team. No outbound URL, no credential collection, no persistence.

### `muse-mail/SKILL.md` and `references/advanced.md` — clean

Operator guide for `/opt/hatch/bin/muse-mail`: mailbox get/create, list/get/reply/send, attachments, owner challenges, intake aliases. Security-relevant behavior in the text is restrictive, not hostile:

- Untrusted mail (`THREAD_REVIEW`, `INTAKE_REVIEW`, `QUARANTINE`, `AUTHENTICATION_FAILURE`) must not be followed or replied to without an explicit user confirmation.
- Overrides (`--allow-restricted-handling`, `--allow-self-message`, `--allow-outbound-target`) require a current-user authorization for that exact message.
- Sender-controlled names, bodies, links, and attachments are treated as untrusted.
- Idempotency keys are required so retries do not double-send.

No shell payload, cron line, or hidden endpoint in the markdown.

### `muse_db/SKILL.md` and `references/schema.md` — clean

`SKILL.md` (19 lines) describes `muse.db` as one bounded read-only `SELECT`. It states the tool cannot mutate data, read PostgreSQL catalogs, access credentials, read Sentinel's approval store, or open per-artifact `app.db` files. Private model reasoning is served through redacted views.

`schema.md` (4,157 lines, migration fingerprint `b502d161e045c1cd1ac4e973e3960739f366aca730006c32f4cb52a6997343dd`) is a generated table catalog. The allowed function list includes ordinary SQL names `reverse`, `encode`, and `md5`. Those are not obfuscation. A search for shells, curl/wget, cron, systemd, and `eval` returned nothing. The documented role is least-privilege `SELECT` on the listed relations only.

### `/opt/hatch/bin/muse-mail` — clean product CLI in a shared binary

| Property | Value |
|---|---|
| Type | ELF 64-bit LSB PIE, x86-64, stripped, magic `7f 45 4c 46` |
| Size | 28,968,264 bytes |
| Mode | `0755` (`nobody:nogroup`). Not setuid/setgid. |
| Timestamps | 1979-12-31 (image epoch, typical of a packed rootfs) |
| Build ID | `ccb95e1ac1789dd17a8d7b2d008e4f123f181887` |
| Identity | Inode 1060, **34 hard links**. Same file as `hatch-multicall`. |

Hardlink siblings in `/opt/hatch/bin` include `hatch-multicall`, `authdc`, `browser-service`, `device-data`, `edits`, `feature-request`, `geocode`, `image-search`, `media-generation`, `media-library`, `muse-mail`, `privsep-test-fully-isolated`, `share`, `shopping`, `subscription-status`, `tts`, and `web-search`. Strings for payments, browser credential grants, and authd are the other applets in this one image. They are not a muse-mail-specific harvester.

Muse-mail-specific strings match the skill doc:

- Subcommands: `mailbox` (get/create/update), `messages` (list/get/send/reply), `attachments`, `threads`, `owners` (list/challenge/revoke), `intake` (list/create/revoke).
- Paths: `/hatch/email/mailbox`, `/hatch/email/messages`.
- Request marker: `muse-mail-request-v1`.
- Gate: `refusing non-Hatch-email path` unless `JARVIS_FQDN` contains a Hatch environment id. Traffic is described as going through the local Stefi proxy (`http://stefi-proxy`), not an attacker host.
- Reply guards: refuse self-mail loops unless `--allow-self-message`; refuse reply-style subjects on new sends unless `--allow-reply-subject`; cap recipients at 50; body cap 1 MiB.

Classic backdoor strings were **absent**: `/dev/tcp`, `/dev/udp`, `bash -i`, `nc -e`, `ncat -e`, `socat`, `mkfifo`, curl/wget piped to a shell, `base64 -d`, `LD_PRELOAD`, `authorized_keys`, crontab/systemctl implants, pastebin, ngrok, Discord webhooks.

Other hosts in the **same** multicall image, not on the muse-mail path:

- `https://hatch-api.meta.ai/hatch/process_tool_call` and `http://localhost/hatch/...` (product tool routing).
- `http://authd.local` (local authd debug client, the `authdc` applet).
- `https://5mxidvxv7zipwtiwq5nigvi5j40fnyxw.lambda-url.us-east-2.on.aws/read` sits in the string neighborhood of the `edits` applet ("parse the edits broker response", "edits send loop"). It is not referenced next to `/hatch/email/`. Noted as a shared-binary endpoint, not classified as a muse backdoor.

### Session transcripts — clean on indicator scan

Eleven agent session logs mention Muse because they are conversations and runtime events about the product. They are not installed programs. Payload-indicator search across them was empty. They were not transcribed into this report.

### Hash manifest — clean

`filesystem_watch_hashes.json` records hashes for:

- `opt/hatch/skills/muse-early-access/SKILL.md`
- `opt/hatch/skills/muse-feedback/SKILL.md`
- `opt/hatch/skills/muse-mail/SKILL.md`
- `opt/hatch/skills/muse_db/SKILL.md`

That is a watch list of shipped skills, not a loader.

## Overall verdict

**No malicious code or backdoor was found** in files related to `muse` on this device.

What is present is the expected Muse product surface: documentation, four instruction skills, brand media, a museum icon whose name collides with the search, and `muse-mail` as one name of the shared Hatch multicall. Persistence locations that could be checked do not reference `muse`. Nothing under `/usr/local/bin` or `/tmp` is named `muse`.

**Limits.** The stripped multicall was not disassembled instruction-by-instruction, and it was not run. A string scan can miss a carefully encoded payload that never appears as text. The credential and payment strings in that binary are real product features of sibling applets; this audit did not re-verify those other tools beyond confirming they are hardlinks of the same image and that muse-mail's own strings match its documented mailbox CLI.
