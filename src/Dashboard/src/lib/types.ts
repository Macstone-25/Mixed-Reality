/**
 * Core type definitions for the research dashboard
 */

export interface EventLog {
  eventId: string;
  type: 'intervention' | 'prompt';
  message: string;
  latency?: number;
  timestamp?: string;
  transcriptIndex?: number;
}

export interface SessionMetadata {
  sessionId: string;
  startTime: string;
  endTime?: string;
  duration?: {
    minutes: number;
    seconds: number;
  };
  interventions: number;
  prompts: number;
  averageLatency?: number;
  errorCount: number;
  errors?: string[];
  transcriptChunks?: number;
  notes?: string;
}

export interface SessionDetail extends SessionMetadata {
  events: EventLog[];
  transcript: string[];
  config: ExperimentConfig;
}

export interface ExperimentConfig {
  model?: string;
  contextWindow?: number;
  temperature?: number;
  systemPrompt?: string;
  triggerThresholds?: Record<string, number | string>;
  [key: string]: unknown;
}

export interface SessionListItem extends SessionMetadata {
  // For list views, include summary data only
}

export interface AggregateStats {
  totalSessions: number;
  averageInterventions: number;
  averageLatency: number;
  percentageWithErrors: number;
}
