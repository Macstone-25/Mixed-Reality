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
  // First, update the session (refresh tokens)
  const response = await updateSession(request);
  const pathname = request.nextUrl.pathname;

  // DEBUG: Log all requests to verify middleware is running
  console.log(`🔒 [Middleware] ${request.method} ${pathname}`);

  // Allow public routes
  if (PUBLIC_ROUTES.some((route) => pathname.startsWith(route))) {
    console.log(`✅ [Middleware] ${pathname} is public - allowing`);
    return response;
  }

  // Validate session for all protected routes
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
      .select('approval_status, role')
      .eq('id', user.id)
      .single();

    if (profileError || !profile) {
      console.error('Middleware: Profile validation failed', { userId: user.id, profileError });
      return NextResponse.redirect(new URL('/auth/login', request.url));
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
