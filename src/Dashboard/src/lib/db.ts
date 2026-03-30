'use server';

import { createClient as createServerSideClient } from './supabase/server';
import type { SessionDetail, SessionListItem, AggregateStats, EventLog } from './types';

/**
 * Database layer for querying Supabase
 * Replaces mockData.ts
 */

/**
 * Get all sessions as list items
 */
export async function getAllSessions(): Promise<SessionListItem[]> {
  const supabase = await createServerSideClient();

  const { data: sessions, error } = await supabase
    .from('sessions')
    .select('id, session_id, created_at, ended_at, artifact_folder_path')
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Error fetching sessions:', error);
    return [];
  }

  if (!sessions) return [];

  // Get event counts for each session
  const sessionsWithCounts = await Promise.all(
    sessions.map(async (session) => {
      const { count: eventCount } = await supabase
        .from('events')
        .select('*', { count: 'exact', head: true })
        .eq('session_id', session.id);

      const { count: promptCount } = await supabase
        .from('events')
        .select('*', { count: 'exact', head: true })
        .eq('session_id', session.id)
        .eq('event_type', 'prompt');

      const { count: interventionCount } = await supabase
        .from('events')
        .select('*', { count: 'exact', head: true })
        .eq('session_id', session.id)
        .eq('event_type', 'intervention');

      const { data: transcriptChunks } = await supabase
        .from('transcript_chunks')
        .select('*', { count: 'exact', head: true })
        .eq('session_id', session.id);

      const { data: events } = await supabase
        .from('events')
        .select('*')
        .eq('session_id', session.id)
        .order('timestamp', { ascending: true });

      // Calculate average latency from events (assuming latency is in message)
      let averageLatency = 0;
      let errorCount = 0;
      if (events) {
        const eventsWithLatency = events.filter(e => e.message?.includes('latency'));
        if (eventsWithLatency.length > 0) {
          const totalLatency = eventsWithLatency.reduce((sum, e) => {
            const match = e.message?.match(/latency[:\s]+(\d+\.?\d*)/i);
            return sum + (match ? parseFloat(match[1]) : 0);
          }, 0);
          averageLatency = totalLatency / eventsWithLatency.length;
        }
        errorCount = events.filter(e => e.severity === 'ERROR').length;
      }

      const startTime = session.created_at;
      const endTime = session.ended_at;
      const durationMs = endTime
        ? new Date(endTime).getTime() - new Date(startTime).getTime()
        : null;
      const durationMinutes = durationMs ? Math.floor(durationMs / 60000) : 0;
      const durationSeconds = durationMs ? Math.floor((durationMs % 60000) / 1000) : 0;

      return {
        sessionId: session.session_id,
        startTime: startTime,
        endTime: endTime || undefined,
        duration: durationMinutes > 0 || durationSeconds > 0 ? { minutes: durationMinutes, seconds: durationSeconds } : undefined,
        interventions: interventionCount || 0,
        prompts: promptCount || 0,
        averageLatency,
        errorCount,
        transcriptChunks: transcriptChunks?.length || 0,
        notes: session.artifact_folder_path || undefined,
      };
    })
  );

  return sessionsWithCounts;
}

/**
 * Get a single session by ID with all related data
 */
export async function getSessionById(sessionId: string): Promise<SessionDetail | null> {
  const supabase = await createServerSideClient();

  // Get session
  const { data: session, error: sessionError } = await supabase
    .from('sessions')
    .select('*')
    .eq('session_id', sessionId)
    .single();

  if (sessionError || !session) {
    console.error('Error fetching session:', sessionError);
    return null;
  }

  // Get events
  const { data: events, error: eventsError } = await supabase
    .from('events')
    .select('*')
    .eq('session_id', session.id)
    .order('timestamp', { ascending: true });

  if (eventsError) {
    console.error('Error fetching events:', eventsError);
  }

  // Get transcript chunks
  const { data: transcriptChunks, error: transcriptError } = await supabase
    .from('transcript_chunks')
    .select('*')
    .eq('session_id', session.id)
    .order('start_time_seconds', { ascending: true });

  if (transcriptError) {
    console.error('Error fetching transcript:', transcriptError);
  }

  // Get experiment config
  const { data: experiment, error: experimentError } = await supabase
    .from('experiments')
    .select('*')
    .eq('session_id', session.id)
    .single();

  if (experimentError && experimentError.code !== 'PGRST116') {
    console.error('Error fetching experiment:', experimentError);
  }

  // Transform events
  const eventLogs: EventLog[] = (events || []).map((event) => ({
    eventId: event.id,
    type: event.event_type.toLowerCase() as 'intervention' | 'prompt',
    message: event.message || '',
    timestamp: event.timestamp,
  }));

  // Transform transcript: concatenate chunks into string array
  const transcript: string[] = (transcriptChunks || []).map(chunk => chunk.text || '');

  // Calculate metrics
  const startTime = session.created_at;
  const endTime = session.ended_at;
  const durationMs = endTime
    ? new Date(endTime).getTime() - new Date(startTime).getTime()
    : null;
  const durationMinutes = durationMs ? Math.floor(durationMs / 60000) : 0;
  const durationSeconds = durationMs ? Math.floor((durationMs % 60000) / 1000) : 0;

  const interventionCount = eventLogs.filter(e => e.type === 'intervention').length;
  const promptCount = eventLogs.filter(e => e.type === 'prompt').length;
  const errorCount = (events || []).filter(e => e.severity === 'ERROR').length;

  let averageLatency = 0;
  const eventsWithLatency = (events || []).filter(e => e.message?.includes('latency'));
  if (eventsWithLatency.length > 0) {
    const totalLatency = eventsWithLatency.reduce((sum, e) => {
      const match = e.message?.match(/latency[:\s]+(\d+\.?\d*)/i);
      return sum + (match ? parseFloat(match[1]) : 0);
    }, 0);
    averageLatency = totalLatency / eventsWithLatency.length;
  }

  const errors = (events || [])
    .filter(e => e.severity === 'ERROR')
    .map(e => e.message || '')
    .filter(msg => msg.length > 0);

  return {
    sessionId: session.session_id,
    startTime,
    endTime: endTime || undefined,
    duration: durationMinutes > 0 || durationSeconds > 0 ? { minutes: durationMinutes, seconds: durationSeconds } : undefined,
    interventions: interventionCount,
    prompts: promptCount,
    averageLatency,
    errorCount,
    errors,
    transcriptChunks: transcript.length,
    notes: session.artifact_folder_path || undefined,
    events: eventLogs,
    transcript,
    config: experiment?.config_json || {},
  };
}

/**
 * Get the most recent session
 */
export async function getMostRecentSession(): Promise<SessionDetail | null> {
  const supabase = await createServerSideClient();

  const { data: session, error } = await supabase
    .from('sessions')
    .select('session_id')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error || !session) {
    if (error) {
      console.error('Error fetching most recent session:', error);
    }
    return null;
  }

  return getSessionById(session.session_id);
}

/**
 * Get aggregate statistics across all sessions
 */
export async function getAggregateStats(): Promise<AggregateStats> {
  const supabase = await createServerSideClient();

  // Count total sessions
  const { count: totalSessions } = await supabase
    .from('sessions')
    .select('*', { count: 'exact', head: true });

  // Count total events
  const { count: totalEvents } = await supabase
    .from('events')
    .select('*', { count: 'exact', head: true });

  // Get all sessions to calculate averages
  const { data: sessions } = await supabase
    .from('sessions')
    .select('id, created_at, ended_at');

  // Get intervention events
  const { data: interventions } = await supabase
    .from('events')
    .select('session_id')
    .eq('event_type', 'intervention');

  const interventionCounts = interventions?.reduce((acc, evt) => {
    acc[evt.session_id] = (acc[evt.session_id] || 0) + 1;
    return acc;
  }, {} as Record<string, number>) || {};

  // Calculate averages
  const totalInterventions = Object.values(interventionCounts).reduce((a, b) => a + b, 0);
  const averageInterventions =
    (totalSessions || 0) > 0 ? Math.round((totalInterventions / (totalSessions || 1)) * 10) / 10 : 0;

  // Calculate average duration and latency
  let totalDuration = 0;
  let validSessions = 0;
  if (sessions) {
    sessions.forEach(s => {
      if (s.ended_at) {
        totalDuration += new Date(s.ended_at).getTime() - new Date(s.created_at).getTime();
        validSessions += 1;
      }
    });
  }
  const averageDuration = validSessions > 0 ? Math.round((totalDuration / validSessions / 1000) * 100) / 100 : 0;

  // Get events with errors
  const { data: errorEvents } = await supabase
    .from('events')
    .select('session_id')
    .eq('severity', 'ERROR');

  const sessionsWithErrors = new Set(errorEvents?.map(e => e.session_id) || []);
  const percentageWithErrors =
    (totalSessions || 0) > 0 ? Math.round(((sessionsWithErrors.size / (totalSessions || 1)) * 100)) : 0;

  return {
    totalSessions: totalSessions || 0,
    averageInterventions,
    averageLatency: averageDuration,
    percentageWithErrors,
  };
}
