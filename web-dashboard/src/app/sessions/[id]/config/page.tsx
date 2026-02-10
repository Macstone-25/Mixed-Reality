'use client';

import { useState } from 'react';
import Link from 'next/link';
import { ArrowLeft, Copy, Check, Menu } from 'lucide-react';
import { getSessionById } from '@/lib/mockData';
import { Sidenav } from '@/components/Sidenav';

interface Props {
  params: Promise<{
    id: string;
  }>;
}

// Since this component needs to handle params and useClient state, we need a wrapper
// For now, we'll export a client component that handles the logic
type PageProps = {
  params: { id: string };
};

export default function ConfigPage({ params }: PageProps) {
  const id = params.id;
  const session = getSessionById(id);
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
              <Link
                href="/sessions"
                className="inline-block px-6 py-3 rounded-lg font-medium transition-colors"
                style={{ backgroundColor: '#7F5539', color: '#F5F1ED' }}
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
              Configuration
            </h1>
          </div>

          <div className="flex-1 overflow-y-auto w-full">
            {/* Back to Session Link */}
            <Link
              href={`/sessions/${id}`}
              className="inline-flex items-center gap-2 mb-6 px-4 py-2 rounded-lg transition-colors"
              style={{ backgroundColor: 'rgba(127, 85, 57, 0.1)', color: '#7F5539' }}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(127, 85, 57, 0.15)')}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'rgba(127, 85, 57, 0.1)')}
            >
              <ArrowLeft size={18} />
              Back to Session
            </Link>

            <ConfigCard config={session.config} sessionId={session.sessionId} />
          </div>
        </div>
      </div>
    </div>
  );
}

function ConfigCard({ config, sessionId }: { config: any; sessionId: string }) {
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  const handleCopy = (key: string, value: any) => {
    const text = typeof value === 'object' ? JSON.stringify(value, null, 2) : String(value);
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  const configJson = JSON.stringify(config, null, 2);

  return (
    <div className="space-y-6">
      {/* Full Config JSON */}
      <div className="bg-white rounded-xl shadow-md overflow-hidden">
        <div className="px-6 py-4" style={{ backgroundColor: '#7F5539', color: '#F5F1ED' }}>
          <h2 className="text-lg font-semibold">Full Configuration (JSON)</h2>
        </div>

        <div className="p-6">
          <div className="relative">
            <pre
              className="bg-gray-900 text-green-400 p-4 rounded-lg overflow-x-auto text-xs leading-relaxed"
              style={{
                fontFamily: "'Monaco', 'Menlo', 'Ubuntu Mono', 'Courier New', monospace",
              }}
            >
              {configJson}
            </pre>
            <button
              onClick={() => handleCopy('full', config)}
              className="absolute top-4 right-4 p-2 rounded-lg transition-colors"
              style={{
                backgroundColor: 'rgba(255, 255, 255, 0.1)',
                color: '#fff',
              }}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.2)')}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.1)')}
              title="Copy to clipboard"
            >
              {copiedKey === 'full' ? <Check size={18} /> : <Copy size={18} />}
            </button>
          </div>
        </div>
      </div>

      {/* Individual Config Items */}
      <div className="bg-white rounded-xl shadow-md overflow-hidden">
        <div className="px-6 py-4" style={{ backgroundColor: '#7F5539', color: '#F5F1ED' }}>
          <h2 className="text-lg font-semibold">Configuration Details</h2>
        </div>

        <div className="divide-y" style={{ borderColor: '#E6CCB2' }}>
          {Object.entries(config).map(([key, value]) => (
            <div key={key} className="px-6 py-6 flex items-start justify-between gap-4">
              <div className="flex-1">
                <p className="text-sm uppercase font-semibold" style={{ color: 'rgba(45, 45, 45, 0.6)', letterSpacing: '0.05em' }}>
                  {key}
                </p>
                <p className="text-sm mt-2 font-mono" style={{ color: '#2D2D2D' }}>
                  {typeof value === 'object' ? JSON.stringify(value, null, 2) : String(value)}
                </p>
              </div>
              <button
                onClick={() => handleCopy(key, value)}
                className="p-2 rounded-lg transition-colors flex-shrink-0"
                style={{
                  backgroundColor: 'rgba(127, 85, 57, 0.1)',
                  color: '#7F5539',
                }}
                onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(127, 85, 57, 0.2)')}
                onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'rgba(127, 85, 57, 0.1)')}
                title="Copy to clipboard"
              >
                {copiedKey === key ? <Check size={18} /> : <Copy size={18} />}
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* CTA Buttons */}
      <div className="flex gap-4 pt-4">
        <Link
          href={`/sessions/${sessionId}`}
          className="inline-block px-6 py-3 rounded-lg font-medium transition-colors"
          style={{ backgroundColor: '#7F5539', color: '#F5F1ED' }}
          onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#6B4C3D')}
          onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = '#7F5539')}
        >
          View Session Detail
        </Link>
        <Link
          href="/sessions"
          className="inline-block px-6 py-3 rounded-lg font-medium transition-colors"
          style={{ backgroundColor: 'rgba(127, 85, 57, 0.1)', color: '#7F5539' }}
          onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(127, 85, 57, 0.2)')}
          onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'rgba(127, 85, 57, 0.1)')}
        >
          All Sessions
        </Link>
      </div>
    </div>
  );
}
