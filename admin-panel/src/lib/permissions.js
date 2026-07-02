export const ROLES = {
  ADMIN: 'admin',
  MODERATOR: 'moderator',
}

export const STAFF_ROLES = [ROLES.ADMIN, ROLES.MODERATOR]

export function isAdmin(role) {
  return role === ROLES.ADMIN
}

export function isModerator(role) {
  return role === ROLES.MODERATOR
}

export function isStaff(role) {
  return STAFF_ROLES.includes(role)
}

/** Routes moderators can access */
export const MODERATOR_PATHS = [
  '/dashboard',
  '/owner-requests',
  '/workspace-requests',
  '/users',
  '/bookings',
  '/payment-verification',
  '/wallet-refunds',
  '/owner-payouts',
  '/reports',
  '/payments',
  '/notifications',
]

/** Admin-only routes */
export const ADMIN_ONLY_PATHS = [
  '/moderators',
  '/moderator-activity',
  '/platform-accounts',
  '/workspaces',
  '/reviews',
  '/collaborations',
  '/chat-monitoring',
  '/owner-revenue',
]

export function canAccessPath(role, path) {
  if (!isStaff(role)) return false
  if (isAdmin(role)) return true
  return MODERATOR_PATHS.includes(path)
}

export function getMenuItems(role) {
  const all = [
    { path: '/dashboard', label: 'Dashboard', icon: 'LayoutDashboard', roles: STAFF_ROLES },
    { path: '/owner-requests', label: 'Owner Requests', icon: 'UserCheck', roles: STAFF_ROLES, badge: 'owners' },
    { path: '/workspace-requests', label: 'Workspace Requests', icon: 'FileCheck', roles: STAFF_ROLES, badge: 'workspaces' },
    { path: '/payment-verification', label: 'Payment Verification', icon: 'ClipboardCheck', roles: STAFF_ROLES, badge: 'payments' },
    { path: '/wallet-refunds', label: 'Wallet & Refunds', icon: 'Wallet', roles: STAFF_ROLES, badge: 'refunds' },
    { path: '/owner-payouts', label: 'Owner Payouts', icon: 'Banknote', roles: STAFF_ROLES, badge: 'payouts' },
    { path: '/reports', label: 'User Reports', icon: 'Flag', roles: STAFF_ROLES, badge: 'reports' },
    { path: '/users', label: 'Users', icon: 'Users', roles: STAFF_ROLES },
    { path: '/bookings', label: 'Bookings', icon: 'Calendar', roles: STAFF_ROLES },
    { path: '/payments', label: 'All Payments', icon: 'CreditCard', roles: STAFF_ROLES },
    { path: '/notifications', label: 'Notifications', icon: 'Bell', roles: STAFF_ROLES },
    { path: '/moderators', label: 'Moderators', icon: 'Shield', roles: [ROLES.ADMIN] },
    { path: '/moderator-activity', label: 'Activity History', icon: 'History', roles: [ROLES.ADMIN] },
    { path: '/platform-accounts', label: 'Platform Accounts', icon: 'Landmark', roles: [ROLES.ADMIN] },
    { path: '/workspaces', label: 'All Workspaces', icon: 'Building2', roles: [ROLES.ADMIN] },
    { path: '/reviews', label: 'Reviews', icon: 'Star', roles: [ROLES.ADMIN] },
    { path: '/collaborations', label: 'Collaborations', icon: 'UsersIcon', roles: [ROLES.ADMIN] },
    { path: '/chat-monitoring', label: 'Chat Monitoring', icon: 'MessageSquare', roles: [ROLES.ADMIN] },
    { path: '/owner-revenue', label: 'Owner Revenue', icon: 'DollarSign', roles: [ROLES.ADMIN] },
  ]

  return all.filter((item) => item.roles.includes(role))
}
