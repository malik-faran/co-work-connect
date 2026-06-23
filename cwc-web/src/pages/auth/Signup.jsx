import { useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import AuthShell from './AuthShell'
import { authService } from '../../services/authService'
import { useToast } from '../../context/ToastContext'

function strength(pw) {
  let s = 0
  if (pw.length >= 8) s++
  if (/[A-Z]/.test(pw)) s++
  if (/[0-9]/.test(pw)) s++
  if (/[^A-Za-z0-9]/.test(pw)) s++
  return s
}

export default function Signup() {
  const navigate = useNavigate()
  const toast = useToast()
  const [params] = useSearchParams()
  const role = params.get('role') === 'owner' ? 'owner' : 'user'

  const [form, setForm] = useState({ name: '', email: '', phone: '', password: '', confirm: '', businessName: '' })
  const [agree, setAgree] = useState(false)
  const [loading, setLoading] = useState(false)
  const [show, setShow] = useState(false)

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value })
  const s = strength(form.password)
  const sColors = ['#e2e8f0', '#ef4444', '#fbbf24', '#38bdf8', '#22c55e']
  const sLabels = ['', 'Weak', 'Fair', 'Good', 'Strong']

  const submit = async (e) => {
    e.preventDefault()
    if (form.password !== form.confirm) return toast.error('Passwords do not match')
    if (s < 2) return toast.error('Please choose a stronger password')
    if (!agree) return toast.error('Please accept the terms to continue')
    setLoading(true)
    try {
      await authService.signUp({
        name: form.name.trim(),
        email: form.email.trim(),
        password: form.password,
        phone: form.phone.trim(),
        role,
        businessName: role === 'owner' ? form.businessName.trim() : null,
      })
      toast.success('Account created! Check your email to verify.')
      navigate('/verify-email', { state: { email: form.email.trim() } })
    } catch (err) {
      toast.error(err.message || 'Signup failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <AuthShell
      title={role === 'owner' ? 'Create owner account' : 'Create your account'}
      subtitle="It only takes a minute to get started."
      footer={<span className="text-secondary">Already registered? <Link to="/login">Sign in</Link></span>}
    >
      <form onSubmit={submit} className="d-flex flex-column gap-3">
        <span className="badge-soft badge-primary-soft align-self-start text-capitalize">
          <i className="bi bi-person-badge me-1"></i>{role} account
        </span>
        <div>
          <label className="form-label">Full name</label>
          <div className="input-icon">
            <i className="bi bi-person"></i>
            <input className="form-control" placeholder="John Doe" value={form.name} onChange={set('name')} required />
          </div>
        </div>
        <div>
          <label className="form-label">Email</label>
          <div className="input-icon">
            <i className="bi bi-envelope"></i>
            <input type="email" className="form-control" placeholder="you@example.com" value={form.email} onChange={set('email')} required />
          </div>
        </div>
        <div>
          <label className="form-label">Phone <span className="text-secondary fw-normal">(optional)</span></label>
          <div className="input-icon">
            <i className="bi bi-telephone"></i>
            <input className="form-control" placeholder="03xx-xxxxxxx" value={form.phone} onChange={set('phone')} />
          </div>
        </div>
        {role === 'owner' && (
          <div>
            <label className="form-label">Business name <span className="text-secondary fw-normal">(optional)</span></label>
            <div className="input-icon">
              <i className="bi bi-building"></i>
              <input className="form-control" placeholder="Your coworking brand" value={form.businessName} onChange={set('businessName')} />
            </div>
          </div>
        )}
        <div>
          <label className="form-label">Password</label>
          <div className="input-icon">
            <i className="bi bi-lock"></i>
            <input type={show ? 'text' : 'password'} className="form-control pe-5" placeholder="••••••••" value={form.password} onChange={set('password')} required />
            <button type="button" className="btn position-absolute end-0 top-50 translate-middle-y text-secondary" onClick={() => setShow(!show)} style={{ zIndex: 3 }}>
              <i className={`bi ${show ? 'bi-eye-slash' : 'bi-eye'}`}></i>
            </button>
          </div>
          {form.password && (
            <div className="d-flex align-items-center gap-2 mt-2">
              <div className="flex-fill d-flex gap-1">
                {[1, 2, 3, 4].map((i) => (
                  <div key={i} style={{ height: 4, flex: 1, borderRadius: 4, background: i <= s ? sColors[s] : '#e2e8f0' }} />
                ))}
              </div>
              <span className="small" style={{ color: sColors[s] }}>{sLabels[s]}</span>
            </div>
          )}
        </div>
        <div>
          <label className="form-label">Confirm password</label>
          <div className="input-icon">
            <i className="bi bi-lock-fill"></i>
            <input type={show ? 'text' : 'password'} className="form-control" placeholder="••••••••" value={form.confirm} onChange={set('confirm')} required />
          </div>
        </div>
        <div className="form-check">
          <input className="form-check-input" type="checkbox" id="agree" checked={agree} onChange={(e) => setAgree(e.target.checked)} />
          <label className="form-check-label small text-secondary" htmlFor="agree">
            I agree to the Terms of Service and Privacy Policy
          </label>
        </div>
        <button className="btn btn-primary btn-lg w-100" disabled={loading}>
          {loading ? <span className="spinner-border spinner-border-sm me-2"></span> : <i className="bi bi-person-plus me-2"></i>}
          Create Account
        </button>
      </form>
    </AuthShell>
  )
}
