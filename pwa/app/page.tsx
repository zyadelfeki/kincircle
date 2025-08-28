"use client";
import { useState } from 'react';
import { createClient } from '@/lib/supabaseClient';

export default function Home() {
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);

  async function signIn() {
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOtp({ email, options: { emailRedirectTo: `${location.origin}/dashboard` } });
    if (error) alert(error.message); else setSent(true);
  }

  return (
    <main style={{ maxWidth: 480, margin: '4rem auto', padding: 16 }}>
      <h1>KinCircle</h1>
      <p>Privacy-first family safety. Sign in with your email.</p>
      <input value={email} onChange={e => setEmail(e.target.value)} placeholder="you@example.com" style={{ width: '100%', padding: 12, marginTop: 8 }} />
      <button onClick={signIn} style={{ marginTop: 12, padding: '10px 16px' }}>Send magic link</button>
      {sent && <p>Check your inbox for a magic link.</p>}
    </main>
  );
}
