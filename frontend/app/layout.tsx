import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'BookingBridge Attribution Tracker',
  description: 'Attribution tracking platform bridging ad platforms and booking systems',
  keywords: 'attribution tracking, marketing analytics, booking conversion',
  authors: [{ name: 'BookingBridge Team' }],
  viewport: 'width=device-width, initial-scale=1',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <head>
        <link rel="icon" href="/favicon.ico" />
        <link rel="manifest" href="/manifest.json" />
        <meta name="theme-color" content="#000000" />
      </head>
      <body className="bg-gray-50 text-gray-900 antialiased">
        <div id="root">
          {children}
        </div>
      </body>
    </html>
  )
}