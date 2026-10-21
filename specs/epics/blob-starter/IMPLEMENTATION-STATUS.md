# blob-starter (BL) — Implementation status

As-built ≠ intent. This file records what actually shipped, and every place
the code departed from `design.md` or from the upstream template.

| Milestone | State | PR |
|---|---|---|
| BL0 — the spec | ✅ Shipped | [#1](https://github.com/sourceplane/blob-starter/pull/1) |
| BL1 — uploads on R2 | ✅ Shipped | [#2](https://github.com/sourceplane/blob-starter/pull/2) |
| BL2 — the R2 bucket from Terraform | ✅ Shipped (validated; apply gated on a linked workspace) | [#3](https://github.com/sourceplane/blob-starter/pull/3) |
| BL3 — ready to instantiate | ✅ Shipped | [#4](https://github.com/sourceplane/blob-starter/pull/4) |
| BL4 — a baseline, in one landing | ✅ Shipped (offline-proven; no live bootstrap yet, risk BL-G) | [#5](https://github.com/sourceplane/blob-starter/pull/5) (BL-5), tagged `baseline-v1` |
| BL5 — the cirrus standard, SVG uploads closed | ✅ Shipped | [#6](https://github.com/sourceplane/blob-starter/pull/6) (BL-6), [#7](https://github.com/sourceplane/blob-starter/pull/7) (BL-7), tagged `baseline-v2` |

## Departures from the upstream template

### `lib/blob/client.ts` replaces `@vercel/blob/client`

`upload(pathname, file, { handleUploadUrl, onUploadProgress })` keeps its
signature; it PUTs the file to the route over XHR (progress events) instead
of the token handshake + direct upload. `components/uploader.tsx` changes
its import line only — until BL5, which gives its file input and its check
the route's raster-only list (below).

### `app/api/upload/route.ts` is a PUT that stores, not a POST that mints a token

Same checks (image/*, 50MB, random suffix), `BLOB.put` instead of
`handleUpload`, the completion log inline. Since BL5 "image/*" is raster
images only — see the cirrus standard (BL5) below.

### `app/api/blob/route.ts` reads R2

`BLOB.get(pathname)` streamed with content type, length, ETag and `nosniff`
— and, since BL5, `Content-Security-Policy: default-src 'none'; sandbox`.

### `next.config.mjs` (ESM) with `initOpenNextCloudflareForDev()`, no Blob image domain

### Page copy and links

"Blob on Vercel" → "R2 on Cloudflare"; the Vercel Blob link → Cloudflare
R2 docs; the deploy button → this repository; the layout title → "R2 Blob
Starter". Not changed: the footer's Vercel logo
(`apps/web/public/vercel.svg`) still links vercel.com, as upstream's does.

### eslint-config-next 16 flat config, Next 16.3.8

### The page's name and source link come from `app/site.ts` (BL4)

`SITE_NAME` is the heading ("R2 on Cloudflare") and the `<title>` (which was
"R2 Blob Starter"); `SOURCE_URL` is the "Deploy your own" pill and the
footer's Source link. The footer linked the upstream template's directory,
whose URL contains this baseline's slug — the rename would have rewritten it
into a broken link — so it links the product's repository; the upstream is
credited in `apps/web/README.md` by its parent directory.

### The Open Graph image is absolute on the request's origin (BL4)

The layout's metadata is `generateMetadata`, with `metadataBase` from the
request's host (`requestOrigin` in `app/site.ts`). The upstream relied on
Vercel's `VERCEL_URL`; unset, Next resolved the image against
`http://localhost:3000`. Reading the request makes `/` render per request
(it was prerendered): the page is one uploader, and the Worker answers it
either way.

### `apps/web/README.md` is the app's, not the template's (BL4)

The upstream README advertised "Deploy with Vercel" and the Vercel Blob
dashboard, and it ships into every product.

## Departures from the port (BL4)

| What | Before | After | Why |
|---|---|---|---|
| `infra/terraform/cloudflare-r2` credentials | `CLOUDFLARE_API_TOKEN` ← the project's `CLOUDFLARE_API_TOKEN` (the `workers-deploy` key, which grants Workers Scripts and KV — NOT R2) | `CLOUDFLARE_API_TOKEN` ← `CLOUDFLARE_R2_TOKEN`, minted by `orun.integrations/reconcile@v1` from the `r2-data` template (Workers R2 Storage Write); previewed in the card's `spec.secrets` | the first apply would have failed authenticating to R2 (risk BL-H); the deploy token stays unable to touch storage, as cirrus's stays unable to touch D1 |
| `apps/web/wrangler.jsonc` | git-ignored, rendered by the build | committed as the fixture render, GENERATED banner; Checks diffs it | the deploy lane checks it exists before the build (risk BL-E) |
| dev's render | `live.mjs --env dev` → no document → red | `--fixture wiring.fixture.json --fixture-envs dev`; the fixture has a `dev` entry | dev is verify-only; no root applies there (BL-F) |
| `apps/web` → `cloudflare-r2` | `dependsOn` in the default mode (a PR's web lane waited on the R2 plan) | `mode: enforced`, `modeRules` advisory on `github-pull-request` | the one landing's order on main; a PR deploys nothing (cirrus-baseline v22's shape) |
| `apps/web` smoke | `grep 'R2 on Cloudflare'` on `/` | `/api/blob` for a new, never-stored name must answer the route's own `Not found` 404, then `/` must render the uploader | the name is the owner's; only a Worker that reached its bucket answers that 404, and nothing is written to the bucket by a deploy |
| `ci.yml` gate | `vars.ORUN_CI == 'true'` | skip only while `intent.yaml` names `ws_CHANGE_ME` | a bootstrap cannot set a repository variable |
| `checks.yml` | push to main + PRs | PRs + `workflow_dispatch` | `orun.run/watch@v1` takes the newest run on the merge sha from ANY workflow |
| stack-tectonic | 0.18.2 | 0.19.0 | first-deploy retry and smoke backoff; not 0.20.0, whose lane-scoped install Next 16's Turbopack refuses |
| orun lane pin | v2.78.0 | v2.78.4 | cirrus-baseline's and portfolio's pin |
| `packages/` | absent — `orun plan` failed: `failed to access discovery root packages` | `packages/.gitkeep` | the discovery roots are required |
| `intent.yaml` docs pages | `specs/epics/…` | `ai/context/*` | the pages must exist in a product |
| the R2 root's prose | Cirrus's "attachments, images … the Next.js incremental cache" | the uploader's bucket, private, reached only through the Worker | it ships into every product; no resource address changed |
| `tooling/wire/render.mjs` | copied the template's header comment | writes a GENERATED banner | the committed render must say it is one |
| `tasks/BL-1..4` | no `metadata` | `metadata.name` and `title` | `orun work check` (≥ v2.79) refused them |

Uploads needed no change to work on a fresh build: BL1 had already replaced
Vercel Blob's token (`BLOB_READ_WRITE_TOKEN`) with the Worker's R2 binding,
so a product built with nothing but the Cloudflare connection stores and
serves files from its first deploy. Nothing third-party remains.

## The cirrus standard, SVG uploads closed (BL5)

One fix to the app, and the baseline brought to cirrus-baseline's standard
around it:

| What | Before | After | Why |
|---|---|---|---|
| what an upload may be | `ALLOWED_CONTENT_TYPES = ['image/*']`, a prefix match — `image/svg+xml` passed | `image/png`, `image/jpeg`, `image/gif`, `image/webp`, `image/avif`, matched on the media type without parameters, case-insensitive, in `apps/web/lib/blob/content-types.ts`; `server.ts` re-exports it, the route refuses the rest with "We only accept PNG, JPEG, GIF, WebP and AVIF images" | an SVG is a document that can carry script, and the delivery route served it from the app's origin: a stored XSS, with anonymous uploads (risk BL-L) |
| the delivery route's response | content type, length, ETag, `nosniff` | plus `Content-Security-Policy: default-src 'none'; sandbox` | whatever a bucket already holds cannot run script on the app's origin |
| the delivery route's comment | "streams the object after authenticating the request" | says the route does not authenticate, as the upload route's does | it never did: nothing ships auth (BL-C) |
| the uploader | `accept="image/*"`, `file.type.split('/')[0] === 'image'` | `accept` and the check from the same list (`lib/blob/client.ts` re-exports it) | the browser refuses what the route would |
| tests | — | `tests/web`: an SVG refused (400, nothing stored), each raster type stored, the policy on a served object; `testing/e2e.test.sh`: the uploader's `accept`, an SVG refused and the policy, on the built Worker | — |
| orun pin | `kiox.yaml` (v2.15.0) + `kiox.lock`, shipped to every product | gone; orun is pinned where it runs, the `orun-action` `version:` in each workflow | nothing ran the kiox pin, and it disagreed with the lanes (v2.78.4) |
| `root-kiox`, `root-kiox-lock` modules | in `01-product` | removed (`testing/phases.test.sh` and the rebrand's skip list follow) | a product is placed with 81 files: 73 − 2 kiox + 9 docs pages + `content-types.ts` |
| component docs | none | `apps/web/docs/`, `tests/web/docs/`, `infra/terraform/cloudflare-r2/docs/` — `overview.md`, `architecture.md`, `runbook.md` | cirrus-baseline documents every component; the workspace Docs library renders `docs/` beside each `component.yaml` |
| how the docs stay true | — | `tooling/catalog/gen-component-docs.py` derives them from the manifest, the Worker config, Terraform and package scripts; Baseline CI runs it with `--check` | a hand-written copy of a manifest drifts silently |
| context pack | `operations.md`, `deployment.md` | plus `current.md`, `decisions.md`, `open-risks.md` | cirrus-baseline's shape; the three new pages are this repository's own and no module places them (the leak gate still allows exactly two) |
| status | BL4 "to be tagged" | BL4 shipped and tagged `baseline-v1`; the page-copy note names the Vercel logo it kept | the tag existed; the documents had not caught up |

### The subdomain from the Cloudflare connection (BL-7)

The console card's `subdomain` input was typed by hand, though it belongs to
the Cloudflare account the same way its id does and has exactly one right
answer. A wrong value surfaced only after deploy, in the smoke checks and the
verify URLs. `blueprint.yaml` now declares
`from: connection.cloudflare.workersSubdomain`, as cirrus-baseline does since
`baseline-v23`: the Cloudflare integration reads the subdomain from the
account at connect and on its hourly health check, and the bootstrap door
fills the input from the connection the build is bound to — the same one
`CLOUDFLARE_ACCOUNT_ID` and the deploy tokens mint from. The console renders
no field for it, and an account with no workers.dev subdomain is refused at
the door, naming the fix.

- `testing/manifest.test.sh` takes cirrus-baseline's check: a
  `connection.<provider>.<fact>` source is accepted, and only when the card's
  `spec.requires.integrations` lists the provider (this card lists
  `[github, cloudflare]`).
- `repo-blueprint.yaml` keeps the input and its default; its description,
  `BOOTSTRAP.md` and `docs/phases/README.md` say a hand-run `orun new` still
  passes `--set subdomain`.
- Nothing a product runs changed: no app, Terraform, test or tooling file.

Verified: `testing/{manifest,phases,coverage,rebrand,retouch,bootstrap-defer,wire}.test.sh`
green; `gen-component-docs.py --check` green (3 components); at v2.58.11,
`orun new --status` on `repo-blueprint.yaml` (`01-product` 81 files) and
`testing/leak.test.sh` (81 files derived; 74 shipped sources name no factory
path); at v2.78.4, `testing/placement.test.sh` (81 tracked files;
cloudflare-r2 → web; `--resume` changes nothing); `orun task check BL-7`
complete. Mutation check: with `cloudflare` removed from
`spec.requires.integrations`, `manifest.test.sh` fails with the one finding
`inputs[subdomain].from is 'connection.cloudflare.workersSubdomain' but
spec.requires.integrations does not list cloudflare`; restored, it passes.

## Verified (BL5)

- `testing/{manifest,phases,coverage,rebrand,retouch,bootstrap-defer,wire}.test.sh`
  green; `gen-component-docs.py --check` green (3 components, 9 pages).
- `orun new --status` (v2.58.11, the bootstrap floor): `01-product` 81 files,
  `02-docs` hook-only.
- `testing/leak.test.sh` (v2.58.11): 81 files derived (73 − 2 kiox + 9 docs
  pages + `content-types.ts`); ai/context still exactly the two declared
  pages; 74 shipped sources name no factory path.
- `testing/placement.test.sh` (v2.78.4, as Baseline CI runs it): 81 files
  placed, both landings, branded, re-tenanted; the product's own plan applies
  `cloudflare-r2` (with `CLOUDFLARE_R2_TOKEN`) at level 0 and deploys `web`
  at level 1 on stage and prod; a pull request waits on nothing; the 02-docs
  merge plans 0 jobs.
- `pnpm install --frozen-lockfile`, `wire:fixture` (committed render
  unchanged), `typecheck`, `lint` (the one upstream unused-variable
  warning), `test` (16 tests, was 11), `build` green.
- `testing/e2e.test.sh` (v2.78.4): the 01-product landing passes the Checks
  sequence; the stage lane's four steps pass in the staged job tree, `BLOB`
  bound to the stage document's bucket; under `wrangler dev` the component's
  smoke passes, the page offers the five raster types, one PNG uploaded
  twice is stored under two suffixed names and streamed back byte for byte
  with the sandboxing CSP and `nosniff`, and a PDF, an SVG, a missing name
  and an unknown object are refused.
- `orun task check BL-6` complete.

## Verified (BL4)

- `orun new --status` reads the blueprint at v2.58.11 (the bootstrap floor),
  v2.78.4 (the lane pin) and v2.79.0: `01-product` 73 files, `02-docs`
  hook-only. `orun validate` and `orun work check` clean.
- `testing/{manifest,phases,coverage,rebrand,retouch,bootstrap-defer,wire}.test.sh`
  green; the manifest test holds the card's three secrets (the `r2-data`
  key among them) to the blueprint's three reconcile hooks.
- `testing/leak.test.sh` (v2.58.11 and v2.79.0): 73 files derived; nothing
  of the factory, nothing local or built, no provenance prose; 66 shipped
  sources name no factory path.
- `testing/placement.test.sh` (fixture "Sam's Photos & Files" /
  `acme-inc/acme-blob-uploads`): two landings; rebrand `--verify` clean; the
  page, the Worker, the bucket names and every secret ref the product's; no
  file names a factory path; workspace re-tenanted, `work:` stripped,
  promotion and dev lanes restored; record rendered. The product's own
  `orun plan --trigger github-push-main` for the 01-product merge:
  `cloudflare-r2` apply on stage and prod at lane level 0, resolving
  `CLOUDFLARE_API_TOKEN` from the product's `CLOUDFLARE_R2_TOKEN`; `web`
  deploy at level 1, resolving the `workers-deploy` key, each waiting on its
  own environment's apply alone; on a pull request `web` waits on nothing;
  the 02-docs merge plans 0 jobs; `--resume` changes nothing. Green under
  v2.78.4 and v2.79.0; refused under v2.58.11 (risk BL-I).
- `testing/e2e.test.sh` (v2.78.4 and v2.79.0): the 01-product landing
  passes the Checks sequence (the committed config is the fixture render);
  in the job tree staged as orun stages it, the stage lane's
  `verify-app-structure`, `build-app` (the live render, from a stage
  document in the job's environment), `verify-build-output` and
  `deploy-dry-run` pass, binding `BLOB` to the document's bucket; `wrangler
  dev` serves the built Worker; the component's own smoke passes; `/`
  carries the product's name, links, origin and uploader; one image
  uploaded twice is stored under two suffixed names and streamed back byte
  for byte; a PDF, a missing name and an unknown object are refused; the
  Open Graph image, the static assets and a 404 are the product's own.
- The smoke against the same build served without its `BLOB` binding: the
  delivery route answers 500 and the smoke fails — it tells a bound bucket
  from a missing one.
- `terraform validate` and `terraform fmt -check` green on
  `infra/terraform/cloudflare-r2` (1.15.3).
- Not verified: a live bootstrap against a workspace (risk BL-G) — the two
  tokens minted, the bucket applied, the Worker deployed, the probes.

## Verified (BL1–BL3)

- Local: `pnpm run wire:fixture`, `pnpm typecheck`, `pnpm lint` (one
  upstream unused-variable warning), `pnpm test` (6 tests), `pnpm build`
  green; `wrangler dev` with a local bucket: `/` 200 ("R2 on Cloudflare"),
  `PUT /api/upload?pathname=test.png` with a PNG body 200 → `test-<suffix>.png`,
  `GET /api/blob?pathname=<that>` 200 `image/png` with byte-identical
  content, a PDF 400, a missing pathname 404.
- `terraform validate` green on `infra/terraform/cloudflare-r2`.
- CI: `Checks` green on #2 and #3.
- Not verified: the R2 apply and a live deploy — both need the product
  linked to an Orun workspace with a Cloudflare connection; the browser
  upload flow end to end (the client helper is exercised by the route
  tests, not by a browser).

## Versions

| Package | Version | Why |
|---|---|---|
| next | 16.3.8 | newest inside `@opennextjs/cloudflare` 1.20.11's peer range |
| @opennextjs/cloudflare | ^1.20.11 | `getCloudflareContext` for the binding; static-assets cache + `populateCache local` |
| wrangler | ^4.151.0 | compatibility_date 2026-10-01 |
