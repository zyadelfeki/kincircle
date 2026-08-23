import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: "You're In — KinCircle",
  description: 'Your KinCircle invitation has been accepted. Download the app or use the PWA to get started.',
};

export default function InviteAcceptedPage() {
  return (
    <div style={{ minHeight: '100vh', background: '#0B132B', color: '#F8FAFC', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <div style={{ background: '#1E293B', border: '1px solid #334155', borderRadius: 20, maxWidth: 480, width: '100%', padding: '40px 28px', textAlign: 'center', boxShadow: '0 20px 40px rgba(0,0,0,0.4)' }}>
        <div style={{ width: 64, height: 64, background: 'rgba(34, 197, 94, 0.15)', border: '1px solid rgba(34, 197, 94, 0.4)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 20px auto', color: '#22C55E', fontSize: 28 }}>
          ✓
        </div>
        <h1 style={{ fontSize: 26, fontWeight: 700, color: '#FFFFFF', marginBottom: 12, lineHeight: 1.3 }}>
          You&apos;re in. Get the KinCircle app
        </h1>
        <p style={{ color: '#94A3B8', fontSize: 15, lineHeight: 1.6, marginBottom: 28 }}>
          You have joined the family circle. Open the KinCircle mobile app or launch the web dashboard to start coordinating with your family.
        </p>
        <a href="kincircle://circle" style={{ display: 'block', width: '100%', padding: 14, borderRadius: 12, fontSize: 16, fontWeight: 600, textDecoration: 'none', background: '#2E86AB', color: '#FFFFFF', marginBottom: 12 }}>
          Open KinCircle App
        </a>
        <Link href="/dashboard" style={{ display: 'block', width: '100%', padding: 14, borderRadius: 12, fontSize: 16, fontWeight: 600, textDecoration: 'none', background: '#0F172A', color: '#38BDF8', border: '1px solid #38BDF8', marginBottom: 20 }}>
          Launch Web App Dashboard
        </Link>
        <p style={{ fontSize: 13, color: '#64748B', lineHeight: 1.5 }}>
          Google Play and Apple App Store listings are coming soon. Use the PWA install prompt in your browser to add KinCircle to your home screen.
        </p>
      </div>
    </div>
  );
}
