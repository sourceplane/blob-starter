# blob-starter — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives. Superseded decisions stay listed, marked, so the history
reads in order.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | The upload goes through the Worker (`PUT /api/upload`, buffered, 50MB max), not a presigned R2 URL | One credential (the binding) and the template's checks stay on the server; presigned URLs need an S3 key pair the baseline would have to broker | `specs/epics/blob-starter/design.md` §2, risk BL-A |
| 2 | Delivery stays a private route (`GET /api/blob?pathname=`), as upstream | The bucket is not public; nothing is served from it but through the Worker | design.md §2, epic README |
| 3 | The `BLOB` binding is the storage credential; no storage key | Replaces `BLOB_READ_WRITE_TOKEN`: a product stores and serves files from its first deploy with nothing but the Cloudflare connection | IMPLEMENTATION-STATUS (BL4) |
| 4 | `wrangler.jsonc` is rendered from the R2 root's wiring document per environment, and the fixture render is committed | The deploy lane checks the config exists before the build; Checks diffs the committed render | risk BL-E |
| 5 | dev renders the fixture; stage and prod refuse without the real document | No root applies in dev, which only verifies | risk BL-F |
| 6 | The R2 root applies with its own `r2-data` key (`CLOUDFLARE_R2_TOKEN`) | The `workers-deploy` token cannot touch R2 | risk BL-H |
| 7 | One landing (`01-product`) then the record (`02-docs`); `apps/web` `dependsOn: cloudflare-r2`, enforced on main, advisory on a pull request | The plan, not a landing boundary, orders the bucket before the Worker (cirrus-baseline since baseline-v22) | design.md §7 |
| 8 | `ci.yml` plans nothing while `intent.yaml` names `ws_CHANGE_ME` | A bootstrap cannot set a repository variable (replaced the `ORUN_CI` gate) | IMPLEMENTATION-STATUS (BL4) |
| 9 | stack-tectonic 0.19.0, not 0.20.0 | Next 16's Turbopack refuses 0.20.0's out-of-tree install | IMPLEMENTATION-STATUS (BL4), design.md §7 |
| 10 | Uploads are raster images only (PNG, JPEG, GIF, WebP, AVIF), one list shared by the route and the uploader; the delivery route serves every object under `default-src 'none'; sandbox` | `image/*` admitted SVG, which the route served from the app's origin as script — a stored XSS | risk BL-L, IMPLEMENTATION-STATUS (BL5) |
| 11 | orun is pinned only where it runs (the `orun-action` `version:` in each workflow); no kiox | `kiox.yaml` pinned a version (v2.15.0) nothing ran | IMPLEMENTATION-STATUS (BL5) |
| 12 | Component docs are generated from the manifests and checked in CI | A hand-written copy of the dependency graph and bindings drifts silently | `tooling/catalog/gen-component-docs.py` |
| 13 | The console card reads `subdomain` from the Cloudflare connection (`from: connection.cloudflare.workersSubdomain`); only a hand-run build passes it | It belongs to the account like its id and has one right answer; a typed one could only be wrong, and wrong showed up after deploy (cirrus-baseline since baseline-v23) | `blueprint.yaml`, IMPLEMENTATION-STATUS (BL-7) |
