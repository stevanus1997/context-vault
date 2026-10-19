# Ask-user — Titik Tunggu Attended lewat `AskUserQuestion`

Dirujuk semua skill yang berhenti nunggu jawaban user di mode attended (kecuali
`discovery` & `init` — lihat Batas). Tujuan: user yang nyetir sesi dari HP
(Remote Control) DIKABARI tiap kali skill nunggu dia. Push native Claude Code
(**Push when actions required** di `/config`) cuma bunyi untuk permission prompt
dan kotak `AskUserQuestion`. Turn yang berakhir dengan pertanyaan teks TIDAK
memicu push, jadi user nggak tahu ada yang nunggu.

`elicitation.md` mengatur ISI Q&A (apa yang ditanya, opsi bawa konsekuensi);
file ini mengatur PENYAJIAN-nya (lewat apa & urutannya).

## Kontrak
- **Titik tunggu = `AskUserQuestion`, bukan akhir turn ber-pertanyaan teks.**
  Titik tunggu = gate approve/revisi, Q&A keputusan, konfirmasi (yes/no, pilih
  fitur/opsi, "lanjut `/ship`?") — apa pun yang bikin skill berhenti sampai
  user jawab.
- **Konten dulu, kotak belakangan.** Di turn yang sama: tulis dulu semua yang
  harus dibaca sebagai teks biasa (draft/artifact, ringkasan diff, Challenge
  Checklist, tradeoff panjang), BARU panggil `AskUserQuestion`. Pertanyaan di
  kotak pendek & merujuk konten di atas (mis. *"Approve draft business.md di
  atas?"*). Kotak TIDAK mengulang/menggantikan konten — kotak bisa nutupin
  teks panjang.
- **Gate approve/revisi:** minimal opsi **Approve** & **Revisi**; `description`
  tiap opsi = konsekuensinya (mis. "Approve → tulis business.md, lanjut
  fanout"). Catatan revisi lewat "Other" (disediakan otomatis oleh tool). Opsi
  khas skill (Drop/Regen/…) boleh, total tetap 2–4.
  TANPA label "(Recommended)" di opsi gate — approve sekali-tap dari HP jadi
  stempel karet (`anti-yes-man.md`).
  Beberapa gate dalam satu pemberhentian (`build` step 6 mode lane, drain pagi
  §I) → satu panggilan per gate, konten gate itu tepat di atas kotaknya —
  jangan digabung walau ≤ 4 (tiap gate punya diff sendiri yang harus dibaca).
- **Q&A keputusan** (isi tetap `elicitation.md`): satu keputusan-bercabang =
  satu panggilan, satu pertanyaan; 2–4 opsi, `description` = 1 baris
  konsekuensi; "Other" = jalan keluar menu ("ceritain versimu sendiri"); TANPA
  label "(Recommended)" untuk keputusan high-impact/ireversibel. Konfirmasi
  sepele boleh digabung — maks 4 pertanyaan per panggilan.
- **Pertanyaan terbuka** ("ceritain alurnya"): susun 2–4 tebakan dari
  knowledge/kode sebagai opsi + "Other" buat versi user. Pertanyaan teks HANYA
  bila benar-benar tak ada tebakan bermakna (konsekuensi: tanpa push).
- **Jawaban = kata-kata user sendiri** (alasan `drop`, alasan tolak saat triase
  `share`, catatan revisi gate): JANGAN tawarkan tebakan karangan sebagai opsi —
  jawabannya jadi catatan keputusan. Minta lewat "Other" (sebut di teks
  pertanyaan) atau teks biasa. User pilih **Revisi**/**tolak** tanpa catatan →
  minta catatannya sebagai teks bebas dulu, baru lanjut.
- **Input bebas yang bukan keputusan** (mis. paste blok feedback `share`, tempel
  log/error) → minta lewat teks biasa; keputusan SESUDAH input itu → kotak.
- **Batas tool:** 1–4 pertanyaan per panggilan, 2–4 opsi per pertanyaan,
  `header` ≤ 12 karakter, `multiSelect` bila pilihan tak saling eksklusif.
  JANGAN bikin opsi "Lainnya/Other" sendiri — sudah otomatis.
- **Pilihan > 4** (mis. menu bagian `guide`, daftar fitur): kelompokkan jadi
  ≤ 4 opsi (sisanya disebut di teks konten, bisa dipilih lewat "Other") ATAU
  pecah jadi 2 pertanyaan berurutan. Jangan memotong pilihan diam-diam.
- **> 4 hal yang masing-masing butuh keputusan** (triase `share` per baris,
  keep/revert `drop` per item, pre-flight `build`, MVP-vs-nanti `roadmap`):
  tampilkan tabel bernomor di konten, lalu kotak bergiliran — maks 4 hal per
  panggilan, satu pertanyaan per hal.
- **Bukan titik tunggu → teks biasa.** Laporan selesai yang tak nunggu apa-apa
  = teks. Laporan yang ditutup pertanyaan → pertanyaannya masuk kotak.

## Batas
- **Unattended/headless: DILARANG.** Tetap berlaku aturan "JANGAN PERNAH nanya
  interaktif" (`build`): pertanyaan jadi entri `queued`/`hold:`, notif lewat
  hook + `notify.sh` seperti biasa. Larangan ini berlaku untuk run tanpa
  pengawasan itu sendiri & semua run headless (`claude -p` / `drive.sh` /
  `/schedule`).
- **Pengecualian: Q&A kanal notif di AWAL `build <fitur> unattended` dari sesi
  INTERAKTIF** (`build` step 1 "Lapor-keluar", `reference.md` §G) — user masih
  di sesi, jadi itu titik tunggu attended → kotak `AskUserQuestion`. Headless +
  `notify.sh` absen tetap JANGAN tanya.
- **Subagent tidak memanggil `AskUserQuestion`** — implementer/reviewer/critic
  mengembalikan pertanyaan ke controller (pola existing); controller yang
  bertanya ke user lewat kotak.
- **Dikecualikan: `discovery` & `init`** — tetap bertanya dengan teks biasa.
  `discovery` sengaja elicit-first (operator cerita bebas; AI baru mengusulkan
  isi saat operator bilang "gak tau/terserah" → `AI-usul`); sebelum `init`
  belum ada knowledge/kode buat bahan tebakan, jadi opsi akan mengarang dan
  menyetir jawaban. Skill yang di-chain dari situ (mis. `discovery` →
  `roadmap`) ikut aturan skill-nya sendiri.
- **Tanpa baris rujukan: `ask` & `render-docs`** — tak punya titik tunggu.
  Saran route `ask` (skill pemilik yang memperbaiki drift) tetap pointer teks,
  BUKAN kotak — `ask` read-only & tak boleh menjalankan skill itu.
- **Gate ≠ interogasi** (`elicitation.md`) tetap berlaku: kotak tidak mengubah
  gate jadi tanya-jawab beruntun.
- **Push butuh setup user, sekali:** app Claude login di akun yang sama + izin
  notif OS + `/config` → Push when actions required. Tanpa itu kotak tetap
  jalan (cuma HP nggak bunyi). Push di-skip selama user fokus/ngetik di
  terminal yang terhubung.
- **Plan B (belum dipakai):** kalau kotak sering nutupin penjelasan → hook
  `Stop` → `notify.sh` di attended, lewat spec terpisah. Spec asal:
  `docs/superpowers/specs/2026-10-19-attended-ask-push-design.md`.
