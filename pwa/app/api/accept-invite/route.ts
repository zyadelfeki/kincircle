import { NextResponse } from 'next/server';
import * as admin from 'firebase-admin';
import { adminAuth, adminDb } from '@/lib/firebaseAdmin';

export async function POST(request: Request) {
  const { searchParams } = new URL(request.url);
  const inviteId = searchParams.get('invite_id');
  if (!inviteId) {
    return NextResponse.json({ error: 'invite_id required' }, { status: 400 });
  }

  const authHeader = request.headers.get('Authorization') || request.headers.get('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return NextResponse.json({ error: 'unauthorized: missing bearer token' }, { status: 401 });
  }

  const token = authHeader.split('Bearer ')[1]?.trim();
  let decodedToken;
  try {
    decodedToken = await adminAuth.verifyIdToken(token);
  } catch (err: any) {
    return NextResponse.json({ error: 'unauthorized: invalid token', details: err.message }, { status: 401 });
  }

  const uid = decodedToken.uid;
  const userEmail = decodedToken.email?.trim().toLowerCase();

  // Fetch invite document
  const inviteRef = adminDb.collection('invites').doc(inviteId);
  const inviteSnap = await inviteRef.get();
  if (!inviteSnap.exists) {
    return NextResponse.json({ error: 'invite not found' }, { status: 404 });
  }

  const inviteData = inviteSnap.data() || {};
  const recipientEmail = inviteData.recipientEmail?.trim().toLowerCase();

  if (recipientEmail && userEmail && recipientEmail !== userEmail) {
    return NextResponse.json({ error: 'forbidden: invite recipient mismatch' }, { status: 403 });
  }

  const familyId = inviteData.familyId;
  if (!familyId) {
    return NextResponse.json({ error: 'invalid invite: missing familyId' }, { status: 400 });
  }

  try {
    // 1. Update ONLY the invite's status field (or updatedAt)
    await inviteRef.update({
      status: 'accepted',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Add user to family members array
    const familyRef = adminDb.collection('families').doc(familyId);
    await familyRef.update({
      members: admin.firestore.FieldValue.arrayUnion(uid),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 3. Set currentFamilyId on user doc
    await adminDb.collection('users').doc(uid).set({
      currentFamilyId: familyId,
      email: decodedToken.email,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return NextResponse.json({ ok: true, familyId });
  } catch (err: any) {
    console.error('Error accepting invite:', err);
    return NextResponse.json({ error: 'failed to accept invite', details: err.message }, { status: 500 });
  }
}
