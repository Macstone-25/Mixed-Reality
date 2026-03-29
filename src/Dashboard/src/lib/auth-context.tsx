'use client';

import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
  useCallback,
} from 'react';
import type { User } from '@supabase/supabase-js';
import { createClient } from '@/lib/supabase/client';
import { fetchCurrentProfile } from '@/lib/auth-actions';

export interface AuthProfile {
  id: string;
  email: string;
  first_name: string | null;
  last_name: string | null;
  role: 'admin' | 'user';
  approval_status: 'pending' | 'approved' | 'rejected';
  created_at: string;
}

export interface AuthContextType {
  user: User | null;
  profile: AuthProfile | null;
  loading: boolean;
  isAuthenticated: boolean;
  isApproved: boolean;
  isAdmin: boolean;
  refreshAuth: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

/**
 * Helper to extract error details from Supabase errors
 */
function getErrorDetails(error: any) {
  return {
    message: error?.message || 'Unknown error',
    code: error?.code || 'UNKNOWN',
    status: (error as any)?.status,
    details: (error as any)?.details,
    hint: (error as any)?.hint,
  };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<AuthProfile | null>(null);
  const [loading, setLoading] = useState(true);

  const supabase = createClient();

  const refreshAuth = useCallback(async () => {
    try {
      const {
        data: { user: currentUser },
      } = await supabase.auth.getUser();

      if (currentUser) {
        setUser(currentUser);

        // Fetch profile via server action (bypasses RLS issues)
        const { profile, error } = await fetchCurrentProfile();

        if (error) {
          console.error('Auth context: Profile fetch failed', {
            userId: currentUser.id,
            error,
          });
          // Don't set profile on error - let it remain null
          // Middleware will route appropriately based on null profile
        } else if (profile) {
          console.log('Auth context: Profile loaded', {
            userId: currentUser.id,
            approvalStatus: profile.approval_status,
            role: profile.role,
          });
          setProfile(profile as AuthProfile);
        } else {
          console.warn('Auth context: No profile data returned', {
            userId: currentUser.id,
          });
        }
      } else {
        setUser(null);
        setProfile(null);
      }
    } catch (error) {
      console.error('Error refreshing auth:', error);
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    // Initial load
    refreshAuth();

    // Subscribe to auth changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, session) => {
      console.log('Auth context: Auth state changed', {
        event,
        hasSession: !!session,
        userId: session?.user?.id,
      });

      if (session?.user) {
        setUser(session.user);

        // Fetch updated profile via server action (bypasses RLS issues)
        const { profile, error } = await fetchCurrentProfile();

        if (error) {
          console.error('Auth context: Profile fetch failed on state change', {
            userId: session.user.id,
            error,
          });
        } else if (profile) {
          console.log('Auth context: Profile loaded on state change', {
            userId: session.user.id,
            approvalStatus: profile.approval_status,
          });
          setProfile(profile as AuthProfile);
        } else {
          console.warn('Auth context: No profile data returned on state change', {
            userId: session.user.id,
          });
        }
      } else {
        console.log('Auth context: User logged out');
        setUser(null);
        setProfile(null);
      }
      setLoading(false);
    });

    return () => {
      subscription?.unsubscribe();
    };
  }, [supabase, refreshAuth]);

  const value: AuthContextType = {
    user,
    profile,
    loading,
    isAuthenticated: user !== null,
    isApproved: profile?.approval_status === 'approved',
    isAdmin: profile?.role === 'admin',
    refreshAuth,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);

  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }

  return context;
}

/**
 * PROFILE FETCH ERROR TROUBLESHOOTING:
 *
 * If you see "Auth context: Profile fetch failed" errors:
 * 
 * MOST COMMON: RLS (Row-Level Security) Policy Issue
 * ──────────────────────────────────────────────────
 * The profiles table has RLS enabled, but the client doesn't have permission to read it.
 * 
 * SOLUTION: Disable RLS (if not using it):
 * 
 *   1. Go to Supabase Dashboard
 *   2. Navigate to: SQL Editor
 *   3. Run this command:
 *      ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
 * 
 * OR: Create proper RLS policies (if using RLS):
 * 
 *      ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
 *      
 *      CREATE POLICY "Users can read own profile"
 *        ON profiles
 *        FOR SELECT
 *        USING (auth.uid() = id);
 *      
 *      CREATE POLICY "Users can update own profile"
 *        ON profiles
 *        FOR UPDATE
 *        USING (auth.uid() = id);
 *      
 *      CREATE POLICY "Users can insert own profile"
 *        ON profiles
 *        FOR INSERT
 *        WITH CHECK (auth.uid() = id);
 * 
 * OTHER CAUSES:
 * ─────────────
 * 1. Profile doesn't exist: User authenticated via Google but profile wasn't created
 *    - Check: SELECT * FROM profiles; in SQL Editor
 *    - Fix: Check auth.callback route creates profile on first Google sign-in
 * 
 * 2. Email column mismatch: The email column doesn't match auth.users.email
 *    - Check signed-in user's email matches profiles.email
 *    - The DEFAULT auth.email() should auto-populate on insert
 * 
 * 3. Service role vs anon key: Using wrong key for certain operations
 *    - Client uses NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY
 *    - Can only access data allowed by RLS policies or when RLS is disabled
 */
