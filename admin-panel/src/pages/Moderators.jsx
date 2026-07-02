import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { isAdmin } from '../lib/permissions'
import { createModeratorAccount } from '../lib/auditLog'
import { Shield, UserPlus, UserMinus, RefreshCw, History, Link as LinkIcon } from 'lucide-react'
import { Link } from 'react-router-dom'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'

const Moderators = ({ user }) => {
  const [moderators, setModerators] = useState([])
  const [loading, setLoading] = useState(true)
  const [creating, setCreating] = useState(false)
  const [form, setForm] = useState({ name: '', email: '', password: '', phone: '' })

  useEffect(() => {
    if (isAdmin(user?.role)) fetchModerators()
    else setLoading(false)
  }, [user])

  const fetchModerators = async () => {
    try {
      setLoading(true)
      const { data, error } = await supabase
        .from('users')
        .select('id, name, email, phone, moderator_active, promoted_at, promoted_by')
        .eq('role', 'moderator')
        .order('promoted_at', { ascending: false })

      if (error) throw error
      setModerators(data || [])
    } catch (e) {
      showError(e.message)
    } finally {
      setLoading(false)
    }
  }

  const handleRegister = async (e) => {
    e.preventDefault()
    setCreating(true)
    try {
      await createModeratorAccount(form)
      showSuccess(`Moderator "${form.name}" registered successfully`)
      setForm({ name: '', email: '', password: '', phone: '' })
      fetchModerators()
    } catch (e) {
      showError(e.message || 'Failed to create moderator')
    } finally {
      setCreating(false)
    }
  }

  const demote = async (userId, name) => {
    if (!window.confirm(`Remove moderator access for "${name}"?`)) return
    try {
      const { error } = await supabase.rpc('admin_set_moderator', {
        p_user_id: userId,
        p_make_moderator: false,
      })
      if (error) throw error
      showSuccess('Moderator demoted to user')
      fetchModerators()
    } catch (e) {
      showError(e.message)
    }
  }

  if (!isAdmin(user?.role)) {
    return (
      <EmptyState icon={Shield} title="Admin Only" message="Only admins can manage moderators." />
    )
  }

  if (loading) return <Loading message="Loading moderators..." />

  return (
    <div className="fade-in">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '32px', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h1 style={{ fontSize: '32px', fontWeight: '800', marginBottom: '8px' }}>Moderators</h1>
          <p style={{ color: '#64748b' }}>
            Register digital assistants with email & password. They login to admin panel (web only).
          </p>
        </div>
        <Link
          to="/moderator-activity"
          style={{
            display: 'flex', alignItems: 'center', gap: '8px', padding: '12px 20px',
            background: 'white', color: '#6366f1', border: '2px solid #6366f1',
            borderRadius: '10px', textDecoration: 'none', fontWeight: '600',
          }}
        >
          <History size={18} /> View Activity History
        </Link>
      </div>

      <form onSubmit={handleRegister} style={{
        background: 'white', padding: '28px', borderRadius: '16px',
        marginBottom: '28px', boxShadow: '0 4px 20px rgba(0,0,0,0.08)',
      }}>
        <h3 style={{ marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}>
          <UserPlus size={22} /> Register New Moderator
        </h3>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '16px', marginBottom: '20px' }}>
          <input
            placeholder="Full name *"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            required
            style={{ padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0' }}
          />
          <input
            type="email"
            placeholder="Email *"
            value={form.email}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
            required
            style={{ padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0' }}
          />
          <input
            type="password"
            placeholder="Password (min 6 chars) *"
            value={form.password}
            onChange={(e) => setForm({ ...form, password: e.target.value })}
            required
            minLength={6}
            style={{ padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0' }}
          />
          <input
            placeholder="Phone (optional)"
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
            style={{ padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0' }}
          />
        </div>
        <button
          type="submit"
          disabled={creating}
          style={{
            padding: '14px 28px', background: creating ? '#94a3b8' : '#10b981', color: 'white',
            border: 'none', borderRadius: '10px', cursor: creating ? 'not-allowed' : 'pointer',
            fontWeight: '700', fontSize: '15px',
          }}
        >
          {creating ? 'Creating account...' : 'Create Moderator Account'}
        </button>
        <p style={{ marginTop: '12px', fontSize: '13px', color: '#94a3b8' }}>
          Account is created instantly — moderator can login at admin panel with this email & password.
        </p>
      </form>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
        <h3>Active Moderators ({moderators.length})</h3>
        <button onClick={fetchModerators} style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 12px', border: '1px solid #e2e8f0', borderRadius: '8px', background: 'white', cursor: 'pointer' }}>
          <RefreshCw size={16} /> Refresh
        </button>
      </div>

      {moderators.length === 0 ? (
        <EmptyState icon={Shield} title="No moderators yet" message="Register a moderator using the form above." />
      ) : (
        <div style={{ display: 'grid', gap: '12px' }}>
          {moderators.map((m) => (
            <div key={m.id} style={{
              background: 'white', padding: '20px', borderRadius: '12px',
              boxShadow: '0 2px 12px rgba(0,0,0,0.06)',
              display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px',
            }}>
              <div>
                <div style={{ fontWeight: '700', fontSize: '16px' }}>{m.name}</div>
                <div style={{ color: '#64748b' }}>{m.email}</div>
                {m.phone && <div style={{ fontSize: '13px', color: '#94a3b8' }}>{m.phone}</div>}
                {m.promoted_at && (
                  <div style={{ fontSize: '12px', color: '#94a3b8', marginTop: '4px' }}>
                    Registered: {new Date(m.promoted_at).toLocaleDateString()}
                  </div>
                )}
              </div>
              <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                <Link
                  to={`/moderator-activity?actor=${m.id}`}
                  style={{
                    padding: '10px 14px', background: '#f1f5f9', color: '#475569',
                    borderRadius: '8px', textDecoration: 'none', fontWeight: '600', fontSize: '13px',
                    display: 'flex', alignItems: 'center', gap: '6px',
                  }}
                >
                  <LinkIcon size={14} /> History
                </Link>
                {m.id !== user?.id && (
                  <button
                    onClick={() => demote(m.id, m.name)}
                    style={{
                      padding: '10px 16px', background: '#fee2e2', color: '#dc2626',
                      border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: '600',
                      display: 'flex', alignItems: 'center', gap: '6px',
                    }}
                  >
                    <UserMinus size={16} /> Remove
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default Moderators
