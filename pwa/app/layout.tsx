import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  metadataBase: new URL('https://kincircle-live.web.app'),
  title: 'KinCircle — Family Safety, Calm by Design',
  description:
    'A calm, family-first safety and coordination app with real-time circle location sharing, safe zone alerts, and one-tap SOS.',
  manifest: '/manifest.webmanifest',
  openGraph: {
    title: 'KinCircle — Family Safety, Calm by Design',
    description:
      'A calm, family-first safety and coordination app with real-time circle location sharing, safe zone alerts, and one-tap SOS.',
    url: 'https://kincircle-live.web.app',
    siteName: 'KinCircle',
    images: [
      {
        url: '/icons/og-image.png',
        width: 1200,
        height: 630,
        alt: 'KinCircle — Family Safety, Calm by Design',
      },
    ],
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'KinCircle — Family Safety, Calm by Design',
    description:
      'A calm, family-first safety and coordination app with real-time circle location sharing, safe zone alerts, and one-tap SOS.',
    images: ['/icons/og-image.png'],
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </head>
      <body>
        {children}
        <script dangerouslySetInnerHTML={{ __html: `if ('serviceWorker' in navigator) { window.addEventListener('load', () => navigator.serviceWorker.register('/sw.js').catch(()=>{})); }` }} />
      </body>
    </html>
  );
}
