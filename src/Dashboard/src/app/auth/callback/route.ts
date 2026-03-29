import { NextRequest, NextResponse } from 'next/server';
import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const code = searchParams.get('code');
  const next = searchParams.get('next') || '/';

  if (code) {
    const cookieStore = await cookies();
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY!,
      {
        cookies: {
          getAll() {
            return cookieStore.getAll();
          },
          setAll(cookiesToSet) {
            try {
              cookiesToSet.forEach(({ name, value, options }) =>
                cookieStore.set(name, value, options)
              );
            } catch {
              // The `setAll` method was called from a Server Component.
              // This can be ignored if you have middleware refreshing
              // user sessions.
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
        return NextResponse.redirect(new URL(next, request.url));
      } else if (approvalStatus === 'pending') {
        // User is pending approval, redirect to pending page
        return NextResponse.redirect(
          new URL('/auth/pending-approval', request.url)
        );
      } else if (approvalStatus === 'rejected') {
        // User was rejected, redirect to login with error
        return NextResponse.redirect(
          new URL('/auth/login?error=rejected', request.url)
        );
      }
    }
  }

  // If something went wrong, redirect to login with error
  return NextResponse.redirect(
    new URL('/auth/login?error=callback', request.url)
  );
}
