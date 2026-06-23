import { useEffect, useState, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { collaborationService } from '../../services/collaborationService'
import { chatService } from '../../services/chatService'
import { storageService } from '../../services/storageService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { Loading, EmptyState, Avatar, Modal } from '../../components/common'
import { timeAgo, fmtDate } from '../../lib/helpers'

const TABS = [
  { key: 'overview', label: 'Overview', icon: 'bi-info-circle' },
  { key: 'team', label: 'Team', icon: 'bi-people' },
  { key: 'milestones', label: 'Milestones', icon: 'bi-list-check' },
  { key: 'files', label: 'Files', icon: 'bi-folder' },
  { key: 'chat', label: 'Chat', icon: 'bi-chat-dots' },
  { key: 'activity', label: 'Activity', icon: 'bi-clock-history' },
]

export default function CollabProject() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { userId, profile } = useAuth()
  const toast = useToast()

  const [tab, setTab] = useState('overview')
  const [project, setProject] = useState(null)
  const [members, setMembers] = useState([])
  const [milestones, setMilestones] = useState([])
  const [files, setFiles] = useState([])
  const [activity, setActivity] = useState([])
  const [loading, setLoading] = useState(true)
  const [showMilestone, setShowMilestone] = useState(false)
  const [ms, setMs] = useState({ title: '', description: '', dueDate: '', assignedTo: '' })

  // chat
  const [room, setRoom] = useState(null)
  const [messages, setMessages] = useState([])
  const [text, setText] = useState('')
  const chatEnd = useRef(null)

  const isOwner = project?.user_id === userId

  const load = async () => {
    try {
      const p = await collaborationService.getById(id)
      setProject(p)
      if (!p) return
      const [m, mil, f, act, r] = await Promise.all([
        collaborationService.getMembers(id),
        collaborationService.getMilestones(id),
        collaborationService.getFiles(id),
        collaborationService.getActivity(id),
        chatService.getGroupRoom(id),
      ])
      setMembers(m)
      setMilestones(mil)
      setFiles(f)
      setActivity(act)
      setRoom(r)
      if (r) setMessages(await chatService.getMessages(r.id))
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
    if (!room) return
    const unsub = chatService.subscribeMessages(room.id, (payload) => {
      setMessages((prev) => (prev.find((m) => m.id === payload.new.id) ? prev : [...prev, payload.new]))
    })
    return unsub
  }, [room])

  useEffect(() => {
    if (tab === 'chat') chatEnd.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, tab])

  const addMilestone = async () => {
    if (!ms.title.trim()) return toast.error('Title required')
    try {
      await collaborationService.addMilestone({
        collaborationId: id, title: ms.title, description: ms.description,
        dueDate: ms.dueDate || null,
        assignedTo: ms.assignedTo || null,
        assignedToName: members.find((m) => m.user_id === ms.assignedTo)?.user_name || null,
        sortOrder: milestones.length,
      })
      setShowMilestone(false)
      setMs({ title: '', description: '', dueDate: '', assignedTo: '' })
      setMilestones(await collaborationService.getMilestones(id))
    } catch (err) { toast.error(err.message) }
  }

  const toggleMilestone = async (m) => {
    await collaborationService.toggleMilestone(m, profile)
    setMilestones(await collaborationService.getMilestones(id))
  }

  const uploadFile = async (e) => {
    const f = e.target.files[0]
    if (!f) return
    try {
      const url = await storageService.uploadCollaborationFile(id, userId, f)
      await collaborationService.addFile({ collaborationId: id, user: profile, fileName: f.name, fileUrl: url, fileType: f.type, fileSize: f.size })
      toast.success('File uploaded')
      setFiles(await collaborationService.getFiles(id))
    } catch (err) { toast.error(err.message || 'Upload failed') }
  }

  const send = async () => {
    if (!text.trim() || !room) return
    const t = text
    setText('')
    try {
      await chatService.sendMessage({ room, senderId: userId, senderName: profile?.name, senderImage: profile?.profile_image_url, message: t })
    } catch (err) { toast.error('Failed to send') }
  }

  const completeProject = async () => {
    if (!confirm('Mark this project as complete?')) return
    await collaborationService.markComplete(project, profile)
    toast.success('Project marked complete')
    load()
  }

  if (loading) return <Loading />
  if (!project) return <div className="container-app"><EmptyState icon="bi-folder-x" title="Project not found" /></div>

  const doneCount = milestones.filter((m) => m.status === 'done').length
  const progress = milestones.length ? Math.round((doneCount / milestones.length) * 100) : 0

  return (
    <div className="container-app" style={{ maxWidth: 980 }}>
      <button className="btn btn-light mb-3" onClick={() => navigate('/collaborations')}><i className="bi bi-arrow-left me-1"></i>Hub</button>

      <div className="card-clean p-4 mb-3" style={{ background: 'var(--hero-gradient)', color: '#fff' }}>
        <div className="d-flex justify-content-between align-items-start">
          <div>
            <h3 className="fw-bold text-white mb-1">{project.title}</h3>
            <span className="badge-soft" style={{ background: 'rgba(255,255,255,0.25)', color: '#fff' }}>{project.status}</span>
          </div>
          {isOwner && project.status === 'active' && (
            <button className="btn btn-light btn-sm" onClick={completeProject}><i className="bi bi-flag me-1"></i>Complete</button>
          )}
        </div>
        <div className="mt-3">
          <div className="d-flex justify-content-between small mb-1"><span style={{ opacity: 0.9 }}>Progress</span><span>{progress}%</span></div>
          <div style={{ height: 8, background: 'rgba(255,255,255,0.25)', borderRadius: 8 }}>
            <div style={{ width: `${progress}%`, height: 8, background: '#fff', borderRadius: 8, transition: 'width 0.4s' }} />
          </div>
        </div>
      </div>

      <div className="pill-tabs mb-4 flex-wrap" style={{ overflowX: 'auto' }}>
        {TABS.map((t) => (
          <button key={t.key} className={tab === t.key ? 'active' : ''} onClick={() => setTab(t.key)}>
            <i className={`bi ${t.icon} me-1`}></i>{t.label}
          </button>
        ))}
      </div>

      {tab === 'overview' && (
        <div className="row g-3">
          <div className="col-md-8">
            <div className="card-clean p-4">
              <h6 className="fw-bold">About</h6>
              <p className="text-secondary" style={{ whiteSpace: 'pre-wrap' }}>{project.description}</p>
              {project.meeting_link && (
                <a href={project.meeting_link} target="_blank" rel="noreferrer" className="btn btn-soft btn-sm"><i className="bi bi-camera-video me-1"></i>Join meeting</a>
              )}
            </div>
          </div>
          <div className="col-md-4">
            <div className="card-clean p-4 text-center">
              <div className="fw-bold fs-3 text-primary">{members.length}</div>
              <div className="small text-secondary">Team members</div>
              <hr className="divider my-2" />
              <div className="fw-bold fs-3 text-primary">{doneCount}/{milestones.length}</div>
              <div className="small text-secondary">Milestones done</div>
            </div>
          </div>
        </div>
      )}

      {tab === 'team' && (
        <div className="row g-3">
          {members.map((m) => (
            <div className="col-sm-6 col-lg-4" key={m.id}>
              <div className="card-clean p-3 d-flex align-items-center gap-3">
                <Avatar src={m.user_profile_image} name={m.user_name} size={48} />
                <div className="flex-fill">
                  <div className="fw-semibold">{m.user_name}</div>
                  <div className="small text-secondary">{m.role_title || m.role}</div>
                </div>
                {isOwner && m.role !== 'owner' && (
                  <button className="btn btn-link btn-sm text-danger" onClick={async () => { await collaborationService.removeMember(id, m.user_id); load() }}><i className="bi bi-x-lg"></i></button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {tab === 'milestones' && (
        <div>
          <div className="d-flex justify-content-end mb-3">
            <button className="btn btn-primary btn-sm" onClick={() => setShowMilestone(true)}><i className="bi bi-plus-lg me-1"></i>Add milestone</button>
          </div>
          {milestones.length === 0 ? (
            <EmptyState icon="bi-list-check" title="No milestones yet" />
          ) : (
            <div className="d-flex flex-column gap-2">
              {milestones.map((m) => (
                <div key={m.id} className="card-clean p-3 d-flex align-items-center gap-3">
                  <button className="btn btn-link p-0" onClick={() => toggleMilestone(m)}>
                    <i className={`bi ${m.status === 'done' ? 'bi-check-circle-fill text-success' : 'bi-circle text-secondary'} fs-5`}></i>
                  </button>
                  <div className="flex-fill">
                    <div className={`fw-semibold ${m.status === 'done' ? 'text-decoration-line-through text-secondary' : ''}`}>{m.title}</div>
                    {m.description && <div className="small text-secondary">{m.description}</div>}
                    <div className="small text-tertiary">
                      {m.assigned_to_name && <span><i className="bi bi-person me-1"></i>{m.assigned_to_name} </span>}
                      {m.due_date && <span><i className="bi bi-calendar me-1"></i>{fmtDate(m.due_date)}</span>}
                    </div>
                  </div>
                  {isOwner && <button className="btn btn-link btn-sm text-danger" onClick={async () => { await collaborationService.deleteMilestone(m.id); setMilestones(await collaborationService.getMilestones(id)) }}><i className="bi bi-trash"></i></button>}
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {tab === 'files' && (
        <div>
          <div className="d-flex justify-content-end mb-3">
            <label className="btn btn-primary btn-sm mb-0"><i className="bi bi-upload me-1"></i>Upload<input type="file" hidden onChange={uploadFile} /></label>
          </div>
          {files.length === 0 ? (
            <EmptyState icon="bi-folder" title="No files shared yet" />
          ) : (
            <div className="row g-2">
              {files.map((f) => (
                <div className="col-md-6" key={f.id}>
                  <a href={f.file_url} target="_blank" rel="noreferrer" className="card-clean p-3 d-flex align-items-center gap-3 text-reset">
                    <i className="bi bi-file-earmark fs-3 text-primary"></i>
                    <div className="flex-fill">
                      <div className="fw-semibold small line-clamp-1">{f.file_name}</div>
                      <div className="small text-secondary">{f.uploader_name} · {timeAgo(f.created_at)}</div>
                    </div>
                    <i className="bi bi-download text-secondary"></i>
                  </a>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {tab === 'chat' && (
        <div className="card-clean p-3">
          {!room ? (
            <EmptyState icon="bi-chat" title="Group chat unavailable" subtitle="The chat room is created when a project launches." />
          ) : (
            <>
              <div className="chat-window" style={{ height: 420 }}>
                {messages.map((m) => {
                  const me = m.sender_id === userId
                  return (
                    <div key={m.id} className={`d-flex ${me ? 'justify-content-end' : 'justify-content-start'} mb-1`}>
                      <div>
                        {!me && <div className="small text-secondary ms-2">{m.sender_name?.split(' ')[0]}</div>}
                        <div className={`bubble ${me ? 'bubble-me' : 'bubble-them'}`}>
                          {m.message_type === 'image' && m.image_url ? <img src={m.image_url} alt="" style={{ maxWidth: 200, borderRadius: 8 }} /> : m.message}
                        </div>
                      </div>
                    </div>
                  )
                })}
                <div ref={chatEnd} />
              </div>
              <div className="d-flex gap-2 mt-2">
                <input className="form-control" placeholder="Message your team..." value={text} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && send()} />
                <button className="btn btn-primary" onClick={send}><i className="bi bi-send"></i></button>
              </div>
            </>
          )}
        </div>
      )}

      {tab === 'activity' && (
        <div className="card-clean p-4">
          {activity.length === 0 ? (
            <p className="text-secondary mb-0">No activity yet.</p>
          ) : (
            <div className="d-flex flex-column gap-3">
              {activity.map((a) => (
                <div key={a.id} className="d-flex gap-3">
                  <div className="stat-icon" style={{ background: '#eef2ff', color: 'var(--primary)', width: 36, height: 36 }}><i className="bi bi-dot fs-4"></i></div>
                  <div>
                    <div className="small"><strong>{a.actor_name}</strong> {a.action.replace(/_/g, ' ')} {a.detail && <span className="text-secondary">— {a.detail}</span>}</div>
                    <div className="small text-tertiary">{timeAgo(a.created_at)}</div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {showMilestone && (
        <Modal show onClose={() => setShowMilestone(false)} title="Add milestone" footer={
          <>
            <button className="btn btn-light" onClick={() => setShowMilestone(false)}>Cancel</button>
            <button className="btn btn-primary" onClick={addMilestone}>Add</button>
          </>
        }>
          <div className="mb-2"><label className="form-label">Title</label><input className="form-control" value={ms.title} onChange={(e) => setMs({ ...ms, title: e.target.value })} /></div>
          <div className="mb-2"><label className="form-label">Description</label><textarea className="form-control" rows={2} value={ms.description} onChange={(e) => setMs({ ...ms, description: e.target.value })} /></div>
          <div className="row g-2">
            <div className="col-6"><label className="form-label">Due date</label><input type="date" className="form-control" value={ms.dueDate} onChange={(e) => setMs({ ...ms, dueDate: e.target.value })} /></div>
            <div className="col-6"><label className="form-label">Assign to</label>
              <select className="form-select" value={ms.assignedTo} onChange={(e) => setMs({ ...ms, assignedTo: e.target.value })}>
                <option value="">Unassigned</option>
                {members.map((m) => <option key={m.user_id} value={m.user_id}>{m.user_name}</option>)}
              </select>
            </div>
          </div>
        </Modal>
      )}
    </div>
  )
}
