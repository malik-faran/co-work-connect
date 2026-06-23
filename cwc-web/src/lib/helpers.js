import { formatDistanceToNow, format, parseISO } from 'date-fns'

export const timeAgo = (date) => {
  if (!date) return ''
  try {
    return formatDistanceToNow(typeof date === 'string' ? parseISO(date) : date, {
      addSuffix: true,
    })
  } catch {
    return ''
  }
}

export const fmtDate = (date, pattern = 'dd MMM yyyy') => {
  if (!date) return ''
  try {
    return format(typeof date === 'string' ? parseISO(date) : date, pattern)
  } catch {
    return ''
  }
}

export const fmtDateTime = (date) => fmtDate(date, 'dd MMM yyyy, hh:mm a')

export const initials = (name = '') =>
  name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase() || '')
    .join('') || '?'

export const dateKey = (d) => {
  const x = d instanceof Date ? d : new Date(d)
  const y = x.getFullYear()
  const m = String(x.getMonth() + 1).padStart(2, '0')
  const day = String(x.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
export const isUuid = (v) => typeof v === 'string' && UUID_RE.test(v)

// Build category list from a workspace row (mirrors detail screen fallback).
export const getCategories = (ws) => {
  let opts = ws?.category_options
  if (typeof opts === 'string') {
    try {
      opts = JSON.parse(opts)
    } catch {
      opts = []
    }
  }
  if (Array.isArray(opts) && opts.length) {
    return opts.map((c) => ({
      type: c.type,
      capacity: Number(c.capacity ?? 10),
      pricePerHour: Number(c.pricePerHour ?? c.price_per_hour ?? 0),
      pricePerDay: Number(c.pricePerDay ?? c.price_per_day ?? 0),
    }))
  }
  return [
    {
      type: ws?.workspace_type || 'shared',
      capacity: Number(ws?.capacity || 10),
      pricePerHour: Number(ws?.price_per_hour || ws?.price_per_day / 8 || 0),
      pricePerDay: Number(ws?.price_per_day || 0),
    },
  ]
}

// Build hourly time slots from a workspace row (mirrors detail screen).
export const getTimeSlots = (ws) => {
  let slots = ws?.time_slots
  if (typeof slots === 'string') {
    try {
      slots = JSON.parse(slots)
    } catch {
      slots = []
    }
  }
  if (Array.isArray(slots) && slots.length) return slots
  const open = parseInt((ws?.opening_time || '09:00').split(':')[0], 10)
  const close = parseInt((ws?.closing_time || '18:00').split(':')[0], 10)
  const out = []
  for (let h = open; h < close; h++) {
    out.push({
      id: `slot_${h}_${h + 1}`,
      label: `${String(h).padStart(2, '0')}:00 - ${String(h + 1).padStart(2, '0')}:00`,
      startHour: h,
      endHour: h + 1,
    })
  }
  return out
}

export const uuid = () =>
  crypto?.randomUUID
    ? crypto.randomUUID()
    : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
        const r = (Math.random() * 16) | 0
        const v = c === 'x' ? r : (r & 0x3) | 0x8
        return v.toString(16)
      })
