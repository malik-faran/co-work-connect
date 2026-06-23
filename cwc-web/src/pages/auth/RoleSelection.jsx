import { useNavigate } from 'react-router-dom'
import AuthShell from './AuthShell'

export default function RoleSelection() {
  const navigate = useNavigate()

  const roles = [
    {
      role: 'user',
      icon: 'bi-person-workspace',
      title: 'Join as a Member',
      text: 'Book workspaces, find teammates and collaborate on projects.',
      gradient: 'var(--primary-gradient)',
    },
    {
      role: 'owner',
      icon: 'bi-building-gear',
      title: 'Join as a Space Owner',
      text: 'List your coworking spaces, manage bookings and receive payments.',
      gradient: 'var(--warm-gradient)',
    },
  ]

  return (
    <AuthShell
      title="How do you want to use CWL?"
      subtitle="Choose your account type to get started."
      footer={
        <span className="text-secondary">
          Already have an account?{' '}
          <a href="/login" onClick={(e) => { e.preventDefault(); navigate('/login') }}>Sign in</a>
        </span>
      }
    >
      <div className="d-flex flex-column gap-3">
        {roles.map((r) => (
          <button
            key={r.role}
            className="card-clean card-hover p-4 text-start border-0 w-100"
            onClick={() => navigate(`/signup?role=${r.role}`)}
          >
            <div className="d-flex align-items-center gap-3">
              <div className="stat-icon" style={{ background: r.gradient, width: 54, height: 54 }}>
                <i className={`bi ${r.icon} text-white fs-4`}></i>
              </div>
              <div className="flex-fill">
                <h6 className="fw-bold mb-1">{r.title}</h6>
                <p className="text-secondary small mb-0">{r.text}</p>
              </div>
              <i className="bi bi-chevron-right text-secondary"></i>
            </div>
          </button>
        ))}
      </div>
    </AuthShell>
  )
}
