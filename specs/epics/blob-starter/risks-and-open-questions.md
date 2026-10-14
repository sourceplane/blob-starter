# blob-starter — risks and open questions

## BL-A — The upload crosses the Worker (ACCEPTED)

Vercel Blob's client uploaded directly to the store; here the file passes
through the Worker and is buffered (R2 needs a known length for a streamed
body). The template's 50MB ceiling keeps that bounded and inside Workers'
request limits. Presigned URLs are the alternative when files grow
(design §2, rejected for now).

## BL-B — No `onUploadCompleted` webhook (RESOLVED)

Blob called the route back after the direct upload. Here the route is the
upload, so the completion log is the route's own `console.log` — same
message, no webhook, no ngrok caveat.

## BL-C — Anonymous uploads (ACCEPTED, as upstream)

The template says "authenticate before generating the token"; the port says
"authenticate before accepting the upload" at the same place. Neither ships
auth.

## BL-D — Page copy (RESOLVED)

"Blob on Vercel", the Vercel Blob link and the deploy button point at R2
and this repository; the layout title reads "R2 Blob Starter".
