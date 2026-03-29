import { getSessionById } from '@/lib/db';
import SessionDetailPageClient from '@/components/SessionDetailPageClient';

interface Props {
  params: Promise<{
    id: string;
  }>;
}

export default async function SessionDetailPage({ params }: Props) {
  const { id } = await params;
  const session = await getSessionById(id);

  return (
    <SessionDetailPageClient sessionId={id} session={session} />
  );
}
