---
name: "voice_design"
description: "Choose or design a new speaking voice when the user asks for a new, different, custom, invented, or generated voice."
metadata: { "includeInPrompt": false }
---

# Voice design

Help the user choose a new voice. By default, one result is selected
immediately. An explicit request for two or three options returns existing
voices without selecting one. Never present a picker or create a widget.

## Start naturally

Let the user's request lead. If they only say they want a new or custom voice
without giving any direction, ask one short question: do they want to describe
the voice, or should you pick one for them? Then wait for the answer. Do not
start voice design in the background before they answer.

If the user explicitly asks to create multiple new voices, explain that this
flow creates one new voice at a time and ask which one to start with. Do not
silently replace requested new designs with existing library voices.

Ask at most once. If the user gives any usable direction, says “surprise me,”
or asks you to choose, proceed without another question or confirmation.

## Choose the path

Call `muse.voice_options` exactly once with the complete request.

- Treat `allow_create_new_voices` as permission, not your choice of outcome.
  Set it to `true` when the user permits creating a custom voice, including
  requests to create, design, invent, or generate one, or hands you the open
  choice with “pick one for me” or “surprise me.” The runtime still chooses an
  existing system or saved voice when it is the best fit.
- Set it to `false` when the user restricts the choice to existing system or
  saved voices.
- Set `candidate_count` to an explicitly requested two or three, and use three
  for “a few.” Otherwise use one. Counts above one return existing voices only
  and do not select, save, or switch, so set both creation fields to `false`.
- For `candidate_count` one, set `require_new_voice` to `true` only when the
  user explicitly requires a newly created voice. Preserve `true` when their
  current reply answers your immediately preceding clarification about a
  request to create, design, invent, generate, or make a custom or brand-new
  voice. For example, “surprise me” after “make a brand-new voice” still
  requires a new design. Set it to `false` for an open request to pick a
  different voice, where the runtime may choose a strong library match.
- Put the user's complete voice request in `request`, including preferences
  established by the immediately preceding exchange.

Preserve every explicit attribute in the immediate request. The runtime supplies
the current voice, available library, and bounded persona and avatar context to
the selector. Do not copy private or unrelated facts into the tool request.

The rewrite service expands a custom request into the detailed acoustic prompt,
conversational instructions, name, and preview text required by the voice model.
Do not write those implementation fields yourself and do not call
`muse.design_voice`.

## Report the result

Custom design runs in one managed background worker. Briefly say it is being
created, then continue normally. Do not poll, retry automatically, or start a
second design while it is running.

Follow the tool's authoritative result:

- For `options`, name the returned voices and ask the user to choose. Do not
  claim anything was selected, saved, or switched.
- In text, say which single voice you picked and invite the user to start a call
  to hear it.
- During a call, confirm the new voice only after `live_switch_completed` is
  true, then invite the caller to change it again if they want.
- If a call ended or changed before activation, say the preference was saved
  but that call did not switch.
- If the result includes a soft-refusal message, say it naturally once before
  describing the safe alternative.

Refer to voices only by display name. Never expose voice, saved-voice, profile,
call, or worker identifiers. Do not create chat preview UI; voice previews stay
in Voice Settings.
