import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'KinCircle',
  description: 'Family safety, privacy-first',
  manifest: '/manifest.webmanifest'
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
