import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { collaborationService } from '../../services/collaborationService'
import { chatService } from '../../services/chatService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { Loading, EmptyState, Avatar, StatusBadge, Modal } from '../../components/common'
import { timeAgo } from '../../lib/helpers'

export default function CollabDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { userId, profile } = useAuth()
  const toast = useToast()

  const [project, setProject] = useState(null)
  const [roles, setRoles] = useState([])
  const [applications, setApplications] = useState([])
  const [members, setMembers] = useState([])
  const [myApp, setMyApp] = useState(null)
  const [myMember, setMyMember] = useState(null)
  const [loading, setLoading] = useState(true)
  const [showApply, setShowApply] = useState(false)
  const [applyRole, setApplyRole] = useState(null)
  const [pitch, setPitch] = useState('')
  const [availability, setAvailability] = useState('')
  const [rate, setRate] = useState('')
  const [busy, setBusy] = useState(false)

  const isOwner = project?.user_id === userId

  const load = async () => {
    try {
      const p = await collaborationService.getById(id)
      setProject(p)
      if (!p) return
      const [r, m] = await Promise.all([
        collaborationService.getRoles(id),
        collaborationService.getMembers(id),
      ])
      setRoles(r)
      setMembers(m)
      setMyApp(await collaborationService.hasApplied(id, userId))
      setMyMember(await collaborationService.isMember(id, userId))
      if (p.user_id === userId) setApplications(await collaborationService.getApplications(id))
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (userId) load()
  }, [id, userId])

  const submitApply = async () => {
    if (!pitch.trim()) return toast.error('Please write a short pitch')
    setBusy(true)
    try {
      await collaborationService.apply({ project, role: applyRole, user: profile, pitch, availability, proposedRate: rate })
      toast.success('Application submitted!')
      setShowApply(false)
      load()
    } catch (err) {
      toast.error(err.message || 'Could not apply')
    } finally {
      setBusy(false)
    }
  }

  const reviewApp = async (app, status) => {
    try {
      await collaborationService.setApplicationStatus(app, status)
      toast.success(`Application ${status}`)
      setApplications(await collaborationService.getApplications(id))
    } catch (err) {
      toast.error(err.message || 'Failed')
    }
  }

  const launch = async () => {
    setBusy(true)
    try {
      await collaborationService.launch(project, profile)
      toast.success('Project launched!')
      navigate(`/project/${id}`)
    } catch (err) {
      toast.error(err.message || 'Launch failed')
    } finally {
      setBusy(false)
    }
  }

  const messageApplicant = async (app) => {
    try {
      const room = await chatService.getOrCreateDirectRoom({ user1Id: userId, user2Id: app.user_id, collaborationId: id })
      navigate(`/chats/${room.id}`)
    } catch { toast.error('Could not start chat') }
  }

  if (loading) return <Loading />
  if (!project) return <div className="container-app"><EmptyState icon="bi-folder-x" title="Project not found" /></div>

  const acceptedCount = applications.filter((a) => a.status === 'accepted').length

  return (
    <div className="container-app" style={{ maxWidth: 900 }}>
      <button className="btn btn-light mb-3" onClick={() => navigate(-1)}><i className="bi bi-arrow-left me-1"></i>Back</button>

      {/* Header */}
      <div className="card-clean overflow-hidden mb-3">
        {project.cover_image_url ? (
          <img src={project.cover_image_url} alt={project.title} style={{ height: 200, width: '100%', objectFit: 'cover' }} />
        ) : (
          <div style={{ height: 140, background: 'var(--hero-gradient)' }}></div>
        )}
        <div className="p-4">
          <div className="d-flex justify-content-between align-items-start gap-2">
            <div>
              <h3 className="fw-bold mb-1">{project.title}</h3>
              <div className="d-flex align-items-center gap-2">
                <Avatar src={project.user_profile_image} name={project.user_name} size={26} />
                <span className="text-secondary small">{project.user_name} · {timeAgo(project.created_at)}</span>
              </div>
            </div>
            <StatusBadge status={project.status} />
          </div>
          <div className="d-flex gap-2 flex-wrap mt-3">
            {project.project_type && <span className="chip chip-static"><i className="bi bi-tag"></i>{project.project_type}</span>}
            {project.budget && <span className="chip chip-static"><i className="bi bi-cash"></i>{project.budget}</span>}
            {project.timeline && <span className="chip chip-static"><i className="bi bi-clock"></i>{project.timeline}</span>}
          </div>

          {(isOwner || myMember) && project.status === 'active' && (
            <button className="btn btn-primary mt-3" onClick={() => navigate(`/project/${id}`)}><i className="bi bi-kanban me-1"></i>Open Project Room</button>
          )}

          {/* Apply / owner actions */}
          {!isOwner && !myMember && project.status === 'recruiting' && (
            myApp ? (
              <div className="alert alert-light mt-3 mb-0">You have applied · <StatusBadge status={myApp.status} /></div>
            ) : (
              <button className="btn btn-primary mt-3" onClick={() => { setApplyRole(roles[0] || null); setShowApply(true) }}><i className="bi bi-send me-1"></i>Apply to join</button>
            )
          )}
          {isOwner && project.status === 'recruiting' && (
            <div className="d-flex gap-2 mt-3 flex-wrap">
              <button className="btn btn-primary" onClick={launch} disabled={acceptedCount === 0 || busy}>
                {busy ? <span className="spinner-border spinner-border-sm me-2"></span> : <i className="bi bi-rocket-takeoff me-1"></i>}
                Launch ({acceptedCount} accepted)
              </button>
              <button className="btn btn-light" onClick={() => navigate(`/collaborations/${id}/edit`)}><i className="bi bi-pencil me-1"></i>Edit</button>
            </div>
          )}
        </div>
      </div>

      <div className="row g-3">
        <div className="col-lg-7">
          <div className="card-clean p-4 mb-3">
            <h6 className="fw-bold">About the project</h6>
            <p className="text-secondary mb-0" style={{ whiteSpace: 'pre-wrap' }}>{project.description}</p>
          </div>

          {/* Roles */}
          {roles.length > 0 && (
            <div className="card-clean p-4">
              <h6 className="fw-bold mb-3">Roles needed</h6>
              <div className="d-flex flex-column gap-2">
                {roles.map((r) => (
                  <div key={r.id} className="card-clean p-3 d-flex justify-content-between align-items-center">
                    <div>
                      <div className="fw-semibold">{r.title}</div>
                      <div className="d-flex flex-wrap gap-1 mt-1">
                        {(r.required_skills || []).map((s) => <span key={s} className="chip chip-static" style={{ fontSize: '0.7rem', padding: '0.15rem 0.5rem' }}>{s}</span>)}
                      </div>
                    </div>
                    {!isOwner && !myMember && project.status === 'recruiting' && !myApp && (
                      <button className="btn btn-soft btn-sm" onClick={() => { setApplyRole(r); setShowApply(true) }}>Apply</button>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        <div className="col-lg-5">
          {/* Members */}
          <div className="card-clean p-4 mb-3">
            <h6 className="fw-bold mb-3">Team ({members.length})</h6>
            {members.length === 0 ? (
              <p className="text-secondary small mb-0">No members yet.</p>
            ) : (
              members.map((m) => (
                <div key={m.id} className="d-flex align-items-center gap-2 mb-2">
                  <Avatar src={m.user_profile_image} name={m.user_name} size={36} />
                  <div>
                    <div className="fw-semibold small">{m.user_name}</div>
                    <div className="small text-secondary">{m.role_title || m.role}</div>
                  </div>
                </div>
              ))
            )}
          </div>

          {/* Applications (owner) */}
          {isOwner && project.status === 'recruiting' && (
            <div className="card-clean p-4">
              <h6 className="fw-bold mb-3">Applications ({applications.length})</h6>
              {applications.length === 0 ? (
                <p className="text-secondary small mb-0">No applications yet.</p>
              ) : (
                applications.map((a) => (
                  <div key={a.id} className="card-clean p-3 mb-2">
                    <div className="d-flex align-items-center gap-2 mb-1">
                      <Avatar src={a.user_profile_image} name={a.user_name} size={32} />
                      <div className="flex-fill">
                        <div className="fw-semibold small">{a.user_name}</div>
                        <div className="small text-secondary">{a.role_title || 'General'}</div>
                      </div>
                      <StatusBadge status={a.status} />
                    </div>
                    <p className="small text-secondary mb-2">{a.pitch_message}</p>
                    <div className="d-flex gap-1 flex-wrap">
                      <button className="btn btn-success btn-sm" onClick={() => reviewApp(a, 'accepted')} disabled={a.status === 'accepted'}>Accept</button>
                      <button className="btn btn-light btn-sm" onClick={() => reviewApp(a, 'shortlisted')}>Shortlist</button>
                      <button className="btn btn-light btn-sm text-danger" onClick={() => reviewApp(a, 'rejected')}>Reject</button>
                      <button className="btn btn-soft btn-sm" onClick={() => messageApplicant(a)}><i className="bi bi-chat"></i></button>
                    </div>
                  </div>
                ))
              )}
            </div>
          )}
        </div>
      </div>

      {/* Apply modal */}
      {showApply && (
        <Modal show onClose={() => setShowApply(false)} title="Apply to join" footer={
          <>
            <button className="btn btn-light" onClick={() => setShowApply(false)}>Cancel</button>
            <button className="btn btn-primary" onClick={submitApply} disabled={busy}>{busy ? <span className="spinner-border spinner-border-sm me-2"></span> : null}Submit</button>
          </>
        }>
          {roles.length > 0 && (
            <div className="mb-3">
              <label className="form-label">Role</label>
              <select className="form-select" value={applyRole?.id || ''} onChange={(e) => setApplyRole(roles.find((r) => r.id === e.target.value))}>
                {roles.map((r) => <option key={r.id} value={r.id}>{r.title}</option>)}
              </select>
            </div>
          )}
          <div className="mb-3">
            <label className="form-label">Pitch message</label>
            <textarea className="form-control" rows={4} placeholder="Why are you a great fit?" value={pitch} onChange={(e) => setPitch(e.target.value)} />
          </div>
          <div className="row g-2">
            <div className="col-6">
              <label className="form-label">Availability</label>
              <input className="form-control" placeholder="e.g. 20 hrs/week" value={availability} onChange={(e) => setAvailability(e.target.value)} />
            </div>
            <div className="col-6">
              <label className="form-label">Proposed rate</label>
              <input className="form-control" placeholder="optional" value={rate} onChange={(e) => setRate(e.target.value)} />
            </div>
          </div>
        </Modal>
      )}
    </div>
  )
}
