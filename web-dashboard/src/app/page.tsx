'use client';

import { useState } from 'react';
import Link from 'next/link';
import { Menu, Clock, AlertCircle, MessageSquare, Zap, BarChart3, Bell, ArrowRight } from 'lucide-react';
import { Sidenav } from '@/components/Sidenav';
import { SessionHealthCard } from '@/components/SessionHealthCard';
import { getMostRecentSession, getAllSessions, getAggregateStats } from '@/lib/mockData';
import { formatTimeOnly, formatDateTimeFull } from '@/lib/dateUtils';

export default function Home() {
  const [sidenavOpen, setSidenavOpen] = useState(false);
  const mostRecentSession = getMostRecentSession();
  const allSessions = getAllSessions();
  const stats = getAggregateStats();
  const recentSessions = allSessions.slice(0, 10);

  const toggleSidenav = () => {
    setSidenavOpen(!sidenavOpen);
  };

  return (
    <div className="flex min-h-screen" style={{ backgroundColor: '#7F5539' }}>
      <Sidenav isOpen={sidenavOpen} onToggle={toggleSidenav} />

      {/* Main content area */}
      <div className={`flex-1 transition-all duration-300 box-border ${sidenavOpen ? 'ml-64' : ''}`}>
        <div
          className={`flex min-h-screen w-full flex-col py-6 sm:py-8 px-4 sm:px-8 md:px-12 lg:px-16 pt-12 sm:pt-16 md:pt-20 ${sidenavOpen ? 'rounded-l-xl' : ''}`}
          style={{ backgroundColor: '#EDE0D4', color: '#2D2D2D' }}
        >
          {/* Header with toggle button */}
          <div className="flex items-center gap-3 sm:gap-4 mb-8 sm:mb-10 md:mb-12">
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
            <h1 className="text-3xl sm:text-4xl md:text-5xl font-bold" style={{ color: '#2D2D2D' }}>
              Dashboard
            </h1>
          </div>

          <div className="flex-1 overflow-y-auto w-full">
            {/* Top Row: Most Recent Session + Overall Statistics */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 sm:gap-8 mb-8 sm:mb-12">
              {/* Most Recent Session - Featured Card */}
              {mostRecentSession && (
                <div>
                  <h2 className="text-xl sm:text-2xl font-bold mb-3 sm:mb-4" style={{ color: '#2D2D2D' }}>
                    Most Recent Session
                  </h2>
                  <Link href={`/sessions/${mostRecentSession.sessionId}`}>
                    <SessionHealthCard
                      title={mostRecentSession.sessionId}
                      status={{
                        label: 'Active',
                        isActive: true,
                      }}
                      topLeftContent={
                        <div className="flex flex-col items-center justify-center">
                          <div className="relative w-32 h-32 mb-4">
                            <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100">
                              <circle cx="50" cy="50" r="45" fill="none" stroke="#DDB892" strokeWidth="2" />
                              <circle 
                                cx="50" 
                                cy="50" 
                                r="45" 
                                fill="none" 
                                stroke="#E6CCB2" 
                                strokeWidth="8" 
                                strokeDasharray={`${
                                  (2 * Math.PI * 45) * 
                                  (Math.max(1 - (mostRecentSession.interventions / Math.max(mostRecentSession.transcriptChunks || 1, 1)), 0))
                                } ${2 * Math.PI * 45}`}
                                strokeLinecap="round" 
                              />
                            </svg>
                            <div className="absolute inset-0 flex flex-col items-center justify-center">
                              <span className="text-3xl font-bold" style={{ color: '#F5F1ED' }}>
                                {Math.round(
                                  100 - ((mostRecentSession.interventions / Math.max(mostRecentSession.transcriptChunks || 1, 1)) * 100)
                                )}%
                              </span>
                              <span className="text-xs" style={{ color: 'rgba(245, 241, 237, 0.7)' }}>per 100 turns</span>
                            </div>
                          </div>
                          
                          {/* Coherence Label with Tooltip */}
                          <div className="relative group">
                            <p className="text-xs text-center cursor-help" style={{ color: 'rgba(245, 241, 237, 0.6)' }}>Conversation Coherence</p>
                            
                            {/* Tooltip */}
                            <div className="absolute bottom-full mb-3 left-1/2 -translate-x-1/2 px-3 py-2 text-xs rounded-md whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none" style={{ backgroundColor: '#7F5539', color: '#F5F1ED' }}>
                              Measures system interruptions per conversation turn. Fewer = better flow.
                              <div className="absolute top-full left-1/2 -translate-x-1/2 border-4 border-transparent" style={{ borderTopColor: '#7F5539' }}></div>
                            </div>
                          </div>
                        </div>
                      }
                      topRightContent={
                        <div className="flex flex-col justify-center space-y-4">
                          <div className="flex flex-col items-center space-y-4">
                            {/* Duration */}
                            <div className="text-center">
                              <div className="flex items-center justify-center gap-2 mb-2">
                                <Clock size={20} style={{ color: '#E6CCB2' }} />
                                <span className="text-xs" style={{ color: 'rgba(245, 241, 237, 0.8)' }}>Duration</span>
                              </div>
                              <p className="text-3xl font-bold" style={{ color: '#F5F1ED' }}>
                                {mostRecentSession.duration ? `${mostRecentSession.duration.minutes}m ${mostRecentSession.duration.seconds}s` : '—'}
                              </p>
                            </div>

                            {/* Start & End Times Side by Side */}
                            <div className="grid grid-cols-2 gap-4 w-full pt-2" style={{ borderTop: '1px solid rgba(245, 241, 237, 0.2)' }}>
                              <div className="text-center">
                                <p className="text-xs" style={{ color: 'rgba(245, 241, 237, 0.6)' }}>Start</p>
                                <p className="text-sm font-bold" style={{ color: '#F5F1ED' }}>{formatTimeOnly(mostRecentSession.startTime)}</p>
                              </div>
                              <div className="text-center">
                                <p className="text-xs" style={{ color: 'rgba(245, 241, 237, 0.6)' }}>End</p>
                                <p className="text-sm font-bold" style={{ color: '#F5F1ED' }}>{mostRecentSession.endTime ? formatTimeOnly(mostRecentSession.endTime) : '—'}</p>
                              </div>
                            </div>
                          </div>
                        </div>
                      }
                      bottomSections={[
                        {
                          title: 'Conversation Activity',
                          items: [
                            {
                              label: 'Speech Segments',
                              value: mostRecentSession.transcriptChunks || 0,
                              icon: <BarChart3 size={16} />,
                              color: '#E6CCB2',
                            },
                            {
                              label: 'Prompts',
                              value: mostRecentSession.prompts,
                              icon: <MessageSquare size={16} />,
                              color: '#E6CCB2',
                            },
                          ],
                        },
                        {
                          title: 'System Behavior',
                          items: [
                            {
                              label: 'Interventions',
                              value: `${mostRecentSession.interventions} / ${mostRecentSession.transcriptChunks || 0}`,
                              icon: <Bell size={16} />,
                              color: '#E6CCB2',
                            },
                            {
                              label: 'Issues Detected',
                              value: mostRecentSession.errorCount,
                              icon: <AlertCircle size={16} />,
                              color: '#FFB5A0',
                              badge: true,
                            },
                          ],
                        },
                      ]}
                    />
                  </Link>
                </div>
              )}

              {/* Overall Statistics - Right Column */}
              <div>
                <h2 className="text-xl sm:text-2xl font-bold mb-3 sm:mb-4" style={{ color: '#2D2D2D' }}>
                  Overall Statistics
                </h2>
                <div className="grid grid-cols-2 gap-3 sm:gap-4 h-full">
                  <div className="flex flex-col items-center justify-center text-center">
                    <p className="text-xs uppercase font-semibold" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>
                      Total Sessions
                    </p>
                    <p className="text-4xl font-bold mt-3" style={{ color: '#7F5539' }}>
                      {stats.totalSessions}
                    </p>
                  </div>

                  <div className="flex flex-col items-center justify-center text-center">
                    <p className="text-xs uppercase font-semibold" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>
                      Avg Interventions
                    </p>
                    <p className="text-4xl font-bold mt-3" style={{ color: '#9C6644' }}>
                      {stats.averageInterventions}
                    </p>
                  </div>

                  <div className="flex flex-col items-center justify-center text-center">
                    <p className="text-xs uppercase font-semibold" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>
                      Avg Latency
                    </p>
                    <p className="text-4xl font-bold mt-3" style={{ color: '#9C6644' }}>
                      {stats.averageLatency}s
                    </p>
                  </div>

                  <div className="flex flex-col items-center justify-center text-center">
                    <p className="text-xs uppercase font-semibold" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>
                      % With Errors
                    </p>
                    <p className="text-4xl font-bold mt-3" style={{ color: '#FFB5A0' }}>
                      {stats.percentageWithErrors}%
                    </p>
                  </div>
                </div>
              </div>
            </div>

            {/* Recent Sessions Preview */}
            <div className="mb-8 sm:mb-12 mt-12 sm:mt-16 md:mt-20">
              <div className="flex flex-col sm:flex-row sm:justify-between items-start sm:items-center gap-3 sm:gap-4 mb-3 sm:mb-4">
                <h2 className="text-xl sm:text-2xl font-bold" style={{ color: '#2D2D2D' }}>
                  Recent Sessions
                </h2>
                <Link
                  href="/sessions"
                  className="inline-flex items-center gap-2 px-3 sm:px-4 py-2 rounded-lg transition-colors text-sm sm:text-base"
                  style={{ backgroundColor: '#7F5539', color: '#F5F1ED' }}
                  onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#6B4C3D')}
                  onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = '#7F5539')}
                >
                  View All Sessions
                  <ArrowRight size={18} />
                </Link>
              </div>

              <div className="bg-white rounded-xl shadow-md overflow-hidden">
                {recentSessions.length > 0 ? (
                  <div className="overflow-x-auto">
                    <table className="w-full text-xs sm:text-sm">
                      <thead>
                        <tr style={{ backgroundColor: '#7F5539', color: '#F5F1ED' }}>
                          <th className="px-2 sm:px-4 md:px-6 py-3 sm:py-4 text-left font-semibold">Session ID</th>
                          <th className="px-2 sm:px-4 md:px-6 py-3 sm:py-4 text-left font-semibold">Start Time</th>
                          <th className="px-2 sm:px-4 md:px-6 py-3 sm:py-4 text-center font-semibold">Interventions</th>
                          <th className="px-2 sm:px-4 md:px-6 py-3 sm:py-4 text-center font-semibold">Prompts</th>
                          <th className="px-2 sm:px-4 md:px-6 py-3 sm:py-4 text-center font-semibold">Avg Latency</th>
                          <th className="px-2 sm:px-4 md:px-6 py-3 sm:py-4 text-center font-semibold">Status</th>
                          <th className="px-2 sm:px-4 md:px-6 py-3 sm:py-4 text-center font-semibold">Action</th>
                        </tr>
                      </thead>
                      <tbody>
                        {recentSessions.map((session, index) => (
                          <tr
                            key={session.sessionId}
                            style={{
                              backgroundColor: index % 2 === 0 ? '#ffffff' : '#fafafa',
                              borderBottom: '1px solid #E6CCB2',
                            }}
                          >
                            <td className="px-2 sm:px-4 md:px-6 py-3 sm:py-4 font-mono" style={{ color: '#7F5539' }}>
                              {session.sessionId}
                            </td>
                            <td className="px-2 sm:px-4 md:px-6 py-3 sm:py-4" style={{ color: '#2D2D2D' }}>
                              {formatDateTimeFull(session.startTime)}
                            </td>
                            <td className="px-2 sm:px-4 md:px-6 py-3 sm:py-4 text-center\">
                              <span className="inline-flex items-center gap-1 px-2 py-1 rounded text-xs whitespace-nowrap" style={{ backgroundColor: 'rgba(230, 204, 178, 0.2)', color: '#9C6644' }}>
                                <Zap size={14} />
                                {session.interventions}
                              </span>
                            </td>
                            <td className="px-2 sm:px-4 md:px-6 py-3 sm:py-4 text-center\">
                              <span className="inline-flex items-center gap-1 px-2 py-1 rounded text-xs whitespace-nowrap" style={{ backgroundColor: 'rgba(214, 186, 164, 0.2)', color: '#9C6644' }}>
                                <MessageSquare size={14} />
                                {session.prompts}
                              </span>
                            </td>
                            <td className="px-2 sm:px-4 md:px-6 py-3 sm:py-4 text-center" style={{ color: '#2D2D2D' }}>
                              {session.averageLatency ? `${session.averageLatency}s` : '—'}
                            </td>
                            <td className="px-2 sm:px-4 md:px-6 py-3 sm:py-4 text-center\">
                              {session.errorCount > 0 ? (
                                <span className="inline-flex items-center gap-1 px-2 py-1 rounded text-xs whitespace-nowrap" style={{ backgroundColor: 'rgba(255, 107, 91, 0.2)', color: '#FF6B5B' }}>
                                  <AlertCircle size={14} />
                                  Errors
                                </span>
                              ) : (
                                <span className="inline-flex items-center gap-1 px-2 py-1 rounded text-xs whitespace-nowrap" style={{ backgroundColor: 'rgba(144, 169, 85, 0.2)', color: '#90A955' }}>
                                  ✓ Clean
                                </span>
                              )}
                            </td>
                            <td className="px-2 sm:px-4 md:px-6 py-3 sm:py-4 text-center\">
                              <Link
                                href={`/sessions/${session.sessionId}`}
                                className="inline-block px-2 sm:px-3 py-1 rounded text-xs sm:text-sm font-medium transition-colors whitespace-nowrap"
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
                    <p className="text-lg font-medium">No sessions available</p>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
