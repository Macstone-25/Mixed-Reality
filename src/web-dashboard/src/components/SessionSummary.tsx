import { Clock, Zap, MessageSquare, AlertCircle, BarChart3 } from 'lucide-react';
import { formatDateTimeFull } from '@/lib/dateUtils';
import type { SessionMetadata } from '@/lib/types';

interface SessionSummaryProps {
  session: SessionMetadata;
}

export function SessionSummary({ session }: SessionSummaryProps) {
  return (
    <div className="bg-white rounded-xl shadow-md p-6 mb-8">
      {/* Header */}
      <div className="flex justify-between items-start mb-6 pb-6" style={{ borderBottom: '2px solid #E6CCB2' }}>
        <div>
          <p className="text-sm" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>Session ID</p>
          <h1 className="text-3xl font-bold font-mono" style={{ color: '#7F5539' }}>
            {session.sessionId}
          </h1>
        </div>
        <div className="text-right">
          <p className="text-sm" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>Start Time</p>
          <p className="text-lg font-bold" style={{ color: '#2D2D2D' }}>
            {formatDateTimeFull(session.startTime)}
          </p>
        </div>
      </div>

      {/* Metrics Grid */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {/* Duration */}
        <div className="p-4 rounded-lg" style={{ backgroundColor: 'rgba(230, 204, 178, 0.1)' }}>
          <div className="flex items-center gap-2 mb-2">
            <Clock size={18} style={{ color: '#7F5539' }} />
            <p className="text-xs uppercase font-semibold" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>Duration</p>
          </div>
          <p className="text-2xl font-bold" style={{ color: '#2D2D2D' }}>
            {session.duration ? `${session.duration.minutes}m ${session.duration.seconds}s` : '—'}
          </p>
        </div>

        {/* Interventions */}
        <div className="p-4 rounded-lg" style={{ backgroundColor: 'rgba(230, 204, 178, 0.1)' }}>
          <div className="flex items-center gap-2 mb-2">
            <Zap size={18} style={{ color: '#7F5539' }} />
            <p className="text-xs uppercase font-semibold" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>Interventions</p>
          </div>
          <p className="text-2xl font-bold" style={{ color: '#2D2D2D' }}>
            {session.interventions}
          </p>
        </div>

        {/* Prompts */}
        <div className="p-4 rounded-lg" style={{ backgroundColor: 'rgba(230, 204, 178, 0.1)' }}>
          <div className="flex items-center gap-2 mb-2">
            <MessageSquare size={18} style={{ color: '#7F5539' }} />
            <p className="text-xs uppercase font-semibold" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>Prompts</p>
          </div>
          <p className="text-2xl font-bold" style={{ color: '#2D2D2D' }}>
            {session.prompts}
          </p>
        </div>

        {/* Avg Latency */}
        <div className="p-4 rounded-lg" style={{ backgroundColor: 'rgba(230, 204, 178, 0.1)' }}>
          <div className="flex items-center gap-2 mb-2">
            <BarChart3 size={18} style={{ color: '#7F5539' }} />
            <p className="text-xs uppercase font-semibold" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>Avg Latency</p>
          </div>
          <p className="text-2xl font-bold" style={{ color: '#2D2D2D' }}>
            {session.averageLatency ? `${session.averageLatency}s` : '—'}
          </p>
        </div>
      </div>

      {/* Error Alert (if present) */}
      {session.errorCount > 0 && (
        <div className="mt-6 p-4 rounded-lg" style={{ backgroundColor: 'rgba(255, 181, 160, 0.15)' }}>
          <div className="flex items-start gap-3">
            <AlertCircle size={20} style={{ color: '#FF6B5B', marginTop: '2px' }} />
            <div>
              <p className="font-semibold" style={{ color: '#FF6B5B' }}>
                {session.errorCount} Error{session.errorCount !== 1 ? 's' : ''} Detected
              </p>
              {session.errors && session.errors.length > 0 && (
                <ul className="mt-2 space-y-1">
                  {session.errors.map((error, i) => (
                    <li key={i} className="text-sm" style={{ color: '#B24A42' }}>
                      • {error}
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
