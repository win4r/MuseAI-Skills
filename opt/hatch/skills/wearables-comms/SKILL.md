---
name: "wearables_comms"
title: "Wearables Calls and Messages"
description: >-
  Required for every call or text-message request originating on a wearable:
  resolve named recipients from synced device contacts and invoke the
  originating wearable, not a paired phone.
metadata: { "includeInPrompt": true, "devices": ["audio-wearable", "mcu-wearable"] }
---

# Wearables Calls and Messages

## Purpose

Handle call and text-message requests that originate on a wearable. Resolve a
named recipient from that wearable's synced contacts, then invoke the
originating wearable's native communications command. Do not silently hand the
action to a paired phone.

An ordinary request such as “call Alice” means a native call where the user
speaks. This workflow does not cover a request for the assistant to conduct the
conversation itself.

## Select the device

1. Call `device.list` and select the one device marked `is_request_origin:
   true`.
2. Call `device.describe` for that device. Its live command names and argument
   schemas are authoritative.
3. Keep that same device id for contact lookup and the final action. Never
   choose a paired phone merely because it also advertises a compatible
   command. Only an explicit request to use another device overrides this
   default; resolve and describe that device before proceeding.
4. If no request-origin device is identifiable, or the selected device does
   not advertise the requested capability, explain that the action is
   unavailable rather than silently switching devices.

## Resolve a recipient

Skip contact lookup when the user supplied a complete phone number. Otherwise,
search the stored contacts first, even when the wearable is online:

```bash
device-data contacts search --match-mode ranked --device <selected_device_id> \
  --query <contact_name>
```

Pass `--phone-label <label>` when the user requested a mobile, home, work, or
other saved number, and `--locale <bcp-47>` when the caller's locale is known.
Ranked results are candidates, not authorization to act. Inspect the complete
result, including `selection_evidence`, every candidate's `match`, and every
candidate's `phone_selection`, before invoking a command.

- Treat `exact_full`, `exact_tokens`, `nickname`, and `phonetic` candidates as
  plausible interpretations of a spoken name. An exact textual match does not
  outrank a plausible homophone: the transcript's spelling came from speech
  recognition, not the user. When
  `requires_spoken_name_clarification` is true, ask a short clarification
  before invoking. Use each collision entry's `spoken_spelling` when
  pronunciation alone cannot distinguish the names.
  More than one plausible candidate with different phone destinations also
  requires clarification, even when the first candidate is an exact match.
- Resolve a phone line separately after resolving the person. If
  `requires_phone_clarification` is true, ask which saved line to use unless
  the user explicitly selected one of the numbered line options you presented.
  If `requested_label_match_count` is zero, say that no saved number has the
  requested label. If `distinct_usable_phone_count` is zero, ask the user for
  a number. Otherwise present the available lines under the rules below and
  use one only after the user selects it. When only one line remains, an
  explicit confirmation selects it.
  Never choose the first or preferred-order number. Multiple stored forms
  grouped into one phone option are one destination, not an ambiguity.
- Do not invoke a call or message from an incomplete search, a weak or
  unresolved name match, or an unresolved phone choice.

## Ask for clarification

When there are at most five selectable contact and phone-line combinations,
give one numbered option for each, keeping ranked contact order and the
returned phone-option order. Include the contact name, its `spoken_spelling`
when it has a spoken-name collision, and a concise phone label when the contact
has multiple lines. If labels are missing or repeated, add the option's
`spoken_suffix` so every spoken choice remains distinguishable. Add an
organization only when it helps distinguish otherwise similar contacts. Use
commas between spelled letters and digits so TTS speaks them separately. For
example:

“1, Sean, spelled S, E, A, N, mobile. 2, Shawn, spelled S, H, A, W, N, work.
Which one should I call?”

When presenting numbered options, end with a question that matches the
requested action: “Which one should I call?” for a call or “Which one should I
message?” for a message. Build message options with the same rules as call
options, and never replace a bounded numbered list with a bare name question.

When more than five combinations remain, or the search is incomplete, do not
read a partial list. Ask one short question that narrows the person first, such
as their last name or organization, then search again. If one resolved contact
still has more than five lines, narrow by phone label or final digits before
presenting options.

Only after you actually presented the complete numbered list may an ordinal on
the next turn select its corresponding option. A name, spelling, organization,
or phone label selects an option only when it identifies exactly one of them.
A bare contact name does not choose a line when that contact still has multiple
numbered line options. A repeated bare name also does not resolve a spoken-name
collision, because ASR may choose the same spelling again; require the option
number, deliberate spelling, or another distinguishing detail. Do not reorder
the presented options while interpreting the answer.

Only when the stored search cannot resolve the recipient, fall back to the
selected device's live `contacts.search` command if `device.describe`
advertises it. Do not run the live search first or silently move the lookup to
another device.

## Place a call

Select the native call command advertised by the selected wearable. Current
clients publish `wearables.comms.provider.call`; do not assume that name or its
arguments without checking `device.describe`. Call `device.invoke` with the
selected device id and the resolved phone number in the exact advertised
schema.

## Send a message

Require both a resolved recipient and the message text. Select the native SMS
command advertised by the selected wearable. Current clients publish
`wearables.comms.native.sms`; use its exact schema from `device.describe`, then
call `device.invoke` on that device.

Apply the recipient and phone-line resolution and clarification rules above
before sending; a supplied message body is not evidence for choosing a
recipient. When clarification is required, keep the user's original message
text unchanged. Once those rules resolve exactly one recipient and line, send
that original text to it without asking the user to repeat it. Do not send to
any candidate before then.

Do not substitute a draft or send command from a paired phone. If the wearable
cannot send the message, report that instead of creating a draft somewhere the
user may never see.

## Report the result

- Report success only when `device.invoke` reports success.
- Relay a useful device-provided failure explanation without exposing internal
  command names or private contact details.
- Do not blindly retry a timed-out, interrupted, or uncertain call or send; the
  action may already have happened.
