import { Link } from 'react-router-dom'
import { APP_TAGLINE } from '../lib/constants'

const features = [
  { icon: 'bi-building', title: 'Book Workspaces', text: 'Find and book private offices, shared desks and meeting rooms by the hour, day or month.' },
  { icon: 'bi-people', title: 'Build Teams', text: 'Post a project, recruit teammates by role and launch a collaborative workspace — Fiverr style.' },
  { icon: 'bi-chat-dots', title: 'Real-time Chat', text: 'Message workspace owners and your project team instantly with live updates.' },
  { icon: 'bi-shield-check', title: 'Secure Payments', text: 'Pay via bank, EasyPaisa or JazzCash with receipt verification and digital tickets.' },
]

export default function Landing() {
  return (
    <div>
      {/* Hero */}
      <section className="hero">
        <div className="container-app py-5 position-relative" style={{ zIndex: 2 }}>
          <nav className="d-flex justify-content-between align-items-center mb-5">
            <div className="d-flex align-items-center gap-2">
              <span className="brand-logo" style={{ background: 'rgba(255,255,255,0.2)' }}>C</span>
              <span className="fw-bold fs-4 text-white">CWL</span>
            </div>
            <div className="d-flex gap-2">
              <Link to="/login" className="btn btn-light btn-sm px-3">Sign In</Link>
              <Link to="/get-started" className="btn btn-sm px-3" style={{ background: '#fff', color: 'var(--primary)' }}>Get Started</Link>
            </div>
          </nav>

          <div className="row align-items-center py-5">
            <div className="col-lg-7 text-white animate__animated animate__fadeInUp">
              <span className="badge-soft mb-3 d-inline-block" style={{ background: 'rgba(255,255,255,0.2)', color: '#fff' }}>
                <i className="bi bi-stars me-1"></i> Coworking + Collaboration platform
              </span>
              <h1 className="display-3 fw-bold mb-3" style={{ color: '#fff', letterSpacing: '-1.5px' }}>
                {APP_TAGLINE}
              </h1>
              <p className="fs-5 mb-4" style={{ color: 'rgba(255,255,255,0.9)', maxWidth: 540 }}>
                CWL connects you with the perfect workspace and the right teammates. Discover spaces,
                form teams, and bring your projects to life — all in one place.
              </p>
              <div className="d-flex flex-wrap gap-3">
                <Link to="/get-started" className="btn btn-lg px-4" style={{ background: '#fff', color: 'var(--primary)' }}>
                  Get Started <i className="bi bi-arrow-right ms-1"></i>
                </Link>
                <Link to="/login" className="btn btn-lg btn-outline-light px-4">I have an account</Link>
              </div>
            </div>
            <div className="col-lg-5 d-none d-lg-block">
              <div className="position-relative animate__animated animate__fadeIn" style={{ animationDelay: '0.3s' }}>
                <div className="card border-0 shadow-lg p-4 mb-3" style={{ borderRadius: 24, transform: 'rotate(-3deg)' }}>
                  <div className="d-flex align-items-center gap-3">
                    <div className="stat-icon" style={{ background: 'var(--primary-gradient)' }}><i className="bi bi-building text-white"></i></div>
                    <div>
                      <div className="fw-bold">Premium Office</div>
                      <div className="text-secondary small">Islamabad · Rs. 3,000/day</div>
                    </div>
                  </div>
                </div>
                <div className="card border-0 shadow-lg p-4" style={{ borderRadius: 24, transform: 'rotate(2deg)', marginLeft: 40 }}>
                  <div className="d-flex align-items-center gap-3">
                    <div className="stat-icon" style={{ background: 'var(--success-gradient)' }}><i className="bi bi-people text-white"></i></div>
                    <div>
                      <div className="fw-bold">Looking for a Designer</div>
                      <div className="text-secondary small">Web App · 4 roles open</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="container-app py-5">
        <div className="text-center mb-5">
          <h2 className="fw-bold">Everything you need to work better</h2>
          <p className="text-secondary">From booking a desk to launching a team project.</p>
        </div>
        <div className="row g-4">
          {features.map((f, i) => (
            <div className="col-md-6 col-lg-3" key={f.title}>
              <div className="card-clean card-hover h-100 p-4 text-center" data-aos="fade-up" data-aos-delay={i * 80}>
                <div className="stat-icon mx-auto mb-3" style={{ background: 'var(--primary-gradient)', width: 56, height: 56 }}>
                  <i className={`bi ${f.icon} text-white fs-4`}></i>
                </div>
                <h6 className="fw-bold">{f.title}</h6>
                <p className="text-secondary small mb-0">{f.text}</p>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* CTA */}
      <section className="container-app pb-5">
        <div className="card border-0 p-5 text-center text-white" style={{ background: 'var(--hero-gradient)', borderRadius: 28 }}>
          <h2 className="fw-bold text-white mb-2">Ready to get started?</h2>
          <p className="mb-4" style={{ color: 'rgba(255,255,255,0.9)' }}>Join CWL today and find your space and your team.</p>
          <div>
            <Link to="/get-started" className="btn btn-lg px-5" style={{ background: '#fff', color: 'var(--primary)' }}>Create Free Account</Link>
          </div>
        </div>
      </section>

      <footer className="text-center text-secondary py-4 small">
        © {new Date().getFullYear()} CWL — Coworking Spaces. Built for the CWC platform.
      </footer>
    </div>
  )
}
