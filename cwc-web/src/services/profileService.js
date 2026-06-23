import { supabase } from '../lib/supabase'
import { uuid } from '../lib/helpers'

export const profileService = {
  async getById(userId) {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('id', userId)
      .maybeSingle()
    if (error) throw error
    return data
  },

  async update(userId, fields) {
    const { data, error } = await supabase
      .from('users')
      .update({ ...fields, updated_at: new Date().toISOString() })
      .eq('id', userId)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async getOpenTeammates(excludeId) {
    let q = supabase
      .from('users')
      .select('*')
      .eq('collaboration_enabled', true)
      .eq('role', 'user')
      .order('updated_at', { ascending: false })
      .limit(100)
    const { data, error } = await q
    if (error) throw error
    return (data || []).filter((u) => u.id !== excludeId)
  },

  // Portfolio
  async getPortfolio(userId) {
    const { data, error } = await supabase
      .from('user_portfolio_items')
      .select('*')
      .eq('user_id', userId)
      .order('sort_order', { ascending: true })
    if (error) throw error
    return data || []
  },

  async savePortfolioItem(item) {
    const row = {
      id: item.id || uuid(),
      user_id: item.user_id,
      title: item.title,
      description: item.description || null,
      image_url: item.image_url || null,
      project_url: item.project_url || null,
      skills: item.skills || [],
      sort_order: item.sort_order ?? 0,
      created_at: item.created_at || new Date().toISOString(),
    }
    const { data, error } = await supabase
      .from('user_portfolio_items')
      .upsert(row)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async deletePortfolioItem(id) {
    const { error } = await supabase
      .from('user_portfolio_items')
      .delete()
      .eq('id', id)
    if (error) throw error
  },

  async updateResume(userId, resumeUrl, resumeFileName) {
    const { data, error } = await supabase
      .from('users')
      .update({
        resume_url: resumeUrl,
        resume_file_name: resumeFileName,
        updated_at: new Date().toISOString(),
      })
      .eq('id', userId)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async clearResume(userId) {
    const { data, error } = await supabase
      .from('users')
      .update({
        resume_url: null,
        resume_file_name: null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', userId)
      .select()
      .single()
    if (error) throw error
    return data
  },
}
