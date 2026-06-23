import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { collaborationService } from '../../services/collaborationService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'

export default function CollabJoin() {
  const { code: codeParam } = useParams()
  const navigate = useNavigate()
  const { userId, profile } = useAuth()
  const toast = useToast()
  const [code, setCode] = useState(codeParam || '')
  const [busy, setBusy] = useState(false)

  const resolve = (input) => {
    const trimmed = (input || '').trim()
    if (trimmed.includes('/')) return trimmed.split('/').filter(Boolean).pop()
    return trimmed
  }

  const join = async (raw) => {
    const c = resolve(raw)
    if (!c) return toast.error('Enter an invite code')
    setBusy(true)
    try {
      const project = await collaborationService.getByInviteCode(c)
      if (!project) { toast.error('Invalid invite code'); return }
      if (!project.invite_link_enabled) { toast.error('This invite link is disabled'); return }
      const member = await collaborationService.isMember(project.id, userId)
      if (member) return navigate(`/project/${project.id}`)
      if (project.status === 'recruiting') {
        toast.info('Apply to join this project.')
        return navigate(`/collaborations/${project.id}`)
      }
      if (project.status === 'active') {
        await collaborationService.joinActive({ project, user: profile, joinedVia: 'link' })
        toast.success('You joined the project!')
        return navigate(`/project/${project.id}`)
      }
      toast.error('This project is no longer accepting members')
    } catch (err) {
      toast.error(err.message || 'Could not join')
    } finally {
      setBusy(false)
    }
  }

  useEffect(() => {
    if (codeParam && userId) join(codeParam)
    // eslint-disable-next-line
  }, [codeParam, userId])

  return (
    <div className="container-app" style={{ maxWidth: 460 }}>
      <div className="card-clean p-4 text-center mt-4">
        <div className="empty-icon mx-auto mb-3"><i className="bi bi-link-45deg fs-1"></i></div>
        <h4 className="fw-bold">Join a Project</h4>
        <p className="text-secondary">Enter an invite code or paste an invite link.</p>
        <input className="form-control text-center mb-3" placeholder="INVITE CODE" value={code} onChange={(e) => setCode(e.target.value)} style={{ letterSpacing: 2, textTransform: 'uppercase' }} />
        <button className="btn btn-primary w-100" onClick={() => join(code)} disabled={busy}>
          {busy ? <span className="spinner-border spinner-border-sm me-2"></span> : <i className="bi bi-box-arrow-in-right me-2"></i>}Join Project
        </button>
      </div>
    </div>
  )
}
