import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { collaborationService } from '../../services/collaborationService'
import { storageService } from '../../services/storageService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { PROJECT_TYPES } from '../../lib/constants'
import { Loading } from '../../components/common'

function SkillInput({ skills, setSkills }) {
  const [val, setVal] = useState('')
  const add = () => {
    const s = val.trim()
    if (s && !skills.includes(s)) setSkills([...skills, s])
    setVal('')
  }
  return (
    <div>
      <div className="d-flex gap-2 mb-2">
        <input className="form-control" placeholder="Add a skill" value={val} onChange={(e) => setVal(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && (e.preventDefault(), add())} />
        <button type="button" className="btn btn-soft" onClick={add}>Add</button>
      </div>
      <div className="d-flex flex-wrap gap-1">
        {skills.map((s) => (
          <span key={s} className="chip" onClick={() => setSkills(skills.filter((x) => x !== s))}>{s} <i className="bi bi-x"></i></span>
        ))}
      </div>
    </div>
  )
}

export default function CollabCreate() {
  const navigate = useNavigate()
  const { id } = useParams()
  const isEdit = !!id
  const { profile } = useAuth()
  const toast = useToast()

  const [step, setStep] = useState(1)
  const [loading, setLoading] = useState(isEdit)
  const [saving, setSaving] = useState(false)
  const [cover, setCover] = useState(null)
  const [form, setForm] = useState({
    title: '', description: '', projectType: PROJECT_TYPES[0], budget: '', timeline: '', visibility: 'public',
  })
  const [roles, setRoles] = useState([{ title: '', skills: [] }])

  useEffect(() => {
    if (isEdit) {
      collaborationService.getById(id).then((c) => {
        if (c) setForm({ title: c.title, description: c.description, projectType: c.project_type || PROJECT_TYPES[0], budget: c.budget || '', timeline: c.timeline || '', visibility: c.visibility || 'public' })
        setLoading(false)
      })
    }
  }, [id, isEdit])

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value })
  const setRole = (i, k, v) => setRoles(roles.map((r, idx) => (idx === i ? { ...r, [k]: v } : r)))

  const submit = async () => {
    if (!form.title.trim() || !form.description.trim()) { setStep(1); return toast.error('Title and description are required') }
    setSaving(true)
    try {
      if (isEdit) {
        await collaborationService.updateProject(id, {
          title: form.title, description: form.description, project_type: form.projectType,
          budget: form.budget || null, timeline: form.timeline || null, visibility: form.visibility,
        })
        toast.success('Project updated')
        navigate(`/collaborations/${id}`)
      } else {
        const validRoles = roles.filter((r) => r.title.trim() && r.skills.length)
        if (!validRoles.length) { setStep(3); return toast.error('Add at least one role with skills') }
        const project = await collaborationService.createProject({
          owner: profile,
          title: form.title, description: form.description, projectType: form.projectType,
          budget: form.budget, timeline: form.timeline, visibility: form.visibility,
          roles: validRoles,
        })
        if (cover) {
          try {
            const url = await storageService.uploadProjectCover(project.id, cover)
            await collaborationService.updateProject(project.id, { cover_image_url: url })
          } catch { /* ignore */ }
        }
        toast.success('Project published!')
        navigate(`/collaborations/${project.id}`)
      }
    } catch (err) {
      toast.error(err.message || 'Failed to save')
    } finally {
      setSaving(false)
    }
  }

  if (loading) return <Loading />

  return (
    <div className="container-app" style={{ maxWidth: 720 }}>
      <button className="btn btn-light mb-3" onClick={() => navigate(-1)}><i className="bi bi-arrow-left me-1"></i>Back</button>
      <h3 className="fw-bold mb-1">{isEdit ? 'Edit Project' : 'Create a Project'}</h3>
      <p className="text-secondary">Recruit teammates and build something great.</p>

      {!isEdit && (
        <div className="d-flex gap-2 mb-4">
          {[1, 2, 3].map((s) => (
            <div key={s} className="flex-fill text-center">
              <div className="rounded-pill" style={{ height: 6, background: s <= step ? 'var(--primary)' : '#e2e8f0' }} />
              <small className={s <= step ? 'text-primary fw-semibold' : 'text-secondary'}>{['Basics', 'Details', 'Roles'][s - 1]}</small>
            </div>
          ))}
        </div>
      )}

      <div className="card-clean p-4">
        {step === 1 && (
          <div className="d-flex flex-column gap-3 animate__animated animate__fadeIn">
            <div>
              <label className="form-label">Project title</label>
              <input className="form-control" placeholder="e.g. Build a food delivery app" value={form.title} onChange={set('title')} />
            </div>
            <div>
              <label className="form-label">Description</label>
              <textarea className="form-control" rows={5} placeholder="Describe your project, goals and what you're looking for..." value={form.description} onChange={set('description')} />
            </div>
            <div>
              <label className="form-label">Category</label>
              <select className="form-select" value={form.projectType} onChange={set('projectType')}>
                {PROJECT_TYPES.map((p) => <option key={p}>{p}</option>)}
              </select>
            </div>
          </div>
        )}

        {step === 2 && (
          <div className="d-flex flex-column gap-3 animate__animated animate__fadeIn">
            <div className="row g-3">
              <div className="col-md-6">
                <label className="form-label">Budget <span className="text-secondary fw-normal">(optional)</span></label>
                <input className="form-control" placeholder="e.g. Rs. 50,000 or Equity" value={form.budget} onChange={set('budget')} />
              </div>
              <div className="col-md-6">
                <label className="form-label">Timeline <span className="text-secondary fw-normal">(optional)</span></label>
                <input className="form-control" placeholder="e.g. 2 months" value={form.timeline} onChange={set('timeline')} />
              </div>
            </div>
            <div>
              <label className="form-label">Visibility</label>
              <select className="form-select" value={form.visibility} onChange={set('visibility')}>
                <option value="public">Public — anyone can discover</option>
                <option value="invite_only">Invite only — share by link/invite</option>
              </select>
            </div>
            {!isEdit && (
              <div>
                <label className="form-label">Cover image <span className="text-secondary fw-normal">(optional)</span></label>
                <input type="file" accept="image/*" className="form-control" onChange={(e) => setCover(e.target.files[0])} />
                {cover && <img src={URL.createObjectURL(cover)} alt="cover" className="mt-2" style={{ height: 120, borderRadius: 12, objectFit: 'cover' }} />}
              </div>
            )}
          </div>
        )}

        {step === 3 && !isEdit && (
          <div className="d-flex flex-column gap-3 animate__animated animate__fadeIn">
            <p className="text-secondary mb-0">Define the roles you need. Each role needs at least one skill.</p>
            {roles.map((r, i) => (
              <div key={i} className="card-clean p-3">
                <div className="d-flex justify-content-between align-items-center mb-2">
                  <span className="fw-semibold">Role {i + 1}</span>
                  {roles.length > 1 && <button className="btn btn-link btn-sm text-danger p-0" onClick={() => setRoles(roles.filter((_, idx) => idx !== i))}>Remove</button>}
                </div>
                <input className="form-control mb-2" placeholder="Role title (e.g. UI Designer)" value={r.title} onChange={(e) => setRole(i, 'title', e.target.value)} />
                <SkillInput skills={r.skills} setSkills={(s) => setRole(i, 'skills', s)} />
              </div>
            ))}
            <button className="btn btn-soft" onClick={() => setRoles([...roles, { title: '', skills: [] }])}><i className="bi bi-plus-lg me-1"></i>Add another role</button>
          </div>
        )}

        <hr className="divider my-4" />
        <div className="d-flex justify-content-between">
          <button className="btn btn-light" onClick={() => (step > 1 ? setStep(step - 1) : navigate(-1))}>{step > 1 ? 'Back' : 'Cancel'}</button>
          {isEdit || step === 3 ? (
            <button className="btn btn-primary" onClick={submit} disabled={saving}>
              {saving ? <span className="spinner-border spinner-border-sm me-2"></span> : null}
              {isEdit ? 'Save Changes' : 'Publish Project'}
            </button>
          ) : (
            <button className="btn btn-primary" onClick={() => setStep(step + 1)}>Continue<i className="bi bi-arrow-right ms-1"></i></button>
          )}
        </div>
      </div>
    </div>
  )
}
