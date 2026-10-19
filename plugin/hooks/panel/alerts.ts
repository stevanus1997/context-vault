import type { Alert } from '../../types'

// Dedup toast: poll pertama (seen null) cuma jadi baseline; tiap key di-toast sekali;
// banyak alert baru sekaligus digabung jadi satu toast.
export function nextAlerts(seen: string[] | null, alerts: Alert[]): { toast: string | null; seen: string[] } {
  if (seen === null) return { toast: null, seen: alerts.map(a => a.key) }
  const fresh = alerts.filter(a => !seen.includes(a.key))
  const first = fresh[0]
  const toast = !first ? null : fresh.length === 1 ? first.text : `${first.text} (+${fresh.length - 1} lagi)`
  return { toast, seen: [...seen, ...fresh.map(a => a.key)].slice(-500) }
}
