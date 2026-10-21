# blob-starter — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted and resolved ones, is
`specs/epics/blob-starter/risks-and-open-questions.md`; this page lists only
what is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| BL-G | No live bootstrap yet: the repository created and linked, the two tokens minted, a real `terraform apply` of the bucket, the published wiring document, a real `wrangler deploy` and the probes are all unproven | OPEN | One bootstrap from a tag against a workspace whose Cloudflare account has R2 enabled |

Accepted, and worth knowing before you change them: BL-A (the upload is
buffered through the Worker), BL-C (anonymous uploads, as upstream),
BL-I (the bootstrap floor plans every edge enforced), BL-J (R2 is
switched on per account by its owner), BL-K (a custom domain is the owner's
step). Resolved in BL5: BL-L (SVG uploads), for products built from
`baseline-v2` on.
