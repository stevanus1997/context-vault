## K. Bentuk prompt dispatch (controller → subagent)

Controller TIDAK membaca isi template superpowers maupun §B. Path-nya diserahkan ke subagent yang butuh. Artefak bulky lewat file di `<root>/.claude/build/<work-item>/`. Tiap subagent membalas sesuai kontrak di bawah.

**`<sdd>`** = folder `skills/subagent-driven-development` superpowers terpasang. Resolve SEKALI per run pakai tool **Glob** (bukan Bash, karena path plugin-cache bernomor versi tak bisa di-allowlist): `path` = `~/.claude/plugins/cache` (HOME user), pattern `*/superpowers/*/skills/subagent-driven-development/implementer-prompt.md`, lalu ambil versi tertinggi. Tidak ketemu (atau harness tanpa tool Glob) → hapus baris "Ikuti template" dari prompt. **Unattended:** jangan resolve `<sdd>`; hapus baris "Ikuti template" dari prompt (probe 2026-10-20: Read & Glob plugin-cache dari subagent ditolak di `claude -p` headless). Kontrak ringkas di bawah tetap lengkap tanpanya. **`<abs>`** = `${CLAUDE_PLUGIN_ROOT}` (absolut).

### Brief-writer (step 3) — `subagent_type: context-vault:brief-writer`
```
Rakit brief task <id> (work-item <work-item>, root <root>).
Aturan isi brief: <abs>/skills/build/reference/b-brief.md
Repo sibuk (baca signature dep dari base-SHA ini): <repo>=<base7>, … | none
Tulis brief ke: <root>/.claude/build/<work-item>/task-<id>-brief.md
Balikan ≤10 baris sesuai kontrak di file agent-mu.
```
Ambiguitas sudah dijawab controller → tambahkan `Jawaban controller: <jawaban>` lalu dispatch ulang.

### Implementer (step 3)
```
Baca brief dulu — itu requirement-mu, nilai eksaknya dipakai verbatim:
  <root>/.claude/build/<work-item>/task-<id>-brief.md
Ikuti template (baca sendiri): <sdd>/implementer-prompt.md
Pakai test-driven-development. Commit HANYA file task (bukan git add -A). Self-review.
Tulis report detail (apa yang dibangun + bukti test TDD + concern) ke:
  <root>/.claude/build/<work-item>/task-<id>-report.md   (ronde fix: APPEND)
Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT (spec kurang → tanya dulu, jangan nebak).
Balikan chat: status + commit SHA + 1 baris hasil test + concern.
```
Ronde fix: tambahkan `Temuan review: <root>/.claude/build/<work-item>/task-<id>-review-r<n>.md` + SHA/file yang disentuh.

### Task-reviewer (step 4)
```
Ikuti template (baca sendiri): <sdd>/task-reviewer-prompt.md
BRIEF:  <root>/.claude/build/<work-item>/task-<id>-brief.md
REPORT: <root>/.claude/build/<work-item>/task-<id>-report.md
DIFF:   <root>/.claude/build/<work-item>/review-<base7>..<head7>.diff
Global constraints: <invarian/konvensi yang mengikat task>
Aturan baca: baca DIFF SEKALI. Kode di luar diff HANYA untuk risiko konkret yang kamu sebut (nama risiko + apa yang dicek). Klaim REPORT = belum terverifikasi.
OVERRIDE format balikan template: tulis laporan LENGKAP ke <root>/.claude/build/<work-item>/task-<id>-review-r<n>.md. Pesan terakhirmu HANYA:
  spec: ✅|❌ <1 baris>
  quality: ✅|❌ (Critical n · Important n · Minor n)
  ⚠️: n
    - <item ⚠️, 1 baris per item>
  review: <path file review>
```
Re-review ronde fix = review penuh dari nol dengan paket diff FRESH (BUKAN `re-review-prompt.md` upstream), cap 3 ronde (SKILL step 4; keputusan desain user).

### Bukti ⚠️ (step 4) — subagent read-only (`Explore`)
```
Task <id>. Item ⚠️ dari reviewer:
  - <item per baris>
Brief: …-brief.md   Diff: …/review-<base7>..<head7>.diff   Repo (read-only): <path>
Per item balas 1 baris: <item> → gap nyata | aman — bukti <file:baris>
```
Keputusan tetap di controller.

### Pre-flight conflict sweep (step 1) — `subagent_type: context-vault:critic`
```
Pre-flight sweep build <work-item>: scan SELURUH <work-item>/tasks.yaml vs control/invariants.md (tenancy/money/idempotency/authz/PII-PCI) + packages[].mandatory_for di control/workspace.yaml. Kumpulkan SEMUA konflik: task yang bakal melanggar invarian, mem-bypass mandatory package, atau saling bentrok.
Balikan: satu baris per konflik — <task> · <invarian/package> · <1 baris>; atau "nol konflik".
```

### Konversi legacy `_carry-notes.md` (step 1, attended, sekali) — general-purpose
```
Konversi <root>/.claude/build/<work-item>/_carry-notes.md → <work-item>/carry.yaml (format: <abs>/skills/build/reference/j-state-titipan.md).
Task belum-done: <daftar id dari ringkasan state>. Ambil HANYA baris yang menyebut task itu atau agenda gate/ship/simplify yang belum lewat. Satu entri per titipan: from: legacy, at: <hari ini>, id C1.. (terbaru di atas). Jangan ubah _carry-notes.md.
Balikan: jumlah entri per target (mis. T75×2 · gate:M6×1 · ship×3).
```
