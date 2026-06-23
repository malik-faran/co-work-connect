import { useEffect, useState, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { profileService } from '../../services/profileService'
import { storageService } from '../../services/storageService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { Loading, EmptyState, Modal } from '../../components/common'

export default function PortfolioEditor() {
  const { userId, profile, refreshProfile } = useAuth()
  const navigate = useNavigate()
  const toast = useToast()
  const resumeInputRef = useRef(null)
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [show, setShow] = useState(false)
  const [editing, setEditing] = useState(null)
  const [form, setForm] = useState({ title: '', description: '', project_url: '', skills: [] })
  const [skillInput, setSkillInput] = useState('')
  const [file, setFile] = useState(null)
  const [saving, setSaving] = useState(false)
  const [resumeUploading, setResumeUploading] = useState(false)

  const load = async () => {
    try {
      setItems(await profileService.getPortfolio(userId))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { if (userId) load() }, [userId])

  const uploadResume = async (e) => {
    const f = e.target.files?.[0]
    if (!f) return
    setResumeUploading(true)
    try {
      const url = await storageService.uploadResume(userId, f)
      await profileService.updateResume(userId, url, f.name)
      await refreshProfile()
      toast.success('Resume uploaded')
    } catch (err) {
      toast.error(err.message || 'Resume upload failed')
    } finally {
      setResumeUploading(false)
      if (resumeInputRef.current) resumeInputRef.current.value = ''
    }
  }

  const removeResume = async () => {
    if (!confirm('Remove your uploaded resume?')) return
    setResumeUploading(true)
    try {
      await profileService.clearResume(userId)
      await refreshProfile()
      toast.success('Resume removed')
    } catch (err) {
      toast.error(err.message || 'Could not remove resume')
    } finally {
      setResumeUploading(false)
    }
  }

  const openNew = () => {
    setEditing(null)
    setForm({ title: '', description: '', project_url: '', skills: [] })
    setFile(null)
    setShow(true)
  }
  const openEdit = (it) => {
    setEditing(it)
    setForm({ title: it.title, description: it.description || '', project_url: it.project_url || '', skills: it.skills || [] })
    setFile(null)
    setShow(true)
  }

  const addSkill = () => {
    const s = skillInput.trim()
    if (s && !form.skills.includes(s)) setForm({ ...form, skills: [...form.skills, s] })
    setSkillInput('')
  }

  const save = async () => {
    if (!form.title.trim()) return toast.error('Title required')
    setSaving(true)
    try {
      let imageUrl = editing?.image_url || null
      if (file) imageUrl = await storageService.uploadPortfolioImage(userId, file)
      await profileService.savePortfolioItem({
        id: editing?.id,
        user_id: userId,
        title: form.title,
        description: form.description,
        project_url: form.project_url,
        skills: form.skills,
        image_url: imageUrl,
        sort_order: editing?.sort_order ?? items.length,
        created_at: editing?.created_at,
      })
      toast.success('Saved')
      setShow(false)
      load()
    } catch (err) {
      toast.error(err.message || 'Save failed')
    } finally {
      setSaving(false)
    }
  }

  const remove = async (it) => {
    if (!confirm('Delete this item?')) return
    await profileService.deletePortfolioItem(it.id)
    load()
  }

  if (loading) return <Loading />

  const hasResume = profile?.resume_url

  return (
    <div className="container-app" style={{ maxWidth: 820 }}>
      <button className="btn btn-light mb-3" onClick={() => navigate(-1)}><i className="bi bi-arrow-left me-1"></i>Back</button>
      <div className="d-flex justify-content-between align-items-center mb-3">
        <h3 className="fw-bold mb-0">Portfolio</h3>
        <button className="btn btn-primary" onClick={openNew}><i className="bi bi-plus-lg me-1"></i>Add Item</button>
      </div>

      {/* Resume section */}
      <div className="card-clean p-4 mb-4">
        <div className="d-flex align-items-start gap-3">
          <div className="stat-icon" style={{ background: 'var(--primary-gradient)', width: 48, height: 48 }}>
            <i className="bi bi-file-earmark-person text-white fs-5"></i>
          </div>
          <div className="flex-fill">
            <h6 className="fw-bold mb-1">My Resume / CV</h6>
            <p className="text-secondary small mb-0">
              {hasResume ? profile.resume_file_name || 'Resume uploaded' : 'Upload PDF, DOC, or DOCX (max 10 MB)'}
            </p>
          </div>
        </div>
        <div className="mt-3 d-flex flex-wrap gap-2">
          {resumeUploading ? (
            <span className="text-secondary small"><span className="spinner-border spinner-border-sm me-2"></span>Uploading...</span>
          ) : hasResume ? (
            <>
              <a href={profile.resume_url} target="_blank" rel="noreferrer" className="btn btn-soft btn-sm">
                <i className="bi bi-eye me-1"></i>View
              </a>
              <label className="btn btn-light btn-sm mb-0">
                <i className="bi bi-upload me-1"></i>Replace
                <input ref={resumeInputRef} type="file" accept=".pdf,.doc,.docx,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document" hidden onChange={uploadResume} />
              </label>
              <button className="btn btn-light btn-sm text-danger" onClick={removeResume}>
                <i className="bi bi-trash me-1"></i>Remove
              </button>
            </>
          ) : (
            <label className="btn btn-primary btn-sm mb-0">
              <i className="bi bi-upload me-1"></i>Upload Resume
              <input ref={resumeInputRef} type="file" accept=".pdf,.doc,.docx,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document" hidden onChange={uploadResume} />
            </label>
          )}
        </div>
      </div>

      <h6 className="fw-bold mb-3">Portfolio work</h6>

      {items.length === 0 ? (
        <EmptyState icon="bi-briefcase" title="No portfolio items" subtitle="Showcase your work to attract collaborators." action={<button className="btn btn-primary" onClick={openNew}>Add your first item</button>} />
      ) : (
        <div className="row g-3">
          {items.map((it) => (
            <div className="col-md-6" key={it.id}>
              <div className="card-clean overflow-hidden h-100">
                {it.image_url && <img src={it.image_url} alt={it.title} style={{ height: 150, width: '100%', objectFit: 'cover' }} />}
                <div className="p-3">
                  <div className="d-flex justify-content-between">
                    <h6 className="fw-bold">{it.title}</h6>
                    <div className="d-flex gap-1">
                      <button className="btn btn-light btn-sm" onClick={() => openEdit(it)}><i className="bi bi-pencil"></i></button>
                      <button className="btn btn-light btn-sm text-danger" onClick={() => remove(it)}><i className="bi bi-trash"></i></button>
                    </div>
                  </div>
                  {it.description && <p className="small text-secondary line-clamp-2">{it.description}</p>}
                  <div className="d-flex flex-wrap gap-1">
                    {(it.skills || []).map((s) => <span key={s} className="chip chip-static" style={{ fontSize: '0.7rem', padding: '0.15rem 0.5rem' }}>{s}</span>)}
                  </div>
                  {it.project_url && <a href={it.project_url} target="_blank" rel="noreferrer" className="small d-block mt-2"><i className="bi bi-link-45deg"></i>View project</a>}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {show && (
        <Modal show onClose={() => setShow(false)} title={editing ? 'Edit item' : 'Add portfolio item'} footer={
          <>
            <button className="btn btn-light" onClick={() => setShow(false)}>Cancel</button>
            <button className="btn btn-primary" onClick={save} disabled={saving}>{saving ? <span className="spinner-border spinner-border-sm me-2"></span> : null}Save</button>
          </>
        }>
          <div className="mb-2"><label className="form-label">Title</label><input className="form-control" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></div>
          <div className="mb-2"><label className="form-label">Description</label><textarea className="form-control" rows={3} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></div>
          <div className="mb-2"><label className="form-label">Project URL</label><input className="form-control" value={form.project_url} onChange={(e) => setForm({ ...form, project_url: e.target.value })} /></div>
          <div className="mb-2">
            <label className="form-label">Skills</label>
            <div className="d-flex gap-2 mb-2">
              <input className="form-control" value={skillInput} onChange={(e) => setSkillInput(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && (e.preventDefault(), addSkill())} placeholder="Add skill" />
              <button className="btn btn-soft" onClick={addSkill}>Add</button>
            </div>
            <div className="d-flex flex-wrap gap-1">{form.skills.map((s) => <span key={s} className="chip" onClick={() => setForm({ ...form, skills: form.skills.filter((x) => x !== s) })}>{s} <i className="bi bi-x"></i></span>)}</div>
          </div>
          <div><label className="form-label">Image</label><input type="file" accept="image/*" className="form-control" onChange={(e) => setFile(e.target.files[0])} /></div>
        </Modal>
      )}
    </div>
  )
}
