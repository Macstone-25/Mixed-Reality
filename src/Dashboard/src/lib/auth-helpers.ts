'use server';

import { createClient } from '@/lib/supabase/server';
import { headers } from 'next/headers';
import type { AuthProfile } from '@/lib/auth-context';

/**
 * Get the correct base URL for OAuth redirects.
 * Works across all environments:
 * - Local development: http://localhost:3000
 * - Vercel production: https://mixed-reality-phi.vercel.app
 * - Vercel preview: https://<preview-url>.vercel.app
 *
 * Priority:
 * 1. Try to use request headers (most reliable on server)
 * 2. Fall back to NEXT_PUBLIC_APP_URL env variable
 * 3. Fall back to default localhost (development only)
 */
export async function getAuthRedirectUrl(): Promise<string> {
  try {
    // Get the Host header from incoming request
    const headersList = await headers();
    const host = headersList.get('host');

    if (host) {
      // Determine protocol based on host
      const protocol = host.includes('localhost') || host.includes('127.0.0.1') ? 'http' : 'https';
      return `${protocol}://${host}`;
    }
  } catch (error) {
    console.warn('Failed to get host from headers:', error);
  }

  // Fall back to environment variable if available
  if (process.env.NEXT_PUBLIC_APP_URL) {
    return process.env.NEXT_PUBLIC_APP_URL;
  }

  // Final fallback for development
  console.warn('No app URL could be determined, falling back to localhost:3000');
  return 'http://localhost:3000';
}

/**
 * Get the OAuth callback redirect URL.
 * Returns: https://example.com/auth/callback
 */
export async function getOAuthCallbackUrl(): Promise<string> {
  const baseUrl = await getAuthRedirectUrl();
  return `${baseUrl}/auth/callback`;
}

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
