'use server';

import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { getOAuthCallbackUrl } from '@/lib/auth-helpers';

export interface AuthError {
  message: string;
  code?: string;
}



/**
 * Sign out the current user
 */
export async function signOut(): Promise<{ success: boolean; error?: AuthError }> {
  const supabase = await createClient();

  try {
    // Clear all sessions (global: true clears all sessions for this user)
    const { error } = await supabase.auth.signOut({ scope: 'global' });

    if (error) {
      console.error('Supabase signOut error:', error);
      return {
        success: false,
        error: {
          message: error.message,
        },
      };
    }

    console.log('User logged out successfully');
    return { success: true };
  } catch (error) {
    console.error('signOut error:', error);
    return {
      success: false,
      error: {
        message: error instanceof Error ? error.message : 'An unexpected error occurred',
      },
    };
  }
}



/**
 * Get current user's approval status
 */
export async function getApprovalStatus(): Promise<{
  approved: boolean;
  error?: AuthError;
}> {
  const supabase = await createClient();

  try {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return {
        approved: false,
        error: {
          message: 'No active session',
        },
      };
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('approval_status')
      .eq('id', user.id)
      .single();

    if (profileError) {
      return {
        approved: false,
        error: {
          message: 'Failed to verify account status',
        },
      };
    }

    return {
      approved: profile?.approval_status === 'approved',
    };
  } catch (error) {
    return {
      approved: false,
      error: {
        message: error instanceof Error ? error.message : 'An unexpected error occurred',
      },
    };
  }
}

/**
 * Get current user information
 */
export async function getCurrentUser() {
  const supabase = await createClient();

  try {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return null;
    }

    // Get profile data
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single();

    if (error) {
      return null;
    }

    return {
      ...user,
      profile,
    };
  } catch (error) {
    return null;
  }
}

/**
 * Sign in with Google OAuth
 * Uses dynamic redirect URL that works across all deployment environments
 */
export async function signInWithGoogle(): Promise<{
  success: boolean;
  url?: string;
  error?: AuthError;
}> {
  const supabase = await createClient();

  try {
    // Get the correct redirect URL for this environment
    const redirectTo = await getOAuthCallbackUrl();

    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo,
        queryParams: {
          access_type: 'offline',
          prompt: 'consent',
        },
      },
    });

    if (error) {
      console.error('Google OAuth error:', error);
      return {
        success: false,
        error: {
          message: error.message || 'OAuth error occurred',
          code: 'OAUTH_ERROR',
        },
      };
    }

    if (data?.url) {
      return {
        success: true,
        url: data.url,
      };
    }

    return {
      success: false,
      error: {
        message: 'Failed to generate OAuth URL',
        code: 'NO_OAUTH_URL',
      },
    };
  } catch (error) {
    console.error('Google sign in error:', error);
    return {
      success: false,
      error: {
        message: 'An unexpected error occurred',
        code: 'UNEXPECTED_ERROR',
      },
    };
  }
}

/**
 * Fetch the current user's profile (server-side)
 * This bypasses RLS policies that block client-side queries
 * The client calls this server action via refreshAuth()
 */
export async function fetchCurrentProfile() {
  const supabase = await createClient();

  try {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return { profile: null };
    }

    const { data: profile, error } = await supabase
      .from('profiles')
      .select('id, email, first_name, last_name, role, approval_status, created_at')
      .eq('id', user.id)
      .single();

    if (error) {
      console.error('fetchCurrentProfile: Profile fetch failed', {
        userId: user.id,
        error: error.message,
      });
      return { profile: null, error: error.message };
    }

    return { profile };
  } catch (error) {
    console.error('fetchCurrentProfile error:', error);
    return { profile: null };
  }
}

/**
 * Update user's profile (first_name, last_name)
 */
export async function updateUserProfile(
  firstName: string,
  lastName: string
): Promise<{ success: boolean; error?: AuthError }> {
  const supabase = await createClient();

  try {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return {
        success: false,
        error: {
          message: 'No active session',
        },
      };
    }

    const { error } = await supabase
      .from('profiles')
      .update({
        first_name: firstName,
        last_name: lastName,
        updated_at: new Date().toISOString(),
      })
      .eq('id', user.id);

    if (error) {
      console.error('updateUserProfile error:', error);
      return {
        success: false,
        error: {
          message: 'Failed to update profile',
        },
      };
    }

    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: {
        message: error instanceof Error ? error.message : 'An unexpected error occurred',
      },
    };
  }
}

