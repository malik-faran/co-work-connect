import { supabase, BUCKETS } from '../lib/supabase'

const ext = (file) => (file.name?.split('.').pop() || 'jpg').toLowerCase()

async function uploadTo(bucket, path, file, contentType) {
  const { error } = await supabase.storage.from(bucket).upload(path, file, {
    cacheControl: '3600',
    upsert: true,
    contentType: contentType || file.type || 'image/jpeg',
  })
  if (error) throw error
  const { data } = supabase.storage.from(bucket).getPublicUrl(path)
  return data.publicUrl
}

export const storageService = {
  async uploadProfileImage(userId, file) {
    const path = `profiles/${userId}/${Date.now()}.${ext(file)}`
    return uploadTo(BUCKETS.profiles, path, file)
  },

  async uploadWorkspaceImage(workspaceId, file) {
    const safe = (file.name || 'image').replace(/[^a-zA-Z0-9._-]/g, '_')
    const path = `workspaces/${workspaceId}/${Date.now()}_${safe}`
    return uploadTo(BUCKETS.workspaces, path, file)
  },

  async uploadChatImage(chatRoomId, userId, file) {
    const path = `${chatRoomId}/${userId}/${Date.now()}.${ext(file)}`
    return uploadTo(BUCKETS.chatImages, path, file)
  },

  async uploadProjectCover(collaborationId, file) {
    const path = `${collaborationId}/${Date.now()}.${ext(file)}`
    return uploadTo(BUCKETS.projectCovers, path, file)
  },

  async uploadCollaborationFile(collaborationId, userId, file) {
    const safe = (file.name || 'file').replace(/[^a-zA-Z0-9._-]/g, '_')
    const path = `${collaborationId}/${userId}/${Date.now()}_${safe}`
    return uploadTo(BUCKETS.collaborationFiles, path, file)
  },

  async uploadPortfolioImage(userId, file) {
    const path = `portfolio_${userId}/${userId}/${Date.now()}.${ext(file)}`
    return uploadTo(BUCKETS.collaborationFiles, path, file)
  },

  async uploadResume(userId, file) {
    const name = (file.name || 'resume').toLowerCase()
    if (!name.endsWith('.pdf') && !name.endsWith('.doc') && !name.endsWith('.docx')) {
      throw new Error('Resume must be PDF, DOC, or DOCX')
    }
    if (file.size > 10 * 1024 * 1024) {
      throw new Error('Resume must be smaller than 10 MB')
    }
    const safe = (file.name || 'resume').replace(/[^a-zA-Z0-9._-]/g, '_')
    const path = `resume_${userId}/${userId}/${Date.now()}_${safe}`
    return uploadTo(BUCKETS.collaborationFiles, path, file, file.type || 'application/octet-stream')
  },

  async uploadReceipt(userId, bookingId, file) {
    const path = `${userId}/${bookingId}/${Date.now()}.${ext(file)}`
    return uploadTo(BUCKETS.paymentReceipts, path, file)
  },
}
