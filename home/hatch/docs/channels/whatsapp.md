---
summary: "WhatsApp Channel setup and media capabilities"
read_when:
  - User wants to talk to Muse on WhatsApp
  - User wants Muse to message or notify them on WhatsApp
  - User wants to reply on WhatsApp instead of the current interface
  - Working on WhatsApp channel linking or pairing
  - User asks about connecting or setting up WhatsApp
  - User asks about sending or receiving files, images, voice messages on WhatsApp
  - User asks about WhatsApp group chats or adding Muse to a group
title: "WhatsApp"
---

# WhatsApp Channel

WhatsApp on Muse provides a **WhatsApp Channel** that lets users message Muse
directly on WhatsApp. Each provider conversation is represented in Muse by a
durable side chat. Muse polls for inbound messages and replies automatically.
Use the `channel.status` / `channel.disable` tools.

The WhatsApp Channel only carries messages between the user and Muse. It does
not itself read, search, or send messages in the user's other WhatsApp chats;
those capabilities, when available, come from a separate account integration.

### How it works

- **Personal 1:1 chat only.** The WhatsApp Channel connects the user's personal WhatsApp to Muse for direct messaging.
It does not support group chats — Muse cannot be added to WhatsApp groups.
- When using the WhatsApp channel, the user is writing to you from the WhatsApp app,
  where the channel has its own thread. The same conversation appears in Muse as a
  side chat titled `WhatsApp`. Replies and scheduled deliveries stay on that chat;
  there is no primary-chat transcript copy.
- The user cannot use Muse to write into the `WhatsApp` side chat directly.
  User messages will always come from the WhatsApp app.
- You should be clear when referring to the Muse app vs the WhatsApp app in the
  WhatsApp channel.
- The daemon polls for inbound messages and runs auto-reply (inference + send).
- Pairing connects a WhatsApp user to the channel via a deep link.

### Supported media and attachments

**What the user can send to Muse on WhatsApp (inbound):**
- Images (photos, screenshots)
- Documents (PDF, doc, spreadsheets, etc.)
- Voice messages and voice recordings — the user can record and send voice notes from WhatsApp and Muse will receive and process them

**What Muse can send to the user on WhatsApp (outbound):**
- Media (images, video, audio)
- Documents (PDF, doc, slides, spreadsheets)
- Self-contained HTML files

### Connecting

If a user wants to connect to the WhatsApp Channel, check `status` first.
When `status` is `unlinked` or `link_pending` and the user wants to connect,
give them this exact two-line response:

`Tap here to connect WhatsApp:`
`[Connect WhatsApp](https://agent.meta.ai/connect/channel?service=whatsapp)`

If the channel is already `linked`, say so instead; if `status` is `checking` or
`unavailable`, follow the `status` guidance below.

### `channel.status` / `channel.disable` Tools

The `channel.status` and `channel.disable` tools are the exclusive way to check status
and disconnect / disable the WhatsApp Channel.
You can also guide users to connect via the link to the settings screen.

Checking status works wherever this tool is offered to you. Disconnecting works
wherever `disable` appears among the tool's actions. If the user asks to
disconnect WhatsApp and `disable` is not available to you, tell them to do it
from a Muse chat rather than trying to call the tool there.

The tool is called with two arguments: `{"action": "status" | "disable", "channel": "whatsapp"}`.
Always start with `status`.

#### `status`

Reads the current state. The result is `{status, connect, chat_url?}`. `connect`
is `null` on a status read (the tool never hands you a connect link; connecting
uses the secure link above). `chat_url` is a separate top-level field, present
only when the channel is linked: a link to the chat in the user's WhatsApp app.

Decide what to do from `status` (values below):
- `linked`: connected. Tell the user they are connected, and you may offer
  `[Open WhatsApp Chat](<chat_url>)` when `chat_url` is present. Do not offer a
  connect link.
- `unlinked`: not connected. To connect, give the user the secure link (see
  Connecting above).
- `link_pending`: a pairing is already in progress, waiting for the user to
  finish it in the app. Point them back to the same connect link, or ask them to
  finish the one they already opened.
- `checking`: state not known yet. Call `status` again before deciding; never
  offer a connect link here.
- `unavailable`: the channel can't be reached right now. Do not offer a connect
  link; tell the user you couldn't connect right now and to try again later, and
  never say the channel is unsupported.

#### `disable`

Disconnects the channel. **Always** confirm the user's intent first, since this stops
WhatsApp messaging. Returns `status: "unlinked"` with `connect: null`.

### Runtime behavior

- Inbound messages are polled on a 1-second cadence when the channel is paired.
- Auto-reply runs a full inference turn and delivers the response back automatically.
- The polling cursor is persisted at `channels/whatsapp/cursor.json`.
