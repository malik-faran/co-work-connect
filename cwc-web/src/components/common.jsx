import { initials } from '../lib/helpers'

export function Loading({ message = 'Loading...', full = false }) {
  return (
    <div className="spinner-wrap" style={full ? { minHeight: '100vh' } : undefined}>
      <div className="loader-ring" />
      <div>{message}</div>
    </div>
  )
}

export function EmptyState({ icon = 'bi-inbox', title, subtitle, action }) {
  return (
    <div className="empty-state animate__animated animate__fadeIn">
      <div className="empty-icon">
        <i className={`bi ${icon}`} style={{ fontSize: '2rem' }}></i>
      </div>
      <h5 className="mb-1">{title}</h5>
      {subtitle && <p className="text-secondary mb-3">{subtitle}</p>}
      {action}
    </div>
  )
}

export function Avatar({ src, name = '', size = 40, className = '' }) {
  const style = { width: size, height: size, fontSize: size * 0.4 }
  if (src) {
    return (
      <img
        src={src}
        alt={name}
        className={`avatar ${className}`}
        style={{ width: size, height: size }}
        onError={(e) => {
          e.currentTarget.style.display = 'none'
        }}
      />
    )
  }
  return (
    <span className={`avatar-fallback ${className}`} style={style}>
      {initials(name)}
    </span>
  )
}

export function Stars({ value = 0, size = '1rem' }) {
  const full = Math.round(value)
  return (
    <span style={{ fontSize: size, lineHeight: 1 }}>
      {[1, 2, 3, 4, 5].map((i) => (
        <i
          key={i}
          className={`bi ${i <= full ? 'bi-star-fill star' : 'bi-star star-empty'}`}
          style={{ marginRight: 1 }}
        ></i>
      ))}
    </span>
  )
}

export function Badge({ children, variant = 'neutral' }) {
  return <span className={`badge-soft badge-${variant}-soft`}>{children}</span>
}

export function StatusBadge({ status }) {
  const map = {
    pending: 'warning',
    confirmed: 'success',
    completed: 'info',
    cancelled: 'error',
    recruiting: 'primary',
    active: 'success',
    draft: 'neutral',
    open: 'primary',
    approved: 'success',
    rejected: 'error',
    awaiting_verification: 'warning',
    awaiting_upload: 'neutral',
    accepted: 'success',
    shortlisted: 'info',
  }
  return <Badge variant={map[status] || 'neutral'}>{(status || '').replace(/_/g, ' ')}</Badge>
}

export function Modal({ show, onClose, title, children, footer, size = '' }) {
  if (!show) return null
  return (
    <>
      <div className="modal-backdrop fade show" style={{ zIndex: 1055 }} onClick={onClose}></div>
      <div
        className="modal fade show d-block"
        style={{ zIndex: 1056 }}
        tabIndex="-1"
        onClick={(e) => e.target.classList.contains('modal') && onClose()}
      >
        <div className={`modal-dialog modal-dialog-centered ${size} animate__animated animate__zoomIn`} style={{ animationDuration: '0.25s' }}>
          <div className="modal-content">
            {title && (
              <div className="modal-header border-0 pb-0">
                <h5 className="modal-title fw-bold">{title}</h5>
                <button className="btn-close" onClick={onClose}></button>
              </div>
            )}
            <div className="modal-body">{children}</div>
            {footer && <div className="modal-footer border-0 pt-0">{footer}</div>}
          </div>
        </div>
      </div>
    </>
  )
}
