'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Loader2, ArrowRight, CheckCircle2 } from 'lucide-react';
import { useAuth } from '@/lib/auth-context';
import { updateUserProfile } from '@/lib/auth-actions';

export default function OnboardingPage() {
  const router = useRouter();
  const { user, loading: authLoading, refreshAuth } = useAuth();

  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentStep, setCurrentStep] = useState<'welcome' | 'form'>('welcome');

  useEffect(() => {
    // If user session loads and they already have a name, redirect to post-onboarding flow
    if (!authLoading && user) {
      // User is authenticated, page can proceed
      // If they already completed onboarding, middleware will handle redirecting them
      // based on their approval status when they go to /
    } else if (!authLoading && !user) {
      // User is not authenticated, redirect to login
      router.push('/auth/login');
    }
  }, [user, authLoading, router]);

  const handleNext = () => {
    setCurrentStep('form');
  };

  const handleFormSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);

    if (!firstName.trim() || !lastName.trim()) {
      setError('Both first name and last name are required');
      return;
    }

    setLoading(true);
    try {
      const result = await updateUserProfile(firstName.trim(), lastName.trim());

      if (result.success) {
        // Refresh auth to get updated profile
        await refreshAuth();
        // Redirect to dashboard
        router.push('/');
      } else {
        setError(result.error?.message || 'Failed to save profile');
      }
    } catch (err) {
      console.error('Profile creation error:', err);
      setError('An error occurred while saving your profile');
    } finally {
      setLoading(false);
    }
  };

  if (authLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ backgroundColor: '#7F5539' }}>
        <Loader2 className="w-8 h-8 animate-spin" style={{ color: '#F5F1ED' }} />
      </div>
    );
  }

  if (!user) {
    return null;
  }

  return (
    <div
      className="min-h-[80vh] flex items-center justify-center px-2 rounded-2xl"
      style={{ backgroundColor: '#7F5539' }}
    >
      <div className="w-full max-w-md">
        {currentStep === 'welcome' ? (
          // Welcome Screen
          <div className="space-y-6 text-center">
            {/* Google OAuth Badge */}
            <div className="flex justify-center">
              <div
                className="inline-flex items-center gap-2 px-4 py-2 rounded-full"
                style={{ backgroundColor: 'rgba(245, 241, 237, 0.1)' }}
              >
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  xmlns="http://www.w3.org/2000/svg"
                >
                  <path
                    d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                    fill="#4285F4"
                  />
                  <path
                    d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                    fill="#34A853"
                  />
                  <path
                    d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                    fill="#FBBC05"
                  />
                  <path
                    d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                    fill="#EA4335"
                  />
                </svg>
                <span style={{ color: '#F5F1ED', fontSize: '0.875rem', fontWeight: '500' }}>
                  Signed in with Google
                </span>
              </div>
            </div>

            {/* Welcome Title */}
            <div>
              <h1 className="text-3xl font-bold mb-3" style={{ color: '#F5F1ED' }}>
                Welcome{user.user_metadata?.display_name ? `, ${user.user_metadata.display_name.split(' ')[0]}` : ''}!
              </h1>
              <p style={{ color: 'rgba(245, 241, 237, 0.8)', fontSize: '1.05rem' }}>
                Just a few quick details to complete your profile.
              </p>
            </div>

            {/* Info Box */}
            <div
              className="p-4 rounded-lg text-sm space-y-3"
              style={{
                backgroundColor: 'rgba(245, 241, 237, 0.1)',
                borderLeft: '4px solid rgba(245, 241, 237, 0.3)',
              }}
            >
              <div className="flex items-start gap-3">
                <CheckCircle2 size={16} style={{ color: '#F5F1ED', flexShrink: 0, marginTop: '2px' }} />
                <p style={{ color: 'rgba(245, 241, 237, 0.8)' }}>
                  Google account verified & secure
                </p>
              </div>
              <div className="flex items-start gap-3">
                <CheckCircle2 size={16} style={{ color: '#F5F1ED', flexShrink: 0, marginTop: '2px' }} />
                <p style={{ color: 'rgba(245, 241, 237, 0.8)' }}>
                  Waiting for admin approval
                </p>
              </div>
              <div className="flex items-start gap-3">
                <CheckCircle2 size={16} style={{ color: '#F5F1ED', flexShrink: 0, marginTop: '2px' }} />
                <p style={{ color: 'rgba(245, 241, 237, 0.8)' }}>
                  Add your name to get started
                </p>
              </div>
            </div>

            {/* Email Display */}
            <div
              className="p-4 rounded-lg"
              style={{ backgroundColor: 'rgba(245, 241, 237, 0.05)' }}
            >
              <p style={{ color: 'rgba(245, 241, 237, 0.6)', fontSize: '0.875rem' }}>
                Google Email
              </p>
              <p style={{ color: '#F5F1ED', fontWeight: 'bold', marginTop: '0.25rem', wordBreak: 'break-all' }}>
                {user.email}
              </p>
            </div>

            {/* Next Button */}
            <button
              onClick={handleNext}
              className="w-full py-3 rounded-lg font-semibold transition-colors flex items-center justify-center gap-2"
              style={{ backgroundColor: '#F5F1ED', color: '#7F5539' }}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.9)')}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = '#F5F1ED')}
            >
              Continue
              <ArrowRight size={18} />
            </button>
          </div>
        ) : (
          // Form Screen
          <div className="space-y-6">
            {/* Header */}
            <div className="text-center">
              <h2 className="text-2xl font-bold mb-2" style={{ color: '#F5F1ED' }}>
                Tell Us Your Name
              </h2>
              <p style={{ color: 'rgba(245, 241, 237, 0.7)' }}>
                This helps us personalize your experience
              </p>
            </div>

            {/* Form */}
            <form onSubmit={handleFormSubmit} className="space-y-4">
              {/* First Name */}
              <div>
                <label htmlFor="firstName" className="block text-sm font-medium mb-2" style={{ color: '#F5F1ED' }}>
                  First Name
                </label>
                <input
                  id="firstName"
                  type="text"
                  value={firstName}
                  onChange={(e) => setFirstName(e.target.value)}
                  placeholder="John"
                  className="w-full px-4 py-3 rounded-lg border transition-colors focus:outline-none"
                  style={{
                    borderColor: 'rgba(245, 241, 237, 0.3)',
                    backgroundColor: 'rgba(245, 241, 237, 0.05)',
                    color: '#F5F1ED',
                  }}
                  onFocus={(e) => {
                    e.currentTarget.style.borderColor = '#F5F1ED';
                    e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.1)';
                  }}
                  onBlur={(e) => {
                    e.currentTarget.style.borderColor = 'rgba(245, 241, 237, 0.3)';
                    e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.05)';
                  }}
                />
              </div>

              {/* Last Name */}
              <div>
                <label htmlFor="lastName" className="block text-sm font-medium mb-2" style={{ color: '#F5F1ED' }}>
                  Last Name
                </label>
                <input
                  id="lastName"
                  type="text"
                  value={lastName}
                  onChange={(e) => setLastName(e.target.value)}
                  placeholder="Doe"
                  className="w-full px-4 py-3 rounded-lg border transition-colors focus:outline-none"
                  style={{
                    borderColor: 'rgba(245, 241, 237, 0.3)',
                    backgroundColor: 'rgba(245, 241, 237, 0.05)',
                    color: '#F5F1ED',
                  }}
                  onFocus={(e) => {
                    e.currentTarget.style.borderColor = '#F5F1ED';
                    e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.1)';
                  }}
                  onBlur={(e) => {
                    e.currentTarget.style.borderColor = 'rgba(245, 241, 237, 0.3)';
                    e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.05)';
                  }}
                />
              </div>

              {/* Error Message */}
              {error && (
                <div
                  className="p-4 rounded-lg text-sm"
                  style={{
                    backgroundColor: 'rgba(239, 68, 68, 0.2)',
                    color: '#FCA5A5',
                    borderLeft: '4px solid #EF4444',
                  }}
                >
                  {error}
                </div>
              )}

              {/* Submit Button */}
              <button
                type="submit"
                disabled={loading}
                className="w-full py-3 rounded-lg font-semibold transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
                style={{ backgroundColor: '#F5F1ED', color: '#7F5539' }}
                onMouseEnter={(e) => {
                  if (!loading) e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.9)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.backgroundColor = '#F5F1ED';
                }}
              >
                {loading && <Loader2 className="w-4 h-4 animate-spin" />}
                {loading ? 'Setting Up...' : 'Complete Setup'}
              </button>

              {/* Back Button */}
              <button
                type="button"
                onClick={() => setCurrentStep('welcome')}
                className="w-full py-3 rounded-lg font-semibold transition-colors"
                style={{
                  backgroundColor: 'rgba(245, 241, 237, 0.1)',
                  color: '#F5F1ED',
                  border: '2px solid rgba(245, 241, 237, 0.2)',
                }}
                onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.15)')}
                onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.1)')}
              >
                Back
              </button>
            </form>

            {/* Info */}
            <p style={{ color: 'rgba(245, 241, 237, 0.5)', fontSize: '0.875rem', textAlign: 'center' }}>
              Your information is read-only from your Google account and can be updated in your profile later.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
