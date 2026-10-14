import { type NextRequest, NextResponse } from 'next/server'
import { bucket } from '@/lib/blob/server'

// Delivery route for private blobs.
// The R2 bucket is not public; this route streams the object after
// authenticating the request.
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
    },
  })
}
