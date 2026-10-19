// Mod context-vault: panel status build + status line + toast.
// Read-only: tiap POLL_MS menjalankan template/.claude/build_status.py (pembaca yang sama dengan
// baris progres drive.sh) lalu menggambar dari JSON-nya. Nol panggilan model; nol op di `claude -p`.
// Spec: docs/superpowers/specs/2026-10-19-build-status-panel-design.md
import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import { nextAlerts } from './panel/alerts'
import { paneRows } from './panel/rows'
import { parseSnapshot } from './panel/snapshot'

export const PANE = 'cv-build'
export const TITLE = 'context-vault · build'
export const POLL_MS = 3000
export const STALE_MS = 90_000      // exit 2 (file setengah tertulis) selama ini → data lama berhenti dipajang
export const BACKOFF_MS = 60_000    // gagal keras (python3 tak ada / crash) → coba lagi sesudah jeda ini, bukan tiap tick

// Baris stderr terakhir yang berisi — di traceback Python itu baris "XxxError: …".
const lastLine = (s: string): string => (s.trim().split('\n').at(-1) ?? '').trim().slice(0, 160)

// Kegagalan keras pembaca → teks error panel.
function describe(exitCode: number, stderr: string): string {
  if (/xcrun|CommandLineTools|developer tools/i.test(stderr)) return 'butuh python3'   // stub /usr/bin/python3 macOS
  if (/SyntaxError/.test(stderr)) return 'python3 terlalu lama (butuh ≥ 3.9)'
  const msg = lastLine(stderr)
  return `pembaca status gagal (exit ${exitCode})${msg ? `: ${msg}` : ''}`
}

const snapshot = atom({ plugin: 'context-vault', key: 'snapshot' } as const, null)
const error = atom({ plugin: 'context-vault', key: 'error' } as const, null)
const seen = atom({ plugin: 'context-vault', key: 'seen' } as const, null)
const wasRunning = atom({ plugin: 'context-vault', key: 'wasRunning' } as const, false)
const autoOpened = atom({ plugin: 'context-vault', key: 'autoOpened' } as const, [])

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    if (e.isInteractive === false) return next(e)
    if (!(await $.fs.exists('control/workspace.yaml'))) return next(e)
    await $.command.register({ name: 'cv-panel', description: 'context-vault: buka/tutup panel status build' })
    const script = `${$.plugin.root}/template/.claude/build_status.py`

    let badSince: number | null = null     // awal rentetan exit 2 (setengah tertulis); reload → mulai lagi
    let holdUntil = 0                      // jeda sesudah gagal keras: jangan spawn python3 (stub macOS!) tiap 3 dtk

    const fail = async (msg: string, now: number): Promise<void> => {
      await update($, error, () => msg)
      $.ui.status(undefined)
      holdUntil = now + BACKOFF_MS
    }

    const poll = async (): Promise<void> => {
      const t0 = await $.clock.now()
      if (t0 < holdUntil) return
      let res
      try {
        res = await $.process.run(['python3', script, '--root', e.cwd, '--format', 'json'], { cwd: e.cwd, timeoutMs: 5000 })
      } catch {
        const slow = (await $.clock.now()) - t0 >= 4500
        return fail(slow ? 'pembaca status kelamaan (> 5 dtk)' : 'butuh python3', t0)
      }
      if (res.exitCode !== 0 && res.exitCode !== 2) return fail(describe(res.exitCode, res.stderr), t0)
      const snap = res.exitCode === 0 ? parseSnapshot(res.stdout) : null
      if (!snap) {
        // exit 2 / JSON terpotong = file setengah tertulis: pakai hasil terakhir — tapi jangan selamanya
        if (badSince === null) badSince = t0
        if (t0 - badSince > STALE_MS) {
          await update($, error, () => `data basi — ${lastLine(res.stderr) || 'pembaca status gagal terus'}`)
          $.ui.status(undefined)
        }
        return
      }
      badSince = null
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

      // Auto-open sekali per work-item per sesi: jeda antar-task (running sempat false) tak membuka
      // ulang panel yang sudah ditutup user; buka manual tetap lewat /cv-panel. Build mana pun yang
      // jalan dihitung, bukan cuma item teratas (urutan item = mtime tasks.yaml, bukan "yang jalan").
      const run = snap.items.find(it => it.running)
      let starts = false
      await update($, wasRunning, was => {
        starts = run !== undefined && !was
        return run !== undefined
      })
      if (!starts || !run) return
      let fresh = false
      await update($, autoOpened, dirs => {
        fresh = !dirs.includes(run.dir)
        return fresh ? [...dirs, run.dir] : dirs
      })
      if (fresh) await $.ui.open({ id: PANE, title: TITLE })
    }

    let busy = false
    const tick = async (): Promise<void> => {
      if (busy) return                     // poll sebelumnya belum selesai: lewati tick ini
      busy = true
      try {
        await poll()
      } catch {
        // op engine ditolak (ui.open/state): jangan sampai interval ikut mati — coba lagi tick berikut
      } finally {
        busy = false
      }
    }
    $.clock.every(POLL_MS, () => {
      void tick()
    })
    await tick()
    return next(e)
  })

  on('command.run', { command: 'cv-panel' }, async $ => {
    const shown = (await $.ui.panes()).some(p => p.id === PANE && p.isShown)
    if (shown) {
      await $.ui.close({ id: PANE })
      return { text: 'Panel build ditutup.' }
    }
    await $.ui.open({ id: PANE, title: TITLE })
    return { text: 'Panel build dibuka.' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const rows = paneRows(await read($, snapshot), await read($, error))
    return (
      <Box flexDirection="column">
        {rows.map(r => (
          <Text wrap="truncate-end" color={r.color} dimColor={r.dim}>
            {r.text || ' '}
          </Text>
        ))}
      </Box>
    )
  })
}
