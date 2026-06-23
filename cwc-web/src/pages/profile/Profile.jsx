import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { profileService } from '../../services/profileService'
import { storageService } from '../../services/storageService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { Avatar } from '../../components/common'
import { CITIES } from '../../lib/constants'

export default function Profile() {
  const { profile, userId, isOwner, refreshProfile, signOut } = useAuth()
  const navigate = useNavigate()
  const toast = useToast()
  const [form, setForm] = useState({
    name: profile?.name || '',
    phone: profile?.phone || '',
    city: profile?.city || '',
    business_name: profile?.business_name || '',
  })
  const [saving, setSaving] = useState(false)
  const [uploading, setUploading] = useState(false)

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value })

  const save = async () => {
    setSaving(true)
    try {
      const fields = { name: form.name, phone: form.phone, city: form.city }
      if (isOwner) fields.business_name = form.business_name
      await profileService.update(userId, fields)
      await refreshProfile()
      toast.success('Profile updated')
    } catch (err) {
      toast.error(err.message || 'Update failed')
    } finally {
      setSaving(false)
    }
  }

  const changePhoto = async (e) => {
    const f = e.target.files[0]
    if (!f) return
    setUploading(true)
    try {
      const url = await storageService.uploadProfileImage(userId, f)
      await profileService.update(userId, { profile_image_url: url })
      await refreshProfile()
      toast.success('Photo updated')
    } catch (err) {
      toast.error('Could not upload photo')
    } finally {
      setUploading(false)
    }
  }

  const logout = async () => {
    await signOut()
    navigate('/login')
  }

  return (
    <div className="container-app" style={{ maxWidth: 720 }}>
      <h3 className="fw-bold mb-3">My Profile</h3>

      <div className="card-clean p-4 mb-3">
        <div className="d-flex align-items-center gap-3">
          <div className="position-relative">
            <Avatar src={profile?.profile_image_url} name={profile?.name} size={80} />
            <label className="btn btn-primary btn-sm rounded-circle position-absolute bottom-0 end-0 mb-0 p-1" style={{ width: 30, height: 30 }}>
              {uploading ? <span className="spinner-border spinner-border-sm"></span> : <i className="bi bi-camera"></i>}
              <input type="file" accept="image/*" hidden onChange={changePhoto} />
            </label>
          </div>
          <div>
            <h5 className="fw-bold mb-0">{profile?.name}</h5>
            <div className="text-secondary">{profile?.email}</div>
            <span className="badge-soft badge-primary-soft mt-1 d-inline-block text-capitalize">{profile?.role}</span>
          </div>
        </div>
      </div>

      <div className="card-clean p-4 mb-3">
        <h6 className="fw-bold mb-3">Account details</h6>
        <div className="row g-3">
          <div className="col-md-6">
            <label className="form-label">Full name</label>
            <input className="form-control" value={form.name} onChange={set('name')} />
          </div>
          <div className="col-md-6">
            <label className="form-label">Phone</label>
            <input className="form-control" value={form.phone} onChange={set('phone')} />
          </div>
          <div className="col-md-6">
            <label className="form-label">City</label>
            <select className="form-select" value={form.city} onChange={set('city')}>
              <option value="">Select city</option>
              {CITIES.map((c) => <option key={c}>{c}</option>)}
            </select>
          </div>
          {isOwner && (
            <div className="col-md-6">
              <label className="form-label">Business name</label>
              <input className="form-control" value={form.business_name} onChange={set('business_name')} />
            </div>
          )}
        </div>
        <button className="btn btn-primary mt-3" onClick={save} disabled={saving}>
          {saving ? <span className="spinner-border spinner-border-sm me-2"></span> : <i className="bi bi-check-lg me-2"></i>}Save Changes
        </button>
      </div>

      <div className="card-clean p-2 mb-3">
        <Link to="/collaboration-profile" className="d-flex align-items-center gap-3 p-3 text-reset border-bottom">
          <i className="bi bi-stars text-primary fs-5"></i><span className="flex-fill fw-semibold">Collaboration Profile</span><i className="bi bi-chevron-right text-secondary"></i>
        </Link>
        <Link to="/portfolio" className="d-flex align-items-center gap-3 p-3 text-reset border-bottom">
          <i className="bi bi-briefcase text-primary fs-5"></i><span className="flex-fill fw-semibold">Portfolio</span><i className="bi bi-chevron-right text-secondary"></i>
        </Link>
        <Link to="/payments" className="d-flex align-items-center gap-3 p-3 text-reset border-bottom">
          <i className="bi bi-receipt text-primary fs-5"></i><span className="flex-fill fw-semibold">Payment History</span><i className="bi bi-chevron-right text-secondary"></i>
        </Link>
        {isOwner && (
          <Link to="/owner/payment-accounts" className="d-flex align-items-center gap-3 p-3 text-reset border-bottom">
            <i className="bi bi-bank text-primary fs-5"></i><span className="flex-fill fw-semibold">Payment Accounts</span><i className="bi bi-chevron-right text-secondary"></i>
          </Link>
        )}
        <Link to="/sos" className="d-flex align-items-center gap-3 p-3 text-reset">
          <i className="bi bi-shield-exclamation text-danger fs-5"></i><span className="flex-fill fw-semibold">Emergency / SOS</span><i className="bi bi-chevron-right text-secondary"></i>
        </Link>
      </div>

      <button className="btn btn-light text-danger w-100" onClick={logout}><i className="bi bi-box-arrow-right me-2"></i>Logout</button>
    </div>
  )
}
