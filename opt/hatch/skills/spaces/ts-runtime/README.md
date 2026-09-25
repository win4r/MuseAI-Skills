# TypeScript Web Artifact Runtime

Source for the `@hatch/space-sdk` package consumed by every TypeScript web artifact.

Current TypeScript web artifacts are built by the web artifact builder subagent through the
Rust `web_artifacts.build` tool, which calls `hatch_spaces::build_pipeline::build_space`.
The canonical source root is `workspace/ts-spaces/<slug>`.

## Layout

```
ts-runtime/
├── build.mjs           # produces the local Bun runtime artifacts
├── cloudflare/         # explicit Worker build/typecheck tooling
│   └── tsconfig.worker.base.json
├── sdk/                # @hatch/space-sdk package source
│   ├── package.json
│   ├── tsconfig.json
│   └── src/
│       ├── index.ts    # server-side surface (defineAction, Ctx, ActionsModule, …)
│       └── client.ts   # browser-side surface (createActionClient)
└── dist/               # gitignored; populated by build.mjs
    └── space-sdk.tgz   # vendored into each TS web artifact via `file:` dep
```

## Building

Local Bun runtime artifacts:

```bash
cd skills/spaces/ts-runtime
bun build.mjs
```

Output lands at `dist/space-sdk.tgz`. Bundle build wires this into the deployed
bundle so `/opt/hatch/skills/spaces/ts-runtime/dist/space-sdk.tgz` exists at
runtime; each scaffolded space's `package.json` references it via
`"@hatch/space-sdk": "file:/opt/hatch/skills/spaces/ts-runtime/dist/space-sdk.tgz"`.

## Cloudflare Worker Export

Cloudflare export is intentionally explicit and is not run by normal
`web_artifacts.build` yet:

```bash
cd skills/spaces/ts-runtime
bun cloudflare/build-cloudflare.mjs \
  --space-dir "$JARVIS_HOME/workspace/ts-spaces/<slug>" \
  --out-dir /tmp/<slug>-cloudflare
```

The exporter writes:

- `worker.js`: bundled Worker action dispatcher.
- `deploy-manifest.json`: Worker source, client files from `client/dist`, and
  SQL migrations from `drizzle/*.sql`.

### Initial Cloudflare Database Seed

The Cloudflare deploy manifest may include an `initialDbSnapshot` field when a
local VM web artifact is shared to Cloudflare for the first time:

```json
{
  "runtime": "hatch-ts-cloudflare-v1",
  "slug": "my-space",
  "name": "My Web Artifact",
  "workerJs": "...",
  "migrations": [],
  "clientFiles": [],
  "initialDbSnapshot": {
    "runtime": "hatch-local-sqlite-snapshot-v1",
    "shortcode": "abc123",
    "slug": "my-space",
    "exportedAtMs": 1725000000000,
    "schemaWatermark": null,
    "payload": {
      "kind": "sqlite_sql",
      "sql": "<sqlite dump sql>"
    }
  }
}
```

`initialDbSnapshot` is a one-way local SQLite seed for Cloudflare D1. Jarvis
clones the local `app.db`, exports the clone as SQL, and includes that SQL in
the deploy manifest. The seed rides on the existing
`POST /space-deploy/spaces/{shortcode}/deploy` control-plane route, so no
additional Stefi proxy route is required for the initial local-to-Cloudflare
copy.
The runtime string is the
`CLOUDFLARE_INITIAL_DB_SNAPSHOT_RUNTIME` wire contract.

Control-plane contract:

- Missing `initialDbSnapshot` preserves the current deploy behavior: create or
  update the Worker, publish client files, and apply SQL migrations.
- When present, `runtime` must match
  `CLOUDFLARE_INITIAL_DB_SNAPSHOT_RUNTIME`, and the snapshot `shortcode` and
  `slug` must match the deployment being handled.
- The control plane treats the snapshot as the full initial D1 state. It
  restores the snapshot before worker deployment and does not replay manifest
  migrations on top of it.
- If Cloudflare reports that the target D1 database is already initialized, the
  control plane treats the seed as already applied and continues with worker
  deployment. A future replace/reset flow must be explicit.
- Blob objects are not included. Existing local `ctx.blobs` data remains local
  until a separate blob migration or remote-blob review path is implemented.

The build generates a Worker tsconfig and typechecks the space's
`server/src/actions.ts` against a Cloudflare-only `@hatch/space-sdk` shim. That
shim exposes the portable `ctx.db` surface backed by D1 and omits local-only
APIs such as `ctx.inference`, `ctx.agent`, and `ctx.emit`, so unsupported action
code fails through TypeScript rather than source scanning. `SpaceDb` deliberately
does not expose `transaction`.

## Blob Storage

Local TypeScript web artifact actions can use `ctx.blobs` for binary or opaque object
data that does not belong in `ctx.db`: generated images, thumbnails,
exports, attachments, cached API files, snapshots, and large payloads. Use
`ctx.db` for structured/queryable state, and store blob keys or searchable
metadata there when the UI needs to query across blob-backed records.

The local VM runtime initializes blob storage lazily on first use:

```text
<spaceDir>/blobs/objects/<id[0:2]>/<id>   id = sha256(key); sharded
<spaceDir>/blobs/index.sqlite
```

`index.sqlite` tracks `key`, `content_type`, `size_bytes`, `etag`,
`visibility`, `created_at_ms`, `updated_at_ms`, and `object_id`. `etag` is
currently a SHA-256 fingerprint of the stored bytes. Object bytes live under a
hashed, sharded `object_id` path rather than `objects/<key>`, so keys may be
long or contain reserved characters without hitting filesystem name limits;
keys are never used as filesystem paths. Blobs written before this change have
a null `object_id` and are read from the legacy `objects/<key>` path (the
served URL is an opaque base64url token regardless).

Example:

```ts
await ctx.blobs.put("images/avatar.png", bytes, {
  contentType: "image/png",
});
const meta = await ctx.blobs.head("images/avatar.png");
const url = await ctx.blobs.getUrl("images/avatar.png", {
  expiresInSeconds: 600,
});
```

`getUrl()` asks the runtime to mint a fetchable blob URL. Local Muse VM web artifacts
return a document-relative `./blobs/<key>` URL served by the daemon under nginx
bearer auth — relative so it resolves against the `/spaces/v2/<slug>/` document
base whether that sits at the origin root (prod) or behind a `/backend/<sid>/`
reverse-proxy prefix (annotation rig). Cloudflare web artifacts return a Worker-relative
`./blobs/public/<key>` or `./blobs/private/<key>?token=...` URL backed by the
per-web-artifact R2 bucket bound as `BUCKET`, with HMAC-signed tokens for private
blobs.

Run the local Cloudflare exporter tests with:

```bash
bun test cloudflare/build-cloudflare.test.mjs
```
