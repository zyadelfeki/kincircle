import Link from 'next/link';

export default function NotFound() {
  return (
    <div style={{ minHeight: '100vh', background: '#0B132B', color: '#F8FAFC', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <h1 style={{ fontSize: 48, fontWeight: 800, color: '#38BDF8', marginBottom: 16 }}>404</h1>
      <h2 style={{ fontSize: 24, fontWeight: 600, color: '#FFFFFF', marginBottom: 12 }}>Page Not Found</h2>
      <p style={{ color: '#94A3B8', fontSize: 16, marginBottom: 24 }}>This page does not exist or has been moved.</p>
      <Link href="/" style={{ background: '#2E86AB', color: '#FFFFFF', padding: '12px 24px', borderRadius: 8, textDecoration: 'none', fontWeight: 600 }}>
        Return Home
      </Link>
    </div>
  );
}
