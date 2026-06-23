import { useState, useEffect, useRef } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import AuthShell from './AuthShell'
import { authService } from '../../services/authService'
import { supabase } from '../../lib/supabase'
import { useToast } from '../../context/ToastContext'

export default function VerifyEmail() {
  const location = useLocation()
  const navigate = useNavigate()
  const toast = useToast()
  const email = location.state?.email || ''
  const [cooldown, setCooldown] = useState(0)
  const [checking, setChecking] = useState(false)
  const pollRef = useRef(null)

  useEffect(() => {
    pollRef.current = setInterval(async () => {
      const ok = await authService.checkVerified()
      if (ok) {
        clearInterval(pollRef.current)
        toast.success('Email verified! Please sign in.')
        await supabase.auth.signOut()
        navigate('/login')
      }
    }, 5000)
    return () => clearInterval(pollRef.current)
  }, [navigate, toast])

  useEffect(() => {
    if (cooldown <= 0) return
    const t = setTimeout(() => setCooldown(cooldown - 1), 1000)
    return () => clearTimeout(t)
  }, [cooldown])

  const check = async () => {
    setChecking(true)
    try {
      const ok = await authService.checkVerified()
      if (ok) {
        toast.success('Verified! Please sign in.')
        await supabase.auth.signOut()
        navigate('/login')
      } else {
        toast.warning('Not verified yet. Please click the link in your email.')
      }
    } finally {
      setChecking(false)
    }
  }

  const resend = async () => {
    try {
      await authService.resendVerification(email)
      toast.success('Verification email resent.')
      setCooldown(45)
    } catch (err) {
      toast.error(err.message || 'Could not resend')
    }
  }

  return (
    <AuthShell title="Verify your email" subtitle="We've sent a confirmation link to your inbox.">
      <div className="text-center">
        <div className="empty-icon mx-auto mb-3 animate__animated animate__pulse animate__infinite" style={{ animationDuration: '2s' }}>
          <i className="bi bi-envelope-paper fs-1"></i>
        </div>
        {email && <p className="text-secondary">Sent to <strong>{email}</strong></p>}
        <p className="text-secondary small">Click the link in your email, then come back here. We'll detect it automatically.</p>
        <div className="d-flex flex-column gap-2 mt-4">
          <button className="btn btn-primary btn-lg" onClick={check} disabled={checking}>
            {checking ? <span className="spinner-border spinner-border-sm me-2"></span> : <i className="bi bi-check-circle me-2"></i>}
            I've verified my email
          </button>
          <button className="btn btn-light" onClick={resend} disabled={cooldown > 0 || !email}>
            {cooldown > 0 ? `Resend in ${cooldown}s` : 'Resend verification email'}
          </button>
          <button className="btn btn-link text-secondary" onClick={() => navigate('/login')}>Back to sign in</button>
        </div>
      </div>
    </AuthShell>
  )
}
