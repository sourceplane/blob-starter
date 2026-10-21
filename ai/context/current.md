# blob-starter — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a product built from it;
the two pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md).

## What it is

Vercel's Blob Next.js Starter — an image uploader with a private delivery
route — on Cloudflare Workers + Static Assets, with the files in an R2 bucket
Terraform provisions, packaged as an Orun baseline: `orun new --blueprint
repo-blueprint.yaml` builds a new product in its own repository and takes it
to live on stage and prod in one landing (`01-product`: the bucket applied,
then the Worker deployed), then records what went live (`02-docs`).

## Release

| | |
|---|---|
| Latest tag | `baseline-v2` (BL5 — the cirrus standard: no kiox, generated component docs, this context pack, and the console card reading `subdomain` from the Cloudflare connection; SVG uploads closed, risk BL-L); `baseline-v1` is BL4 |
| Proven live | No. Everything short of the platform is proven offline in Baseline CI, an upload round-tripped through the built Worker included; a live bootstrap from a tag is still to come (risk BL-G) |

`baseline-v1` accepts any `image/*` upload, SVG included, and serves it from
the product's own origin (BL-L). A product built from it needs BL5's change
to `apps/web/lib/blob`, the delivery route and the uploader, which
`baseline-v2` carries.

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/blob-starter/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/blob-starter/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/blob-starter/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What each component is | `apps/web/docs/`, `tests/web/docs/`, `infra/terraform/cloudflare-r2/docs/` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Bootstrap one product from `baseline-v2` against a workspace whose
   Cloudflare account has R2 enabled (BL-J), and record its timings (closes
   BL-G).
