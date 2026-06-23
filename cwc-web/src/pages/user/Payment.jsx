import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import { paymentService } from '../../services/paymentService'
import { workspaceService } from '../../services/workspaceService'
import { storageService } from '../../services/storageService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { Loading } from '../../components/common'
import { currency } from '../../lib/constants'

const ACCOUNT_META = {
  bank: { icon: 'bi-bank', label: 'Bank Transfer' },
  easypaisa: { icon: 'bi-phone', label: 'EasyPaisa' },
  jazzcash: { icon: 'bi-phone-vibrate', label: 'JazzCash' },
}

export default function Payment() {
  const { bookingId } = useParams()
  const navigate = useNavigate()
  const { userId } = useAuth()
  const toast = useToast()

  const [booking, setBooking] = useState(null)
  const [workspace, setWorkspace] = useState(null)
  const [payment, setPayment] = useState(null)
  const [accounts, setAccounts] = useState([])
  const [selectedAccount, setSelectedAccount] = useState(null)
  const [reference, setReference] = useState('')
  const [file, setFile] = useState(null)
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    const init = async () => {
      try {
        const { data: b } = await supabase.from('bookings').select('*').eq('id', bookingId).maybeSingle()
        setBooking(b)
        if (!b) return
        const ws = await workspaceService.getById(b.workspace_id)
        setWorkspace(ws)
        const pay = await paymentService.createManualPayment({ bookingId: b.id, userId, amount: b.total_price })
        setPayment(pay)
        const accs = await paymentService.getAccountsForWorkspace(ws.owner_id, ws.id)
        setAccounts(accs)
        setSelectedAccount(accs.find((a) => a.is_default) || accs[0] || null)
      } catch (err) {
        console.error(err)
        toast.error('Could not load payment')
      } finally {
        setLoading(false)
      }
    }
    init()
  }, [bookingId, userId])

  const submit = async () => {
    if (!selectedAccount) return toast.error('Select a payment account')
    if (!file) return toast.error('Please upload your payment receipt')
    setSubmitting(true)
    try {
      const url = await storageService.uploadReceipt(userId, booking.id, file)
      await paymentService.submitReceipt({
        paymentId: payment.id,
        ownerAccountId: selectedAccount.id,
        receiptUrl: url,
        transferReference: reference,
        ownerId: workspace.owner_id,
        bookingId: booking.id,
      })
      toast.success('Receipt submitted! Awaiting owner verification.')
      navigate('/bookings')
    } catch (err) {
      toast.error(err.message || 'Submission failed')
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) return <Loading message="Preparing payment..." />
  if (!booking) return <div className="container-app"><p>Booking not found.</p></div>

  return (
    <div className="container-app" style={{ maxWidth: 720 }}>
      <button className="btn btn-light mb-3" onClick={() => navigate(-1)}><i className="bi bi-arrow-left me-1"></i>Back</button>
      <h3 className="fw-bold mb-1">Complete Payment</h3>
      <p className="text-secondary">Transfer the amount, then upload your receipt for verification.</p>

      {/* Summary */}
      <div className="card-clean p-4 mb-3" style={{ background: 'var(--hero-gradient)', color: '#fff' }}>
        <div className="d-flex justify-content-between">
          <div>
            <div style={{ opacity: 0.85 }}>{booking.workspace_name}</div>
            <div className="small" style={{ opacity: 0.7 }}>Booking #{booking.id.slice(0, 8)}</div>
          </div>
          <div className="text-end">
            <div className="small" style={{ opacity: 0.85 }}>Amount due</div>
            <div className="fw-bold fs-3 text-white">{currency(booking.total_price)}</div>
          </div>
        </div>
      </div>

      {/* Accounts */}
      <div className="card-clean p-4 mb-3">
        <h6 className="fw-bold mb-3">Choose a payment method</h6>
        {accounts.length === 0 ? (
          <p className="text-secondary mb-0">The owner hasn't added any payment accounts yet. Please contact them.</p>
        ) : (
          <div className="d-flex flex-column gap-2">
            {accounts.map((a) => {
              const meta = ACCOUNT_META[a.account_type] || ACCOUNT_META.bank
              const active = selectedAccount?.id === a.id
              return (
                <button key={a.id} className={`card-clean p-3 text-start border-0 ${active ? 'border border-primary' : ''}`} style={active ? { boxShadow: '0 0 0 2px var(--primary)' } : {}} onClick={() => setSelectedAccount(a)}>
                  <div className="d-flex align-items-center gap-3">
                    <div className="stat-icon" style={{ background: 'var(--primary-gradient)' }}><i className={`bi ${meta.icon} text-white`}></i></div>
                    <div className="flex-fill">
                      <div className="fw-semibold">{meta.label} {a.bank_name && `· ${a.bank_name}`}</div>
                      <div className="small text-secondary">{a.account_title} — {a.account_number}</div>
                    </div>
                    {active && <i className="bi bi-check-circle-fill text-primary fs-5"></i>}
                  </div>
                </button>
              )
            })}
          </div>
        )}
      </div>

      {/* Upload */}
      {accounts.length > 0 && (
        <div className="card-clean p-4 mb-3">
          <h6 className="fw-bold mb-3">Upload receipt</h6>
          <div className="mb-3">
            <label className="form-label">Transaction reference <span className="text-secondary fw-normal">(optional)</span></label>
            <input className="form-control" placeholder="TID / reference number" value={reference} onChange={(e) => setReference(e.target.value)} />
          </div>
          <label className="form-label">Receipt image</label>
          <input type="file" className="form-control" accept="image/*" onChange={(e) => setFile(e.target.files[0])} />
          {file && (
            <div className="mt-3 text-center">
              <img src={URL.createObjectURL(file)} alt="receipt" style={{ maxHeight: 220, borderRadius: 12 }} />
            </div>
          )}
          <button className="btn btn-primary btn-lg w-100 mt-3" onClick={submit} disabled={submitting}>
            {submitting ? <span className="spinner-border spinner-border-sm me-2"></span> : <i className="bi bi-cloud-upload me-2"></i>}
            Submit Receipt
          </button>
        </div>
      )}
    </div>
  )
}
