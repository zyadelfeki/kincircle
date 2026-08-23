import type { Metadata } from 'next';
import DashboardClient from './DashboardClient';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'KinCircle — Family Dashboard',
  description: 'Manage your family circles, view pending invitations, and coordinate family safety with KinCircle.',
};

export type Family = { id: string; name: string };
export type Invite = { id: string; familyId: string; recipientEmail: string; status: string; createdAt?: string };

export default function Dashboard() {
  return <DashboardClient />;
}
