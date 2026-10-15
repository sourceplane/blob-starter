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
| Deploy on push | Orun: `apps/web/component.yaml` renders the config for `$ORUN_ENVIRONMENT`, builds, and deploys `blob-starter-web-{stage,prod}` on merge to `main` once the product is linked — after the bucket's apply (BL4) |

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
carries `@@wiring(cloudflare-r2/__ENV__:r2_bucket_name)@@`; `pnpm run
wire:fixture` renders from `wiring.fixture.json` (and, since BL4, that
render is the committed `wrangler.jsonc`, because the deploy lane checks it
exists before it builds — risk BL-E), the stage and prod lanes from
`WIRING_CLOUDFLARE_R2_<ENV>`, and dev, which no root applies to, from the
fixture (BL-F); `wrangler dev` and `next dev` (through
`initOpenNextCloudflareForDev()`) get a local bucket.

## 5. The repository

```
apps/web                      the template + the Workers build
  lib/blob/client.ts          the browser upload helper (replaces @vercel/blob/client)
  lib/blob/server.ts          the bucket, the checks, the suffix (replaces @vercel/blob)
  app/api/upload/route.ts     PUT: validate and store
  app/api/blob/route.ts       GET: stream a private object
  app/site.ts                 the site's name and source link (BL4: the rename seam) + the request origin
  wrangler.template.jsonc     worker name, nodejs_compat, ASSETS, the BLOB binding as a wiring token
  wiring.fixture.json         offline bucket names for local work and the verify lanes (dev, stage, prod)
  wrangler.jsonc              the fixture render, committed (BL4)
  cloudflare-env.d.ts         the bindings' types
infra/terraform/cloudflare-r2 the bucket per environment
tests/web                     vitest: both routes against an in-memory bucket, the helpers
```

## 6. Out of scope

Authentication (the template's ⚠️ comments stay where they were), public
buckets or custom domains for direct delivery, multipart uploads above the
Worker's request limit, image resizing.

## 7. The baseline (BL4)

The repository instantiates new products the way
[cirrus-baseline](https://github.com/sourceplane/cirrus-baseline) does since
its one-landing bootstrap (`baseline-v22`): a console card (`blueprint.yaml`)
the platform renders, a build document (`repo-blueprint.yaml`) `orun new`
runs, and a rename engine that makes the copy somebody else's. What a small
product carries besides — the product README, the context pack, the
deployment-record hook, the bootstrap helpers and the offline test suite —
is `portfolio-starter-kit`'s `baseline-v2`, as ported to Cloudflare by
`kv-redis-starter`'s KR4.

| | portfolio-starter-kit (`baseline-v2`) | cirrus-baseline (`baseline-v22`) | here |
|---|---|---|---|
| phases | three: `01-scaffold`, `02-site`, `03-docs` | `01-product`, `07-domain` (optional), `08-docs` | two: `01-product`, `02-docs` |
| the order a landing used to hold | the scaffold before the site | the data plane before the fleet, the fleet before its bindings | the R2 bucket before the Worker that binds it |
| how the plan holds it instead | — | enforced `dependsOn` on main (advisory on a PR) | `apps/web` `dependsOn: cloudflare-r2`, `mode: enforced` with `modeRules` advisory on `github-pull-request` |
| brokered secrets | `CLOUDFLARE_API_TOKEN` (`workers-deploy`), `CLOUDFLARE_ACCOUNT_ID` | + `CLOUDFLARE_D1_TOKEN` (`d1-edit`) | + `CLOUDFLARE_R2_TOKEN` (`r2-data`): the deploy token cannot touch R2, so the bucket's apply has its own, as cirrus's D1 root does |
| the landing's await | watch, probe | watch, `WIRING_CLOUDFLARE_D1`/`_KV` exist on stage and prod, probe | watch, `WIRING_CLOUDFLARE_R2` exists on stage and prod, probe |
| task contracts | `.baseline/tasks/` | `tasks/` | `.baseline/tasks/` — `tasks/` is this repository's own work tree |
| stack-tectonic | 0.19.0 | 0.20.0 | 0.19.0 (Next 16's Turbopack refuses 0.20.0's out-of-tree install) |

**One landing.** `01-product` places every module, brands the tree, mints
the three keys, and lands it as one pull request whose checks it waits for
(Checks: install, the fixture render, typecheck, lint, test, build). The
convergence after the merge plans `cloudflare-r2` (apply, with the r2-data
key) and `web` (deploy, with the workers-deploy key) on stage and prod; the
web lanes are one level below the R2 lanes, so each Worker deploy starts
after its environment's apply — and since a job resolves its secrets when
it starts, the `WIRING_CLOUDFLARE_R2_<ENV>` it renders from is there. Stage
and prod run side by side (the promotion gate is deferred until `02-docs`),
and dev's push lanes are deferred too. The landing then waits on the
convergence (`orun.run/watch@v1`), asks the platform that the wiring exists
on both environments (`orun.secrets/exists@v1`), and probes both URLs.
`02-docs` places nothing: it restores the two deferrals, renders the
deployment record and lands it.

**Uploads on a fresh build.** Nothing in the product needs a key the
platform cannot broker: the Worker's `BLOB` binding is its storage
credential, so the first deploy stores and serves files. The smoke proves
the binding without writing — the delivery route asked for a name nobody
stored answers its own `Not found` 404 only after reading the bucket — and
the deployment record's probe does the same.

**Identity in the app** is `apps/web/app/site.ts`: `SITE_NAME` (the heading
and `<title>`) and `SOURCE_URL` (the "Deploy your own" pill and the footer's
Source link, which pointed at the upstream template's directory — a URL that
contains this baseline's slug, which the rename would have rewritten into a
broken link). The name is written with `JSON.stringify`, so any name the
card's pattern admits stays a valid string. The slug also names the R2
buckets (`stg-<slug>-stage`) through terraform's `repo`, so two products in
one account never collide on a name.

**No `SITE_URL`.** The only absolute link the page renders to itself is the
Open Graph image, which Next resolves against `metadataBase` — and, unset,
against `http://localhost:3000`. `generateMetadata` sets `metadataBase` to
the request's own origin: right on workers.dev, on a custom domain, and
under `wrangler dev`, with nothing to configure.

**Testing without the platform.** `testing/lib/bootstrap.sh` places both
phases and runs the blueprint's own `run:` hooks, read out of the document;
`testing/placement.test.sh` plans the product's own merge (the R2 apply
first, each job with its own key) and a pull request (nothing waits);
`testing/wire.test.sh` holds the wiring path together; `testing/e2e.test.sh`
builds the product in the tree orun stages, with the stage wiring document
in the job's environment, dry-deploys it, serves it, runs its smoke and
round-trips an upload.
