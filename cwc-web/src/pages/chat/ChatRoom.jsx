import { useEffect, useState, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { chatService } from '../../services/chatService'
import { storageService } from '../../services/storageService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { Loading, Avatar } from '../../components/common'
import { fmtDate } from '../../lib/helpers'

export default function ChatRoom() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { userId, profile } = useAuth()
  const toast = useToast()

  const [room, setRoom] = useState(null)
  const [messages, setMessages] = useState([])
  const [text, setText] = useState('')
  const [loading, setLoading] = useState(true)
  const [sending, setSending] = useState(false)
  const endRef = useRef(null)

  const load = async () => {
    try {
      const r = await chatService.getRoom(id)
      setRoom(r)
      setMessages(await chatService.getMessages(id))
      await chatService.markRead(id, userId)
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (userId) load()
  }, [id, userId])

  useEffect(() => {
    const unsub = chatService.subscribeMessages(id, (payload) => {
      setMessages((prev) => (prev.find((m) => m.id === payload.new.id) ? prev : [...prev, payload.new]))
      if (payload.new.sender_id !== userId) chatService.markRead(id, userId)
    })
    return unsub
  }, [id, userId])

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const title = () => {
    if (!room) return 'Chat'
    if (room.room_type === 'group') return room.name || 'Group'
    return room.user1_id === userId ? room.user2_name : room.user1_name
  }
  const titleImg = () => {
    if (!room || room.room_type === 'group') return null
    return room.user1_id === userId ? room.user2_profile_image : room.user1_profile_image
  }

  const send = async () => {
    if (!text.trim() || !room) return
    const t = text
    setText('')
    setSending(true)
    try {
      await chatService.sendMessage({ room, senderId: userId, senderName: profile?.name, senderImage: profile?.profile_image_url, message: t })
    } catch (err) {
      toast.error('Failed to send')
    } finally {
      setSending(false)
    }
  }

  const sendImage = async (e) => {
    const f = e.target.files[0]
    if (!f || !room) return
    try {
      const url = await storageService.uploadChatImage(room.id, userId, f)
      await chatService.sendMessage({ room, senderId: userId, senderName: profile?.name, senderImage: profile?.profile_image_url, message: '📷 Photo', type: 'image', imageUrl: url })
    } catch (err) {
      toast.error('Could not send image')
    }
  }

  if (loading) return <Loading />

  let lastDate = null

  return (
    <div className="container-app" style={{ maxWidth: 760 }}>
      <div className="card-clean p-3 mb-2 d-flex align-items-center gap-3">
        <button className="btn btn-light btn-sm" onClick={() => navigate('/chats')}><i className="bi bi-arrow-left"></i></button>
        {room?.room_type === 'group' ? (
          <span className="avatar-fallback" style={{ width: 40, height: 40, background: 'var(--cool-gradient)' }}><i className="bi bi-people"></i></span>
        ) : (
          <Avatar src={titleImg()} name={title()} size={40} />
        )}
        <div>
          <div className="fw-semibold">{title()}</div>
          {room?.room_type === 'group' && <div className="small text-secondary">Project team</div>}
        </div>
      </div>

      <div className="chat-window">
        {messages.map((m) => {
          const me = m.sender_id === userId
          const d = fmtDate(m.created_at)
          const showDate = d !== lastDate
          lastDate = d
          return (
            <div key={m.id}>
              {showDate && <div className="text-center my-2"><span className="badge-soft badge-neutral-soft">{d}</span></div>}
              <div className={`d-flex ${me ? 'justify-content-end' : 'justify-content-start'} mb-1`}>
                <div>
                  {!me && room?.room_type === 'group' && <div className="small text-secondary ms-2">{m.sender_name?.split(' ')[0]}</div>}
                  <div className={`bubble ${me ? 'bubble-me' : 'bubble-them'}`}>
                    {m.message_type === 'image' && m.image_url ? (
                      <img src={m.image_url} alt="" style={{ maxWidth: 220, borderRadius: 10, cursor: 'pointer' }} onClick={() => window.open(m.image_url, '_blank')} />
                    ) : (
                      m.message
                    )}
                  </div>
                  <div className={`small text-tertiary ${me ? 'text-end' : ''}`} style={{ fontSize: '0.68rem' }}>{fmtDate(m.created_at, 'hh:mm a')}</div>
                </div>
              </div>
            </div>
          )
        })}
        <div ref={endRef} />
      </div>

      <div className="d-flex gap-2 mt-2">
        <label className="btn btn-light mb-0"><i className="bi bi-image"></i><input type="file" accept="image/*" hidden onChange={sendImage} /></label>
        <input className="form-control" placeholder="Type a message..." value={text} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && send()} />
        <button className="btn btn-primary" onClick={send} disabled={sending}><i className="bi bi-send"></i></button>
      </div>
    </div>
  )
}
