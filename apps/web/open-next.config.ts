// OpenNext Cloudflare adapter config.
//
// Nothing here revalidates: the page and the two upload routes render per
// request in the Worker, and what the build does prerender (the Open Graph
// image) the static-assets incremental cache serves straight from the
// Worker's static assets — read only, nothing to provision. The uploads'
// bucket is the app's own `BLOB` binding, not a cache. A template that
// revalidates (ISR, `revalidateTag`) swaps this for the R2 incremental cache
// plus a tag cache.
import { defineCloudflareConfig } from "@opennextjs/cloudflare/config";
import staticAssetsIncrementalCache from "@opennextjs/cloudflare/overrides/incremental-cache/static-assets-incremental-cache";

export default defineCloudflareConfig({
  incrementalCache: staticAssetsIncrementalCache,
});
