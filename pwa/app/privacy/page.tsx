import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'KinCircle — Privacy Policy',
  description:
    'KinCircle privacy policy: how we collect, use, and protect your location, circle membership, sensor, and account data.',
  openGraph: {
    title: 'KinCircle — Privacy Policy',
    description:
      'KinCircle privacy policy: how we collect, use, and protect your location, circle membership, sensor, and account data.',
    url: 'https://kincircle-live.web.app/privacy',
  },
};

export default function PrivacyPolicyPage() {
  const gaId = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID || process.env.GA_MEASUREMENT_ID;

  return (
    <div style={{ minHeight: '100vh', background: '#0B132B', color: '#F8FAFC', display: 'flex', flexDirection: 'column' }}>
      {/* Optional GA4 tracking for marketing pages */}
      {gaId && (
        <>
          <script async src={`https://www.googletagmanager.com/gtag/js?id=${gaId}`} />
          <script
            dangerouslySetInnerHTML={{
              __html: `
                window.dataLayer = window.dataLayer || [];
                function gtag(){dataLayer.push(arguments);}
                gtag('js', new Date());
                gtag('config', '${gaId}');
              `,
            }}
          />
        </>
      )}

      {/* Header / Nav */}
      <header style={{ borderBottom: '1px solid #1E293B', padding: '16px 24px', background: '#0F172A' }}>
        <div style={{ maxWidth: 860, margin: '0 auto', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Link href="/" style={{ color: '#FFFFFF', textDecoration: 'none', fontSize: 20, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
            KinCircle
          </Link>
          <nav style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
            <Link href="/" style={{ color: '#94A3B8', textDecoration: 'none', fontSize: 14 }}>Home</Link>
            <Link href="/dashboard" style={{ color: '#38BDF8', textDecoration: 'none', fontSize: 14, fontWeight: 600 }}>Web App</Link>
          </nav>
        </div>
      </header>

      {/* Main Content */}
      <main style={{ maxWidth: 860, margin: '0 auto', padding: '40px 24px 64px 24px', flex: 1 }}>
        <h1 style={{ fontSize: 32, fontWeight: 800, color: '#FFFFFF', marginBottom: 8 }}>Privacy Policy</h1>
        <p style={{ color: '#94A3B8', fontSize: 14, marginBottom: 32 }}>Last updated: August 2026</p>

        <section style={{ marginBottom: 32 }}>
          <h2 style={{ fontSize: 20, fontWeight: 700, color: '#38BDF8', marginBottom: 12 }}>1. Our Privacy Commitment</h2>
          <p style={{ color: '#CBD5E1', lineHeight: 1.7, fontSize: 15, marginBottom: 12 }}>
            KinCircle is built on a simple principle: family safety software should bring calm and peace of mind without compromising your privacy. We collect only the data necessary to provide circle location sharing, safe zone arrival alerts, and emergency crash detection. We never sell your personal data, never track you for third-party advertisements, and never share location information outside your accepted family circles.
          </p>
        </section>

        <section style={{ marginBottom: 32 }}>
          <h2 style={{ fontSize: 20, fontWeight: 700, color: '#38BDF8', marginBottom: 12 }}>2. Information We Collect</h2>
          <ul style={{ color: '#CBD5E1', lineHeight: 1.7, fontSize: 15, paddingLeft: 20 }}>
            <li style={{ marginBottom: 8 }}>
              <strong>Account Information:</strong> When you register or sign in, we collect your email address and display name.
            </li>
            <li style={{ marginBottom: 8 }}>
              <strong>Real-Time Location Data:</strong> With your explicit consent, we collect precise GPS latitude and longitude coordinates to share with members of your active family circle and trigger geofence safe zone alerts.
            </li>
            <li style={{ marginBottom: 8 }}>
              <strong>Family Circles &amp; Membership:</strong> Information about family circles you create or join, member lists, and invite tokens.
            </li>
            <li style={{ marginBottom: 8 }}>
              <strong>Motion &amp; Sensor Data:</strong> Accelerometer and motion sensor telemetry collected during active trips to detect severe impact (crash detection) and calculate driving safety scores.
            </li>
          </ul>
        </section>

        <section style={{ marginBottom: 32 }}>
          <h2 style={{ fontSize: 20, fontWeight: 700, color: '#38BDF8', marginBottom: 12 }}>3. How Your Data Is Shared</h2>
          <p style={{ color: '#CBD5E1', lineHeight: 1.7, fontSize: 15, marginBottom: 12 }}>
            <strong>Within Your Circles:</strong> Your real-time location and safe zone status are visible only to accepted members of your family circle. You can toggle Invisible Mode at any time to temporarily hide your location.
          </p>
          <p style={{ color: '#CBD5E1', lineHeight: 1.7, fontSize: 15 }}>
            <strong>No Third-Party Advertising:</strong> We do not broker, rent, or sell location or behavioral data to data brokers or ad networks.
          </p>
        </section>

        <section style={{ marginBottom: 32 }}>
          <h2 style={{ fontSize: 20, fontWeight: 700, color: '#38BDF8', marginBottom: 12 }}>4. Backend Infrastructure &amp; Service Providers</h2>
          <p style={{ color: '#CBD5E1', lineHeight: 1.7, fontSize: 15, marginBottom: 12 }}>
            We rely on trusted cloud infrastructure to operate KinCircle securely:
          </p>
          <ul style={{ color: '#CBD5E1', lineHeight: 1.7, fontSize: 15, paddingLeft: 20 }}>
            <li style={{ marginBottom: 8 }}>
              <strong>Google Cloud &amp; Firebase:</strong> Used for secure authentication, Cloud Firestore database storage, Cloud Functions, and Firebase Hosting.
            </li>
            <li style={{ marginBottom: 8 }}>
              <strong>SendGrid (Twilio):</strong> Used strictly for transmitting transactional family circle invitation emails requested by users.
            </li>
            <li style={{ marginBottom: 8 }}>
              <strong>Analytics &amp; Cookies:</strong> We use Google Analytics 4 (GA4) with anonymized IP tracking solely on our public marketing and landing web pages to measure aggregate website traffic. Analytics tracking is not present on private dashboards or authenticated family data pages.
            </li>
          </ul>
        </section>

        <section style={{ marginBottom: 32 }}>
          <h2 style={{ fontSize: 20, fontWeight: 700, color: '#38BDF8', marginBottom: 12 }}>5. Data Security &amp; Encryption</h2>
          <p style={{ color: '#CBD5E1', lineHeight: 1.7, fontSize: 15 }}>
            All data in transit is encrypted using industry-standard TLS. In accordance with GDPR and data portability standards, full account data exports requested by users can be locally encrypted on device using AES-256 with secure enclave key storage.
          </p>
        </section>

        <section style={{ marginBottom: 32 }}>
          <h2 style={{ fontSize: 20, fontWeight: 700, color: '#38BDF8', marginBottom: 12 }}>6. Your Rights &amp; Data Deletion</h2>
          <p style={{ color: '#CBD5E1', lineHeight: 1.7, fontSize: 15, marginBottom: 12 }}>
            You have full control over your personal information:
          </p>
          <ul style={{ color: '#CBD5E1', lineHeight: 1.7, fontSize: 15, paddingLeft: 20 }}>
            <li style={{ marginBottom: 8 }}>Leave or delete family circles at any time.</li>
            <li style={{ marginBottom: 8 }}>Export all stored account data and location history.</li>
            <li style={{ marginBottom: 8 }}>Permanently delete your KinCircle account and associated data directly from the app or by contacting support.</li>
          </ul>
        </section>

        <section>
          <h2 style={{ fontSize: 20, fontWeight: 700, color: '#38BDF8', marginBottom: 12 }}>7. Contact Us</h2>
          <p style={{ color: '#CBD5E1', lineHeight: 1.7, fontSize: 15 }}>
            If you have questions regarding this Privacy Policy or your data, please contact the KinCircle team at <a href="mailto:PUT_YOUR_REAL_EMAIL_HERE" style={{ color: '#38BDF8', textDecoration: 'underline' }}>PUT_YOUR_REAL_EMAIL_HERE</a>.
          </p>
        </section>
      </main>

      {/* Footer */}
      <footer style={{ borderTop: '1px solid #1E293B', padding: '24px', background: '#0F172A', textAlign: 'center', color: '#64748B', fontSize: 13 }}>
        <div style={{ maxWidth: 860, margin: '0 auto', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
          <span>© {new Date().getFullYear()} KinCircle. All rights reserved.</span>
          <div style={{ display: 'flex', gap: 16 }}>
            <Link href="/" style={{ color: '#94A3B8', textDecoration: 'none' }}>Home</Link>
            <Link href="/privacy" style={{ color: '#38BDF8', textDecoration: 'none' }}>Privacy Policy</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
