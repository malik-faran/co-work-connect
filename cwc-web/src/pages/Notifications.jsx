import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { notificationService } from '../services/notificationService'
import { collaborationService } from '../services/collaborationService'
import { useAuth } from '../context/AuthContext'
import { useToast } from '../context/ToastContext'
import { Loading, EmptyState } from '../components/common'
import { timeAgo } from '../lib/helpers'

const ICONS = {
  booking_confirmed: { icon: 'bi-calendar-check', color: 'var(--success)' },
  booking_cancelled: { icon: 'bi-calendar-x', color: 'var(--error)' },
  chat_message: { icon: 'bi-chat-dots', color: 'var(--primary)' },
  payment_receipt: { icon: 'bi-receipt', color: 'var(--warning)' },
  payment_rejected: { icon: 'bi-x-circle', color: 'var(--error)' },
  collaboration_application: { icon: 'bi-person-plus', color: 'var(--primary)' },
  collaboration_shortlisted: { icon: 'bi-star', color: 'var(--info)' },
  collaboration_rejected: { icon: 'bi-dash-circle', color: 'var(--error)' },
  collaboration_launched: { icon: 'bi-rocket-takeoff', color: 'var(--success)' },
  collaboration_invite: { icon: 'bi-envelope-paper', color: 'var(--primary)' },
  collaboration_completed: { icon: 'bi-flag', color: 'var(--success)' },
}

export default function Notifications() {
  const { userId, profile } = useAuth()
  const navigate = useNavigate()
  const toast = useToast()
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)

  const load = async () => {
    try {
      setItems(await notificationService.getForUser(userId))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (!userId) return
    load()
    const unsub = notificationService.subscribe(userId, load)
    return unsub
  }, [userId])

  const open = async (n) => {
    if (!n.is_read) {
      await notificationService.markRead(n.id)
      setItems((prev) => prev.map((x) => (x.id === n.id ? { ...x, is_read: true } : x)))
    }
    const meta = n.metadata || {}
    if (n.type === 'chat_message' && meta.chat_room_id) navigate(`/chats/${meta.chat_room_id}`)
    else if (meta.collaboration_id) navigate(`/collaborations/${meta.collaboration_id}`)
    else if (meta.booking_id) navigate('/bookings')
  }

  const respondInvite = async (n, accept) => {
    try {
      const invites = await collaborationService.getMyInvites(userId)
      const inv = invites.find((i) => i.id === n.metadata?.invite_id) || invites.find((i) => i.collaboration_id === n.metadata?.collaboration_id)
      if (!inv) return toast.error('Invite no longer available')
      await collaborationService.respondInvite(inv, accept, profile)
      await notificationService.markRead(n.id)
      toast.success(accept ? 'Invite accepted!' : 'Declined')
      load()
    } catch (err) {
      toast.error(err.message || 'Failed')
    }
  }

  const markAll = async () => {
    await notificationService.markAllRead(userId)
    load()
  }

  if (loading) return <Loading />

  return (
    <div className="container-app" style={{ maxWidth: 720 }}>
      <div className="d-flex justify-content-between align-items-center mb-3">
        <h3 className="fw-bold mb-0">Notifications</h3>
        {items.some((n) => !n.is_read) && <button className="btn btn-light btn-sm" onClick={markAll}>Mark all read</button>}
      </div>

      {items.length === 0 ? (
        <EmptyState icon="bi-bell" title="No notifications" subtitle="You're all caught up!" />
      ) : (
        <div className="card-clean overflow-hidden">
          {items.map((n, i) => {
            const meta = ICONS[n.type] || { icon: 'bi-bell', color: 'var(--text-secondary)' }
            return (
              <div key={n.id} className={`d-flex gap-3 p-3 ${i ? 'border-top' : ''} ${!n.is_read ? '' : 'opacity-75'}`} style={{ cursor: 'pointer', background: !n.is_read ? '#f7f9ff' : '#fff' }} onClick={() => open(n)}>
                <div className="stat-icon" style={{ background: '#eef2ff', color: meta.color, width: 42, height: 42 }}><i className={`bi ${meta.icon}`}></i></div>
                <div className="flex-fill">
                  <div className="d-flex justify-content-between">
                    <span className="fw-semibold">{n.title}</span>
                    <span className="small text-tertiary">{timeAgo(n.created_at)}</span>
                  </div>
                  <div className="small text-secondary">{n.message}</div>
                  {n.type === 'collaboration_invite' && (
                    <div className="d-flex gap-2 mt-2" onClick={(e) => e.stopPropagation()}>
                      <button className="btn btn-primary btn-sm" onClick={() => respondInvite(n, true)}>Accept</button>
                      <button className="btn btn-light btn-sm" onClick={() => respondInvite(n, false)}>Decline</button>
                    </div>
                  )}
                </div>
                {!n.is_read && <span className="rounded-circle bg-primary align-self-center" style={{ width: 8, height: 8 }}></span>}
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
