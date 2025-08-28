"use client";
import type React from 'react';
import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabaseClient';
import type { RealtimePostgresInsertPayload } from '@supabase/supabase-js';
import type { Family, Invite } from './page';

export default function DashboardClient({ initialFamilies, initialInvites }: { initialFamilies: Family[]; initialInvites: Invite[] }) {
  const supabase = createClient();
  const [families, setFamilies] = useState<Family[]>(initialFamilies);
  const [invites, setInvites] = useState<Invite[]>(initialInvites);
  const [email, setEmail] = useState('');

  useEffect(() => {
    const run = async () => {
      const { data: sessionData } = await supabase.auth.getSession();
      if (!sessionData.session) return;
      const userEmail = sessionData.session.user.email;
      const userId = sessionData.session.user.id;
      const channel = supabase
        .channel('invites-realtime')
        .on(
          'postgres_changes',
          { event: 'INSERT', schema: 'public', table: 'invites', filter: `recipient_email=eq.${userEmail}` },
          async (payload: RealtimePostgresInsertPayload<any>) => {
            const row = payload.new as any;
            setInvites((prev: Invite[]) => [
              { id: row.id, family_id: row.family_id, recipient_email: row.recipient_email, status: row.status, created_at: row.created_at },
              ...prev
            ]);
          }
        )
        .on(
          'postgres_changes',
          { event: 'INSERT', schema: 'public', table: 'family_members', filter: `user_id=eq.${userId}` },
          async (payload: RealtimePostgresInsertPayload<any>) => {
            const row = payload.new as any;
            // fetch the family's name and add to list if not present
            const { data: fam, error } = await supabase.from('families').select('id,name').eq('id', row.family_id).single();
            if (!error && fam && !families.find(f => f.id === fam.id)) {
              setFamilies((prev: Family[]) => [{ id: fam.id, name: fam.name }, ...prev]);
            }
          }
        )
        .subscribe();
      return () => supabase.removeChannel(channel);
    };
    const p = run();
    return () => { p.then((cleanup: any) => cleanup && cleanup()); };
  }, []);

  async function createFamily() {
    const name = prompt('Family name');
    if (!name) return;
    const { data: user } = await supabase.auth.getUser();
    const ownerId = user.user?.id;
    if (!ownerId) return alert('Not signed in');
    const { data: fams, error } = await supabase.from('families').insert({ name, owner_id: ownerId }).select('id').single();
    if (error) return alert(error.message);
    const famId = (fams as any).id as string;
    const { error: mErr } = await supabase.from('family_members').insert({ family_id: famId, user_id: ownerId, role: 'admin' });
    if (mErr) alert(mErr.message);
    setFamilies([{ id: famId, name }, ...families]);
  }

  async function sendInvite() {
    if (!email) return;
    const familyId = families[0]?.id;
    if (!familyId) return alert('Create a family first');
    const { error } = await supabase.from('invites').insert({ family_id: familyId, recipient_email: email });
    if (error) alert(error.message); else setEmail('');
  }

  async function accept(inviteId: string) {
    const res = await fetch(`/api/accept-invite?invite_id=${inviteId}`, { method: 'POST' });
    if (!res.ok) return alert('Failed to accept');
    const body = await res.json();
    setInvites(invites.filter(i => i.id !== inviteId));
    if (body.family && !families.find(f => f.id === body.family.id)) {
      setFamilies([{ id: body.family.id, name: body.family.name }, ...families]);
    }
  }

  async function decline(inviteId: string) {
    const res = await fetch(`/api/decline-invite?invite_id=${inviteId}`, { method: 'POST' });
    if (!res.ok) return alert('Failed to decline');
    setInvites(invites.filter(i => i.id !== inviteId));
  }

  return (
    <main style={{ maxWidth: 720, margin: '2rem auto', padding: 16 }}>
      <h2>Dashboard</h2>
      <button onClick={createFamily}>Create family</button>
      <section>
        <h3>Your families</h3>
        <ul>{families.map((f: Family) => (<li key={f.id}>{f.name}</li>))}</ul>
      </section>
      <section>
        <h3>Invites</h3>
        <div>
          <input value={email} onChange={(e: React.ChangeEvent<HTMLInputElement>) => setEmail(e.target.value)} placeholder="invitee@example.com" />
          <button onClick={sendInvite}>Send invite</button>
        </div>
        <ul>
          {invites.map((i: Invite) => (
            <li key={i.id}>
              {i.recipient_email} — {i.status}
              <button style={{ marginLeft: 8 }} onClick={() => accept(i.id)}>Accept</button>
              <button style={{ marginLeft: 8 }} onClick={() => decline(i.id)}>Decline</button>
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
