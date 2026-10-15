# blob-starter — risks and open questions

## BL-A — The upload crosses the Worker (ACCEPTED)

Vercel Blob's client uploaded directly to the store; here the file passes
through the Worker and is buffered (R2 needs a known length for a streamed
body). The template's 50MB ceiling keeps that bounded and inside Workers'
request limits. Presigned URLs are the alternative when files grow
(design §2, rejected for now).

## BL-B — No `onUploadCompleted` webhook (RESOLVED)

Blob called the route back after the direct upload. Here the route is the
upload, so the completion log is the route's own `console.log` — same
message, no webhook, no ngrok caveat.

## BL-C — Anonymous uploads (ACCEPTED, as upstream)

The template says "authenticate before generating the token"; the port says
"authenticate before accepting the upload" at the same place. Neither ships
auth.

## BL-D — Page copy (RESOLVED)

"Blob on Vercel", the Vercel Blob link and the deploy button point at R2
and this repository; the layout title reads "R2 Blob Starter".

## BL-E — The deploy lane checked for a config only the build makes (RESOLVED in BL4)

stack-tectonic's `cloudflare-workers-assets-turbo` runs `verify-app-structure`
— `test -f package.json`, `test -f <wranglerConfig>` — BEFORE `build-app`, in
a job tree staged from the checkout. `wrangler.jsonc` was git-ignored and
rendered only by the build, so every Orun lane of the product (dev, stage,
prod; pull request or merge) would have failed at that step: no lane had
ever run (`ORUN_CI` was never set). Fix: commit `wrangler.jsonc` as the
fixture render of `wrangler.template.jsonc` (with a GENERATED banner); the
build still re-renders it for its environment. Checks fails when the two
disagree (`git diff --exit-code` after `wire:fixture`), and
`testing/wire.test.sh` checks the same. `testing/e2e.test.sh` runs the step
in a staged tree.

## BL-F — The dev lane had no wiring document to render (RESOLVED in BL4)

`buildCommand` rendered with `live.mjs --env "${ORUN_ENVIRONMENT}"`, which
needs `WIRING_CLOUDFLARE_R2_<ENV>`. `dev` subscribes `web` (verify) but no
root applies there, so `WIRING_CLOUDFLARE_R2_DEV` never exists: every dev
lane would have failed in `build-app`. Fix: `live.mjs --fixture
wiring.fixture.json --fixture-envs dev` renders the fixture for the
verify-only environment, and only for it; the fixture gained a `dev` entry.
stage and prod still need the real document and refuse without it
(`testing/wire.test.sh`).

## BL-G — No live bootstrap yet (OPEN)

Everything short of the platform is proven on every pull request: the card
against the build, the blueprint read by three orun versions, the leak gate,
the wiring path, the offline bootstrap with the blueprint's own hooks, the
product's own plan (the R2 apply, with the r2-data key, before the Worker's
deploy; nothing waiting on a pull request), and the produced product built
in the job tree, dry-deployed with the stage document's bucket, served,
smoke-tested, and an upload stored and read back through the built Worker.
NOT proven: the repository created and linked, the two tokens minted by
`integrations/reconcile`, a real `terraform apply` (the root is held to
`terraform validate`; its `adopt.tf` lookup calls the Cloudflare API), the
lease-published document, a real `wrangler deploy`, the probes. Hence the
registry row is `unlisted` until one bootstrap from the tag has come up.

## BL-H — The R2 root applied with a token that cannot touch R2 (RESOLVED in BL4)

`infra/terraform/cloudflare-r2/component.yaml` bound the project's
`CLOUDFLARE_API_TOKEN` — the key the platform mints from the `workers-deploy`
template, whose grant is Workers Scripts, KV Storage and Account Settings,
and no R2. The first apply (and the plan before it: `adopt.tf` lists the
account's buckets) would have been refused. Fix: 01-product mints a second
key, `CLOUDFLARE_R2_TOKEN`, from the `r2-data` template (Workers R2 Storage
Write), with its own `orun.integrations/reconcile@v1` hook; the root binds it
as the provider's `CLOUDFLARE_API_TOKEN`, the way cirrus-baseline's D1 root
binds `CLOUDFLARE_D1_TOKEN`. The card's `spec.secrets` lists it
(`testing/manifest.test.sh` holds the two to each other), and
`testing/placement.test.sh` asserts the product's planned R2 jobs resolve it
and its Worker deploys resolve the deploy key. The running Worker needs
neither: it reaches its bucket through its binding.

## BL-I — The bootstrap floor plans every edge enforced (ACCEPTED)

orun v2.58.11 — the floor for RUNNING a bootstrap — does not apply a
`dependsOn` edge's `modeRules`: it plans a pull request with `web` waiting on
the R2 plan. That CLI never plans the product's CI (its `ci.yml` pins
v2.78.4, which applies them), and on a push to main both agree. The
placement tier plans as the product does: `baseline.yml` runs it under the
lane pin, and the test refuses an orun older than `ci.yml`'s pin.

## BL-J — R2 must be switched on for the account (ACCEPTED, an owner step)

Cloudflare asks for R2 to be enabled once per account (dashboard → R2), even
on the free tier, and refuses a bucket create until it is ("Please enable R2
through the Cloudflare Dashboard"). No brokered scope can do it. BOOTSTRAP.md
lists it under what you need, and the troubleshooting tables name the
error; the Worker, which waits on the apply, does not deploy until it is.

## BL-K — A custom domain is the owner's step (ACCEPTED)

Attaching a domain to a Worker needs zone permissions the brokered
`workers-deploy` token does not carry, and `dns-edit` needs zone ids a build
does not have. The product's README says how to attach one; nothing in the
repository changes, because the page takes its origin from the request.
