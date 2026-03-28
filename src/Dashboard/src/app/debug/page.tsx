'use client';

import { useAuth } from '@/lib/auth-context';
import { useEffect, useState } from 'react';

export default function DebugPage() {
  const { user, profile, loading, isAuthenticated, isApproved, isAdmin } =
    useAuth();
  const [diagnostics, setDiagnostics] = useState<string>('');

  useEffect(() => {
    if (!loading) {
      const diag = `
=== AUTH DIAGNOSTICS ===
Timestamp: ${new Date().toISOString()}

User Authentication:
  - Authenticated: ${isAuthenticated}
  - User ID: ${user?.id || 'NOT SET'}
  - Email: ${user?.email || 'NOT SET'}
  - User Last Sign In: ${user?.last_sign_in_at || 'NOT SET'}

Profile Data:
  - Profile loaded: ${profile !== null}
  - Approval Status: ${profile?.approval_status || 'NOT SET'}
  - Role: ${profile?.role || 'NOT SET'}
  - First Name: ${profile?.first_name || 'NOT SET'}
  - Is Approved: ${isApproved}
  - Is Admin: ${isAdmin}

Loading State:
  - Loading: ${loading}

Troubleshooting:
  - If profile data is missing but user is authenticated, check browser console for "Auth context: Profile fetch failed" errors
  - Common causes:
    1. RLS policies blocking access to profiles table
    2. Profile record not created after signup
    3. Database permissions issue
  `;
      setDiagnostics(diag);
    }
  }, [user, profile, loading, isAuthenticated, isApproved, isAdmin]);

  return (
    <div style={{ padding: '20px', fontFamily: 'monospace' }}>
      <h1>Auth Debug Page</h1>
      <p>
        Check your browser console (F12 → Console tab) for detailed error
        messages
      </p>
      <pre
        style={{
          backgroundColor: '#f4f4f4',
          padding: '15px',
          borderRadius: '4px',
          overflowX: 'auto',
        }}
      >
        {diagnostics}
      </pre>
      <hr />
      <h2>Raw JSON Data:</h2>
      <pre
        style={{
          backgroundColor: '#f4f4f4',
          padding: '15px',
          borderRadius: '4px',
          overflowX: 'auto',
        }}
      >
        {JSON.stringify(
          {
            user: user ? { id: user.id, email: user.email } : null,
            profile,
            authStatus: {
              isAuthenticated,
              isApproved,
              isAdmin,
              loading,
            },
          },
          null,
          2
        )}
      </pre>
    </div>
  );
}
