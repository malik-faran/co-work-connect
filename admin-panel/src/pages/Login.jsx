import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { Shield } from 'lucide-react'
import { supabase, fetchStaffProfileWithTimeout } from '../lib/supabase'
import { Btn, Field } from '../components/ui/PageShell'

const Login = ({ onLoginStart, onLoginSuccess, onLoginEnd }) => {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleLogin = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError('')
    onLoginStart?.()

    try {
      const { data, error: signInError } = await Promise.race([
        supabase.auth.signInWithPassword({
          email: email.trim(),
          password,
        }),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('Login timed out. Check internet / Supabase URL.')), 20000)
        ),
      ])

      if (signInError) {
        if (/email not confirmed/i.test(signInError.message)) {
          throw new Error('Please verify your email first (Supabase Auth → Users → confirm email).')
        }
        throw signInError
      }
      if (!data?.user) throw new Error('Login failed. Please try again.')

      const profile = await fetchStaffProfileWithTimeout(data.user.id)

      const staffUser = {
        id: data.user.id,
        email: data.user.email,
        role: profile.role,
        name: profile.name,
      }

      onLoginSuccess?.(staffUser)
      navigate('/dashboard', { replace: true })
    } catch (err) {
      supabase.auth.signOut().catch(() => {})
      setError(err.message || 'Login failed')
    } finally {
      setLoading(false)
      onLoginEnd?.()
    }
  }

  return (
    <div className="login-page">
      <section className="login-hero">
        <div>
          <div style={{
            width: 56,
            height: 56,
            borderRadius: 14,
            background: 'rgba(255,255,255,0.12)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            marginBottom: 28,
          }}>
            <Shield size={28} />
          </div>
          <h1>Operate CWC with confidence</h1>
          <p>
            Secure console for admins and moderators — verify payments, review reports,
            approve owners, and keep the platform safe.
          </p>
        </div>
        <p style={{ fontSize: 13, color: 'rgba(255,255,255,0.5)', position: 'relative', zIndex: 1 }}>
          Coworking With Creators · Staff access only
        </p>
      </section>

      <section className="login-form-wrap">
        <div className="login-card fade-in">
          <h2>Sign in</h2>
          <p>Use your admin or moderator account credentials.</p>

          {error && <div className="alert-error">{error}</div>}

          <form onSubmit={handleLogin}>
            <Field label="Email address">
              <input
                type="email"
                className="input"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                disabled={loading}
                placeholder="admin@cwc.com"
              />
            </Field>

            <Field label="Password">
              <input
                type="password"
                className="input"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                disabled={loading}
                placeholder="Enter your password"
              />
            </Field>

            <Btn type="submit" variant="primary" size="lg" disabled={loading} style={{ width: '100%' }}>
              {loading ? 'Signing in...' : 'Sign in'}
            </Btn>
          </form>

          <p style={{ marginTop: 20, fontSize: 12, color: 'var(--text-tertiary)', textAlign: 'center', lineHeight: 1.6 }}>
            App user and owner accounts cannot sign in here. Your database role must be
            {' '}<strong>admin</strong> or <strong>moderator</strong>.
          </p>
          <p style={{ marginTop: 12, textAlign: 'center' }}>
            <Link to="/" style={{ fontSize: 13, color: 'var(--primary)', fontWeight: 600 }}>
              ← Back to project home
            </Link>
          </p>
        </div>
      </section>
    </div>
  )
}

export default Login
