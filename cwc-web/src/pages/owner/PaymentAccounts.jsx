import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { paymentService } from '../../services/paymentService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { Loading, EmptyState, Modal } from '../../components/common'
import { ACCOUNT_TYPES } from '../../lib/constants'

const META = {
  bank: { icon: 'bi-bank', label: 'Bank Account' },
  easypaisa: { icon: 'bi-phone', label: 'EasyPaisa' },
  jazzcash: { icon: 'bi-phone-vibrate', label: 'JazzCash' },
}

export default function PaymentAccounts() {
  const { userId } = useAuth()
  const navigate = useNavigate()
  const toast = useToast()
  const [accounts, setAccounts] = useState([])
  const [loading, setLoading] = useState(true)
  const [show, setShow] = useState(false)
  const [form, setForm] = useState({ account_type: 'bank', account_title: '', account_number: '', bank_name: '', is_default: false })
  const [saving, setSaving] = useState(false)

  const load = async () => {
    try { setAccounts(await paymentService.getOwnerAccounts(userId)) } finally { setLoading(false) }
  }
  useEffect(() => { if (userId) load() }, [userId])

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value })

  const save = async () => {
    if (!form.account_title.trim() || !form.account_number.trim()) return toast.error('Fill in account details')
    if (form.account_type === 'bank' && !form.bank_name.trim()) return toast.error('Bank name required')
    setSaving(true)
    try {
      await paymentService.createAccount({
        ownerId: userId,
        accountType: form.account_type,
        accountTitle: form.account_title,
        accountNumber: form.account_number,
        bankName: form.bank_name,
        isDefault: form.is_default,
      })
      toast.success('Account added')
      setShow(false)
      setForm({ account_type: 'bank', account_title: '', account_number: '', bank_name: '', is_default: false })
      load()
    } catch (err) { toast.error(err.message) } finally { setSaving(false) }
  }

  const setDefault = async (a) => { await paymentService.setDefaultAccount(userId, a.id); load() }
  const remove = async (a) => { if (confirm('Delete this account?')) { await paymentService.deleteAccount(a.id); load() } }

  if (loading) return <Loading />

  return (
    <div className="container-app" style={{ maxWidth: 720 }}>
      <button className="btn btn-light mb-3" onClick={() => navigate(-1)}><i className="bi bi-arrow-left me-1"></i>Back</button>
      <div className="d-flex justify-content-between align-items-center mb-3">
        <h3 className="fw-bold mb-0">Payment Accounts</h3>
        <button className="btn btn-primary" onClick={() => setShow(true)}><i className="bi bi-plus-lg me-1"></i>Add</button>
      </div>
      <p className="text-secondary">These accounts are shown to users when they pay for your workspaces.</p>

      {accounts.length === 0 ? (
        <EmptyState icon="bi-bank" title="No payment accounts" subtitle="Add a bank or mobile wallet to receive payments." action={<button className="btn btn-primary" onClick={() => setShow(true)}>Add Account</button>} />
      ) : (
        <div className="d-flex flex-column gap-2">
          {accounts.map((a) => {
            const m = META[a.account_type] || META.bank
            return (
              <div className="card-clean p-3 d-flex align-items-center gap-3" key={a.id}>
                <div className="stat-icon" style={{ background: 'var(--primary-gradient)' }}><i className={`bi ${m.icon} text-white`}></i></div>
                <div className="flex-fill">
                  <div className="fw-semibold">{m.label} {a.bank_name && `· ${a.bank_name}`} {a.is_default && <span className="badge-soft badge-success-soft ms-1">Default</span>}</div>
                  <div className="small text-secondary">{a.account_title} — {a.account_number}</div>
                </div>
                {!a.is_default && <button className="btn btn-light btn-sm" onClick={() => setDefault(a)}>Set default</button>}
                <button className="btn btn-light btn-sm text-danger" onClick={() => remove(a)}><i className="bi bi-trash"></i></button>
              </div>
            )
          })}
        </div>
      )}

      {show && (
        <Modal show onClose={() => setShow(false)} title="Add payment account" footer={
          <>
            <button className="btn btn-light" onClick={() => setShow(false)}>Cancel</button>
            <button className="btn btn-primary" onClick={save} disabled={saving}>{saving ? <span className="spinner-border spinner-border-sm me-2"></span> : null}Add</button>
          </>
        }>
          <div className="mb-2">
            <label className="form-label">Type</label>
            <select className="form-select" value={form.account_type} onChange={set('account_type')}>
              {ACCOUNT_TYPES.map((t) => <option key={t} value={t}>{META[t].label}</option>)}
            </select>
          </div>
          {form.account_type === 'bank' && (
            <div className="mb-2"><label className="form-label">Bank name</label><input className="form-control" value={form.bank_name} onChange={set('bank_name')} /></div>
          )}
          <div className="mb-2"><label className="form-label">Account title</label><input className="form-control" value={form.account_title} onChange={set('account_title')} placeholder="Account holder name" /></div>
          <div className="mb-2"><label className="form-label">{form.account_type === 'bank' ? 'Account number / IBAN' : 'Mobile number'}</label><input className="form-control" value={form.account_number} onChange={set('account_number')} /></div>
          <div className="form-check">
            <input className="form-check-input" type="checkbox" id="def" checked={form.is_default} onChange={(e) => setForm({ ...form, is_default: e.target.checked })} />
            <label className="form-check-label" htmlFor="def">Set as default</label>
          </div>
        </Modal>
      )}
    </div>
  )
}
