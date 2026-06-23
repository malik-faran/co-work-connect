// App-wide constants mirroring the Flutter app's AppConstants.

export const APP_NAME = 'CWL'
export const APP_TAGLINE = 'Find teammates. Build projects. Book spaces.'

export const ROLES = { user: 'user', owner: 'owner', admin: 'admin' }

export const BOOKING_STATUS = {
  pending: 'pending',
  confirmed: 'confirmed',
  cancelled: 'cancelled',
  completed: 'completed',
}

export const PAYMENT_STATUS = {
  pending: 'pending',
  processing: 'processing',
  completed: 'completed',
  failed: 'failed',
  cancelled: 'cancelled',
  expired: 'expired',
}

export const RECEIPT_STATUS = {
  awaitingUpload: 'awaiting_upload',
  awaitingVerification: 'awaiting_verification',
  approved: 'approved',
  rejected: 'rejected',
}

export const ACCOUNT_TYPES = ['bank', 'easypaisa', 'jazzcash']

export const WORKSPACE_TYPES = {
  private: 'private',
  shared: 'shared',
  meetingRoom: 'meeting-room',
}

export const WORKSPACE_TYPE_LABELS = {
  private: 'Private Office',
  shared: 'Shared Desk',
  'meeting-room': 'Meeting Room',
}

export const CITIES = [
  'Islamabad',
  'Lahore',
  'Karachi',
  'Rawalpindi',
  'Faisalabad',
  'Peshawar',
]

export const AMENITIES = [
  'WiFi',
  'Parking',
  'Coffee',
  'Tea',
  'Air Conditioning',
  'Security',
  'Kitchen',
  'Restroom',
]

export const AMENITY_ICONS = {
  WiFi: 'bi-wifi',
  Parking: 'bi-p-square',
  Coffee: 'bi-cup-hot',
  Tea: 'bi-cup',
  'Air Conditioning': 'bi-snow',
  Security: 'bi-shield-check',
  Kitchen: 'bi-egg-fried',
  Restroom: 'bi-droplet',
}

export const PROJECT_TYPES = [
  'Web Development',
  'Mobile App',
  'UI/UX Design',
  'Graphic Design',
  'Content Writing',
  'Digital Marketing',
  'Video Editing',
  'Data Science',
  'Business / Startup',
  'Other',
]

export const COLLAB_STATUS = {
  draft: 'draft',
  recruiting: 'recruiting',
  active: 'active',
  completed: 'completed',
  cancelled: 'cancelled',
}

export const currency = (n) =>
  `Rs. ${Number(n || 0).toLocaleString('en-PK', { maximumFractionDigits: 0 })}`
