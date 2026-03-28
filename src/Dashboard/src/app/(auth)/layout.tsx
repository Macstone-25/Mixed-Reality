import { redirect } from 'next/navigation';
import { getCurrentUserProfile } from '@/lib/auth-helpers';
import type { ReactNode } from 'react';

/**
 * AUTH LAYOUT - Unauthenticated Routes Only
 * 
 * This layout prevents authenticated users from accessing auth pages.
 * If a user is already logged in and tries to visit /login or /signup,
 * they will be redirected to the dashboard.
 * 
 * This improves UX by preventing the "already logged in" state.
 */

interface AuthLayoutProps {
  children: ReactNode;
}

export default async function AuthLayout({ children }: AuthLayoutProps) {
  // Check if user is already authenticated
  const profile = await getCurrentUserProfile();

  if (profile) {
    // User is already authenticated, redirect to dashboard
    redirect('/');
  }

  // User is not authenticated, safe to show auth pages
  return <>{children}</>;
}
