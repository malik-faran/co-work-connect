import { Navigate, useLocation } from 'react-router-dom'
import { canAccessPath } from '../lib/permissions'

const ProtectedRoute = ({ user, children }) => {
  const location = useLocation()
  const path = location.pathname

  if (!user) {
    return <Navigate to="/login" replace />
  }

  if (!canAccessPath(user.role, path)) {
    return <Navigate to="/dashboard" replace />
  }

  return children
}

export default ProtectedRoute
