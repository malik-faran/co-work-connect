import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { Star, RefreshCw, Search, MessageSquare, Trash2 } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'

const Reviews = () => {
  const [reviews, setReviews] = useState([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [filter, setFilter] = useState('all') // all, high (4-5), low (1-2), medium (3)
  const [deletingId, setDeletingId] = useState(null)

  useEffect(() => {
    fetchReviews()
  }, [filter])

  const fetchReviews = async () => {
    try {
      setLoading(true)
      const { data, error } = await supabase
        .from('reviews')
        .select(`
          *,
          workspaces(name),
          users(name, email)
        `)
        .order('created_at', { ascending: false })

      if (error) throw error

      let filtered = data || []
      
      // Apply rating filter
      if (filter === 'high') {
        filtered = filtered.filter(r => r.rating >= 4)
      } else if (filter === 'low') {
        filtered = filtered.filter(r => r.rating <= 2)
      } else if (filter === 'medium') {
        filtered = filtered.filter(r => r.rating === 3)
      }

      setReviews(filtered)
    } catch (error) {
      console.error('Error fetching reviews:', error)
      showError('Failed to load reviews: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  const handleDeleteReview = async (reviewId, userName) => {
    if (!confirm(`Are you sure you want to delete the review by "${userName}"?\n\nThis action cannot be undone.`)) {
      return
    }

    try {
      setDeletingId(reviewId)
      const { error } = await supabase
        .from('reviews')
        .delete()
        .eq('id', reviewId)

      if (error) throw error

      showSuccess('Review deleted successfully')
      fetchReviews()
    } catch (error) {
      console.error('Error deleting review:', error)
      showError('Failed to delete review: ' + error.message)
    } finally {
      setDeletingId(null)
    }
  }

  const filteredReviews = reviews.filter(review => {
    if (!searchQuery) return true
    const query = searchQuery.toLowerCase()
    return (
      review.users?.name?.toLowerCase().includes(query) ||
      review.workspaces?.name?.toLowerCase().includes(query) ||
      review.comment?.toLowerCase().includes(query)
    )
  })

  const getRatingColor = (rating) => {
    if (rating >= 4) return '#10b981'
    if (rating >= 3) return '#f59e0b'
    return '#ef4444'
  }

  if (loading) {
    return <Loading message="Loading reviews..." />
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
            Reviews & Ratings
          </h1>
          <p style={{ 
            color: '#64748b', 
            fontSize: '16px',
            fontWeight: '500'
          }}>
            Manage all workspace reviews and ratings
          </p>
        </div>
        
        <div style={{ 
          display: 'flex', 
          gap: '12px',
          alignItems: 'center'
        }}>
          <button
            onClick={fetchReviews}
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

      {/* Filters */}
      <div style={{
        background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
        backdropFilter: 'blur(10px)',
        padding: '24px',
        borderRadius: '16px',
        marginBottom: '24px',
        boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
        border: '1px solid rgba(255, 255, 255, 0.2)',
        display: 'flex',
        gap: '16px',
        flexWrap: 'wrap',
        alignItems: 'center'
      }}>
        {/* Search */}
        <div style={{ position: 'relative', flex: '1', minWidth: '250px' }}>
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
            placeholder="Search by user, workspace, or comment..."
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

        {/* Rating Filter */}
        <select
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          style={{
            padding: '10px 16px',
            border: '1px solid #e2e8f0',
            borderRadius: '8px',
            fontSize: '14px',
            backgroundColor: 'white',
            cursor: 'pointer',
            outline: 'none',
            minWidth: '150px',
            transition: 'border-color 0.2s'
          }}
          onFocus={(e) => e.target.style.borderColor = '#3b82f6'}
          onBlur={(e) => e.target.style.borderColor = '#e2e8f0'}
        >
          <option value="all">All Ratings</option>
          <option value="high">High (4-5 stars)</option>
          <option value="medium">Medium (3 stars)</option>
          <option value="low">Low (1-2 stars)</option>
        </select>

        {/* Count */}
        <div style={{
          padding: '8px 16px',
          backgroundColor: '#f1f5f9',
          borderRadius: '8px',
          fontSize: '14px',
          color: '#475569',
          fontWeight: '500'
        }}>
          {filteredReviews.length} {filteredReviews.length === 1 ? 'review' : 'reviews'}
        </div>
      </div>

      {/* Reviews List */}
      {filteredReviews.length === 0 ? (
        <EmptyState
          icon={Star}
          title={searchQuery ? "No reviews found" : "No reviews yet"}
          message={searchQuery ? "Try adjusting your search or filter" : "Reviews will appear here once users submit them"}
        />
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {filteredReviews.map((review) => (
            <div
              key={review.id}
              style={{
                background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
                backdropFilter: 'blur(10px)',
                padding: '24px',
                borderRadius: '16px',
                boxShadow: '0 4px 20px rgba(0, 0, 0, 0.08)',
                border: '1px solid rgba(255, 255, 255, 0.2)',
                borderLeft: `4px solid ${getRatingColor(review.rating)}`,
                transition: 'all 0.3s'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-2px)'
                e.currentTarget.style.boxShadow = '0 8px 24px rgba(0, 0, 0, 0.12)'
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)'
                e.currentTarget.style.boxShadow = '0 4px 20px rgba(0, 0, 0, 0.08)'
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', gap: '20px' }}>
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px' }}>
                    <h3 style={{ 
                      fontSize: '18px', 
                      fontWeight: '600', 
                      color: '#1e293b' 
                    }}>
                      {review.users?.name || 'Unknown User'}
                    </h3>
                    <span style={{
                      padding: '4px 10px',
                      borderRadius: '6px',
                      fontSize: '11px',
                      fontWeight: '600',
                      backgroundColor: getRatingColor(review.rating) + '20',
                      color: getRatingColor(review.rating)
                    }}>
                      {review.workspaces?.name || 'Unknown Workspace'}
                    </span>
                  </div>

                  {/* Rating Stars */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
                    {[1, 2, 3, 4, 5].map((star) => (
                      <Star
                        key={star}
                        size={18}
                        fill={star <= review.rating ? getRatingColor(review.rating) : 'none'}
                        color={star <= review.rating ? getRatingColor(review.rating) : '#e2e8f0'}
                      />
                    ))}
                    <span style={{
                      marginLeft: '8px',
                      fontSize: '14px',
                      fontWeight: '600',
                      color: getRatingColor(review.rating)
                    }}>
                      {(review.rating ?? 0).toFixed(1)} / 5.0
                    </span>
                  </div>

                  {/* Comment */}
                  {review.comment && (
                    <div style={{
                      padding: '12px',
                      background: '#f8fafc',
                      borderRadius: '8px',
                      marginBottom: '12px',
                      fontSize: '14px',
                      color: '#64748b',
                      lineHeight: '1.6'
                    }}>
                      <MessageSquare size={16} style={{ display: 'inline', marginRight: '6px', verticalAlign: 'middle' }} />
                      {review.comment}
                    </div>
                  )}

                  <div style={{ 
                    fontSize: '12px', 
                    color: '#94a3b8',
                    paddingTop: '12px',
                    borderTop: '1px solid #f1f5f9'
                  }}>
                    {format(new Date(review.created_at), 'MMM dd, yyyy • hh:mm a')}
                  </div>
                </div>

                <div style={{ flexShrink: 0 }}>
                  <button
                    onClick={() => handleDeleteReview(review.id, review.users?.name)}
                    disabled={deletingId === review.id}
                    style={{
                      padding: '10px 16px',
                      background: deletingId === review.id 
                        ? 'linear-gradient(135deg, #94a3b8 0%, #64748b 100%)' 
                        : 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)',
                      color: 'white',
                      border: 'none',
                      borderRadius: '10px',
                      cursor: deletingId === review.id ? 'not-allowed' : 'pointer',
                      fontSize: '13px',
                      fontWeight: '600',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '8px',
                      transition: 'all 0.3s',
                      boxShadow: deletingId === review.id ? 'none' : '0 4px 12px rgba(239, 68, 68, 0.3)'
                    }}
                    onMouseEnter={(e) => {
                      if (deletingId !== review.id) {
                        e.target.style.transform = 'translateY(-2px)'
                        e.target.style.boxShadow = '0 6px 16px rgba(239, 68, 68, 0.4)'
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (deletingId !== review.id) {
                        e.target.style.transform = 'translateY(0)'
                        e.target.style.boxShadow = '0 4px 12px rgba(239, 68, 68, 0.3)'
                      }
                    }}
                  >
                    <Trash2 size={16} />
                    {deletingId === review.id ? 'Deleting...' : 'Delete'}
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default Reviews
