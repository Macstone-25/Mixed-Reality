import { getMostRecentSession, getAllSessions, getAggregateStats } from '@/lib/db';
import { formatTimeOnly, formatDateTimeFull } from '@/lib/dateUtils';
import HomePageClient from './page-client';

export default async function Home() {
  const mostRecentSession = await getMostRecentSession();
  const allSessions = await getAllSessions();
  const stats = await getAggregateStats();
  const recentSessions = allSessions.slice(0, 10);

  // Calculate coherence percentage safely
  const calculateCoherence = (interventions: number, transcriptChunks?: number) => {
    if (!transcriptChunks || transcriptChunks === 0) {
      return null; // No data available
    }
    return Math.max(0, Math.min(100, 100 - ((interventions / transcriptChunks) * 100)));
  };

  const coherence = mostRecentSession ? calculateCoherence(mostRecentSession.interventions, mostRecentSession.transcriptChunks) : null;

  return (
    <HomePageClient
      mostRecentSession={mostRecentSession}
      recentSessions={recentSessions}
      stats={stats}
      coherence={coherence}
    />
  );
}
