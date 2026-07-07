import { X } from 'lucide-react'

export function PageHeader({ title, subtitle, actions, badge }) {
  return (
    <div className="page-header">
      <div>
        <div className="page-header__title-row">
          <h1 className="page-header__title">{title}</h1>
          {badge != null && <span className="badge badge--primary">{badge}</span>}
        </div>
        {subtitle && <p className="page-header__subtitle">{subtitle}</p>}
      </div>
      {actions && <div className="page-header__actions">{actions}</div>}
    </div>
  )
}

export function Panel({ children, className = '', padding = true, style }) {
  return (
    <div
      className={`panel ${padding ? 'panel--padded' : ''} ${className}`.trim()}
      style={style}
    >
      {children}
    </div>
  )
}

export function StatPill({ label, value, tone = 'default' }) {
  return (
    <div className={`stat-pill stat-pill--${tone}`}>
      <span className="stat-pill__label">{label}</span>
      <span className="stat-pill__value">{value}</span>
    </div>
  )
}

export function FilterTabs({ options, value, onChange }) {
  return (
    <div className="filter-tabs">
      {options.map((opt) => (
        <button
          key={opt.value}
          type="button"
          className={`filter-tabs__item ${value === opt.value ? 'is-active' : ''}`}
          onClick={() => onChange(opt.value)}
        >
          {opt.label}
          {opt.count != null && <span className="filter-tabs__count">{opt.count}</span>}
        </button>
      ))}
    </div>
  )
}

export function StatusBadge({ status, map = {} }) {
  const style = map[status] || {}
  return (
    <span
      className="status-badge"
      style={{
        background: style.bg || 'var(--surface-3)',
        color: style.color || 'var(--text-secondary)',
      }}
    >
      {(status || '').replace(/_/g, ' ')}
    </span>
  )
}

export function Btn({
  children,
  onClick,
  variant = 'primary',
  size = 'md',
  disabled,
  icon: Icon,
  type = 'button',
  className = '',
  style,
}) {
  return (
    <button
      type={type}
      disabled={disabled}
      onClick={onClick}
      style={style}
      className={`btn btn--${variant} btn--${size} ${className}`.trim()}
    >
      {Icon && <Icon size={size === 'sm' ? 14 : 16} />}
      {children}
    </button>
  )
}

export function Modal({ open, onClose, title, children, wide }) {
  if (!open) return null
  return (
    <div className="modal-backdrop" onClick={onClose} role="presentation">
      <div
        className={`modal ${wide ? 'modal--wide' : ''}`}
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
      >
        <div className="modal__header">
          <h2 className="modal__title">{title}</h2>
          <button type="button" className="icon-btn" onClick={onClose} aria-label="Close">
            <X size={18} />
          </button>
        </div>
        <div className="modal__body">{children}</div>
      </div>
    </div>
  )
}

export function Field({ label, children, hint }) {
  return (
    <label className="field">
      {label && <span className="field__label">{label}</span>}
      {children}
      {hint && <span className="field__hint">{hint}</span>}
    </label>
  )
}

export function EmptyPanel({ icon: Icon, title, message, action }) {
  return (
    <div className="empty-panel">
      {Icon && (
        <div className="empty-panel__icon">
          <Icon size={32} />
        </div>
      )}
      <h3>{title}</h3>
      <p>{message}</p>
      {action}
    </div>
  )
}
