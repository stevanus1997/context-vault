// Test mod panel build context-vault — jalanin: claude plugin test plugin
// Engine di bawah plugin dijawab hook test (fs.exists, process.run, ui.*, command.register);
// hook yang manggil $ tanpa jawaban di-skip diam-diam, jadi tiap op yang dipanggil wajib dijawab.
import { expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

import type { Alert, SnapItem, Snapshot } from '../../types'
import { nextAlerts } from '../panel/alerts'

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
function world(on: On, runs: Run[], opts: { exists?: boolean; before?: () => Promise<void> } = {}) {
  const seen = { argv: [] as (readonly string[])[], status: [] as (string | undefined)[], toasts: [] as string[], opens: 0, registers: [] as string[] }
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
