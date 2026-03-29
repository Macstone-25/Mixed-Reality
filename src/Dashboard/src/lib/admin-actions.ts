'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';

export interface AdminActionResult {
  success: boolean;
  error?: {
    message: string;
    code?: string;
  };
}

/**
 * Approve a pending user
 */
export async function approveUser(userId: string): Promise<AdminActionResult> {
  const supabase = await createClient();

  try {
    // First verify requesting user is admin
    const {
      data: { user: currentUser },
    } = await supabase.auth.getUser();
    if (!currentUser) {
      return {
        success: false,
        error: { message: 'Not authenticated' },
      };
    }

    const { data: currentProfile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', currentUser.id)
      .single();

    if (currentProfile?.role !== 'admin') {
      return {
        success: false,
        error: { message: 'Not authorized' },
      };
    }

    // Update the target user's approval status
    const { error } = await supabase
      .from('profiles')
      .update({
        approval_status: 'approved',
        approved_by: currentUser.id,
        approved_at: new Date().toISOString(),
      })
      .eq('id', userId);

    if (error) {
      console.error('Approve user error:', error);
      return {
        success: false,
        error: { message: 'Failed to approve user' },
      };
    }

    // Revalidate paths that this user might access now that they're approved
    revalidatePath('/', 'layout');
    revalidatePath('/auth/pending-approval');

    return { success: true };
  } catch (error) {
    console.error('Approve user error:', error);
    return {
      success: false,
      error: { message: error instanceof Error ? error.message : 'An error occurred' },
    };
  }
}

/**
 * Reject a pending user
 */
export async function rejectUser(
  userId: string,
  reason: string
): Promise<AdminActionResult> {
  const supabase = await createClient();

  try {
    // First verify requesting user is admin
    const {
      data: { user: currentUser },
    } = await supabase.auth.getUser();
    if (!currentUser) {
      return {
        success: false,
        error: { message: 'Not authenticated' },
      };
    }

    const { data: currentProfile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', currentUser.id)
      .single();

    if (currentProfile?.role !== 'admin') {
      return {
        success: false,
        error: { message: 'Not authorized' },
      };
    }

    // Update the target user's approval status
    const { error } = await supabase
      .from('profiles')
      .update({
        approval_status: 'rejected',
        rejection_reason: reason,
        rejected_at: new Date().toISOString(),
      })
      .eq('id', userId);

    if (error) {
      console.error('Reject user error:', error);
      return {
        success: false,
        error: { message: 'Failed to reject user' },
      };
    }

    // Revalidate paths that this user might be accessing
    revalidatePath('/', 'layout');
    revalidatePath('/auth/pending-approval');

    return { success: true };
  } catch (error) {
    console.error('Reject user error:', error);
    return {
      success: false,
      error: { message: error instanceof Error ? error.message : 'An error occurred' },
    };
  }
}

/**
 * Get all pending users
 */
export async function getPendingUsers() {
  const supabase = await createClient();

  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('id, first_name, last_name, email, created_at, approval_status')
      .eq('approval_status', 'pending')
      .order('created_at', { ascending: true });

    if (error) {
      console.error('Get pending users error:', error);
      return { success: false, data: [] };
    }

    // Join with auth.users to get email
    const users = data?.map((profile: any) => ({
      id: profile.id,
      name: `${profile.first_name} ${profile.last_name}`,
      createdAt: profile.created_at,
      status: profile.approval_status,
    })) || [];

    return { success: true, data: users };
  } catch (error) {
    console.error('Get pending users error:', error);
    return { success: false, data: [] };
  }
}

/**
 * Get all users
 */
export async function getAllUsers(page: number = 1, limit: number = 10) {
  const supabase = await createClient();

  try {
    const offset = (page - 1) * limit;

    const { data, error, count } = await supabase
      .from('profiles')
      .select('id, first_name, last_name, email, role, approval_status, created_at', {
        count: 'exact',
      })
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      console.error('Get all users error:', error);
      return { success: false, data: [], total: 0 };
    }

    const users = data?.map((profile: any) => ({
      id: profile.id,
      name: `${profile.first_name} ${profile.last_name}`,
      email: profile.email,
      role: profile.role,
      status: profile.approval_status,
      createdAt: profile.created_at,
    })) || [];

    return { success: true, data: users, total: count || 0 };
  } catch (error) {
    console.error('Get all users error:', error);
    return { success: false, data: [], total: 0 };
  }
}

/**
 * Promote a user to admin
 */
export async function promoteUser(userId: string): Promise<AdminActionResult> {
  const supabase = await createClient();

  try {
    // First verify requesting user is admin
    const {
      data: { user: currentUser },
    } = await supabase.auth.getUser();
    if (!currentUser) {
      return {
        success: false,
        error: { message: 'Not authenticated' },
      };
    }

    const { data: currentProfile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', currentUser.id)
      .single();

    if (currentProfile?.role !== 'admin') {
      return {
        success: false,
        error: { message: 'Not authorized' },
      };
    }

    // Prevent promoting the same user
    if (currentUser.id === userId) {
      return {
        success: false,
        error: { message: 'Cannot promote yourself' },
      };
    }

    // Update the target user's role
    const { error } = await supabase
      .from('profiles')
      .update({
        role: 'admin',
        promoted_by: currentUser.id,
        promoted_at: new Date().toISOString(),
      })
      .eq('id', userId);

    if (error) {
      console.error('Promote user error:', error);
      return {
        success: false,
        error: { message: 'Failed to promote user' },
      };
    }

    // Revalidate paths
    revalidatePath('/', 'layout');
    revalidatePath('/admin/users');

    return { success: true };
  } catch (error) {
    console.error('Promote user error:', error);
    return {
      success: false,
      error: { message: error instanceof Error ? error.message : 'An error occurred' },
    };
  }
}

/**
 * Demote a user from admin to user
 */
export async function demoteUser(userId: string): Promise<AdminActionResult> {
  const supabase = await createClient();

  try {
    // First verify requesting user is admin
    const {
      data: { user: currentUser },
    } = await supabase.auth.getUser();
    if (!currentUser) {
      return {
        success: false,
        error: { message: 'Not authenticated' },
      };
    }

    const { data: currentProfile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', currentUser.id)
      .single();

    if (currentProfile?.role !== 'admin') {
      return {
        success: false,
        error: { message: 'Not authorized' },
      };
    }

    // Prevent demoting the same user
    if (currentUser.id === userId) {
      return {
        success: false,
        error: { message: 'Cannot demote yourself' },
      };
    }

    // Update the target user's role
    const { error } = await supabase
      .from('profiles')
      .update({
        role: 'user',
        demoted_by: currentUser.id,
        demoted_at: new Date().toISOString(),
      })
      .eq('id', userId);

    if (error) {
      console.error('Demote user error:', error);
      return {
        success: false,
        error: { message: 'Failed to demote user' },
      };
    }

    // Revalidate paths
    revalidatePath('/', 'layout');
    revalidatePath('/admin/users');

    return { success: true };
  } catch (error) {
    console.error('Demote user error:', error);
    return {
      success: false,
      error: { message: error instanceof Error ? error.message : 'An error occurred' },
    };
  }
}
