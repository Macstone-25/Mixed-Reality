import { isCurrentUserAdmin } from '@/lib/auth-helpers';

/**
 * EXAMPLE: Admin Navigation Links
 * 
 * This component shows how to conditionally render admin links based on role.
 * Use this pattern in your navigation/sidebar components.
 * 
 * Benefits:
 * - Server-side role check (more secure than client-side)
 * - Don't show admin UI to non-admin users at all
 * - Reduces payload size for non-admin users
 */

export async function AdminNavLinks() {
  // Check role server-side
  // No client-side JS needed for this decision
  const isAdmin = await isCurrentUserAdmin();

  if (!isAdmin) {
    return null; // Don't render anything for non-admins
  }

  return (
    <>
      <div className="my-4 border-t border-gray-200"></div>
      <p className="text-xs font-semibold text-gray-600 px-4 pt-2">ADMIN</p>
      <a href="/admin/users" className="block px-4 py-2 text-gray-700 hover:bg-gray-100">
        User Management
      </a>
      <a href="/admin/settings" className="block px-4 py-2 text-gray-700 hover:bg-gray-100">
        Settings
      </a>
    </>
  );
}

/**
 * USAGE IN SIDENAV:
 * 
 * Replace your client-side Sidenav with a hybrid approach:
 * 
 * File: src/components/Sidenav.tsx (Server Component)
 * 
 * import { AdminNavLinks } from '@/components/AdminNavLinks';
 * import { UserInfo } from '@/components/UserInfo';
 *
 * export async function Sidenav() {
 *   return (
 *     <nav>
 *       <UserInfo />
 *       <div className="space-y-2">
 *         <a href="/sessions">All Sessions</a>
 *         <a href="/sessions/new">New Session</a>
 *       </div>
 *       <AdminNavLinks />
 *     </nav>
 *   );
 * }
 * 
 * Or if you need client-side interactivity, use a Server Component wrapper:
 * 
 * export default async function SidenavWrapper() {
 *   const isAdmin = await isCurrentUserAdmin();
 *   return <SidenavClient isAdmin={isAdmin} />;
 * }
 * 
 * // SidenavClient.tsx (Client Component)
 * 'use client';
 * 
 * export function SidenavClient({ isAdmin }: { isAdmin: boolean }) {
 *   // Now you have isAdmin available on the client without fetching again
 *   return (
 *     <nav>
 *       {isAdmin && (
 *         <a href="/admin/users">User Management</a>
 *       )}
 *     </nav>
 *   );
 * }
 */
