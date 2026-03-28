'use server';

import { getAllSessions } from '@/lib/db';
import SessionsPageClient from './page-client';

export default async function SessionsPage() {
  const allSessions = await getAllSessions();


  return <SessionsPageClient allSessions={allSessions} />;
}
