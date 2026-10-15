# blob-starter — implementation plan

Milestones land in order; each task is one pull request on an
`orun/BL-n-<slug>` branch with an `Orun-Task: BL-n` trailer.

## BL0 — the spec ✅

This doc set, `epic.yaml` and the task contracts, merged to `main`.

**Done when**
- the five documents and `epic.yaml` are on `main`
- `tasks/BL-1..BL-4.TaskContract.yaml` exist

## BL1 — uploads on R2 ✅

`apps/web` with `lib/blob`, the two routes against R2, the wrangler
template + fixture, `tests/web`.

**Done when**
- `pnpm install && pnpm run wire:fixture && pnpm typecheck && pnpm lint && pnpm test && pnpm build` is green locally and in `Checks`
- `wrangler dev`: `/` 200 with "R2 on Cloudflare"; `PUT /api/upload?pathname=x.png` with an image body 200 and a suffixed pathname; the same pathname on `GET /api/blob` 200 with the bytes and `image/png`; a PDF 400; a missing pathname 400/404

## BL2 — the R2 bucket from Terraform ✅

`infra/terraform/cloudflare-r2` (component + terraform), validated.

**Done when**
- `terraform validate` passes on the root
- the wiring key the root outputs (`r2_bucket_name`) is the one the template's token names

## BL3 — ready to instantiate ✅

README, `IMPLEMENTATION-STATUS.md`, epic `completed`.

**Done when**
- the README quick start works from a fresh clone
- the status file lists every PR and departure

## Sequencing note

BL1's component already names the root's wiring secret; BL2 makes the name
true. Applying BL2 needs a workspace with a Cloudflare connection.
