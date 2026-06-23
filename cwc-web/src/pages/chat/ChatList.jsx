import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { chatService } from '../../services/chatService'
import { useAuth } from '../../context/AuthContext'
import { Loading, EmptyState, Avatar } from '../../components/common'
import { timeAgo } from '../../lib/helpers'

export default function ChatList() {
  const { userId } = useAuth()
  const navigate = useNavigate()
  const [rooms, setRooms] = useState([])
  const [loading, setLoading] = useState(true)

  const load = async () => {
    try {
      setRooms(await chatService.getUserChatRooms(userId))
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (!userId) return
    load()
    const unsub = chatService.subscribeRooms(userId, load)
    return unsub
  }, [userId])

  const roomInfo = (r) => {
    if (r.room_type === 'group') {
      return { name: r.name || 'Group', img: null, unread: 0, group: true }
    }
    const isU1 = r.user1_id === userId
    return {
      name: isU1 ? r.user2_name : r.user1_name,
      img: isU1 ? r.user2_profile_image : r.user1_profile_image,
      unread: isU1 ? r.unread_count1 : r.unread_count2,
      group: false,
    }
  }

  if (loading) return <Loading message="Loading messages..." />

  return (
    <div className="container-app" style={{ maxWidth: 720 }}>
      <h3 className="fw-bold mb-3">Messages</h3>
      {rooms.length === 0 ? (
        <EmptyState icon="bi-chat-dots" title="No conversations yet" subtitle="Message a workspace owner or your project team to get started." />
      ) : (
        <div className="card-clean overflow-hidden">
          {rooms.map((r, i) => {
            const info = roomInfo(r)
            return (
              <button key={r.id} className={`d-flex align-items-center gap-3 p-3 w-100 text-start border-0 bg-transparent ${i ? 'border-top' : ''}`} onClick={() => navigate(`/chats/${r.id}`)}>
                {info.group ? (
                  <span className="avatar-fallback" style={{ width: 48, height: 48, background: 'var(--cool-gradient)' }}><i className="bi bi-people"></i></span>
                ) : (
                  <Avatar src={info.img} name={info.name} size={48} />
                )}
                <div className="flex-fill min-w-0">
                  <div className="d-flex justify-content-between">
                    <span className="fw-semibold line-clamp-1">{info.name || 'Conversation'}</span>
                    <span className="small text-tertiary">{timeAgo(r.last_message_at || r.created_at)}</span>
                  </div>
                  <div className="small text-secondary line-clamp-1">{r.last_message || 'No messages yet'}</div>
                </div>
                {info.unread > 0 && <span className="badge rounded-pill bg-primary">{info.unread}</span>}
              </button>
            )
          })}
        </div>
      )}
    </div>
  )
}
