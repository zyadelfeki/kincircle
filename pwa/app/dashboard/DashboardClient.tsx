"use client";
import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import {
  onAuthStateChanged,
  isSignInWithEmailLink,
  signInWithEmailLink,
  signOut,
  type User,
} from 'firebase/auth';
import {
  collection,
  query,
  where,
  onSnapshot,
  addDoc,
  setDoc,
  doc,
  serverTimestamp,
} from 'firebase/firestore';
import { auth, db } from '@/lib/firebaseClient';
import type { Family, Invite } from './page';

export default function DashboardClient() {
  const router = useRouter();
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [families, setFamilies] = useState<Family[]>([]);
  const [invites, setInvites] = useState<Invite[]>([]);
  const [email, setEmail] = useState('');
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    // 1. Check if returning from email link sign in
    if (typeof window !== 'undefined' && isSignInWithEmailLink(auth, window.location.href)) {
      let storedEmail = window.localStorage.getItem('emailForSignIn');
      if (!storedEmail) {
        storedEmail = window.prompt('Please provide your email for sign-in confirmation');
      }
      if (storedEmail) {
        signInWithEmailLink(auth, storedEmail, window.location.href)
          .then(() => {
            window.localStorage.removeItem('emailForSignIn');
            // Clean url
            window.history.replaceState(null, '', window.location.pathname);
          })
          .catch((err) => {
            console.error('Sign in link error:', err);
            alert(err.message || 'Failed to complete email link sign in');
          });
      }
    }

    // 2. Auth state listener
    const unsubscribeAuth = onAuthStateChanged(auth, (user) => {
      setCurrentUser(user);
      setLoading(false);
    });

    return () => unsubscribeAuth();
  }, []);

  // 3. Realtime Firestore subscriptions for families and invites
  useEffect(() => {
    if (!currentUser) {
      setFamilies([]);
      setInvites([]);
      return;
    }

    // Subscribe to families where current user is a member
    const familiesQuery = query(
      collection(db, 'families'),
      where('members', 'array-contains', currentUser.uid)
    );

    const unsubscribeFamilies = onSnapshot(familiesQuery, (snapshot) => {
      const famList: Family[] = [];
      snapshot.forEach((docSnap) => {
        const data = docSnap.data();
        famList.push({
          id: docSnap.id,
          name: data.name || 'Family Circle',
        });
      });
      setFamilies(famList);
    }, (error) => {
      console.error('Families subscription error:', error);
    });

    // Subscribe to pending invites sent to user's email
    const userEmail = currentUser.email?.trim().toLowerCase() || '';
    if (!userEmail) {
      return () => {
        unsubscribeFamilies();
      };
    }

    const invitesQuery = query(
      collection(db, 'invites'),
      where('recipientEmail', '==', userEmail),
      where('status', '==', 'pending')
    );

    const unsubscribeInvites = onSnapshot(invitesQuery, (snapshot) => {
      const invList: Invite[] = [];
      snapshot.forEach((docSnap) => {
        const data = docSnap.data();
        invList.push({
          id: docSnap.id,
          familyId: data.familyId || '',
          recipientEmail: data.recipientEmail || '',
          status: data.status || 'pending',
          createdAt: data.createdAt?.toDate?.()?.toISOString() || '',
        });
      });
      setInvites(invList);
    }, (error) => {
      console.error('Invites subscription error:', error);
    });

    return () => {
      unsubscribeFamilies();
      unsubscribeInvites();
    };
  }, [currentUser]);

  async function handleCreateFamily() {
    const name = prompt('Enter a name for your family circle (e.g. The Smiths):');
    if (!name || !name.trim() || !currentUser) return;

    setActionLoading(true);
    try {
      const familyRef = await addDoc(collection(db, 'families'), {
        name: name.trim(),
        ownerId: currentUser.uid,
        members: [currentUser.uid],
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });

      // Update user doc with currentFamilyId
      await setDoc(doc(db, 'users', currentUser.uid), {
        currentFamilyId: familyRef.id,
        email: currentUser.email,
        updatedAt: serverTimestamp(),
      }, { merge: true });
    } catch (err: any) {
      alert(err.message || 'Failed to create family');
    } finally {
      setActionLoading(false);
    }
  }

  async function handleSendInvite(e: React.FormEvent) {
    e.preventDefault();
    if (!email || !email.trim() || !currentUser) return;
    const currentFamily = families[0];
    if (!currentFamily) {
      return alert('Please create or join a family circle first.');
    }

    setActionLoading(true);
    try {
      await addDoc(collection(db, 'invites'), {
        senderUid: currentUser.uid,
        recipientEmail: email.trim().toLowerCase(),
        familyId: currentFamily.id,
        status: 'pending',
        createdAt: serverTimestamp(),
      });
      setEmail('');
      alert(`Invitation sent to ${email}!`);
    } catch (err: any) {
      alert(err.message || 'Failed to send invite');
    } finally {
      setActionLoading(false);
    }
  }

  async function handleAccept(inviteId: string) {
    if (!currentUser) return;
    setActionLoading(true);
    try {
      const idToken = await currentUser.getIdToken();
      const res = await fetch(`/api/accept-invite?invite_id=${inviteId}`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${idToken}`,
        },
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.error || 'Failed to accept invitation');
      }
    } catch (err: any) {
      alert(err.message || 'Error accepting invitation');
    } finally {
      setActionLoading(false);
    }
  }

  async function handleDecline(inviteId: string) {
    if (!currentUser) return;
    setActionLoading(true);
    try {
      const idToken = await currentUser.getIdToken();
      const res = await fetch(`/api/decline-invite?invite_id=${inviteId}`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${idToken}`,
        },
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.error || 'Failed to decline invitation');
      }
    } catch (err: any) {
      alert(err.message || 'Error declining invitation');
    } finally {
      setActionLoading(false);
    }
  }

  async function handleSignOut() {
    await signOut(auth);
    router.push('/');
  }

  if (loading) {
    return (
      <div style={{ minHeight: '100vh', background: '#0B132B', color: '#F8FAFC', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <p style={{ color: '#94A3B8' }}>Loading KinCircle...</p>
      </div>
    );
  }

  if (!currentUser) {
    return (
      <div style={{ minHeight: '100vh', background: '#0B132B', color: '#F8FAFC', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 24, textAlign: 'center' }}>
        <h2 style={{ fontSize: 24, fontWeight: 700, marginBottom: 12 }}>Sign In Required</h2>
        <p style={{ color: '#94A3B8', marginBottom: 24, maxWidth: 400 }}>
          Please sign in with your email link to view and manage your family circles.
        </p>
        <Link href="/" style={{ background: '#2E86AB', color: '#FFFFFF', padding: '10px 20px', borderRadius: 8, textDecoration: 'none', fontWeight: 600 }}>
          Go to Sign In
        </Link>
      </div>
    );
  }

  return (
    <div style={{ minHeight: '100vh', background: '#0B132B', color: '#F8FAFC', display: 'flex', flexDirection: 'column' }}>
      {/* Top Header */}
      <header style={{ borderBottom: '1px solid #1E293B', padding: '16px 24px', background: '#0F172A' }}>
        <div style={{ maxWidth: 860, margin: '0 auto', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Link href="/" style={{ color: '#FFFFFF', textDecoration: 'none', fontSize: 20, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 10 }}>
            <img src="/icons/icon-192.png" alt="KinCircle brand logo icon" width="28" height="28" style={{ borderRadius: 6 }} />
            KinCircle
          </Link>
          <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
            <span style={{ fontSize: 13, color: '#94A3B8' }}>{currentUser.email}</span>
            <button
              onClick={handleSignOut}
              style={{ background: '#334155', color: '#F8FAFC', border: 'none', padding: '6px 14px', borderRadius: 6, fontSize: 13, cursor: 'pointer' }}
            >
              Sign Out
            </button>
          </div>
        </div>
      </header>

      {/* Main Dashboard Content */}
      <main style={{ maxWidth: 860, margin: '32px auto', padding: '0 24px', width: '100%', boxSizing: 'border-box' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
          <div>
            <h1 style={{ fontSize: 28, fontWeight: 800, margin: 0 }}>Family Dashboard</h1>
            <p style={{ color: '#94A3B8', fontSize: 14, marginTop: 4 }}>Manage circles and invitations</p>
          </div>
          <button
            onClick={handleCreateFamily}
            disabled={actionLoading}
            style={{ background: '#2E86AB', color: '#FFFFFF', border: 'none', padding: '10px 18px', borderRadius: 8, fontSize: 14, fontWeight: 600, cursor: 'pointer', opacity: actionLoading ? 0.7 : 1 }}
          >
            + Create Family
          </button>
        </div>

        {/* Pending Invites Section */}
        <section style={{ background: '#1E293B', border: '1px solid #334155', borderRadius: 16, padding: 24, marginBottom: 24 }}>
          <h2 style={{ fontSize: 18, fontWeight: 700, marginTop: 0, marginBottom: 16, color: '#38BDF8' }}>
            Pending Invitations {invites.length > 0 && `(${invites.length})`}
          </h2>
          {invites.length === 0 ? (
            <p style={{ color: '#94A3B8', fontSize: 14, margin: 0 }}>No pending invitations.</p>
          ) : (
            <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 12 }}>
              {invites.map((inv) => (
                <li key={inv.id} style={{ background: '#0F172A', border: '1px solid #334155', borderRadius: 10, padding: '14px 16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
                  <div>
                    <div style={{ fontWeight: 600, fontSize: 15 }}>Circle Invitation</div>
                    <div style={{ color: '#94A3B8', fontSize: 13 }}>Family ID: {inv.familyId}</div>
                  </div>
                  <div style={{ display: 'flex', gap: 10 }}>
                    <button
                      onClick={() => handleAccept(inv.id)}
                      disabled={actionLoading}
                      style={{ background: '#22C55E', color: '#FFFFFF', border: 'none', padding: '8px 16px', borderRadius: 6, fontSize: 13, fontWeight: 600, cursor: 'pointer' }}
                    >
                      Accept
                    </button>
                    <button
                      onClick={() => handleDecline(inv.id)}
                      disabled={actionLoading}
                      style={{ background: '#475569', color: '#F8FAFC', border: 'none', padding: '8px 16px', borderRadius: 6, fontSize: 13, cursor: 'pointer' }}
                    >
                      Decline
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>

        {/* Your Families Section */}
        <section style={{ background: '#1E293B', border: '1px solid #334155', borderRadius: 16, padding: 24, marginBottom: 24 }}>
          <h2 style={{ fontSize: 18, fontWeight: 700, marginTop: 0, marginBottom: 16 }}>Your Family Circles</h2>
          {families.length === 0 ? (
            <p style={{ color: '#94A3B8', fontSize: 14, margin: 0 }}>
              You are not a member of any family circle yet. Click "+ Create Family" above to get started.
            </p>
          ) : (
            <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 12 }}>
              {families.map((f) => (
                <li key={f.id} style={{ background: '#0F172A', border: '1px solid #334155', borderRadius: 10, padding: '16px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: 16, fontWeight: 600 }}>{f.name}</span>
                  <span style={{ fontSize: 12, color: '#64748B' }}>ID: {f.id}</span>
                </li>
              ))}
            </ul>
          )}
        </section>

        {/* Send Invite Section */}
        {families.length > 0 && (
          <section style={{ background: '#1E293B', border: '1px solid #334155', borderRadius: 16, padding: 24 }}>
            <h2 style={{ fontSize: 18, fontWeight: 700, marginTop: 0, marginBottom: 8 }}>Invite Family Member</h2>
            <p style={{ color: '#94A3B8', fontSize: 14, marginBottom: 16 }}>
              Send an email invite to join your circle ({families[0].name}).
            </p>
            <form onSubmit={handleSendInvite} style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="member@example.com"
                style={{ flex: 1, minWidth: 240, padding: '10px 14px', background: '#0F172A', border: '1px solid #475569', borderRadius: 8, color: '#FFFFFF', fontSize: 14 }}
              />
              <button
                type="submit"
                disabled={actionLoading}
                style={{ background: '#2E86AB', color: '#FFFFFF', border: 'none', padding: '10px 20px', borderRadius: 8, fontSize: 14, fontWeight: 600, cursor: 'pointer', opacity: actionLoading ? 0.7 : 1 }}
              >
                Send Invite
              </button>
            </form>
          </section>
        )}
      </main>
    </div>
  );
}
