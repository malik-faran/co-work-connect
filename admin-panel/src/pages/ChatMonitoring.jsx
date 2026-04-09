import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { MessageSquare, RefreshCw, Search, Eye, Trash2 } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'

const ChatMonitoring = () => {
  const [chatRooms, setChatRooms] = useState([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedRoom, setSelectedRoom] = useState(null)
  const [messages, setMessages] = useState([])
  const [loadingMessages, setLoadingMessages] = useState(false)
  const [deletingId, setDeletingId] = useState(null)
  const [isMobile, setIsMobile] = useState(window.innerWidth < 768)

  useEffect(() => {
    const handleResize = () => setIsMobile(window.innerWidth < 768)
    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  useEffect(() => {
    fetchChatRooms()
  }, [])

  const fetchChatRooms = async () => {
    try {
      setLoading(true)
      const { data, error } = await supabase
        .from('chat_rooms')
        .select('*')
        .order('last_message_at', { ascending: false })

      if (error) throw error
      setChatRooms(data || [])
    } catch (error) {
      console.error('Error fetching chat rooms:', error)
      showError('Failed to load chat rooms: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  const fetchMessages = async (roomId) => {
    try {
      setLoadingMessages(true)
      const { data, error } = await supabase
        .from('messages')
        .select('*')
        .eq('chat_room_id', roomId)
        .order('created_at', { ascending: true })

      if (error) throw error
      setMessages(data || [])
    } catch (error) {
      console.error('Error fetching messages:', error)
      showError('Failed to load messages: ' + error.message)
    } finally {
      setLoadingMessages(false)
    }
  }

  const handleViewMessages = (room) => {
    setSelectedRoom(room)
    fetchMessages(room.id)
  }

  const handleDeleteRoom = async (roomId) => {
    if (!confirm('Are you sure you want to delete this chat room?\n\nAll messages will also be deleted.')) {
      return
    }

    try {
      setDeletingId(roomId)
      
      // Delete messages first
      await supabase
        .from('messages')
        .delete()
        .eq('chat_room_id', roomId)

      // Then delete the room
      const { error } = await supabase
        .from('chat_rooms')
        .delete()
        .eq('id', roomId)

      if (error) throw error

      showSuccess('Chat room deleted successfully')
      fetchChatRooms()
      if (selectedRoom?.id === roomId) {
        setSelectedRoom(null)
        setMessages([])
      }
    } catch (error) {
      console.error('Error deleting chat room:', error)
      showError('Failed to delete chat room: ' + error.message)
    } finally {
      setDeletingId(null)
    }
  }

  const filteredRooms = chatRooms.filter(room => {
    if (!searchQuery) return true
    const query = searchQuery.toLowerCase()
    return (
      room.user1_name?.toLowerCase().includes(query) ||
      room.user2_name?.toLowerCase().includes(query) ||
      room.last_message?.toLowerCase().includes(query)
    )
  })

  if (loading) {
    return <Loading message="Loading chat rooms..." />
  }

  return (
    <div className="fade-in">
      {/* Header */}
      <div style={{ 
        background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
        backdropFilter: 'blur(10px)',
        padding: '32px',
        borderRadius: '20px',
        boxShadow: '0 8px 32px rgba(0, 0, 0, 0.1)',
        border: '1px solid rgba(255, 255, 255, 0.2)',
        marginBottom: '32px',
        display: 'flex', 
        justifyContent: 'space-between', 
        alignItems: 'center', 
        flexWrap: 'wrap',
        gap: '20px'
      }}>
        <div>
          <h1 style={{ 
            fontSize: 'clamp(24px, 5vw, 42px)', 
            fontWeight: '800',
            background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            backgroundClip: 'text',
            marginBottom: '12px',
            letterSpacing: '-0.5px'
          }}>
            Chat Monitoring
          </h1>
          <p style={{ 
            color: '#64748b', 
            fontSize: '16px',
            fontWeight: '500'
          }}>
            Monitor and manage user conversations
          </p>
        </div>
        
        <div style={{ 
          display: 'flex', 
          gap: '12px',
          alignItems: 'center'
        }}>
          <button
            onClick={fetchChatRooms}
            style={{
              padding: '12px 20px',
              background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
              color: 'white',
              border: 'none',
              borderRadius: '12px',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '600',
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              boxShadow: '0 4px 12px rgba(99, 102, 241, 0.3)',
              transition: 'all 0.3s'
            }}
            onMouseEnter={(e) => {
              e.target.style.transform = 'translateY(-2px)'
              e.target.style.boxShadow = '0 6px 16px rgba(99, 102, 241, 0.4)'
            }}
            onMouseLeave={(e) => {
              e.target.style.transform = 'translateY(0)'
              e.target.style.boxShadow = '0 4px 12px rgba(99, 102, 241, 0.3)'
            }}
          >
            <RefreshCw size={18} />
            Refresh
          </button>
        </div>
      </div>

      {/* Search */}
      <div style={{
        background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
        backdropFilter: 'blur(10px)',
        padding: '24px',
        borderRadius: '16px',
        marginBottom: '24px',
        boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
        border: '1px solid rgba(255, 255, 255, 0.2)'
      }}>
        <div style={{ position: 'relative' }}>
          <Search 
            size={18} 
            style={{
              position: 'absolute',
              left: '12px',
              top: '50%',
              transform: 'translateY(-50%)',
              color: '#94a3b8'
            }}
          />
          <input
            type="text"
            placeholder="Search by user names or message content..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            style={{
              width: '100%',
              padding: '10px 12px 10px 40px',
              border: '1px solid #e2e8f0',
              borderRadius: '8px',
              fontSize: '14px',
              outline: 'none',
              transition: 'border-color 0.2s'
            }}
            onFocus={(e) => e.target.style.borderColor = '#3b82f6'}
            onBlur={(e) => e.target.style.borderColor = '#e2e8f0'}
          />
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: selectedRoom && !isMobile ? 'minmax(0, 1fr) minmax(0, 1fr)' : '1fr', gap: '24px' }}>
        {/* Chat Rooms List */}
        <div>
          {filteredRooms.length === 0 ? (
            <EmptyState
              icon={MessageSquare}
              title={searchQuery ? "No chat rooms found" : "No chat rooms yet"}
              message={searchQuery ? "Try adjusting your search" : "Chat rooms will appear here once users start conversations"}
            />
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              {filteredRooms.map((room) => (
                <div
                  key={room.id}
                  style={{
                    background: selectedRoom?.id === room.id
                      ? 'linear-gradient(135deg, rgba(99, 102, 241, 0.1) 0%, rgba(139, 92, 246, 0.1) 100%)'
                      : 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
                    backdropFilter: 'blur(10px)',
                    padding: '20px',
                    borderRadius: '16px',
                    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
                    border: selectedRoom?.id === room.id
                      ? '2px solid #6366f1'
                      : '1px solid rgba(255, 255, 255, 0.2)',
                    transition: 'all 0.3s',
                    cursor: 'pointer'
                  }}
                  onClick={() => handleViewMessages(room)}
                  onMouseEnter={(e) => {
                    if (selectedRoom?.id !== room.id) {
                      e.currentTarget.style.transform = 'translateY(-2px)'
                      e.currentTarget.style.boxShadow = '0 8px 24px rgba(0, 0, 0, 0.12)'
                    }
                  }}
                  onMouseLeave={(e) => {
                    if (selectedRoom?.id !== room.id) {
                      e.currentTarget.style.transform = 'translateY(0)'
                      e.currentTarget.style.boxShadow = '0 4px 20px rgba(0, 0, 0, 0.08)'
                    }
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', gap: '12px' }}>
                    <div style={{ flex: 1 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px' }}>
                        <h3 style={{ 
                          fontSize: '16px', 
                          fontWeight: '600', 
                          color: '#1e293b' 
                        }}>
                          {room.user1_name} ↔ {room.user2_name}
                        </h3>
                        {(room.unread_count1 > 0 || room.unread_count2 > 0) && (
                          <span style={{
                            padding: '2px 8px',
                            borderRadius: '12px',
                            fontSize: '10px',
                            fontWeight: '700',
                            backgroundColor: '#ef4444',
                            color: 'white'
                          }}>
                            {room.unread_count1 + room.unread_count2}
                          </span>
                        )}
                      </div>
                      
                      {room.last_message && (
                        <p style={{ 
                          color: '#64748b', 
                          fontSize: '13px',
                          marginBottom: '8px',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap'
                        }}>
                          {room.last_message}
                        </p>
                      )}

                      {room.last_message_at && (
                        <div style={{ 
                          fontSize: '11px', 
                          color: '#94a3b8'
                        }}>
                          {format(new Date(room.last_message_at), 'MMM dd, yyyy • hh:mm a')}
                        </div>
                      )}
                    </div>

                    <div style={{ display: 'flex', gap: '8px', flexShrink: 0 }}>
                      <button
                        onClick={(e) => {
                          e.stopPropagation()
                          handleViewMessages(room)
                        }}
                        style={{
                          padding: '8px 12px',
                          background: 'linear-gradient(135deg, #3b82f6 0%, #2563eb 100%)',
                          color: 'white',
                          border: 'none',
                          borderRadius: '8px',
                          cursor: 'pointer',
                          fontSize: '12px',
                          fontWeight: '600',
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '6px',
                          transition: 'all 0.3s'
                        }}
                      >
                        <Eye size={14} />
                        View
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation()
                          handleDeleteRoom(room.id)
                        }}
                        disabled={deletingId === room.id}
                        style={{
                          padding: '8px 12px',
                          background: deletingId === room.id 
                            ? 'linear-gradient(135deg, #94a3b8 0%, #64748b 100%)' 
                            : 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)',
                          color: 'white',
                          border: 'none',
                          borderRadius: '8px',
                          cursor: deletingId === room.id ? 'not-allowed' : 'pointer',
                          fontSize: '12px',
                          fontWeight: '600',
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '6px',
                          transition: 'all 0.3s'
                        }}
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Messages View */}
        {selectedRoom && (
          <div style={{
            background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
            backdropFilter: 'blur(10px)',
            padding: '24px',
            borderRadius: '16px',
            boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
            border: '1px solid rgba(255, 255, 255, 0.2)',
            maxHeight: '600px',
            display: 'flex',
            flexDirection: 'column'
          }}>
            <div style={{ 
              display: 'flex', 
              justifyContent: 'space-between', 
              alignItems: 'center',
              marginBottom: '20px',
              paddingBottom: '16px',
              borderBottom: '1px solid #e2e8f0'
            }}>
              <div>
                <h3 style={{ fontSize: '18px', fontWeight: '700', color: '#1e293b', marginBottom: '4px' }}>
                  {selectedRoom.user1_name} ↔ {selectedRoom.user2_name}
                </h3>
                <p style={{ fontSize: '12px', color: '#94a3b8' }}>
                  Chat Room Messages
                </p>
              </div>
              <button
                onClick={() => {
                  setSelectedRoom(null)
                  setMessages([])
                }}
                style={{
                  padding: '8px 12px',
                  background: '#f1f5f9',
                  color: '#64748b',
                  border: 'none',
                  borderRadius: '8px',
                  cursor: 'pointer',
                  fontSize: '12px',
                  fontWeight: '600'
                }}
              >
                Close
              </button>
            </div>

            {loadingMessages ? (
              <div style={{ textAlign: 'center', padding: '40px' }}>
                <Loading message="Loading messages..." />
              </div>
            ) : messages.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '40px', color: '#94a3b8' }}>
                No messages in this chat room
              </div>
            ) : (
              <div style={{ 
                flex: 1, 
                overflowY: 'auto',
                display: 'flex',
                flexDirection: 'column',
                gap: '12px'
              }}>
                {messages.map((msg) => (
                  <div
                    key={msg.id}
                    style={{
                      padding: '12px 16px',
                      background: '#f8fafc',
                      borderRadius: '12px',
                      borderLeft: '3px solid #6366f1'
                    }}
                  >
                    <div style={{ 
                      display: 'flex', 
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      marginBottom: '8px'
                    }}>
                      <span style={{ 
                        fontSize: '13px', 
                        fontWeight: '600', 
                        color: '#1e293b' 
                      }}>
                        {msg.sender_name}
                      </span>
                      <span style={{ 
                        fontSize: '11px', 
                        color: '#94a3b8' 
                      }}>
                        {format(new Date(msg.created_at), 'MMM dd, hh:mm a')}
                      </span>
                    </div>
                    <p style={{ 
                      fontSize: '14px', 
                      color: '#64748b',
                      lineHeight: '1.5',
                      margin: 0
                    }}>
                      {msg.message}
                    </p>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

export default ChatMonitoring
