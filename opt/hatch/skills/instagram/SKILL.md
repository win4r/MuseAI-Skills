---
name: "instagram"
description: "Answer questions about Instagram posts and reels, including links the user shares, using post context, media descriptions, and visual inspection when needed. Read profiles, followers, posts, comments, likes, stories, feed, saved content, and insights. Manage feed interests and profile details, and publish stories, reels, posts, or carousels when requested."
icon: "instagram"
metadata: { "includeInPrompt": true }
---

# Instagram CLI

## Purpose
Read and manage authenticated Instagram data using the `instagram-cli` companion CLI.

Use the separate `instagram_messages` skill for inbox, thread/message reads, filtered inbox, top recipients, and DM search.

## Questions about a post or reel

For questions about a supplied Instagram post or reel, read [Instagram content questions](references/content-questions.md) with `muse.read` before investigating. Use available post evidence, inspect unresolved visual details, and finish the user's task with the relevant skill. Don't sound more certain than you are: say plainly what you checked, call a guess a guess, and admit what you couldn't verify.

## Account Linking

Before running any other command, verify the user's Instagram account is connected by running `instagram-cli accounts`. If the command returns account info (one or more accounts with `user_fbid`), the account is connected — proceed normally. Cache this result for the rest of the conversation; do not re-run the check before every command. If any subsequent command fails with an auth or account error, re-run `instagram-cli accounts` to recheck account linking status.

If the command fails or returns an empty result indicating no account is linked, the account is not connected. Get the connect URL by running `instagram-cli connect-url` (it outputs JSON with a `connect_url` field), then tell the user, substituting that URL:

> Your Instagram account is not connected. To connect it, visit [Meta Accounts Center](`connect_url`) and link your Instagram account.

If the user asks to disconnect their Instagram account, run `instagram-cli disconnect-url` (it outputs JSON with a `disconnect_url` field) and direct them to that URL:

> To disconnect your Instagram account, visit [Meta Accounts Center](`disconnect_url`) and remove the linked account.

Always read these URLs from the command output rather than hardcoding them.

## Operating rules
1. Use this skill for authenticated Instagram non-messaging data, location lookup for Story stickers, and content questions about specific user-supplied Instagram posts or reels. Use `social.search` for general post discovery; use attributed public sources to research people, not identification from their faces.
2. **Always call `accounts` first** to obtain the `user_own_fbid` for `--account-id`. Cache this value for subsequent commands in the same conversation. If `accounts` returns no entries, direct the user to Meta Accounts Center to link an Instagram account (refer to the "Account Linking" section for details).
3. Never expose FBIDs, opaque IDs, or implementation terminology to the user. Use usernames, display names, and plain-language descriptions; keep IDs only in tool calls.
4. **Budget your API calls against the task at hand.** The Instagram API enforces rate limits, and excessive calls will result in `429 Too Many Requests` errors that are not retried. As a rule of thumb:
   - If the task you're doing can be completed in the **low hundreds** of API calls, that's fine — proceed normally.
   - If the task looks like it would require **more than ~1,000 API calls** (for example, paginating through every follower of a large account, or fanning out per-post comment/liker fetches across a huge set of posts), stop and be careful: confirm with the user that the scope is worth it, narrow the work (date ranges, top-N only, specific IDs), or propose a smaller approximation before continuing.
   - Apply common sense in between: batch your information gathering, reuse data from earlier responses (e.g. IDs and usernames from `accounts` or `profile`), and don't re-run the same command with identical arguments unless the previous call failed or the user explicitly asks for a refresh.
   - Only paginate (`--after` / `--max-id`) when the user explicitly needs more results. Don't automatically fetch all pages.
   - When you stop early, say so. If a response carries `has_next_page: true`, `has_more: true`, or similar and you are not fetching the rest, tell the user how much you saw and that more remains, then offer to continue. Never report a paginated read as complete on the strength of one page.
5. Avoid requests to persistently / frequently poll these commands.

## Tooling
Use `exec` to run account-scoped commands:

```sh
instagram-cli <target> --account-id <user_own_fbid> [options]
```

Use `instagram-cli accounts` only to discover available account IDs.

For every write action—including interest updates, publishing, and profile
changes—act only when the user explicitly asks for that change.

Targets:
- `accounts`
- `profile`
- `current-interests`
- `posts`
- `followers`
- `following`
- `close-friends`
- `feed`
- `activity-notifications`
- `user-profile`
- `tagged-posts`
- `post`
- `fetch-post-comments`
- `fetch-post-likers`
- `saved-posts`
- `saved-collections`
- `create-saved-collection`
- `rename-saved-collection`
- `save-post`
- `unsave-post`
- `own-stories`
- `own-stories-archive`
- `stories-tray`
- `story-media`
- `location-search`
- `media-understanding`
- `account-insights`
- `recently-liked-posts`
- `recently-commented-posts`
- `update-interests`
- `post-feed`
- `post-story`
- `set-profile-picture`
- `update-bio`

### Post output

`posts`, `feed`, and `post` return the same compact post collection used by
social search. Read `posts[]` directly; do not guess a provider GraphQL path or
pipe these commands through `jq`:

```json
{
  "format": "social_posts_v1",
  "count": 1,
  "posts": [{
    "rank": 1,
    "post_id": "...",
    "url": "https://www.instagram.com/...",
    "platform": "instagram",
    "created_at": "2026-08-04T19:03:58+00:00",
    "post_created_at": {"utc":"...","user_local":"...","user_timezone":"..."},
    "username": "account",
    "post_caption": "..."
  }],
  "next_cursor": "...",
  "has_next_page": true
}
```

`created_at` remains for compatibility; prefer `post_created_at.user_local`
when presenting a post time. Fields unavailable in the provider response are omitted. A feed item can omit
`url` or `created_at`; for a selected item that will be quoted, dated, or linked,
run `post --id <post_id>` and use the hydrated record. A valid partial response
includes the provider's reason in optional `provider_error`; do not describe it
as a complete page. If required post data is absent, the CLI fails and includes
that reason when the provider supplied one. Without a provider reason, it
reports the schema mismatch rather than returning an empty post list.

### Global options
- `--account-id <user_own_fbid>` **(required for all commands except `accounts`)** — select which Instagram account to operate on. The value must be the authenticated user's own `user_fbid` field from the `accounts` command response — do not use any other user's ID. Always call `accounts` first to obtain this value. If `accounts` returns multiple entries, ask the user which account to use before proceeding.
- `--retries <N>` — retry transient failures (default: 0).
- `--after <cursor>` — pagination cursor from the previous response. Omit to fetch the first page. Available on all paginated commands.

## Commands

### Accounts
List Instagram accounts associated with the currently authenticated user.

```sh
instagram-cli accounts
```

### Profile
Fetches Instagram profile bio, including follower/following counts. Omit `--username` and `--profile-url` to fetch the user's own profile. Otherwise, provide a username/handle or a profile URL to fetch another user's profile. If you just want counts instead of the actual list of followers/following, use this (it's cheaper/faster).
```sh
instagram-cli profile --account-id <user_own_fbid>
instagram-cli profile --account-id <user_own_fbid> --username <username>
instagram-cli profile --account-id <user_own_fbid> --username @<username>
instagram-cli profile --account-id <user_own_fbid> --profile-url https://instagram.com/<username>
```

### Update bio
Update the user's Instagram profile bio. `--bio` is required and may contain at
most 150 characters. Pass an empty string to clear the bio.

```sh
instagram-cli update-bio --account-id <user_own_fbid> --bio "Photographer and traveler"
```

### Current interests
Returns topics the user is interested in or uninterested in. Do not distinguish between inferred and explicit interests when presenting results to the user — just show the topic and its type.
```sh
instagram-cli current-interests --account-id <user_own_fbid>
```

### Update interests
Mark a topic as "interested" so the user sees more of it on Instagram, or as "not interested" so the user sees less of it.

```sh
instagram-cli update-interests --account-id <user_own_fbid> --text "cooking" --interested true
instagram-cli update-interests --account-id <user_own_fbid> --text "politics" --interested false
```

### Posts
Omit `--username` and `--user-id` to fetch the user's own posts. Otherwise, provide one or more usernames or one or more user IDs to fetch other users' posts. Do not mix usernames and user IDs in the same command.
Use the previous response's `page_info.end_cursor` as `--after`. Omit on first request.
Available filters mirror the shared Clippy post query where supported: `--since`, `--until`, `--sort-order asc|desc`, `--limit`, and repeated/comma-separated `--post-types` values such as `POST`, `REEL`, `STORY`, or `HIGHLIGHT`.

```sh
instagram-cli posts --account-id <user_own_fbid>
instagram-cli posts --account-id <user_own_fbid> --after <cursor>
instagram-cli posts --account-id <user_own_fbid> --username <username>
instagram-cli posts --account-id <user_own_fbid> --username <username>,<username>
instagram-cli posts --account-id <user_own_fbid> --user-id <FBID>
instagram-cli posts --account-id <user_own_fbid> --user-id <FBID>,<FBID>
instagram-cli posts --account-id <user_own_fbid> --username <username> --since 2026-01-01 --until 2026-02-01 --sort-order asc --limit 25 --post-types POST,REEL
```

### Followers
Fetch the user's own follower list. `--count` is optional and defaults to `200`.
Use the previous response's `page_info.end_cursor` or `next_max_id` as `--after`. Omit on first request.

```sh
instagram-cli followers --account-id <user_own_fbid>
instagram-cli followers --account-id <user_own_fbid> --count 25
instagram-cli followers --account-id <user_own_fbid> --after <cursor>
```

### Following
Fetch the user's own following list. Other users' following lists are not supported. `--count` is optional and defaults to `200`.
Use the previous response's `page_info.end_cursor` or `next_max_id` as `--after`. Omit on first request.

```sh
instagram-cli following --account-id <user_own_fbid>
instagram-cli following --account-id <user_own_fbid> --count 25
instagram-cli following --account-id <user_own_fbid> --after <cursor>
```

### Close friends
Returns the user's current Instagram close friends list.

This is the user's own curated Close Friends list on Instagram. It is not ranked or inferred. To get an inferred list of people the user interacts with most, use the `top-recipients` command from the `instagram_messages` skill instead.

```sh
instagram-cli close-friends --account-id <user_own_fbid>
```

### Feed
Following feed:
```sh
instagram-cli feed --account-id <user_own_fbid> --variant following
```

Close-friends feed:
```sh
instagram-cli feed --account-id <user_own_fbid> --variant favorites
```

`--variant` is REQUIRED and only `following` and `favorites` are supported; the ranked home timeline is not readable through this surface (omitting the variant fails fast with this rule).

For all feed variants, use the previous response's `page_info.end_cursor` as `--after`. Omit on first request.

```sh
instagram-cli feed --account-id <user_own_fbid> --variant following --after <cursor>
```

### Activity notifications
Returns `notifications` and `priority_notifications` without marking them seen.
Paginate with `page_info.end_cursor` as `--after`.

```sh
instagram-cli activity-notifications --account-id <user_own_fbid> [--after <cursor>]
```

### Other user's profile
Fetch another user's profile by user ID, username, or profile URL. Prefer `--user-id` when you already have a user FBID from prior tool output.

```sh
instagram-cli user-profile --account-id <user_own_fbid> --user-id 18841401449726893
instagram-cli user-profile --account-id <user_own_fbid> --username @<username>
instagram-cli user-profile --account-id <user_own_fbid> --profile-url https://instagram.com/<username>
```

### Tagged posts
Fetch posts a user has been tagged in. Omit `--user-id` to fetch the user's own tagged posts. Otherwise, `--user-id` should be the target user's FBID.
Use `--since`, `--until`, `--sort-order`, and `--limit` to narrow the shared engagement query.

```sh
instagram-cli tagged-posts --account-id <user_own_fbid>
instagram-cli tagged-posts --account-id <user_own_fbid> --after <cursor>
instagram-cli tagged-posts --account-id <user_own_fbid> --user-id 18841401449726893
instagram-cli tagged-posts --account-id <user_own_fbid> --user-id 18841401449726893,18841401449726894 --since 2026-01-01 --until 2026-02-01 --sort-order asc --limit 25
```

### Post by ID or URL
Fetch a single post by its media ID or full Instagram post/reel URL. Provide
exactly one of `--id` or `--url`.

```sh
instagram-cli post --account-id <user_own_fbid> --id 3599891547851922338_14631749
instagram-cli post --account-id <user_own_fbid> --id 3599891547851922338
instagram-cli post --account-id <user_own_fbid> --url https://www.instagram.com/p/SHORTCODE/
instagram-cli post --account-id <user_own_fbid> --url https://www.instagram.com/reels/anfiurkjnwed
```

### Post comments
Fetch comments for one or more posts by media ID. Pass a comma-separated list to `--post-ids`; batch multiple IDs into a single call instead of calling this command per post.Use `--since`, `--until`, `--sort-order`, `--limit`, and repeated/comma-separated `--author-ids` filters when needed.

```sh
instagram-cli fetch-post-comments --account-id <user_own_fbid> --post-ids 3599891547851922338
instagram-cli fetch-post-comments --account-id <user_own_fbid> --post-ids 3599891547851922338,3599891547851922339
instagram-cli fetch-post-comments --account-id <user_own_fbid> --post-ids 3599891547851922338 --limit 25 --after <cursor>
instagram-cli fetch-post-comments --account-id <user_own_fbid> --post-ids 3599891547851922338 --since 2026-01-01 --until 2026-02-01 --author-ids 18841401449726893
```

### Post likers
Fetch likers for one or more posts by media ID. Pass a comma-separated list to `--post-ids`; batch multiple IDs into a single call instead of calling this command per post.Use `--since`, `--until`, `--sort-order`, `--limit`, and repeated/comma-separated `--reactor-ids` filters when needed.

```sh
instagram-cli fetch-post-likers --account-id <user_own_fbid> --post-ids 3599891547851922338
instagram-cli fetch-post-likers --account-id <user_own_fbid> --post-ids 3599891547851922338,3599891547851922339
instagram-cli fetch-post-likers --account-id <user_own_fbid> --post-ids 3599891547851922338 --limit 25 --after <cursor>
instagram-cli fetch-post-likers --account-id <user_own_fbid> --post-ids 3599891547851922338 --since 2026-01-01 --until 2026-02-01 --reactor-ids 18841401449726893
```

### Saved posts
Fetch the user's saved posts. Include an optional collection_id to fetch posts saved within a particular collection (you can get the `collection_id` from the `saved-collections` command).
Without `--collection-id`, `saved-posts` uses the shared engagement query and supports `--since`, `--until`, `--sort-order`, and `--limit`.

```sh
instagram-cli saved-posts --account-id <user_own_fbid>
instagram-cli saved-posts --account-id <user_own_fbid> --after <cursor>
instagram-cli saved-posts --account-id <user_own_fbid> --since 2026-01-01 --until 2026-02-01 --sort-order asc --limit 25
instagram-cli saved-posts --account-id <user_own_fbid> --after <cursor> --collection-id "2949392323392323"
```

### Saved collections
Fetch the user's saved collections (folders/categories of saved posts).

```sh
instagram-cli saved-collections --account-id <user_own_fbid>
instagram-cli saved-collections --account-id <user_own_fbid> --after <cursor>
```

### Manage saved posts and collections

```sh
instagram-cli create-saved-collection --account-id <user_own_fbid> --name "Travel"
instagram-cli rename-saved-collection --account-id <user_own_fbid> --collection-id 2949392323392323 --name "Japan"

instagram-cli save-post --account-id <user_own_fbid> --media-ids 3599891547851922338
instagram-cli save-post --account-id <user_own_fbid> --media-ids 3599891547851922338,3599891547851922339 --collection-id 2949392323392323

instagram-cli unsave-post --account-id <user_own_fbid> --media-ids 3599891547851922338 --collection-id 2949392323392323
instagram-cli unsave-post --account-id <user_own_fbid> --media-ids 3599891547851922338
```

Saving with a collection both saves the post and adds it to that collection. Unsaving with a collection only removes it from that collection; omitting `--collection-id` unsaves it globally.

### Own stories
Fetch the user's own currently posted Instagram stories.

```sh
instagram-cli own-stories --account-id <user_own_fbid>
```

### Stories archive
Fetch the user's own Instagram story archive. Use the previous response's `next_max_id` as `--max-id` to paginate. Omit on first request. If an item in the response has a non-empty video url, select that over the image url.

```sh
instagram-cli own-stories-archive --account-id <user_own_fbid>
instagram-cli own-stories-archive --account-id <user_own_fbid> --max-id <cursor>
```

### Stories tray
Fetch the user's stories tray (currently available stories posted by people the user follows). `--count` is optional and defaults to `200`. The response contains **only media IDs** — no links, images, or video. To get an actual media permalink for a specific story, pass its ID to `story-media`.

```sh
instagram-cli stories-tray --account-id <user_own_fbid>
instagram-cli stories-tray --account-id <user_own_fbid> --count 25
```

Be judicious about following up with `story-media`: do **not** eagerly fetch media for every story in the tray. Only fetch media for IDs the user explicitly asks about, or a small subset they've clearly requested.

### Story media
Fetch media metadata (permalink, posted-at time, expires-at time) for one or more story items by ID. Pass a comma-separated list to `--ids`; batch multiple IDs into a single call instead of calling this command per item.

```sh
instagram-cli story-media --account-id <user_own_fbid> --ids 18103150772488230
instagram-cli story-media --account-id <user_own_fbid> --ids 18103150772488230,55858390399494949
```

### Location search
Search Instagram locations with required `--search-query`. Optionally pass
both `--latitude` and `--longitude` to narrow the results.

```sh
instagram-cli location-search --account-id <user_own_fbid> --search-query "Central Park"
instagram-cli location-search --account-id <user_own_fbid> \
  --search-query "Central Park" --latitude 40.7829 --longitude -73.9654
```

Before passing media to `post-story`, `post-feed`, or `set-profile-picture`,
ensure that every media and cover file is in the workspace path. If it is not,
copy it to the workspace. Never use a `/tmp` path.

### Publish story
Publish one JPEG, PNG, static WebP, MP4, or MOV file, preferably vertical 9:16
at 1080 x 1920 px. Strongly avoid letterboxing. `--file` is required and
limited to 100 MB. Directly posted videos require a matching JPEG, PNG, or
static WebP `--cover`; videos edited with stickers or text generate their cover
automatically.

Use `post-story --draft` with `--file` and `--editor-json` for all visible Story
text and supported native stickers. First run
`instagram-cli post-story --help` and follow its detailed parameter, text, sticker,
geometry, and media contract. Draft mode renders under
`workspace/instagram/stories` without posting. Always render from the same clean
media for revisions, show the returned media inline, and ask the user to confirm
it before posting. Record every returned draft output and cover path. After
confirmation, rerun the same command without `--draft`; it renders the approved
edit in the same directory and posts that output. Once publishing succeeds,
delete every earlier draft and draft cover by its exact recorded path. Keep the
last user-approved draft and the final published render, and never use a glob.

Only mention, location, and link native stickers are supported; refuse all
others. For a location sticker, select a result with `location-search` and
include its `location_id` in the location object passed to `--editor-json`.
Mention objects require `user_fbid`; link objects require `url`.

The final command automatically uploads the rendered output and its video cover:

```sh
EDITOR_JSON='[
  {"type":"text","text":"SUMMER IN NYC","style":"poster","x":0.5,"y":0.2},
  {"type":"mention","text":"@friend","user_fbid":"123","style":"default","x":0.5,"y":0.4},
  {"type":"location","text":"Central Park","location_id":"456","style":"default","x":0.5,"y":0.65},
  {"type":"link","text":"Learn more","url":"https://example.com","style":"default","x":0.5,"y":0.82}
]'

instagram-cli post-story --draft --account-id <user_own_fbid> \
  --file <clean-media> --editor-json "$EDITOR_JSON"

instagram-cli post-story --account-id <user_own_fbid> --file <clean-media> \
  --editor-json "$EDITOR_JSON"
```

### Publish feed post
Publish media to the user's feed. `post-feed` selects the post type from the
files supplied:

- One JPEG or PNG image or static WebP image publishes a regular image post.
  Prefer portrait 4:5 at 1080 x 1350 px; square 1:1 at 1080 x 1080 px is also
  suitable.
- One MP4/MOV publishes a reel shared to the feed and profile grid. Use vertical
  9:16 video, preferably 1080 x 1920 px, and pass a matching JPEG, PNG, or
  static WebP `--cover`.
- Two or more JPEG, PNG, static WebP, MP4, or MOV files publish a carousel in
  the order supplied. Image, video, and mixed image/video carousels are
  supported. Keep all items at the same aspect ratio and dimensions, preferably
  4:5 at 1080 x 1350 px.

Each file may be at most 100 MB. `--caption` is optional, may include hashtags
and textual @mentions, and is limited to 2,200 characters. Whitespace-only
captions are treated as absent. `--mentions` takes a JSON array of user tags.
Each tag requires `user_fbid`; optional `x` and `y` coordinates run from 0 to 1
and default to 0.5. On a carousel, the CLI applies the supplied user tags to
every item.

For video media, `--video-thumbnail-playback-offset-ms` optionally selects a
non-negative video frame for the final thumbnail. Each video requires a JPEG,
PNG, or static WebP `--cover`, shown until frame extraction finishes. For a
carousel, repeat `--cover` once per video in the same order as the video files;
image items do not take covers. Do not pass either video option for an
image-only post or carousel.

```sh
# Image post
instagram-cli post-feed --account-id <user_own_fbid> \
  --file /path/to/post.jpg --caption 'A feed caption' \
  --mentions '[{"user_fbid":"<tagged_user_fbid>","x":0.5,"y":0.5}]'

# Reel shared to feed
instagram-cli post-feed --account-id <user_own_fbid> \
  --file /path/to/reel.mp4 --cover /path/to/cover.jpg \
  --video-thumbnail-playback-offset-ms 1200 \
  --caption 'A caption with #hashtags and @mentions'

# Mixed carousel; file order is display order and cover order follows videos
instagram-cli post-feed --account-id <user_own_fbid> \
  --file /path/to/first.jpg --file /path/to/second.mp4 \
  --cover /path/to/second-cover.jpg \
  --caption 'A carousel caption'
```

Do not use `--retries` for posting because an automatic retry could publish a
duplicate. Instagram also enforces a per-account daily publish limit.

### Set profile picture
Pass exactly one square (1:1) JPEG or PNG, preferably at least 320 x 320 px and
no larger than 1080 x 1080 px. The file may be at most 100 MB.

```sh
instagram-cli set-profile-picture --account-id <user_own_fbid> \
  --file /path/to/profile.jpg
```

### Media understanding
Fetch media descriptions for one or more Instagram media FBIDs, including narrative summary and semantic understanding. Pass a comma-separated list to `--media-ids`; batch multiple IDs into a single call instead of calling this command per item.

```sh
instagram-cli media-understanding --account-id <user_own_fbid> --media-ids 18103150772488230
instagram-cli media-understanding --account-id <user_own_fbid> --media-ids 18103150772488230,55858390399494949
```

### Recently liked posts
Fetch posts the user has recently liked.

```sh
instagram-cli recently-liked-posts --account-id <user_own_fbid>
instagram-cli recently-liked-posts --account-id <user_own_fbid> --limit 5
instagram-cli recently-liked-posts --account-id <user_own_fbid> --limit 10 --after <cursor>
instagram-cli recently-liked-posts --account-id <user_own_fbid> --since 2026-01-01 --until 2026-02-01 --sort-order asc
```

### Recently commented posts
Fetch posts the user has recently commented on.

```sh
instagram-cli recently-commented-posts --account-id <user_own_fbid>
instagram-cli recently-commented-posts --account-id <user_own_fbid> --limit 5
instagram-cli recently-commented-posts --account-id <user_own_fbid> --limit 10 --after <cursor>
instagram-cli recently-commented-posts --account-id <user_own_fbid> --since 2026-01-01 --until 2026-02-01 --sort-order asc
```

### Analytics workflows

Before analyzing Instagram performance, load the workflow skill that owns the
request:

- Use `social_content_performance` for the user's own accounts, posts, or
  historical results.
- Use `social_competitor_analysis` for competitor, peer, or category
  comparisons.
- When every account belongs to the user, use `social_content_performance`.

## Output
The CLI prints JSON to stdout. Post reads use the normalized collection above;
other commands retain their provider-specific decoded JSON. When presenting
results to the user, focus on meaningful content (names, text, images/video,
links, captions etc.). Never expose raw IDs, cursors, unix timestamps, internal
metadata, or implementation details; keep them only in tool calls.
