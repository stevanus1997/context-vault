## G. Lapor-keluar / notifikasi (mode unattended — M7)

> ⛔ **Harness Kimi Code:** bagian unattended di file ini BELUM berlaku di Kimi — lihat banner di `SKILL.md` (fase 2).

Tujuan: run hands-off TAK berhenti DIAM — manusia dikabari saat dibutuhkan, bukan menunggui terminal. **Sumber kebenaran = laporan disk; notifikasi = best-effort di atasnya** (kanal tak diset / nama event hook beda antar-versi → laporan tetap ada, run tetap resumable). Nol pelonggaran gate: manusia & keputusan yang sama, cuma ditambah "telepon".

**Tiga artefak (ditulis `build`):**
1. **Penanda mode** `<root>/.claude/.unattended` — ditulis di AWAL run unattended (step 1); berarti "ada run hands-off berjalan, kabari kalau beku". Di-clear saat run ATTENDED (self-heal penanda basi dari run yang ke-abort) & dihapus hook `on-stop` saat run berhenti.
2. **Penanda stop** `<root>/.claude/.unattended-stop` — ditulis TEPAT sebelum mengakhiri turn di SETIAP titik STOP (cap-volume / tak ada task READY — antrian & blocker / abnormal / selesai — pemetaan SKILL step 1), isi = SATU baris alasan (mis. `review: 6 gate + 1 blocker — build fitur-x`). Hanya ditulis bila run mode unattended.
3. **Laporan** `<work-item>/last-run.md` — ditulis di tiap stop. **Baris pertama WAJIB header mesin** (kebaca driver outer-loop §H), lalu prosa human-readable:
   ```
   outcome: continue|review|done|halt
   done: <jumlah task done total>
   pending: <jumlah task belum done>
   review: <jumlah entri queued di gates.yaml — OPSIONAL, driver toleran absen>
   blockers: <jumlah task needs_human + blocked — OPSIONAL>
   reason: <satu baris alasan berhenti>
   ```
   Lalu prosa: task/segmen terakhir, ringkas diff, "butuh apa dari manusia" — (amandemen 2026-08-27) WAJIB memuat: daftar entri `queued` (segmen + `reason` + 1 baris ringkas diff), daftar blocker (`needs_human`/`blocked` + `hold:` disalin verbatim — pertanyaan `NEEDS_CONTEXT` ikut), daftar `auto` ringkas; sumber kebenaran tetap `gates.yaml`/`tasks.yaml` (prosa ini ditulis ulang tiap stop). Ini bahan resume + input driver outer-loop (§H). (Driver baca `outcome`+`done`; `pending`/`reason` buat notif + laporan manusia.) (Bila run unattended menyentuh area sensitif, prosa memuat banner *"DIBANGUN UNATTENDED — review security-critic wajib sebelum merge"*.)

**Nilai `outcome` (dipetakan dari alasan stop):**
- `done` — SEMUA task `done` + `gates.yaml` tanpa `queued` + 7a clear (step 7, siap-ship). Driver berhenti (sukses).
- `continue` — berhenti karena **cap-volume** (§D) tercapai, masih ada task READY (juga ditulis di akhir drain pagi §I bila masih ada task READY). Aman di-restart proses fresh → driver lanjut (entri `queued` persisten, tak menghalangi).
- `review` — (amandemen 2026-08-27) tak ada task READY, tapi ada gate `queued` dan/atau task `needs_human`/`blocked` — nunggu keputusan manusia, TAK ada yang rusak. Driver berhenti, notif; manusia jalankan `build <fitur>` attended → drain pagi (§I) → lalu `drive.sh` lagi.
- `halt` — HANYA **abnormal** (amandemen 2026-08-27): circuit-breaker (§D, 2 `blocked` berakar sama) / **blocker lingkungan** (allowlist kosong, permission denial tak teratasi, tak bisa tulis `tasks.yaml`/commit, env) / state korup (`in_progress` ganda satu repo, deps rujuk task tak ada). `needs_human`/`blocked` tunggal/`migrate` destructive/`risk:high` BUKAN `halt` — mereka `review` (subtree nunggu, sisanya sudah dibangun). Ada yang rusak → driver berhenti, JANGAN restart — cek `last-run.md`.

**WAJIB di mode unattended (headless `claude -p`):** JANGAN PERNAH akhiri turn dengan pertanyaan interaktif / pesan ngobrol — tak ada yang baca/jawab, dan driver cuma dapat "last-run.md tak ada". Tiap berhenti (termasuk blocker tak terduga) **emit `outcome` + `last-run.md` DULU, baru stop**. Pertanyaan di unattended TIDAK pernah ditanyakan (amandemen 2026-08-27): approval gate → entri `queued` di `gates.yaml`; approval blocker (migrate destructive/backfill, `manual:`, `NEEDS_CONTEXT`, konflik pre-flight) → `needs_human` + `hold:`; hanya pertanyaan run-mode/state pra-dispatch yang tak bisa diantrikan (mis. staleness `tasks.yaml` vs `plans/*`) → `halt` (abnormal).

**Pengiriman notif = HARNESS via hook (deterministik — jalan walau build beku/crash), BUKAN model:**
- `on-stop.sh` (hook `Stop`, ter-ship di template): tiap turn berakhir → ADA penanda stop? → panggil `notify.sh` + hapus penanda stop + matikan penanda mode. Tak ada penanda → diam (sesi biasa tak ke-spam).
- `on-permission.sh` (hook `PermissionRequest`, ter-ship): tool minta approval → penanda mode ADA? → kabari "BEKU nunggu approval" (kasus allowlist §D bocor; model tak bisa kabari diri sendiri saat beku). Tool `AskUserQuestion` (harness ikut memicu hook ini untuk kotak pertanyaan) → pesan beda "nunggu jawaban (kotak): <header>" — header saja, isi pertanyaan tak dikirim. Tanpa penanda mode → diam. **TIDAK** auto-approve/deny — cuma kabari.

**notify.sh** (`<root>/.claude/notify.sh`) = kanal pilihan USER, diset SEKALI lewat Q&A kanal **di sesi interaktif** (`wire` 5.5 / `upgrade` / `build --unattended` interaktif) — **JANGAN di headless** (`drive.sh`/`/schedule`): di headless, absen → hook no-op + dicatat di `last-run.md`, precheck `drive.sh` yang menjaga di depan — **BUKAN di-ship plugin** (bisa memuat token/topik pribadi → wajib gitignored, di-handle `init`). Q&A: *"mau dikabarin lewat apa? (1) HP via ntfy.sh (2) notif macOS (3) Telegram (4) tak usah"* → tulis baris yang sesuai, `chmod +x`:
- ntfy: `curl -fsS -d "$1" ntfy.sh/<topik-unik-user>`
- macOS: `osascript -e "display notification \"$1\" with title \"build\""`
- Telegram: `curl -fsS "https://api.telegram.org/bot<TOKEN>/sendMessage" -d chat_id=<ID> --data-urlencode "text=$1"`
- pilihan 4 / kanal lain (Slack/Discord/email): file no-op atau user tulis satu baris `curl` sendiri.

Absen / pilihan 4 → hook jadi no-op otomatis (guard `[ -x notify.sh ]`); laporan disk tetap jalan. Generik: plugin tak mengunci satu kanal — menyediakan mekanisme + slot, user yang colok.

**Higiene kanal (ingatkan user saat Q&A):** pakai topik/channel **privat & tak-ketebak** (mis. ntfy topik dengan akhiran acak `stevanus-build-9f3a`, bukan kata umum) — pesan notif memuat ringkas alasan/tool yang beku, jadi topik publik = bocor info. Pesan sengaja ringkas (alasan + nama tool), bukan dump perintah penuh, untuk perkecil paparan.
