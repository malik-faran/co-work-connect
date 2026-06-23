import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { workspaceService } from '../../services/workspaceService'
import { storageService } from '../../services/storageService'
import { useAuth } from '../../context/AuthContext'
import { useToast } from '../../context/ToastContext'
import { Loading } from '../../components/common'
import { CITIES, AMENITIES, WORKSPACE_TYPE_LABELS } from '../../lib/constants'
import { uuid } from '../../lib/helpers'

const CAT_TYPES = ['private', 'shared', 'meeting-room']

function buildTimeSlots(open, close) {
  const oh = parseInt(open.split(':')[0], 10)
  const ch = parseInt(close.split(':')[0], 10)
  const slots = []
  for (let h = oh; h < ch; h++) {
    slots.push({ id: uuid(), label: `${String(h).padStart(2, '0')}:00 - ${String(h + 1).padStart(2, '0')}:00`, startHour: h, endHour: h + 1 })
  }
  return slots
}

export default function AddWorkspace() {
  const { id } = useParams()
  const isEdit = !!id
  const navigate = useNavigate()
  const { userId } = useAuth()
  const toast = useToast()

  const [loading, setLoading] = useState(isEdit)
  const [saving, setSaving] = useState(false)
  const [existing, setExisting] = useState(null)

  const [form, setForm] = useState({
    name: '', description: '', address: '', city: CITIES[0], latitude: 0, longitude: 0,
    phone: '', email: '', opening_time: '09:00', closing_time: '18:00', is_available: true,
  })
  const [amenities, setAmenities] = useState([])
  const [categories, setCategories] = useState({
    private: { enabled: false, capacity: 1, pricePerHour: 500, pricePerDay: 3000 },
    shared: { enabled: true, capacity: 10, pricePerHour: 200, pricePerDay: 1200 },
    'meeting-room': { enabled: false, capacity: 8, pricePerHour: 800, pricePerDay: 5000 },
  })
  const [existingImages, setExistingImages] = useState([])
  const [files, setFiles] = useState([])

  useEffect(() => {
    if (!isEdit) return
    workspaceService.getById(id).then((ws) => {
      if (ws) {
        setExisting(ws)
        setForm({
          name: ws.name, description: ws.description, address: ws.address, city: ws.city,
          latitude: ws.latitude, longitude: ws.longitude, phone: ws.phone || '', email: ws.email || '',
          opening_time: ws.opening_time, closing_time: ws.closing_time, is_available: ws.is_available,
        })
        setAmenities(ws.amenities || [])
        setExistingImages(ws.image_urls || [])
        let opts = ws.category_options
        if (typeof opts === 'string') { try { opts = JSON.parse(opts) } catch { opts = [] } }
        const cats = { ...categories }
        Object.keys(cats).forEach((k) => (cats[k].enabled = false))
        ;(opts || []).forEach((o) => {
          if (cats[o.type]) cats[o.type] = { enabled: true, capacity: o.capacity, pricePerHour: o.pricePerHour ?? o.price_per_hour, pricePerDay: o.pricePerDay ?? o.price_per_day }
        })
        setCategories(cats)
      }
      setLoading(false)
    })
    // eslint-disable-next-line
  }, [id])

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value })
  const toggleAmenity = (a) => setAmenities((p) => (p.includes(a) ? p.filter((x) => x !== a) : [...p, a]))
  const setCat = (type, field, value) => setCategories((c) => ({ ...c, [type]: { ...c[type], [field]: value } }))

  const save = async () => {
    const enabled = CAT_TYPES.filter((t) => categories[t].enabled)
    if (!form.name.trim() || !form.address.trim()) return toast.error('Name and address are required')
    if (!enabled.length) return toast.error('Enable at least one workspace category')
    if (!isEdit && files.length === 0) return toast.error('Add at least one image')

    setSaving(true)
    try {
      const wsId = isEdit ? id : uuid()
      let imageUrls = [...existingImages]
      for (const f of files) {
        const url = await storageService.uploadWorkspaceImage(wsId, f)
        imageUrls.push(url)
      }

      const categoryOptions = enabled.map((t) => ({
        type: t,
        capacity: Number(categories[t].capacity),
        pricePerHour: Number(categories[t].pricePerHour),
        pricePerDay: Number(categories[t].pricePerDay),
      }))
      const first = categoryOptions[0]
      const slots = buildTimeSlots(form.opening_time, form.closing_time)

      const payload = {
        owner_id: userId,
        name: form.name,
        description: form.description,
        address: form.address,
        city: form.city,
        country: 'Pakistan',
        latitude: Number(form.latitude) || 0,
        longitude: Number(form.longitude) || 0,
        price_per_day: first.pricePerDay,
        price_per_hour: 0,
        capacity: Math.max(1, categoryOptions.reduce((s, c) => s + c.capacity, 0)),
        amenities,
        image_urls: imageUrls,
        is_available: form.is_available,
        workspace_type: first.type,
        category_options: categoryOptions,
        time_slots: slots.length ? slots : existing?.time_slots || [],
        opening_time: form.opening_time,
        closing_time: form.closing_time,
        phone: form.phone || null,
        email: form.email || null,
        operating_hours: [`${form.opening_time} - ${form.closing_time}`],
      }

      if (isEdit) {
        await workspaceService.update(id, payload)
        toast.success('Workspace updated')
      } else {
        await workspaceService.create({ id: wsId, ...payload, created_at: new Date().toISOString() })
        toast.success('Workspace published!')
      }
      navigate('/owner')
    } catch (err) {
      toast.error(err.message || 'Save failed')
    } finally {
      setSaving(false)
    }
  }

  if (loading) return <Loading />

  return (
    <div className="container-app" style={{ maxWidth: 820 }}>
      <button className="btn btn-light mb-3" onClick={() => navigate(-1)}><i className="bi bi-arrow-left me-1"></i>Back</button>
      <h3 className="fw-bold mb-3">{isEdit ? 'Edit Workspace' : 'Add Workspace'}</h3>

      {/* Basics */}
      <div className="card-clean p-4 mb-3">
        <h6 className="fw-bold mb-3">Basic information</h6>
        <div className="row g-3">
          <div className="col-12"><label className="form-label">Name</label><input className="form-control" value={form.name} onChange={set('name')} placeholder="e.g. The Hub Coworking" /></div>
          <div className="col-12"><label className="form-label">Description</label><textarea className="form-control" rows={3} value={form.description} onChange={set('description')} /></div>
          <div className="col-md-8"><label className="form-label">Address</label><input className="form-control" value={form.address} onChange={set('address')} /></div>
          <div className="col-md-4"><label className="form-label">City</label><select className="form-select" value={form.city} onChange={set('city')}>{CITIES.map((c) => <option key={c}>{c}</option>)}</select></div>
          <div className="col-md-6"><label className="form-label">Latitude</label><input type="number" className="form-control" value={form.latitude} onChange={set('latitude')} /></div>
          <div className="col-md-6"><label className="form-label">Longitude</label><input type="number" className="form-control" value={form.longitude} onChange={set('longitude')} /></div>
          <div className="col-md-6"><label className="form-label">Phone</label><input className="form-control" value={form.phone} onChange={set('phone')} /></div>
          <div className="col-md-6"><label className="form-label">Email</label><input className="form-control" value={form.email} onChange={set('email')} /></div>
          <div className="col-md-6"><label className="form-label">Opening time</label><input type="time" className="form-control" value={form.opening_time} onChange={set('opening_time')} /></div>
          <div className="col-md-6"><label className="form-label">Closing time</label><input type="time" className="form-control" value={form.closing_time} onChange={set('closing_time')} /></div>
        </div>
      </div>

      {/* Categories */}
      <div className="card-clean p-4 mb-3">
        <h6 className="fw-bold mb-3">Workspace categories & pricing</h6>
        {CAT_TYPES.map((t) => (
          <div key={t} className="card-clean p-3 mb-2">
            <div className="form-check form-switch mb-2">
              <input className="form-check-input" type="checkbox" checked={categories[t].enabled} onChange={(e) => setCat(t, 'enabled', e.target.checked)} style={{ width: 40, height: 22 }} />
              <label className="form-check-label fw-semibold ms-2">{WORKSPACE_TYPE_LABELS[t]}</label>
            </div>
            {categories[t].enabled && (
              <div className="row g-2">
                <div className="col-4"><label className="form-label small">Capacity</label><input type="number" className="form-control" value={categories[t].capacity} onChange={(e) => setCat(t, 'capacity', e.target.value)} /></div>
                <div className="col-4"><label className="form-label small">Price/hour</label><input type="number" className="form-control" value={categories[t].pricePerHour} onChange={(e) => setCat(t, 'pricePerHour', e.target.value)} /></div>
                <div className="col-4"><label className="form-label small">Price/day</label><input type="number" className="form-control" value={categories[t].pricePerDay} onChange={(e) => setCat(t, 'pricePerDay', e.target.value)} /></div>
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Amenities */}
      <div className="card-clean p-4 mb-3">
        <h6 className="fw-bold mb-3">Amenities</h6>
        <div className="d-flex flex-wrap gap-2">
          {AMENITIES.map((a) => <button key={a} className={`chip ${amenities.includes(a) ? 'active' : ''}`} onClick={() => toggleAmenity(a)}>{a}</button>)}
        </div>
      </div>

      {/* Images */}
      <div className="card-clean p-4 mb-3">
        <h6 className="fw-bold mb-3">Images</h6>
        <input type="file" accept="image/*" multiple className="form-control mb-3" onChange={(e) => setFiles([...files, ...Array.from(e.target.files)])} />
        <div className="d-flex flex-wrap gap-2">
          {existingImages.map((url) => (
            <div key={url} className="position-relative">
              <img src={url} alt="" style={{ width: 90, height: 90, objectFit: 'cover', borderRadius: 10 }} />
              <button className="btn btn-danger btn-sm position-absolute top-0 end-0 p-0" style={{ width: 22, height: 22 }} onClick={() => setExistingImages(existingImages.filter((x) => x !== url))}><i className="bi bi-x"></i></button>
            </div>
          ))}
          {files.map((f, i) => (
            <div key={i} className="position-relative">
              <img src={URL.createObjectURL(f)} alt="" style={{ width: 90, height: 90, objectFit: 'cover', borderRadius: 10 }} />
              <button className="btn btn-danger btn-sm position-absolute top-0 end-0 p-0" style={{ width: 22, height: 22 }} onClick={() => setFiles(files.filter((_, idx) => idx !== i))}><i className="bi bi-x"></i></button>
            </div>
          ))}
        </div>
      </div>

      <div className="card-clean p-3 mb-3 d-flex justify-content-between align-items-center">
        <div className="form-check form-switch mb-0">
          <input className="form-check-input" type="checkbox" checked={form.is_available} onChange={(e) => setForm({ ...form, is_available: e.target.checked })} style={{ width: 44, height: 24 }} />
          <label className="form-check-label fw-semibold ms-2">Available for booking</label>
        </div>
      </div>

      <button className="btn btn-primary btn-lg w-100" onClick={save} disabled={saving}>
        {saving ? <span className="spinner-border spinner-border-sm me-2"></span> : <i className="bi bi-check-lg me-2"></i>}
        {isEdit ? 'Save Changes' : 'Publish Workspace'}
      </button>
    </div>
  )
}
