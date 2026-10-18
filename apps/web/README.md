# apps/web — the uploader and its two routes

An image uploader with drag-and-drop, a preview, a progress bar and a private
delivery route, from Vercel's Blob Next.js Starter
([vercel/examples](https://github.com/vercel/examples/tree/main/storage), MIT),
running on Cloudflare Workers + Static Assets with the files in a
**Cloudflare R2** bucket instead of Vercel Blob:

- `app/page.tsx` — the page around `<Uploader />`
- `components/uploader.tsx` — pick or drop an image (PNG, JPEG, GIF, WebP
  or AVIF, 50MB max), preview, upload with progress, a toast linking the
  stored file
- `app/api/upload/route.ts` — `PUT ?pathname=`: the same checks again on the
  server, then `BLOB.put` under the name plus a random suffix; answers
  `{ pathname, contentType, size }`
- `app/api/blob/route.ts` — `GET ?pathname=`: streams the object with its
  content type, `nosniff` and a CSP that sandboxes it, or the route's own
  `Not found` 404
- `lib/blob/client.ts`, `lib/blob/server.ts` — the two halves of what
  `@vercel/blob` did; `lib/blob/content-types.ts` — the raster types both
  accept (no SVG: it can carry script, and the route serves from this
  origin)
- `app/site.ts` — the site's name and the repository its links point at

```bash
pnpm dev        # next dev on http://localhost:3000, a local R2 bucket through wrangler's platform proxy
pnpm build      # next build + opennextjs-cloudflare build → .open-next/
pnpm preview    # wrangler dev over the built Worker, the same local bucket
```

The bucket needs no key: the Worker binds it as `BLOB`. Its name is not
hand-written either. `wrangler.template.jsonc` names it as a wiring token;
`wrangler.jsonc` is that template rendered from `wiring.fixture.json`
(placeholder names, for local work and verification), and every deploy
renders it again from the name the `cloudflare-r2` Terraform root published
for the environment (`component.yaml`'s `buildCommand`).

⚠️ Both routes accept anonymous requests, as the template's do; each says
where to add your own authentication. The file passes through the Worker,
buffered, which the 50MB ceiling keeps inside its limits.
