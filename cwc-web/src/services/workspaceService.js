import { supabase } from '../lib/supabase'

export const workspaceService = {
  async getAll() {
    const { data, error } = await supabase
      .from('workspaces')
      .select('*')
      .eq('is_available', true)
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  },

  async getById(id) {
    const { data, error } = await supabase
      .from('workspaces')
      .select('*')
      .eq('id', id)
      .maybeSingle()
    if (error) throw error
    return data
  },

  async getByOwner(ownerId) {
    const { data, error } = await supabase
      .from('workspaces')
      .select('*')
      .eq('owner_id', ownerId)
      .order('created_at', { ascending: false })
    if (error) throw error
    return data || []
  },

  async create(payload) {
    const { data, error } = await supabase
      .from('workspaces')
      .insert(payload)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async update(id, payload) {
    const { data, error } = await supabase
      .from('workspaces')
      .update({ ...payload, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single()
    if (error) throw error
    return data
  },

  async setAvailability(id, isAvailable) {
    const { error } = await supabase
      .from('workspaces')
      .update({ is_available: isAvailable, updated_at: new Date().toISOString() })
      .eq('id', id)
    if (error) throw error
  },

  async remove(id) {
    const { error } = await supabase.from('workspaces').delete().eq('id', id)
    if (error) throw error
  },
}
