import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { profileService } from '../../services/profileService'
import { collaborationService } from '../../services/collaborationService'
import { chatService } from '../../services/chatService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { Loading, EmptyState, Avatar, Modal } from '../../components/common'

export default function PublicProfile() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { userId, profile: me } = useAuth()
  const toast = useToast()
  const [user, setUser] = useState(null)
  const [portfolio, setPortfolio] = useState([])
  const [loading, setLoading] = useState(true)
  const [showInvite, setShowInvite] = useState(false)
  const [myProjects, setMyProjects] = useState([])
  const [inviteProject, setInviteProject] = useState('')
  const [inviteMsg, setInviteMsg] = useState('')

  useEffect(() => {
    Promise.all([profileService.getById(id), profileService.getPortfolio(id)])
      .then(([u, p]) => { setUser(u); setPortfolio(p) })
      .finally(() => setLoading(false))
  }, [id])

  const openInvite = async () => {
    const posts = await collaborationService.getMyPosts(userId)
    setMyProjects(posts.filter((p) => p.status === 'recruiting' || p.status === 'active'))
    setInviteProject(posts[0]?.id || '')
    setShowInvite(true)
  }

  const sendInvite = async () => {
    const project = myProjects.find((p) => p.id === inviteProject)
    if (!project) return toast.error('Select a project')
    try {
      await collaborationService.sendInvite({ project, invitedBy: me, invitedUser: id, message: inviteMsg })
      toast.success('Invite sent!')
      setShowInvite(false)
    } catch (err) {
      toast.error(err.message || 'Failed')
    }
  }

  const message = async () => {
    try {
      const room = await chatService.getOrCreateDirectRoom({ user1Id: userId, user2Id: id })
      navigate(`/chats/${room.id}`)
    } catch { toast.error('Could not start chat') }
  }

  if (loading) return <Loading />
  if (!user) return <div className="container-app"><EmptyState icon="bi-person-x" title="User not found" /></div>

  return (
    <div className="container-app" style={{ maxWidth: 820 }}>
      <button className="btn btn-light mb-3" onClick={() => navigate(-1)}><i className="bi bi-arrow-left me-1"></i>Back</button>

      <div className="card-clean overflow-hidden mb-3">
        <div style={{ height: 90, background: 'var(--hero-gradient)' }}></div>
        <div className="p-4">
          <div className="d-flex align-items-end gap-3" style={{ marginTop: -60 }}>
            <Avatar src={user.profile_image_url} name={user.name} size={96} className="border border-4 border-white" />
            <div className="pb-2">
              <h4 className="fw-bold mb-0">{user.name}</h4>
              <div className="text-secondary">{user.collaboration_headline || user.profession || 'Member'}</div>
            </div>
          </div>
          <div className="d-flex gap-3 flex-wrap mt-3 text-secondary small">
            {user.city && <span><i className="bi bi-geo-alt me-1"></i>{user.city}</span>}
            {user.availability && <span><i className="bi bi-clock me-1"></i>{user.availability}</span>}
            {user.collaboration_enabled && <span className="badge-soft badge-success-soft">Open to collaborate</span>}
          </div>
          {user.bio && <p className="text-secondary mt-3 mb-0">{user.bio}</p>}
          {userId !== id && (
            <div className="d-flex gap-2 mt-3">
              <button className="btn btn-primary" onClick={openInvite}><i className="bi bi-person-plus me-1"></i>Invite to project</button>
              <button className="btn btn-light" onClick={message}><i className="bi bi-chat-dots me-1"></i>Message</button>
            </div>
          )}
        </div>
      </div>

      {(user.skills || []).length > 0 && (
        <div className="card-clean p-4 mb-3">
          <h6 className="fw-bold mb-2">Skills</h6>
          <div className="d-flex flex-wrap gap-1">{user.skills.map((s) => <span key={s} className="chip chip-static">{s}</span>)}</div>
        </div>
      )}

      <div className="card-clean p-4">
        <h6 className="fw-bold mb-3">Portfolio</h6>

        {user.resume_url && (
          <div className="card-clean p-3 mb-3 d-flex align-items-center gap-3" style={{ background: '#f7f9ff' }}>
            <div className="stat-icon" style={{ background: 'var(--primary-gradient)', width: 44, height: 44 }}>
              <i className="bi bi-file-earmark-person text-white"></i>
            </div>
            <div className="flex-fill">
              <div className="fw-semibold">Resume / CV</div>
              <div className="small text-secondary line-clamp-1">{user.resume_file_name || 'Download resume'}</div>
            </div>
            <a href={user.resume_url} target="_blank" rel="noreferrer" className="btn btn-soft btn-sm">
              <i className="bi bi-download me-1"></i>View
            </a>
          </div>
        )}

        {portfolio.length === 0 && !user.resume_url ? (
          <p className="text-secondary mb-0">No portfolio items yet.</p>
        ) : portfolio.length === 0 ? (
          <p className="text-secondary mb-0">No work items yet.</p>
        ) : (
          <div className="row g-3">
            {portfolio.map((it) => (
              <div className="col-md-6" key={it.id}>
                <div className="card-clean overflow-hidden h-100">
                  {it.image_url && <img src={it.image_url} alt={it.title} style={{ height: 130, width: '100%', objectFit: 'cover' }} />}
                  <div className="p-3">
                    <h6 className="fw-bold">{it.title}</h6>
                    {it.description && <p className="small text-secondary line-clamp-2">{it.description}</p>}
                    {it.project_url && <a href={it.project_url} target="_blank" rel="noreferrer" className="small"><i className="bi bi-link-45deg"></i>View</a>}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {showInvite && (
        <Modal show onClose={() => setShowInvite(false)} title={`Invite ${user.name}`} footer={
          <>
            <button className="btn btn-light" onClick={() => setShowInvite(false)}>Cancel</button>
            <button className="btn btn-primary" onClick={sendInvite}>Send Invite</button>
          </>
        }>
          {myProjects.length === 0 ? (
            <p className="text-secondary mb-0">You don't have any active/recruiting projects. Create one first.</p>
          ) : (
            <>
              <div className="mb-2">
                <label className="form-label">Project</label>
                <select className="form-select" value={inviteProject} onChange={(e) => setInviteProject(e.target.value)}>
                  {myProjects.map((p) => <option key={p.id} value={p.id}>{p.title}</option>)}
                </select>
              </div>
              <div>
                <label className="form-label">Message (optional)</label>
                <textarea className="form-control" rows={3} value={inviteMsg} onChange={(e) => setInviteMsg(e.target.value)} />
              </div>
            </>
          )}
        </Modal>
      )}
    </div>
  )
}
