// Kontrak mod context-vault: snapshot JSON v1 dari template/.claude/build_status.py
// (cermin persis skemanya) + nilai $.state yang dipakai panel build.

export type SnapTask = {
  id: string
  unit: string
  desc: string
  status: string
  elapsed: string | null
  phase: 'impl' | null
  quiet: boolean
  quiet_for: string | null
  reason: string | null
  waiting_on: string[]
}

export type SnapLane = {
  id: string
  unit: string
  desc: string
  elapsed: string | null
  phase: 'impl' | null
  quiet: boolean
  quiet_for: string | null
}

export type SnapHeld = {
  id: string
  unit: string
  status: 'blocked' | 'needs_human'
  reason: string | null
  blocks: string[]
}

export type SnapGate = { id: string; segment: string; reason: string }

export type SnapMilestone = { id: string; title: string; done: number; total: number; tasks: SnapTask[] }

export type SnapItem = {
  kind: 'feature' | 'fix'
  name: string
  dir: string
  mode: 'unattended' | 'attended'
  drive: { round: number; elapsed: string; max: string } | null
  done: number
  total: number
  running: boolean
  lanes: SnapLane[]
  held: SnapHeld[]
  gates: SnapGate[]
  eta: { text: string; held_note: string | null } | null
  milestones: SnapMilestone[]
  drive_line: string
}

export type Alert = { key: string; text: string }

// File rusak (dan sudah lama, bukan setengah tertulis) di satu work-item: item itu dilewati.
export type SnapError = { dir: string; message: string }

export type Snapshot = { v: 1; items: SnapItem[]; alerts: Alert[]; status_line: string | null; errors: SnapError[] }

declare module 'claude-code' {
  interface PluginState {
    'context-vault': {
      snapshot: Snapshot | null
      error: string | null
      seen: string[] | null
      wasRunning: boolean
      autoOpened: string[]
    }
  }
}
