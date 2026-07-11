import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import {
  Smartphone,
  Building2,
  Users,
  Briefcase,
  Shield,
  Download,
  ArrowDown,
} from 'lucide-react'
import { supabase } from '../lib/supabase'
import Loading from '../components/Loading'

const APK_KEYS = ['android_apk_url', 'android_apk_version', 'android_apk_notes']

const Landing = ({ user }) => {
  const [loading, setLoading] = useState(true)
  const [apkUrl, setApkUrl] = useState('')
  const [apkVersion, setApkVersion] = useState('')
  const [apkNotes, setApkNotes] = useState('')

  useEffect(() => {
    const load = async () => {
      try {
        const { data, error } = await supabase
          .from('platform_settings')
          .select('key, value, updated_at')
          .in('key', APK_KEYS)

        if (error) throw error

        const map = Object.fromEntries((data || []).map((r) => [r.key, r.value]))
        setApkUrl((map.android_apk_url || '').trim())
        setApkVersion((map.android_apk_version || '').trim())
        setApkNotes((map.android_apk_notes || '').trim())
      } catch (e) {
        console.error('Failed to load APK settings:', e)
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  const adminTarget = user ? '/dashboard' : '/login'

  if (loading) {
    return <Loading message="Loading..." />
  }

  const hasApk = Boolean(apkUrl)

  return (
    <div className="landing-page">
      <header className="landing-header">
        <div className="landing-header__brand">
          <div className="landing-header__logo">CWC</div>
          <span>Co-Work Connect</span>
        </div>
        <Link to={adminTarget} className="landing-header__admin">
          <Shield size={16} />
          Administrator
        </Link>
      </header>

      <main className="landing-main">
        <section className="landing-hero">
          <p className="landing-hero__eyebrow">Final Year Project · Workspace Marketplace</p>
          <h1>Find workspaces. Collaborate. Grow together.</h1>
          <p className="landing-hero__lead">
            <strong>Co-Work Connect (CWC)</strong> connects freelancers, teams, and workspace
            owners across Pakistan. Book desks and meeting rooms, manage owner listings, chat in
            real time, run collaboration projects with milestone payments, and handle wallet-based
            bookings — all in one mobile app.
          </p>

          <div className="landing-features">
            <div className="landing-feature">
              <Building2 size={22} />
              <div>
                <strong>Workspace booking</strong>
                <span>Discover and reserve coworking spaces</span>
              </div>
            </div>
            <div className="landing-feature">
              <Briefcase size={22} />
              <div>
                <strong>Collaboration hub</strong>
                <span>Projects, milestones, and team payments</span>
              </div>
            </div>
            <div className="landing-feature">
              <Users size={22} />
              <div>
                <strong>For owners &amp; users</strong>
                <span>List spaces, earn revenue, manage bookings</span>
              </div>
            </div>
          </div>
        </section>

        <section className="landing-download">
          <div className="landing-download__icon">
            <Smartphone size={40} />
          </div>
          <h2>Download APK for Android</h2>
          <p className="landing-download__hint">
            Get the latest Android build directly from here.
          </p>

          {hasApk ? (
            <>
              {apkVersion && (
                <span className="landing-download__version">Version {apkVersion}</span>
              )}
              {apkNotes && (
                <p className="landing-download__notes">{apkNotes}</p>
              )}
              <a
                href={apkUrl}
                className="landing-download__btn"
                download
                target="_blank"
                rel="noopener noreferrer"
              >
                <Download size={20} />
                Download Android APK
              </a>
              <p className="landing-download__fine">
                Tap to download. You may need to allow installs from unknown sources on your device.
              </p>
            </>
          ) : (
            <div className="landing-download__soon">
              <ArrowDown size={28} style={{ opacity: 0.4, marginBottom: 12 }} />
              <strong>APK will release soon</strong>
              <p>Check back later for the Android app download.</p>
            </div>
          )}
        </section>
      </main>

      <footer className="landing-footer">
        <p>© {new Date().getFullYear()} Co-Work Connect (CWC). All rights reserved.</p>
      </footer>
    </div>
  )
}

export default Landing
