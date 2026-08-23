# KinCircle PWA (Next.js + Firebase)

PWA-first shell for KinCircle: auth, families, invites. Firebase provides Authentication, Firestore, and Realtime sync matching the mobile app backend.

## Setup

1. Copy `.env.example` to `.env.local` and fill `NEXT_PUBLIC_FIREBASE_*` configuration variables.
2. Install deps and run:

```bash
npm install
npm run dev
```

Visit http://localhost:3000

## Features
- Email magic link authentication via Firebase Auth.
- Create family circles (writes to Firestore `families` collection).
- Send invites (writes to Firestore `invites` collection).
- Accept / decline invites via Firebase Admin API routes.
- PWA manifest + basic service worker.
