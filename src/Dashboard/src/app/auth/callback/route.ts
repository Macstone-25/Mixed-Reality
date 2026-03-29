import { NextRequest, NextResponse } from 'next/server';
import { createServerClient } from '@supabase/ssr';
import type { CookieOptions } from '@supabase/ssr';
import { cookies } from 'next/headers';

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const code = searchParams.get('code');
  const next = searchParams.get('next') || '/';

  if (code) {
    const cookieStore = await cookies();
    const cookiesToSet: Array<{ name: string; value: string; options: CookieOptions }> = [];

    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY!,
      {
        cookies: {
          getAll() {
            return cookieStore.getAll();
          },
          setAll(cookiesToSetFromSupabase) {
            try {
              cookiesToSetFromSupabase.forEach(({ name, value, options }) => {
                // Store cookies to apply to response later
                cookiesToSet.push({ name, value, options });
                // Also set in request cookies
                cookieStore.set(name, value, options as CookieOptions);
              });
            } catch (error) {
              console.warn('Failed to set cookies:', error);
            }
          },
        },
      }
    );

    // Exchange the code for a session
    const { data, error } = await supabase.auth.exchangeCodeForSession(code);

    if (!error && data.user) {
      // Use the user from the code exchange response
      const user = data.user;

      // Check user's approval status
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('approval_status')
        .eq('id', user.id)
        .single();

      // If profile query fails or approval_status is not set, treat as pending
      // (database trigger should create profile with approval_status='pending' on signup)
      const approvalStatus = profile?.approval_status || 'pending';

      if (approvalStatus === 'approved') {
        // User is approved, redirect to requested page
        const response = NextResponse.redirect(new URL(next, request.url));
        // Apply cookies to response
        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options as CookieOptions);
        });
        return response;
      } else if (approvalStatus === 'pending') {
        // User is pending approval, redirect to pending page
        const response = NextResponse.redirect(new URL('/auth/pending-approval', request.url));
        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options as CookieOptions);
        });
        return response;
      } else if (approvalStatus === 'rejected') {
        // User was rejected, redirect to login with error
        const response = NextResponse.redirect(new URL('/auth/login?error=rejected', request.url));
        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options as CookieOptions);
        });
        return response;
      }
    }
  }

  // If something went wrong, redirect to login with error
  return NextResponse.redirect(
    new URL('/auth/login?error=callback', request.url)
  );
}
