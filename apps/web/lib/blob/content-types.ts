// What an upload may be, shared by the uploader (the file input's `accept`
// and its check before the upload) and the upload route (the check that
// counts). Raster images only: an SVG is a document that can carry script,
// and the delivery route serves whatever the bucket holds from this app's
// own origin.

export const ALLOWED_CONTENT_TYPES = [
  'image/png',
  'image/jpeg',
  'image/gif',
  'image/webp',
  'image/avif',
] as const

export const NOT_ALLOWED_MESSAGE = 'We only accept PNG, JPEG, GIF, WebP and AVIF images'

// Compares the media type alone: parameters (`; charset=…`) and case do not
// change what the browser will make of the file.
export function isAllowedContentType(contentType: string | null | undefined): boolean {
  if (!contentType) return false
  const [mediaType = ''] = contentType.split(';')
  return (ALLOWED_CONTENT_TYPES as readonly string[]).includes(mediaType.trim().toLowerCase())
}
