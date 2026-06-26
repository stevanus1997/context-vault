# fix — Reference (skema `fix.yaml` + `tasks.yaml`-fix + dispatch deltas)

Dibaca oleh skill `fix`. SKILL.md tetap ramping; detail skema & template ada di sini. Sebagian besar mesin eksekusi **dipinjam dari `build`** — lihat `${CLAUDE_PLUGIN_ROOT}/skills/build/reference.md` (rakit prompt §B, gate §D, resume §E). File ini hanya menulis **delta khas-fix**.

## A. Skema `fix.yaml` (mode post-ship)

```yaml
id: <slug>                   # mis. kupon-expired
status: open                 # open → diagnosed → shipped (+ dropped)
severity: normal             # normal | urgent  (metadata: urutan render-docs + sinyal)
reported_at: <YYYY-MM-DD>
reported: "<gejala dari user, 1 baris>"
relates_to: [<nama-fitur>]   # array; boleh >1; boleh [] (bug di shared util / skeleton wire)
flow: <nama-flow>            # link ke business/flows.md (boleh kosong)
units: [<app/pkg>]           # app/package kena (inferensi + KONFIRMASI user) — basis branch & gate
sensitivity: ""              # HASIL RE-EVALUASI vs invariants.md (lihat §D) — BUKAN warisan pasif
root_cause: ""               # diisi saat diagnosed
knowledge_touched: []        # mis. ["business/flows.md"] bila triage cabang-3 koreksi doc
fix_pr: ""                   # diisi saat shipped (oleh ship)
shipped_at: ""               # diisi saat shipped (oleh ship)
reason: ""                   # diisi saat dropped
```

## B. Skema `tasks.yaml` untuk fix

**WAJIB skema yang SAMA** dengan `breakdown` (`${CLAUDE_PLUGIN_ROOT}/skills/breakdown/reference.md` §A) — yaitu **milestone-wrapped** (`milestones[].tasks[]`), supaya hard-guard `build` (iterasi per-milestone) tidak mismatch. JANGAN list task flat.

- **mode post-ship** → tulis ke `control/fixes/<id>/tasks.yaml`: satu milestone `id: FIX`, `title: <slug>`, isi 1–3 task. Task `unit` = app/package dari `fix.yaml.units`. Lintas-unit → tambah task `unit: integration` (roundtrip) + tulis `_shared.md` mini **wajib**.
- **mode in-flight** → **append** task ke `control/features/<fitur>/tasks.yaml` yang sudah ada, ke dalam milestone task `corrects`-nya (atau milestone `FIX` baru bila tak jelas). Tiap task fix bawa field tambahan:

```yaml
- id: fix-<slug>
  kind: fix                  # default task TANPA kind = implicit "feat"; ini penanda korektif
  corrects: <id-task-asal>   # task yang hasilnya meleset (traceability) — boleh kosong utk gap
  observed: "<apa yang menyimpang dari plan/business>"
  unit: <app/pkg>
  files: [ ... ]             # seperti task biasa
  approach: "reproduce dulu (<test>), baru perbaiki"
  test: ["<kasus regresi yang harus lulus>"]
  mockup: <path ke control/fixes/<id>/mockups/ ATAU control/features/<fitur>/mockups/ — ATAU kosong>   # OPSIONAL; diisi HANYA saat visual-defect (§F)
  deps: []
  status: pending
```

`build` memperlakukan `kind`/`corrects`/`observed` sebagai **metadata** (traceability) — tidak mengubah eksekusi. Field **`mockup:`** (opsional, hanya saat visual-defect — §F) **bukan** metadata pasif: `build` menelannya generik (`${CLAUDE_PLUGIN_ROOT}/skills/build/reference.md` §B) → reproduksi-visual + gate eyeball + bobot-3 + model terkuat, **tanpa** perubahan `build`.

## C. Dispatch deltas (semua kerja berat → subagent; konduktor cuma simpan kesimpulan)

1. **Reproduce (subagent).** Dispatch subagent: "tulis SATU test/snapshot yang MERAH menangkap `<gejala>`; jangan perbaiki dulu". Balikan = path test + bukti merah. Test ini jadi `test` di task.
2. **Root-cause (subagent, `systematic-debugging`).** Dispatch subagent investigasi (context-heavy → JANGAN di konduktor): "temukan akar `<gejala>` pakai systematic-debugging; balik 1 paragraf root cause + file/baris". Konduktor simpan ke `root_cause` (post-ship) atau ke `observed`/`approach` task (in-flight).
3. **Implementasi (pinjam `build`).** Setelah task tertulis, eksekusi via `build` (post-ship: work-item `fixes/<id>/`; in-flight: `build` mem-`pick` task baru). Konteks prompt implementer untuk fix WAJIB memuat (eksplisit, jangan diasumsikan): `conventions.md` + pointer file pola + `root_cause` + (post-ship) kutipan `business.md` fitur `relates_to`. Lintas-unit → potongan `_shared.md` mini.

## D. Triage 3-arah + tripwire + sensitivity re-eval

**Tiga kemungkinan** (gate sebelum kerja apa pun):
1. **Kode salah** (perilaku ≠ `business.md`/`plan`) → lanjut lane `fix` (koreksi kode).
2. **Requirement baru** (perilaku diminta tak pernah dispec) → **STOP → `/feature`**.
3. **Doc salah** (kode benar, `business.md`/`flows.md` usang) → **koreksi KNOWLEDGE** (update `business/`, gated + `critic`), catat di `knowledge_touched`. Bila keduanya salah → koreksi kode + knowledge.

**Tripwire eskalasi ke `/feature`** (mekanis, bukan judgment) — STOP bila fix:
- butuh entri BARU di `workspace.yaml.capabilities`, ATAU
- butuh vendor BARU di `control/integrations.md`, ATAU
- menambah `unit` di luar footprint fitur `relates_to` (cek `fanout.md`).

**Sensitivity re-evaluation:** bandingkan rencana/diff fix vs `control/invariants.md` (tenancy/money/idempotency/authz/PII-PCI). Bila fix menyentuh data sensitif yang fitur asal tak punya → set `fix.yaml.sensitivity` sesuai temuan (mis. `payments`/`pii`), walau fitur `relates_to` ber-`sensitivity: []`. Ini yang menyetir Security Gate `ship` (4.5).

## E. Drop (self-handle)

Triage/investigasi = bukan-bug / wontfix / duplikat → `fix` **self-set** `fix.yaml` `status: dropped` + isi `reason`, folder dikeep (memori). **JANGAN** panggil skill `drop` (itu khusus fitur — asumsi `feature.yaml`/promosi capability yang tak relevan untuk fix).
