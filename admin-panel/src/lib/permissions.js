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
  '/staff-inbox',
  '/owner-requests',
  '/workspace-requests',
  '/users',
  '/bookings',
  '/payment-verification',
  '/wallet-topup-verification',
  '/wallet-refunds',
  '/wallet-explorer',
  '/owner-payouts',
  '/reports',
  '/collaboration-hub',
  '/payments',
  '/notifications',
]

/** Admin-only routes */
export const ADMIN_ONLY_PATHS = [
  '/moderators',
  '/moderator-activity',
  '/platform-accounts',
  '/app-release',
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
    { path: '/dashboard', label: 'Dashboard', icon: 'LayoutDashboard', roles: STAFF_ROLES, section: 'overview' },
    { path: '/staff-inbox', label: 'Staff Inbox', icon: 'Inbox', roles: STAFF_ROLES, badge: 'inbox', section: 'overview' },
    { path: '/owner-requests', label: 'Owner Requests', icon: 'UserCheck', roles: STAFF_ROLES, badge: 'owners', section: 'operations' },
    { path: '/workspace-requests', label: 'Workspace Requests', icon: 'FileCheck', roles: STAFF_ROLES, badge: 'workspaces', section: 'operations' },
    { path: '/payment-verification', label: 'Payment Verification', icon: 'ClipboardCheck', roles: STAFF_ROLES, badge: 'payments', section: 'finance' },
    { path: '/wallet-topup-verification', label: 'Wallet Top-Ups', icon: 'Wallet', roles: STAFF_ROLES, badge: 'topups', section: 'finance' },
    { path: '/wallet-refunds', label: 'Wallet & Refunds', icon: 'Wallet', roles: STAFF_ROLES, badge: 'refunds', section: 'finance' },
    { path: '/wallet-explorer', label: 'Wallet Explorer', icon: 'Search', roles: STAFF_ROLES, section: 'finance' },
    { path: '/owner-payouts', label: 'Owner Payouts', icon: 'Banknote', roles: STAFF_ROLES, badge: 'payouts', section: 'finance' },
    { path: '/reports', label: 'User Reports', icon: 'Flag', roles: STAFF_ROLES, badge: 'reports', section: 'moderation' },
    { path: '/users', label: 'Users', icon: 'Users', roles: STAFF_ROLES, section: 'people' },
    { path: '/bookings', label: 'Bookings', icon: 'Calendar', roles: STAFF_ROLES, section: 'people' },
    { path: '/payments', label: 'All Payments', icon: 'CreditCard', roles: STAFF_ROLES, section: 'finance' },
    { path: '/notifications', label: 'Notifications', icon: 'Bell', roles: STAFF_ROLES, section: 'people' },
    { path: '/moderators', label: 'Moderators', icon: 'Shield', roles: [ROLES.ADMIN], section: 'admin' },
    { path: '/moderator-activity', label: 'Activity History', icon: 'History', roles: [ROLES.ADMIN], section: 'admin' },
    { path: '/platform-accounts', label: 'Platform Accounts', icon: 'Landmark', roles: [ROLES.ADMIN], section: 'admin' },
    { path: '/app-release', label: 'Android APK Release', icon: 'Smartphone', roles: [ROLES.ADMIN], section: 'admin' },
    { path: '/workspaces', label: 'All Workspaces', icon: 'Building2', roles: [ROLES.ADMIN], section: 'content' },
    { path: '/reviews', label: 'Reviews', icon: 'Star', roles: [ROLES.ADMIN], section: 'content' },
    { path: '/collaboration-hub', label: 'Collaboration Hub', icon: 'Briefcase', roles: STAFF_ROLES, badge: 'collabHeld', section: 'moderation' },
    { path: '/collaborations', label: 'Collaborations (legacy)', icon: 'UsersIcon', roles: [ROLES.ADMIN], section: 'content' },
    { path: '/chat-monitoring', label: 'Chat Monitoring', icon: 'MessageSquare', roles: [ROLES.ADMIN], section: 'moderation' },
    { path: '/owner-revenue', label: 'Platform Revenue', icon: 'DollarSign', roles: [ROLES.ADMIN], section: 'finance' },
  ]

  return all.filter((item) => item.roles.includes(role))
}

const SECTION_LABELS = {
  overview: 'Overview',
  operations: 'Operations',
  finance: 'Finance',
  moderation: 'Moderation',
  people: 'People & Activity',
  content: 'Content',
  admin: 'Administration',
}

export function getMenuSections(role) {
  const items = getMenuItems(role)
  const order = ['overview', 'operations', 'finance', 'moderation', 'people', 'content', 'admin']
  const grouped = {}

  for (const item of items) {
    const key = item.section || 'overview'
    if (!grouped[key]) grouped[key] = []
    grouped[key].push(item)
  }

  return order
    .filter((key) => grouped[key]?.length)
    .map((key) => ({
      id: key,
      label: SECTION_LABELS[key] || key,
      items: grouped[key],
    }))
}

export function getPageMeta(pathname) {
  const map = {
    '/dashboard': { title: 'Dashboard', crumb: 'Overview' },
    '/staff-inbox': { title: 'Staff Inbox', crumb: 'Overview' },
    '/wallet-explorer': { title: 'Wallet Explorer', crumb: 'Finance' },
    '/collaboration-hub': { title: 'Collaboration Hub', crumb: 'Moderation' },
    '/owner-requests': { title: 'Owner Requests', crumb: 'Operations' },
    '/workspace-requests': { title: 'Workspace Requests', crumb: 'Operations' },
    '/payment-verification': { title: 'Payment Verification', crumb: 'Finance' },
    '/wallet-topup-verification': { title: 'Wallet Top-Ups', crumb: 'Finance' },
    '/wallet-refunds': { title: 'Wallet & Refunds', crumb: 'Finance' },
    '/owner-payouts': { title: 'Owner Payouts', crumb: 'Finance' },
    '/reports': { title: 'User Reports', crumb: 'Moderation' },
    '/users': { title: 'Users', crumb: 'People' },
    '/bookings': { title: 'Bookings', crumb: 'People' },
    '/payments': { title: 'All Payments', crumb: 'Finance' },
    '/notifications': { title: 'Notifications', crumb: 'People' },
    '/moderators': { title: 'Moderators', crumb: 'Administration' },
    '/moderator-activity': { title: 'Activity History', crumb: 'Administration' },
    '/platform-accounts': { title: 'Platform Accounts', crumb: 'Administration' },
    '/app-release': { title: 'Android APK Release', crumb: 'Administration' },
    '/workspaces': { title: 'All Workspaces', crumb: 'Content' },
    '/reviews': { title: 'Reviews', crumb: 'Content' },
    '/collaborations': { title: 'Collaborations', crumb: 'Content' },
    '/chat-monitoring': { title: 'Chat Monitoring', crumb: 'Moderation' },
    '/owner-revenue': { title: 'Platform Revenue', crumb: 'Finance' },
  }
  return map[pathname] || { title: 'Panel', crumb: 'CWC' }
}
