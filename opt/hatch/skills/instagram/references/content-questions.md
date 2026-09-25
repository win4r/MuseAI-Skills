# Instagram content questions

Use the post to answer the user's question. Get what the question needs, answer it, and skip lookups you don't need.

## Read the available evidence

Follow the Instagram skill's account rules and retrieve the supplied URL with `instagram-cli post`. Fetch the exact URL the user sent, and check the post you got back is really the one they linked. Use returned IDs for subsequent commands; do not derive an ID from the shortcode. If native authentication is unavailable, use independently authorized public social or browser access.

Read the caption, creator links, and relevant descriptions or comments. `instagram-cli media-understanding` returns stored text, not fresh image analysis or video. An empty field just means nothing was stored, not that the detail isn't in the video, and calling it again won't analyze anything new.

Save complete JSON and inspect the fields relevant to the question, including nested descriptions and product or brand annotations. Read the whole response, not just the first chunk or the URLs. Inspect the returned structure before selecting fields; a description may be a list. Keep track of who said each comment, and whether you saw all of them or just the first page.

If native reads lack the needed context, choose one fallback: `social.search` with the exact `post_url`, or raw Zeitgeist when you need stored annotations or media locations:

```sh
hatch-zeitgeist --post-url '<exact supplied URL>' --raw --no-save > '<work directory>/enriched.json'
```

Read the relevant fields in that saved response before seeking more media. `--raw` preserves `content_understanding`, which normal social output omits. Product and brand annotations may be machine guesses: treat them as leads, and don't claim an exact match until you've checked it yourself. A thumbnail can be present even when `media` is null.

A public post or reel link does not need a connected account: fetch it with `instagram-cli post --url` before deciding a link can't be read.

## Inspect unresolved visual details

Use a post image or a frame that shows the item, not the creator's avatar. Preserve the complete returned signed image URL, download it successfully, and use `muse.read` on the local file to inspect it. A reel thumbnail may show a different moment from the one you need.

If needed, ask `browser.spawn_task` to inspect the supplied post for the specific unanswered detail. Have it play or pause using visible controls, inspect relevant frames with `muse.automation` look, and report what it saw and anything it couldn't play or open. Ask it to return any usable direct video URL with its source promptly. With authorized video bytes, use local ffmpeg to extract relevant frames and read them. Do not send video files or URLs to third-party conversion services or bypass access denials.

`browser.open` reads page text; it does not watch video, and instagram.com, facebook.com, and threads.com links are blocked for it. Don't spend a step on it for a post URL; use the native tools or a browser task instead. Not seeing inside the video is not evidence the logo or product isn't there. A matching creator crosspost may supply missing evidence; confirm it is the same content.

## Finish the user's task

Share your best answer as soon as you have one: give the identification and the links you've already found, then improve on it if a later check adds something. Don't end with only a promise when you already have something shareable.

For buying or matching an item, read the shopping skill and perform the requested search. Identify the depicted item before asking for fit or preferences; ask when choosing a variant or alternatives depends on them. When the match depends on visual details, compare candidate images with the source. Label alternatives honestly and follow shopping's validation and presentation rules. If they asked where to buy it, that's your go-ahead: find buying options, don't ask permission.

For questions about people or claims, use explicit attribution and credible public sources. The uploader is not necessarily the person depicted; do not identify people from their faces. A missing tag, bio detail, or search result does not prove a claim false or a product unavailable. Carry those caveats into anything you hand to another tool and into your answer, and name the specific thing you couldn't confirm.
