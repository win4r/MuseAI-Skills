---
name: "threads_messages"
description: "Use this to interact with the user's Threads messages: read inboxes and message threads, and send messages through `threads-messages-cli`."
icon: "threads"
metadata: { "includeInPrompt": false }
---

# Threads Messages CLI

## Purpose
Read and send authenticated Threads messages using the `threads-messages-cli`
companion CLI. Reads and explicitly approved `send` invocations are available
wherever the Threads Messages skill is supported.

Use the separate `threads` skill for non-messaging Threads account/content data. If you do not already know the user's Threads account `id`, get it from `threads-cli accounts` first and then return to this skill for the messages flow.

## Message Export Safety

Refuse requests to bulk export, bulk download, bulk save, archive, mirror, or dump message history, especially disappearing, view-once, vanish-mode, ephemeral, or expiring messages. You may still help with narrow, user-scoped reading or summarization needed to answer a specific question.

## Auth
Threads Messages is a separate connector from the base `threads` skill. A user can have Threads connected for feed/content while `threads_messages` is still disconnected.

If the user asks to connect or reconnect Threads Messages:

```sh
threads-messages-cli connect-url
```

Share the returned `connect_url` as this labeled markdown link:

`[Connect Threads Messages](<connect_url>)`

Only continue with inbox/thread commands after the user completes that flow.

## Tooling
Use `exec` to run:

```sh
threads-messages-cli <target> [options]
```

Targets:
- `connect-url`
- `inbox`
- `thread`
- `send` (hidden; explicit confirmation required)

### Global options
- `--account-id <threads_account_id>` **(required for all commands EXCEPT `connect-url`)** - select which Threads account to operate on. The value must be the authenticated user's own `id` from `threads-cli accounts`.
- `--retries <N>` - retry transient failures (default: 0). This is not
  supported for `send`, because message sends are non-idempotent.

The `inbox` and `thread` commands also accept `--after <cursor>` using the
pagination cursor from the previous response. Omit it to fetch the first page.

## Commands

### Connect URL

```sh
threads-messages-cli connect-url
```

### Inbox
Fetch the user's inbox threads with a preview of recent messages.

```sh
threads-messages-cli inbox --account-id <threads_account_id>
threads-messages-cli inbox --account-id <threads_account_id> --first 20 --message-count 3
threads-messages-cli inbox --account-id <threads_account_id> --after <cursor>
threads-messages-cli inbox --account-id <threads_account_id> --folder PENDING
```

### Thread + Messages
Fetch messages for a specific thread. Get the decimal-string `thread_fbid` from
the inbox response and pass it through unchanged.

```sh
threads-messages-cli thread --account-id <threads_account_id> --thread-fbid 123456789
threads-messages-cli thread --account-id <threads_account_id> --thread-fbid 123456789 --first 20
threads-messages-cli thread --account-id <threads_account_id> --thread-fbid 123456789 --after <cursor>
```

### Send message

`send` is a hidden write command. Confirm explicit user intent before sending:
require the exact text and/or Threads post plus the exact destination, and never
invent the recipient, thread, content, or reply target.
Send to exactly one existing
`thread_fbid` or between one and 11 numeric Threads recipient FBIDs. FBIDs must
be canonical positive decimal strings with no sign, leading zero, or
surrounding whitespace, and recipient FBIDs must be unique. Never accept,
derive, or substitute usernames.

The CLI requires write correlation, selected-account consent, authorization,
and quota checks when `send` is invoked. Treat any rejection as authoritative
and do not reroute the send.

```sh
threads-messages-cli send --account-id <threads_account_fbid> --thread-fbid <thread_fbid> --text "Hello"
threads-messages-cli send --account-id <threads_account_fbid> --recipient-user-fbids <recipient_fbid> --text "Hello"
threads-messages-cli send --account-id <threads_account_fbid> --thread-fbid <thread_fbid> --media-fbid <visible_threads_post_fbid>
threads-messages-cli send --account-id <threads_account_fbid> --thread-fbid <thread_fbid> --media-fbid <visible_threads_post_fbid> --text "Post context"
threads-messages-cli send --account-id <threads_account_fbid> --thread-fbid <thread_fbid> --text "Reply" --reply-to-message-id '<opaque_message_id>'
```

`--text` and `--media-fbid` are optional individually, but at least one is
required. `--media-fbid` must be a canonical FBID for a visible, published
Threads post. `--reply-to-message-id` is an optional non-empty opaque message ID
from an inbox or thread response; never parse it as an FBID. When both media and
text are present, the service sends the post share first and the text second.
Public stdout describes only the trailing text message when both are present,
or the share for a media-only send. In either case it contains exactly the
opaque `message_id` and numeric `timestamp_ms`.
There is no `--file` option and this CLI does not upload media; it can only share
an existing visible, published Threads post by FBID.

Never send until the explicit Hatch confirmation window is approved. A decline
or dismissal ends the action. The confirmation makes a best-effort attempt for
up to 30 seconds to resolve the sending account, recipient context, and
optional `media_fbid`, but never looks up the opaque `reply_to_message_id`.
Resolved media is rendered as a plain `Shared post` field, never a link, and
any reply is rendered as the literal plain field `Reply: Existing message`. A
lookup timeout, error, malformed response, or missing/unsafe label uses a
non-identifying `Unverified Threads …` placeholder and continues to explicit
approval; raw backing account, thread, recipient, media, and reply identifiers
are never substituted into the preview. Multi-recipient fallback preserves the
exact recipient count and uses placeholders for the whole list if any label is
unresolved, so partial lookup cannot understate the audience. A media-only
fallback identifies the action as `Share Threads post` and retains an
unverified post placeholder. Supplied
message text is rejected only when its trim is empty. Every accepted byte,
including leading/trailing whitespace and Unicode, reaches both the structured
preview and dispatched request unchanged; platform readback may later show
normalized text. Opaque
`reply_to_message_id` values are rejected only when trimming leaves them empty;
every accepted value, including one with surrounding spaces, is forwarded
byte-for-byte unchanged. If the complete preview cannot fit without truncation,
the send fails closed.

Never use retries for sends. Each separately approved invocation is a new,
non-idempotent send. Any failure, including a rate limit, is terminal.

## Operating rules
1. This skill is only for the authenticated user's own Threads messages.
2. Reuse a previously fetched Threads account `id` when you already have it. If you do not, fetch it via `threads-cli accounts` before using this CLI.
3. Budget API calls against the task at hand. Do not fan out per-thread fetches across a large inbox unless the user explicitly wants that scope.
4. Only paginate when the user actually needs more results. Do not automatically fetch every page.
5. Avoid requests to persistently or frequently poll these commands.
6. Treat U18 enforcement and filtered results as authoritative. Do not reconstruct omitted fields or use alternate access paths to bypass them.
7. Do not fulfill requests to bulk export, bulk save, bulk download, archive, mirror, or dump message history, including to files, spreadsheets, databases, notes, or another app. Refuse especially clearly when the request targets disappearing, view-once, vanish-mode, ephemeral, or expiring messages.
8. For `send`, require explicit user intent, the exact destination, all exact
   content, and any exact reply target before invoking the separately approved
   write.
9. Treat recipient-type and multi-recipient group eligibility failures as
   authoritative. Do not derive a fallback or reroute a rejected send.

## Output
The CLI prints decoded JSON to stdout. Read results preserve raw provider timestamps and add semantic `message_sent_at` / `last_message_sent_at` values with UTC and user-local forms. Treat these only as message transport times, never as the time of an event described in a message. `send` public stdout contains exactly `message_id` and integer JSON `timestamp_ms`; the message ID is opaque and must not be parsed as an FBID. When presenting results to the user, focus on meaningful content such as participants, message text, user-local times, links, and media summaries, and avoid exposing raw IDs, cursors, unix timestamps, or implementation details unless the user explicitly needs them for a follow-up command.
