import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { profileService } from '../../services/profileService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'

export default function CollaborationProfile() {
  const { profile, userId, refreshProfile } = useAuth()
  const navigate = useNavigate()
  const toast = useToast()
  const [form, setForm] = useState({
    collaboration_enabled: profile?.collaboration_enabled || false,
    collaboration_headline: profile?.collaboration_headline || '',
    bio: profile?.bio || '',
    availability: profile?.availability || '',
  })
  const [skills, setSkills] = useState(profile?.skills || [])
  const [skillInput, setSkillInput] = useState('')
  const [saving, setSaving] = useState(false)

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value })

  const addSkill = () => {
    const s = skillInput.trim()
    if (s && !skills.includes(s)) setSkills([...skills, s])
    setSkillInput('')
  }

  const save = async () => {
    setSaving(true)
    try {
      await profileService.update(userId, {
        collaboration_enabled: form.collaboration_enabled,
        collaboration_headline: form.collaboration_headline,
        bio: form.bio,
        availability: form.availability,
        skills,
      })
      await refreshProfile()
      toast.success('Collaboration profile updated')
    } catch (err) {
      toast.error(err.message || 'Update failed')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="container-app" style={{ maxWidth: 640 }}>
      <button className="btn btn-light mb-3" onClick={() => navigate(-1)}><i className="bi bi-arrow-left me-1"></i>Back</button>
      <h3 className="fw-bold mb-1">Collaboration Profile</h3>
      <p className="text-secondary">Let others find you for projects.</p>

      <div className="card-clean p-4">
        <div className="form-check form-switch mb-3">
          <input className="form-check-input" type="checkbox" id="open" checked={form.collaboration_enabled} onChange={(e) => setForm({ ...form, collaboration_enabled: e.target.checked })} style={{ width: 44, height: 24 }} />
          <label className="form-check-label fw-semibold ms-2" htmlFor="open">Open to Collaborate</label>
          <div className="small text-secondary ms-2">When on, you appear in the "Teammates" tab.</div>
        </div>
        <div className="mb-3">
          <label className="form-label">Headline</label>
          <input className="form-control" placeholder="e.g. Full-stack developer & designer" value={form.collaboration_headline} onChange={set('collaboration_headline')} />
        </div>
        <div className="mb-3">
          <label className="form-label">Bio</label>
          <textarea className="form-control" rows={4} placeholder="Tell teams about yourself..." value={form.bio} onChange={set('bio')} />
        </div>
        <div className="mb-3">
          <label className="form-label">Availability</label>
          <input className="form-control" placeholder="e.g. 20 hrs/week, weekends" value={form.availability} onChange={set('availability')} />
        </div>
        <div className="mb-3">
          <label className="form-label">Skills</label>
          <div className="d-flex gap-2 mb-2">
            <input className="form-control" placeholder="Add a skill" value={skillInput} onChange={(e) => setSkillInput(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && (e.preventDefault(), addSkill())} />
            <button className="btn btn-soft" onClick={addSkill}>Add</button>
          </div>
          <div className="d-flex flex-wrap gap-1">
            {skills.map((s) => <span key={s} className="chip" onClick={() => setSkills(skills.filter((x) => x !== s))}>{s} <i className="bi bi-x"></i></span>)}
          </div>
        </div>
        <button className="btn btn-primary" onClick={save} disabled={saving}>
          {saving ? <span className="spinner-border spinner-border-sm me-2"></span> : <i className="bi bi-check-lg me-2"></i>}Save
        </button>
      </div>
    </div>
  )
}
