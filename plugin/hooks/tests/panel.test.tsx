// Test mod panel build context-vault — jalanin: claude plugin test plugin
// Engine di bawah plugin dijawab hook test (fs.exists, process.run, ui.*, command.register);
// hook yang manggil $ tanpa jawaban di-skip diam-diam, jadi tiap op yang dipanggil wajib dijawab.
import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On } from 'claude-code'

import type { Alert, SnapItem, Snapshot } from '../../types'
import { nextAlerts } from '../panel/alerts'
import { bar, pips } from '../panel/view'
import { SNAP_MID } from './fixture-snapshot'

const item = (over: Partial<SnapItem> = {}): SnapItem => ({
  kind: 'feature', name: 'checkout-v2', dir: 'control/features/checkout-v2', mode: 'attended', drive: null,
  done: 7, total: 12, running: true, lanes: [], held: [], gates: [], eta: null, milestones: [], drive_line: '',
  ...over,
})
const gateG3: Alert = { key: 'gate|control/features/checkout-v2|G3', text: '◆ checkout-v2 · gate G3 antri — api×M2: floor-scan T6 (token)' }
const heldT9: Alert = { key: 'held|control/features/checkout-v2|T9|needs_human|', text: '⏸ checkout-v2 · T9 needs_human' }
const stop: Alert = { key: 'stop|control/features/checkout-v2|review|1799999900', text: '🔔 checkout-v2 · build berhenti — 1 gate + 1 blocker nunggu lo' }
const snapA: Snapshot = { v: 1, items: [item()], alerts: [gateG3], status_line: 'checkout-v2 7/12 · 1 gate', errors: [] }
const snapB: Snapshot = { ...snapA, alerts: [gateG3, heldT9], status_line: 'checkout-v2 7/12 · 1 ketahan · 1 gate' }
const snapC: Snapshot = { ...snapA, alerts: [gateG3, heldT9, stop] }
const running = (r: boolean): Snapshot => ({ ...snapA, items: [item({ running: r })] })

type Run = Snapshot | { exitCode: number; stdout?: string; stderr?: string } | 'reject'
const START = { cwd: '/p', surface: null, isInteractive: true } as const

// Jawab semua op engine ({ value } atau { deny } = call plugin reject); process.run dijawab
// berurutan dari antrian (habis → jawaban terakhir diulang).
function world(on: On, runs: Run[], opts: { exists?: boolean; before?: () => Promise<void>; panes?: { id: string; isShown: boolean }[]; openDeny?: boolean } = {}) {
  const seen = { argv: [] as (readonly string[])[], status: [] as (string | undefined)[], toasts: [] as string[], titles: [] as (string | undefined)[], opens: 0, closes: 0, registers: [] as string[] }
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
    return { value: { exitCode: r.exitCode, stdout: r.stdout ?? '', stderr: r.stderr ?? 'boom', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('ui.status', async ($, e) => { seen.status.push(e.text); return { value: undefined } })
  on('ui.toast', async ($, e) => { seen.toasts.push(e.text); return { value: undefined } })
  on('ui.open', async ($, e) => { seen.opens++; seen.titles.push(e.title); return opts.openDeny ? { deny: 'ui.open ditolak' } : { value: { isPlaced: true } } })
  on('ui.close', async () => { seen.closes++; return { value: undefined } })
  on('ui.panes', async () => ({
    value: (opts.panes ?? []).map(p => ({ ...p, title: '🔨 build', isFocused: false, isPlaced: true, plugin: 'context-vault' })),
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

test('python3 nggak bisa jalan → status dikosongkan; jeda 60 dtk (nggak spawn tiap 3 dtk), lalu pulih tanpa toast', async ($, on) => {
  const w = world(on, ['reject', snapA])
  const clock = mock.clock(on)
  await $.session.start(START)
  expect(w.status).toEqual([undefined])
  for (let i = 0; i < 5; i++) await clock.advance(3000)
  expect(w.argv.length).toBe(1)              // t=15000: masih jeda
  await clock.advance(45_000)                // t=60000: jeda habis → coba lagi
  expect(w.argv.length).toBe(2)
  expect(w.status.at(-1)).toBe('checkout-v2 7/12 · 1 gate')
  expect(w.toasts).toEqual([])
})

test('exit 2 (setengah tertulis) terus > 90 dtk → data lama berhenti dipajang: peringatan + status kosong', async ($, on) => {
  const w = world(on, [snapA, { exitCode: 2, stderr: 'build_status: control/features/x/tasks.yaml: kosong' }])
  const clock = mock.clock(on)
  await $.session.start(START)
  await clock.advance(87_000)                // gagal sejak t=3000 → 84 dtk: masih wajar
  expect(w.status.at(-1)).toBe('checkout-v2 7/12 · 1 gate')
  await clock.advance(9_000)                 // t=96000 → 93 dtk
  expect(w.status.at(-1)).toBeUndefined()
  const ui = await mountPane($)
  expect(await ui.find({ type: 'Text', text: /^Panel: data basi/ })).toBeDefined()
})

test('pembaca crash (exit 1) → baris error dari stderr + status kosong, bukan "Nunggu data…" diam-diam', async ($, on) => {
  const w = world(on, [{ exitCode: 1, stderr: 'Traceback (most recent call last):\n  File "x", line 1\nValueError: boom\n' }])
  mock.clock(on)
  await $.session.start(START)
  expect(w.status).toEqual([undefined])
  const ui = await mountPane($)
  expect(await ui.find({ type: 'Text', text: /^Panel: pembaca status gagal \(exit 1\): ValueError: boom$/ })).toBeDefined()
})

test('python3 stub macOS (Command Line Tools belum ada) → pesan install; python3 lama (SyntaxError) → pesan versi', async ($, on) => {
  world(on, [
    { exitCode: 1, stderr: 'xcrun: error: invalid active developer path (/Library/Developer/CommandLineTools), missing xcrun\n' },
    { exitCode: 1, stderr: '  File "build_status.py", line 394\nSyntaxError: invalid syntax\n' },
  ])
  const clock = mock.clock(on)
  await $.session.start(START)
  let ui = await mountPane($)
  expect(await ui.find({ type: 'Text', text: /^Panel butuh python3/ })).toBeDefined()
  await ui.unmount()
  await clock.advance(60_000)
  ui = await mountPane($)
  expect(await ui.find({ type: 'Text', text: /^Panel: python3 terlalu lama/ })).toBeDefined()
})

test('auto-open: build yang jalan bukan item teratas tetap membuka panel', async ($, on) => {
  const snap: Snapshot = { ...snapA, items: [item({ running: false }), item({ name: 'login', dir: 'control/features/login', running: true })] }
  const w = world(on, [snap])
  mock.clock(on)
  await $.session.start(START)
  expect(w.opens).toBe(1)
  expect(w.titles).toEqual(['🔨 build'])     // judul pendek: tab pane sempit nggak motong
})

test('poll pertama melempar (ui.open ditolak) → interval tetap hidup', async ($, on) => {
  const w = world(on, [running(true), snapA], { openDeny: true })
  const clock = mock.clock(on)
  await $.session.start(START)
  await clock.advance(3000)
  expect(w.argv.length).toBe(2)
  expect(w.status.at(-1)).toBe('checkout-v2 7/12 · 1 gate')
})

test('reload mod (session.start jalan lagi, $.state tetap): alert lama nggak di-toast, panel nggak dibuka ulang', async ($, on) => {
  const w = world(on, [running(true), running(true)])
  mock.clock(on)
  await $.session.start(START)
  expect(w.opens).toBe(1)
  await $.session.start(START)
  expect(w.argv.length).toBe(2)
  expect(w.toasts).toEqual([])
  expect(w.opens).toBe(1)
})

test('auto-open sekali per work-item: jeda antar-task nggak buka ulang panel yang ditutup user', async ($, on) => {
  const other: Snapshot = { ...snapA, items: [item({ name: 'login', dir: 'control/features/login', running: true })] }
  const w = world(on, [running(true), running(true), running(false), running(true), running(false), other])
  const clock = mock.clock(on)
  await $.session.start(START)
  expect(w.opens).toBe(1)
  await clock.advance(3000)                  // masih jalan
  await clock.advance(3000)                  // jeda: task lama done, task baru belum in_progress
  await clock.advance(3000)                  // task berikut jalan — fitur sama
  expect(w.opens).toBe(1)
  await clock.advance(3000)
  await clock.advance(3000)                  // build lain mulai → buka sekali untuk dia
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

// --- Task 7: isi panel + /cv-panel (tampilan: kartu header + emoji, lihat view.tsx) ---
const MID2: Snapshot = { ...SNAP_MID, items: SNAP_MID.items.slice(0, 2) }
const withItem = (over: Partial<SnapItem>): Snapshot => ({ ...MID2, items: [{ ...MID2.items[0]!, ...over }] })
const paneOf = async ($: Engine, on: On, snap: Snapshot) => {
  world(on, [snap])
  mock.clock(on)
  await $.session.start(START)
  return mountPane($)
}
type Ui = Awaited<ReturnType<typeof mountPane>>
const texts = async (ui: Ui) => (await ui.findAll({ type: 'Text' })).map(t => t.text)
const row = async (ui: Ui, key: string) => (await ui.find({ key }))?.text

test('panel: kartu header — nama tebal, chip mode, +N build lain', async ($, on) => {
  const ui = await paneOf($, on, MID2)
  expect((await ui.find({ key: 'card' }))?.props.borderStyle).toBe('round')
  expect((await ui.find({ type: 'Text', text: /^checkout-v2$/ }))?.props.bold).toBe(true)
  expect(await texts(ui)).toContain(' 🤖 UNATTENDED · putaran 2 ')
  expect(await texts(ui)).toContain('+1 build lain')
  // pane sempit: chip turun baris, nama nggak dipotong demi chip
  expect((await ui.find({ key: 'head' }))?.props.flexWrap).toBe('wrap')
})

test('panel: build attended → chip 👀 ATTENDED, tanpa footer putaran', async ($, on) => {
  const ui = await paneOf($, on, { ...MID2, items: [MID2.items[1]!] })
  expect(await texts(ui)).toContain(' 👀 ATTENDED ')
  expect(await ui.find({ key: 'footer' })).toBeUndefined()
})

test('panel: progres — pips ▰▱ berwarna, angka, persen, ETA + catatan ketahan', async ($, on) => {
  const ui = await paneOf($, on, MID2)
  expect(await texts(ui)).toContain('▰▰▰▰▰▰▰▱▱▱▱▱ 7/12 · 58%')
  expect(await texts(ui)).toContain('🏁 sisa ~1–15m + T9 nunggu lo')      // tanpa spasi depan: turun baris tetap rata kiri
  expect((await ui.find({ key: 'progress' }))?.props.flexWrap).toBe('wrap')
  expect((await ui.find({ type: 'Text', text: /^▰+$/ }))?.props.color).toBe('success')
  expect((await ui.find({ type: 'Text', text: /^▱+$/ }))?.props.dimColor).toBe(true)
})

test('panel: ETA lewat estimasi → ⌛ tanpa "sisa"', async ($, on) => {
  const ui = await paneOf($, on, withItem({ eta: { text: 'lewat estimasi', held_note: null } }))
  expect(await texts(ui)).toContain('⌛ lewat estimasi')
  expect((await texts(ui)).some(t => t.includes('sisa'))).toBe(false)
})

test('panel: ringkasan — 🔄 jalan, 🚧 ketahan + yang ditahan, 🚦 gate', async ($, on) => {
  const ui = await paneOf($, on, MID2)
  expect(await row(ui, 'lanes')).toBe('🔄 2 jalan  T8 api · T11 web')
  expect(await row(ui, 'held-T9')).toBe('🚧 T9 ketahan  nahan T12, T13')
  expect(await row(ui, 'gates')).toBe('🚦 1 gate antri')
})

test('panel: lane diam (sesi crash) → 💤 diam, bukan jalan', async ($, on) => {
  const it = MID2.items[0]!
  const ui = await paneOf($, on, withItem({ running: false, lanes: it.lanes.map(l => ({ ...l, quiet: true, quiet_for: '2j' })) }))
  expect(await row(ui, 'lanes')).toBe('💤 2 diam  T8 api · T11 web')
})

test('panel: milestone kelar dilipat ✅ satu baris, yang jalan 📂 + bar', async ($, on) => {
  const ui = await paneOf($, on, MID2)
  expect(await row(ui, 'ms-M1')).toBe('✅ M1 Fondasi auth 4/4')
  expect(await ui.find({ key: 'task-T1' })).toBeUndefined()
  expect(await row(ui, 'ms-M2')).toBe('📂 M2 Checkout ███░░░░░ 3/8')
})

test('panel: baris task — ikon status, unit, fase/durasi, alasan ketahan, nunggu dep, int', async ($, on) => {
  const ui = await paneOf($, on, MID2)
  expect(await row(ui, 'task-T5')).toBe('✅ T5   api  cart totals service')
  expect(await row(ui, 'task-T8')).toBe('🔄 T8   api  checkout endpoint impl · 12m')
  expect(await row(ui, 'task-T11')).toBe('🔄 T11  web  cart summary UI 7m')
  expect(await row(ui, 'task-T9')).toBe('🚧 T9   api  migrate orders needs_human')
  expect(await row(ui, 'why-T9')).toBe('↳ migrate destructive — nunggu lo')
  expect(await row(ui, 'task-T12')).toBe('⏳ T12  web  checkout button nunggu T9, T11')
  expect(await row(ui, 'task-T13')).toBe('⏳ T13  int  checkout roundtrip nunggu T8, T12')
})

test('panel: judul panjang — task belum kelar & milestone 📂 turun baris, task ✅ tetap satu baris', async ($, on) => {
  const ui = await paneOf($, on, MID2)
  const wrapOf = async (text: RegExp) => (await ui.find({ type: 'Text', text }))?.props.wrap
  expect(await wrapOf(/^checkout button$/)).toBe('wrap')                  // ⏳ T12
  expect(await wrapOf(/^checkout endpoint$/)).toBe('wrap')                // 🔄 T8
  expect(await wrapOf(/^migrate destructive — nunggu lo$/)).toBe('wrap')  // ↳ alasan T9
  expect(await wrapOf(/^cart totals service$/)).toBe('truncate-end')      // ✅ T5
  expect(await wrapOf(/^Checkout$/)).toBe('wrap')                         // 📂 M2
  expect(await wrapOf(/^✅ M1 Fondasi auth$/)).toBe('truncate-end')        // milestone kelar dilipat
})

test('panel: task diam → 💤 "diam <durasi>", bukan durasi naik', async ($, on) => {
  const it = MID2.items[0]!
  const ms = it.milestones.map(m => ({ ...m, tasks: m.tasks.map(x => (x.id === 'T8' ? { ...x, quiet: true, quiet_for: '40m' } : x)) }))
  const ui = await paneOf($, on, withItem({ milestones: ms }))
  expect(await row(ui, 'task-T8')).toBe('💤 T8   api  checkout endpoint diam 40m')
})

test('panel: gate antri + footer putaran', async ($, on) => {
  const ui = await paneOf($, on, MID2)
  expect(await row(ui, 'gate-G3')).toBe('🚦 G3  api×M2  floor-scan T6 (token)')
  expect(await row(ui, 'footer')).toBe('🕒 jalan 1j12m / maks 6j')
})

test('panel: file rusak di work-item lain → 🚨 peringatan, item sehat tetap tampil', async ($, on) => {
  const err = { dir: 'control/features/old-done', message: 'control/features/old-done/tasks.yaml: baris 8: indentasi tak terduga' }
  const ui = await paneOf($, on, { ...MID2, errors: [err] })
  expect(await ui.find({ key: 'card' })).toBeDefined()
  expect(await row(ui, 'err-0')).toBe('🚨 control/features/old-done/tasks.yaml: baris 8: indentasi tak terduga')
})

test('panel: nggak ada build → ☕, peringatan file rusak tetap tampil', async ($, on) => {
  const err = { dir: 'control/features/old-done', message: 'control/features/old-done/tasks.yaml: baris 8: indentasi tak terduga' }
  const ui = await paneOf($, on, { ...MID2, items: [], errors: [err] })
  expect(await texts(ui)).toContain('☕ Nggak ada build jalan.')
  expect(await row(ui, 'err-0')).toBe('🚨 control/features/old-done/tasks.yaml: baris 8: indentasi tak terduga')
  expect(await ui.find({ key: 'card' })).toBeUndefined()
})

test('panel: belum ada data (poll pertama exit 2) → ⏳ Nunggu data…', async ($, on) => {
  const ui = await paneOf($, on, { exitCode: 2 } as unknown as Snapshot)
  expect(await texts(ui)).toContain('⏳ Nunggu data…')
})

test('panel: pesan error pakai ikon — 🐍 python3, 🚨 lainnya', async ($, on) => {
  world(on, ['reject', { exitCode: 1, stderr: 'ValueError: boom\n' }])
  const clock = mock.clock(on)
  await $.session.start(START)
  let ui = await mountPane($)
  expect((await texts(ui)).some(t => t.startsWith('🐍 Panel butuh python3'))).toBe(true)
  await ui.unmount()
  await clock.advance(60_000)
  ui = await mountPane($)
  expect((await texts(ui)).some(t => t.startsWith('🚨 Panel: pembaca status gagal'))).toBe(true)
})

test('bar: blok per-delapan (▏…▉) + sisa ░; pips: ▰ bulat + ▱', async () => {
  expect(bar(3, 8, 8)).toEqual(['███', '░░░░░'])
  expect(bar(5, 8, 4)).toEqual(['██▌', '░'])
  expect(bar(1, 3, 4)).toEqual(['█▍', '░░'])
  expect(bar(0, 0, 4)).toEqual(['', '░░░░'])
  expect(bar(9, 8, 4)).toEqual(['████', ''])
  expect(pips(7, 12, 12)).toEqual(['▰▰▰▰▰▰▰', '▱▱▱▱▱'])
  expect(pips(0, 0, 3)).toEqual(['', '▱▱▱'])
})

const PANE_PROPS = { title: '🔨 build', isFocused: false, bodyColumns: 60, placement: 'inline', scroll: { offset: 0, bodyRows: 30 }, view: {} } as const
type Surface = 'terminal' | 'desktop'
const mountPane = ($: Engine, surface: Surface = 'terminal') =>
  $.ui.mount({ plugin: 'context-vault', surface, component: 'Pane', requestId: 'cv-build', props: PANE_PROPS })

test('pane di-mount (terminal & desktop): menggambar snapshot terakhir', async ($, on) => {
  world(on, [SNAP_MID])
  mock.clock(on)
  await $.session.start(START)
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await mountPane($, surface)
    expect(await ui.find({ type: 'Text', text: /^checkout-v2$/ })).toBeDefined()
    expect(await ui.find({ key: 'ms-M1' })).toBeDefined()
    await ui.unmount()
  }
})

test('pane: exit ≠ 0 sesudah data valid → tetap gambar data lama', async ($, on) => {
  world(on, [SNAP_MID, { exitCode: 2 }])
  const clock = mock.clock(on)
  await $.session.start(START)
  await clock.advance(3000)
  const ui = await mountPane($)
  expect(await ui.find({ type: 'Text', text: /UNATTENDED · putaran 2/ })).toBeDefined()
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
