import { NextResponse } from 'next/server'
import {
  MAX_UPLOAD_BYTES,
  NOT_ALLOWED_MESSAGE,
  bucket,
  isAllowedContentType,
  putBlob,
} from '@/lib/blob/server'

// Receives the browser's upload and stores it in R2. This is the Worker's
// front door for uploads (Blob's `handleUpload` minted a client token for a
// direct upload instead): the checks the template declared — images only,
// 50MB max, a random suffix on the name — with "images" narrowed to raster
// formats (PNG, JPEG, GIF, WebP, AVIF). The template's `image/*` admitted
// SVG, which the delivery route would serve from this origin as a document
// that can run script.
//
// ⚠️ Authenticate and authorize users before accepting the upload.
// Otherwise, you're allowing anonymous uploads.
export async function PUT(request: Request): Promise<NextResponse> {
  const url = new URL(request.url)
  const pathname = url.searchParams.get('pathname')
  const contentType = request.headers.get('content-type')
  const length = Number(request.headers.get('content-length') ?? '0')

  if (!pathname) {
    return NextResponse.json({ error: 'Missing pathname' }, { status: 400 })
  }
  if (!isAllowedContentType(contentType)) {
    return NextResponse.json({ error: NOT_ALLOWED_MESSAGE }, { status: 400 })
  }
  if (length > MAX_UPLOAD_BYTES) {
    return NextResponse.json({ error: 'File size too big (max 50MB)' }, { status: 400 })
  }
  if (!request.body) {
    return NextResponse.json({ error: 'Missing file' }, { status: 400 })
  }

  try {
    const store = await bucket()
    // R2 needs a known length to stream a request body; buffer the file,
    // which the 50MB ceiling above keeps bounded.
    const bytes = await request.arrayBuffer()
    if (bytes.byteLength > MAX_UPLOAD_BYTES) {
      return NextResponse.json({ error: 'File size too big (max 50MB)' }, { status: 400 })
    }
    const blob = await putBlob(pathname, bytes, contentType as string, store)
    console.log('blob upload completed', blob)
    return NextResponse.json(blob)
  } catch (error) {
    return NextResponse.json({ error: (error as Error).message }, { status: 400 })
  }
}
