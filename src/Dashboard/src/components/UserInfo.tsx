import { getCurrentUserProfile } from '@/lib/auth-helpers';

/**
 * USER INFO DISPLAY (Server Component)
 * 
 * Demonstrates how to get and display user profile information server-side.
 * 
 * Benefits:
 * - No client-side state needed
 * - Profile data available immediately (no loading state needed)
 * - Works even with JavaScript disabled
 * - Consistent data from server
 */

export async function UserInfo() {
  const profile = await getCurrentUserProfile();

  if (!profile) {
    return null;
  }

  const displayName = profile.first_name && profile.last_name 
    ? `${profile.first_name} ${profile.last_name}`
    : profile.email;

  const roleDisplay = profile.role === 'admin' ? '👑 Admin' : '👤 User';
  const approvalDisplay = profile.approval_status === 'approved' ? '✓ Approved' : `⏳ ${profile.approval_status}`;

  return (
    <div className="border-b pb-4 mb-4">
      <p className="font-semibold text-sm">{displayName}</p>
      <p className="text-xs text-gray-600">{profile.email}</p>
      <div className="mt-2 space-y-1 text-xs">
        <p>
          <span className="font-medium">Role:</span> {roleDisplay}
        </p>
        <p>
          <span className="font-medium">Status:</span> {approvalDisplay}
        </p>
      </div>
    </div>
  );
}

/**
 * USAGE IN LAYOUTS:
 * 
 * src/app/layout.tsx or in your Sidenav component
 * 
 * import { UserInfo } from '@/components/UserInfo';
 * 
 * export default function Sidenav() {
 *   return (
 *     <aside className="w-64 bg-gray-100">
 *       <UserInfo />
 *       Navigation items here
 *     </aside>
 *   );
 * }
 * 
 * MIGRATION FROM CLIENT-SIDE CONTEXT:
 * 
 * If currently using useAuth() hook:
 * 
 * Before (client-side, with loading state):
 * use client;
 * const { profile, loading } = useAuth();
 * if (loading) return <Skeleton />;
 * return <div>{profile?.first_name}</div>;
 * 
 * After (server-side, instant):
 * const profile = getCurrentUserProfile();
 * return <div>{profile?.first_name}</div>;
 * 
 * Keep useAuth() for client-side interactivity only (state, events).
 * Use server components for displaying data.
 */
