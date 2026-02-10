import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';
import { getSessionById } from '@/lib/mockData';
import { SessionSummary } from '@/components/SessionSummary';
import { TabsContent } from '@/components/SessionDetailTabs';
import SessionDetailPageClient from '@/components/SessionDetailPageClient';

interface Props {
  params: Promise<{
    id: string;
  }>;
}

export default async function SessionDetailPage({ params }: Props) {
  const { id } = await params;
  const session = getSessionById(id);

  return (
    <SessionDetailPageClient sessionId={id} session={session} />
  );
}
