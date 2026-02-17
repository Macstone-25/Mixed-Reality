'use client';

import { useState } from 'react';
import Link from 'next/link';
import { Menu, ArrowLeft } from 'lucide-react';
import { Sidenav } from '@/components/Sidenav';
import { SessionSummary } from '@/components/SessionSummary';
import { TabsContent } from '@/components/SessionDetailTabs';

interface SessionDetailPageClientProps {
  sessionId: string;
  session: any;
}

export default function SessionDetailPageClient({ sessionId, session }: SessionDetailPageClientProps) {
  const [sidenavOpen, setSidenavOpen] = useState(false);

  const toggleSidenav = () => {
    setSidenavOpen(!sidenavOpen);
  };

  if (!session) {
    return (
      <div className="flex min-h-screen" style={{ backgroundColor: '#7F5539' }}>
        <Sidenav isOpen={sidenavOpen} onToggle={toggleSidenav} />

        <div className={`flex-1 transition-all duration-300 ${sidenavOpen ? 'ml-64' : ''}`}>
          <div
            className={`flex min-h-screen w-full flex-col items-center justify-center px-16 ${sidenavOpen ? 'rounded-l-xl' : ''}`}
            style={{ backgroundColor: '#EDE0D4', color: '#2D2D2D' }}
          >
            <div className="text-center">
              <h1 className="text-4xl font-bold mb-4" style={{ color: '#2D2D2D' }}>
                Session Not Found
              </h1>
              <p className="text-lg mb-8" style={{ color: 'rgba(45, 45, 45, 0.7)' }}>
                The session "{sessionId}" does not exist.
              </p>
              <Link
                href="/sessions"
                className="inline-block px-6 py-3 rounded-lg font-medium transition-colors"
                style={{ backgroundColor: '#7F5539', color: '#F5F1ED' }}
                onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#6B4C3D')}
                onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = '#7F5539')}
              >
                Back to Sessions
              </Link>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen" style={{ backgroundColor: '#7F5539' }}>
      <Sidenav isOpen={sidenavOpen} onToggle={toggleSidenav} />

      <div className={`flex-1 transition-all duration-300 ${sidenavOpen ? 'ml-64' : ''}`}>
        <div
          className={`flex min-h-screen w-full flex-col py-8 px-16 ${sidenavOpen ? 'rounded-l-xl' : ''}`}
          style={{ backgroundColor: '#EDE0D4', color: '#2D2D2D' }}
        >
          {/* Header with toggle button */}
          <div className="flex items-center gap-4 mb-8">
            <button
              onClick={toggleSidenav}
              className="p-2 rounded-lg transition-colors"
              style={{ color: '#2D2D2D', backgroundColor: 'rgba(45, 45, 45, 0.08)' }}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(45, 45, 45, 0.15)')}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'rgba(45, 45, 45, 0.08)')}
              aria-label="Open navigation"
            >
              <Menu size={24} />
            </button>
            <h1 className="text-3xl font-bold" style={{ color: '#2D2D2D' }}>
              Session Detail
            </h1>
          </div>

          <div className="flex-1 overflow-y-auto w-full">
            {/* Back Button */}
            <Link
              href="/sessions"
              className="inline-flex items-center gap-2 mb-6 px-4 py-2 rounded-lg transition-colors"
              style={{ backgroundColor: 'rgba(127, 85, 57, 0.1)', color: '#7F5539' }}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(127, 85, 57, 0.15)')}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'rgba(127, 85, 57, 0.1)')}
            >
              <ArrowLeft size={18} />
              Back to Sessions
            </Link>

            {/* Session Summary */}
            <SessionSummary session={session} />

            {/* Tabbed Content */}
            <TabsContent session={session} />
          </div>
        </div>
      </div>
    </div>
  );
}
