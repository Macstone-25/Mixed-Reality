import { MessageSquare, Zap, Clock, AlertCircle } from 'lucide-react';
import { formatTimeOnly } from '@/lib/dateUtils';
import type { EventLog } from '@/lib/types';

interface EventsTableProps {
  events: EventLog[];
}

export function EventsTable({ events }: EventsTableProps) {
  return (
    <div className="bg-white rounded-xl shadow-md overflow-hidden">
      <div className="px-6 py-4" style={{ backgroundColor: '#7F5539', color: '#F5F1ED' }}>
        <h3 className="text-lg font-semibold">Interruptions & Prompts</h3>
      </div>

      {events.length > 0 ? (
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr style={{ backgroundColor: '#ECDFC2', borderBottom: '2px solid #E6CCB2' }}>
                <th className="px-6 py-3 text-left text-sm font-semibold" style={{ color: '#2D2D2D' }}>Type</th>
                <th className="px-6 py-3 text-left text-sm font-semibold" style={{ color: '#2D2D2D' }}>Event ID</th>
                <th className="px-6 py-3 text-left text-sm font-semibold" style={{ color: '#2D2D2D' }}>Message</th>
                <th className="px-6 py-3 text-center text-sm font-semibold" style={{ color: '#2D2D2D' }}>Latency</th>
                <th className="px-6 py-3 text-left text-sm font-semibold" style={{ color: '#2D2D2D' }}>Timestamp</th>
              </tr>
            </thead>
            <tbody>
              {events.map((event, index) => (
                <tr
                  key={event.eventId}
                  style={{
                    backgroundColor: index % 2 === 0 ? '#ffffff' : '#fafafa',
                    borderBottom: '1px solid #E6CCB2',
                  }}
                >
                  <td className="px-6 py-4">
                    {event.type === 'intervention' ? (
                      <span className="inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium" style={{ backgroundColor: 'rgba(230, 204, 178, 0.2)', color: '#9C6644' }}>
                        <Zap size={14} />
                        Intervention
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium" style={{ backgroundColor: 'rgba(214, 186, 164, 0.2)', color: '#9C6644' }}>
                        <MessageSquare size={14} />
                        Prompt
                      </span>
                    )}
                  </td>
                  <td className="px-6 py-4 text-sm font-mono" style={{ color: '#7F5539' }}>
                    {event.eventId}
                  </td>
                  <td className="px-6 py-4 text-sm" style={{ color: '#2D2D2D' }}>
                    {event.message}
                  </td>
                  <td className="px-6 py-4 text-center text-sm" style={{ color: '#2D2D2D' }}>
                    {event.latency ? `${event.latency}s` : '—'}
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-600" style={{ color: 'rgba(45, 45, 45, 0.7)' }}>
                    {event.timestamp ? formatTimeOnly(event.timestamp) : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center py-8" style={{ color: 'rgba(45, 45, 45, 0.5)' }}>
          <p className="text-sm">No events recorded for this session</p>
        </div>
      )}
    </div>
  );
}
