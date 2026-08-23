"use client";
import { useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { sendSignInLinkToEmail } from 'firebase/auth';
import { auth } from '@/lib/firebaseClient';

export default function Home() {
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);
  const [loading, setLoading] = useState(false);

  async function signIn(e: React.FormEvent) {
    e.preventDefault();
    if (!email) return;
    setLoading(true);
    try {
      const actionCodeSettings = {
        url: `${window.location.origin}/dashboard`,
        handleCodeInApp: true,
      };
      await sendSignInLinkToEmail(auth, email, actionCodeSettings);
      window.localStorage.setItem('emailForSignIn', email);
      setSent(true);
    } catch (err: any) {
      alert(err.message || 'An error occurred during sign in');
    } finally {
      setLoading(false);
    }
  }

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'MobileApplication',
    name: 'KinCircle',
    operatingSystem: 'Android, iOS',
    applicationCategory: 'LifestyleApplication',
    description:
      'A calm, family-first safety and coordination app with real-time circle location sharing, safe zone alerts, and one-tap SOS.',
  };

  const gaId = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID || process.env.GA_MEASUREMENT_ID;

  return (
    <div className="landing-container" style={{ minHeight: '100vh', background: '#0B132B', color: '#F8FAFC', display: 'flex', flexDirection: 'column' }}>
      {/* MobileApplication JSON-LD Schema */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />

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

      {/* Top Navigation */}
      <header style={{ borderBottom: '1px solid #1E293B', padding: '16px 24px', background: '#0F172A', position: 'sticky', top: 0, zIndex: 40 }}>
        <div style={{ maxWidth: 1080, margin: '0 auto', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Link href="/" style={{ color: '#FFFFFF', textDecoration: 'none', fontSize: 20, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 10 }}>
            <img src="/icons/icon-192.png" alt="KinCircle brand logo icon" width="28" height="28" style={{ borderRadius: 6 }} />
            KinCircle
          </Link>
          <nav style={{ display: 'flex', gap: 20, alignItems: 'center' }}>
            <a href="#faq" style={{ color: '#94A3B8', textDecoration: 'none', fontSize: 14 }}>FAQ</a>
            <Link href="/privacy" style={{ color: '#94A3B8', textDecoration: 'none', fontSize: 14 }}>Privacy</Link>
            <Link href="/dashboard" style={{ background: '#2E86AB', color: '#FFFFFF', padding: '8px 16px', borderRadius: 8, textDecoration: 'none', fontSize: 14, fontWeight: 600 }}>
              Web App
            </Link>
          </nav>
        </div>
      </header>

      {/* Hero Section (Above the fold on mobile) */}
      <section style={{ maxWidth: 860, margin: '0 auto', padding: '40px 24px 32px 24px', textAlign: 'center' }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: 'rgba(56, 189, 248, 0.1)', border: '1px solid rgba(56, 189, 248, 0.2)', padding: '6px 14px', borderRadius: 20, color: '#38BDF8', fontSize: 13, fontWeight: 600, marginBottom: 20 }}>
          Calm Family Safety &amp; Coordination
        </div>
        <h1 style={{ fontSize: 'clamp(28px, 6vw, 44px)', fontWeight: 800, color: '#FFFFFF', lineHeight: 1.2, marginBottom: 16 }}>
          Family Safety, Calm by Design
        </h1>
        <p style={{ color: '#94A3B8', fontSize: 'clamp(15px, 3vw, 18px)', lineHeight: 1.6, maxWidth: 620, margin: '0 auto 28px auto' }}>
          Real-time location sharing, automatic safe zone arrival alerts, and instant one-tap SOS for your family circles.
        </p>

        {/* Primary CTA box above the fold */}
        <div id="get-app" style={{ maxWidth: 440, margin: '0 auto', background: '#1E293B', border: '1px solid #334155', borderRadius: 16, padding: '24px 20px', boxShadow: '0 12px 28px rgba(0,0,0,0.3)' }}>
          <h2 style={{ fontSize: 18, fontWeight: 700, color: '#FFFFFF', marginBottom: 8 }}>
            Get Started with KinCircle
          </h2>
          <p style={{ color: '#94A3B8', fontSize: 13, marginBottom: 16 }}>
            Sign in with email to launch the web app or join your family circle.
          </p>
          {sent ? (
            <div style={{ background: 'rgba(34, 197, 94, 0.1)', border: '1px solid #22C55E', borderRadius: 10, padding: 14, color: '#4ADE80', fontSize: 14 }}>
              ✓ Check your inbox for your secure magic sign-in link.
            </div>
          ) : (
            <form onSubmit={signIn} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
                style={{ width: '100%', padding: '12px 14px', background: '#0F172A', border: '1px solid #475569', borderRadius: 8, color: '#FFFFFF', fontSize: 15, boxSizing: 'border-box' }}
              />
              <button
                type="submit"
                disabled={loading}
                style={{ width: '100%', padding: '12px 16px', background: '#2E86AB', color: '#FFFFFF', border: 'none', borderRadius: 8, fontSize: 15, fontWeight: 600, cursor: 'pointer', opacity: loading ? 0.7 : 1 }}
              >
                {loading ? 'Sending link...' : 'Get the App'}
              </button>
            </form>
          )}
          <div style={{ marginTop: 14, fontSize: 12, color: '#64748B' }}>
            No password required • Free core features included
          </div>
        </div>
      </section>

      {/* Feature Highlights Grid */}
      <section style={{ maxWidth: 1080, margin: '20px auto 40px auto', padding: '0 24px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 20 }}>
          <div style={{ background: '#1E293B', border: '1px solid #334155', borderRadius: 16, padding: 24 }}>
            <div style={{ width: 44, height: 44, borderRadius: 10, background: 'rgba(56, 189, 248, 0.15)', color: '#38BDF8', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, marginBottom: 16 }}>
              📍
            </div>
            <h3 style={{ fontSize: 17, fontWeight: 700, color: '#FFFFFF', marginBottom: 8 }}>Private Family Circles</h3>
            <p style={{ color: '#94A3B8', fontSize: 14, lineHeight: 1.5 }}>
              Share precise, real-time location exclusively with verified family members who you invite.
            </p>
          </div>

          <div style={{ background: '#1E293B', border: '1px solid #334155', borderRadius: 16, padding: 24 }}>
            <div style={{ width: 44, height: 44, borderRadius: 10, background: 'rgba(34, 197, 94, 0.15)', color: '#22C55E', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, marginBottom: 16 }}>
              🛡️
            </div>
            <h3 style={{ fontSize: 17, fontWeight: 700, color: '#FFFFFF', marginBottom: 8 }}>Safe Zone Alerts</h3>
            <p style={{ color: '#94A3B8', fontSize: 14, lineHeight: 1.5 }}>
              Create custom geofences around home, school, and work with automatic departure and arrival notifications.
            </p>
          </div>

          <div style={{ background: '#1E293B', border: '1px solid #334155', borderRadius: 16, padding: 24 }}>
            <div style={{ width: 44, height: 44, borderRadius: 10, background: 'rgba(239, 68, 68, 0.15)', color: '#EF4444', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, marginBottom: 16 }}>
              🚨
            </div>
            <h3 style={{ fontSize: 17, fontWeight: 700, color: '#FFFFFF', marginBottom: 8 }}>One-Tap SOS Alert</h3>
            <p style={{ color: '#94A3B8', fontSize: 14, lineHeight: 1.5 }}>
              Send an instant emergency broadcast with live GPS coordinates to all family circle members in critical moments.
            </p>
          </div>

          <div style={{ background: '#1E293B', border: '1px solid #334155', borderRadius: 16, padding: 24 }}>
            <div style={{ width: 44, height: 44, borderRadius: 10, background: 'rgba(168, 85, 247, 0.15)', color: '#A855F7', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, marginBottom: 16 }}>
              🔒
            </div>
            <h3 style={{ fontSize: 17, fontWeight: 700, color: '#FFFFFF', marginBottom: 8 }}>Privacy-First Design</h3>
            <p style={{ color: '#94A3B8', fontSize: 14, lineHeight: 1.5 }}>
              Zero ad tracking and no selling data to brokers. Easily toggle Invisible Mode anytime you want privacy.
            </p>
          </div>
        </div>
      </section>

      {/* Honest FAQ Section */}
      <section id="faq" style={{ maxWidth: 860, margin: '40px auto 60px auto', padding: '0 24px' }}>
        <h2 style={{ fontSize: 28, fontWeight: 800, color: '#FFFFFF', textAlign: 'center', marginBottom: 12 }}>
          Frequently Asked Questions
        </h2>
        <p style={{ color: '#94A3B8', fontSize: 15, textAlign: 'center', marginBottom: 36 }}>
          Honest answers about how KinCircle protects your family and respects your data.
        </p>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ background: '#1E293B', border: '1px solid #334155', borderRadius: 14, padding: '20px 24px' }}>
            <h3 style={{ fontSize: 17, fontWeight: 700, color: '#38BDF8', marginBottom: 8 }}>What is KinCircle?</h3>
            <p style={{ color: '#CBD5E1', fontSize: 14, lineHeight: 1.6 }}>
              KinCircle is a calm, family-first safety and coordination platform. It lets you create private circles with your family to share live locations on a map, receive automatic notifications when loved ones arrive at or leave safe zones (like home or school), and trigger instant emergency SOS alerts.
            </p>
          </div>

          <div style={{ background: '#1E293B', border: '1px solid #334155', borderRadius: 14, padding: '20px 24px' }}>
            <h3 style={{ fontSize: 17, fontWeight: 700, color: '#38BDF8', marginBottom: 8 }}>Who can see my location?</h3>
            <p style={{ color: '#CBD5E1', fontSize: 14, lineHeight: 1.6 }}>
              Only members of the specific family circles you have joined or created can see your location. Your location is never made public, is never visible to search engines or strangers, and is never sold to third parties or ad networks. You can also turn on Invisible Mode to pause location sharing at any time.
            </p>
          </div>

          <div style={{ background: '#1E293B', border: '1px solid #334155', borderRadius: 14, padding: '20px 24px' }}>
            <h3 style={{ fontSize: 17, fontWeight: 700, color: '#38BDF8', marginBottom: 8 }}>What data do you collect?</h3>
            <p style={{ color: '#CBD5E1', fontSize: 14, lineHeight: 1.6 }}>
              We collect basic account info (email and display name), real-time location coordinates for circle sharing, safe zone coordinates, and on-device sensor data during trips for collision detection and driving safety metrics. When you export your data, we support local AES-256 encryption.
            </p>
          </div>

          <div style={{ background: '#1E293B', border: '1px solid #334155', borderRadius: 14, padding: '20px 24px' }}>
            <h3 style={{ fontSize: 17, fontWeight: 700, color: '#38BDF8', marginBottom: 8 }}>How do invites work?</h3>
            <p style={{ color: '#CBD5E1', fontSize: 14, lineHeight: 1.6 }}>
              A circle creator generates a secure invite link or code from their app. When you open the invite link or input the code, your account is added to the circle in Firestore. Invite notification emails are delivered reliably via SendGrid without sharing any other circle details.
            </p>
          </div>

          <div style={{ background: '#1E293B', border: '1px solid #334155', borderRadius: 14, padding: '20px 24px' }}>
            <h3 style={{ fontSize: 17, fontWeight: 700, color: '#38BDF8', marginBottom: 8 }}>Is KinCircle free?</h3>
            <p style={{ color: '#CBD5E1', fontSize: 14, lineHeight: 1.6 }}>
              Yes. Core family safety features—including real-time location sharing, safe zone notifications, and one-tap emergency SOS alerts—are free. An optional KinCircle Pro subscription is available for extended location history and driver safety telemetry.
            </p>
          </div>
        </div>
      </section>

      {/* Sticky Bottom CTA Bar for Mobile Only */}
      <div className="mobile-sticky-cta" style={{ position: 'fixed', bottom: 0, left: 0, right: 0, background: '#0F172A', borderTop: '1px solid #334155', padding: '12px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', zIndex: 50, boxShadow: '0 -4px 16px rgba(0,0,0,0.4)' }}>
        <div>
          <div style={{ color: '#FFFFFF', fontWeight: 700, fontSize: 14 }}>KinCircle</div>
          <div style={{ color: '#94A3B8', fontSize: 12 }}>Family Safety &amp; Location</div>
        </div>
        <a href="#get-app" style={{ background: '#2E86AB', color: '#FFFFFF', padding: '10px 18px', borderRadius: 8, fontSize: 14, fontWeight: 600, textDecoration: 'none' }}>
          Get the App
        </a>
      </div>

      <style jsx>{`
        @media (min-width: 769px) {
          .mobile-sticky-cta {
            display: none !important;
          }
        }
      `}</style>

      {/* Footer */}
      <footer style={{ borderTop: '1px solid #1E293B', padding: '28px 24px 80px 24px', background: '#0F172A', textAlign: 'center', color: '#64748B', fontSize: 13, marginTop: 'auto' }}>
        <div style={{ maxWidth: 860, margin: '0 auto', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 16 }}>
          <span>© {new Date().getFullYear()} KinCircle. All rights reserved.</span>
          <div style={{ display: 'flex', gap: 20 }}>
            <Link href="/" style={{ color: '#94A3B8', textDecoration: 'none' }}>Home</Link>
            <a href="#faq" style={{ color: '#94A3B8', textDecoration: 'none' }}>FAQ</a>
            <Link href="/privacy" style={{ color: '#38BDF8', textDecoration: 'none' }}>Privacy Policy</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
