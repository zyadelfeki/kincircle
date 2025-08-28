import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs';

export async function POST(request: Request) {
  const { searchParams } = new URL(request.url);
  const inviteId = searchParams.get('invite_id');
  if (!inviteId) return NextResponse.json({ error: 'invite_id required' }, { status: 400 });

  const supabase = createRouteHandlerClient({ cookies });
  const {
    data: { user }
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  // Fetch invite and verify recipient
  const { data: invite, error: invErr } = await supabase
    .from('invites')
    .select('id,recipient_email')
    .eq('id', inviteId)
    .single();
  if (invErr || !invite) return NextResponse.json({ error: 'invite not found' }, { status: 404 });

  if (invite.recipient_email !== user.email) return NextResponse.json({ error: 'forbidden' }, { status: 403 });

  // Delete invite (decline)
  const { error: delErr } = await supabase.from('invites').delete().eq('id', inviteId);
  if (delErr) return NextResponse.json({ error: delErr.message }, { status: 400 });

  return NextResponse.json({ ok: true });
}
