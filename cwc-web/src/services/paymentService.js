import { supabase } from '../lib/supabase'
import { uuid } from '../lib/helpers'
import { notificationService } from './notificationService'

export const paymentService = {
  async getByBooking(bookingId) {
    const { data, error } = await supabase
      .from('payments')
      .select('*')
      .eq('booking_id', bookingId)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()
    if (error) throw error
    return data
  },

  async getUserPayments(userId) {
    const { data, error } = await supabase
      .from('payments')
      .select('*, bookings(*)')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  },

  async getOwnerReceived(ownerId) {
    const { data: ws } = await supabase
      .from('workspaces')
      .select('id')
      .eq('owner_id', ownerId)
    const wsIds = (ws || []).map((w) => w.id)
    if (!wsIds.length) return []
    const { data: bk } = await supabase
      .from('bookings')
      .select('id')
      .in('workspace_id', wsIds)
    const bkIds = (bk || []).map((b) => b.id)
    if (!bkIds.length) return []
    const { data, error } = await supabase
      .from('payments')
      .select('*, bookings(*)')
      .in('booking_id', bkIds)
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  },

  async getPendingReceiptsForOwner(ownerId) {
    const { data: ws } = await supabase
      .from('workspaces')
      .select('id')
      .eq('owner_id', ownerId)
    const wsIds = (ws || []).map((w) => w.id)
    if (!wsIds.length) return []
    const { data: bk } = await supabase
      .from('bookings')
      .select('id')
      .in('workspace_id', wsIds)
    const bkIds = (bk || []).map((b) => b.id)
    if (!bkIds.length) return []
    const { data, error } = await supabase
      .from('payments')
      .select('*, bookings(*)')
      .in('booking_id', bkIds)
      .eq('receipt_status', 'awaiting_verification')
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  },

  // Create/switch to a manual payment row for a booking.
  async createManualPayment({ bookingId, userId, amount }) {
    const existing = await this.getByBooking(bookingId)
    const expires = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
    if (existing && existing.status !== 'completed') {
      const keepReceipt =
        existing.receipt_status === 'awaiting_verification' ||
        existing.receipt_status === 'approved'
      const { data, error } = await supabase
        .from('payments')
        .update({
          payment_method: 'manual',
          status: 'pending',
          receipt_status: keepReceipt ? existing.receipt_status : 'awaiting_upload',
          stripe_payment_intent_id: null,
          stripe_client_secret: null,
          expires_at: expires,
          updated_at: new Date().toISOString(),
        })
        .eq('id', existing.id)
        .select()
        .single()
      if (error) throw error
      return data
    }
    const { data, error } = await supabase
      .from('payments')
      .insert({
        id: uuid(),
        booking_id: bookingId,
        user_id: userId,
        amount,
        currency: 'PKR',
        status: 'pending',
        payment_method: 'manual',
        receipt_status: 'awaiting_upload',
        expires_at: expires,
        created_at: new Date().toISOString(),
      })
      .select()
      .single()
    if (error) throw error
    return data
  },

  async submitReceipt({ paymentId, ownerAccountId, receiptUrl, transferReference, ownerId, bookingId }) {
    const { data, error } = await supabase
      .from('payments')
      .update({
        payment_method: 'manual',
        status: 'pending',
        owner_account_id: ownerAccountId,
        receipt_url: receiptUrl,
        receipt_status: 'awaiting_verification',
        transfer_reference: transferReference || null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', paymentId)
      .select()
      .single()
    if (error) throw error
    if (ownerId) {
      await notificationService.create({
        userId: ownerId,
        title: 'Payment Receipt Submitted',
        message: 'A user submitted a payment receipt for verification.',
        type: 'payment_receipt',
        metadata: { booking_id: bookingId, payment_id: paymentId },
      })
    }
    return data
  },

  async approve(payment) {
    const { error } = await supabase
      .from('payments')
      .update({
        status: 'completed',
        receipt_status: 'approved',
        owner_verified_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', payment.id)
    if (error) throw error
    await supabase
      .from('bookings')
      .update({ status: 'confirmed', updated_at: new Date().toISOString() })
      .eq('id', payment.booking_id)
    await notificationService.create({
      userId: payment.user_id,
      title: 'Payment Approved',
      message: 'Your payment was verified and your booking is confirmed.',
      type: 'booking_confirmed',
      metadata: { booking_id: payment.booking_id },
    })
  },

  async reject(payment, reason) {
    const { error } = await supabase
      .from('payments')
      .update({
        receipt_status: 'rejected',
        failure_reason: reason || 'Receipt rejected by owner',
        updated_at: new Date().toISOString(),
      })
      .eq('id', payment.id)
    if (error) throw error
    await notificationService.create({
      userId: payment.user_id,
      title: 'Payment Rejected',
      message: reason || 'Your payment receipt was rejected. Please re-upload.',
      type: 'payment_rejected',
      metadata: { booking_id: payment.booking_id },
    })
  },

  // Owner payment accounts
  async getOwnerAccounts(ownerId) {
    const { data, error } = await supabase
      .from('owner_payment_accounts')
      .select('*')
      .eq('owner_id', ownerId)
      .eq('is_active', true)
      .order('is_default', { ascending: false })
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  },

  async getAccountsForWorkspace(ownerId, workspaceId) {
    const { data, error } = await supabase
      .from('owner_payment_accounts')
      .select('*')
      .eq('owner_id', ownerId)
      .eq('is_active', true)
      .or(`workspace_id.is.null,workspace_id.eq.${workspaceId}`)
      .order('is_default', { ascending: false })
    if (error) throw error
    return data || []
  },

  async createAccount({ ownerId, accountType, accountTitle, accountNumber, bankName, isDefault }) {
    if (isDefault) {
      await supabase
        .from('owner_payment_accounts')
        .update({ is_default: false })
        .eq('owner_id', ownerId)
    }
    const { data, error } = await supabase
      .from('owner_payment_accounts')
      .insert({
        id: uuid(),
        owner_id: ownerId,
        account_type: accountType,
        account_title: accountTitle,
        account_number: accountNumber,
        bank_name: accountType === 'bank' ? bankName : null,
        is_default: !!isDefault,
        is_active: true,
        created_at: new Date().toISOString(),
      })
      .select()
      .single()
    if (error) throw error
    return data
  },

  async setDefaultAccount(ownerId, accountId) {
    await supabase
      .from('owner_payment_accounts')
      .update({ is_default: false })
      .eq('owner_id', ownerId)
    const { error } = await supabase
      .from('owner_payment_accounts')
      .update({ is_default: true, updated_at: new Date().toISOString() })
      .eq('id', accountId)
    if (error) throw error
  },

  async deleteAccount(accountId) {
    const { error } = await supabase
      .from('owner_payment_accounts')
      .delete()
      .eq('id', accountId)
    if (error) throw error
  },
}
