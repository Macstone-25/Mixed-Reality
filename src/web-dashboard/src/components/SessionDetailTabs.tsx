'use client';

import { useState, useRef } from 'react';
import { EventsTable } from '@/components/EventsTable';
import { TranscriptView } from '@/components/TranscriptView';
import { ExperimentConfig, SessionDetail } from '@/lib/types';

interface TabsContentProps {
  session: SessionDetail;
}

const TABS = [
  { label: 'Events', value: 'events' },
  { label: 'Transcript', value: 'transcript' },
  { label: 'Config', value: 'config' },
];

export function TabsContent({ session }: TabsContentProps) {
  const [activeTab, setActiveTab] = useState('events');
  const [focusedTab, setFocusedTab] = useState('events');
  const tabRefs = useRef<Record<string, HTMLButtonElement | null>>({});

  const handleTabClick = (tabValue: string) => {
    setActiveTab(tabValue);
    setFocusedTab(tabValue);
  };

  const handleKeyDown = (e: React.KeyboardEvent, tabValue: string) => {
    const currentIndex = TABS.findIndex(t => t.value === tabValue);
    let nextIndex = currentIndex;

    if (e.key === 'ArrowRight') {
      e.preventDefault();
      nextIndex = (currentIndex + 1) % TABS.length;
    } else if (e.key === 'ArrowLeft') {
      e.preventDefault();
      nextIndex = (currentIndex - 1 + TABS.length) % TABS.length;
    } else if (e.key === 'Home') {
      e.preventDefault();
      nextIndex = 0;
    } else if (e.key === 'End') {
      e.preventDefault();
      nextIndex = TABS.length - 1;
    } else {
      return;
    }

    const nextTab = TABS[nextIndex].value;
    setActiveTab(nextTab);
    setFocusedTab(nextTab);
    setTimeout(() => tabRefs.current[nextTab]?.focus(), 0);
  };

  return (
    <div>
      {/* Tab Navigation */}
      <div
        className="flex gap-2 mb-6 border-b"
        style={{ borderColor: '#E6CCB2' }}
        role="tablist"
      >
        {TABS.map(tab => (
          <button
            key={tab.value}
            ref={(el) => {
              if (el) tabRefs.current[tab.value] = el;
            }}
            onClick={() => handleTabClick(tab.value)}
            onKeyDown={(e) => handleKeyDown(e, tab.value)}
            onFocus={() => setFocusedTab(tab.value)}
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
            className="px-4 py-3 font-medium transition-colors border-b-2 outline-none focus:ring-2 focus:ring-offset-2"
            style={{
              borderColor: activeTab === tab.value ? '#7F5539' : 'transparent',
              color: activeTab === tab.value ? '#7F5539' : 'rgba(45, 45, 45, 0.6)',
              outlineOffset: '-2px',
            }}
            onFocus={(e) => {
              e.currentTarget.style.outline = '2px solid #7F5539';
              e.currentTarget.style.outlineOffset = '-4px';
            }}
            onBlur={(e) => {
              e.currentTarget.style.outline = 'none';
            }}
            role="tab"
            aria-selected={activeTab === tab.value}
            aria-controls={`tabpanel-${tab.value}`}
            tabIndex={focusedTab === tab.value ? 0 : -1}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      <div>
        {activeTab === 'events' && (
          <div id="tabpanel-events" role="tabpanel" aria-labelledby="tab-events">
            <EventsTable events={session.events} />
          </div>
        )}
        {activeTab === 'transcript' && (
          <div id="tabpanel-transcript" role="tabpanel" aria-labelledby="tab-transcript">
            <TranscriptView transcript={session.transcript} />
          </div>
        )}
        {activeTab === 'config' && (
          <div id="tabpanel-config" role="tabpanel" aria-labelledby="tab-config">
            <ConfigView config={session.config} />
          </div>
        )}
      </div>
    </div>
  );
}

function ConfigView({ config }: { config: ExperimentConfig }) {
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
