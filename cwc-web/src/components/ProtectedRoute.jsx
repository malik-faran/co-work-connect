import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { Loading } from './common'

export default function ProtectedRoute({ children, ownerOnly = false }) {
  const { isAuthed, loading, isOwner } = useAuth()
  const location = useLocation()

  if (loading) return <Loading full message="Loading your workspace..." />
  if (!isAuthed) return <Navigate to="/login" state={{ from: location }} replace />
  if (ownerOnly && !isOwner) return <Navigate to="/home" replace />
  return children
}
