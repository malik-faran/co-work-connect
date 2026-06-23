import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { collaborationService } from '../../services/collaborationService'
import { profileService } from '../../services/profileService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { Loading, EmptyState, Avatar, StatusBadge } from '../../components/common'
import { timeAgo } from '../../lib/helpers'

const TABS = ['Discover', 'Teammates', 'My Posts', 'My Teams', 'Applications']

function ProjectCard({ c }) {
  return (
    <Link to={`/collaborations/${c.id}`} className="text-reset">
      <div className="card-clean card-hover h-100 overflow-hidden" data-aos="fade-up">
        {c.cover_image_url ? (
          <img src={c.cover_image_url} alt={c.title} style={{ height: 130, width: '100%', objectFit: 'cover' }} />
        ) : (
          <div style={{ height: 130, background: 'var(--cool-gradient)' }} className="d-flex align-items-center justify-content-center">
            <i className="bi bi-kanban text-white" style={{ fontSize: '2.5rem', opacity: 0.8 }}></i>
          </div>
        )}
        <div className="p-3">
          <div className="d-flex justify-content-between align-items-start gap-2 mb-1">
            <h6 className="fw-bold mb-0 line-clamp-1">{c.title}</h6>
            <StatusBadge status={c.status} />
          </div>
          {c.project_type && <span className="badge-soft badge-primary-soft mb-2 d-inline-block">{c.project_type}</span>}
          <p className="text-secondary small line-clamp-2 mb-2">{c.description}</p>
          <div className="d-flex flex-wrap gap-1 mb-2">
            {(c.required_skills || []).slice(0, 3).map((s) => (
              <span key={s} className="chip chip-static" style={{ fontSize: '0.7rem', padding: '0.15rem 0.5rem' }}>{s}</span>
            ))}
          </div>
          <div className="d-flex justify-content-between align-items-center">
            <div className="d-flex align-items-center gap-2">
              <Avatar src={c.user_profile_image} name={c.user_name} size={24} />
              <span className="small text-secondary">{c.user_name}</span>
            </div>
            <span className="small text-tertiary">{timeAgo(c.created_at)}</span>
          </div>
        </div>
      </div>
    </Link>
  )
}

export default function Collaborations() {
  const { userId, profile } = useAuth()
  const navigate = useNavigate()
  const toast = useToast()
  const [tab, setTab] = useState('Discover')
  const [loading, setLoading] = useState(true)
  const [data, setData] = useState([])
  const [search, setSearch] = useState('')
  const [invites, setInvites] = useState([])

  const load = async () => {
    setLoading(true)
    try {
      let res = []
      if (tab === 'Discover') res = await collaborationService.getDiscover(userId)
      else if (tab === 'Teammates') res = await profileService.getOpenTeammates(userId)
      else if (tab === 'My Posts') res = await collaborationService.getMyPosts(userId)
      else if (tab === 'My Teams') res = await collaborationService.getMyTeams(userId)
      else if (tab === 'Applications') res = await collaborationService.getMyApplications(userId)
      setData(res)
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (userId) load()
  }, [tab, userId])

  useEffect(() => {
    if (userId) collaborationService.getMyInvites(userId).then(setInvites).catch(() => {})
  }, [userId])

  const respondInvite = async (inv, accept) => {
    try {
      await collaborationService.respondInvite(inv, accept, profile)
      toast.success(accept ? 'Invite accepted!' : 'Invite declined')
      setInvites(invites.filter((i) => i.id !== inv.id))
    } catch (err) {
      toast.error(err.message || 'Failed')
    }
  }

  const q = search.trim().toLowerCase()
  const filtered = (tab === 'Discover' && q)
    ? data.filter((c) => [c.title, c.description, ...(c.required_skills || [])].filter(Boolean).some((f) => f.toLowerCase().includes(q)))
    : data

  return (
    <div className="container-app">
      <div className="d-flex flex-wrap justify-content-between align-items-center gap-3 mb-3">
        <div>
          <h3 className="fw-bold mb-0">Collaboration Hub</h3>
          <p className="text-secondary mb-0">Find teammates and build projects together.</p>
        </div>
        <div className="d-flex gap-2">
          <button className="btn btn-light" onClick={() => navigate('/join')}><i className="bi bi-link-45deg me-1"></i>Join with code</button>
          <button className="btn btn-primary" onClick={() => navigate('/collaborations/create')}><i className="bi bi-plus-lg me-1"></i>New Project</button>
        </div>
      </div>

      {/* Invites banner */}
      {invites.length > 0 && (
        <div className="card-clean p-3 mb-3" style={{ borderLeft: '4px solid var(--primary)' }}>
          <div className="fw-semibold mb-2"><i className="bi bi-envelope-paper me-1 text-primary"></i>You have {invites.length} project invite{invites.length > 1 ? 's' : ''}</div>
          {invites.map((inv) => (
            <div key={inv.id} className="d-flex justify-content-between align-items-center py-2 border-top">
              <div>
                <div className="fw-semibold small">{inv.collaboration_title}</div>
                <div className="small text-secondary">from {inv.invited_by_name}{inv.role_title && ` · ${inv.role_title}`}</div>
              </div>
              <div className="d-flex gap-2">
                <button className="btn btn-primary btn-sm" onClick={() => respondInvite(inv, true)}>Accept</button>
                <button className="btn btn-light btn-sm" onClick={() => respondInvite(inv, false)}>Decline</button>
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="d-flex flex-wrap gap-2 justify-content-between align-items-center mb-4">
        <div className="pill-tabs flex-wrap">
          {TABS.map((t) => (
            <button key={t} className={tab === t ? 'active' : ''} onClick={() => setTab(t)}>{t}</button>
          ))}
        </div>
        {tab === 'Discover' && (
          <div className="input-icon" style={{ minWidth: 240 }}>
            <i className="bi bi-search"></i>
            <input className="form-control" placeholder="Search projects or skills..." value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
        )}
      </div>

      {loading ? (
        <Loading />
      ) : filtered.length === 0 ? (
        <EmptyState
          icon="bi-people"
          title={tab === 'Teammates' ? 'No open teammates yet' : 'Nothing here yet'}
          subtitle={tab === 'Discover' ? 'Be the first to post a project!' : ''}
          action={tab === 'My Posts' ? <button className="btn btn-primary" onClick={() => navigate('/collaborations/create')}>Create a Project</button> : null}
        />
      ) : tab === 'Teammates' ? (
        <div className="row g-3">
          {filtered.map((u) => (
            <div className="col-sm-6 col-lg-4" key={u.id}>
              <Link to={`/u/${u.id}`} className="text-reset">
                <div className="card-clean card-hover p-3 h-100">
                  <div className="d-flex align-items-center gap-3 mb-2">
                    <Avatar src={u.profile_image_url} name={u.name} size={48} />
                    <div>
                      <div className="fw-bold">{u.name}</div>
                      <div className="small text-secondary">{u.collaboration_headline || u.profession || 'Open to collaborate'}</div>
                    </div>
                  </div>
                  {u.bio && <p className="small text-secondary line-clamp-2 mb-2">{u.bio}</p>}
                  <div className="d-flex flex-wrap gap-1">
                    {(u.skills || []).slice(0, 4).map((s) => (
                      <span key={s} className="chip chip-static" style={{ fontSize: '0.7rem', padding: '0.15rem 0.5rem' }}>{s}</span>
                    ))}
                  </div>
                </div>
              </Link>
            </div>
          ))}
        </div>
      ) : tab === 'Applications' ? (
        <div className="d-flex flex-column gap-2">
          {filtered.map((a) => (
            <Link to={`/collaborations/${a.collaboration_id}`} key={a.id} className="text-reset">
              <div className="card-clean card-hover p-3 d-flex justify-content-between align-items-center">
                <div>
                  <div className="fw-semibold">{a.collaborations?.title || 'Project'}</div>
                  <div className="small text-secondary">{a.role_title || 'General'} · applied {timeAgo(a.created_at)}</div>
                </div>
                <StatusBadge status={a.status} />
              </div>
            </Link>
          ))}
        </div>
      ) : (
        <div className="row g-3">
          {filtered.map((c) => (
            <div className="col-sm-6 col-lg-4" key={c.id}>
              <ProjectCard c={c} />
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
