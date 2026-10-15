# blob-starter — implementation plan

Milestones land in order; each task is one pull request on an
`orun/BL-n-<slug>` branch with an `Orun-Task: BL-n` trailer.

## BL0 — the spec ✅

This doc set, `epic.yaml` and the task contracts, merged to `main`.

**Done when**
- the five documents and `epic.yaml` are on `main`
- `tasks/BL-1..BL-4.TaskContract.yaml` exist (BL-5 joined with BL4)

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

## BL4 — a baseline, in one landing ✅

`blueprint.yaml`, `repo-blueprint.yaml` (two phases: `01-product`,
`02-docs`), `.baseline/` (identity, task contracts, the product's README),
`tooling/rebrand`, `tooling/bootstrap`, `hooks/render-deployment-docs.sh`,
`ai/context/`, `docs/phases/`, `BOOTSTRAP.md`, `testing/`, `baseline.yml`
and `tag.yml` (design §7); and what the product needed to deploy from a
fresh repository: the R2 root on an `r2-data` key of its own,
`wrangler.jsonc` committed, dev rendering the fixture, `apps/web`'s
enforced `dependsOn: cloudflare-r2` on main, `packages/`.

**Done when**
- orun at the bootstrap floor (v2.58.11), the lane pin (v2.78.4) and the
  current CLI (v2.79.0) reads `repo-blueprint.yaml`, and
  `testing/manifest.test.sh` holds the card to it — the r2-data key included
- the product's own push-to-main plan applies `cloudflare-r2` (with
  `CLOUDFLARE_R2_TOKEN`) before it deploys `web` (with
  `CLOUDFLARE_API_TOKEN`) on stage and prod (`testing/placement.test.sh`)
- `Baseline CI` is green: the contract tests, the wiring path, the leak gate,
  the offline bootstrap and the end-to-end tier, which uploads an image to
  the built Worker and reads it back
- the status file records what is proven offline and what only a live
  bootstrap can prove

## After BL4 (outside this repository)

1. Cut `baseline-v1` with `tag.yml` from the merged `main`.
2. Register the row in orun-cloud's `infra/baselines-registry/baselines.yaml`
   (unlisted) with the card vendored at the tag.
3. Bootstrap one product from the tag against a workspace whose Cloudflare
   account has R2 enabled; record its timings; then flip the row to public
   with a page on orunbase.com.

## Sequencing note

BL1's component already names the root's wiring secret; BL2 makes the name
true. Applying BL2 needs a workspace with a Cloudflare connection; until
then the Orun lane plans nothing (`ws_CHANGE_ME`) and `Checks` is the merge
gate. BL4 packages BL1–BL2 as a baseline whose one landing applies BL2's
root, with a token of its own, before it deploys BL1's Worker.
