# blob-starter (BL) — Implementation status

As-built ≠ intent. This file records what actually shipped, and every place
the code departed from `design.md` or from the upstream template.

| Milestone | State | PR |
|---|---|---|
| BL0 — the spec | ✅ Shipped | [#1](https://github.com/sourceplane/blob-starter/pull/1) |
| BL1 — uploads on R2 | ✅ Shipped | [#2](https://github.com/sourceplane/blob-starter/pull/2) |
| BL2 — the R2 bucket from Terraform | ✅ Shipped (validated; apply gated on a linked workspace) | [#3](https://github.com/sourceplane/blob-starter/pull/3) |
| BL3 — ready to instantiate | ✅ Shipped | [#4](https://github.com/sourceplane/blob-starter/pull/4) |

## Departures from the upstream template

### `lib/blob/client.ts` replaces `@vercel/blob/client`

`upload(pathname, file, { handleUploadUrl, onUploadProgress })` keeps its
signature; it PUTs the file to the route over XHR (progress events) instead
of the token handshake + direct upload. `components/uploader.tsx` changes
its import line only.

### `app/api/upload/route.ts` is a PUT that stores, not a POST that mints a token

Same checks (image/*, 50MB, random suffix), `BLOB.put` instead of
`handleUpload`, the completion log inline.

### `app/api/blob/route.ts` reads R2

`BLOB.get(pathname)` streamed with content type, length, ETag and `nosniff`.

### `next.config.mjs` (ESM) with `initOpenNextCloudflareForDev()`, no Blob image domain

### Page copy and links

"Blob on Vercel" → "R2 on Cloudflare"; the Vercel Blob link → Cloudflare
R2 docs; the deploy button → this repository; the layout title → "R2 Blob
Starter".

### eslint-config-next 16 flat config, Next 16.3.8

## Verified

- Local: `pnpm run wire:fixture`, `pnpm typecheck`, `pnpm lint` (one
  upstream unused-variable warning), `pnpm test` (6 tests), `pnpm build`
  green; `wrangler dev` with a local bucket: `/` 200 ("R2 on Cloudflare"),
  `PUT /api/upload?pathname=test.png` with a PNG body 200 → `test-<suffix>.png`,
  `GET /api/blob?pathname=<that>` 200 `image/png` with byte-identical
  content, a PDF 400, a missing pathname 404.
- `terraform validate` green on `infra/terraform/cloudflare-r2`.
- CI: `Checks` green on #2 and #3.
- Not verified: the R2 apply and a live deploy — both need the product
  linked to an Orun workspace with a Cloudflare connection (`ORUN_CI`); the
  browser upload flow end to end (the client helper is exercised by the
  route tests, not by a browser).

## Versions

| Package | Version | Why |
|---|---|---|
| next | 16.3.8 | newest inside `@opennextjs/cloudflare` 1.20.11's peer range |
| @opennextjs/cloudflare | ^1.20.11 | `getCloudflareContext` for the binding; static-assets cache + `populateCache local` |
| wrangler | ^4.151.0 | compatibility_date 2026-10-01 |
