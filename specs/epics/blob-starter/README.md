# Epic: blob-starter (BL)

**Vercel's Blob starter is an uploader and a delivery route around a store that is Vercel's. On Cloudflare the store is R2, the bucket comes from Terraform through Orun, and its name reaches the Worker through the wiring documents the Cirrus baseline uses for every binding. The one real difference is how bytes get in: Vercel Blob's client asks the app for a token and uploads straight to Vercel; here the upload route is the bucket's front door, with the same image-only and 50MB checks, the same random suffix, the same result shape — so the uploader component changes one import line.**

The port keeps the template's page, uploader, progress bar, toasts and styles. It adds `lib/blob/{client,server}.ts` (the two halves of what `@vercel/blob` did), rewrites the two route handlers against the `BLOB` R2 binding, and adds the Workers build, the monorepo wrapper, a test package for both routes, the R2 Terraform root, and the deploy contract.

## Status

| Field | Value |
|-------|-------|
| Status | ✅ BL0–BL6 shipped (#1–#8; BL4 tagged `baseline-v1`, BL5 — the cirrus standard, SVG uploads closed, BL-6 and BL-7 — tagged `baseline-v2`, BL6 — the domain is set later, BL-8 — tagged `baseline-v3`). R2 apply and live deploy proven only by a live bootstrap (risk BL-G) |
| Cluster | **BL** (BL0–BL6) |
| Owner(s) | `apps/web` (the uploader, the routes, `lib/blob`) · `tests/web` · `infra/terraform/cloudflare-r2` |
| Builds on | `cirrus-baseline` conventions: the R2 root and the `@@wiring(...)@@` deploy-time render; the `kv-redis-starter` port's binding shape |
| Upstream | [vercel/examples `storage/blob-starter`](https://github.com/vercel/examples/tree/main/storage/blob-starter) |
| Changes | The store (Vercel Blob → R2), the upload path (client token → upload route), the Workers build, tests, the R2 root, the deploy contract; page copy says R2; since BL5, raster uploads only and a sandboxed delivery route (risk BL-L) |
| Decisions locked | (1) The upload goes through the Worker (one route, bounded at 50MB), not a presigned R2 URL: it keeps the template's server-side checks where they were. (2) Delivery stays a private route (`/api/blob?pathname=`), as upstream. (3) `wrangler.jsonc` rendered per environment — and, since BL4, committed as the fixture render, because the deploy lane checks it exists before the build (risk BL-E). (4) BL4: one landing — the plan, not a landing boundary, orders the bucket before the Worker; the bucket's apply has a token of its own (`r2-data`), because the deploy token cannot touch R2. |
| Gate | BL1 is the first user-visible rung. BL2 applies only with a linked workspace; verified by `terraform validate`. |
| Shipped as | `baseline-v3` ([#8](https://github.com/sourceplane/blob-starter/pull/8), BL6: no domain asked), `baseline-v1` ([#5](https://github.com/sourceplane/blob-starter/pull/5)), `baseline-v2` ([#6](https://github.com/sourceplane/blob-starter/pull/6), [#7](https://github.com/sourceplane/blob-starter/pull/7)); proven offline (Baseline CI: an upload round-tripped through the built Worker under `wrangler dev`), deploy gated until a workspace is linked |

## Read order

1. `design.md` — what maps to what, the upload flow, what is out of scope
2. `implementation-plan.md` — the milestones and what "done" means for each
3. `risks-and-open-questions.md` — what could go wrong and what was decided
4. `IMPLEMENTATION-STATUS.md` — what actually shipped (kept distinct from intent)

## Milestones at a glance

| Milestone | What it lands | Done when |
|---|---|---|
| BL0 — the spec | this doc set and the task contracts | merged on `main` |
| BL1 — uploads on R2 | `apps/web`, the rendered wrangler config, `tests/web` | upload + delivery work under `wrangler dev`; Checks green |
| BL2 — the R2 bucket from Terraform | `infra/terraform/cloudflare-r2` | the root validates; the wiring key matches the template |
| BL3 — ready to instantiate | README, as-built status | a reader can run, test, preview and deploy it |
| BL4 — a baseline, in one landing | card, build document, rename, bootstrap tooling, tests | a new product goes from nothing to live in one landing, the R2 bucket applied before the Worker; Baseline CI green |
| BL5 — the cirrus standard, SVG uploads closed | raster-only uploads and a sandboxed delivery route; no kiox, generated component docs, the context pack, status that agrees with the tags; the console card reads `subdomain` from the Cloudflare connection | an SVG upload is refused and a served object cannot run script; Baseline CI green with the docs check |
| BL6 — the domain is set later | the console asks for no domain; an empty `productdomain` brands the placeholder `<reponame>.example.com` for an owner to replace | Baseline CI green on a fixture with no domain |
