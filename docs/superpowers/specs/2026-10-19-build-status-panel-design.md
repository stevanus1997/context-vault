# Desain — panel status build (mod Claude Code) + baris progres `drive.sh`

**Tanggal:** 2026-10-19
**Status:** Disetujui user 2026-10-19 → `writing-plans`
**Scope:** mod baru di plugin (`plugin/hooks/` — hooks module + `hooks.json` `modules`) · `plugin/template/.claude/drive.sh` (baris progres + file heartbeat) · test (`plugin/hooks/tests/drive.test.sh` + test mod `*.test.ts`) · `guide/reference.md` · `plugin.json` (versi + deskripsi) · regen `plugin-kimi/` (verifikasi mod TIDAK ikut)
**Mockup acuan:** `.superpowers/brainstorm/34832-1792375338/content/panel-layout-v2.html` + `tree-grouping.html` opsi A (lokal, gitignored; versi ASCII terbaru di §4 yang berlaku)

---

## 1. Masalah

Selama `/build` jalan, nggak ada cara murah buat tahu progresnya.

- **Unattended (`drive.sh`).** Selama `claude -p` jalan, `drive.sh` diam total: cuma ngeprint `[drive] putaran N …` di awal putaran dan satu baris hasil di akhir. Kata user: dia buka `tasks.yaml` manual dan ngitung sendiri satu-satu.
- **Attended.** Waktu orchestrator nunggu subagent, user nanya "sisa berapa lagi task-nya". Itu buang satu giliran chat cuma buat status, dan orchestrator harus baca ulang `tasks.yaml`.

Yang dicari user tiap kali ngecek: **udah task ke berapa**, **task mana yang jalan paralel** (mode lane, maks 1 in-flight per repo), dan gambaran **kira-kira sisa berapa lama**.

## 2. Hasil yang diharapkan

1. **Panel di sesi Claude Code** (mod) yang update sendiri dari file di disk, tanpa manggil model. Dipakai waktu attended, dan waktu unattended bila user membiarkan satu sesi Claude Code nganggur di root produk.
2. **Baris progres di terminal `drive.sh`** yang update di tempat selama `claude -p` jalan. Ini buat unattended tanpa sesi tambahan.
3. Pendukung panel: **status line** satu baris dan **toast** waktu ada yang nyangkut.

Kriteria berhasil:
- User nggak perlu buka `tasks.yaml` lagi buat tahu progres, lane yang jalan, apa yang ketahan, atau gate yang antri.
- User nggak perlu nanya orchestrator soal status.
- Angka di panel, status line, dan `drive.sh` selalu sama untuk state disk yang sama.

## 3. Keputusan desain

| # | Keputusan | Asal |
|---|-----------|------|
| D1 | Dua permukaan: panel mod (attended + sesi nganggur) **dan** baris progres `drive.sh` (unattended). Opsi "perintah status manual" dan "notif HP tiap task" ditolak. | user (pilih A+B) |
| D2 | Mod **masuk plugin context-vault**, bukan mod terpisah. Semua yang install plugin dapet panelnya. | user |
| D3 | **Read-only total.** Panel nggak nulis file apa pun di `control/` dan nggak punya tombol aksi (approve gate dsb.). Gate tetap lewat `/build` (drain pagi) supaya diff + test + `security-critic` nggak kelewat. | user setuju |
| D4 | Layout **B + 3 ubahan** (§4): ringkasan 3 baris di atas, pohon milestone, milestone kelar dilipat jadi satu baris, alasan ketahan nempel di bawah task-nya. | user (pilih dari mockup) |
| D4a | Pohon dikelompokkan **per milestone** (sama kayak `tasks.yaml`), unit di tiap baris task. Bukan per unit×milestone. | rekomendasi desainer, user nanya rekomendasi |
| D5 | **Estimasi sisa waktu** ditampilkan sebagai **rentang** (`sisa ~40–70m`), baru muncul setelah 2–3 task kelar di run ini. Waktu nunggu manusia di gate nggak dihitung. | user setuju |
| D6 | Toast hanya untuk kejadian yang butuh perhatian: task jadi `blocked`/`needs_human` (dengan `hold:`), entri gate baru `queued`, build berhenti (`outcome` done/review/halt). **Bukan** tiap task kelar. | user setuju |
| D7 | Fix (`control/fixes/<id>/tasks.yaml`) tampil dengan cara sama seperti fitur. Fix nggak punya `gates.yaml`, jadi bagian gate kosong/dilewati. | user setuju |
| D8 | Sisa jatah budget per putaran (bobot 10, build reference §D) **tidak** ditampilkan. Angka itu dihitung model dalam kepala dan nggak pernah ditulis ke disk. | dicek; user setuju "kalau nggak ada, buang" |
| D9 | Port Kimi nggak dapet panel (mod = fitur Claude Code saja). `tools/build-kimi.sh` sudah nggak menyalin `plugin/hooks/`, jadi mod otomatis nggak ikut. Ubahan `drive.sh` ada di `template/`, jadi ikut tersalin; itu nggak masalah karena cuma bash. | dicek |

## 4. Isi panel

Contoh di tengah build (data contoh, bukan nyata). Milestone di `tasks.yaml` boleh berisi task dari beberapa unit sekaligus (app, package, `integration`), jadi pohon dikelompokkan **per milestone** dan unit ditulis di tiap baris task:

```
checkout-v2  unattended · putaran 2
███████░░░░░ 7/12  sisa ~40–70m
▸ 2 jalan T8 api · T11 web
⏸ T9 ketahan · nahan T12, T13
◆ 1 gate antri

✓ M1 Fondasi auth         4/4
M2 Checkout  ███░░░░░    3/8
 ✓ T5  api  cart totals service
 ✓ T6  api  session-bound cart
 ✓ T7  web  cart page shell
 ▸ T8  api  checkout endpoint impl 12m
 ⏸ T9  api  migrate orders    needs_human
          migrate destructive — nunggu lo
 ▸ T11 web  cart summary UI   7m
 · T12 web  checkout button   nunggu T9
 · T13 int  checkout roundtrip

◆ G3 api×M2  floor-scan T6 (token)
putaran 1j12m / maks 8j
```

Mendekati akhir, milestone yang kelar udah kelipat semua dan panelnya makin pendek:

```
checkout-v2  unattended · putaran 3
███████████░ 11/12  sisa ~8–15m
▸ 1 jalan T13 integration
◆ 2 gate antri

✓ M1 Fondasi auth         4/4
M2 Checkout  ███████░    7/8
 ▸ T13 int  checkout roundtrip impl 6m

◆ G3 api×M2  floor-scan T6 (token)
◆ G5 web×M2  floor-scan T12 (session)
putaran 2j40m / maks 8j
```

(Di contoh kedua, task `done` di milestone yang belum kelar boleh disembunyikan atau tetap ditampilkan. Itu diserahkan ke builder, asal milestone yang kelar selalu satu baris.)

Aturan isi:

- **Header:** nama work-item (fitur atau fix), mode (`unattended · putaran N` bila `drive.sh` hidup, selain itu `attended`), progress bar `done/total`, estimasi (§6).
- **Ringkasan 3 baris:** `▸ N jalan` (task `in_progress` + unit-nya), `⏸ <task> ketahan` (task `blocked`/`needs_human` + daftar task yang ikut nunggu di belakangnya lewat `deps`, transitif), `◆ N gate antri` (entri `gates.yaml` `status: queued`). Baris yang nol dihilangkan.
- **Pohon milestone:** satu grup per milestone `tasks.yaml` (id + `title`), urut dokumen; task di dalamnya urut dokumen juga, dengan unit di tiap baris (`integration` boleh disingkat `int`). Milestone yang semua task-nya `done` → satu baris `✓ <id> <title> n/n`. Milestone lain menampilkan task dengan ikon status: `✓` done, `▸` in_progress (+ durasi, plus label `impl` hanya bila pasti, §5), `⏸` blocked/needs_human (+ baris `hold:` di bawahnya; tanpa `hold:` → tampilkan `manual:` pertama atau status saja), `·` pending (+ `nunggu <dep>` bila ada dep yang belum done).
- **Gate:** tiap entri `queued`: id, `segment`, `reason`.
- **Footer:** lama putaran / batas maksimal (hanya bila `drive.sh` hidup).

**Status line** (`$.ui.status`): `checkout-v2 7/12 · 2 lane · 1 ketahan · 1 gate · ~40–70m`. Bagian yang nol dihilangkan. Status line dikosongkan bila nggak ada build aktif.

**Toast** (`$.ui.toast`), sekali per kejadian (jangan diulang tiap refresh atau tiap reload mod): `⏸ checkout-v2 · T9 needs_human — migrate destructive, nahan 2 task`.

## 5. Sumber data

Semua dibaca dari disk di root produk (cwd sesi). Nggak ada yang ditulis panel.

| Data | Sumber |
|------|--------|
| status task, `hold:`, `deps`, `unit`, milestone, `commits:` | `control/features/<f>/tasks.yaml`, `control/fixes/<id>/tasks.yaml` |
| status fitur/fix (aktif atau nggak) | `feature.yaml` `status: active` · `fix.yaml` `status: open`/`diagnosed` |
| gate antri | `control/features/<f>/gates.yaml` (`status: queued`) |
| hasil putaran terakhir | `<work-item>/last-run.md` (header mesin: `outcome`, `done`, `pending`, `review`, `blockers`, `reason`) |
| putaran ke-N, mulai jam berapa, batas jam | file heartbeat baru dari `drive.sh` (§7) |
| fase + durasi task yang jalan | scratch `.claude/build/<work-item>/`: `task-<id>-brief.md` ditulis tepat sebelum dispatch; `task-<id>-report.md` ditulis implementer waktu selesai |
| durasi task yang udah kelar (buat estimasi) | mtime brief → waktu commit `head` di `commits:` (lihat catatan di bawah) |

**Fase task yang jalan (dicek ke alur `build`):** re-dispatch setelah review memakai brief yang sama dan cuma meng-APPEND report. Jadi dari disk cuma satu hal yang pasti: brief ada dan report **belum ada** → putaran implement pertama → label `impl`. Begitu report ada, task bisa sedang direview atau sedang di-implement ulang, dan dua-duanya nggak bisa dibedakan dari file. Di kondisi itu tampilkan **durasi saja tanpa label fase**. Jangan menampilkan fase yang salah. (Keputusan desainer; mockup §4 masih menunjukkan label `review`, anggap itu contoh lama.) Builder tetap cek penamaan folder `<work-item>` untuk fix (contoh di reference cuma ada untuk fitur: `.claude/build/auth/…`).

**Durasi task kelar:** waktu commit `head` itu waktu implementer commit, sebelum review. Jadi durasi dari situ sedikit lebih pendek dari kenyataan. Builder boleh pakai sinyal akhir yang lebih baik bila ada, misalnya waktu flip ke `done` yang diamati panel sendiri selagi terbuka dan disimpan di `$.store`. Syaratnya: estimasi tetap jalan walaupun panel baru dibuka di tengah run.

**Kapan work-item dianggap "perlu ditampilkan"** (satu definisi, dipakai panel, status line, dan auto-open §8): manifest aktif (`feature.yaml` `active` · `fix.yaml` `open`/`diagnosed`) **dan** minimal satu dari:
- ada task `in_progress`;
- heartbeat `drive.sh` hidup (§7);
- ada entri `gates.yaml` `queued`;
- ada task `blocked`/`needs_human`.

Jadi pagi setelah `outcome: review` (drive.sh udah mati, nggak ada yang jalan, tapi 2 gate antri + 1 blocker), work-item **tetap tampil**, karena justru itu yang perlu dilihat user. Fitur `active` yang semua task-nya `done` tanpa gate antri, atau yang belum pernah di-build, **nggak** tampil.

**Task `in_progress` yang diam:** bila nggak ada heartbeat hidup dan nggak ada aktivitas file (mtime `tasks.yaml`, isi `.claude/build/<work-item>/`) selama lebih dari N menit, task itu jangan ditampilkan sebagai `▸` dengan durasi yang terus naik. Tampilkan `▸ T8 diam 40m`. Ini nutup dua kasus: sesi yang crash ninggalin `in_progress`, dan build attended yang nunggu jawaban user (approve migrate, NEEDS_CONTEXT) dengan task tetap `in_progress`. N diserahkan ke builder. (Keputusan desainer.) **N = 90 menit** (review akhir): implementer attended baru nulis report waktu selesai, dan di 459 task nyata ~14% punya jeda > 30 menit tanpa tulisan file walau masih kerja.

**Work-item mana yang ditampilkan:** dari yang memenuhi syarat di atas, yang `tasks.yaml`-nya paling baru berubah. Bila lebih dari satu, tambahin satu baris `+N build lain` di bawah header. Nggak ada yang memenuhi → panel bilang nggak ada build, dan status line kosong. (Keputusan desainer.)

**Refresh:** panel baca ulang tiap beberapa detik atau saat file berubah, mana pun yang tersedia di API mod. Pembacaan harus murah, dan nggak boleh memanggil model.

## 6. Estimasi sisa waktu

- **Sampel:** durasi tiap task yang `done` di work-item ini (§5).
- **Bobot:** sama dengan cap-volume build (reference §D): 3 bila ber-`mockup:` ATAU `unit: integration` ATAU `files` > 4; 2 bila `files` 3–4; 1 selainnya. Hitung waktu per poin bobot.
- **Sisa per repo:** jumlah bobot task yang belum `done` di repo itu × waktu per poin, dikurangi waktu yang sudah berjalan untuk task `in_progress` di repo itu. Ambil **repo dengan sisa terbesar**, karena tiap repo cuma jalan satu task sekaligus.
- **Task ketahan:** task `blocked`/`needs_human` dan subtree-nya nggak dihitung ke sisa, karena nunggu manusia. Bila ada, tambahin keterangan pendek, misalnya `+ T9 nunggu lo`.
- **Rentang:** bawah–atas dari sebaran waktu-per-poin sampel. Metode persisnya (misal persentil atau min–max) diserahkan ke builder. Rentang harus melebar kalau sampelnya sedikit atau sebarannya besar.
- **Ambang tampil:** sembunyikan estimasi sampai ada minimal 2–3 sampel `done`. Angka persisnya diserahkan ke builder.
- Waktu nunggu manusia di gate attended otomatis nggak ikut, karena sampelnya durasi per task, bukan jam dinding.

Perkiraan keakuratan (perkiraan desainer, belum diukur): di awal run bisa meleset 2x, setelah sekitar sepertiga task kelar sekitar 30–50%. Yang bikin meleset paling parah: task yang review-nya bolak-balik 2–3 putaran, task berat, dan lane yang nunggu dep lintas-repo (estimasi per-repo nggak mensimulasikan dep antar-repo, jadi cenderung optimistis).

## 7. `drive.sh`

Dua tambahan, keduanya di dalam loop yang sudah ada (`plugin/template/.claude/drive.sh`):

1. **Baris progres selama `claude -p` jalan.** Proses kecil di latar baca state dari disk tiap beberapa detik dan menulis satu baris yang **update di tempat** (`\r`):
   ```
   [drive] putaran 2 · 7/12 · ▸ T8 api, T11 web · ⏸ 1 · ◆ 1 · 1j12m · sisa ~40–70m
   ```
   - Proses latar wajib mati waktu `claude -p` selesai atau `drive.sh` di-Ctrl-C (trap). Baris ditutup dengan newline sebelum output berikutnya, supaya pesan `[drive] outcome=…` nggak tabrakan.
   - Bila stdout bukan TTY (mis. di-redirect ke file log), jangan pakai `\r`. Tulis baris baru hanya saat isinya berubah.
   - Isi dan angka harus **sama** dengan panel (§2 kriteria). Caranya diserahkan ke builder: satu skrip pembaca bersama yang dipanggil `drive.sh` dan panel, atau logika terpisah yang dites terhadap fixture yang sama.
   - Dependensi baru boleh, asal precheck-nya di awal `drive.sh` (pola precheck yang sudah ada: `jq`, allowlist, trust). Kalau nggak ada, tampilkan instruksi lalu exit, jangan diam-diam tanpa baris progres. `drive.sh` saat ini sudah butuh `jq`; parsing YAML butuh sesuatu (mis. `python3`, preseden: skill `share` pakai `python3`).
2. **File heartbeat** di scratch `.claude/build/<fitur>/` (gitignored), berisi: putaran ke-N, waktu mulai `drive.sh`, waktu mulai putaran, `MAX_JAM`, PID `drive.sh`. Ditulis tiap awal putaran dan dihapus waktu `drive.sh` keluar (trap). Panel baca file ini buat header `unattended · putaran N` dan footer lama putaran. Bila file ada tapi PID-nya mati (crash, kill -9), anggap `drive.sh` nggak jalan. Ticker juga men-touch file ini tiap tick; heartbeat yang nggak di-touch > 2 menit dianggap basi, karena sesudah reboot PID-nya bisa dipakai proses lain (review akhir).

Produk lama dapet `drive.sh` baru lewat `/upgrade` yang sudah ada. `upgrade` menampilkan diff dan minta GATE sebelum mengganti file generik plugin (`upgrade/SKILL.md` step "Ada tapi beda"). Nggak ada perubahan di `upgrade`.

## 8. Kapan panel muncul

- Mod membuka panel sendiri hanya waktu ada yang **benar-benar jalan**: task `in_progress` yang nggak diam (§5), atau heartbeat `drive.sh` hidup. Kondisi "cuma nunggu" (gate antri, blocker) nggak membuka panel sendiri; status line dan buka manual sudah cukup. Panel nggak ditutup otomatis.
- Di `claude -p` (headless, termasuk putaran `drive.sh`) mod nggak melakukan apa-apa. Catatan API: panel yang dibuka tanpa diminta baru tampil di lebar ≥144 kolom. Di bawah itu panel nunggu, dan status line jadi andalan.
- Ada slash command buat buka/tutup panel manual. Panel yang diminta user tampil dari ≥110 kolom. Nama command diserahkan ke builder, tapi harus kebaca jelas di namespace plugin.
- Toast dan status line jalan terus walaupun panel ditutup.

(Keputusan builder-level, diambil desainer.)

## 9. Tujuan, non-tujuan, anti-tujuan

**Tujuan:** lihat progres build (attended & unattended) tanpa buka file dan tanpa nanya orchestrator. Jumlah task, lane yang jalan, yang ketahan + alasannya, gate antri, estimasi sisa.

**Non-tujuan:**
- Aksi dari panel (approve/revisi gate, reset task, jalanin build).
- Multiplexer ala herdr (pane per agent, attach ke subagent). Subagent jalan di dalam Claude, bukan terminal terpisah.
- Riwayat lintas fitur, grafik, atau dashboard web.
- Tampilan dari HP atau jarak jauh (`notify.sh` sudah ada untuk itu).
- Panel di Kimi Code.
- Sisa budget per putaran (D8).
- Jaminan akurasi estimasi.

**Anti-tujuan (gagal walaupun "jalan"):**
- Panel, status line, dan `drive.sh` menampilkan angka berbeda untuk state yang sama.
- Panel menulis atau mengubah file apa pun di `control/`, atau mengganggu `build` (lock, race) saat membaca `tasks.yaml` yang sedang ditulis. Pembacaan YAML setengah-tertulis harus ditoleransi: pakai hasil terakhir yang valid, jangan crash dan jangan nampilin kosong.
- Panel memanggil model atau memakan token.
- Toast berisik: diulang tiap refresh, tiap reload mod, atau tiap task kelar.
- Menampilkan fase/estimasi yang yakin padahal salah. Lebih baik dihilangkan daripada bohong.
- Merusak hook yang sudah ada (`auto-title.sh` di `plugin/hooks/hooks.json`) atau build `plugin-kimi/`.
- Membuat Claude Code versi lama yang belum kenal mod jadi error saat memuat plugin.

## 10. Risiko teknis yang wajib dicek builder dulu

1. **`hooks.json` campuran — sudah dicek, aman di 2.1.303.** Salinan `plugin/` di scratch dengan `hooks.json` berisi `hooks` (auto-title) **dan** `modules: ["./register.ts"]` lolos `claude plugin validate` ("Validation passed", module terbaca: `session.start`, `$.ui.status`). Builder tetap pastikan auto-title masih jalan setelah mod ditambah.
2. **Kompatibilitas versi — belum dicek.** Pastikan plugin tetap termuat normal di Claude Code versi lama yang belum punya engine mod (key `modules` diabaikan, bukan error). Uji dengan versi lama yang nyata, bukan asumsi. **Bila versi lama gagal memuat plugin karena `modules`:** jangan paksa versi minimum ke seluruh plugin, karena semua skill ikut hilang di versi lama. Pindahkan mod ke **plugin saudara di marketplace yang sama** (mis. `context-vault-panel`), dan sebut di README + `guide` cara install-nya. Ini menyimpang dari D2 hanya di cabang gagal ini. (Keputusan desainer.)

   **Hasil uji (Task 1):** salinan `plugin/` dengan `hooks.json` = `hooks` (auto-title) + `modules: ["./register.ts"]` (module dummy `session.start` → `$.ui.status`), dibandingkan dengan salinan kontrol tanpa `modules`. Dijalankan lewat `npx @anthropic-ai/claude-code@V` dengan `DISABLE_AUTOUPDATER=1`.
   - **2.1.0 — LULUS.** `plugin validate` → `✔ Validation passed`. `-p "balas persis: ok" --plugin-dir` → `ok`, sama dengan kontrol. Debug log (`~/.claude/debug/*.txt`): `Loaded hooks from standard location for plugin context-vault`, `Registered 1 hooks from 1 plugins`, `Loaded 26 skills`; nol `Failed to load`/`Invalid hooks`.
   - **2.0.77 — LULUS.** Output identik dengan 2.1.0 (validate passed, `ok`, hook auto-title terdaftar, 26 skill).
   - **2.0.30 — LULUS** (titik data tambahan: rilis 2.0 awal yang sudah punya `--plugin-dir`). Validate passed, `ok`, `Registered 1 hooks from 1 plugins`, 26 skill.
   - **1.0.128 — N/A, bukan GAGAL karena `modules`.** Versi 1.0 belum punya sistem plugin: `error: unknown option '--plugin-dir'` **juga untuk salinan kontrol**, dan subcommand `plugin` nggak ada (argumennya dianggap prompt). Plugin ini memang nggak bisa dipasang di 1.0.x, dengan atau tanpa mod.

   Kesimpulan: key `modules` diabaikan tanpa error di semua versi yang bisa memuat plugin. Mod tetap di plugin utama (D2); rencana cadangan plugin saudara nggak dipakai.

   **Koreksi sesudah review akhir:** uji di atas jalan sebelum Task 6 menambah `"types": "./types/index.d.ts"` ke `plugin.json`. Key itu **ditolak** manifest CC lama yang strict (`Unrecognized key: "types"` di 2.0.30, 2.0.77, 2.1.0) dan **seluruh plugin gagal dimuat** (nol skill, nol hook). Key itu dibuang: 2.1.303 tetap menemukan kontrak `types/index.d.ts` lewat lokasi default (`claude plugin validate` → "declares state: context-vault.…"). Matriks diulang atas `plugin/` final: 2.1.0, 2.0.77, 2.0.30 → `plugin validate` passed, `Total plugin skills loaded: 26`, `Registered 1 hooks from 1 plugins`; 2.1.303 → `hooks module context-vault@inline loaded … events: session.start,command.run,ui.render` + auto-title jalan. Penjaga regresi: `tools/tests/manifest.test.sh` (key `plugin.json` ⊆ yang diterima CC lama; versi `marketplace.json` = `plugin.json`).
3. **Mod dari plugin terinstall.** Pastikan hooks module ikut termuat waktu plugin di-install lewat marketplace (`/plugin install`), bukan cuma dari folder dev-mods atau `--plugin-dir`.
4. **Parsing YAML di environment mod.** Mod jalan tanpa Node dan cuma bisa meng-import file milik plugin sendiri. Builder pilih: parser YAML kecil yang dibundel di plugin (cukup untuk subset yang dipakai `tasks.yaml`/`gates.yaml`), atau menjalankan skrip pembaca bersama lewat `$.process` (lihat §7 poin 1).
5. **Sinyal durasi** (§5) diverifikasi terhadap alur `build` nyata. Fase udah dicek (cuma `impl` putaran pertama yang pasti).

## 11. Diserahkan ke builder

- Nama file, struktur modul, nama slash command, interval refresh.
- Satu skrip pembaca bersama vs logika terpisah (dengan syarat angka sama, §7).
- Metode rentang estimasi dan ambang tampil persis (§6).
- Warna dan ikon persis. Mockup jadi acuan, bukan pixel-spec.
- Bentuk test: `drive.test.sh` diperluas untuk baris progres + heartbeat (termasuk non-TTY dan cleanup trap); test mod (`claude plugin test`) untuk perhitungan ringkasan, pohon (lipat milestone, `nunggu <dep>`, subtree ketahan), estimasi (ambang, per-repo), dedup toast, dan toleransi YAML setengah-tertulis; fixture `tasks.yaml`/`gates.yaml`/`last-run.md` dipakai bersama.
- Update `guide/reference.md`, `README.md`, `plugin.json` (bump minor + deskripsi), lalu regen `plugin-kimi/` dan pastikan `build-kimi.test.sh` tetap hijau.
