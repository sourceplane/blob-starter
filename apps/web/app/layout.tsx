import './globals.css'
import type { Metadata } from 'next'
import { headers } from 'next/headers'
import { Inter } from 'next/font/google'
import { SITE_NAME, requestOrigin } from './site'

// The Open Graph image (app/opengraph-image.png) is an absolute URL, which
// Next resolves against `metadataBase` — and, without one, against
// `http://localhost:3000`. The origin is the request's own (app/site.ts).
export async function generateMetadata(): Promise<Metadata> {
  return {
    title: SITE_NAME,
    description: 'A simple Next.js app with Cloudflare R2 for image uploads',
    metadataBase: requestOrigin(await headers()),
  }
}

const inter = Inter({
  variable: '--font-inter',
  subsets: ['latin'],
  display: 'swap',
})

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.variable}>{children}</body>
    </html>
  )
}
