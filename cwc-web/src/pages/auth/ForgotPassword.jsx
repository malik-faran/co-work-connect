import { useState } from 'react'
import { Link } from 'react-router-dom'
import AuthShell from './AuthShell'
import { authService } from '../../services/authService'
import { useToast } from '../../context/ToastContext'

export default function ForgotPassword() {
  const toast = useToast()
  const [email, setEmail] = useState('')
  const [sent, setSent] = useState(false)
  const [loading, setLoading] = useState(false)

  const submit = async (e) => {
    e.preventDefault()
    setLoading(true)
    try {
      await authService.forgotPassword(email.trim())
      setSent(true)
      toast.success('Reset link sent! Check your inbox.')
    } catch (err) {
      toast.error(err.message || 'Could not send reset email')
    } finally {
      setLoading(false)
    }
  }

  return (
    <AuthShell
      title="Reset your password"
      subtitle="Enter your email and we'll send you a reset link."
      footer={<Link to="/login"><i className="bi bi-arrow-left me-1"></i>Back to sign in</Link>}
    >
      {sent ? (
        <div className="text-center py-4">
          <div className="empty-icon mx-auto mb-3"><i className="bi bi-envelope-check fs-2"></i></div>
          <h6 className="fw-bold">Check your email</h6>
          <p className="text-secondary">We've sent a password reset link to <strong>{email}</strong></p>
        </div>
      ) : (
        <form onSubmit={submit} className="d-flex flex-column gap-3">
          <div>
            <label className="form-label">Email</label>
            <div className="input-icon">
              <i className="bi bi-envelope"></i>
              <input type="email" className="form-control" placeholder="you@example.com" value={email} onChange={(e) => setEmail(e.target.value)} required />
            </div>
          </div>
          <button className="btn btn-primary btn-lg w-100" disabled={loading}>
            {loading ? <span className="spinner-border spinner-border-sm me-2"></span> : <i className="bi bi-send me-2"></i>}
            Send Reset Link
          </button>
        </form>
      )}
    </AuthShell>
  )
}
