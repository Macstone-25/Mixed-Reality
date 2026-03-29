'use server';

import { createClient } from '@/lib/supabase/server';
import type { AuthProfile } from '@/lib/auth-context';

/**
 * Get the current user's profile (server-side)
 * Should be called in Server Components to avoid client-side state queries
 * Uses Supabase server client which has access to session cookies
 */
export async function getCurrentUserProfile(): Promise<AuthProfile | null> {
  const supabase = await createClient();

  try {
    const { data: { user }, error: userError } = await supabase.auth.getUser();

    if (userError || !user) {
      console.warn('getCurrentUserProfile: No authenticated user');
      return null;
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, email, first_name, last_name, role, approval_status, created_at')
      .eq('id', user.id)
      .single();

    if (profileError || !profile) {
      console.error('getCurrentUserProfile: Failed to fetch profile', { userId: user.id, profileError });
      return null;
    }

    return profile as AuthProfile;
  } catch (error) {
    console.error('getCurrentUserProfile error:', error);
    return null;
  }
}

/**
 * Check if the current user is an admin (server-side)
 */
export async function isCurrentUserAdmin(): Promise<boolean> {
  const profile = await getCurrentUserProfile();
  return profile?.role === 'admin';
}

/**
 * Get the current user's approval status (server-side)
 */
export async function getCurrentUserApprovalStatus(): Promise<'pending' | 'approved' | 'rejected' | null> {
  const profile = await getCurrentUserProfile();
  return profile?.approval_status || null;
}
