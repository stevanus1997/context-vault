import type { Snapshot } from '../../types'

// stdout build_status.py --format json → Snapshot; bukan JSON / bukan v1 → null.
export function parseSnapshot(stdout: string): Snapshot | null {
  try {
    const v = JSON.parse(stdout)
    if (v && v.v === 1 && Array.isArray(v.items) && Array.isArray(v.alerts)) {
      return { ...v, errors: Array.isArray(v.errors) ? v.errors : [] } as Snapshot
    }
  } catch {
    // JSON setengah jadi / kosong: anggap nggak ada data baru
  }
  return null
}
