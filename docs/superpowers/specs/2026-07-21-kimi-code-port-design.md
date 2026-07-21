# Design — Port Kimi Code, Fase 1: Core Interaktif (Generator `plugin-kimi/`)

- **Tanggal:** 2026-07-21
- **Status:** Disetujui (brainstorming) → siap plan implementasi
- **Area kena:** `tools/build-kimi.sh` (BARU), `tools/tests/build-kimi.test.sh` (BARU), `plugin-kimi/` (BARU — generated + committed), README (seksi instalasi Kimi Code). **`plugin/` TIDAK disentuh sama sekali — read-only bagi generator.**

---

## 1. Konteks & Masalah

Plugin context-vault berformat plugin Claude Code. Kebutuhan: plugin ini bisa dipakai juga di **Kimi Code CLI** (MoonshotAI; `kimi` 0.28.1 sudah ter-install di mesin) — tanpa risiko sedikit pun ke sisi Claude ("gw takut malah ngerusak plugin buat Claude-nya").

**Hasil riset docs Kimi Code** (www.kimi.com/code/docs, dicek 2026-07-21):

- **Plugin** — manifest `kimi.plugin.json` ATAU `.kimi-plugin/plugin.json` (yang pertama menang bila keduanya ada). Bisa deklarasi skills, hooks, slash commands, MCP, session-init. Env: `KIMI_PLUGIN_ROOT`, `KIMI_CODE_HOME`. Install per-user via `/plugins` (tab Custom; di-copy ke `$KIMI_CODE_HOME/plugins/managed/<id>/`); perubahan butuh `/reload`.
- **Skills** — `SKILL.md` bentuk direktori; frontmatter wajib `name` + `description` (opsional `type`, `whenToUse`, `arguments`, `disableModelInvocation`). Invokasi manual `/skill:<nama> <args>`; model juga bisa auto-invoke dari description. Placeholder body: `${KIMI_SKILL_DIR}` (folder skill saat ini).
- **Hooks** — `[[hooks]]` di `config.toml`; 14 event (UserPromptSubmit, Stop, PermissionRequest, SessionStart, dst); stdin JSON snake_case; exit 0 = allow, 2 = block. **Tidak ada `sessionTitle`.**
- **Sub-agent** — hanya built-in `coder` / `explore` / `plan`; **tidak ada custom agent file** (padanan `agents/*.md` Claude tidak ada).
- **Headless** — `kimi -p "<prompt>"` jalan di policy `auto`: *"no human approval is requested"* — semua tool call di-approve otomatis. Penegakan `[[permission.rules]]` deny di mode ini **belum terverifikasi**.
- **Permission** — `[[permission.rules]]` di config.toml, pattern `Bash(rm -rf*)` (mirip Claude tapi tanpa `:` sebelum `*`), first-match-wins.

**Inventaris ke-Claude-an plugin saat ini:**

- 37× `${CLAUDE_PLUGIN_ROOT}` di ~20 file (skills + rules) — nunjuk `rules/` & `template/`.
- `agents/critic.md` + `agents/security-critic.md` — subagent custom, dispatch dari ~10 skill.
- `hooks/hooks.json` + `auto-title.sh` — bersandar `sessionTitle` UPS yang undocumented (lihat addendum spec auto-title).
- `template/.claude/` — settings.json permissions format Claude, `drive.sh` hardcode `claude -p ... --permission-mode acceptEdits`, on-stop/on-permission hooks.
- Lane unattended M7 — safety model-nya berasumsi rem harness Claude (acceptEdits = auto file-edit doang, Bash tetap tunduk allowlist + deny).
- Frontmatter 24 skill: hanya `name` + `description` → **sudah valid di Kimi apa adanya.**

## 2. Tujuan & Non-Tujuan

**Tujuan (fase 1)**

- Plugin bisa di-install dan **semua 24 skill jalan interaktif** di Kimi Code CLI.
- `plugin/` tetap satu-satunya source of truth; **sisi Claude nol perubahan, nol risiko** — dijamin struktural, bukan kehati-hatian.
- Artefak Kimi (`plugin-kimi/`) ke-commit → installable langsung dari clone tanpa menjalankan generator.
- Rem eksplisit: `build --unattended` di Kimi **ditolak** sampai fase 2 lolos probe.

**Non-Tujuan (fase 2, spec terpisah — lihat D8)**

- **Tidak** porting template produk versi Kimi (`.kimi-code/` permission TOML, hooks TOML).
- **Tidak** bikin `drive.sh` varian Kimi / harness-detect — drive.sh tetap nyetir `claude` doang.
- **Tidak** porting lane unattended — GATED probe empiris deny-rules di `kimi -p`.
- **Tidak** porting hook auto-title — tak ada padanan `sessionTitle` di Kimi; fitur ini Claude-only.
- **Tidak** bikin slash-command wrapper Kimi — invokasi `/skill:<nama>` sudah cukup.
- **Tidak** publikasi ke marketplace Kimi (Official/Third-party) — install Custom/lokal dulu.

## 3. Keputusan Desain (terkunci)

**D1 — Arsitektur generator; `plugin/` read-only.**
`tools/build-kimi.sh`: `rm -rf plugin-kimi/` → copy dari `plugin/` → transformasi → self-check. Regen-dari-nol tiap jalan = idempoten by construction, deterministik. `plugin-kimi/` di-commit, ber-README "GENERATED — jangan edit di sini; edit `plugin/` lalu `bash tools/build-kimi.sh`".
Alternatif ditolak: (a) satu tree netral-harness — 37 titik path jadi prosa rapuh di DUA harness sekaligus; (b) fork/branch — drift pasti.
Jaminan Claude-aman bersifat struktural: Claude Code nge-load plugin dari `"source": "./plugin"` (`.claude-plugin/marketplace.json`) — `plugin-kimi/` & `tools/` invisible baginya; generator cuma MEMBACA `plugin/`; self-check memaksa `git status --porcelain -- plugin/` kosong, kalau tidak → exit 1 keras.

**D2 — Manifest `.kimi-plugin/plugin.json`; versi sync via jq.**
Bentuk `.kimi-plugin/plugin.json` dipilih (mirror layout `.claude-plugin/` — simetri; cukup satu file karena `kimi.plugin.json` tidak kita buat). Field `name`/`description`/`version` diambil dari `plugin/.claude-plugin/plugin.json` via jq → satu sumber versi, mismatch ketangkep test. Skema field lain (deklarasi skills, metadata developer) belum terdokumentasi lengkap → **diverifikasi saat implementasi** terhadap docs + install nyata; acceptance (§6) = hakim; temuan dicatat ke addendum spec (pola addendum auto-title).

**D3 — Rewrite path root: `${CLAUDE_PLUGIN_ROOT}` → `${KIMI_SKILL_DIR}/../..`.**
Berlaku ke semua `.md` hasil copy (skills + rules). `${KIMI_SKILL_DIR}` = placeholder resmi body skill Kimi; `skills/<nama>/` dua level di bawah root plugin → `/../..` = root.
Nuansa sadar: di file yang dibaca runtime via Read (mis. `rules/pr-template.md`), placeholder TIDAK di-substitusi harness — sama persis dengan kondisi hari ini di Claude (model resolve dari konteks karena root absolut sudah diketahui dari body skill). Diuji di acceptance.

**D4 — Adaptasi subagent: `rules/kimi-harness.md` + pointer per-skill.**
Kimi tak punya custom agent file → mapping ditulis generator ke `plugin-kimi/rules/kimi-harness.md`:

| Dispatch di skill | Di Kimi Code |
|---|---|
| subagent `context-vault:critic` | sub-agent `explore` (read-only); prompt = isi `agents/critic.md` (dibaca via Read) + konteks tugas |
| subagent `context-vault:security-critic` | sub-agent `explore`; prompt = isi `agents/security-critic.md` + diff/konteks |
| implementer / worker nulis-kode (build, fix, dst) | sub-agent `coder` |
| reviewer / reader read-only | sub-agent `explore` |

Catatan di file itu: sub-agent Kimi tidak menerima custom system prompt → seluruh isi file agent masuk sebagai bagian prompt tugas.
Injeksi: satu baris tepat di bawah frontmatter (sebelum H1) — "Harness Kimi Code: sebelum dispatch subagent apa pun, baca `${KIMI_SKILL_DIR}/../../rules/kimi-harness.md`." — HANYA di skill yang menyebut subagent (daftar via grep saat generate, bukan hardcode).

**D5 — Rem unattended: banner tolak di copy Kimi skill `build`.**
Generator inject banner tepat di bawah frontmatter `plugin-kimi/skills/build/SKILL.md` (+ catatan satu baris di `build/reference.md`, di heading pertama bagian unattended — cari via grep `unattended`):

> ⛔ HARNESS KIMI CODE — `--unattended` BELUM diporting (fase 2). `kimi -p` auto-approve SEMUA tool; rem allowlist/deny belum terbukti berlaku di mode itu. Kalau user minta `build <fitur> --unattended` di sini: TOLAK, jelaskan alasannya, tawarkan build interaktif biasa atau lane unattended via Claude Code (`bash .claude/drive.sh <fitur>`) di repo yang sama.

Banner dicabut hanya oleh fase 2 (probe lolos). Konsisten dengan drive.sh yang memang cuma manggil `claude` — dua pagar saling nyambung.

**D6 — Yang di-skip / di-copy sadar.**
- `hooks/` **tidak ikut** ke `plugin-kimi/` (auto-title Claude-only; tanpa ini tak ada file mati).
- `.claude-plugin/` **tidak ikut** (digantikan `.kimi-plugin/`).
- `agents/` **ikut apa adanya** — bukan sebagai agent harness, tapi sebagai file prompt yang dibaca via Read (D4).
- `template/` **ikut apa adanya** — init/wire di Kimi tetap scaffold `template/.claude/` + `control/` ke produk. Sadar & disengaja: produk jadi **hybrid** — kerja interaktif bebas di Kimi/Claude (state di disk: `control/`, tasks.yaml, git), lane unattended tetap via Claude (`drive.sh`) di repo yang sama.

**D7 — Namespace invokasi beda, tidak dijembatani.**
Claude: `/context-vault:build x` · Kimi: `/skill:build x`. Perbedaan ini didokumentasikan (README seksi Kimi), bukan di-alias-kan. Referensi antar-skill di body ("jalankan wire", "chain architect") berbentuk prosa nama skill → tetap valid di dua harness.

**D8 — Fase 2 (out of scope, gated probe).**
Protokol probe (murah, config asli tak tersentuh): `KIMI_CODE_HOME` scratch + `[[permission.rules]]` deny pattern jinak (mis. `Bash(touch PROBE*)`) → `kimi -p "jalankan: touch PROBE-1"` → amati ditegakkan/tidak. Plus probe penempatan config level project.
Lolos → spec fase 2: template `.kimi-code/`, drive varian Kimi, cabut banner D5. Gagal → unattended tetap lane Claude selamanya-sampai-Kimi-berubah, dicatat README. Dua-duanya outcome jujur.

## 4. Perilaku (contoh konkret)

```
# Claude Code — TIDAK berubah sedikit pun
/context-vault:build checkout-v2       → jalan seperti biasa

# Kimi Code — baru
kimi                                    → buka sesi di root produk
/skill:guide                            → tur onboarding jalan
/skill:build checkout-v2                → build interaktif; dispatch critic =
                                          sub-agent explore ber-prompt agents/critic.md
/skill:build checkout-v2 --unattended   → DITOLAK (banner D5) + ditawari
                                          interaktif / lane Claude

# Maintenance
vim plugin/skills/build/SKILL.md        → edit source (Claude)
bash tools/build-kimi.sh                → regen; diff cuma di plugin-kimi/
```

## 5. Komponen

```
tools/
├── build-kimi.sh               ← generator (BARU)
└── tests/
    └── build-kimi.test.sh      ← test generator (BARU)
plugin-kimi/                    ← GENERATED + committed (BARU)
├── .kimi-plugin/plugin.json    ← manifest; name/desc/version via jq dari source
├── README.md                   ← "GENERATED — edit di plugin/, lalu regen"
├── skills/…                    ← 24 skill; path di-rewrite (D3), pointer (D4),
│                                  banner di build (D5)
├── rules/…                     ← rewrite path + kimi-harness.md (D4)
├── agents/                     ← copy as-is; dipakai sebagai file prompt
└── template/                   ← copy as-is (produk hybrid, D6)
```

`plugin/` tak berubah; `hooks/` & `.claude-plugin/` tidak ikut ke tree Kimi.

## 6. Testing

**Otomatis — `tools/tests/build-kimi.test.sh`** (pola bash-test seperti `plugin/hooks/tests/auto-title.test.sh`):

1. Generator exit 0.
2. `git status --porcelain -- plugin/` kosong (source untouched).
3. Nol residu string `CLAUDE_PLUGIN_ROOT` di `plugin-kimi/`.
4. Manifest valid JSON (jq) + `version` == versi source plugin.json.
5. Banner D5 ada di `skills/build/SKILL.md`; pointer D4 ada di tiap skill yang match grep `subagent`; `rules/kimi-harness.md` ada.
6. `plugin-kimi/hooks/` dan `plugin-kimi/.claude-plugin/` tidak ada.
7. Jalankan 2× → `diff -r` identik (deterministik).

**Empiris (sekali, fase implementasi, `kimi` 0.28.1):**
Install `plugin-kimi/` via `/plugins` tab Custom → 24 skill kelisting; `/skill:guide` jalan end-to-end; satu alur yang membaca `rules/` via path hasil rewrite terbukti resolve (kandidat murah: guide baca reference, atau ship baca `rules/pr-template.md`). Temuan skema manifest & perilaku placeholder dicatat ke **addendum** spec ini.

**Regresi Claude:** `git status` bersih di `plugin/` (dijamin test #2) + smoke satu skill di Claude Code kalau mau ekstra yakin — tak ada jalur perubahan yang menyentuh sisi Claude.

## 7. Rilis & Propagasi

- Ritual rilis nambah satu langkah: `bash tools/build-kimi.sh` sebelum commit rilis (dicatat di README). Test #4 (version-sync) menjaga kelupaan regen minimal ketahuan saat test jalan.
- Rilis fitur ini: bump minor → 0.21.0.
- README dapat seksi **"Instalasi di Kimi Code"**: cara install via `/plugins` Custom, invokasi `/skill:<nama>`, daftar yang belum tersedia di Kimi (auto-title, unattended — fase 2), pola hybrid produk (D6).

## 8. Risiko & Mitigasi

| Risiko | Mitigasi |
|---|---|
| Skema manifest Kimi beda dari dugaan (docs tak lengkap) | Acceptance install nyata = hakim (D2); generator gampang disesuaikan; temuan → addendum |
| `${KIMI_SKILL_DIR}` tak ke-substitusi di suatu konteks | Acceptance menguji alur baca `rules/` beneran; fallback: rewrite ke prosa "dua level di atas folder skill ini" |
| Description panjang bikin auto-invoke Kimi berisik/salah trigger | Description dibiarkan sama dulu (sudah spesifik + ada frasa trigger); kalau terbukti berisik → `disableModelInvocation`/trim per-skill sebagai tweak lanjutan |
| Orang jalanin unattended di Kimi | Banner tolak D5; drive.sh memang hanya manggil `claude` — dua pagar |
| Drift `plugin/` vs `plugin-kimi/` antar rilis | Regen-dari-nol; test version-sync; ritual rilis di README |
| Generator tak sengaja nulis ke `plugin/` | Self-check porcelain `plugin/` kosong → exit 1 keras (D1, test #2) |
| Edit nyasar langsung di `plugin-kimi/` | README GENERATED di root tree + regen berikutnya menimpa (by design) |

---

## 9. Addendum pasca-implementasi (2026-07-21)

Temuan empiris acceptance `kimi` 0.28.1 (install nyata via `/plugins` tab Custom):

1. **Skema manifest — D2 terkoreksi:** manifest minimal `{name, description, version, author}` DITERIMA (state ok, terdeteksi `kimi-plugin-dir`) TAPI **skills TIDAK auto-discover** — panel `/plugins` menunjukkan `Skills (0)`. Kimi WAJIB deklarasi eksplisit `"skills": "./skills/"` (beda dari Claude Code yang auto-discover folder `skills/`). Fix di generator (commit `72694ed`); sesudahnya panel menunjukkan `Skill instructions: present` + `Skills (1)` — angka itu = jumlah PATH yang dideklarasikan (folder `./skills/`), bukan jumlah skill individual; skill individual muncul di autocomplete `/skill:`.
2. **`skillInstructions` dipakai (di luar rencana D2 minimal):** field manifest Kimi untuk instruksi harness level-plugin — diisi mapping subagent (critic/security-critic → `explore` + prompt dari `agents/*.md`, implementer → `coder`) + penegasan tolak `--unattended`. Preseden: plugin superpowers ter-install di mesin yang sama memakai pola ini dan terbukti jalan. Komplemen (bukan pengganti) pointer D4 + `rules/kimi-harness.md`.
3. **Namespace invokasi:** `/skill:<nama>` (mis. `/skill:guide`) — sesuai asumsi D7; README akurat tanpa perubahan.
4. **Substitusi `${KIMI_SKILL_DIR}`:** terbukti jalan — probe `/skill:ask` di folder produk membaca `rules/kimi-harness.md` via path absolut instalan (`~/.kimi-code/plugins/managed/context-vault/…`). Fallback prosa D3 TIDAK diperlukan.
5. **Smoke:** `/skill:guide` jalan end-to-end; `/skill:ask` jalan di folder produk. Dikonfirmasi user di terminal.
6. **Catatan operasional:** install Kimi = COPY ke `$KIMI_CODE_HOME/plugins/managed/<id>/` — perubahan di `plugin-kimi/` repo TIDAK otomatis kebawa; user perlu `/plugins` → Update (atau reinstall) + `/reload` tiap kali artefak di-regen.
