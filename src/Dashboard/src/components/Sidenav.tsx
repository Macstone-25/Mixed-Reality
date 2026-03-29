'use client';

import { X, LogOut } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { signOut } from "@/lib/auth-actions";
import { useState } from "react";

interface NavItem {
  label: string;
  href: string;
}

interface SidenavProps {
  isOpen: boolean;
  onToggle: () => void;
  navItems?: NavItem[];
}

const defaultNavItems: NavItem[] = [
  { label: "Dashboard", href: "/" },
  { label: "All Sessions", href: "/sessions" },
  { label: "Profile", href: "/profile" },
];

export function Sidenav({ isOpen, onToggle, navItems = defaultNavItems }: SidenavProps) {
  const router = useRouter();
  const { user, profile, loading, isAdmin } = useAuth();
  const [isLoggingOut, setIsLoggingOut] = useState(false);

  const handleLogout = async () => {
    setIsLoggingOut(true);
    try {
      const result = await signOut();
      if (result.success) {
        // Use hard redirect to clear all client-side state and auth context cache
        // router.push() is a soft navigation that doesn't clear cached auth state
        window.location.href = '/auth/login';
      } else {
        console.error('Logout failed:', result.error);
        alert('Logout failed. Please try again.');
        setIsLoggingOut(false);
      }
    } catch (error) {
      console.error('Logout error:', error);
      alert('An error occurred during logout');
      setIsLoggingOut(false);
    }
  };

  // Get user display name
  const displayName = profile?.first_name && profile?.last_name
    ? `${profile.first_name} ${profile.last_name}`
    : user?.email || 'User';

  return (
    <>
      {/* Sidenav */}
      <nav
        className={`fixed left-0 top-0 h-screen w-64 shadow-lg transform transition-transform duration-300 ease-in-out z-40 ${
          isOpen ? "translate-x-0" : "-translate-x-full"
        }`}
        style={{ backgroundColor: '#7F5539' }}
      >
        <div className="flex flex-col h-full p-6" style={{ color: '#F5F1ED' }}>
          {/* Close button */}
          <button
            onClick={onToggle}
            className="self-end mb-8 p-2 rounded-lg transition-colors"
            style={{ color: '#F5F1ED', backgroundColor: 'rgba(245, 241, 237, 0.1)' }}
            onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.2)')}
            onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.1)')}
            aria-label="Close navigation"
          >
            <X size={24} />
          </button>

          {/* User Info Section */}
          {!loading && user && (
            <div
              className="mb-6 p-4 rounded-lg"
              style={{ backgroundColor: 'rgba(245, 241, 237, 0.1)' }}
            >
              <p className="text-xs" style={{ color: 'rgba(245, 241, 237, 0.6)' }}>
                Logged in as
              </p>
              <p className="font-semibold mt-1 break-words">{displayName}</p>
              <p className="text-xs mt-2 break-words" style={{ color: 'rgba(245, 241, 237, 0.7)' }}>
                {user.email}
              </p>
            </div>
          )}

          {/* Navigation items */}
          <div className="space-y-2 flex-1">
            {navItems.map((item) => (
              <Link
                key={item.label}
                href={item.href}
                className="block px-4 py-2 rounded-lg transition-colors"
                style={{ color: '#F5F1ED' }}
                onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.15)')}
                onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
              >
                {item.label}
              </Link>
            ))}

            {/* Admin Section */}
            {isAdmin && (
              <>
                <div className="my-4 border-t" style={{ borderColor: 'rgba(245, 241, 237, 0.2)' }}></div>
                <p className="text-xs px-4 pt-2" style={{ color: 'rgba(245, 241, 237, 0.6)' }}>
                  ADMIN
                </p>
                <Link
                  href="/admin/users"
                  className="block px-4 py-2 rounded-lg transition-colors"
                  style={{ color: '#F5F1ED' }}
                  onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.15)')}
                  onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
                >
                  User Management
                </Link>
              </>
            )}
          </div>

          {/* Footer with Logout */}
          <div className="border-t pt-4 space-y-3" style={{ borderColor: 'rgba(245, 241, 237, 0.2)' }}>
            {/* Logout Button */}
            {!loading && user && (
              <button
                onClick={handleLogout}
                disabled={isLoggingOut}
                className="w-full px-4 py-2 rounded-lg font-semibold transition-colors disabled:opacity-50 flex items-center gap-2"
                style={{
                  backgroundColor: 'rgba(245, 241, 237, 0.15)',
                  color: '#F5F1ED',
                }}
                onMouseEnter={(e) => {
                  if (!isLoggingOut) {
                    e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.25)';
                  }
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.backgroundColor = 'rgba(245, 241, 237, 0.15)';
                }}
              >
                <LogOut size={18} />
                {isLoggingOut ? 'Logging out...' : 'Logout'}
              </button>
            )}

            {/* Copyright */}
            <p className="text-xs" style={{ color: 'rgba(245, 241, 237, 0.6)' }}>
              Capstone © 2026
            </p>
          </div>
        </div>
      </nav>

      {/* Overlay when sidenav is open */}
      {isOpen && (
        <div
          className="fixed inset-0 z-30 transition-opacity"
          onClick={onToggle}
          aria-hidden="true"
        />
      )}
    </>
  );
}
