import { type NextRequest, NextResponse } from 'next/server';
import { updateSession } from '@/lib/supabase/middleware';
import { createServerClient } from '@supabase/ssr';
import type { CookieOptions } from '@supabase/ssr';
import { cookies } from 'next/headers';

// Public routes that don't require authentication
const PUBLIC_ROUTES = [
  '/auth/login',
  '/auth/signup',
  '/auth/callback',
];

// Routes that require approval but not specific permissions
const APPROVAL_REQUIRED_ROUTES = ['/admin', '/sessions'];

// Routes that require admin role
const ADMIN_ROUTES = ['/admin'];

export async function middleware(request: NextRequest) {
  const pathname = request.nextUrl.pathname;

  // Allow public routes without session updates
  if (PUBLIC_ROUTES.some((route) => pathname.startsWith(route))) {
    return NextResponse.next();
  }

  // For protected routes, update the session (refresh tokens)
  const response = await updateSession(request);
  try {
    const cookieStore = await cookies();
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY!,
      {
        cookies: {
          get(name: string) {
            return cookieStore.get(name)?.value;
          },
          set(name: string, value: string, options: CookieOptions) {
            try {
              cookieStore.set({ name, value, ...options });
            } catch {
              // Ignored
            }
          },
          remove(name: string, options: CookieOptions) {
            try {
              cookieStore.set({ name, value: '', ...options });
            } catch {
              // Ignored
            }
          },
        },
      }
    );

    // Check authentication
    const { data: { user }, error: userError } = await supabase.auth.getUser();

    if (userError || !user) {
      console.warn(`❌ [Middleware] No valid session for ${pathname} - redirecting to /auth/login`, { userError, hasUser: !!user });
      return NextResponse.redirect(new URL('/auth/login', request.url));
    }

    // Fetch user profile - fail-closed on error
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('approval_status, role, first_name')
      .eq('id', user.id)
      .single();

    if (profileError || !profile) {
      console.error('Middleware: Profile validation failed', { userId: user.id, profileError });
      return NextResponse.redirect(new URL('/auth/login', request.url));
    }

    console.log(`📋 [Middleware] Profile loaded for ${user.email}:`, {
      first_name: profile.first_name,
      approval_status: profile.approval_status,
      role: profile.role,
    });

    // Check if user needs to complete onboarding (no first name set)
    if (!profile.first_name) {
      console.log(`🔄 [Middleware] User ${user.email} has no first_name, checking if on onboarding page...`);
      if (pathname !== '/auth/onboarding') {
        console.log(`↪️ [Middleware] Redirecting ${user.email} to /auth/onboarding`);
        return NextResponse.redirect(new URL('/auth/onboarding', request.url));
      }
      console.log(`✅ [Middleware] User ${user.email} is on /auth/onboarding, allowing`);
      return response;
    }

    // Pending users can only access pending-approval page
    if (profile.approval_status !== 'approved') {
      if (pathname !== '/auth/pending-approval') {
        return NextResponse.redirect(new URL('/auth/pending-approval', request.url));
      }
      return response;
    }

    // Approved users shouldn't be on auth pages
    if (pathname.startsWith('/auth')) {
      return NextResponse.redirect(new URL('/', request.url));
    }

    // Admin-only routes
    if (ADMIN_ROUTES.some((route) => pathname.startsWith(route))) {
      if (profile.role !== 'admin') {
        console.warn('Middleware: Non-admin accessing admin route', {
          userId: user.id,
          pathname,
          role: profile.role,
        });
        return NextResponse.redirect(new URL('/sessions', request.url));
      }
    }

    return response;
  } catch (error) {
    console.error('Middleware error', error);
    return NextResponse.redirect(new URL('/auth/login', request.url));
  }
}

export const config = {
  matcher: [
    '/',                              // Explicitly match root
    '/sessions/:path*',               // Explicitly match /sessions/*
    '/admin/:path*',                  // Explicitly match /admin/*
    '/((?!_next|api|auth|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
