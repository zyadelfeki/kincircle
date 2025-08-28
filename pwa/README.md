# KinCircle PWA (Next.js + Supabase)

PWA-first shell for KinCircle: auth, families, invites. Supabase/Postgres provides auth, RLS, and realtime.

## Setup

1. Create a Supabase project.
2. In the SQL editor, run `infra/supabase/schema.sql`.
3. Copy `.env.example` to `.env.local` and fill `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
4. Install deps and run:

```bash
npm install
npm run dev
```

Visit http://localhost:3000

## Features
- Magic-link auth.
- Create families (owner = current user).
- Send invites (sender auto-filled via trigger).
- PWA manifest + basic service worker.

## Notes
- RLS policies are minimal and conservative; expand as needed.
- For production, add icons and a more complete service worker caching strategy.
