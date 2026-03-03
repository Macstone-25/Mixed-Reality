import { getSessionById } from '@/lib/mockData';
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
