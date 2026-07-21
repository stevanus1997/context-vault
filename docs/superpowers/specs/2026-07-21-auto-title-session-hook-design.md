# Design — Auto-Title Session via Hook Plugin (`UserPromptSubmit`)

- **Tanggal:** 2026-07-21
- **Status:** Disetujui (brainstorming) → siap plan implementasi
- **Area kena:** `plugin/hooks/hooks.json` (BARU), `plugin/hooks/auto-title.sh` (BARU), `plugin/.claude-plugin/plugin.json` (bump versi saat rilis). **Template produk (`plugin/template/`) TIDAK disentuh** — hook hidup di level plugin, bukan di scaffolding produk.

---

## 1. Konteks & Masalah

Feedback nyata dari pengguna plugin: session Claude Code di picker `/resume` susah dibedain. Sejak Claude Code v2.1.196 session yang gak dinamain dapet nama auto-generated kayak `my-app-3f` — gak nunjukin lagi ngerjain apa. Akibatnya user harus `/rename` manual tiap session, atau nebak-nebak session mana yang isinya build fitur X.

Padahal di alur context-vault, hampir semua session dimulai dari invokasi skill yang udah bawa konteksnya sendiri: `/build checkout-v2`, `/fix bug-otp`, `/ship checkout-v2`. Informasi buat judul yang bagus **sudah ada di prompt pertama** — tinggal dipanen.

Mekanisme resminya tersedia: hook `UserPromptSubmit` (dan `SessionStart`) boleh nge-return `hookSpecificOutput.sessionTitle` dan Claude Code langsung rename session-nya. Plugin juga boleh ship hook sendiri via `hooks/hooks.json` di root plugin — aktif otomatis di semua project yang enable plugin.

## 2. Tujuan & Non-Tujuan

**Tujuan**
- Session otomatis ke-judul dari skill context-vault yang dipanggil — `/build checkout-v2` → judul `build: checkout-v2` — tanpa aksi user.
- Propagasi gratis: user cukup update plugin. Tanpa `/upgrade` per produk, tanpa nyentuh `.claude/settings.json` produk.
- Judul selalu nunjukin kerjaan **terakhir** (last-skill-wins).

**Non-Tujuan (YAGNI)**
- **Tidak** nge-judul invokasi natural-language ("kerjain checkout-v2" → model manggil Skill tool sendiri). Gak ada jalur hook yang support `sessionTitle` buat kasus itu; slash-only adalah batasan yang disengaja.
- **Tidak** pake hook `SessionStart` buat deteksi "user udah namain session". Nama auto-generated (`my-app-3f`) gak bisa dibedain dari nama manual — salah deteksi bikin fitur mati total. Lebih baik gak deteksi daripada deteksi salah.
- **Tidak** ngedit file transcript `.jsonl` atau index session di `~/.claude/projects/` — format internal, gak disupport.
- **Tidak** nge-judul dari skill read-only (`/ask`, `/guide`, `/render-docs`, `/debt`) — side question pas lagi build gak boleh nimpa judul kerjaan.
- **Tidak** nambah opsi konfigurasi (on/off, format kustom) di v1 — tunggu feedback.

## 3. Keputusan Desain (terkunci)

**D1 — Penempatan: level plugin, bukan template produk.**
`plugin/hooks/hooks.json` + `plugin/hooks/auto-title.sh`, path script via `${CLAUDE_PLUGIN_ROOT}`. Alternatif yang ditolak: hook di `plugin/template/.claude/settings.json` (kayak `on-stop.sh`) — butuh `/upgrade` per produk lama, propagasi lambat, dan fitur ini sifatnya per-plugin bukan per-produk.

**D2 — Event: `UserPromptSubmit` doang.**
Satu-satunya event yang (a) fire tiap prompt user dan (b) support output `sessionTitle`. `UserPromptExpansion` liat args mentah tapi gak support `sessionTitle`; `SessionStart` ditolak (lihat Non-Tujuan).

**D3 — Whitelist & format judul.**

| Kategori | Skill | Judul |
|---|---|---|
| Kerja + argumen | `feature` `intake` `fanout` `plan` `breakdown` `build` `fix` `tweak` `ship` `drop` `add-app` `add-package` `add-integration` | `<skill>: <args>` (args full, truncate 48 char + `…`) |
| Kerja tanpa argumen | `init` `architect` `wire` `design-system` `extract` `upgrade` `discovery` | `<skill>` |
| Read-only / di luar whitelist | `ask` `guide` `render-docs` `debt` + semua non-context-vault | judul TIDAK disentuh (exit 0 diam) |

Aturan seragam: judul = nama skill + (`: ` + args kalau ada). Skill ber-argumen yang dipanggil tanpa argumen (mis. `/build` doang buat resume) → judul nama skill doang.

**D4 — Last-skill-wins.**
Tiap invokasi skill whitelist nge-set ulang judul. `/feature x` → `/breakdown x` → `/build x` → judul akhir `build: x`. Session di `/resume` keliatan dari kerjaan terakhirnya.

**D5 — Manual `/rename`: dua tingkat, diverifikasi empiris.**
- **Tingkat 1 (kalau `/rename` observable oleh hook):** `auto-title.sh` deteksi prompt `/rename <nama>` → tulis lock-file per-session di `~/.claude/context-vault/session-locks/<session_id>`. Skill kerja berikutnya cek lock → skip. Nama manual user bertahan.
- **Tingkat 2 (kalau `/rename` built-in TIDAK lewat hook):** degradasi jujur — nama manual bertahan **sampai** skill kerja berikutnya dipanggil; dicatet sebagai known caveat di README.
- Mana yang berlaku ditentukan **satu langkah verifikasi empiris** di fase implementasi (logging hook sekali jalan). Input `UserPromptSubmit` TIDAK bawa judul session saat ini, jadi gak ada cara langsung ngecek "udah di-rename belum".
- Lock-file: mkdir -p idempoten, prune opportunistik file >30 hari biar gak numpuk.

**D6 — Parsing: tag expansion dulu, fallback regex mentah.**
Hook nerima prompt yang **sudah di-expand** — invokasi slash command muncul sebagai tag `<command-name>` / `<command-args>` di dalam prompt. Urutan parsing:
1. Ekstrak `<command-name>` + `<command-args>` dari prompt.
2. Fallback: prompt mentah berpola `^/<skill> <args>` (jaga-jaga beda versi Claude Code / hook nerima bentuk mentah).
3. Normalisasi nama skill: buang prefix `context-vault:` dan leading `/`.
Dua-duanya gagal → bukan invokasi skill → exit 0 diam.

**D7 — Aman & gak ganggu.**
- Output JSON dibangun pake `jq` (escape kutip/newline di args aneh kayak `/tweak naikin fee "admin"`).
- Script **selalu exit 0** — kegagalan parsing/lock gak boleh mblokir prompt user.
- Dependensi: `bash` + `jq` (sama kayak hook template yang sudah ada).

**D8 — Prasyarat versi.**
Field `sessionTitle` di output hook itu fitur Claude Code era v2.1.19x+. Di versi lama hook-nya no-op aman (output diabaikan). Dicatet di README.

## 4. Perilaku (contoh konkret)

```
09:00  /feature checkout-v2      → "feature: checkout-v2"
10:30  /breakdown checkout-v2    → "breakdown: checkout-v2"
13:00  /build checkout-v2        → "build: checkout-v2"
13:40  /ask status produk        → (tetap "build: checkout-v2")
14:00  /fix bug-otp              → "fix: bug-otp"
15:00  /rename eksperimen-gw     → "eksperimen-gw" (+ lock, kalau Tingkat 1)
15:10  /tweak fee-admin          → Tingkat 1: tetap "eksperimen-gw"
                                    Tingkat 2: jadi "tweak: fee-admin" (caveat)
16:00  /wire                     → "wire" (atau tetap ke-lock di Tingkat 1)
       /tweak naikin fee admin jadi 5rb per transaksi biar nutup ongkos
                                 → "tweak: naikin fee admin jadi 5rb per transaksi bi…"
```

## 5. Komponen

```
plugin/
├── hooks/
│   ├── hooks.json        ← registrasi UserPromptSubmit → auto-title.sh
│   └── auto-title.sh     ← parse → whitelist → lock-check → emit sessionTitle
```

`hooks.json` schema-nya identik dengan key `"hooks"` di settings.json, command pake `"${CLAUDE_PLUGIN_ROOT}/hooks/auto-title.sh"`.

## 6. Testing

- **Unit (otomatis):** test script yang feed contoh stdin JSON ke `auto-title.sh` dan assert stdout — kasus: skill+args, skill tanpa args, args panjang (truncate), args ber-kutip/newline, skill read-only (silent), prompt biasa (silent), bentuk `context-vault:build`, bentuk mentah `/build x`, `/rename` (lock) + invokasi setelah lock.
- **Empiris (sekali, fase implementasi):** hook logging sementara buat mastiin (a) bentuk persis prompt expansion di `UserPromptSubmit`, (b) apakah `/rename` built-in lewat hook. Hasilnya nge-lock D5 Tingkat 1 vs 2 dan bisa nyesuaikan regex D6.
- **Smoke manual:** enable plugin lokal → `/build coba-x` → cek judul di prompt bar + `/resume`.

## 7. Rilis & Propagasi

- Bump `plugin.json` versi → 0.19.0, sebut fitur di description/README (termasuk caveat D5 Tingkat 2 kalau itu yang berlaku + prasyarat versi Claude Code).
- Propagasi otomatis ke semua pengguna saat update plugin. Nol perubahan di sisi produk.

## 8. Risiko & Mitigasi

| Risiko | Mitigasi |
|---|---|
| Format expansion prompt beda antar versi Claude Code | Parsing dua lapis (D6) + verifikasi empiris; gagal parse = no-op aman |
| `/rename` gak observable → judul manual ketimpa | Degradasi jujur Tingkat 2 + caveat terdokumentasi (D5) |
| Args aneh ngerusak JSON output | `jq` buat escape (D7) |
| Hook error mblokir prompt user | selalu exit 0, gak pake `decision: block` (D7) |
| Claude Code lama gak kenal `sessionTitle` | field diabaikan, no-op aman (D8) |
