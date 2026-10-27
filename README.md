# blob-starter

Vercel's [Blob Next.js Starter](https://github.com/vercel/examples/tree/main/storage/blob-starter)
— an image uploader with drag-and-drop, preview, progress and a private
delivery route — running on **Cloudflare Workers + Static Assets** through
[`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare), with the
files in a **Cloudflare R2** bucket provisioned by Terraform through
[Orun](https://github.com/sourceplane/orun), and packaged as an **Orun
baseline**: one command takes a new product from nothing to live on stage
and prod, in its own repository, under its own name — in ONE landing.

The page and the uploader are the template's; the store is R2 and the
upload route is its front door. What the baseline adds is everything needed
to make a copy of it somebody else's, built the way
[cirrus-baseline](https://github.com/sourceplane/cirrus-baseline) is since
its one-landing bootstrap. See
[`specs/epics/blob-starter`](specs/epics/blob-starter/README.md) for the
design, the milestones and the as-built status.

## Instantiating a product

```bash
git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/blob-starter
cd blob-starter
orun new --blueprint repo-blueprint.yaml --out ~/sites/acme-uploads --run-hooks --resume \
  --set reponame=acme-uploads --set productname="Acme Uploads" \
  --set githuborg=acme-inc --set subdomain=<workers-dev-subdomain>
```

Or, once the platform's registry lists it, from the Orun console (Baselines →
`blob-starter` → Build). Two phases: **`01-product`** creates the
repository and lands the whole product as ONE pull request — intent, CI,
tooling, the R2 root, the uploader and its tests — and one convergence
applies the R2 bucket on stage and prod and then deploys the uploader bound
to it; **`02-docs`** records the live deployment from probed facts.
**[BOOTSTRAP.md](BOOTSTRAP.md)** is the operator guide;
[docs/phases/](docs/phases/README.md) has a page per phase.

The only connection a build needs is Cloudflare (with R2 enabled on the
account). Uploads work from the first deploy: the Worker reaches its bucket
through its R2 binding, so there is no storage token to paste — Vercel
Blob's `BLOB_READ_WRITE_TOKEN` has no counterpart here.

The new repository receives the **product only** — the app, its R2 root, its
tests, its CI, its tooling, a README of its own and its operating contract —
renamed throughout to the product's name, repository, Cloudflare Worker and
bucket names. None of this repository's machinery ships.

| What makes it a baseline | Where |
|---|---|
| The console card (inputs, secrets, programme) | `blueprint.yaml` |
| The build document (modules, phases, hooks) | `repo-blueprint.yaml` |
| This tree's identity, and the bootstrap's task contracts | `.baseline/` |
| The rename engine | `tooling/rebrand/rebrand.mjs` |
| The bootstrap's helpers (deferrals, redeploy marker, work-tree strip) | `tooling/bootstrap/` |
| The deployment-record renderer | `hooks/render-deployment-docs.sh` |
| The product's README and context pack | `.baseline/product/README.md`, `ai/context/` |
| The baseline's tests: contract, wiring, leak, offline bootstrap, end to end | `testing/`, `.github/workflows/baseline.yml` |
| Cutting a `baseline-vN` tag | `.github/workflows/tag.yml` |

## What is here (the product)

| Surface | Where |
|---|---|
| The page and the uploader | `apps/web/app/page.tsx`, `apps/web/components/uploader.tsx` |
| The site's name and source link | `apps/web/app/site.ts` |
| Upload (PUT, PNG/JPEG/GIF/WebP/AVIF ≤ 50MB — no SVG — random suffix) and delivery (GET, private, sandboxed) | `apps/web/app/api/upload/route.ts`, `apps/web/app/api/blob/route.ts` |
| The two halves of what `@vercel/blob` did, and the upload types they share | `apps/web/lib/blob/client.ts`, `apps/web/lib/blob/server.ts`, `apps/web/lib/blob/content-types.ts` |
| Workers build, bindings and deploy contract | `apps/web/next.config.mjs`, `open-next.config.ts`, `wrangler.template.jsonc` + `wiring.fixture.json` (→ the committed `wrangler.jsonc`), `component.yaml` |
| The R2 bucket (stage, prod) | `infra/terraform/cloudflare-r2` |
| The wrangler renderer | `tooling/wire` |
| Tests | `tests/web` (vitest, both routes against an in-memory bucket) |

## Getting started

```bash
pnpm install
pnpm run wire:fixture   # render apps/web/wrangler.jsonc from the offline fixture
pnpm typecheck
pnpm lint
pnpm test
pnpm build              # next build + opennextjs-cloudflare build → apps/web/.open-next
```

```bash
pnpm --filter @app/web dev        # http://localhost:3000 — a local R2 bucket through wrangler's platform proxy
pnpm --filter @app/web preview    # wrangler dev over the built Worker, same local bucket
```

## How it maps to Vercel

| Vercel | Here |
|---|---|
| Next.js hosting | One Cloudflare Worker (`.open-next/worker.js`) + Static Assets |
| Vercel Blob (`BLOB_READ_WRITE_TOKEN`) | R2 bucket bound as `BLOB`; the binding is the credential |
| `upload()` client token handshake + direct upload | `PUT /api/upload?pathname=` through the Worker, with progress; the same checks, with images narrowed to raster formats (an SVG can carry script); same result shape |
| `GET /api/blob` private delivery | Same route, streaming from R2, under `nosniff` and a CSP that sandboxes what it serves |
| A store created in the dashboard | `infra/terraform/cloudflare-r2`, applied by Orun before the Worker deploys |
| Deploy on push | Orun applies the bucket and deploys `<repo>-web-{stage,prod}` on merge to `main` (`apps/web/component.yaml`) |
| "Deploy with Vercel" (clone the template) | `orun new --blueprint repo-blueprint.yaml` — a new repository, branded, deployed |

Both routes carry the template's ⚠️ "add your own authentication" notes:
nothing ships auth.

## How the bucket name reaches the Worker

```
infra/terraform/cloudflare-r2 ──apply──► orun secret WIRING_CLOUDFLARE_R2 (stage, prod)
   (CLOUDFLARE_R2_TOKEN, r2-data)              │   (each deploy resolves it as it starts;
                                               │    a missing one fails the lane)
                                               ▼
apps/web  dependsOn cloudflare-r2 (enforced on main) · secretEnv WIRING_CLOUDFLARE_R2_<ENV>
  build:  tooling/wire/live.mjs → wrangler.jsonc with the environment's bucket name
          (dev, verify-only, renders the fixture) → next build → opennextjs-cloudflare
  deploy: CLOUDFLARE_API_TOKEN (workers-deploy) — the running Worker holds no storage key
```

`wrangler.jsonc` is committed as the fixture render of
`wrangler.template.jsonc`, because the deploy lane's `verify-app-structure`
step checks the config exists before it builds; `testing/e2e.test.sh` fails
if the two disagree.

## CI

| Workflow | What it runs | Ships to a product |
|---|---|---|
| `ci.yml` | the Orun pipeline, and the only workflow a product carries: `orun plan --changed`, then one job per lane. A pull request runs the verify lanes (the R2 root planned for stage and prod, the uploader built and dry-deployed per environment — no tests, no lint), except the bootstrap's own landings (`orun/BASE-*`), where `plan` alone runs and nothing waits for it (the landing checked its commit in the box); a merge applies the R2 bucket, then deploys stage → prod. It plans nothing while `intent.yaml` names the placeholder workspace `ws_CHANGE_ME`, as this repository does. A manual run (Orunbase's Deploy button, or Run workflow on `main`) plans the environment and components it names under the push-to-main trigger, so they deploy as a merge deploys them | yes |
| `baseline.yml` | the baseline's own tiers: contract tests, the wiring path, the blueprint read by the pinned orun, the leak gate, the offline bootstrap with the product's own plan, the landing installed, type-checked, linted, tested and built, the product built in the job tree, dry-deployed and served | no |
| `tag.yml` | cuts a `baseline-vN` tag (manual) | no |
