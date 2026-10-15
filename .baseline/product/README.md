# blob-starter

An image uploader — drag and drop or pick an image, preview it, upload it
with a progress bar, and open it again from a private delivery route —
Next.js on **Cloudflare Workers + Static Assets** through
[`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare), with the
files in a **Cloudflare R2** bucket that Terraform provisions per
environment.

## Live deployment

<!-- 02-docs:begin -->
Not recorded yet. The bootstrap's last phase writes the live URLs, the
workspace and the secrets inventory into
[ai/context/deployment.md](ai/context/deployment.md); how the site deploys
and how to operate it is in
[ai/context/operations.md](ai/context/operations.md).
<!-- 02-docs:end -->

## What is here

| Surface | Where |
|---|---|
| The page and the uploader | `apps/web/app/page.tsx`, `apps/web/components/uploader.tsx` |
| The site's name and source link | `apps/web/app/site.ts` |
| Upload (PUT, image/* ≤ 50MB, random suffix) and delivery (GET, private) | `apps/web/app/api/upload/route.ts`, `apps/web/app/api/blob/route.ts` |
| The browser upload helper and the bucket's checks | `apps/web/lib/blob/client.ts`, `apps/web/lib/blob/server.ts` |
| Workers build, bindings and deploy contract | `apps/web/next.config.mjs`, `open-next.config.ts`, `wrangler.template.jsonc` + `wiring.fixture.json` (→ `wrangler.jsonc`), `component.yaml` |
| The R2 bucket (stage, prod) | `infra/terraform/cloudflare-r2` |
| Tests | `tests/web` (vitest: both routes against an in-memory bucket) |

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
pnpm --filter @app/web preview    # wrangler dev over the built Worker, the same local bucket
```

Make the page yours in `apps/web/app/page.tsx`, and its name and the
repository it links to in `apps/web/app/site.ts`.

## How uploads work

The browser PUTs the file to `/api/upload?pathname=<name>` with progress;
the route accepts images only, up to 50MB, stores the file in the bucket
under the name plus a random suffix, and answers
`{ pathname, contentType, size }`. `/api/blob?pathname=<stored name>`
streams it back with its content type. The bucket is private: nothing is
served from it except through that route.

There is no storage key to configure. The Worker binds the bucket as
`BLOB`, and the binding is the credential. Its name is never hand-written:
`apps/web/wrangler.template.jsonc` names it as a wiring token, and
`wrangler.jsonc` is that template rendered — from `wiring.fixture.json`
(placeholder names) for local work and verification, and on every deploy
from the document the `cloudflare-r2` Terraform root publishes after its
apply (`WIRING_CLOUDFLARE_R2`, per environment). Edit the template, then
`pnpm run wire:fixture`; Checks fails if the committed `wrangler.jsonc` is
not the fixture render.

**Anyone can upload.** Both routes carry an "add your own authentication"
note where a check belongs (`app/api/upload/route.ts`,
`app/api/blob/route.ts`); nothing ships one. Put your sign-in in front of
them before you share the URL.

## How it deploys

Merges to `main` converge through [Orun](https://github.com/sourceplane/orun):
`.github/workflows/ci.yml` plans the changed components and runs each lane
against the workspace in `intent.yaml`. The R2 bucket applies first, then
the uploader builds with that environment's bucket name and deploys — to
`stage`, then to `prod` once stage has converged on the same commit; `dev`
only verifies. The Worker is `blob-starter-web-<env>` on your account's
workers.dev subdomain, and every deploy is smoke-tested over HTTP: the
delivery route must answer from the bucket and the page must render its
uploader. `checks.yml` runs install, the fixture render, typecheck, lint,
test and build on every pull request. (A push to `main` runs `ci.yml`
alone, which applies, builds and deploys.)

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. Two
Cloudflare tokens — one that deploys Workers, one that manages R2 — and the
account id are brokered per run from the workspace's Cloudflare connection,
and the bucket names travel as Orun secrets; nothing provider-shaped is
stored in the repository or in GitHub.

## Custom domain

The site answers on workers.dev from its first deploy. To serve it on your
own domain, add the domain to the Cloudflare account the site deploys into
and attach it to the Worker (dashboard → Workers & Pages →
`blob-starter-web-prod` → Settings → Domains & Routes → Add → Custom
domain). Nothing in the repository changes: the page builds its absolute
links from the request it is answering.
