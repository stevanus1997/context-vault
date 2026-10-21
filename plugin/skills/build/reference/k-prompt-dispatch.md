## K. Bentuk prompt dispatch (controller → subagent)

Controller TIDAK membaca isi template superpowers maupun §B. Path-nya diserahkan ke subagent yang butuh. Artefak bulky lewat file di `<root>/<wi>/`. Tiap subagent membalas sesuai kontrak di bawah.

- **`<wi>`** = folder scratch work-item, persis dari baris `work-item: … · scratch <wi>` ringkasan state (fitur `.claude/build/<fitur>`, fix `.claude/build/fixes/<id>`). Semua path brief/report/review/`_rules` di bawah memakai `<root>/<wi>/`. `<work-item>` = folder `control/` (`control/features/<f>` / `control/fixes/<id>`).
- **`<abs>`** = `${CLAUDE_PLUGIN_ROOT}` (absolut).
- **`<sdd>`** = folder `skills/subagent-driven-development` superpowers terpasang. Read `~/.claude/plugins/installed_plugins.json` SEKALI per run → `installPath` entri `superpowers@…` + `/skills/subagent-driven-development`. Implementer/reviewer membaca template-nya sendiri lewat Read, dan ini butuh allowlist `Read(~/.claude/plugins/cache/**)` + `Read(~/.claude/plugins/installed_plugins.json)` (template `settings.json`). Probe 2026-10-20: tanpa allowlist itu, Read di luar root produk ditolak di `claude -p` headless, baik dari sesi utama maupun subagent. Kalau file tak terbaca, entri absen, atau mode unattended tanpa allowlist itu → hapus baris "Ikuti template" dari prompt. Kontrak ringkas di bawah tetap lengkap tanpanya. Plugin dipasang di luar `~/.claude/plugins` (dev `--plugin-dir`) → tambah `Read(<abs>/**)` sendiri.

**Balikan dikirim SEKALI.** Subagent di-dispatch dengan `name` (bisa dijawab lewat `SendMessage` saat NEEDS_CONTEXT) → ia kirim balikan lewat `SendMessage` ke `main`, lalu teks akhirnya cukup `.`. Tanpa `name` → balikan = teks akhir saja, tanpa `SendMessage`. Alasannya: di CC 2.1.30x `idle_notification` agent bernama ikut membawa teks akhirnya, jadi balikan yang juga dikirim lewat pesan sampai DUA kali (sesi mahjong `6de3fd82`: ~100K karakter duplikat untuk 15 task). Tiap template di bawah memuat baris `Balikan SEKALI (aturan di atas).`.

### Brief-writer (step 3) — `subagent_type: context-vault:brief-writer`
Degrade (c) SKILL step 1 → controller merakit brief sendiri, tanpa brief-writer.
```
Rakit brief task <id> (work-item <work-item>, root <root>).
Aturan isi brief: <abs>/skills/build/reference/b-brief.md
Repo sibuk (baca signature dep & listing dir dari base-SHA ini): <repo>=<base7>, … | none
Tulis brief ke: <root>/<wi>/task-<id>-brief.md
Balikan ≤10 baris sesuai kontrak di file agent-mu. Balikan SEKALI (aturan di atas).
```
Ambiguitas sudah dijawab controller → tambahkan `Jawaban controller: <jawaban>` lalu dispatch ulang. Jawaban ≤2 baris boleh langsung ditambahkan ke brief tanpa membacanya utuh: Read brief `limit: 1` → Edit baris 1 jadi baris 1 + `Jawaban controller: …`. Maks 2 kali dispatch ulang per task. Kalau masih `ambigu:` → attended: tanya user; unattended: `needs_human` + `hold: "NEEDS_CONTEXT: <pertanyaan>"`. `titipan: GAGAL …` → perbaiki `carry.yaml` dulu (SKILL step 1, file rusak), lalu dispatch ulang.

### Implementer (step 3)
```
Baca brief dulu — itu requirement-mu, nilai eksaknya dipakai verbatim:
  <root>/<wi>/task-<id>-brief.md
Ikuti template (baca sendiri): <sdd>/implementer-prompt.md
Pakai test-driven-development. Commit HANYA file task (bukan git add -A). Self-review.
Tulis report detail (apa yang dibangun + bukti test TDD + concern) ke:
  <root>/<wi>/task-<id>-report.md   (ronde fix: APPEND)
Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT (spec kurang → tanya dulu, jangan nebak).
Balikan chat: status + commit SHA + 1 baris hasil test + concern. Balikan SEKALI (aturan di atas).
```
Ronde fix: tambahkan `Temuan review: <root>/<wi>/task-<id>-review-r<n>.md` + SHA/file yang disentuh.

### Task-reviewer (step 4)
```
Ikuti template (baca sendiri): <sdd>/task-reviewer-prompt.md
BRIEF:  <root>/<wi>/task-<id>-brief.md
REPORT: <root>/<wi>/task-<id>-report.md
DIFF:   <root>/<wi>/review-<base7>..<head7>.diff
Global constraints: <invarian/konvensi yang mengikat task>
Aturan baca: baca DIFF SEKALI. Kode di luar diff HANYA untuk risiko konkret yang kamu sebut (nama risiko + apa yang dicek). Klaim REPORT = belum terverifikasi.
OVERRIDE format balikan template: tulis laporan LENGKAP ke <root>/<wi>/task-<id>-review-r<n>.md. Pesan terakhirmu HANYA:
  spec: ✅|❌ <1 baris>
  quality: ✅|❌ (Critical n · Important n · Minor n)
  ⚠️: n
    - <item ⚠️, 1 baris per item>
  catatan: n   (≤5 — temuan Minor/Important yang TIDAK wajib dibereskan di task ini tapi relevan buat kode lain, task lain, simplify, atau ship)
    - <1 baris + file:baris>
  review: <path file review>
Balikan SEKALI (aturan di atas).
```
Tiap `catatan:` diputuskan controller pakai peta: titipan task/gate/simplify/ship (§J), `control/debt.yaml` (pintu ke-4), atau buang. Re-review ronde fix = review penuh dari nol dengan paket diff FRESH (BUKAN `re-review-prompt.md` upstream), cap 3 ronde (SKILL step 4; keputusan desain user).

### Bukti ⚠️ (step 4) — subagent read-only (`Explore`)
```
Task <id>. Item ⚠️ dari reviewer:
  - <item per baris>
Brief: <root>/<wi>/task-<id>-brief.md   Diff: <root>/<wi>/review-<base7>..<head7>.diff   Repo (read-only): <path>
Per item balas 1 baris: <item> → gap nyata | aman — bukti <file:baris>
Alat: Read saja (unattended: grep/find/ls lewat Bash ditolak). Balikan SEKALI (aturan di atas).
```
Keputusan tetap di controller.

### Pre-flight conflict sweep (step 1) — `subagent_type: context-vault:critic`
```
Pre-flight sweep build <work-item>: scan SELURUH <work-item>/tasks.yaml vs control/invariants.md (tenancy/money/idempotency/authz/PII-PCI) + packages[].mandatory_for di control/workspace.yaml. Kumpulkan SEMUA konflik: task yang bakal melanggar invarian, mem-bypass mandatory package, atau saling bentrok.
Balikan: satu baris per konflik — <task> · <invarian/package> · <1 baris>; atau "nol konflik". Balikan SEKALI (aturan di atas).
```

### Konversi legacy `_carry-notes.md` (step 1, attended, sekali) — general-purpose
```
Konversi <root>/<wi>/_carry-notes.md → <root>/<work-item>/carry.yaml (format: <abs>/skills/build/reference/j-state-titipan.md).
Task belum-done: <daftar id dari ringkasan state>. Ambil HANYA baris yang menyebut task itu atau agenda gate/ship/simplify yang belum lewat. Satu entri per titipan (for: boleh list kalau satu catatan berlaku buat beberapa task): from: legacy, at: <hari ini>, id mulai <next dari baris carry: ringkasan state> (terbaru di atas). carry.yaml sudah ada → TAMBAH di atas entri yang ada, jangan timpa. Lalu set key legacy_converted: <hari ini> tepat di bawah header (tanpa itu legacy tetap dibaca). Jangan ubah _carry-notes.md.
Balikan: jumlah entri per target (mis. T75×2 · gate:M6×1 · ship×3). Balikan SEKALI (aturan di atas).
```
