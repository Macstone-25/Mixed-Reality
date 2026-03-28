'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';
import SignInWithGoogleButton from '@/components/SignInWithGoogleButton';

export default function LoginPage() {
  const router = useRouter();
  const { user, isApproved, loading: authLoading } = useAuth();

  // Redirect if already authenticated
  useEffect(() => {
    if (!authLoading && user) {
      if (isApproved) {
        // Already approved, go to dashboard
        router.push('/');
      } else {
        // Not approved yet, go to pending approval page
        router.push('/auth/pending-approval');
      }
    }
  }, [user, isApproved, authLoading, router]);

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="text-center">
        <h1 className="text-4xl font-bold mb-3" style={{ color: '#2D2D2D' }}>
          Welcome Back
        </h1>
        <p style={{ color: 'rgba(45, 45, 45, 0.6)', fontSize: '1.1rem' }}>
          Access your research session dashboard
        </p>
      </div>

      {/* Info Box */}
      <div
        className="p-6 rounded-lg text-sm"
        style={{
          backgroundColor: 'rgba(127, 85, 57, 0.08)',
          borderLeft: '4px solid #7F5539',
        }}
      >
        <p style={{ color: 'rgba(45, 45, 45, 0.8)', lineHeight: '1.6' }}>
          We use Google Sign-In to keep your account secure. Sign in with the email address you used to create your account below.
        </p>
      </div>

      {/* Google Sign In Button */}
      <div>
        <SignInWithGoogleButton />
      </div>

      {/* Features/Benefits */}
      <div className="space-y-3">
        <p className="text-center text-sm" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>
          ✓ Secure, one-click sign in
        </p>
        <p className="text-center text-sm" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>
          ✓ No passwords to remember
        </p>
        <p className="text-center text-sm" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>
          ✓ Your data is always protected
        </p>
      </div>

      {/* Need Help Text */}
      <div className="text-center text-sm" style={{ color: 'rgba(45, 45, 45, 0.5)' }}>
        <p>Having trouble signing in? The Google Sign-In window will open in a new tab.</p>
      </div>
    </div>
  );
}
