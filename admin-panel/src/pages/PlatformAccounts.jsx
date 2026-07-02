import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { isAdmin } from '../lib/permissions'
import { Landmark, Plus, RefreshCw, Star, Trash2 } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'

const emptyForm = {
  account_type: 'easypaisa',
  account_title: 'Co-Work Connect',
  account_number: '',
  bank_name: '',
  is_active: true,
  is_default: false,
}

const PlatformAccounts = ({ user }) => {
  const [accounts, setAccounts] = useState([])
  const [loading, setLoading] = useState(true)
  const [form, setForm] = useState(emptyForm)
  const [showForm, setShowForm] = useState(false)
  const [deletingId, setDeletingId] = useState(null)

  useEffect(() => {
    if (isAdmin(user?.role)) fetchAccounts()
    else setLoading(false)
  }, [user])

  const fetchAccounts = async () => {
    try {
      setLoading(true)
      const { data, error } = await supabase
        .from('platform_payment_accounts')
        .select('*')
        .order('is_default', { ascending: false })

      if (error) throw error
      setAccounts(data || [])
    } catch (e) {
      showError(e.message)
    } finally {
      setLoading(false)
    }
  }

  const saveAccount = async (e) => {
    e.preventDefault()
    try {
      if (form.is_default) {
        await supabase
          .from('platform_payment_accounts')
          .update({ is_default: false })
          .eq('is_default', true)
      }

      const { error } = await supabase.from('platform_payment_accounts').insert({
        ...form,
        bank_name: form.account_type === 'bank' ? form.bank_name : null,
      })
      if (error) throw error

      showSuccess('Platform account added')
      setForm(emptyForm)
      setShowForm(false)
      fetchAccounts()
    } catch (e) {
      showError(e.message)
    }
  }

  const setDefault = async (id) => {
    try {
      await supabase.from('platform_payment_accounts').update({ is_default: false }).neq('id', '00000000-0000-0000-0000-000000000000')
      const { error } = await supabase.from('platform_payment_accounts').update({ is_default: true }).eq('id', id)
      if (error) throw error
      showSuccess('Default account updated')
      fetchAccounts()
    } catch (e) {
      showError(e.message)
    }
  }

  const toggleActive = async (id, active) => {
    try {
      const { error } = await supabase.from('platform_payment_accounts').update({ is_active: !active }).eq('id', id)
      if (error) throw error
      fetchAccounts()
    } catch (e) {
      showError(e.message)
    }
  }

  const deleteAccount = async (account) => {
    const label = `${account.account_type} — ${account.account_number}`
    if (!window.confirm(`Delete platform account "${label}"?\n\nThis cannot be undone. Past payments linked to this account will keep their records.`)) {
      return
    }

    setDeletingId(account.id)
    try {
      if (account.is_default) {
        const other = accounts.find((a) => a.id !== account.id && a.is_active)
        if (other) {
          await supabase.from('platform_payment_accounts').update({ is_default: true }).eq('id', other.id)
        }
      }

      const { error } = await supabase
        .from('platform_payment_accounts')
        .delete()
        .eq('id', account.id)

      if (error) throw error
      showSuccess('Platform account deleted')
      fetchAccounts()
    } catch (e) {
      showError(e.message)
    } finally {
      setDeletingId(null)
    }
  }

  if (!isAdmin(user?.role)) {
    return <EmptyState icon={Landmark} title="Admin Only" message="Only admins can manage platform payment accounts." />
  }

  if (loading) return <Loading message="Loading platform accounts..." />

  return (
    <div className="fade-in">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '32px', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <h1 style={{ fontSize: '32px', fontWeight: '800', marginBottom: '8px' }}>Platform Accounts</h1>
          <p style={{ color: '#64748b' }}>
            Users transfer booking payments to these CWC accounts (middle-man model).
          </p>
        </div>
        <button onClick={() => setShowForm(!showForm)} style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '12px 20px', background: '#6366f1', color: 'white', border: 'none', borderRadius: '10px', cursor: 'pointer', fontWeight: '600' }}>
          <Plus size={18} /> Add Account
        </button>
      </div>

      {showForm && (
        <form onSubmit={saveAccount} style={{ background: 'white', padding: '24px', borderRadius: '16px', marginBottom: '24px', boxShadow: '0 4px 20px rgba(0,0,0,0.08)' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px', marginBottom: '16px' }}>
            <select value={form.account_type} onChange={(e) => setForm({ ...form, account_type: e.target.value })} style={{ padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
              <option value="easypaisa">EasyPaisa</option>
              <option value="jazzcash">JazzCash</option>
              <option value="bank">Bank</option>
            </select>
            <input placeholder="Account title" value={form.account_title} onChange={(e) => setForm({ ...form, account_title: e.target.value })} required style={{ padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0' }} />
            <input placeholder="Account number" value={form.account_number} onChange={(e) => setForm({ ...form, account_number: e.target.value })} required style={{ padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0' }} />
            {form.account_type === 'bank' && (
              <input placeholder="Bank name" value={form.bank_name} onChange={(e) => setForm({ ...form, bank_name: e.target.value })} style={{ padding: '12px', borderRadius: '8px', border: '1px solid #e2e8f0' }} />
            )}
          </div>
          <label style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
            <input type="checkbox" checked={form.is_default} onChange={(e) => setForm({ ...form, is_default: e.target.checked })} />
            Set as default account shown to users
          </label>
          <button type="submit" style={{ padding: '12px 24px', background: '#10b981', color: 'white', border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: '600' }}>Save Account</button>
        </form>
      )}

      {accounts.length === 0 ? (
        <EmptyState icon={Landmark} title="No accounts" message="Add your JazzCash/EasyPaisa/Bank details." />
      ) : (
        <div style={{ display: 'grid', gap: '12px' }}>
          {accounts.map((a) => (
            <div key={a.id} style={{ background: 'white', padding: '20px', borderRadius: '12px', boxShadow: '0 2px 12px rgba(0,0,0,0.06)', opacity: a.is_active ? 1 : 0.6 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <strong style={{ textTransform: 'capitalize' }}>{a.account_type}</strong>
                    {a.is_default && <span style={{ background: '#fef3c7', color: '#d97706', padding: '2px 8px', borderRadius: '12px', fontSize: '11px', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '4px' }}><Star size={12} /> Default</span>}
                    {!a.is_active && <span style={{ color: '#ef4444', fontSize: '12px' }}>Inactive</span>}
                  </div>
                  <div style={{ marginTop: '4px' }}>{a.account_title}</div>
                  <div style={{ color: '#6366f1', fontWeight: '700', fontSize: '18px', marginTop: '4px' }}>{a.account_number}</div>
                  {a.bank_name && <div style={{ color: '#64748b', fontSize: '14px' }}>{a.bank_name}</div>}
                </div>
                <div style={{ display: 'flex', gap: '8px', alignItems: 'flex-start' }}>
                  {!a.is_default && a.is_active && (
                    <button onClick={() => setDefault(a.id)} style={{ padding: '8px 12px', background: '#f1f5f9', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '13px' }}>Set Default</button>
                  )}
                  <button onClick={() => toggleActive(a.id, a.is_active)} style={{ padding: '8px 12px', background: a.is_active ? '#fee2e2' : '#d1fae5', color: a.is_active ? '#dc2626' : '#059669', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '13px' }}>
                    {a.is_active ? 'Deactivate' : 'Activate'}
                  </button>
                  <button
                    onClick={() => deleteAccount(a)}
                    disabled={deletingId === a.id}
                    style={{
                      padding: '8px 12px',
                      background: '#fef2f2',
                      color: '#dc2626',
                      border: '1px solid #fecaca',
                      borderRadius: '8px',
                      cursor: deletingId === a.id ? 'not-allowed' : 'pointer',
                      fontSize: '13px',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px',
                      opacity: deletingId === a.id ? 0.6 : 1,
                    }}
                  >
                    <Trash2 size={14} />
                    {deletingId === a.id ? 'Deleting...' : 'Delete'}
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      <button onClick={fetchAccounts} style={{ marginTop: '16px', display: 'flex', alignItems: 'center', gap: '6px', padding: '10px 16px', border: '1px solid #e2e8f0', borderRadius: '8px', background: 'white', cursor: 'pointer' }}>
        <RefreshCw size={16} /> Refresh
      </button>
    </div>
  )
}

export default PlatformAccounts
