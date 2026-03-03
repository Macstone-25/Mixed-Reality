import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';
import { getSessionById } from '@/lib/mockData';
import { ConfigPageClient } from './config-client';

interface Props {
  params: Promise<{
    id: string;
  }>;
}

export default async function ConfigPage({ params }: Props) {
  const { id } = await params;
  const session = getSessionById(id);

  if (!session) {
    return (
      <div
        className="flex min-h-screen w-full flex-col items-center justify-center px-16"
        style={{ backgroundColor: '#EDE0D4', color: '#2D2D2D' }}
      >
        <div className="text-center">
          <h1 className="text-4xl font-bold mb-4" style={{ color: '#2D2D2D' }}>
            Session Not Found
          </h1>
          <Link
            href="/sessions"
            className="inline-block px-6 py-3 rounded-lg font-medium transition-colors"
            style={{ backgroundColor: '#7F5539', color: '#F5F1ED' }}
          >
            Back to Sessions
          </Link>
        </div>
      </div>
    );
  }

  return (
    <ConfigPageClient session={session} />
  );
}
