import { createClient as create } from '@supabase/supabase-js';

export function createClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
  return create(url, anon, { auth: { persistSession: true, detectSessionInUrl: true } });
}
