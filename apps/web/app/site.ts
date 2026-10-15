// The site's identity, written once. The page heading and its <title> read
// SITE_NAME; the "Deploy your own" pill and the footer's Source link go to
// SOURCE_URL. Instantiating the site under a new name rewrites both to that
// name and its repository, so keep them literal and on one line each.
export const SITE_NAME = "R2 on Cloudflare"
export const SOURCE_URL = "https://github.com/sourceplane/blob-starter"

// The origin a request was made to, for the metadata's absolute URLs (the Open
// Graph image). Reading it makes the page render per request, in the Worker,
// which is what lets the site need no configured origin: on workers.dev, on a
// custom domain or under `wrangler dev` it is whatever host the visitor asked
// for.
export function requestOrigin(headers: { get(name: string): string | null }): URL | undefined {
  const host = headers.get('x-forwarded-host') ?? headers.get('host')
  if (!host) return undefined
  const local = /^(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/.test(host)
  const proto = headers.get('x-forwarded-proto') ?? (local ? 'http' : 'https')
  try {
    return new URL(`${proto}://${host}`)
  } catch {
    return undefined
  }
}
