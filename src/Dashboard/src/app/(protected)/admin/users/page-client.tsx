'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { CheckCircle2, XCircle, AlertCircle, Loader2, RefreshCw, ChevronLeft, ChevronRight, Menu, Shield, ShieldOff, MoreVertical } from 'lucide-react';
import { useAuth } from '@/lib/auth-context';
import { approveUser, rejectUser, getPendingUsers, getAllUsers, promoteUser, demoteUser } from '@/lib/admin-actions';
import { Sidenav } from '@/components/Sidenav';

interface User {
  id: string;
  name: string;
  email?: string;
  role?: string;
  status: string;
  createdAt: string;
}

export default function AdminUsersPageClient() {
  const router = useRouter();
  const { user, profile, isAdmin, loading: authLoading } = useAuth();

  const [activeTab, setActiveTab] = useState<'pending' | 'all'>('pending');
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionInProgress, setActionInProgress] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [sidenavOpen, setSidenavOpen] = useState(false);
  const [openMenuUserId, setOpenMenuUserId] = useState<string | null>(null);

  // Pagination
  const [currentPage, setCurrentPage] = useState(1);
  const [totalUsers, setTotalUsers] = useState(0);
  const itemsPerPage = 10;

  // Redirect if not admin
  useEffect(() => {
    if (!authLoading && (!user || !isAdmin)) {
      router.push('/');
    }
  }, [user, isAdmin, authLoading, router]);

  // Load users
  useEffect(() => {
    if (authLoading || !isAdmin) return;

    const loadUsers = async () => {
      setLoading(true);
      setError(null);

      try {
        if (activeTab === 'pending') {
          const result = await getPendingUsers();
          if (result.success) {
            setUsers(result.data);
            setTotalUsers(result.data.length);
          } else {
            setError('Failed to load pending users');
          }
        } else {
          const result = await getAllUsers(currentPage, itemsPerPage);
          if (result.success) {
            setUsers(result.data);
            setTotalUsers(result.total);
          } else {
            setError('Failed to load users');
          }
        }
      } catch (err) {
        console.error('Error loading users:', err);
        setError('An error occurred while loading users');
      } finally {
        setLoading(false);
      }
    };

    loadUsers();
  }, [activeTab, currentPage, authLoading, isAdmin]);

  // Close menu when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      if (!target.closest('button') && !target.closest('[role="menu"]')) {
        setOpenMenuUserId(null);
      }
    };

    document.addEventListener('click', handleClickOutside);
    return () => document.removeEventListener('click', handleClickOutside);
  }, []);

  const handleApprove = async (userId: string) => {
    setActionInProgress(userId);
    try {
      const result = await approveUser(userId);
      if (result.success) {
        setSuccessMessage('User approved successfully');
        // Reload users
        const reloadResult = await getPendingUsers();
        if (reloadResult.success) {
          setUsers(reloadResult.data);
        }
        setTimeout(() => setSuccessMessage(null), 3000);
      } else {
        setError(result.error?.message || 'Failed to approve user');
      }
    } catch (err) {
      console.error('Error approving user:', err);
      setError('An error occurred while approving user');
    } finally {
      setActionInProgress(null);
    }
  };

  const handleReject = async (userId: string) => {
    const reason = prompt('Enter rejection reason (optional):');
    if (reason === null) return; // User cancelled

    setActionInProgress(userId);
    try {
      const result = await rejectUser(userId, reason);
      if (result.success) {
        setSuccessMessage('User rejected successfully');
        // Reload users
        const reloadResult = await getPendingUsers();
        if (reloadResult.success) {
          setUsers(reloadResult.data);
        }
        setTimeout(() => setSuccessMessage(null), 3000);
      } else {
        setError(result.error?.message || 'Failed to reject user');
      }
    } catch (err) {
      console.error('Error rejecting user:', err);
      setError('An error occurred while rejecting user');
    } finally {
      setActionInProgress(null);
    }
  };

  const handlePromote = async (userId: string) => {
    setActionInProgress(userId);
    setOpenMenuUserId(null);
    try {
      const result = await promoteUser(userId);
      if (result.success) {
        setSuccessMessage('User promoted to admin successfully');
        // Reload users
        const reloadResult = await getAllUsers(currentPage, itemsPerPage);
        if (reloadResult.success) {
          setUsers(reloadResult.data);
          setTotalUsers(reloadResult.total);
        }
        setTimeout(() => setSuccessMessage(null), 3000);
      } else {
        setError(result.error?.message || 'Failed to promote user');
      }
    } catch (err) {
      console.error('Error promoting user:', err);
      setError('An error occurred while promoting user');
    } finally {
      setActionInProgress(null);
    }
  };

  const handleDemote = async (userId: string) => {
    const confirm = window.confirm('Are you sure you want to demote this admin user to regular user?');
    if (!confirm) return;

    setActionInProgress(userId);
    setOpenMenuUserId(null);
    try {
      const result = await demoteUser(userId);
      if (result.success) {
        setSuccessMessage('User demoted to regular user successfully');
        // Reload users
        const reloadResult = await getAllUsers(currentPage, itemsPerPage);
        if (reloadResult.success) {
          setUsers(reloadResult.data);
          setTotalUsers(reloadResult.total);
        }
        setTimeout(() => setSuccessMessage(null), 3000);
      } else {
        setError(result.error?.message || 'Failed to demote user');
      }
    } catch (err) {
      console.error('Error demoting user:', err);
      setError('An error occurred while demoting user');
    } finally {
      setActionInProgress(null);
    }
  };

  const handleRefresh = async () => {
    setLoading(true);
    try {
      if (activeTab === 'pending') {
        const result = await getPendingUsers();
        if (result.success) {
          setUsers(result.data);
          setTotalUsers(result.data.length);
        }
      } else {
        const result = await getAllUsers(currentPage, itemsPerPage);
        if (result.success) {
          setUsers(result.data);
          setTotalUsers(result.total);
        }
      }
    } catch (err) {
      console.error('Error refreshing:', err);
    } finally {
      setLoading(false);
    }
  };

  const toggleSidenav = () => {
    setSidenavOpen(!sidenavOpen);
  };

  if (authLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#EDE0D4]">
        <div className="text-center">
          <Loader2 className="w-8 h-8 animate-spin mx-auto mb-4" style={{ color: '#7F5539' }} />
          <p style={{ color: '#2D2D2D' }}>Loading...</p>
        </div>
      </div>
    );
  }

  if (!user || !isAdmin) {
    return null;
  }

  const totalPages = Math.ceil(totalUsers / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage + 1;
  const endIndex = Math.min(currentPage * itemsPerPage, totalUsers);

  return (
    <div className="flex min-h-screen" style={{ backgroundColor: '#7F5539' }}>
      <Sidenav isOpen={sidenavOpen} onToggle={toggleSidenav} />

      <div className={`flex-1 transition-all duration-300 box-border ${sidenavOpen ? 'ml-64' : ''}`}>
        <div
          className={`min-h-screen w-full py-6 sm:py-8 px-4 sm:px-8 md:px-12 lg:px-16 ${sidenavOpen ? 'rounded-l-xl' : ''}`}
          style={{ backgroundColor: '#EDE0D4' }}
        >
          {/* Header with toggle button */}
          <div className="flex items-center gap-3 sm:gap-4 mb-8 sm:mb-10">
            <button
              onClick={toggleSidenav}
              className="p-2 rounded-lg transition-colors flex-shrink-0"
              style={{ color: '#2D2D2D', backgroundColor: 'rgba(45, 45, 45, 0.08)' }}
              onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'rgba(45, 45, 45, 0.15)')}
              onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'rgba(45, 45, 45, 0.08)')}
              aria-label="Open navigation"
            >
              <Menu size={24} />
            </button>
            <h1 className="text-2xl sm:text-3xl font-bold" style={{ color: '#2D2D2D' }}>
              User Management
            </h1>
          </div>

          <div className="max-w-6xl">
            {/* Subheader */}
            <p style={{ color: '#7F5539' }} className="mb-6">
              Manage and approve user accounts
            </p>

            {/* Messages */}
            {error && (
              <div
                className="mb-4 p-4 rounded-lg flex items-center gap-3"
                style={{ backgroundColor: '#FFE5E5', color: '#D32F2F' }}
              >
                <AlertCircle className="w-5 h-5 flex-shrink-0" />
                <span>{error}</span>
              </div>
            )}

            {successMessage && (
              <div
                className="mb-4 p-4 rounded-lg flex items-center gap-3"
                style={{ backgroundColor: '#E8F5E9', color: '#2E7D32' }}
              >
                <CheckCircle2 className="w-5 h-5 flex-shrink-0" />
                <span>{successMessage}</span>
              </div>
            )}

            {/* Tabs and Refresh */}
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
              <div className="flex gap-2">
                <button
                  onClick={() => {
                    setActiveTab('pending');
                    setCurrentPage(1);
                  }}
                  className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                    activeTab === 'pending'
                      ? 'text-white'
                      : 'bg-white text-[#2D2D2D]'
                  }`}
                  style={{
                    backgroundColor: activeTab === 'pending' ? '#7F5539' : '#FFFFFF',
                  }}
                >
                  Pending ({users.filter((u) => u.status === 'pending').length})
                </button>
                <button
                  onClick={() => {
                    setActiveTab('all');
                    setCurrentPage(1);
                  }}
                  className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                    activeTab === 'all' ? 'text-white' : 'bg-white text-[#2D2D2D]'
                  }`}
                  style={{
                    backgroundColor: activeTab === 'all' ? '#7F5539' : '#FFFFFF',
                  }}
                >
                  All Users
                </button>
              </div>

              <button
                onClick={handleRefresh}
                disabled={loading}
                className="px-4 py-2 rounded-lg bg-white font-medium transition-colors hover:opacity-80 disabled:opacity-50 flex items-center gap-2 justify-center sm:justify-start"
                style={{ color: '#7F5539' }}
              >
                <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
                Refresh
              </button>
            </div>

            {/* Users Table */}
            <div className="bg-white rounded-lg shadow-sm overflow-hidden">
              {loading && users.length === 0 ? (
                <div className="p-8 text-center">
                  <Loader2 className="w-6 h-6 animate-spin mx-auto mb-2" style={{ color: '#7F5539' }} />
                  <p style={{ color: '#2D2D2D' }}>Loading users...</p>
                </div>
              ) : users.length === 0 ? (
                <div className="p-8 text-center" style={{ color: '#7F5539' }}>
                  <p>No users found in this category</p>
                </div>
              ) : (
                <>
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead style={{ backgroundColor: '#F5F5F5' }}>
                        <tr>
                          <th className="px-6 py-3 text-left text-sm font-semibold" style={{ color: '#2D2D2D' }}>
                            Name
                          </th>
                          {activeTab === 'all' && (
                            <th className="px-6 py-3 text-left text-sm font-semibold" style={{ color: '#2D2D2D' }}>
                              Email
                            </th>
                          )}
                          {activeTab === 'all' && (
                            <th className="px-6 py-3 text-left text-sm font-semibold" style={{ color: '#2D2D2D' }}>
                              Role
                            </th>
                          )}
                          <th className="px-6 py-3 text-left text-sm font-semibold" style={{ color: '#2D2D2D' }}>
                            Status
                          </th>
                          <th className="px-6 py-3 text-left text-sm font-semibold" style={{ color: '#2D2D2D' }}>
                            Created
                          </th>
                          <th className="px-6 py-3 text-right text-sm font-semibold" style={{ color: '#2D2D2D' }}>
                            Actions
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        {users.map((user, index) => (
                          <tr
                            key={user.id}
                            style={{
                              backgroundColor: index % 2 === 0 ? '#FFFFFF' : '#FAFAFA',
                              borderBottom: '1px solid #E0E0E0',
                            }}
                          >
                            <td className="px-6 py-4 text-sm" style={{ color: '#2D2D2D' }}>
                              {user.name}
                            </td>
                            {activeTab === 'all' && (
                              <td className="px-6 py-4 text-sm" style={{ color: '#7F5539' }}>
                                {user.email}
                              </td>
                            )}
                            {activeTab === 'all' && (
                              <td className="px-6 py-4 text-sm" style={{ color: '#2D2D2D' }}>
                                <span
                                  className="px-2 py-1 rounded text-xs font-medium"
                                  style={{
                                    backgroundColor: user.role === 'admin' ? '#FFF3CD' : '#E3F2FD',
                                    color: user.role === 'admin' ? '#856404' : '#1565C0',
                                  }}
                                >
                                  {user.role}
                                </span>
                              </td>
                            )}
                            <td className="px-6 py-4 text-sm">
                              <span
                                className="px-2 py-1 rounded text-xs font-medium"
                                style={{
                                  backgroundColor:
                                    user.status === 'approved'
                                      ? '#E8F5E9'
                                      : user.status === 'pending'
                                        ? '#FFF9E6'
                                        : '#FFEBEE',
                                  color:
                                    user.status === 'approved'
                                      ? '#2E7D32'
                                      : user.status === 'pending'
                                        ? '#F57F17'
                                        : '#D32F2F',
                                }}
                              >
                                {user.status.charAt(0).toUpperCase() + user.status.slice(1)}
                              </span>
                            </td>
                            <td className="px-6 py-4 text-sm" style={{ color: '#7F5539' }}>
                              {new Date(user.createdAt).toLocaleDateString()}
                            </td>
                            <td className="px-6 py-4 text-sm text-right relative">
                              {activeTab === 'pending' ? (
                                <div className="flex gap-2 justify-end">
                                  <button
                                    onClick={() => handleApprove(user.id)}
                                    disabled={actionInProgress === user.id}
                                    className="px-3 py-1 rounded text-xs font-medium transition-opacity hover:opacity-80 disabled:opacity-50 flex items-center gap-1"
                                    style={{ backgroundColor: '#E8F5E9', color: '#2E7D32' }}
                                  >
                                    {actionInProgress === user.id ? (
                                      <Loader2 className="w-3 h-3 animate-spin" />
                                    ) : (
                                      <CheckCircle2 className="w-3 h-3" />
                                    )}
                                    Approve
                                  </button>
                                  <button
                                    onClick={() => handleReject(user.id)}
                                    disabled={actionInProgress === user.id}
                                    className="px-3 py-1 rounded text-xs font-medium transition-opacity hover:opacity-80 disabled:opacity-50 flex items-center gap-1"
                                    style={{ backgroundColor: '#FFEBEE', color: '#D32F2F' }}
                                  >
                                    {actionInProgress === user.id ? (
                                      <Loader2 className="w-3 h-3 animate-spin" />
                                    ) : (
                                      <XCircle className="w-3 h-3" />
                                    )}
                                    Reject
                                  </button>
                                </div>
                              ) : (
                                <div className="relative inline-block">
                                  <button
                                    onClick={() => setOpenMenuUserId(openMenuUserId === user.id ? null : user.id)}
                                    disabled={actionInProgress === user.id}
                                    className="p-1 rounded hover:bg-gray-100 disabled:opacity-50"
                                    title="User actions"
                                  >
                                    <MoreVertical className="w-4 h-4" style={{ color: '#7F5539' }} />
                                  </button>
                                  {openMenuUserId === user.id && (
                                    <div
                                      className="absolute right-0 mt-1 bg-white rounded-lg shadow-lg border z-10"
                                      style={{ borderColor: '#E0E0E0', minWidth: '160px' }}
                                    >
                                      {user.role === 'user' ? (
                                        <button
                                          onClick={() => handlePromote(user.id)}
                                          disabled={actionInProgress === user.id}
                                          className="w-full text-left px-4 py-2 text-sm hover:bg-gray-100 disabled:opacity-50 flex items-center gap-2 first:rounded-t-lg"
                                          style={{ color: '#7F5539' }}
                                        >
                                          {actionInProgress === user.id ? (
                                            <Loader2 className="w-3 h-3 animate-spin" />
                                          ) : (
                                            <Shield className="w-3 h-3" />
                                          )}
                                          Promote to Admin
                                        </button>
                                      ) : (
                                        <button
                                          onClick={() => handleDemote(user.id)}
                                          disabled={actionInProgress === user.id}
                                          className="w-full text-left px-4 py-2 text-sm hover:bg-gray-100 disabled:opacity-50 flex items-center gap-2 first:rounded-t-lg"
                                          style={{ color: '#D32F2F' }}
                                        >
                                          {actionInProgress === user.id ? (
                                            <Loader2 className="w-3 h-3 animate-spin" />
                                          ) : (
                                            <ShieldOff className="w-3 h-3" />
                                          )}
                                          Demote to User
                                        </button>
                                      )}
                                    </div>
                                  )}
                                </div>
                              )}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>

                  {/* Pagination */}
                  {activeTab === 'all' && totalPages > 1 && (
                    <div className="px-6 py-4 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 border-t border-gray-200">
                      <p style={{ color: '#7F5539' }} className="text-sm">
                        Showing {startIndex} to {endIndex} of {totalUsers} users
                      </p>
                      <div className="flex gap-2">
                        <button
                          onClick={() => setCurrentPage(Math.max(1, currentPage - 1))}
                          disabled={currentPage === 1}
                          className="p-2 rounded border transition-colors disabled:opacity-50 hover:bg-gray-100"
                          style={{ borderColor: '#7F5539' }}
                        >
                          <ChevronLeft className="w-4 h-4" style={{ color: '#7F5539' }} />
                        </button>
                        <span style={{ color: '#2D2D2D' }} className="px-3 py-2 text-sm">
                          Page {currentPage} of {totalPages}
                        </span>
                        <button
                          onClick={() => setCurrentPage(Math.min(totalPages, currentPage + 1))}
                          disabled={currentPage === totalPages}
                          className="p-2 rounded border transition-colors disabled:opacity-50 hover:bg-gray-100"
                          style={{ borderColor: '#7F5539' }}
                        >
                          <ChevronRight className="w-4 h-4" style={{ color: '#7F5539' }} />
                        </button>
                      </div>
                    </div>
                  )}
                </>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
