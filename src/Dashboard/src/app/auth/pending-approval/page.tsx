'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Clock, RefreshCw, CheckCircle2, AlertCircle } from 'lucide-react';
import { useAuth } from '@/lib/auth-context';
import { signOut } from '@/lib/auth-actions';

export default function PendingApprovalPage() {
  const router = useRouter();
  const { isApproved, loading, refreshAuth } = useAuth();
  const [isLoading, setIsLoading] = useState(false);
  const [isChecking, setIsChecking] = useState(false);
  const [lastCheckTime, setLastCheckTime] = useState<Date | null>(null);
  const [checkError, setCheckError] = useState<string | null>(null);

  // Redirect if already approved
  useEffect(() => {
    if (!loading && isApproved) {
      router.push('/');
    }
  }, [isApproved, loading, router]);

  // Poll approval status every 5 seconds for real-time updates
  useEffect(() => {
    if (isApproved || loading) return;

    const pollInterval = setInterval(async () => {
      setCheckError(null);
      try {
        await refreshAuth();
        setLastCheckTime(new Date());
      } catch (error) {
        console.error('Auto-check failed:', error);
        setCheckError('Unable to check status. Please try refreshing manually.');
      }
    }, 5000);

    return () => clearInterval(pollInterval);
  }, [isApproved, loading, refreshAuth]);

  const handleManualRefresh = async () => {
    setIsChecking(true);
    setCheckError(null);
    try {
      await refreshAuth();
      setLastCheckTime(new Date());
    } catch (error) {
      console.error('Manual check failed:', error);
      setCheckError('Unable to check status. Please try again shortly.');
    } finally {
      setIsChecking(false);
    }
  };

  const handleLogout = async () => {
    setIsLoading(true);
    await signOut();
  };

  // Format time since last check
  const getTimeSinceLastCheck = () => {
    if (!lastCheckTime) return 'just now';
    
    const seconds = Math.floor((new Date().getTime() - lastCheckTime.getTime()) / 1000);
    
    if (seconds < 60) return `${seconds}s ago`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    return `${Math.floor(seconds / 3600)}h ago`;
  };

  return (
    <div className="space-y-8 text-center">
      {/* Icon */}
      <div className="flex justify-center">
        <div
          className="p-4 rounded-full"
          style={{ backgroundColor: 'rgba(127, 85, 57, 0.1)' }}
        >
          <Clock size={48} style={{ color: '#7F5539' }} />
        </div>
      </div>

      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold mb-2" style={{ color: '#2D2D2D' }}>
          Account Pending Approval
        </h1>
        <p
          className="text-lg mb-4"
          style={{ color: 'rgba(45, 45, 45, 0.6)' }}
        >
          Thank you for signing up!
        </p>
      </div>

      {/* Message */}
      <div
        className="p-6 rounded-lg"
        style={{
          backgroundColor: 'rgba(127, 85, 57, 0.1)',
        }}
      >
        <p style={{ color: 'rgba(45, 45, 45, 0.8)', lineHeight: '1.6' }}>
          Your account has been created and is now pending approval by an administrator.
          <br />
          <br />
          You will receive an email notification once your account has been approved,
          at which point you'll be automatically redirected to the dashboard.
        </p>
      </div>

      {/* Info Box - What's Happening */}
      <div
        className="p-4 rounded-lg text-sm flex items-start gap-3"
        style={{
          backgroundColor: '#FEF3C7',
          color: '#78350F',
          borderLeft: '4px solid #F59E0B',
        }}
      >
        <AlertCircle size={20} className="flex-shrink-0 mt-0.5" />
        <div className="text-left">
          <p className="font-semibold mb-1">What's Happening</p>
          <ul style={{ fontSize: '0.875rem', lineHeight: '1.5' }}>
            <li>✓ Your account is created</li>
            <li>⏳ An administrator is reviewing your request</li>
            <li>✓ Your status is checked automatically every 5 seconds</li>
            <li>📧 You'll get an email when approved</li>
          </ul>
        </div>
      </div>

      {/* Auto-Check Status */}
      <div
        className="p-4 rounded-lg text-sm"
        style={{
          backgroundColor: 'rgba(34, 197, 94, 0.05)',
          border: '1px solid rgba(34, 197, 94, 0.2)',
          color: 'rgba(20, 83, 45, 0.8)',
        }}
      >
        <div className="flex items-center justify-center gap-2 mb-2">
          <CheckCircle2 size={16} style={{ color: '#22C55E' }} />
          <span className="font-semibold">Auto-checking in progress</span>
        </div>
        <p>
          Status checked {lastCheckTime ? getTimeSinceLastCheck() : 'continuously'} — 
          will refresh automatically every 5 seconds.
        </p>
      </div>

      {/* Error Message */}
      {checkError && (
        <div
          className="p-4 rounded-lg text-sm flex items-start gap-3"
          style={{
            backgroundColor: '#FEE2E2',
            color: '#7F1D1D',
            borderLeft: '4px solid #EF4444',
          }}
        >
          <AlertCircle size={16} className="flex-shrink-0 mt-0.5" />
          <div className="text-left">{checkError}</div>
        </div>
      )}

      {/* Manual Refresh Button */}
      <button
        onClick={handleManualRefresh}
        disabled={isChecking}
        className="w-full py-3 rounded-lg font-semibold transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
        style={{
          backgroundColor: 'rgba(127, 85, 57, 0.1)',
          color: '#7F5539',
          border: '2px solid #7F5539',
        }}
        onMouseEnter={(e) => {
          if (!isChecking) {
            e.currentTarget.style.backgroundColor = 'rgba(127, 85, 57, 0.15)';
          }
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.backgroundColor = 'rgba(127, 85, 57, 0.1)';
        }}
      >
        <RefreshCw size={18} className={isChecking ? 'animate-spin' : ''} />
        {isChecking ? 'Checking...' : 'Refresh Check Now'}
      </button>

      {/* Logout Button */}
      <button
        onClick={handleLogout}
        disabled={isLoading}
        className="w-full py-3 rounded-lg font-semibold transition-colors disabled:opacity-50"
        style={{
          backgroundColor: '#7F5539',
          color: '#F5F1ED',
        }}
        onMouseEnter={(e) => {
          if (!isLoading) {
            e.currentTarget.style.backgroundColor = '#6B4C3D';
          }
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.backgroundColor = '#7F5539';
        }}
      >
        {isLoading ? 'Logging Out...' : 'Log Out'}
      </button>

      {/* Back to Sign In */}
      <p style={{ color: 'rgba(45, 45, 45, 0.6)', fontSize: '0.875rem' }}>
        Already approved?{' '}
        <button
          onClick={() => router.push('/auth/login')}
          className="font-semibold transition-colors"
          style={{ color: '#7F5539' }}
          onMouseEnter={(e) => (e.currentTarget.style.color = '#6B4C3D')}
          onMouseLeave={(e) => (e.currentTarget.style.color = '#7F5539')}
        >
          Sign in here
        </button>
      </p>
    </div>
  );
}
