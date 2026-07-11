import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { isAdmin } from '../lib/permissions'
import { Smartphone, Upload, Link as LinkIcon, RefreshCw, ExternalLink } from 'lucide-react'
import Loading from '../components/Loading'
import {
  PageHeader,
  Panel,
  Btn,
  Field,
} from '../components/ui/PageShell'
import { showSuccess, showError } from '../utils/toast'

const APK_KEYS = ['android_apk_url', 'android_apk_version', 'android_apk_notes']

const AppRelease = ({ user }) => {
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [url, setUrl] = useState('')
  const [version, setVersion] = useState('')
  const [notes, setNotes] = useState('')
  const [updatedAt, setUpdatedAt] = useState(null)

  const admin = isAdmin(user?.role)

  useEffect(() => {
    if (admin) fetchSettings()
    else setLoading(false)
  }, [admin])

  const fetchSettings = async () => {
    try {
      setLoading(true)
      const { data, error } = await supabase
        .from('platform_settings')
        .select('key, value, updated_at')
        .in('key', APK_KEYS)

      if (error) throw error

      const rows = data || []
      const map = Object.fromEntries(rows.map((r) => [r.key, r]))
      setUrl(map.android_apk_url?.value || '')
      setVersion(map.android_apk_version?.value || '')
      setNotes(map.android_apk_notes?.value || '')
      const latest = rows.reduce((max, r) => {
        const t = r.updated_at ? new Date(r.updated_at).getTime() : 0
        return t > max ? t : max
      }, 0)
      setUpdatedAt(latest ? new Date(latest) : null)
    } catch (e) {
      showError(e.message)
    } finally {
      setLoading(false)
    }
  }

  const saveRelease = async (nextUrl = url) => {
    setSaving(true)
    try {
      const { error } = await supabase.rpc('admin_set_android_apk_release', {
        p_url: nextUrl.trim(),
        p_version: version.trim() || null,
        p_notes: notes.trim() || null,
      })
      if (error) throw error
      showSuccess('Android release updated — visible on the public home page')
      await fetchSettings()
    } catch (e) {
      showError(e.message)
    } finally {
      setSaving(false)
    }
  }

  const handleFileUpload = async (e) => {
    const file = e.target.files?.[0]
    if (!file) return

    if (!file.name.toLowerCase().endsWith('.apk')) {
      showError('Please select an .apk file')
      return
    }

    if (file.size > 100 * 1024 * 1024) {
      showError('APK must be under 100 MB')
      return
    }

    setUploading(true)
    try {
      const path = `android/cwc-${version.trim() || 'release'}-${Date.now()}.apk`

      const { error: uploadError } = await supabase.storage
        .from('app-releases')
        .upload(path, file, {
          cacheControl: '3600',
          upsert: true,
          contentType: 'application/vnd.android.package-archive',
        })

      if (uploadError) throw uploadError

      const { data: urlData } = supabase.storage.from('app-releases').getPublicUrl(path)
      const publicUrl = urlData?.publicUrl
      if (!publicUrl) throw new Error('Could not get public URL for uploaded APK')

      setUrl(publicUrl)
      await saveRelease(publicUrl)
    } catch (err) {
      showError(err.message || 'Upload failed. Run supabase/54_app_release_apk.sql first.')
    } finally {
      setUploading(false)
      e.target.value = ''
    }
  }

  if (!admin) {
    return (
      <Panel>
        <p style={{ color: 'var(--text-secondary)' }}>Only administrators can manage app releases.</p>
      </Panel>
    )
  }

  if (loading) return <Loading message="Loading app release settings..." />

  return (
    <div className="fade-in">
      <PageHeader
        title="Android App Release"
        subtitle="Upload a new APK or paste a download link. The public home page uses this for the Download button."
        actions={
          <Btn variant="secondary" icon={RefreshCw} onClick={fetchSettings}>
            Refresh
          </Btn>
        }
      />

      <div style={{ display: 'grid', gap: 20, maxWidth: 720 }}>
        <Panel>
          <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
            <Upload size={18} /> Upload APK file
          </h3>
          <p style={{ fontSize: 14, color: 'var(--text-secondary)', marginBottom: 16 }}>
            Uploads to Supabase Storage (<code>app-releases</code> bucket) and sets the public download link automatically.
          </p>
          <label className="btn btn--primary btn--md" style={{ cursor: 'pointer', display: 'inline-flex' }}>
            <Smartphone size={16} />
            {uploading ? 'Uploading...' : 'Choose APK file'}
            <input
              type="file"
              accept=".apk,application/vnd.android.package-archive"
              onChange={handleFileUpload}
              disabled={uploading || saving}
              style={{ display: 'none' }}
            />
          </label>
        </Panel>

        <Panel>
          <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
            <LinkIcon size={18} /> Or paste download link
          </h3>
          <Field label="APK URL" hint="Direct link to .apk (Google Drive direct link, CDN, etc.)">
            <input
              className="input"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="https://.../app-release.apk"
            />
          </Field>
          <Field label="Version label" hint="Shown on the home page, e.g. 1.0.0">
            <input
              className="input"
              value={version}
              onChange={(e) => setVersion(e.target.value)}
              placeholder="1.0.0"
            />
          </Field>
          <Field label="Release notes (optional)" hint="Short note for users on the download section">
            <textarea
              className="textarea"
              rows={3}
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Bug fixes and performance improvements..."
            />
          </Field>
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginTop: 8 }}>
            <Btn variant="primary" onClick={() => saveRelease()} disabled={saving || uploading}>
              {saving ? 'Saving...' : 'Save release'}
            </Btn>
            {url && (
              <Btn
                variant="ghost"
                icon={ExternalLink}
                onClick={() => window.open(url, '_blank', 'noopener,noreferrer')}
              >
                Test download link
              </Btn>
            )}
            <Btn
              variant="danger"
              onClick={() => {
                if (confirm('Remove APK link? Home page will show "APK will release soon".')) {
                  setUrl('')
                  saveRelease('')
                }
              }}
              disabled={saving}
            >
              Clear link
            </Btn>
          </div>
          {updatedAt && (
            <p style={{ fontSize: 12, color: 'var(--text-tertiary)', marginTop: 16 }}>
              Last updated: {updatedAt.toLocaleString()}
            </p>
          )}
        </Panel>

        <Panel style={{ background: 'var(--surface-2)' }}>
          <p style={{ fontSize: 14, color: 'var(--text-secondary)', margin: 0 }}>
            Public page: <a href="/" target="_blank" rel="noreferrer" style={{ color: 'var(--primary)' }}>Open home page ↗</a>
            {' '}— visitors see project info and the download button when a link is set.
          </p>
        </Panel>
      </div>
    </div>
  )
}

export default AppRelease
