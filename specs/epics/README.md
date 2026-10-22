# Epics

Orun-style work programs. Each epic is a folder carrying `epic.yaml` (the
declaration the platform reads: slug, key prefix, milestones with exit
criteria and task keys) beside its doc set. The pull request that adds the
folder is the adoption; the merge creates the epic in the workspace.

| Epic | Cluster | Status | What it is |
|------|---------|--------|------------|
| [`blob-starter/`](./blob-starter/) | **BL** | ✅ Shipped (`baseline-v3`); live bootstrap pending | Vercel's Blob Next.js Starter, equivalent in code and function, on Cloudflare Workers with uploads stored in R2 — and an Orun baseline that instantiates it in one landing (BL4) |

As-built ≠ intent: what shipped lives in each epic's `IMPLEMENTATION-STATUS.md`.
