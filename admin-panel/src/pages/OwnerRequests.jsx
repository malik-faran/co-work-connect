import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { Check, X, Mail, Phone, Building, RefreshCw, ClipboardCheck, AlertCircle, FileText, Search } from 'lucide-react'
import Loading from '../components/Loading'
import EmptyState from '../components/EmptyState'
import { showSuccess, showError } from '../utils/toast'
import { recordStaffAction } from '../lib/auditLog'

const OwnerRequests = () => {
  const [requests, setRequests] = useState([])
  const [loading, setLoading] = useState(true)
  const [selectedRequest, setSelectedRequest] = useState(null)
  const [rejectionReason, setRejectionReason] = useState('')
  const [showRejectForm, setShowRejectForm] = useState(false)
  const [zoomLevel, setZoomLevel] = useState(1)
  
  // Review checklist states
  const [checklist, setChecklist] = useState({
    businessName: false,
    contactInfo: false,
    cnicAuthentic: false,
    addressConfirmed: false
  })

  useEffect(() => {
    fetchOwnerRequests()
  }, [])

  const fetchOwnerRequests = async () => {
    try {
      setLoading(true)
      // Fetch owners where owner_approved is null (pending approval)
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('role', 'owner')
        .is('owner_approved', null)
        .order('created_at', { ascending: false })

      if (error) {
        console.error('Supabase error:', error)
        if (error.message && error.message.includes('column') && error.message.includes('owner_approved')) {
          alert('Database Error: owner_approved column is missing. Please add it to the users table.')
        } else {
          throw error
        }
      }
      setRequests(data || [])
    } catch (error) {
      console.error('Error fetching owner requests:', error)
      showError('Error loading owner requests: ' + (error.message || 'Unknown error'))
    } finally {
      setLoading(false)
    }
  }

  const handleApprove = async (userId, userName) => {
    try {
      const { error } = await supabase
        .from('users')
        .update({ owner_approved: true })
        .eq('id', userId)

      if (error) throw error

      // Create notification for mobile user
      await supabase
        .from('notifications')
        .insert({
          user_id: userId,
          title: 'Owner Application Approved! 🎉',
          message: 'Congratulations! Your application to become a workspace owner has been approved. You can now add and manage workspaces in the app.',
          type: 'owner_approved',
          is_read: false,
          created_at: new Date().toISOString()
        })

      showSuccess(`Owner "${userName}" approved successfully!`)
      await recordStaffAction({
        action: 'owner_approved',
        entityType: 'user',
        entityId: userId,
        summary: `Approved owner application: ${userName}`,
        details: { user_name: userName },
      })
      setSelectedRequest(null)
      fetchOwnerRequests()
    } catch (error) {
      console.error('Error approving owner:', error)
      showError('Error approving owner: ' + error.message)
    }
  }

  const handleReject = async (userId, userName) => {
    const finalReason = rejectionReason.trim() || 'Your uploaded documents could not be fully verified.'
    
    try {
      const { error } = await supabase
        .from('users')
        .update({ owner_approved: false, role: 'user' })
        .eq('id', userId)

      if (error) throw error

      // Create rejection notification for mobile user
      await supabase
        .from('notifications')
        .insert({
          user_id: userId,
          title: 'Owner Application Status Update',
          message: `Your owner application was not approved. Reason: ${finalReason} Please re-verify and update your profile in the app.`,
          type: 'owner_rejected',
          is_read: false,
          created_at: new Date().toISOString(),
          metadata: { reason: finalReason }
        })

      showSuccess(`Owner request for "${userName}" rejected`)
      await recordStaffAction({
        action: 'owner_rejected',
        entityType: 'user',
        entityId: userId,
        summary: `Rejected owner application: ${userName}`,
        details: { reason: finalReason },
      })
      setSelectedRequest(null)
      setShowRejectForm(false)
      setRejectionReason('')
      fetchOwnerRequests()
    } catch (error) {
      console.error('Error rejecting owner:', error)
      showError('Error rejecting owner: ' + error.message)
    }
  }

  const openReviewModal = (request) => {
    setSelectedRequest(request)
    setZoomLevel(1)
    setRejectionReason('')
    setShowRejectForm(false)
    setChecklist({
      businessName: false,
      contactInfo: false,
      cnicAuthentic: false,
      addressConfirmed: false
    })
  }

  if (loading) {
    return <Loading message="Loading owner requests..." />
  }

  return (
    <div className="fade-in">
      {/* Header */}
      <div style={{ 
        background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
        backdropFilter: 'blur(10px)',
        padding: '32px',
        borderRadius: '20px',
        boxShadow: '0 8px 32px rgba(0, 0, 0, 0.08)',
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
            background: 'linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            backgroundClip: 'text',
            marginBottom: '12px',
            letterSpacing: '-0.5px'
          }}>
            Owner Verification
          </h1>
          <p style={{ 
            color: '#64748b', 
            fontSize: '16px',
            fontWeight: '500'
          }}>
            Review identities, business documents, and credentials for onboarding.
          </p>
        </div>
        <button
          onClick={fetchOwnerRequests}
          style={{
            padding: '12px 20px',
            background: 'linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%)',
            color: 'white',
            border: 'none',
            borderRadius: '12px',
            cursor: 'pointer',
            fontSize: '14px',
            fontWeight: '600',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            boxShadow: '0 4px 12px rgba(99, 102, 241, 0.2)',
            transition: 'all 0.3s'
          }}
        >
          <RefreshCw size={18} />
          Refresh
        </button>
      </div>

      {/* Main Grid View */}
      {requests.length === 0 ? (
        <EmptyState
          icon={Building}
          title="No pending requests"
          message="All owner requests have been fully processed"
        />
      ) : (
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(min(380px, 100%), 1fr))',
          gap: '24px'
        }}>
          {requests.map((request) => (
            <div
              key={request.id}
              style={{
                background: 'linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%)',
                backdropFilter: 'blur(10px)',
                padding: '28px',
                borderRadius: '20px',
                boxShadow: '0 8px 32px rgba(0, 0, 0, 0.05)',
                border: '1px solid rgba(255, 255, 255, 0.2)',
                transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                position: 'relative',
                overflow: 'hidden',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-6px)'
                e.currentTarget.style.boxShadow = '0 12px 40px rgba(99, 102, 241, 0.1)'
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0)'
                e.currentTarget.style.boxShadow = '0 8px 32px rgba(0, 0, 0, 0.05)'
              }}
            >
              <div style={{
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                height: '4px',
                background: 'linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%)',
                borderRadius: '20px 20px 0 0'
              }} />
              
              <div>
                <h3 style={{ 
                  fontSize: '20px', 
                  fontWeight: '700', 
                  marginBottom: '16px', 
                  color: '#1e293b' 
                }}>
                  {request.name}
                </h3>
                
                <div style={{ 
                  display: 'flex', 
                  flexDirection: 'column', 
                  gap: '12px', 
                  marginBottom: '20px' 
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#64748b', fontSize: '14px' }}>
                    <Mail size={16} color="#94a3b8" />
                    <span style={{ wordBreak: 'break-all' }}>{request.email}</span>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#64748b', fontSize: '14px' }}>
                    <Phone size={16} color="#94a3b8" />
                    <span>{request.phone || 'No phone supplied'}</span>
                  </div>
                  {request.business_name && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#64748b', fontSize: '14px' }}>
                      <Building size={16} color="#94a3b8" />
                      <span style={{ fontWeight: '600', color: '#1e293b' }}>{request.business_name}</span>
                    </div>
                  )}
                  {request.city && (
                    <div style={{ color: '#64748b', fontSize: '13px', marginLeft: '26px' }}>
                      📍 {request.city}
                    </div>
                  )}
                </div>

                <div style={{
                  display: 'inline-block',
                  padding: '4px 10px',
                  borderRadius: 6,
                  fontSize: 11,
                  fontWeight: 600,
                  background: request.cnic_image_url ? '#d1fae5' : '#fee2e2',
                  color: request.cnic_image_url ? '#065f46' : '#991b1b',
                  marginBottom: 8,
                }}>
                  {request.cnic_image_url ? 'CNIC uploaded' : 'CNIC missing — cannot approve'}
                </div>
              </div>

              <div style={{ 
                paddingTop: '16px',
                borderTop: '1px solid #f1f5f9',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                marginTop: '16px'
              }}>
                <span style={{ fontSize: '11px', color: '#94a3b8' }}>
                  Applied: {new Date(request.created_at).toLocaleDateString()}
                </span>
                
                <button
                  onClick={() => openReviewModal(request)}
                  style={{
                    padding: '8px 16px',
                    background: 'linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%)',
                    color: 'white',
                    border: 'none',
                    borderRadius: '10px',
                    cursor: 'pointer',
                    fontSize: '13px',
                    fontWeight: '700',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    boxShadow: '0 4px 12px rgba(99, 102, 241, 0.2)',
                    transition: 'all 0.2s'
                  }}
                  onMouseEnter={(e) => e.target.style.transform = 'scale(1.03)'}
                  onMouseLeave={(e) => e.target.style.transform = 'scale(1)'}
                >
                  <ClipboardCheck size={16} />
                  Review Application
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Review & Verification Modal Detailer */}
      {selectedRequest && (
        <div style={{
          position: 'fixed',
          inset: 0,
          background: 'rgba(15, 23, 42, 0.4)',
          backdropFilter: 'blur(8px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 2000,
          padding: '20px',
          animation: 'fadeIn 0.3s ease-out'
        }}>
          <div style={{
            background: 'white',
            width: '100%',
            maxWidth: '1000px',
            height: '90vh',
            borderRadius: '24px',
            boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
            display: 'flex',
            flexDirection: 'column',
            overflow: 'hidden',
            border: '1px solid rgba(255, 255, 255, 0.8)'
          }}>
            {/* Modal Header */}
            <div style={{
              padding: '24px 32px',
              borderBottom: '1px solid #f1f5f9',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              background: 'linear-gradient(135deg, #1e293b 0%, #0f172a 100%)',
              color: 'white'
            }}>
              <div>
                <h2 style={{ fontSize: '22px', fontWeight: '800' }}>Reviewing: {selectedRequest.name}</h2>
                <p style={{ fontSize: '13px', color: '#94a3b8', marginTop: '4px' }}>
                  Verify owner eligibility and review submitted documentation
                </p>
              </div>
              <button
                onClick={() => setSelectedRequest(null)}
                style={{
                  background: 'rgba(255, 255, 255, 0.1)',
                  border: 'none',
                  color: 'white',
                  cursor: 'pointer',
                  width: '36px',
                  height: '36px',
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  transition: 'all 0.2s'
                }}
              >
                <X size={18} />
              </button>
            </div>

            {/* Modal Content - Split layout */}
            <div style={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
              
              {/* Left Panel: CNIC Visualizer */}
              <div style={{ 
                flex: 1.2, 
                background: '#f8fafc', 
                borderRight: '1px solid #f1f5f9',
                display: 'flex',
                flexDirection: 'column',
                padding: '24px'
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                  <span style={{ fontSize: '14px', fontWeight: '700', color: '#475569', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <FileText size={18} color="#6366f1" />
                    CNIC / Document Identity Proof
                  </span>
                  
                  {selectedRequest.cnic_image_url && (
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button 
                        onClick={() => setZoomLevel(prev => Math.max(prev - 0.25, 0.5))}
                        style={{ padding: '4px 10px', borderRadius: '6px', border: '1px solid #cbd5e1', cursor: 'pointer', fontSize: '12px', background: 'white' }}
                      >
                        Zoom Out
                      </button>
                      <button 
                        onClick={() => setZoomLevel(prev => Math.min(prev + 0.25, 2.5))}
                        style={{ padding: '4px 10px', borderRadius: '6px', border: '1px solid #cbd5e1', cursor: 'pointer', fontSize: '12px', background: 'white' }}
                      >
                        Zoom In
                      </button>
                    </div>
                  )}
                </div>

                <div style={{ 
                  flex: 1, 
                  background: 'white', 
                  borderRadius: '16px', 
                  border: '1px dashed #cbd5e1',
                  overflow: 'auto',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  position: 'relative'
                }}>
                  {selectedRequest.cnic_image_url ? (
                    <img 
                      src={selectedRequest.cnic_image_url} 
                      alt="CNIC Proof" 
                      style={{ 
                        transform: `scale(${zoomLevel})`, 
                        maxWidth: '90%', 
                        maxHeight: '90%', 
                        objectFit: 'contain',
                        transition: 'transform 0.2s',
                        cursor: 'grab'
                      }} 
                    />
                  ) : (
                    <div style={{ textAlign: 'center', padding: '24px', color: '#94a3b8' }}>
                      <AlertCircle size={40} style={{ marginBottom: '12px' }} />
                      <p style={{ fontSize: '14px', fontWeight: '500' }}>No identity proof document uploaded</p>
                      <p style={{ fontSize: '12px', marginTop: '4px' }}>Owner profile requires CNIC image verification</p>
                    </div>
                  )}
                </div>
              </div>

              {/* Right Panel: Checklists & Verification Actions */}
              <div style={{ 
                flex: 1, 
                padding: '32px',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between',
                overflowY: 'auto'
              }}>
                <div>
                  {/* Business & Profile metadata */}
                  <div style={{ marginBottom: '24px' }}>
                    <h4 style={{ fontSize: '12px', color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '1px', marginBottom: '12px', fontWeight: '700' }}>
                      Details Summary
                    </h4>
                    
                    <div style={{ background: '#f8fafc', padding: '16px', borderRadius: '12px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                      <div style={{ fontSize: '13px', color: '#64748b' }}>
                        Name: <strong style={{ color: '#1e293b' }}>{selectedRequest.name}</strong>
                      </div>
                      <div style={{ fontSize: '13px', color: '#64748b' }}>
                        Email: <strong style={{ color: '#1e293b' }}>{selectedRequest.email}</strong>
                      </div>
                      <div style={{ fontSize: '13px', color: '#64748b' }}>
                        Phone: <strong style={{ color: '#1e293b' }}>{selectedRequest.phone || 'N/A'}</strong>
                      </div>
                      {selectedRequest.business_name && (
                        <div style={{ fontSize: '13px', color: '#64748b' }}>
                          Business: <strong style={{ color: '#1e293b' }}>{selectedRequest.business_name}</strong>
                        </div>
                      )}
                      {selectedRequest.business_address && (
                        <div style={{ fontSize: '13px', color: '#64748b' }}>
                          Address: <strong style={{ color: '#1e293b' }}>{selectedRequest.business_address}</strong>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Verification Checklist */}
                  <div style={{ marginBottom: '24px' }}>
                    <h4 style={{ fontSize: '12px', color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '1px', marginBottom: '12px', fontWeight: '700' }}>
                      Inspection Checklist
                    </h4>
                    
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                      <label style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '14px', color: '#475569', cursor: 'pointer' }}>
                        <input 
                          type="checkbox" 
                          checked={checklist.businessName}
                          onChange={(e) => setChecklist(prev => ({ ...prev, businessName: e.target.checked }))}
                          style={{ width: '16px', height: '16px', accentColor: '#6366f1' }}
                        />
                        Verify business legal name matches
                      </label>
                      <label style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '14px', color: '#475569', cursor: 'pointer' }}>
                        <input 
                          type="checkbox" 
                          checked={checklist.contactInfo}
                          onChange={(e) => setChecklist(prev => ({ ...prev, contactInfo: e.target.checked }))}
                          style={{ width: '16px', height: '16px', accentColor: '#6366f1' }}
                        />
                        Verify contact number & email format
                      </label>
                      <label style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '14px', color: '#475569', cursor: 'pointer' }}>
                        <input 
                          type="checkbox" 
                          checked={checklist.cnicAuthentic}
                          disabled={!selectedRequest.cnic_image_url}
                          onChange={(e) => setChecklist(prev => ({ ...prev, cnicAuthentic: e.target.checked }))}
                          style={{ width: '16px', height: '16px', accentColor: '#6366f1' }}
                        />
                        Verify CNIC card authenticity & details
                      </label>
                      <label style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '14px', color: '#475569', cursor: 'pointer' }}>
                        <input 
                          type="checkbox" 
                          checked={checklist.addressConfirmed}
                          onChange={(e) => setChecklist(prev => ({ ...prev, addressConfirmed: e.target.checked }))}
                          style={{ width: '16px', height: '16px', accentColor: '#6366f1' }}
                        />
                        Confirm operating city & physical address
                      </label>
                    </div>
                  </div>
                </div>

                {/* Form Rejection Notes Drawer */}
                <div>
                  {showRejectForm ? (
                    <div style={{ background: '#fef2f2', padding: '16px', borderRadius: '12px', border: '1px solid #fee2e2', marginBottom: '16px' }}>
                      <label style={{ fontSize: '13px', fontWeight: '700', color: '#991b1b', display: 'block', marginBottom: '8px' }}>
                        Explain Reason for Rejection
                      </label>
                      <textarea
                        value={rejectionReason}
                        onChange={(e) => setRejectionReason(e.target.value)}
                        placeholder="e.g. CNIC photo is blurry. Please upload a clear photo of the front and back of your CNIC card."
                        rows="3"
                        style={{
                          width: '100%',
                          padding: '10px',
                          border: '1px solid #fca5a5',
                          borderRadius: '8px',
                          fontSize: '13px',
                          outline: 'none',
                          resize: 'none',
                          marginBottom: '12px'
                        }}
                      />
                      <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                        <button
                          onClick={() => setShowRejectForm(false)}
                          style={{ padding: '6px 12px', fontSize: '12px', border: 'none', background: 'transparent', cursor: 'pointer', color: '#64748b' }}
                        >
                          Cancel
                        </button>
                        <button
                          onClick={() => handleReject(selectedRequest.id, selectedRequest.name)}
                          style={{
                            padding: '8px 16px',
                            fontSize: '12px',
                            background: 'linear-gradient(135deg, #ef4444 0%, #dc2626 100%)',
                            color: 'white',
                            border: 'none',
                            borderRadius: '8px',
                            cursor: 'pointer',
                            fontWeight: '600'
                          }}
                        >
                          Confirm Rejection
                        </button>
                      </div>
                    </div>
                  ) : null}

                  {/* Actions buttons */}
                  {!showRejectForm && (
                    <div style={{ display: 'flex', gap: '12px' }}>
                      <button
                        onClick={() => setShowRejectForm(true)}
                        style={{
                          flex: 1,
                          padding: '14px',
                          background: 'white',
                          border: '1px solid #ef4444',
                          color: '#ef4444',
                          borderRadius: '12px',
                          cursor: 'pointer',
                          fontWeight: '700',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          gap: '8px',
                          fontSize: '14px',
                          transition: 'all 0.2s'
                        }}
                        onMouseEnter={(e) => e.target.style.background = '#fef2f2'}
                        onMouseLeave={(e) => e.target.style.background = 'white'}
                      >
                        <X size={18} />
                        Reject Application
                      </button>
                      
                      <button
                        onClick={() => handleApprove(selectedRequest.id, selectedRequest.name)}
                        disabled={!selectedRequest.cnic_image_url || !checklist.businessName || !checklist.contactInfo || !checklist.cnicAuthentic || !checklist.addressConfirmed}
                        style={{
                          flex: 1.5,
                          padding: '14px',
                          background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                          color: 'white',
                          border: 'none',
                          borderRadius: '12px',
                          cursor: 'pointer',
                          fontWeight: '800',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          gap: '8px',
                          fontSize: '14px',
                          boxShadow: '0 4px 12px rgba(16, 185, 129, 0.2)',
                          transition: 'all 0.2s'
                        }}
                        onMouseEnter={(e) => {
                          e.target.style.transform = 'translateY(-2px)'
                          e.target.style.boxShadow = '0 6px 16px rgba(16, 185, 129, 0.3)'
                        }}
                        onMouseLeave={(e) => {
                          e.target.style.transform = 'translateY(0)'
                          e.target.style.boxShadow = '0 4px 12px rgba(16, 185, 129, 0.2)'
                        }}
                      >
                        <Check size={18} />
                        Approve Application
                      </button>
                    </div>
                  )}
                </div>

              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default OwnerRequests
