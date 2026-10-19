// Mod context-vault: panel status build + status line + toast.
// Read-only: tiap POLL_MS menjalankan template/.claude/build_status.py (pembaca yang sama dengan
// baris progres drive.sh) lalu menggambar dari JSON-nya. Nol panggilan model; nol op di `claude -p`.
// Spec: docs/superpowers/specs/2026-10-19-build-status-panel-design.md
import { atom, update } from 'claude-code'
import type { Register } from 'claude-code'

import { nextAlerts } from './panel/alerts'
import { parseSnapshot } from './panel/snapshot'

export const PANE = 'cv-build'
export const TITLE = 'context-vault · build'
export const POLL_MS = 3000

const snapshot = atom({ plugin: 'context-vault', key: 'snapshot' } as const, null)
const error = atom({ plugin: 'context-vault', key: 'error' } as const, null)
const seen = atom({ plugin: 'context-vault', key: 'seen' } as const, null)
const wasRunning = atom({ plugin: 'context-vault', key: 'wasRunning' } as const, false)

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    if (e.isInteractive === false) return next(e)
    if (!(await $.fs.exists('control/workspace.yaml'))) return next(e)
    await $.command.register({ name: 'cv-panel', description: 'context-vault: buka/tutup panel status build' })
    const script = `${$.plugin.root}/template/.claude/build_status.py`

    const poll = async (): Promise<void> => {
      let res
      try {
        res = await $.process.run(['python3', script, '--root', e.cwd, '--format', 'json'], { cwd: e.cwd, timeoutMs: 5000 })
      } catch {
        await update($, error, () => 'butuh python3')
        $.ui.status(undefined)
        return
      }
      const snap = res.exitCode === 0 ? parseSnapshot(res.stdout) : null
      if (!snap) return                    // file setengah tertulis / rusak: pakai hasil terakhir yang valid
      await update($, snapshot, () => snap)
      await update($, error, () => null)
      $.ui.status(snap.status_line ?? undefined)

      let toast: string | null = null
      await update($, seen, prev => {
        const r = nextAlerts(prev, snap.alerts)
        toast = r.toast
        return r.seen
      })
      if (toast) $.ui.toast(toast, { timeoutMs: 8000 })

      const isRunning = snap.items[0]?.running ?? false
      let opens = false
      await update($, wasRunning, was => {
        opens = isRunning && !was
        return isRunning
      })
      if (opens) await $.ui.open({ id: PANE, title: TITLE })
    }

    await poll()
    let busy = false
    $.clock.every(POLL_MS, () => {
      if (busy) return                     // poll sebelumnya belum selesai: lewati tick ini
      busy = true
      void poll().finally(() => {
        busy = false
      })
    })
    return next(e)
  })
}
