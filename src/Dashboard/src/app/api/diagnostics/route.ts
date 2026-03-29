import { createClient } from '@/lib/supabase/server';
import { NextResponse } from 'next/server';

/**
 * Diagnostic endpoint to test profile fetch and capture actual error details
 */
export async function GET() {
  const supabase = await createClient();

  try {
    // Get current user
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError) {
      return NextResponse.json(
        {
          status: 'error',
          step: 'getUser',
          error: {
            message: authError.message,
            code: authError.code,
            status: (authError as any).status,
            details: (authError as any).details,
          },
        },
        { status: 500 }
      );
    }

    if (!user) {
      return NextResponse.json(
        {
          status: 'not_authenticated',
          message: 'No user logged in',
        },
        { status: 401 }
      );
    }

    // Try to fetch profile
    const { data: profileData, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single();

    if (profileError) {
      console.error('Profile fetch error in API:', {
        userId: user.id,
        errorMessage: profileError.message,
        errorCode: profileError.code,
        errorStatus: (profileError as any).status,
        errorDetails: (profileError as any).details,
        errorHint: (profileError as any).hint,
        fullError: JSON.stringify(profileError),
      });

      return NextResponse.json(
        {
          status: 'profile_fetch_error',
          user: {
            id: user.id,
            email: user.email,
            created_at: user.created_at,
          },
          error: {
            message: profileError.message,
            code: profileError.code,
            status: (profileError as any).status,
            details: (profileError as any).details,
            hint: (profileError as any).hint,
          },
          diagnosis: diagnoseError(profileError),
        },
        { status: 500 }
      );
    }

    if (!profileData) {
      return NextResponse.json(
        {
          status: 'profile_not_found',
          user: {
            id: user.id,
            email: user.email,
          },
          message: 'User authenticated but profile record does not exist',
          suggestion: 'Profile should be created during signup',
        },
        { status: 404 }
      );
    }

    // Success!
    return NextResponse.json({
      status: 'success',
      user: {
        id: user.id,
        email: user.email,
      },
      profile: profileData,
      message: 'Profile loaded successfully',
    });
  } catch (error) {
    console.error('Unexpected error in diagnostic endpoint:', error);
    return NextResponse.json(
      {
        status: 'error',
        step: 'unexpected',
        error: {
          message: error instanceof Error ? error.message : 'Unknown error',
          stack: error instanceof Error ? error.stack : undefined,
        },
      },
      { status: 500 }
    );
  }
}

function diagnoseError(error: any): string[] {
  const hints: string[] = [];

  if (error.code === 'PGRST116') {
    hints.push('Profile record does not exist for this user');
    hints.push('Action: Check if profile creation succeeds during signup');
    hints.push('Fix: Run profile creation migration or re-signup user');
  }

  if (error.code === '42501' || error.message?.includes('permission')) {
    hints.push('RLS (Row Level Security) policy is blocking access');
    hints.push(
      'Fix: Run in Supabase SQL editor: ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;'
    );
    hints.push(
      'OR create proper RLS policies that allow users to read their own profiles'
    );
  }

  if (error.message?.includes('JWT')) {
    hints.push('Session token is invalid or expired');
    hints.push('Action: User should log out and log in again');
  }

  if (!hints.length) {
    hints.push(`Unknown error: ${error.message}`);
    hints.push(`Error code: ${error.code}`);
    hints.push('Check server logs for full error details');
  }

  return hints;
}
