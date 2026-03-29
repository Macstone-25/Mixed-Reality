import { redirect } from 'next/navigation';
import { getCurrentUserProfile } from '@/lib/auth-helpers';
import type { ReactNode } from 'react';

/**
 * PROTECTED LAYOUT EXAMPLE
 * 
 * This layout demonstrates proper server-side protection for authenticated routes.
 * Place this layout.tsx in your protected route directory (e.g., src/app/(protected)/layout.tsx)
 * 
 * Benefits:
 * - Server-side validation before rendering any children
 * - User profile available to all child pages via context/props
 * - No flash of wrong content (middleware + server validation)
 * - Cleaner separation between auth routes and app routes
 */

interface ProtectedLayoutProps {
  children: ReactNode;
}

export default async function ProtectedLayout({ children }: ProtectedLayoutProps) {
  // Get user profile server-side
  // If user is not authenticated, middleware already redirected to /auth/login
  // This double-check ensures extra safety
  const profile = await getCurrentUserProfile();

  if (!profile) {
    // This shouldn't happen if middleware is working correctly,
    // but fail-closed if it does
    redirect('/auth/login');
  }

  // If user is not approved, middleware would have redirected to /auth/pending-approval
  // But double-check here as well
  if (profile.approval_status !== 'approved') {
    redirect('/auth/pending-approval');
  }

  // At this point, user is authenticated and approved
  // Safe to render protected content

  return <>{children}</>;
}

/**
 * USAGE IN PROTECTED PAGES:
 * 
 * File: src/app/(protected)/sessions/page.tsx
 * 
 * import { getCurrentUserProfile } from '@/lib/auth-helpers';
 *
 * export default async function SessionsPage() {
 *   const profile = await getCurrentUserProfile();
 *
 *   return (
 *     <div>
 *       <h1>Sessions</h1>
 *       <p>Welcome, {profile?.first_name}!</p>
 *     </div>
 *   );
 * }
 * 
 * FILE STRUCTURE:
 * src/app/
 * ├── (auth)/              ← Auth routes group
 * │   ├── login/page.tsx
 * │   ├── signup/page.tsx
 * │   └── ...
 * ├── (protected)/         ← App routes group (auto-validated by middleware)
 * │   ├── layout.tsx       ← This file
 * │   ├── sessions/page.tsx
 * │   ├── admin/
 * │   │   └── users/page.tsx
 * │   └── ...
 * └── layout.tsx           ← Root layout
 */
