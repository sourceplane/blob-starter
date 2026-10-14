# blob-starter

Vercel's [Blob Next.js Starter](https://github.com/vercel/examples/tree/main/storage/blob-starter)
— an image uploader with drag-and-drop, preview, progress and a private
delivery route — running on **Cloudflare Workers + Static Assets** through
[`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare), with the
files in a **Cloudflare R2** bucket provisioned by Terraform through
[Orun](https://github.com/sourceplane/orun), inside the repository
conventions of the [Cirrus baseline](https://github.com/sourceplane/cirrus-baseline).

The page and the uploader are the template's; the store is R2 and the
upload route is its front door. See
[`specs/epics/blob-starter`](specs/epics/blob-starter/README.md) for the
design, the milestones and the as-built status.

## What is here

| Surface | Where |
|---|---|
| The page and the uploader | `apps/web/app/page.tsx`, `apps/web/components/uploader.tsx` |
| Upload (PUT, image/* ≤ 50MB, random suffix) and delivery (GET, private) | `apps/web/app/api/upload/route.ts`, `apps/web/app/api/blob/route.ts` |
| The two halves of what `@vercel/blob` did | `apps/web/lib/blob/client.ts`, `apps/web/lib/blob/server.ts` |
| Workers build, bindings and deploy contract | `apps/web/next.config.mjs`, `open-next.config.ts`, `wrangler.template.jsonc` + `wiring.fixture.json`, `component.yaml` |
| The R2 bucket (stage, prod) | `infra/terraform/cloudflare-r2` |
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
| `upload()` client token handshake + direct upload | `PUT /api/upload?pathname=` through the Worker, with progress; same checks, same result shape |
| `GET /api/blob` private delivery | Same route, streaming from R2 |
| Deploy on push | Orun deploys `blob-starter-web-{stage,prod}` on merge to `main` (`apps/web/component.yaml`) |

Both routes carry the template's ⚠️ "add your own authentication" notes:
nothing ships auth.

## Deploying

`.github/workflows/checks.yml` runs install, wire, typecheck, lint, test and
build on every push and pull request. `ci.yml` is the Orun pipeline: set
`execution.state.workspace` in `intent.yaml` to this product's workspace
(`orun cloud link`), connect a Cloudflare account to it, and set the
`ORUN_CI` repository variable to `true`. A merge to `main` then applies the
R2 root, renders the Worker's config with the real bucket name, and deploys
to `stage`, then `prod`.
