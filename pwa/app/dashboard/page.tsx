import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { createServerComponentClient } from '@supabase/auth-helpers-nextjs';
import DashboardClient from './DashboardClient';

export type Family = { id: string; name: string };
export type Invite = { id: string; family_id: string; recipient_email: string; status: string; created_at: string };

export default async function Dashboard() {
  const supabase = createServerComponentClient({ cookies });
  const {
    data: { session }
  } = await supabase.auth.getSession();
  if (!session) redirect('/');

  const { data: families } = await supabase
    .from('families')
    .select('id,name')
    .order('created_at', { ascending: false });

  const { data: invites } = await supabase
    .from('invites')
    .select('id,family_id,recipient_email,status,created_at')
    .eq('recipient_email', session.user.email)
    .eq('status', 'pending')
    .order('created_at', { ascending: false });

  return (
    <DashboardClient initialFamilies={families ?? []} initialInvites={invites ?? []} />
  );
}
