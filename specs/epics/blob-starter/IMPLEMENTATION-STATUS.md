# blob-starter (BL) — Implementation status

As-built ≠ intent. This file records what actually shipped, and every place
the code departed from `design.md` or from the upstream template.

| Milestone | State | PR |
|---|---|---|
| BL0 — the spec | | |
| BL1 — uploads on R2 | | |
| BL2 — the R2 bucket from Terraform | | |
| BL3 — ready to instantiate | | |

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
