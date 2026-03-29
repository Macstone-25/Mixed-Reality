import { redirect } from 'next/navigation';
import { getCurrentUserProfile } from '@/lib/auth-helpers';
import type { ReactNode } from 'react';

/**
 * ADMIN LAYOUT - Role-Based Access Control
 * 
 * This layout enforces admin-only access to all routes under /admin/*
 * The parent (protected) layout already validates authentication,
 * so this layout only needs to verify the admin role.
 */

interface AdminLayoutProps {
  children: ReactNode;
}

export default async function AdminLayout({ children }: AdminLayoutProps) {
  // Get user profile (already validated by parent (protected) layout)
  const profile = await getCurrentUserProfile();

  if (!profile) {
    // Should not happen due to parent layout, but fail-closed
    redirect('/auth/login');
  }

  // Verify user has admin role
  if (profile.role !== 'admin') {
    // Non-admin users redirected to sessions page
    redirect('/sessions');
  }

  // User is admin, safe to render admin content
  return <>{children}</>;
}
