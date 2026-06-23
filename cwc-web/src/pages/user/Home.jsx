import { useEffect, useMemo, useState } from 'react'
import { useAuth } from '../../context/AuthContext'
import { workspaceService } from '../../services/workspaceService'
import WorkspaceCard from '../../components/WorkspaceCard'
import { Loading, EmptyState } from '../../components/common'
import { AMENITIES, WORKSPACE_TYPE_LABELS } from '../../lib/constants'

const TYPE_CHIPS = [
  { value: null, label: 'All', icon: 'bi-grid' },
  { value: 'private', label: 'Private Office', icon: 'bi-door-closed' },
  { value: 'meeting-room', label: 'Meeting Room', icon: 'bi-easel' },
  { value: 'shared', label: 'Shared Desk', icon: 'bi-people' },
]

export default function Home() {
  const { profile } = useAuth()
  const [all, setAll] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [type, setType] = useState(null)
  const [amenities, setAmenities] = useState([])
  const [showFilters, setShowFilters] = useState(false)

  useEffect(() => {
    workspaceService
      .getAll()
      .then(setAll)
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [])

  const toggleAmenity = (a) =>
    setAmenities((prev) => (prev.includes(a) ? prev.filter((x) => x !== a) : [...prev, a]))

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return all.filter((ws) => {
      if (q) {
        const hit = [ws.name, ws.city, ws.address].filter(Boolean).some((f) => f.toLowerCase().includes(q))
        if (!hit) return false
      }
      if (type) {
        let opts = ws.category_options
        if (typeof opts === 'string') { try { opts = JSON.parse(opts) } catch { opts = [] } }
        const inCats = Array.isArray(opts) && opts.some((c) => c.type === type)
        if (ws.workspace_type !== type && !inCats) return false
      }
      if (amenities.length) {
        const wa = (ws.amenities || []).map((x) => x.toLowerCase())
        if (!amenities.every((a) => wa.includes(a.toLowerCase()))) return false
      }
      return true
    })
  }, [all, search, type, amenities])

  if (loading) return <Loading message="Finding workspaces..." />

  return (
    <div className="container-app">
      {/* Greeting */}
      <div className="d-flex flex-wrap justify-content-between align-items-end gap-3 mb-4">
        <div>
          <p className="text-secondary mb-0">Hello, {profile?.name?.split(' ')[0] || 'there'} 👋</p>
          <h3 className="fw-bold mb-0">Find your perfect workspace</h3>
          {profile?.city && <span className="text-secondary small"><i className="bi bi-geo-alt me-1"></i>{profile.city}</span>}
        </div>
      </div>

      {/* Search */}
      <div className="card-clean p-3 mb-3">
        <div className="d-flex gap-2">
          <div className="input-icon flex-fill">
            <i className="bi bi-search"></i>
            <input className="form-control" placeholder="Search by name, city or address..." value={search} onChange={(e) => setSearch(e.target.value)} />
          </div>
          <button className={`btn ${showFilters || amenities.length ? 'btn-primary' : 'btn-light'}`} onClick={() => setShowFilters(!showFilters)}>
            <i className="bi bi-sliders"></i>
            {amenities.length > 0 && <span className="ms-1">{amenities.length}</span>}
          </button>
        </div>

        {/* Type chips */}
        <div className="d-flex gap-2 mt-3 flex-wrap">
          {TYPE_CHIPS.map((c) => (
            <button key={c.label} className={`chip ${type === c.value ? 'active' : ''}`} onClick={() => setType(c.value)}>
              <i className={`bi ${c.icon}`}></i>{c.label}
            </button>
          ))}
        </div>

        {showFilters && (
          <div className="mt-3 animate__animated animate__fadeIn">
            <div className="small fw-semibold mb-2">Amenities</div>
            <div className="d-flex gap-2 flex-wrap">
              {AMENITIES.map((a) => (
                <button key={a} className={`chip ${amenities.includes(a) ? 'active' : ''}`} onClick={() => toggleAmenity(a)}>{a}</button>
              ))}
            </div>
            {amenities.length > 0 && (
              <button className="btn btn-link btn-sm px-0 mt-2" onClick={() => setAmenities([])}>Clear filters</button>
            )}
          </div>
        )}
      </div>

      <div className="d-flex justify-content-between align-items-center mb-3">
        <span className="text-secondary">{filtered.length} workspace{filtered.length !== 1 ? 's' : ''} found</span>
      </div>

      {filtered.length === 0 ? (
        <EmptyState icon="bi-building-x" title="No workspaces found" subtitle="Try adjusting your search or filters." />
      ) : (
        <div className="row g-4">
          {filtered.map((ws) => (
            <div className="col-sm-6 col-lg-4 col-xl-3" key={ws.id}>
              <WorkspaceCard ws={ws} />
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
