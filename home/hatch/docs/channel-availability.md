# Channel availability and routing


## Available channels

Live delivery routes can only be determined by querying the API. Messaging channel availability varies by Muse. Check which channels
this Muse has in two places:

1. `channel.status`: an "unknown provider" error means that channel is
  not available on this Muse right now, not that no such channel
  exists
2. `~/docs/channels/`: every available channel has its own guide here (whatsapp.md); if a service has no guide,
  it is not available on this Muse right now. The directory itself is
  removed when no channel is available, so a missing `~/docs/channels/`
  means none right now, not an error

A linked status confirms linking but does not prove delivery is
working.

WhatsApp is the channel today.

Not available:

- Discord: no channel exists.
- SMS: no channel exists; texting through a paired phone is a
  different path, covered in `~/docs/calls-texts-notifications.md`.
- iMessage: not available as a chat channel on this Muse right now.
  Working with the Messages app on a paired Mac (searching history,
  sending an iMessage for the user) is a different path, covered in
  `~/docs/devices/mac_app.md`.

## Connection and disconnection

Connect through the official secure link
(https://agent.meta.ai/connect/channel?service=whatsapp) or the app's
Messaging Channels settings screen, which uses that same link flow.
Disconnect through the Messaging Channels screen.

The Messaging Channels screen shows a QR code on large screens, or a Connect
button that opens WhatsApp on phones and small screens. These artifacts come
only from the app: no phone number, wa.me link, QR code, or link code exists
outside that flow.

## Linked conversation behavior

WhatsApp conversations are one-on-one between you and the user.
You cannot join or be added to group chats even after linking. You cannot read
the user's WhatsApp message history and cannot send messages from the user's
personal account. Group behavior varies by channel; see the channel's guide
in `~/docs/channels/`.

## Message routing

Every provider conversation is a separate side chat in the app, never
mirrored into main chat. A reply always goes out on the surface the message
arrived on. A channel message can only be sent from that channel's own side
chat. You cannot push a one-off message into a provider conversation from
any other chat. The only way to reach a channel proactively is a scheduled
task created from that channel's chat. Main-chat schedules deliver in main
chat, not to channels. Answers cannot be forwarded between channels. Approvals
can be answered from a linked WhatsApp conversation.

