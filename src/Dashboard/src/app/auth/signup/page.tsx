'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

export default function SignUpPage() {
  const router = useRouter();

  useEffect(() => {
    // Redirect to login - all authentication now goes through Google
    router.push('/auth/login');
  }, [router]);

  return null;
}

