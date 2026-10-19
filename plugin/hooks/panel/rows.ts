import type { SnapTask, Snapshot } from '../../types'

// Snapshot → baris panel (murni). Layout spec §4 (D4/D4a): header + progres, ringkasan 3 baris,
// pohon per milestone (yang kelar dilipat satu baris), gate antri, footer drive.sh.
export type Row = { text: string; color?: string; dim?: boolean }

export function bar(done: number, total: number, width: number): string {
  const f = total ? Math.min(width, Math.max(0, Math.round((done / total) * width))) : 0
  return '█'.repeat(f) + '░'.repeat(width - f)
}

const HELD = ['blocked', 'needs_human']

function taskRows(t: SnapTask): Row[] {
  const u = t.unit === 'integration' ? 'int' : t.unit
  const head = ` %s ${t.id.padEnd(4)} ${u.padEnd(4)} ${t.desc}`
  if (t.status === 'done') return [{ text: head.replace('%s', '✓'), color: 'success' }]
  if (t.status === 'in_progress') {
    const tail = t.quiet ? ` diam ${t.quiet_for ?? ''}` : ` ${t.phase ? t.phase + ' ' : ''}${t.elapsed ?? ''}`
    return [{ text: (head.replace('%s', '▸') + tail).trimEnd(), color: 'suggestion' }]
  }
  if (HELD.includes(t.status)) {
    const rows: Row[] = [{ text: `${head.replace('%s', '⏸')} ${t.status}`, color: 'warning' }]
    if (t.reason) rows.push({ text: `          ${t.reason}`, dim: true })
    return rows
  }
  const wait = t.waiting_on.length ? ` nunggu ${t.waiting_on.join(', ')}` : ''
  return [{ text: head.replace('%s', '·') + wait, dim: true }]
}

export function paneRows(snap: Snapshot | null, error: string | null): Row[] {
  if (error !== null) return [{ text: 'Panel butuh python3 — install dulu (macOS: xcode-select --install).', color: 'warning' }]
  if (snap === null) return [{ text: 'Nunggu data…', dim: true }]
  const it = snap.items[0]
  const errs: Row[] = (snap.errors ?? []).map(e => ({ text: `⚠ ${e.message}`, color: 'warning' }))
  if (!it) return [{ text: 'Nggak ada build jalan.', dim: true }, ...errs]

  const rows: Row[] = [{ text: `${it.name}  ${it.drive ? `unattended · putaran ${it.drive.round}` : 'attended'}` }]
  if (snap.items.length > 1) rows.push({ text: `+${snap.items.length - 1} build lain`, dim: true })
  rows.push({
    text: `${bar(it.done, it.total, 12)} ${it.done}/${it.total}` +
      (it.eta ? `  sisa ${it.eta.text}` : '') + (it.eta?.held_note ? ` ${it.eta.held_note}` : ''),
  })
  if (it.lanes.length) {
    const label = it.lanes.some(l => !l.quiet) ? 'jalan' : 'diam'   // diam = in_progress tanpa aktivitas (crash / nunggu jawaban)
    rows.push({ text: `▸ ${it.lanes.length} ${label} ${it.lanes.map(l => `${l.id} ${l.unit}`).join(' · ')}`, color: 'suggestion' })
  }
  for (const h of it.held) {
    rows.push({ text: `⏸ ${h.id} ketahan` + (h.blocks.length ? ` · nahan ${h.blocks.join(', ')}` : ''), color: 'warning' })
  }
  if (it.gates.length) rows.push({ text: `◆ ${it.gates.length} gate antri`, color: 'permission' })
  rows.push({ text: '' })

  for (const m of it.milestones) {
    if (m.done === m.total) {
      rows.push({ text: `✓ ${m.id} ${m.title}  ${m.done}/${m.total}`, color: 'success' })
      continue
    }
    rows.push({ text: `${m.id} ${m.title}  ${bar(m.done, m.total, 8)}  ${m.done}/${m.total}` })
    for (const t of m.tasks) rows.push(...taskRows(t))
  }
  if (it.gates.length) {
    rows.push({ text: '' })
    for (const g of it.gates) rows.push({ text: `◆ ${g.id} ${g.segment}  ${g.reason}`, color: 'permission' })
  }
  if (errs.length) rows.push({ text: '' }, ...errs)
  if (it.drive) rows.push({ text: `jalan ${it.drive.elapsed} / maks ${it.drive.max}`, dim: true })
  return rows
}
