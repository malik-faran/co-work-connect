import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase, fetchStaffProfileWithTimeout } from '../lib/supabase'

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
    <div style={{
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      padding: '20px',
      position: 'relative',
      overflow: 'hidden'
    }}>
      <div style={{
        position: 'absolute',
        top: '-50%',
        left: '-50%',
        width: '200%',
        height: '200%',
        background: 'radial-gradient(circle, rgba(255, 255, 255, 0.17) 1px, transparent 1px)',
        backgroundSize: '50px 50px',
        animation: 'shimmer 20s linear infinite'
      }} />
      
      <div style={{
        background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
        backdropFilter: 'blur(20px)',
        padding: '48px',
        borderRadius: '24px',
        boxShadow: '0 20px 60px rgba(0, 0, 0, 0.3)',
        border: '1px solid rgba(255, 255, 255, 0.3)',
        width: '100%',
        maxWidth: '460px',
        animation: 'scaleIn 0.5s ease-out',
        position: 'relative',
        zIndex: 1
      }}>
        <div style={{ textAlign: 'center', marginBottom: '40px' }}>
          <div style={{
            width: '80px',
            height: '80px',
            background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
            borderRadius: '20px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 24px',
            boxShadow: '0 8px 24px rgba(102, 126, 234, 0.4)',
          }}>
            <span style={{ fontSize: '40px' }}>🔐</span>
          </div>
          <h1 style={{
            fontSize: '36px',
            fontWeight: '800',
            marginBottom: '12px',
            background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            backgroundClip: 'text',
          }}>
            Admin & Moderator Panel
          </h1>
          <p style={{ color: '#64748b', fontSize: '16px', fontWeight: '500' }}>
            Sign in with admin or moderator account
          </p>
        </div>

        {error && (
          <div style={{
            padding: '14px 16px',
            backgroundColor: '#fee2e2',
            color: '#dc2626',
            borderRadius: '8px',
            marginBottom: '24px',
            fontSize: '14px',
            border: '1px solid #fecaca',
          }}>
            {error}
          </div>
        )}

        <form onSubmit={handleLogin}>
          <div style={{ marginBottom: '20px' }}>
            <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: '600', color: '#374151' }}>
              Email Address
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              disabled={loading}
              style={{
                width: '100%', padding: '14px 16px', border: '1px solid #e2e8f0',
                borderRadius: '8px', fontSize: '14px', outline: 'none',
                backgroundColor: '#f8fafc', boxSizing: 'border-box',
              }}
              placeholder="admin@cwc.com"
            />
          </div>

          <div style={{ marginBottom: '28px' }}>
            <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: '600', color: '#374151' }}>
              Password
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              disabled={loading}
              style={{
                width: '100%', padding: '14px 16px', border: '1px solid #e2e8f0',
                borderRadius: '8px', fontSize: '14px', outline: 'none',
                backgroundColor: '#f8fafc', boxSizing: 'border-box',
              }}
              placeholder="Enter your password"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            style={{
              width: '100%', padding: '16px',
              background: loading ? '#94a3b8' : 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
              color: 'white', border: 'none', borderRadius: '12px',
              fontSize: '16px', fontWeight: '700',
              cursor: loading ? 'not-allowed' : 'pointer',
            }}
          >
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
        </form>

        <p style={{ marginTop: '20px', fontSize: '12px', color: '#94a3b8', textAlign: 'center', lineHeight: 1.5 }}>
          Note: App user/owner accounts cannot login here. Account must have role <strong>admin</strong> or <strong>moderator</strong> in database.
        </p>
      </div>
    </div>
  )
}

export default Login
