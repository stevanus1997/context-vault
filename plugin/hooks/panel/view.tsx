import type { ElementTable } from 'claude-code'

import type { SnapItem, SnapMilestone, SnapTask, Snapshot } from '../../types'

// Snapshot → pohon panel. Layout spec §4 (D4/D4a) — kartu header (nama, chip mode, progres, ringkasan),
// pohon per milestone (yang kelar dilipat satu baris), gate antri, footer drive.sh.
// Ikon = emoji satu code point (tanpa VS16/ZWJ) supaya lebarnya pasti 2 sel di terminal mana pun.
// Ekor kanan yang nggak pernah turun baris diawali spasi: jarak minimum ke deskripsi (terpotong / turun baris);
// baris yang boleh turun (head, progress) pakai columnGap biar baris keduanya tetap rata kiri.
// Jangan namai variabel `h`: itu factory JSX global.
type Els = Pick<ElementTable, 'Box' | 'Text'>

const ICON = {
  done: '✅', run: '🔄', quiet: '💤', held: '🚧', pending: '⏳', gate: '🚦', open: '📂',
  eta: '🏁', late: '⌛', unattended: '🤖', attended: '👀', clock: '🕒', idle: '☕', alert: '🚨', python: '🐍',
} as const

const EIGHTHS = ['', '▏', '▎', '▍', '▌', '▋', '▊', '▉']

// [isi, sisa]: isi pakai blok per-delapan biar progres kecil tetap kelihatan geser.
export function bar(done: number, total: number, width: number): [string, string] {
  const cells = total ? Math.min(width, Math.max(0, (done / total) * width)) : 0
  let full = Math.floor(cells)
  let part = Math.round((cells - full) * 8)
  if (part === 8) { full++; part = 0 }
  const on = '█'.repeat(full) + EIGHTHS[part]
  return [on, '░'.repeat(width - full - (part ? 1 : 0))]
}

export function pips(done: number, total: number, width: number): [string, string] {
  const f = total ? Math.min(width, Math.max(0, Math.round((done / total) * width))) : 0
  return ['▰'.repeat(f), '▱'.repeat(width - f)]
}

const HELD = ['blocked', 'needs_human']

function Message(els: Els, icon: string, text: string, color?: string) {
  const { Text } = els
  return <Text><Text>{`${icon} `}</Text><Text color={color} dimColor={!color}>{text}</Text></Text>
}

function errorMessage(els: Els, error: string) {
  return error === 'butuh python3'
    ? Message(els, ICON.python, 'Panel butuh python3 — install dulu (macOS: xcode-select --install).', 'warning')
    : Message(els, ICON.alert, `Panel: ${error}`, 'warning')
}

function Card(els: Els, it: SnapItem, more: number) {
  const { Box, Text } = els
  const [on, off] = pips(it.done, it.total, 12)
  const pct = it.total ? Math.round((it.done / it.total) * 100) : 0
  const late = it.eta !== null && !it.eta.text.startsWith('~')
  const quiet = !it.lanes.some(l => !l.quiet)       // diam = in_progress tanpa aktivitas (crash / nunggu jawaban)
  return (
    <Box key="card" flexDirection="column" borderStyle="round" borderColor={it.running ? 'claude' : 'subtle'} paddingX={1}>
      <Box key="head" justifyContent="space-between" flexWrap="wrap" columnGap={1}>
        <Text bold wrap="truncate-end">{it.name}</Text>
        <Box flexShrink={0}>
          {it.drive
            ? <Text color="inverseText" backgroundColor="claude" bold>{` ${ICON.unattended} UNATTENDED · putaran ${it.drive.round} `}</Text>
            : <Text color="inverseText" backgroundColor="inactive">{` ${ICON.attended} ATTENDED `}</Text>}
        </Box>
      </Box>
      {more > 0 && <Text dimColor>{`+${more} build lain`}</Text>}
      <Box key="progress" justifyContent="space-between" flexWrap="wrap" columnGap={1} marginTop={1}>
        <Text>
          <Text color="success">{on}</Text><Text dimColor>{off}</Text>
          <Text bold>{` ${it.done}/${it.total}`}</Text><Text dimColor>{` · ${pct}%`}</Text>
        </Text>
        {it.eta && (
          <Text color={late ? 'warning' : undefined}>
            {late ? `${ICON.late} ${it.eta.text}` : `${ICON.eta} sisa ${it.eta.text}`}
            {it.eta.held_note && <Text dimColor>{` ${it.eta.held_note}`}</Text>}
          </Text>
        )}
      </Box>
      {it.lanes.length > 0 && (
        <Box key="lanes">
          <Text wrap="truncate-end">
            <Text color={quiet ? 'warning' : 'suggestion'}>{`${quiet ? ICON.quiet : ICON.run} ${it.lanes.length} ${quiet ? 'diam' : 'jalan'}`}</Text>
            <Text dimColor>{`  ${it.lanes.map(l => `${l.id} ${l.unit}`).join(' · ')}`}</Text>
          </Text>
        </Box>
      )}
      {it.held.map(x => (
        <Box key={`held-${x.id}`}>
          <Text wrap="truncate-end">
            <Text color="warning">{`${ICON.held} ${x.id} ketahan`}</Text>
            {x.blocks.length > 0 && <Text dimColor>{`  nahan ${x.blocks.join(', ')}`}</Text>}
          </Text>
        </Box>
      ))}
      {it.gates.length > 0 && (
        <Box key="gates"><Text color="permission">{`${ICON.gate} ${it.gates.length} gate antri`}</Text></Box>
      )}
    </Box>
  )
}

function taskTail(t: SnapTask): { text: string; color?: string; dim?: boolean } | null {
  if (t.status === 'in_progress') {
    if (t.quiet) return { text: ` diam ${t.quiet_for ?? ''}`.trimEnd(), color: 'warning' }
    const tail = [t.phase, t.elapsed].filter(Boolean).join(' · ')
    return tail ? { text: ` ${tail}`, color: 'suggestion' } : null
  }
  if (HELD.includes(t.status)) return { text: ` ${t.status}`, color: 'warning' }
  if (t.status === 'pending' && t.waiting_on.length) return { text: ` nunggu ${t.waiting_on.join(', ')}`, dim: true }
  return null
}

function taskIcon(t: SnapTask): string {
  if (t.status === 'done') return ICON.done
  if (t.status === 'in_progress') return t.quiet ? ICON.quiet : ICON.run
  if (HELD.includes(t.status)) return ICON.held
  return ICON.pending
}

function Task(els: Els, t: SnapTask) {
  const { Box, Text } = els
  const unit = t.unit === 'integration' ? 'int' : t.unit
  const done = t.status === 'done'
  const tail = taskTail(t)
  // Deskripsi di kolom sendiri: yang belum kelar turun baris rata di bawah awal deskripsi,
  // yang kelar (riwayat) tetap satu baris biar task yang jalan nggak kedorong ke bawah.
  return (
    <Box flexDirection="column">
      <Box key={`task-${t.id}`}>
        <Box flexShrink={0}>
          <Text dimColor={done}>{`${taskIcon(t)} ${t.id.padEnd(4)} `}<Text dimColor>{`${unit.padEnd(4)} `}</Text></Text>
        </Box>
        <Box key={`desc-${t.id}`} flexGrow={1} flexShrink={1}>
          <Text wrap={done ? 'truncate-end' : 'wrap'} dimColor={done}>{t.desc}</Text>
        </Box>
        {tail && <Box flexShrink={0}><Text color={tail.color} dimColor={tail.dim}>{tail.text}</Text></Box>}
      </Box>
      {HELD.includes(t.status) && t.reason && (
        <Box key={`why-${t.id}`} paddingLeft={13}>
          <Box flexShrink={0}><Text dimColor italic>{'↳ '}</Text></Box>
          <Text dimColor italic wrap="wrap">{t.reason}</Text>
        </Box>
      )}
    </Box>
  )
}

function Milestone(els: Els, m: SnapMilestone) {
  const { Box, Text } = els
  if (m.done === m.total) {
    return (
      <Box key={`ms-${m.id}`} justifyContent="space-between">
        <Text color="success" wrap="truncate-end">{`${ICON.done} ${m.id} ${m.title}`}</Text>
        <Box flexShrink={0}><Text dimColor>{` ${m.done}/${m.total}`}</Text></Box>
      </Box>
    )
  }
  const [on, off] = bar(m.done, m.total, 8)
  return (
    <Box flexDirection="column">
      <Box key={`ms-${m.id}`}>
        <Box flexShrink={0}><Text bold>{`${ICON.open} ${m.id} `}</Text></Box>
        <Box flexGrow={1} flexShrink={1}><Text bold wrap="wrap">{m.title}</Text></Box>
        <Box flexShrink={0}>
          <Text>{' '}<Text color="claude">{on}</Text><Text dimColor>{off}</Text>{` ${m.done}/${m.total}`}</Text>
        </Box>
      </Box>
      <Box flexDirection="column" paddingLeft={3}>
        {m.tasks.map(t => Task(els, t))}
      </Box>
    </Box>
  )
}

export function paneView(els: Els, snap: Snapshot | null, error: string | null) {
  const { Box, Text } = els
  if (error !== null) return errorMessage(els, error)
  if (snap === null) return Message(els, ICON.pending, 'Nunggu data…')
  const errs = (snap.errors ?? []).map((e, i) => (
    <Box key={`err-${i}`}>{Message(els, ICON.alert, e.message, 'warning')}</Box>
  ))
  const it = snap.items[0]
  if (!it) {
    return <Box flexDirection="column">{Message(els, ICON.idle, 'Nggak ada build jalan.')}{errs}</Box>
  }
  return (
    <Box flexDirection="column">
      {Card(els, it, snap.items.length - 1)}
      <Box flexDirection="column" marginTop={1}>
        {it.milestones.map(m => Milestone(els, m))}
      </Box>
      {it.gates.length > 0 && (
        <Box flexDirection="column" marginTop={1}>
          {it.gates.map(g => (
            <Box key={`gate-${g.id}`}>
              <Text wrap="truncate-end">
                {`${ICON.gate} `}<Text color="permission" bold>{g.id}</Text>
                <Text dimColor>{`  ${g.segment}`}</Text>{`  ${g.reason}`}
              </Text>
            </Box>
          ))}
        </Box>
      )}
      {errs.length > 0 && <Box flexDirection="column" marginTop={1}>{errs}</Box>}
      {it.drive && (
        <Box key="footer" marginTop={1}>
          <Text dimColor>{`${ICON.clock} jalan ${it.drive.elapsed} / maks ${it.drive.max}`}</Text>
        </Box>
      )}
    </Box>
  )
}
