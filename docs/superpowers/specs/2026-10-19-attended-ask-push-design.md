# Desain — Titik tunggu attended lewat `AskUserQuestion` (push native Remote Control)

**Tanggal:** 2026-10-19
**Status:** Draf (menunggu review user → `writing-plans`)
**Scope:** `plugin/rules/ask-user.md` (BARU) · `plugin/rules/elicitation.md` (pointer) · semua `plugin/skills/*/SKILL.md` + `reference.md` yang bertanya ke user di mode attended · `guide` (cheatsheet) · `README.md` · `tools/build-kimi.sh` (mapping `kimi-harness.md`) · regen `plugin-kimi/`

---

## 1. Masalah

User sekarang kebanyakan menyetir sesi Claude Code lewat **Remote Control** dari HP. Di mode attended, skill sering berhenti nunggu jawaban user. Yang paling sering adalah pipeline `feature` (`intake` → `fanout` → `plan`) dan `build`. Bentuk tunggunya ada tiga: gate "approve/revisi?", Q&A keputusan, dan permission prompt.

Nggak ada yang ngabarin. Akibatnya user ngecek HP kira-kira tiap 5 menit, *"ocd gtu tiap 5 mnit ngecek apakah ada yang butuh confirm gw apa engga"*.

Mekanisme notif yang sudah ada (`notify.sh` + hook `on-stop.sh`/`on-permission.sh`, `build/reference.md` §G) **sengaja diam di attended**. Dua hook itu cuma jalan kalau ada penanda `.unattended`.

## 2. Temuan (dokumentasi Claude Code, dicek 2026-10-19)

- **Remote Control punya push native ke app Claude.** Di `/config` ada dua toggle. **Push when actions required** mengirim push untuk *"permission prompts and questions"*. **Push when Claude decides** mengirim push kapan pun model memutuskan, jadi tidak dijamin. Push di-skip selama user mengetik di, atau fokus ke, terminal yang terhubung. Sumber: https://code.claude.com/docs/en/remote-control#mobile-push-notifications
- **Dialog yang diteruskan Remote Control** (permission prompt dan `AskUserQuestion`) tetap terbuka sampai dijawab, tanpa timeout. Sumber: https://code.claude.com/docs/en/remote-control#limitations
- **Hook tidak bisa mengirim push ke app Claude.** `PushNotification` adalah tool model, bukan aksi hook. Hook cuma bisa memanggil kanal milik user sendiri (`notify.sh`).
- **Semua titik tunggu skill context-vault saat ini berupa teks biasa yang diikuti akhir turn.** Hasil grep: nol pemakaian `AskUserQuestion` di `plugin/skills`. Karena itu toggle "actions required" tidak menangkapnya. Yang tertangkap hanya permission prompt.
- **Tidak ada skill yang membatasi tool lewat `allowed-tools`** (grep: nol). `AskUserQuestion` sudah tersedia di semua skill.

## 3. Hasil yang diharapkan

Di mode attended, tiap kali skill butuh jawaban user untuk lanjut, HP user bunyi lewat push app Claude (dengan toggle aktif). User tap notif dan langsung menjawab di dialog.

Kriteria berhasil:
- Gate dan Q&A keputusan di `feature`/`build` (dan skill lain) memicu push tanpa user ngecek manual.
- Konten yang harus dibaca sebelum memutuskan tetap kebaca utuh (draft `business.md`, plan, ringkasan diff, Challenge Checklist).
- Jalur jawaban bebas (catatan revisi, "versi gw sendiri") tetap ada.
- Perilaku unattended/headless tidak berubah sama sekali.

## 4. Keputusan (dari brainstorming)

| # | Keputusan | Asal |
|---|-----------|------|
| D1 | Kanal = **push native app Claude**: titik tunggu memakai `AskUserQuestion`, dan user menyalakan toggle **Push when actions required** di `/config` (aksi user sekali, bukan di-ship plugin). | User memilih "AskUserQuestion dl deh" |
| D2 | **Plan B ditunda:** hook `Stop` → `notify.sh` di attended. Plan B dipakai HANYA kalau nanti kotak `AskUserQuestion` sering menutupi penjelasan. Plan B itu spec terpisah. | User: *"nnti klo suka penjelasan nya gk ke baca gw baru minta pke hook stop"* |
| D3 | Cakupan titik tunggu = **gate approve/revisi + Q&A keputusan (elicitation) + konfirmasi lain** yang membuat skill berhenti nunggu jawaban. | User: *"bolej pke kotak pertanyaan juga"* (untuk Q&A) |
| D4 | Cakupan skill = **semua skill** yang bertanya ke user di attended, bukan cuma `feature`/`build`. | Playback disetujui user ("lgtm") |
| D5 | Push boleh bunyi walau user sedang di depan laptop. (Push native memang di-skip saat terminal fokus, dan itu juga OK.) | User: *"gpp, bunyi aja tiap butuh confirm"* |
| D6 | **Konten panjang ditulis sebagai teks biasa DULU, baru kotak pertanyaan muncul berisi pertanyaan pendek.** Tujuannya mengurangi bug "penjelasan ketutupan kotak" yang pernah user alami. | Playback disetujui user |
| D7 | Unattended/headless **tidak berubah**: tetap tidak pernah bertanya, dan jalur `notify.sh`/hook tetap seperti sekarang. | Playback disetujui user |
| D8 | Aturan **terpusat di satu file** `plugin/rules/ask-user.md` yang dirujuk tiap skill, mengikuti pola rujukan `rules/elicitation.md`. | Keputusan Claude, disetujui di playback |
| D9 | Versi Kimi: kalau Kimi Code tidak punya tool yang setara, fallback-nya bertanya dengan teks biasa. | Keputusan Claude, disetujui di playback |
| D10 | **`discovery` dan `init` dikecualikan**: dua skill itu tidak disentuh dan tetap bertanya dengan teks biasa (tanpa push). Alasannya, `discovery` sengaja elicit-first (operator cerita bebas, AI baru mengusulkan isi kalau operator bilang "gak tau/terserah" → `AI-usul`, rombakan 2026-07-22). Sebelum `init` belum ada knowledge atau kode untuk bahan tebakan, jadi opsi akan mengarang dan menyetir jawaban. | User: *"discovery/init di kecualikan aja"* |

## 5. Kontrak aturan `rules/ask-user.md` (draf isi)

Berlaku di **mode attended**, setiap kali skill butuh jawaban atau keputusan user untuk melanjutkan.

1. **Pakai `AskUserQuestion`. Jangan mengakhiri turn dengan pertanyaan teks.** Turn yang berakhir dengan pertanyaan teks tidak memicu push native, jadi user tidak tahu ada yang nunggu.
2. **Urutan: konten dulu, kotak belakangan.** Di turn yang sama, tulis dulu semua yang perlu dibaca sebagai teks biasa (artifact/draft, ringkasan diff, Challenge Checklist, tradeoff panjang). Sesudah itu baru panggil `AskUserQuestion`. Teks pertanyaan di kotak dibuat pendek dan merujuk konten di atasnya, misalnya *"Approve draft business.md di atas?"*. Kotak tidak boleh mengulang atau menggantikan konten.
3. **Gate approve/revisi.** Minimal ada opsi **Approve** dan **Revisi**. `description` tiap opsi berisi konsekuensinya, misalnya "Approve → tulis business.md, lanjut ke fanout". Catatan revisi masuk lewat "Other", yang disediakan otomatis oleh tool. Opsi khas skill boleh ditambah (mis. Drop/Regen) selama totalnya tetap 2–4.
4. **Q&A keputusan (isi tetap diatur `elicitation.md`):**
   - Satu keputusan-bercabang = satu panggilan dengan satu pertanyaan.
   - Opsi berjumlah 2–4, dengan `description` = 1 baris konsekuensi. Ini memenuhi aturan "opsi bawa konsekuensi".
   - "Other" berfungsi sebagai jalan keluar dari menu (aturan "ceritain versimu sendiri").
   - Jangan pakai label "(Recommended)" untuk keputusan berdampak tinggi atau ireversibel.
   - Konfirmasi sepele boleh digabung, sampai 4 pertanyaan dalam satu panggilan.
5. **Pertanyaan terbuka** (deskriptif, mis. "ceritain alurnya"): susun 2–4 tebakan dari knowledge/kode sebagai opsi, ditambah "Other" untuk versi user. Fallback ke pertanyaan teks hanya boleh kalau benar-benar tidak ada tebakan yang bermakna. Konsekuensinya: tanpa push. *(Keputusan Claude.)* Aturan ini tidak berlaku di `discovery`/`init` (D10), karena kedua skill itu dikecualikan dari seluruh aturan.
6. **Batas tool:**
   - 1–4 pertanyaan per panggilan, 2–4 opsi per pertanyaan.
   - `header` maksimal 12 karakter.
   - Pakai `multiSelect` kalau pilihannya tidak saling eksklusif.
   - Jangan membuat opsi "Lainnya/Other" sendiri, karena sudah otomatis.
7. **Bukan titik tunggu → teks biasa.** Laporan selesai yang tidak menunggu keputusan tetap ditulis sebagai teks biasa. Tapi kalau laporan itu diakhiri pertanyaan ("lanjut `/ship`?"), pertanyaannya masuk kotak.
8. **Subagent tidak memanggil `AskUserQuestion`.** Implementer, reviewer, dan critic mengembalikan pertanyaan ke controller, sesuai pola yang sudah ada (mis. `build` step 3, "subagent balik nanya").
9. **Unattended/headless: dilarang.** Aturan "JANGAN PERNAH nanya interaktif" di `build` tetap berlaku. Pertanyaan jadi entri `queued`/`hold:` seperti sekarang.

## 6. Cakupan perubahan

- **BARU `plugin/rules/ask-user.md`**: isi sesuai §5.
- **`plugin/rules/elicitation.md`**: satu pointer. Penyajian pertanyaan (kanal/format) diatur `ask-user.md`, sedangkan isi/kontrak Q&A tetap di file ini. Seksi "Gate ≠ interogasi" tetap berlaku: memakai kotak tidak mengubah gate jadi tanya-jawab beruntun.
- **Dikecualikan: `discovery` dan `init`** (D10). Kedua skill itu tidak menerima rujukan `ask-user.md`, dan alur tanyanya tidak diubah. `ask-user.md` menyebut pengecualian ini secara eksplisit, supaya skill yang di-chain dari situ (mis. `discovery` → `roadmap`) tetap jelas: skill hasil chain mengikuti aturannya sendiri.
- **Semua skill lain yang bertanya ke user di attended**: tambahkan rujukan `${CLAUDE_PLUGIN_ROOT}/rules/ask-user.md`, dengan pola sama seperti rujukan `elicitation.md` (mis. `intake/SKILL.md:29`). Selaraskan juga frasa gate yang eksplisit ("minta approve/revisi", "tunggu approve", "GATE: tampilkan → approve") supaya tidak bertentangan dengan aturan. Daftar skill dienumerasi builder lewat grep. Saat desain ditulis, ada 24 `SKILL.md` yang menyebut gate/approve/tanya/Q&A, ditambah `reference.md` yang memuat gate (mis. `build/reference.md` §I drain pagi, `wire/reference.md`, `design-system/reference.md`, `breakdown/reference.md`). Skill yang read-only dan tidak pernah menunggu keputusan (`ask` saat menjawab biasa) tidak perlu disentuh, kecuali ada titik di mana skill itu berhenti nunggu jawaban.
- **`build` drain pagi (§I)**: satu gate `queued` = satu panggilan, dengan konten gate itu (segmen, reason, ringkasan diff) ditulis dulu. Gate jangan digabung 4-sekaligus, karena tiap gate punya konten sendiri yang harus dibaca. *(Keputusan Claude.)*
- **`guide`**: tambahkan tip di cheatsheet/FAQ. Untuk dikabari di HP saat attended, nyalakan **Push when actions required** di `/config` (butuh app Claude login di akun yang sama dan izin notif OS).
- **`README.md`**: satu baris tip yang sama.
- **Kimi (`tools/build-kimi.sh`)**: `rules/` sudah ikut di-copy apa adanya. Tambahkan satu baris di `kimi-harness.md` hasil generate, dengan isi: `AskUserQuestion` → padanan Kimi Code kalau ada (builder memverifikasi di docs Kimi Code), kalau tidak ada → bertanya dengan teks biasa. Regen `plugin-kimi/` dan pastikan `tools/tests/build-kimi.test.sh` hijau.
- **Skill `share`** (baru, landed di `9ee57b4`) ikut cakupan D4. Titik tunggunya: pilih fitur saat nama tak diberikan → kotak (daftar fitur sebagai opsi). Paste feedback rekan saat triase itu input bebas, bukan keputusan, jadi tetap teks biasa sesuai aturan 5 (fallback). Keputusan triase per masukan → kotak. *(Keputusan Claude.)*
- **Basis plan**: `main` sesudah `9ee57b4` (Task 5 `share` sudah ter-commit). Anchor old/new plan diambil dari tree saat itu.
- **Rilis**: satu bump di akhir plan ini, dari versi yang tercatat di `plugin/.claude-plugin/plugin.json` saat eksekusi. Waktu desain ditulis versinya masih `0.24.0`, dan plan `share` tidak punya task bump. Kalau `share` sudah di-bump terpisah duluan, bump ini naik dari situ. Pola `chore(release): bump …` + regen Kimi. *(Keputusan Claude.)*

## 7. Non-goals

- Hook `Stop` → `notify.sh` di attended (Plan B, D2).
- Mengubah hook, `notify.sh`, `drive.sh`, atau perilaku unattended apa pun.
- Men-ship setting toggle push di template produk. Toggle itu per-user/per-perangkat dan butuh registrasi app. *(Keputusan Claude.)*
- Skill memanggil `PushNotification` sendiri.

## 8. Anti-goals (gagal walau secara teknis jalan)

- Kotak pertanyaan menutupi konten yang harus dibaca sebelum memutuskan.
- Run headless beku karena ada `AskUserQuestion`.
- Jalur jawaban bebas hilang, sehingga user dipaksa memilih opsi yang tidak pas.
- Gate berubah jadi interogasi beruntun (melanggar "Gate ≠ interogasi").
- Muncul label "(Recommended)" di keputusan berdampak tinggi (melanggar `elicitation.md`/`anti-yes-man.md`).

## 9. Verifikasi

- **Cakupan (grep):** tiap skill yang punya titik tunggu attended (kecuali `discovery`/`init`) merujuk `rules/ask-user.md`, `discovery`/`init` tidak berubah, dan tidak ada sisa instruksi yang menyuruh mengakhiri turn dengan pertanyaan teks di jalur attended.
- **Kimi:** `bash tools/tests/build-kimi.test.sh` hijau setelah regen.
- **Smoke manual oleh user:**
  1. Di produk nyata, dengan toggle aktif, jalankan `/tweak` atau `/feature` lewat Remote Control.
  2. Cek HP bunyi di gate.
  3. Cek konten di atas kotak kebaca.
  4. Cek jawaban lewat "Other" sampai ke skill.
- **Pemicu Plan B:** user melaporkan kotak masih sering menutupi penjelasan → buka spec baru untuk hook `Stop` → `notify.sh`.

## 10. Diserahkan ke builder

- Wording persis `rules/ask-user.md` dan wording rujukan per skill. Nama file `ask-user.md` adalah keputusan Claude dan boleh diganti kalau ada yang lebih cocok dengan konvensi `rules/`.
- Cara terbaik menyelaraskan frasa gate per skill (edit minimal; jangan menulis ulang alur skill).
- Nomor versi rilis.
