import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { format } from 'date-fns'
import { Wallet, Search, RefreshCw, ArrowUpCircle, ArrowDownCircle } from 'lucide-react'
import QueryBanner from '../components/QueryBanner'
import {
  PageHeader,
  Panel,
  Btn,
  Field,
  EmptyPanel,
  StatPill,
} from '../components/ui/PageShell'
import { showSuccess, showError } from '../utils/toast'
import { hydrateUsersByIds, isSchemaError } from '../lib/staffQuery'

const WalletExplorer = () => {
  const [query, setQuery] = useState('')
  const [searching, setSearching] = useState(false)
  const [user, setUser] = useState(null)
  const [wallet, setWallet] = useState(null)
  const [txns, setTxns] = useState([])
  const [recentTxns, setRecentTxns] = useState([])
  const [recentLoading, setRecentLoading] = useState(true)
  const [loadError, setLoadError] = useState('')
  const [amount, setAmount] = useState('')
  const [direction, setDirection] = useState('credit')
  const [reason, setReason] = useState('')
  const [adjusting, setAdjusting] = useState(false)

  useEffect(() => {
    loadRecentActivity()
  }, [])

  const loadRecentActivity = async () => {
    try {
      setRecentLoading(true)
      setLoadError('')
      const { data, error } = await supabase
        .from('wallet_transactions')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(25)
      if (error) throw error
      const rows = data || []
      const userIds = rows.map((t) => t.user_id)
      const map = await hydrateUsersByIds(userIds)
      setRecentTxns(rows.map((t) => ({ ...t, user: map[t.user_id] })))
    } catch (err) {
      const msg = err?.message || String(err)
      if (isSchemaError(err, 'wallet_transactions')) {
        setLoadError('Wallet tables missing. Run supabase/19_moderator_platform_wallet.sql in Supabase.')
      } else if (msg.includes('permission') || msg.includes('policy')) {
        setLoadError('Staff cannot read wallet data (RLS). Run supabase/19_moderator_platform_wallet.sql.')
      } else {
        setLoadError(msg)
      }
      setRecentTxns([])
    } finally {
      setRecentLoading(false)
    }
  }

  const searchUser = async (e) => {
    e?.preventDefault()
    const q = query.trim()
    if (q.length < 2) {
      showError('Enter at least 2 characters (email or name)')
      return
    }
    setSearching(true)
    try {
      let res = await supabase
        .from('users')
        .select('id, name, email, role, suspended_at, deleted_at')
        .ilike('email', `%${q}%`)
        .limit(5)

      if (res.error?.message?.includes('deleted_at') || res.error?.message?.includes('suspended_at')) {
        res = await supabase
          .from('users')
          .select('id, name, email, role')
          .ilike('email', `%${q}%`)
          .limit(5)
      }

      if (!res.data?.length) {
        res = await supabase
          .from('users')
          .select('id, name, email, role, suspended_at, deleted_at')
          .ilike('name', `%${q}%`)
          .limit(5)
        if (res.error?.message?.includes('deleted_at') || res.error?.message?.includes('suspended_at')) {
          res = await supabase
            .from('users')
            .select('id, name, email, role')
            .ilike('name', `%${q}%`)
            .limit(5)
        }
      }

      if (res.error) throw res.error
      if (!res.data?.length) {
        showError('No user found')
        setUser(null)
        setWallet(null)
        setTxns([])
        return
      }

      const picked = res.data[0]
      if (res.data.length > 1) {
        showSuccess(`Showing first match: ${picked.name}`)
      }
      setUser(picked)
      await loadWallet(picked.id)
    } catch (err) {
      showError(err.message)
    } finally {
      setSearching(false)
    }
  }

  const loadWallet = async (userId) => {
    const [{ data: w, error: wErr }, { data: t, error: tErr }] = await Promise.all([
      supabase.from('user_wallets').select('*').eq('user_id', userId).maybeSingle(),
      supabase
        .from('wallet_transactions')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(50),
    ])
    if (wErr) throw wErr
    if (tErr) throw tErr
    setWallet(w || { user_id: userId, balance: 0, currency: 'PKR' })
    setTxns(t || [])
  }

  const adjustWallet = async () => {
    if (!user) return
    const amt = parseFloat(amount)
    if (!amt || amt <= 0) {
      showError('Enter a valid amount')
      return
    }
    if (!reason.trim() || reason.trim().length < 5) {
      showError('Reason must be at least 5 characters')
      return
    }
    setAdjusting(true)
    try {
      const { error } = await supabase.rpc('staff_adjust_wallet', {
        p_user_id: user.id,
        p_amount: amt,
        p_direction: direction,
        p_reason: reason.trim(),
      })
      if (error) throw error
      showSuccess(`Wallet ${direction} successful`)
      setAmount('')
      setReason('')
      await loadWallet(user.id)
    } catch (err) {
      showError(err.message)
    } finally {
      setAdjusting(false)
    }
  }

  return (
    <div className="fade-in">
      <PageHeader
        title="Wallet Explorer"
        subtitle="Search a user by email or name, or review recent wallet activity below."
      />

      <QueryBanner error={loadError} hint="Run migration 19 (and 49 for manual adjust), then refresh." />

      <Panel style={{ marginBottom: 20 }}>
        <form onSubmit={searchUser} style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
          <input
            className="input"
            style={{ flex: 1, minWidth: 220 }}
            placeholder="Search by email or name..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          <Btn type="submit" variant="primary" icon={Search} disabled={searching}>
            {searching ? 'Searching...' : 'Search'}
          </Btn>
        </form>
      </Panel>

      {!user ? (
        <>
          <Panel padding={false} style={{ marginBottom: 20 }}>
            <div style={{ padding: '16px 16px 8px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <strong style={{ fontSize: 14 }}>Recent wallet activity</strong>
              <Btn variant="ghost" size="sm" icon={RefreshCw} onClick={loadRecentActivity}>Refresh</Btn>
            </div>
            <div style={{ maxHeight: 360, overflowY: 'auto' }}>
              {recentLoading ? (
                <p style={{ padding: 20, color: 'var(--text-tertiary)' }}>Loading recent transactions...</p>
              ) : recentTxns.length === 0 ? (
                <p style={{ padding: 20, color: 'var(--text-tertiary)', fontSize: 14 }}>
                  {loadError ? 'Fix the error above to see transactions.' : 'No wallet transactions yet. Users need to top up or pay via wallet first.'}
                </p>
              ) : (
                recentTxns.map((t) => (
                  <div
                    key={t.id}
                    style={{
                      padding: '14px 16px',
                      borderBottom: '1px solid var(--border)',
                      display: 'flex',
                      justifyContent: 'space-between',
                      gap: 12,
                      cursor: 'pointer',
                    }}
                    onClick={() => {
                      if (t.user) {
                        setUser(t.user)
                        loadWallet(t.user.id).catch((err) => showError(err.message))
                      }
                    }}
                  >
                    <div>
                      <div style={{ fontWeight: 600, fontSize: 14 }}>
                        {t.user?.name || 'User'} · {t.user?.email || t.user_id}
                      </div>
                      <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginTop: 4 }}>{t.reason}</div>
                      <div style={{ fontSize: 11, color: 'var(--text-tertiary)', marginTop: 4 }}>
                        {format(new Date(t.created_at), 'MMM d, yyyy HH:mm')}
                      </div>
                    </div>
                    <div style={{ fontWeight: 700, color: t.txn_type === 'credit' ? 'var(--success)' : 'var(--danger)' }}>
                      {t.txn_type === 'credit' ? '+' : '−'} PKR {Number(t.amount).toLocaleString()}
                    </div>
                  </div>
                ))
              )}
            </div>
          </Panel>
          <Panel>
            <EmptyPanel
              icon={Wallet}
              title="Find a user"
              message="Search by email or name above, or click a recent transaction to open that wallet."
            />
          </Panel>
        </>
      ) : (
        <>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12, marginBottom: 20 }}>
            <StatPill label="User" value={user.name} tone="primary" />
            <StatPill
              label="Balance"
              value={`PKR ${Number(wallet?.balance || 0).toLocaleString()}`}
              tone="success"
            />
            <StatPill label="Role" value={user.role} />
            {user.suspended_at && <StatPill label="Status" value="Suspended" tone="danger" />}
            {user.deleted_at && <StatPill label="Status" value="Deleted" tone="warning" />}
          </div>

          <div className="reports-layout">
            <Panel>
              <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 14 }}>Manual adjustment</h3>
              <Field label="Direction">
                <select className="select" value={direction} onChange={(e) => setDirection(e.target.value)}>
                  <option value="credit">Credit (add funds)</option>
                  <option value="debit">Debit (deduct funds)</option>
                </select>
              </Field>
              <Field label="Amount (PKR)">
                <input
                  className="input"
                  type="number"
                  min="1"
                  step="0.01"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="500"
                />
              </Field>
              <Field label="Reason" hint="Logged in audit trail and sent to user">
                <textarea
                  className="textarea"
                  rows={3}
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  placeholder="Dispute resolution, correction, goodwill credit..."
                />
              </Field>
              <Btn
                variant={direction === 'credit' ? 'success' : 'danger'}
                icon={direction === 'credit' ? ArrowUpCircle : ArrowDownCircle}
                onClick={adjustWallet}
                disabled={adjusting || user.deleted_at}
              >
                {adjusting ? 'Processing...' : `${direction === 'credit' ? 'Credit' : 'Debit'} wallet`}
              </Btn>
              <p style={{ fontSize: 12, color: 'var(--text-tertiary)', marginTop: 12 }}>
                {user.email}
              </p>
            </Panel>

            <Panel padding={false}>
              <div style={{ padding: '16px 16px 8px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between' }}>
                <strong style={{ fontSize: 14 }}>Transactions</strong>
                <Btn variant="ghost" size="sm" icon={RefreshCw} onClick={() => loadWallet(user.id)}>Refresh</Btn>
              </div>
              <div style={{ maxHeight: 480, overflowY: 'auto' }}>
                {txns.length === 0 ? (
                  <p style={{ padding: 20, color: 'var(--text-tertiary)', fontSize: 14 }}>No transactions yet.</p>
                ) : (
                  txns.map((t) => (
                    <div
                      key={t.id}
                      style={{
                        padding: '14px 16px',
                        borderBottom: '1px solid var(--border)',
                        display: 'flex',
                        justifyContent: 'space-between',
                        gap: 12,
                      }}
                    >
                      <div>
                        <div style={{ fontWeight: 600, fontSize: 14, color: t.txn_type === 'credit' ? 'var(--success)' : 'var(--danger)' }}>
                          {t.txn_type === 'credit' ? '+' : '−'} PKR {Number(t.amount).toLocaleString()}
                        </div>
                        <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginTop: 4 }}>{t.reason}</div>
                        <div style={{ fontSize: 11, color: 'var(--text-tertiary)', marginTop: 4 }}>
                          {format(new Date(t.created_at), 'MMM d, yyyy HH:mm')}
                        </div>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </Panel>
          </div>
        </>
      )}
    </div>
  )
}

export default WalletExplorer
