'use client';

import { useState } from 'react';
import { EventsTable } from '@/components/EventsTable';
import { TranscriptView } from '@/components/TranscriptView';

interface TabsContentProps {
  session: any;
}

export function TabsContent({ session }: TabsContentProps) {
  const [activeTab, setActiveTab] = useState('events');

  return (
    <div>
      {/* Tab Navigation */}
      <div className="flex gap-2 mb-6 border-b" style={{ borderColor: '#E6CCB2' }}>
        {[
          { label: 'Events', value: 'events' },
          { label: 'Transcript', value: 'transcript' },
          { label: 'Config', value: 'config' },
        ].map(tab => (
          <button
            key={tab.value}
            onClick={() => setActiveTab(tab.value)}
            className="px-4 py-3 font-medium transition-colors border-b-2"
            style={{
              borderColor: activeTab === tab.value ? '#7F5539' : 'transparent',
              color: activeTab === tab.value ? '#7F5539' : 'rgba(45, 45, 45, 0.6)',
            }}
            onMouseEnter={(e) => {
              if (activeTab !== tab.value) {
                e.currentTarget.style.color = 'rgba(45, 45, 45, 0.8)';
              }
            }}
            onMouseLeave={(e) => {
              if (activeTab !== tab.value) {
                e.currentTarget.style.color = 'rgba(45, 45, 45, 0.6)';
              }
            }}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      <div>
        {activeTab === 'events' && <EventsTable events={session.events} />}
        {activeTab === 'transcript' && <TranscriptView transcript={session.transcript} />}
        {activeTab === 'config' && <ConfigView config={session.config} />}
      </div>
    </div>
  );
}

function ConfigView({ config }: { config: any }) {
  return (
    <div className="bg-white rounded-xl shadow-md overflow-hidden">
      <div className="px-6 py-4" style={{ backgroundColor: '#7F5539', color: '#F5F1ED' }}>
        <h3 className="text-lg font-semibold">Experiment Configuration</h3>
      </div>

      <div className="px-6 py-6">
        <div className="space-y-4">
          {Object.entries(config).map(([key, value]) => (
            <div key={key} className="flex flex-col border-b pb-4" style={{ borderColor: '#E6CCB2' }}>
              <p className="text-sm uppercase font-semibold" style={{ color: 'rgba(45, 45, 45, 0.6)' }}>
                {key}
              </p>
              <p className="text-sm mt-2 font-mono" style={{ color: '#2D2D2D' }}>
                {typeof value === 'object' ? JSON.stringify(value, null, 2) : String(value)}
              </p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
