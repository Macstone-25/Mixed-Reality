import type { SessionDetail, SessionListItem, AggregateStats } from './types';

/**
 * Mock data for development
 * Replace with actual data fetching from CSV/Events.log/Experiment.json later
 */

const mockSessions: SessionDetail[] = [
  {
    sessionId: 'sess_001_20260210',
    startTime: '2026-02-10T14:30:00Z',
    endTime: '2026-02-10T15:15:00Z',
    duration: { minutes: 45, seconds: 32 },
    interventions: 8,
    prompts: 15,
    averageLatency: 2.3,
    errorCount: 1,
    errors: ['LLM timeout on event 5'],
    transcriptChunks: 42,
    notes: 'Testing with high context window',
    events: [
      { eventId: 'evt_001', type: 'prompt', message: 'Initial system prompt', latency: 1.2, timestamp: '2026-02-10T14:30:05Z' },
      { eventId: 'evt_002', type: 'intervention', message: 'Coherence threshold exceeded', timestamp: '2026-02-10T14:32:10Z' },
      { eventId: 'evt_003', type: 'prompt', message: 'Follow-up clarification', latency: 2.1, timestamp: '2026-02-10T14:33:15Z' },
      { eventId: 'evt_004', type: 'intervention', message: 'Topic drift detected', timestamp: '2026-02-10T14:35:20Z' },
      { eventId: 'evt_005', type: 'prompt', message: 'Refocus prompt', latency: 0.8, timestamp: '2026-02-10T14:36:00Z' },
    ],
    transcript: [
      'Speaker A: Can we discuss the research methodology?',
      'Speaker B: Of course. What specifically?',
      'Speaker A: The sampling approach seems limited.',
      '[System intervention: Refocusing conversation]',
      'Speaker B: Good point. Let me explain the rationale.',
      'Speaker A: That makes sense now.',
    ],
    config: {
      model: 'gpt-4-turbo',
      contextWindow: 8192,
      temperature: 0.7,
      systemPrompt: 'You are a research assistant helping to guide conversations...',
      triggerThresholds: {
        coherenceDrop: 0.15,
        topicDrift: 0.3,
      },
    },
  },
  {
    sessionId: 'sess_002_20260209',
    startTime: '2026-02-09T10:00:00Z',
    endTime: '2026-02-09T10:22:00Z',
    duration: { minutes: 22, seconds: 15 },
    interventions: 3,
    prompts: 8,
    averageLatency: 1.8,
    errorCount: 0,
    errors: [],
    transcriptChunks: 28,
    notes: 'Clean run with low intervention rate',
    events: [
      { eventId: 'evt_101', type: 'prompt', message: 'Initial prompt', latency: 1.5, timestamp: '2026-02-09T10:00:10Z' },
      { eventId: 'evt_102', type: 'intervention', message: 'Minor coherence adjustment', timestamp: '2026-02-09T10:08:30Z' },
    ],
    transcript: [
      'Speaker A: Research methodology discussion',
      'Speaker B: Methodology overview',
    ],
    config: {
      model: 'gpt-4',
      contextWindow: 8192,
      temperature: 0.5,
      systemPrompt: 'You are a research assistant...',
    },
  },
  {
    sessionId: 'sess_003_20260208',
    startTime: '2026-02-08T16:45:00Z',
    endTime: '2026-02-08T17:30:00Z',
    duration: { minutes: 45, seconds: 0 },
    interventions: 12,
    prompts: 20,
    averageLatency: 3.2,
    errorCount: 2,
    errors: ['Deepgram transcription error', 'LLM rate limit'],
    transcriptChunks: 55,
    notes: 'High intervention rate - debugging needed',
    events: [],
    transcript: [],
    config: {
      model: 'gpt-3.5-turbo',
      contextWindow: 4096,
      temperature: 0.8,
    },
  },
];

/**
 * Get all sessions as list items
 */
export function getAllSessions(): SessionListItem[] {
  return mockSessions.map(session => ({
    sessionId: session.sessionId,
    startTime: session.startTime,
    endTime: session.endTime,
    duration: session.duration,
    interventions: session.interventions,
    prompts: session.prompts,
    averageLatency: session.averageLatency,
    errorCount: session.errorCount,
    transcriptChunks: session.transcriptChunks,
    notes: session.notes,
  }));
}

/**
 * Get a single session by ID
 */
export function getSessionById(sessionId: string): SessionDetail | null {
  return mockSessions.find(s => s.sessionId === sessionId) || null;
}

/**
 * Get the most recent session
 */
export function getMostRecentSession(): SessionDetail | null {
  if (mockSessions.length === 0) return null;
  return mockSessions[0];
}

/**
 * Get aggregate statistics across all sessions
 */
export function getAggregateStats(): AggregateStats {
  const sessions = mockSessions;
  const totalSessions = sessions.length;

  if (totalSessions === 0) {
    return {
      totalSessions: 0,
      averageInterventions: 0,
      averageLatency: 0,
      percentageWithErrors: 0,
    };
  }

  const totalInterventions = sessions.reduce((sum, s) => sum + s.interventions, 0);
  const totalLatency = sessions.reduce((sum, s) => sum + (s.averageLatency || 0), 0);
  const sessionsWithErrors = sessions.filter(s => s.errorCount > 0).length;

  return {
    totalSessions,
    averageInterventions: Math.round((totalInterventions / totalSessions) * 10) / 10,
    averageLatency: Math.round((totalLatency / totalSessions) * 100) / 100,
    percentageWithErrors: Math.round((sessionsWithErrors / totalSessions) * 100),
  };
}
