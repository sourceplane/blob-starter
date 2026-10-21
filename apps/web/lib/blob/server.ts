import { getCloudflareContext } from '@opennextjs/cloudflare'

// The server half of what `@vercel/blob` did: an R2 bucket bound as BLOB.
// `put` stores a file under a pathname with a random suffix (what Blob's
// `addRandomSuffix` did), `get` streams it back.

export const MAX_UPLOAD_BYTES = 50 * 1024 * 1024 // 50MB, as the template

// Raster images only (PNG, JPEG, GIF, WebP, AVIF). The template allowed
// `image/*`, which admits `image/svg+xml` — a document that runs script when
// the delivery route serves it from this origin.
export { ALLOWED_CONTENT_TYPES, NOT_ALLOWED_MESSAGE, isAllowedContentType } from './content-types'

export function withRandomSuffix(pathname: string, random = crypto.randomUUID()): string {
  const suffix = random.replace(/-/g, '').slice(0, 30)
  const dot = pathname.lastIndexOf('.')
  if (dot <= 0 || dot === pathname.length - 1) return `${pathname}-${suffix}`
  return `${pathname.slice(0, dot)}-${suffix}${pathname.slice(dot)}`
}

export async function bucket(): Promise<R2Bucket> {
  const { env } = await getCloudflareContext({ async: true })
  return env.BLOB
}

export interface PutBlobResult {
  pathname: string
  contentType: string
  size: number
}

export async function putBlob(
  pathname: string,
  body: ReadableStream | ArrayBuffer | string,
  contentType: string,
  store: R2Bucket,
): Promise<PutBlobResult> {
  const key = withRandomSuffix(pathname)
  const object = await store.put(key, body, { httpMetadata: { contentType } })
  return { pathname: key, contentType, size: object?.size ?? 0 }
}
