# blob-starter — design

## 1. What the template is

One page with `<Uploader />`: pick or drop an image (image/* only, 50MB
max, checked in the browser), preview it, upload with a progress bar, get a
toast with a "View file" link. `POST /api/upload` runs Blob's
`handleUpload` (mints a client token with `allowedContentTypes`,
`addRandomSuffix`, `maximumSizeInBytes`; logs completion). `GET
/api/blob?pathname=` streams a private blob with its content type.

## 2. The mapping (Vercel → Cloudflare)

| Vercel primitive the template uses | Here |
|---|---|
| Next.js hosting | Cloudflare Workers + Static Assets; the Worker is `@opennextjs/cloudflare`'s output |
| Vercel Blob store (`BLOB_READ_WRITE_TOKEN`) | R2 bucket bound as `BLOB`; no token, the binding is the credential |
| `upload()` from `@vercel/blob/client` (token handshake, direct upload, progress) | `lib/blob/client.ts` `upload()`: same signature, `PUT /api/upload?pathname=` over XHR with progress; resolves `{ pathname, contentType, size }` |
| `handleUpload` in `POST /api/upload` | `PUT /api/upload`: image/* only, 50MB max (header and body), random suffix (`withRandomSuffix`), `BLOB.put` with the content type, the same completion log |
| `get(pathname, { access: 'private' })` in `GET /api/blob` | `BLOB.get(pathname)` streamed with content type, length, ETag, `nosniff` |
| `images.domains` for the Blob host | Not needed: delivery is this app's own route |
| A store created in the dashboard | `infra/terraform/cloudflare-r2`: one bucket per environment, name published as the `WIRING_CLOUDFLARE_R2` secret |
| Deploy on push | Orun: `apps/web/component.yaml` renders the config for `$ORUN_ENVIRONMENT`, builds, and deploys `blob-starter-web-{stage,prod}` on merge to `main` once the product is linked |

Alternative rejected: presigned R2 PUT URLs minted by the route (the
closest shape to Blob's token handshake). They need the S3 API with an
access key pair — a second credential the Cirrus baseline would have to
broker — and they move the content-type and size checks off the server.
The Worker route keeps one credential (the binding) and the checks where
the template put them; 50MB through a Worker is well inside its limits.

## 3. The upload flow

```
browser  ── PUT /api/upload?pathname=photo.png (body: the file, Content-Type: image/png) ──►  Worker
                                                                                               │ isAllowedContentType, MAX_UPLOAD_BYTES
                                                                                               │ BLOB.put("photo-<suffix>.png", bytes, {httpMetadata})
         ◄── { pathname, contentType, size } ─────────────────────────────────────────────────┘
browser  ── GET /api/blob?pathname=photo-<suffix>.png ──►  Worker ── BLOB.get ──► stream + Content-Type
```

## 4. The wiring flow

Same as kv-redis-starter with the R2 root: `wrangler.template.jsonc`
carries `@@wiring(cloudflare-r2/__ENV__:r2_bucket_name)@@`; the verify
lane and `pnpm run wire:fixture` render from `wiring.fixture.json`, the
deploy lane from `WIRING_CLOUDFLARE_R2_<ENV>`; `wrangler dev` and `next
dev` (through `initOpenNextCloudflareForDev()`) get a local bucket.

## 5. The repository

```
apps/web                      the template + the Workers build
  lib/blob/client.ts          the browser upload helper (replaces @vercel/blob/client)
  lib/blob/server.ts          the bucket, the checks, the suffix (replaces @vercel/blob)
  app/api/upload/route.ts     PUT: validate and store
  app/api/blob/route.ts       GET: stream a private object
  wrangler.template.jsonc     worker name, nodejs_compat, ASSETS, the BLOB binding as a wiring token
  cloudflare-env.d.ts         the bindings' types
infra/terraform/cloudflare-r2 the bucket per environment
tests/web                     vitest: both routes against an in-memory bucket, the helpers
```

## 6. Out of scope

Authentication (the template's ⚠️ comments stay where they were), public
buckets or custom domains for direct delivery, multipart uploads above the
Worker's request limit, image resizing.
