'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Menu, ArrowLeft, Loader2 } from 'lucide-react';
import { useAuth } from '@/lib/auth-context';
import { updateUserProfile } from '@/lib/auth-actions';
import { Sidenav } from '@/components/Sidenav';

export default function ProfileEditPageClient() {
  const router = useRouter();
  const { user, profile, loading: authLoading, refreshAuth } = useAuth();

  const [sidenavOpen, setSidenavOpen] = useState(false);
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [originalFirstName, setOriginalFirstName] = useState('');
  const [originalLastName, setOriginalLastName] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  // Check if there are unsaved changes
  const hasChanges =
    firstName.trim() !== originalFirstName.trim() || lastName.trim() !== originalLastName.trim();

  const toggleSidenav = () => {
    setSidenavOpen(!sidenavOpen);
  };

  // Initialize form with current profile data
  useEffect(() => {
    if (!authLoading && profile) {
      setFirstName(profile.first_name || '');
      setLastName(profile.last_name || '');
      setOriginalFirstName(profile.first_name || '');
      setOriginalLastName(profile.last_name || '');
    }
  }, [profile, authLoading]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSuccess(false);

    if (!firstName.trim() || !lastName.trim()) {
      setError('First name and last name are required');
      return;
    }

    setLoading(true);
    try {
      const result = await updateUserProfile(firstName.trim(), lastName.trim());

      if (result.success) {
        setSuccess(true);
        // Refresh auth context to update profile
        await refreshAuth();
        // Update original values to reflect saved changes
        setOriginalFirstName(firstName.trim());
        setOriginalLastName(lastName.trim());
        // Reset success message after 2 seconds
        setTimeout(() => {
          setSuccess(false);
        }, 2000);
      } else {
        setError(result.error?.message || 'Failed to update profile');
      }
    } catch (err) {
      console.error('Profile update error:', err);
      setError('An error occurred while updating your profile');
    } finally {
      setLoading(false);
    }
  };

  if (authLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ backgroundColor: '#EDE0D4' }}>
        <Loader2 className="w-8 h-8 animate-spin" style={{ color: '#7F5539' }} />
      </div>
    );
  }

  if (!user) {
    return null;
  }

  return (
    <div className="flex min-h-screen" style={{ backgroundColor: '#7F5539' }}>
      <Sidenav isOpen={sidenavOpen} onToggle={toggleSidenav} />

      <div className={`flex-1 transition-all duration-300 box-border ${sidenavOpen ? 'ml-64' : ''}`}>
        <div
          className={`min-h-screen w-full py-6 sm:py-8 px-4 sm:px-8 md:px-12 lg:px-16 ${sidenavOpen ? 'rounded-l-xl' : ''}`}
          style={{ backgroundColor: '#EDE0D4' }}
        >
          {/* Header */}
          <div className="flex items-center gap-3 sm:gap-4 mb-8">
            <button
              onClick={toggleSidenav}
              className="p-2 rounded-lg transition-colors flex-shrink-0"
              style={{ color: '#2D2D2D', backgroundColor: 'rgba(45, 45, 45, 0.08)' }}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(45, 45, 45, 0.15)')}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'rgba(45, 45, 45, 0.08)')}
              aria-label="Open navigation"
            >
              <Menu size={24} />
            </button>
            <h1 className="text-2xl sm:text-3xl font-bold" style={{ color: '#2D2D2D' }}>
              Edit Profile
            </h1>
          </div>

          {/* Content */}
          <div className="max-w-2xl">
            {/* Card */}
            <div className="bg-white rounded-lg shadow-sm p-6 sm:p-8">
              {/* User Email Display */}
              <div className="mb-6">
                <label className="block text-sm font-medium mb-2" style={{ color: '#2D2D2D' }}>
                  Email
                </label>
                <div
                  className="w-full px-4 py-3 rounded-lg bg-gray-50"
                  style={{ color: '#7F5539' }}
                >
                  {user.email}
                </div>
                <p className="text-xs mt-1" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>
                  Your email cannot be changed here
                </p>
              </div>

              {/* Form */}
              <form onSubmit={handleSubmit} className="space-y-6">
                {/* First Name */}
                <div>
                  <label htmlFor="firstName" className="block text-sm font-medium mb-2" style={{ color: '#2D2D2D' }}>
                    First Name
                  </label>
                  <input
                    id="firstName"
                    type="text"
                    value={firstName}
                    onChange={(e) => setFirstName(e.target.value)}
                    placeholder="Enter your first name"
                    className="w-full px-4 py-3 rounded-lg border transition-colors focus:outline-none focus:ring-2"
                    style={{
                      borderColor: '#C9B5A0',
                      color: '#2D2D2D',
                      backgroundColor: '#FFFFFF',
                    }}
                    onFocus={(e) => (e.currentTarget.style.borderColor = '#7F5539')}
                    onBlur={(e) => (e.currentTarget.style.borderColor = '#C9B5A0')}
                  />
                </div>

                {/* Last Name */}
                <div>
                  <label htmlFor="lastName" className="block text-sm font-medium mb-2" style={{ color: '#2D2D2D' }}>
                    Last Name
                  </label>
                  <input
                    id="lastName"
                    type="text"
                    value={lastName}
                    onChange={(e) => setLastName(e.target.value)}
                    placeholder="Enter your last name"
                    className="w-full px-4 py-3 rounded-lg border transition-colors focus:outline-none focus:ring-2"
                    style={{
                      borderColor: '#C9B5A0',
                      color: '#2D2D2D',
                      backgroundColor: '#FFFFFF',
                    }}
                    onFocus={(e) => (e.currentTarget.style.borderColor = '#7F5539')}
                    onBlur={(e) => (e.currentTarget.style.borderColor = '#C9B5A0')}
                  />
                </div>

                {/* Error Message */}
                {error && (
                  <div
                    className="p-4 rounded-lg text-sm"
                    style={{ backgroundColor: '#FFE5E5', color: '#D32F2F' }}
                  >
                    {error}
                  </div>
                )}

                {/* Success Message */}
                {success && (
                  <div
                    className="p-4 rounded-lg text-sm"
                    style={{ backgroundColor: '#E8F5E9', color: '#2E7D32' }}
                  >
                    Profile updated successfully!
                  </div>
                )}

                {/* Buttons */}
                <div className="flex gap-3 pt-2">
                  <button
                    type="submit"
                    disabled={loading || !hasChanges}
                    className="flex-1 py-3 rounded-lg font-semibold transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
                    style={{ backgroundColor: '#7F5539', color: '#F5F1ED' }}
                    onMouseEnter={(e) => {
                      if (!loading && hasChanges) e.currentTarget.style.backgroundColor = '#6B4C3D';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.backgroundColor = '#7F5539';
                    }}
                  >
                    {loading && <Loader2 className="w-4 h-4 animate-spin" />}
                    {loading ? 'Saving...' : 'Save Changes'}
                  </button>
                  <button
                    type="button"
                    onClick={() => router.back()}
                    className="px-6 py-3 rounded-lg font-semibold transition-colors"
                    style={{ backgroundColor: '#FFFFFF', color: '#7F5539', border: '2px solid #7F5539' }}
                    onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(127, 85, 57, 0.05)')}
                    onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = '#FFFFFF')}
                  >
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
