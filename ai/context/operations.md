# blob-starter — operating contract (for humans and agents)

This is the standing guide to how this site is deployed and operated.
Instance facts (live URLs, workspace, secrets inventory) live in
[deployment.md](deployment.md), rendered from probed reality by the
bootstrap's `02-docs` phase; this file is the contract that stays true
between deployments. It is written to give an agent with repository read
access enough context to reason about and operate the site without any
other source.

## What this system is

An image uploader on Cloudflare alone, expressed as an Orun
component-native desired-state repo.

- **`infra/terraform/cloudflare-r2`** — one private R2 bucket per deployed
  environment (`stage`, `prod`), applied by Terraform. After each apply it
  publishes a wiring document — `{r2_bucket_name}` — as the Orun secret
  `WIRING_CLOUDFLARE_R2` on that environment.
- **`apps/web`** — the uploader: Next.js built by `@opennextjs/cloudflare`
  into one Worker plus Static Assets. `PUT /api/upload?pathname=` accepts an
  image (≤ 50MB) and stores it in the `BLOB` R2 binding under the name plus
  a random suffix; `GET /api/blob?pathname=` streams it back. The page
  renders per request (its metadata takes the request's origin).
- **`tests/web`** — both routes against an in-memory bucket (vitest),
  verified on the `dev` rung.
- **`tooling/*`** — shared TypeScript and ESLint configuration, and the
  wrangler renderer that turns `wrangler.template.jsonc` plus a wiring
  document into `wrangler.jsonc`.

Environments: **`stage`** and **`prod`** are deployed; **`dev` is
verify-only by design** — lanes build and test, nothing deploys, and no
bucket exists for it (its build renders the committed fixture).

## Identity and tenancy

Every remote operation runs against ONE Orun workspace, declared in
`intent.yaml` under `execution.state.workspace` — committed, enforced, and
what CI uses. Do not remove it; headless credentials depend on it. If it
reads `ws_SET_ME`, the bootstrap had no workspace to write: set the real one
before anything else.

## How deployment works

1. Merge (or push) to `main`.
2. CI (`.github/workflows/ci.yml`) runs `orun plan --changed` — only
   components whose files changed are planned — then runs each planned lane
   with `orun run --remote-state`, authenticated by GitHub OIDC (the
   exchange resolves this repository's linked workspace server-side).
3. **The bucket before the Worker.** `cloudflare-r2` applies for the
   environment and publishes `WIRING_CLOUDFLARE_R2`. `apps/web` declares an
   enforced `dependsOn` on it for pushes to `main`, so its deploy starts only
   after that apply — and a job resolves its secrets when it starts, so the
   document is there.
4. `apps/web` renders `wrangler.jsonc` from that document (the real bucket
   name), builds once per environment, `wrangler deploy` ships
   `blob-starter-web-<env>`, and a smoke test asks the delivery route for an
   object nobody stored and requires the route's own `Not found` 404 —
   proof the Worker reached its bucket — then requires the page to render
   its uploader. The smoke uploads nothing.
5. `prod` deploys after `stage` has converged on the same commit
   (`environments.prod.promotion` in intent.yaml).
6. **The convergence run is the deployment.** A green run means every
   planned lane applied. Failed lanes are retried with
   `gh run rerun --failed`, which resumes the same execution.

On a pull request nothing applies or deploys: the R2 root plans, the
uploader builds and dry-deploys, and the edges in step 3 are advisory.

Caveats that matter:

- A push that touches no component files plans zero lanes — that run is
  green and deployed nothing. Never treat "latest run green" as "site
  converged"; probe the URLs instead.
- A change to `intent.yaml`'s `environments` maps to no component and
  redeploys nothing on its own. Land it with a change under `apps/web`.
- `wrangler.jsonc` is generated. Edit `wrangler.template.jsonc` and run
  `pnpm run wire:fixture`; Checks fails when the two disagree.
- R2 must be enabled on the Cloudflare account (dashboard → R2, once per
  account). Without it the R2 root's apply fails and the Worker, which waits
  on it, does not deploy.

## Secrets model

- **Brokered provider secrets**, minted per run from the workspace's
  Cloudflare connection — no long-lived values at rest, nothing to rotate by
  hand:
  - `CLOUDFLARE_API_TOKEN` — the `workers-deploy` scope (Workers Scripts and
    KV Storage write). The Worker's deploy uses it; it cannot touch R2.
  - `CLOUDFLARE_R2_TOKEN` — the `r2-data` scope (Workers R2 Storage Write).
    The R2 root applies with it, bound there as `CLOUDFLARE_API_TOKEN`.
  - `CLOUDFLARE_ACCOUNT_ID` — a connection fact both bind.
- **Wiring**: `WIRING_CLOUDFLARE_R2` on `stage` and `prod`, written by the
  R2 root's apply (lease-published), read by the Worker's build as
  `WIRING_CLOUDFLARE_R2_<ENV>`. It holds the bucket name, not a credential.
- **The running Worker holds no storage credential.** It reaches the bucket
  through its `BLOB` binding; the page needs no runtime secret.
- Inspect by NAME only: `orun secrets list --org <ws> --project` and
  `--env stage|prod`. No tooling in this repository prints a secret value,
  and no document in `ai/context/` may contain one.

## Uploads are anonymous

Both routes carry an "add your own authentication" note where the check
belongs, and nothing ships one: anyone who can reach the URL can store an
image (≤ 50MB) and read back any object whose name they know. Add
authentication before you share the URL, at those two notes.

## Verifying the system

```bash
# the page on each environment (also recorded, probed, in deployment.md)
curl -s -o /dev/null -w '%{http_code}\n' https://blob-starter-web-stage.your-workers-subdomain.workers.dev/

# the bucket, through the Worker: an unknown name is the route's own 404
curl -s -w ' %{http_code}\n' "https://blob-starter-web-prod.your-workers-subdomain.workers.dev/api/blob?pathname=no-such-object.png"

# a round trip (it stores a file — on stage, not prod)
curl -s -X PUT -H 'content-type: image/png' --data-binary @some.png \
  "https://blob-starter-web-stage.your-workers-subdomain.workers.dev/api/upload?pathname=check.png"

# the wiring the deploys read, and workspace readiness
orun secrets list --org <ws> --env stage && orun secrets list --org <ws> --env prod
orun integrations list --org <ws> --json && orun cloud check --org <ws>
```

## Common operations

| task | how |
|---|---|
| change the page | edit `apps/web/app/page.tsx` (its name and links: `apps/web/app/site.ts`), merge |
| change what uploads accept | `MAX_UPLOAD_BYTES` and `ALLOWED_CONTENT_TYPES` in `apps/web/lib/blob/server.ts` (and the matching browser check in `components/uploader.tsx`) |
| deploy a change | merge to `main`; watch the run; failed lanes → `gh run rerun --failed` |
| redeploy without a change | edit the last line of `apps/web/component.yaml` (`# orun: redeploy <reason> <stamp>`) and merge — it is a deploy trigger, nothing reads it |
| list or delete stored files | `wrangler r2 object …` on the bucket named in the environment's `WIRING_CLOUDFLARE_R2` (`--remote`), or the dashboard's R2 page |
| add a binding (D1, KV, another bucket) | a Terraform root under `infra/terraform/` that publishes `WIRING_<ROOT>`, a token in `wrangler.template.jsonc`, its fixture entry, the root in the build's `--components`, the `WIRING_<ROOT>_<ENV>` secretEnv and an enforced `dependsOn` on it in `apps/web/component.yaml` |
| serve a custom domain | attach it to the Worker in Cloudflare (README, "Custom domain"); nothing in the repository changes |
| add a runtime secret | `orun secrets set <KEY> --org <ws> --env <env>` |
| headless credentials | `ORUN_TOKEN` (workspace-scoped) + `GITHUB_TOKEN` |

The deployment record is the bootstrap's `02-docs` phase. Re-running it (the
Orun console's Retry on that phase, or `orun new … --phase 02-docs`)
re-probes the URLs and re-renders [deployment.md](deployment.md); it is
idempotent.

## Evolution

Files pass through the Worker, buffered, which the 50MB ceiling keeps inside
its limits. Larger files are presigned R2 uploads (the S3 API with an
access key pair, a second credential) or multipart uploads through the
binding. Structural changes follow the same contract that deployed the
site: add a component under `apps/`, `infra/` or `packages/` with a
`component.yaml`, land it as a pull request, and the convergence run
applies it.
