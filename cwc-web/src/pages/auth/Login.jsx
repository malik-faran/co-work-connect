import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import AuthShell from './AuthShell'
import { authService } from '../../services/authService'
import { useToast } from '../../context/ToastContext'

export default function Login() {
  const navigate = useNavigate()
  const toast = useToast()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [show, setShow] = useState(false)
  const [loading, setLoading] = useState(false)

  const submit = async (e) => {
    e.preventDefault()
    setLoading(true)
    try {
      await authService.signIn({ email: email.trim(), password })
      toast.success('Welcome back!')
      navigate('/')
    } catch (err) {
      if (/verify/i.test(err.message)) {
        toast.warning('Please verify your email first.')
        navigate('/verify-email', { state: { email: email.trim() } })
      } else {
        toast.error(err.message || 'Login failed')
      }
    } finally {
      setLoading(false)
    }
  }

  return (
    <AuthShell
      title="Welcome back"
      subtitle="Sign in to continue to your workspace."
      footer={<span className="text-secondary">New here? <Link to="/get-started">Create an account</Link></span>}
    >
      <form onSubmit={submit} className="d-flex flex-column gap-3">
        <div>
          <label className="form-label">Email</label>
          <div className="input-icon">
            <i className="bi bi-envelope"></i>
            <input type="email" className="form-control" placeholder="you@example.com" value={email} onChange={(e) => setEmail(e.target.value)} required />
          </div>
        </div>
        <div>
          <label className="form-label">Password</label>
          <div className="input-icon">
            <i className="bi bi-lock"></i>
            <input type={show ? 'text' : 'password'} className="form-control pe-5" placeholder="••••••••" value={password} onChange={(e) => setPassword(e.target.value)} required />
            <button type="button" className="btn position-absolute end-0 top-50 translate-middle-y text-secondary" onClick={() => setShow(!show)} style={{ zIndex: 3 }}>
              <i className={`bi ${show ? 'bi-eye-slash' : 'bi-eye'}`}></i>
            </button>
          </div>
          <div className="text-end mt-1">
            <Link to="/forgot-password" className="small">Forgot password?</Link>
          </div>
        </div>
        <button className="btn btn-primary btn-lg w-100" disabled={loading}>
          {loading ? <span className="spinner-border spinner-border-sm me-2"></span> : <i className="bi bi-box-arrow-in-right me-2"></i>}
          Sign In
        </button>
      </form>
    </AuthShell>
  )
}
