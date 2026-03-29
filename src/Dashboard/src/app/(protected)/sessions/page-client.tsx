'use client';

import { useState, useMemo } from 'react';
import Link from 'next/link';
import { Search, Filter, AlertCircle, Zap, MessageSquare, Menu } from 'lucide-react';
import { Sidenav } from '@/components/Sidenav';
import { formatDateTimeFull } from '@/lib/dateUtils';
import type { SessionListItem } from '@/lib/types';

interface SessionsPageClientProps {
  allSessions: SessionListItem[];
}

export default function SessionsPageClient({ allSessions }: SessionsPageClientProps) {
  const [sidenavOpen, setSidenavOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterErrors, setFilterErrors] = useState(false);
  const [filterHighInterventions, setFilterHighInterventions] = useState(false);
  const [dateRange, setDateRange] = useState({ start: '', end: '' });

  const toggleSidenav = () => {
    setSidenavOpen(!sidenavOpen);
  };

  const filteredSessions = useMemo(() => {
    return allSessions.filter(session => {
      // Search filter
      if (
        searchQuery &&
        !session.sessionId.toLowerCase().includes(searchQuery.toLowerCase())
      ) {
        return false;
      }

      // Error filter
      if (filterErrors && session.errorCount === 0) {
        return false;
      }

      // High interventions filter (threshold: > 10)
      if (filterHighInterventions && session.interventions <= 10) {
        return false;
      }

      // Date range filter
      if (dateRange.start) {
        const sessionDate = new Date(session.startTime);
        const startDate = new Date(dateRange.start);
        if (sessionDate < startDate) return false;
      }

      if (dateRange.end) {
        const sessionDate = new Date(session.startTime);
        const endDate = new Date(dateRange.end);
        endDate.setHours(23, 59, 59, 999);
        if (sessionDate > endDate) return false;
      }

      return true;
    });
  }, [searchQuery, filterErrors, filterHighInterventions, dateRange, allSessions]);

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
              All Sessions
            </h1>
          </div>

          <div className="flex-1 overflow-y-auto w-full">
            {/* Filters Section */}
            <div className="bg-white rounded-xl p-6 mb-8 shadow-md" style={{ borderLeft: '4px solid #7F5539' }}>
              <div className="flex items-center gap-2 mb-4">
                <Filter size={20} style={{ color: '#7F5539' }} />
                <h2 className="text-lg font-semibold" style={{ color: '#2D2D2D' }}>
                  Filters
                </h2>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                {/* Search */}
                <div className="relative">
                  <Search size={16} className="absolute left-3 top-3" style={{ color: '#9C6644' }} />
                  <input
                    type="text"
                    placeholder="Search by session ID..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="w-full pl-10 pr-4 py-2 rounded-lg border transition-colors"
                    style={{
                      borderColor: '#E6CCB2',
                      backgroundColor: '#ffffff',
                    }}
                  />
                </div>

                {/* Date Range */}
                <div className="flex gap-2">
                  <input
                    type="date"
                    value={dateRange.start}
                    onChange={(e) => setDateRange({ ...dateRange, start: e.target.value })}
                    className="flex-1 px-4 py-2 rounded-lg border"
                    style={{ borderColor: '#E6CCB2' }}
                  />
                  <input
                    type="date"
                    value={dateRange.end}
                    onChange={(e) => setDateRange({ ...dateRange, end: e.target.value })}
                    className="flex-1 px-4 py-2 rounded-lg border"
                    style={{ borderColor: '#E6CCB2' }}
                  />
                </div>

                {/* Checkbox Filters */}
                <label className="flex items-center gap-2 cursor-pointer px-4 py-2 rounded-lg" style={{ backgroundColor: 'rgba(127, 85, 57, 0.05)' }}>
                  <input
                    type="checkbox"
                    checked={filterErrors}
                    onChange={(e) => setFilterErrors(e.target.checked)}
                    className="rounded"
                  />
                  <span className="text-sm">Only errors</span>
                </label>

                <label className="flex items-center gap-2 cursor-pointer px-4 py-2 rounded-lg" style={{ backgroundColor: 'rgba(127, 85, 57, 0.05)' }}>
                  <input
                    type="checkbox"
                    checked={filterHighInterventions}
                    onChange={(e) => setFilterHighInterventions(e.target.checked)}
                    className="rounded"
                  />
                  <span className="text-sm">High interventions (&gt;10)</span>
                </label>
              </div>
            </div>

            {/* Results Summary */}
            <div className="mb-4 text-sm" style={{ color: 'rgba(45, 45, 45, 0.7)' }}>
              Showing {filteredSessions.length} of {allSessions.length} sessions
            </div>

            {/* Sessions Table */}
            <div className="bg-white rounded-xl shadow-md overflow-hidden">
              {filteredSessions.length > 0 ? (
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead>
                      <tr style={{ backgroundColor: '#7F5539', color: '#F5F1ED' }}>
                        <th className="px-6 py-4 text-left text-sm font-semibold">Session ID</th>
                        <th className="px-6 py-4 text-left text-sm font-semibold">Start Time</th>
                        <th className="px-6 py-4 text-center text-sm font-semibold">Interventions</th>
                        <th className="px-6 py-4 text-center text-sm font-semibold">Prompts</th>
                        <th className="px-6 py-4 text-center text-sm font-semibold">Avg Latency</th>
                        <th className="px-6 py-4 text-center text-sm font-semibold">Errors</th>
                        <th className="px-6 py-4 text-center text-sm font-semibold">Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filteredSessions.map((session, index) => (
                        <tr
                          key={session.sessionId}
                          style={{
                            backgroundColor: index % 2 === 0 ? '#ffffff' : '#fafafa',
                            borderBottom: '1px solid #E6CCB2',
                          }}
                        >
                          <td className="px-6 py-4 text-sm font-mono" style={{ color: '#7F5539' }}>
                            {session.sessionId}
                          </td>
                          <td className="px-6 py-4 text-sm" style={{ color: '#2D2D2D' }}>
                            {formatDateTimeFull(session.startTime)}
                          </td>
                          <td className="px-6 py-4 text-center">
                            <span className="inline-flex items-center gap-1 px-2 py-1 rounded" style={{ backgroundColor: 'rgba(230, 204, 178, 0.2)', color: '#9C6644' }}>
                              <Zap size={14} />
                              {session.interventions}
                            </span>
                          </td>
                          <td className="px-6 py-4 text-center">
                            <span className="inline-flex items-center gap-1 px-2 py-1 rounded" style={{ backgroundColor: 'rgba(214, 186, 164, 0.2)', color: '#9C6644' }}>
                              <MessageSquare size={14} />
                              {session.prompts}
                            </span>
                          </td>
                          <td className="px-6 py-4 text-center text-sm" style={{ color: '#2D2D2D' }}>
                            {session.averageLatency ? `${session.averageLatency}s` : '—'}
                          </td>
                          <td className="px-6 py-4 text-center">
                            {session.errorCount > 0 ? (
                              <span className="inline-flex items-center gap-1 px-2 py-1 rounded" style={{ backgroundColor: 'rgba(255, 181, 160, 0.2)', color: '#FF6B5B' }}>
                                <AlertCircle size={14} />
                                {session.errorCount}
                              </span>
                            ) : (
                              <span className="text-sm" style={{ color: '#90A955' }}>
                                ✓
                              </span>
                            )}
                          </td>
                          <td className="px-6 py-4 text-center">
                            <Link
                              href={`/sessions/${session.sessionId}`}
                              className="inline-block px-4 py-2 rounded-lg text-sm font-medium transition-colors"
                              style={{
                                backgroundColor: '#7F5539',
                                color: '#F5F1ED',
                              }}
                              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#6B4C3D')}
                              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = '#7F5539')}
                            >
                              View
                            </Link>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : (
                <div className="flex flex-col items-center justify-center py-12" style={{ color: 'rgba(45, 45, 45, 0.5)' }}>
                  <Filter size={32} className="mb-4" />
                  <p className="text-lg font-medium">No sessions match your filters</p>
                  <p className="text-sm mt-2">Try adjusting your search or filter criteria</p>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
