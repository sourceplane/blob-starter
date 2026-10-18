import { type NextRequest, NextResponse } from 'next/server'
import { bucket } from '@/lib/blob/server'

// Delivery route for private blobs.
// The R2 bucket is not public; this route is the only way to read it, and it
// streams the object to anyone who asks for its stored name.
//
// ⚠️ Authenticate and authorize users before streaming the object.
// Otherwise, anyone with the name can read it — nothing here checks who asks.
//
// What it serves comes from this app's own origin, so the response is locked
// down whatever the bucket holds: `nosniff` holds the browser to the stored
// content type, and the CSP gives no source to load from and sandboxes the
// object (no script, an opaque origin) — so even a file that is a document,
// such as an SVG stored before the upload route refused them, cannot run.
const CONTENT_SECURITY_POLICY = "default-src 'none'; sandbox"

export async function GET(request: NextRequest) {
  // ⚠️ Add your own authentication here.
  // For example: await authRequest(request)

  const pathname = request.nextUrl.searchParams.get('pathname')

  if (!pathname) {
    return NextResponse.json({ error: 'Missing pathname' }, { status: 400 })
  }

  const store = await bucket()
  const object = await store.get(pathname)

  if (!object) {
    return new NextResponse('Not found', { status: 404 })
  }

  return new NextResponse(object.body, {
    headers: {
      'Content-Type': object.httpMetadata?.contentType ?? 'application/octet-stream',
      'Content-Length': String(object.size),
      ETag: object.httpEtag,
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': CONTENT_SECURITY_POLICY,
    },
  })
}
