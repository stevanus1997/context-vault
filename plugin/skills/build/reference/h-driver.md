## H. Outer-loop driver (unattended berkelanjutan lintas-sesi — M7)

Tujuan: ubah "user ngetik `build` lagi tiap sesi" jadi mesin yang muter sendiri sampai fitur kelar / butuh manusia. **Inti = sinyal `outcome` (§G); driver tinggal baca lalu putuskan lanjut/stop.** Plugin TAK bikin mesin loop sendiri — pakai yang harness/OS sudah sediakan (selaras prinsip `wire`: delegasi ke tool resmi). Dua engkol, sinyal sama:

**Fresh context: cuma dari PROSES BARU.** `claude -p` (proses baru tiap putaran) & `/schedule` (sesi cloud fresh tiap run) memberi context kosong + resume dari `tasks.yaml` (disk) — pola Ralph asli. `/loop` TIDAK (akumulatif, sesi sama) → bukan engkol untuk ini.

### Engkol 1 — bash (`drive.sh`, ter-ship di template) — grind kontinu
`bash <root>/.claude/drive.sh <fitur> [maks-jam]`. Tiap putaran: spawn `claude -p "build <fitur> --unattended" --permission-mode acceptEdits` (PROSES BARU, context fresh) → baca header `outcome`/`done` dari `last-run.md` → putuskan. **`acceptEdits` WAJIB** — auto-terima tool `Edit`/`Write` (mis. `tasks.yaml` + file kode) tanpa prompt, **sementara Bash TETAP tunduk allowlist** (push/`rm -rf` tetap diblok `deny`). Tanpa ini, headless beku di permission tool `Edit` (kasus nyata: reset status task ke-deny → build mati di task-1). Allowlist Bash WAJIB punya bentuk multi-repo `git -C <path> <subcmd>` ter-ENUMERASI per unit path (commit/checkout/dst) selain bentuk polos — bentuk wildcard-tengah `git -C * …` TAK PERNAH match (mati; matcher cuma hormati `:*` di akhir), diturunkan `wire` 5.5/`upgrade` dari `workspace.yaml`. Kalau tak ada/masih bentuk-mati, commit per-repo beku. Plus workspace WAJIB di-`trust` (precheck `drive.sh`) — kalau tidak, `permissions.allow` produk diabaikan headless. **TIGA backstop (semua deterministik, di luar model):**
- `outcome: done` → stop sukses; `outcome: review` → stop, manusia drain pagi (`build <fitur>` attended, §I) lalu jalankan `drive.sh` lagi; `outcome: halt` → stop abnormal, **JANGAN restart** — cek `last-run.md`.
- **nol-kemajuan** — `done` tak naik dari putaran sebelumnya → mandek → stop (auto-scale: 10 atau 1000 task tak masalah, yang dijaga "ada kemajuan", bukan "berapa kali").
- **deadline waktu** (`maks-jam`, default 6) → stop.

Build self-cap per putaran (cap-volume §D = **budget bobot**, default **10 poin** — bukan jumlah task; task berat ber-`mockup:`/`integration` makan jatah lebih cepat) supaya tiap proses kecil & mati sebelum context membengkak. "Budget 10" = aturan tertulis yang model hitung-sendiri-lalu-patuhi; `drive.sh` = rem keras di luar model.

### Engkol 2 — `/schedule` — batch terjadwal (overnight / lepas-laptop)
`/schedule` sebuah routine: tiap <interval> jalankan `build <fitur> --unattended`. Tiap run = sesi cloud FRESH → build self-resume dari `tasks.yaml`, kerjakan 1 batch (≤cap), tulis `outcome` + notif. Routine berulang sampai `outcome: done` (run berikutnya jadi no-op: manifest closed / tak ada `pending`) — lalu **hapus routine**. **Bedanya dari bash:** `/schedule` tak baca `outcome` untuk auto-stop (tiap run independen) → saat `outcome: review`/`halt`, run terjadwal berikutnya akan berakhir sama lagi (nol kerja, notif berulang "masih nunggu kamu") → **pause/hapus routine sampai manusia drain/beresin**. Cocok bila tak mau grind kontinu / laptop mati.

### Aturan aman (dua-duanya)
Driver menumpang floor (langkah-1 §D) + notif (§G); ia **tak pernah** melonggarkan gate. `review`/`halt` → selalu berhenti & panggil manusia; driver tak pernah auto-lewati `needs_human`/migrate destructive/Security — migrate additive auto-apply HANYA bila opt-in allowlist (`wire` 5.5). Tak ada auto-merge/auto-ship — `outcome: done` berarti "siap di-`ship`", `ship` tetap attended (jatah manusia).
