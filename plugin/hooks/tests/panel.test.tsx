// Test mod panel build context-vault — jalanin: claude plugin test plugin
// Engine di bawah plugin dijawab hook test (fs.exists, process.run, ui.*, command.register);
// hook yang manggil $ tanpa jawaban di-skip diam-diam, jadi tiap op yang dipanggil wajib dijawab.
import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On } from 'claude-code'

import type { Alert, SnapItem, Snapshot } from '../../types'
import { nextAlerts } from '../panel/alerts'
import { bar, paneRows } from '../panel/rows'
import { SNAP_MID } from './fixture-snapshot'

const item = (over: Partial<SnapItem> = {}): SnapItem => ({
  kind: 'feature', name: 'checkout-v2', dir: 'control/features/checkout-v2', mode: 'attended', drive: null,
  done: 7, total: 12, running: true, lanes: [], held: [], gates: [], eta: null, milestones: [], drive_line: '',
  ...over,
})
const gateG3: Alert = { key: 'gate|control/features/checkout-v2|G3', text: '◆ checkout-v2 · gate G3 antri — api×M2: floor-scan T6 (token)' }
const heldT9: Alert = { key: 'held|control/features/checkout-v2|T9|needs_human|', text: '⏸ checkout-v2 · T9 needs_human' }
const stop: Alert = { key: 'stop|control/features/checkout-v2|review|1799999900', text: '🔔 checkout-v2 · build berhenti — 1 gate + 1 blocker nunggu lo' }
const snapA: Snapshot = { v: 1, items: [item()], alerts: [gateG3], status_line: 'checkout-v2 7/12 · 1 gate' }
const snapB: Snapshot = { ...snapA, alerts: [gateG3, heldT9], status_line: 'checkout-v2 7/12 · 1 ketahan · 1 gate' }
const snapC: Snapshot = { ...snapA, alerts: [gateG3, heldT9, stop] }
const running = (r: boolean): Snapshot => ({ ...snapA, items: [item({ running: r })] })

type Run = Snapshot | { exitCode: number; stdout?: string } | 'reject'
const START = { cwd: '/p', surface: null, isInteractive: true } as const

// Jawab semua op engine ({ value } atau { deny } = call plugin reject); process.run dijawab
// berurutan dari antrian (habis → jawaban terakhir diulang).
function world(on: On, runs: Run[], opts: { exists?: boolean; before?: () => Promise<void>; panes?: { id: string; isShown: boolean }[] } = {}) {
  const seen = { argv: [] as (readonly string[])[], status: [] as (string | undefined)[], toasts: [] as string[], opens: 0, closes: 0, registers: [] as string[] }
  let last: Run = runs[0] ?? snapA
  on('session.start', async ($, e) => ({ cwd: e.cwd }))
  on('fs.exists', async () => ({ value: opts.exists ?? true }))
  on('command.register', async ($, e) => { seen.registers.push(e.name); return { value: { command: e.name } } })
  on('process.run', async ($, e) => {
    seen.argv.push(e.argv)
    await opts.before?.()
    const r = runs.length ? runs.shift()! : last
    last = r
    if (r === 'reject') return { deny: 'spawn python3 ENOENT' }
    if ('v' in r) return { value: { exitCode: 0, stdout: JSON.stringify(r), stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
    return { value: { exitCode: r.exitCode, stdout: r.stdout ?? '', stderr: 'boom', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('ui.status', async ($, e) => { seen.status.push(e.text); return { value: undefined } })
  on('ui.toast', async ($, e) => { seen.toasts.push(e.text); return { value: undefined } })
  on('ui.open', async () => { seen.opens++; return { value: { isPlaced: true } } })
  on('ui.close', async () => { seen.closes++; return { value: undefined } })
  on('ui.panes', async () => ({
    value: (opts.panes ?? []).map(p => ({ ...p, title: 'context-vault · build', isFocused: false, isPlaced: true, plugin: 'context-vault' })),
  }))
  return seen
}

test('headless (claude -p): nol op — nggak poll, nggak register command', async ($, on) => {
  const w = world(on, [snapA])
  mock.clock(on)
  await $.session.start({ ...START, isInteractive: false })
  expect(w.argv.length).toBe(0)
  expect(w.registers).toEqual([])
})

test('bukan produk context-vault (tanpa control/workspace.yaml): nggak poll', async ($, on) => {
  const w = world(on, [snapA], { exists: false })
  mock.clock(on)
  await $.session.start(START)
  expect(w.argv.length).toBe(0)
})

test('poll pertama: status line = status_line, toast nol (baseline), command terdaftar', async ($, on) => {
  const w = world(on, [snapA])
  mock.clock(on)
  await $.session.start(START)
  expect(w.status.at(-1)).toBe('checkout-v2 7/12 · 1 gate')
  expect(w.toasts).toEqual([])
  expect(w.registers).toEqual(['cv-panel'])
  const argv = w.argv[0]!
  expect(argv[0]).toBe('python3')
  expect(argv[1]).toMatch(/\/plugin\/template\/\.claude\/build_status\.py$/)
  expect(argv.slice(2)).toEqual(['--root', '/p', '--format', 'json'])
})

test('alert baru di tick berikut → satu toast; snapshot sama lagi → nggak diulang', async ($, on) => {
  const w = world(on, [snapA, snapB, snapB])
  const clock = mock.clock(on)
  await $.session.start(START)
  await clock.advance(3000)
  expect(w.toasts).toEqual([heldT9.text])
  await clock.advance(3000)
  expect(w.toasts).toEqual([heldT9.text])
  expect(w.status.at(-1)).toBe('checkout-v2 7/12 · 1 ketahan · 1 gate')
})

test('dua alert baru sekaligus → satu toast "(+1 lagi)"', async ($, on) => {
  const w = world(on, [snapA, snapC])
  const clock = mock.clock(on)
  await $.session.start(START)
  await clock.advance(3000)
  expect(w.toasts).toEqual([`${heldT9.text} (+1 lagi)`])
})

test('exit ≠ 0 / JSON setengah jadi → status lama dipertahankan, baseline alert nggak hilang', async ($, on) => {
  const w = world(on, [snapA, { exitCode: 2 }, { exitCode: 0, stdout: '{"v":1,"items":' }, snapB])
  const clock = mock.clock(on)
  await $.session.start(START)
  const n = w.status.length
  await clock.advance(3000)
  await clock.advance(3000)
  expect(w.status.length).toBe(n)
  expect(w.status.at(-1)).toBe('checkout-v2 7/12 · 1 gate')
  await clock.advance(3000)
  expect(w.toasts).toEqual([heldT9.text])    // gateG3 tetap dianggap sudah dilihat
})

test('python3 nggak bisa jalan → status dikosongkan; pulih di poll berikut tanpa toast', async ($, on) => {
  const w = world(on, ['reject', snapA])
  const clock = mock.clock(on)
  await $.session.start(START)
  expect(w.status).toEqual([undefined])
  await clock.advance(3000)
  expect(w.status.at(-1)).toBe('checkout-v2 7/12 · 1 gate')
  expect(w.toasts).toEqual([])
})

test('auto-open hanya saat running berubah false → true', async ($, on) => {
  const w = world(on, [running(true), running(true), running(false), running(true)])
  const clock = mock.clock(on)
  await $.session.start(START)
  expect(w.opens).toBe(1)
  await clock.advance(3000)
  expect(w.opens).toBe(1)
  await clock.advance(3000)
  await clock.advance(3000)
  expect(w.opens).toBe(2)
})

test('poll lambat: tick berikutnya dilewati, bukan ditumpuk', async ($, on) => {
  let slow = false
  const clock = mock.clock(on)
  const w = world(on, [snapA], { before: async () => { if (slow) await clock.sleep(5000) } })   // poll ke-2 makan 5 dtk (> POLL_MS)
  await $.session.start(START)
  slow = true
  await clock.advance(3000)                  // t=3000: poll ke-2 mulai, tertahan sampai t=8000
  slow = false
  await clock.advance(3000)                  // t=6000: masih busy → dilewati
  expect(w.argv.length).toBe(2)
  await clock.advance(3000)                  // t=9000: poll ke-3
  expect(w.argv.length).toBe(3)
})

test('nextAlerts murni: baseline lalu yang baru saja', async () => {
  const a: Alert = { key: 'a', text: 'A' }
  const b: Alert = { key: 'b', text: 'B' }
  expect(nextAlerts(null, [a])).toEqual({ toast: null, seen: ['a'] })
  expect(nextAlerts(['a'], [a, b])).toEqual({ toast: 'B', seen: ['a', 'b'] })
  expect(nextAlerts(['a', 'b'], [a, b])).toEqual({ toast: null, seen: ['a', 'b'] })
})

// --- Task 7: isi panel + /cv-panel ---
const texts = (snap: Snapshot | null, err: string | null = null) => paneRows(snap, err).map(r => r.text)
const MID2: Snapshot = { ...SNAP_MID, items: SNAP_MID.items.slice(0, 2) }

test('paneRows: header, +N build lain, milestone kelar dilipat', async () => {
  const t = texts(MID2)
  expect(t).toContain('checkout-v2  unattended · putaran 2')
  expect(t).toContain('+1 build lain')
  expect(t.some(x => x.startsWith('✓ M1 Fondasi auth') && x.endsWith('4/4'))).toBe(true)
  expect(t.some(x => x.includes(' T1 '))).toBe(false)
})

test('paneRows: progres + ringkasan 3 baris', async () => {
  const t = texts(MID2)
  expect(t).toContain('███████░░░░░ 7/12  sisa ~1–15m + T9 nunggu lo')
  expect(t).toContain('▸ 2 jalan T8 api · T11 web')
  expect(t).toContain('⏸ T9 ketahan · nahan T12, T13')
  expect(t).toContain('◆ 1 gate antri')
})

test('paneRows: baris task — fase, ketahan + alasan, nunggu dep, int', async () => {
  const t = texts(MID2)
  expect(t).toContain('M2 Checkout  ███░░░░░  3/8')
  expect(t).toContain(' ▸ T8   api  checkout endpoint impl 12m')
  expect(t).toContain(' ▸ T11  web  cart summary UI 7m')
  expect(t).toContain(' ⏸ T9   api  migrate orders needs_human')
  expect(t).toContain('          migrate destructive — nunggu lo')
  expect(t.find(x => x.startsWith(' · T12 '))?.endsWith('nunggu T9, T11')).toBe(true)
  expect(t.find(x => x.startsWith(' · T13 '))).toContain(' int  ')
  expect(t).toContain('◆ G3 api×M2  floor-scan T6 (token)')
  expect(t).toContain('jalan 1j12m / maks 6j')
})

test('paneRows: task diam → "diam <durasi>", bukan durasi naik', async () => {
  const it = MID2.items[0]!
  const ms = it.milestones.map(m => ({ ...m, tasks: m.tasks.map(x => (x.id === 'T8' ? { ...x, quiet: true, quiet_for: '40m' } : x)) }))
  const t = texts({ ...MID2, items: [{ ...it, milestones: ms }] })
  expect(t.find(x => x.startsWith(' ▸ T8 '))?.endsWith('diam 40m')).toBe(true)
})

test('paneRows: error, belum ada data, nggak ada build; bar', async () => {
  expect(texts(null, 'butuh python3')[0]).toMatch(/^Panel butuh python3/)
  expect(paneRows(null, null)).toEqual([{ text: 'Nunggu data…', dim: true }])
  expect(paneRows({ ...SNAP_MID, items: [] }, null)).toEqual([{ text: 'Nggak ada build jalan.', dim: true }])
  expect(bar(3, 8, 8)).toBe('███░░░░░')
  expect(bar(0, 0, 4)).toBe('░░░░')
  expect(bar(9, 8, 4)).toBe('████')
})

const PANE_PROPS = { title: 'context-vault · build', isFocused: false, bodyColumns: 60, placement: 'inline', scroll: { offset: 0, bodyRows: 30 }, view: {} } as const
type Surface = 'terminal' | 'desktop'
const mountPane = ($: Engine, surface: Surface = 'terminal') =>
  $.ui.mount({ plugin: 'context-vault', surface, component: 'Pane', requestId: 'cv-build', props: PANE_PROPS })

test('pane di-mount (terminal & desktop): menggambar snapshot terakhir', async ($, on) => {
  world(on, [SNAP_MID])
  mock.clock(on)
  await $.session.start(START)
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await mountPane($, surface)
    expect(await ui.find({ type: 'Text', text: /^checkout-v2  / })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /^✓ M1 Fondasi auth/ })).toBeDefined()
    await ui.unmount()
  }
})

test('pane: exit ≠ 0 sesudah data valid → tetap gambar data lama', async ($, on) => {
  world(on, [SNAP_MID, { exitCode: 2 }])
  const clock = mock.clock(on)
  await $.session.start(START)
  await clock.advance(3000)
  const ui = await mountPane($)
  expect(await ui.find({ type: 'Text', text: /^checkout-v2  unattended/ })).toBeDefined()
})

test('pane: python3 nggak bisa jalan → pesan install', async ($, on) => {
  world(on, ['reject'])
  mock.clock(on)
  await $.session.start(START)
  const ui = await mountPane($)
  expect(await ui.find({ type: 'Text', text: /^Panel butuh python3/ })).toBeDefined()
})

const CV_PANEL = { command: 'cv-panel', args: '', origin: { kind: 'composer' }, presentation: { isFullscreen: false, columns: 120 } } as const

test('/cv-panel: buka kalau belum tampil, tutup kalau tampil', async ($, on) => {
  const panes: { id: string; isShown: boolean }[] = []
  const w = world(on, [running(false)], { panes })
  mock.clock(on)
  await $.session.start(START)
  expect((await $.command.run(CV_PANEL)).text).toBe('Panel build dibuka.')
  expect(w.opens).toBe(1)
  panes.push({ id: 'cv-build', isShown: true })
  expect((await $.command.run(CV_PANEL)).text).toBe('Panel build ditutup.')
  expect(w.closes).toBe(1)
})
