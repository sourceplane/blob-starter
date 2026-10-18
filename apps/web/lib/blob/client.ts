// The browser half of what `@vercel/blob/client` did: upload a File to this
// app's /api/upload route with progress, and get back the stored pathname.
// Blob's client uploaded straight to Vercel's store with a token minted by
// the route; here the route is the store's front door, so no token round
// trip and no size the Worker cannot see.

// The types the route accepts, for the file input and the uploader's own
// check before it sends anything: raster images only, no SVG.
export { ALLOWED_CONTENT_TYPES, NOT_ALLOWED_MESSAGE, isAllowedContentType } from './content-types'

export interface UploadOptions {
  access?: 'private' | 'public'
  handleUploadUrl: string
  onUploadProgress?: (event: { loaded: number; total: number; percentage: number }) => void
}

export interface UploadResult {
  pathname: string
  contentType: string
  size: number
}

export function upload(pathname: string, file: File, options: UploadOptions): Promise<UploadResult> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    const url = `${options.handleUploadUrl}?pathname=${encodeURIComponent(pathname)}`
    xhr.open('PUT', url)
    xhr.setRequestHeader('Content-Type', file.type || 'application/octet-stream')
    xhr.upload.onprogress = (e) => {
      if (!e.lengthComputable) return
      options.onUploadProgress?.({
        loaded: e.loaded,
        total: e.total,
        percentage: Math.round((e.loaded / e.total) * 100),
      })
    }
    xhr.onload = () => {
      let body: unknown = null
      try {
        body = JSON.parse(xhr.responseText)
      } catch {
        // not json
      }
      if (xhr.status >= 200 && xhr.status < 300) {
        resolve(body as UploadResult)
      } else {
        const message =
          (body as { error?: string } | null)?.error ?? `Upload failed (${xhr.status})`
        reject(new Error(message))
      }
    }
    xhr.onerror = () => reject(new Error('Upload failed'))
    xhr.send(file)
  })
}
