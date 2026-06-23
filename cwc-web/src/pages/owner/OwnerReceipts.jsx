import { useEffect, useState } from 'react'
import { paymentService } from '../../services/paymentService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { Loading, EmptyState, Modal } from '../../components/common'
import { currency } from '../../lib/constants'
import { fmtDateTime } from '../../lib/helpers'

export default function OwnerReceipts({ embedded = false }) {
  const { userId } = useAuth()
  const toast = useToast()
  const [receipts, setReceipts] = useState([])
  const [loading, setLoading] = useState(true)
  const [preview, setPreview] = useState(null)
  const [rejecting, setRejecting] = useState(null)
  const [reason, setReason] = useState('')

  const load = async () => {
    try {
      setReceipts(await paymentService.getPendingReceiptsForOwner(userId))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { if (userId) load() }, [userId])

  const approve = async (p) => {
    try {
      await paymentService.approve(p)
      toast.success('Payment approved — booking confirmed')
      load()
    } catch (err) { toast.error(err.message) }
  }

  const doReject = async () => {
    try {
      await paymentService.reject(rejecting, reason)
      toast.success('Receipt rejected')
      setRejecting(null)
      setReason('')
      load()
    } catch (err) { toast.error(err.message) }
  }

  if (loading) return <Loading />

  const Wrapper = embedded ? 'div' : 'div'

  return (
    <Wrapper className={embedded ? '' : 'container-app'} style={embedded ? {} : { maxWidth: 820 }}>
      {!embedded && (
        <h3 className="fw-bold mb-3">Payment Receipts</h3>
      )}

      {receipts.length === 0 ? (
        <EmptyState icon="bi-receipt-cutoff" title="No pending receipts" subtitle="Submitted receipts will appear here for verification." />
      ) : (
        <div className="d-flex flex-column gap-3">
          {receipts.map((p) => (
            <div className="card-clean p-3" key={p.id}>
              <div className="d-flex justify-content-between align-items-start">
                <div>
                  <h6 className="fw-bold mb-1">{p.bookings?.workspace_name || 'Booking'}</h6>
                  <div className="small text-secondary">{fmtDateTime(p.created_at)}</div>
                  {p.transfer_reference && <div className="small text-secondary">Ref: {p.transfer_reference}</div>}
                </div>
                <span className="fw-bold text-primary">{currency(p.amount)}</span>
              </div>
              {p.receipt_url && (
                <img src={p.receipt_url} alt="receipt" style={{ maxHeight: 160, borderRadius: 10, cursor: 'pointer' }} className="mt-2" onClick={() => setPreview(p.receipt_url)} />
              )}
              <div className="d-flex gap-2 mt-3">
                <button className="btn btn-success btn-sm flex-fill" onClick={() => approve(p)}><i className="bi bi-check-lg me-1"></i>Approve</button>
                <button className="btn btn-light btn-sm flex-fill text-danger" onClick={() => setRejecting(p)}><i className="bi bi-x-lg me-1"></i>Reject</button>
              </div>
            </div>
          ))}
        </div>
      )}

      {preview && (
        <Modal show onClose={() => setPreview(null)} title="Receipt">
          <img src={preview} alt="receipt" style={{ width: '100%', borderRadius: 10 }} />
        </Modal>
      )}

      {rejecting && (
        <Modal show onClose={() => setRejecting(null)} title="Reject receipt" footer={
          <>
            <button className="btn btn-light" onClick={() => setRejecting(null)}>Cancel</button>
            <button className="btn btn-danger" onClick={doReject}>Reject</button>
          </>
        }>
          <label className="form-label">Reason (optional)</label>
          <textarea className="form-control" rows={3} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Let the user know why..." />
        </Modal>
      )}
    </Wrapper>
  )
}
