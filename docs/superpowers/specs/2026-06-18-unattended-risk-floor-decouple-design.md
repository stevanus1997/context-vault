# Desain — Decouple `risk` dari `sensitivity` + buka jalan loop unattended

**Tanggal:** 2026-06-18
**Status:** Disetujui (siap masuk `writing-plans`)
**Scope:** "Lengkap" (lihat §3) — risk decouple + floor-scan + setup prasyarat unattended + catatan migrasi
**Menyusul / mengoreksi:** `docs/superpowers/specs/2026-06-06-m7-graduated-autonomy-design.md` (D4)

---

## 1. Masalah

Temen-temen pengguna plugin lapor: tiap nyoba **loop engineering** (`drive.sh` / `build <fitur> --unattended`), loop **selalu berhenti di ronde-1** dengan alasan dianggap "berisiko gede". Loop praktis **tak terpakai**.

Akar yang dikonfirmasi (rantai sebab):

1. `intake/SKILL.md` (≈baris 57) memasang **floor keras**: bila `feature.yaml` `sensitivity` memuat `payments`/`pii` → `risk` **minimal `high`** (HARD, tak bisa diturunkan selama `sensitivity` non-kosong).
2. Heuristik `pii` di intake = fitur yang **mengumpulkan/menyimpan/MENAMPILKAN** nama, email, alamat, telp, gov-id. Heuristik `payments` = menggerakkan/menyimpan uang.
3. `build` step 6 (`SKILL.md` ≈baris 48; `reference.md` §D/§G/§H): saat unattended **dan** `risk: high` → auto-approve **tak pernah nyala** → emit `outcome: halt` **dini di ronde-1**, reason `"risk:high butuh attended"`.
4. `drive.sh` (≈baris 44): `outcome=halt` → **berhenti, tak di-restart**.

**Akibat:** hampir **setiap fitur produk nyata** menyentuh nama/email/uang → ke-tag `pii`/`payments` → `risk` ke-floor `high` → unattended `halt` ronde-1. Floor-nya benar secara niat (lindungi blast-radius duit + kewajiban PCI/PII), tapi **jaringnya kelebaran** sampai menelan seluruh fitur unattended.

Ada pula **dua jalur freeze ronde-1 LAIN** (terungkap saat review desain) yang gejalanya sama-sama kebaca "loop tak jalan", dibahas di §3 komponen C.

---

## 2. Akar konseptual — spec M7 mengoreksi dirinya sendiri

Spec M7 (`2026-06-06-...`) **D1** sudah menyatakan dua sumbu ini **ortogonal**:

- `risk` = **seberapa berbahaya kalau build keliru** (menyetir *cadence* build).
- `sensitivity` = **apa yang sensitif** (menyetir *kedalaman* Security Gate di `ship`).

D1 bahkan memberi contoh persis kasus ini: *"fitur PII-read-only yang aman dibangun (CSS menampilkan nama) butuh `sensitivity:[pii]` untuk red-team ship, tapi TIDAK butuh `risk:high` di build."*

Lalu **D4** justru **menyatukan kembali** keduanya lewat floor borongan `sensitivity non-kosong → risk:high`, dan footnote D4 sendiri sudah mengakui: *"fitur PII sepele (tampilkan nama) ⇒ floor high ⇒ unattended mati untuk fitur itu."*

**Kesimpulan:** perubahan ini **bukan mengubah desain** — ini **mengembalikan D4 ke niat asli D1.** Itu justifikasi paling kuat dan paling tak kontroversial.

---

## 3. Keputusan desain (scope "Lengkap")

Empat komponen, bertumpuk. A+B = inti (benar & aman). C+D = bikin loop benar-benar terpakai end-to-end untuk produk fresh & lama.

### Komponen A — Decouple `risk` dari `sensitivity` (persempit floor)

**Redefinisi `risk`** sebagai penilaian **blast-radius build**, bukan sensitivitas data runtime. `risk: high` bila build-nya sendiri berbahaya:

- operasi **destruktif/irreversible**;
- **migrasi skema/data** (catatan: task `migrate` sudah punya floor keras sendiri di build step 3 — ini cuma membuat tag level-fitur jujur);
- **batas auth/keamanan** (authn/authz, session/token, isolasi tenant, CORS/origin);
- **plumbing pergerakan uang** (charge/capture/refund/payout/settlement/transfer, simpan PAN/token-kartu).

**Persempit floor** di `intake/SKILL.md`:

> Floor lama: `sensitivity` non-kosong → `risk` minimal `high` (HARD).
> Floor baru: `sensitivity` memuat `payments` **DAN** fitur benar-benar **menggerakkan uang** (verba charge/capture/refund/payout/settlement/transfer, atau menyimpan instrumen-bayar — **bukan** sekadar menampilkan harga/invoice/saldo read-only) → `risk` minimal `high` (HARD). **`pii` saja TIDAK lagi memaksa floor** — `pii` menyetir kedalaman Security Gate `ship`, bukan cadence build (sesuai D1).

Tetap **advisory** + default `normal` bila tak yakin + user konfirmasi di gate intake.

**Kosakata dipinjam dari yang SUDAH ADA** agar dua permukaan tak melenceng: `tweak/reference.md` (≈baris 4–5) sudah mengoperasikan **Verba-uang (PLUMBING)** = charge/capture · refund · payout/settlement/transfer · simpan PAN, dan **Verba-keamanan**. Komponen A me-mirror daftar itu.

**TIDAK disentuh:** mekanik heuristik `sensitivity` (tetap mengusulkan tag `pii`/`payments` seperti sekarang), dan **Security Gate `ship`** (`ship/SKILL.md` ≈baris 34, security-critic atas diff payments/pii) — itu benar dan tetap.

### Komponen B — Floor-scan deterministik di build (jaring pengaman)

Decouple memindahkan keputusan dari trigger *mekanis* ke *judgment model* di intake. Bila intake **salah-tag** fitur berbahaya (mis. fitur auth dianggap `normal`), build bisa auto-commit kode berbahaya tanpa jaring. Tutup dengan jaring **deterministik, tak bergantung tag fitur**:

Di **build step 6, sebelum auto-approve** sebuah segmen (mode unattended): **scan diff segmen** untuk verba bahaya — authn/authz, session/token, filter isolasi tenant (`tenant_id`), CORS/origin, charge/capture/refund/payout/settlement/transfer, simpan PAN/token-kartu, dan **DDL migrasi** (`CREATE`/`ALTER`/`DROP`, `prisma migrate`/`db push`, `drizzle push`). **Kena satu → STOP attended**, *apa pun* tag `risk` fiturnya.

Tambahan terkait: **migrasi tak-terdeklarasi** — bila diff menyentuh DDL tapi tak ada `actions: migrate` → perlakukan sebagai migrasi tak-terdeklarasi → **STOP** (agar floor `migrate` step-3 tak bisa di-bypass dengan salah-tag).

Mirror pola **floor-scan yang `tweak` sudah punya** (`tweak/reference.md` ≈baris 33) — pinjam, bukan bikin baru.

### Komponen C — Setup prasyarat unattended (notify + allowlist) + backstop

Dua prasyarat unattended bila absen bikin freeze ronde-1 **terlepas dari risk**:

- **notify.sh stall:** run unattended pertama, bila `notify.sh` belum ada, build melakukan **Q&A interaktif** memilih kanal notif. Headless (`claude -p`) tak ada yang menjawab → **freeze**.
- **allowlist kosong:** bila `permissions.allow` (`<produk>/.claude/settings.json`) belum memuat perintah verifikasi stack (diisi `wire` step 5.5), build menabrak **prompt izin** harness saat jalanin test → headless tak ada yang approve → **freeze**.

**Prinsip:** pertanyaan setup dijawab **saat ada manusia**, bukan diam-diam saat headless. **DITOLAK: auto-bikin `notify.sh` "diam" (no-op)** — itu bikin user terbang buta tanpa sadar (lihat §5). Pertahanan berlapis:

1. **Proaktif (`wire`):** `wire` sudah mengisi allowlist di step 5.5. Tambahkan di situ **setup `notify.sh`** — tanya kanal lalu tulis (`chmod +x`). Karena `notify.sh` **user-specific + gitignored**, ia di-**tanya**, bukan di-ship. Pertanyaan **bisa di-skip** (*"setup notif untuk unattended? skip kalau belum perlu"*) agar tak memaksa user yang tak pakai unattended. (`init` tetap memastikan `.claude/` + gitignore seperti sekarang.)
2. **Migrasi (`upgrade`):** produk lama (di-init versi plugin lawas) tak punya setup ini. `upgrade` (domain = `.claude/`, presence-based, gated) **menawarkan** setup notify + cek allowlist yang sama, sehingga produk lama menyusul. (Konsisten: `upgrade` boleh menyentuh `.claude/`; `control/` existing tetap haram.)
3. **Backstop (`drive.sh`, pola "Y"):** `drive.sh` di-launch oleh manusia di terminal — momen yang dijamin ada manusia. **Sebelum masuk loop**, precheck **keduanya**: `notify.sh` ada? allowlist memuat perintah verifikasi? Bila salah satu kurang → **cetak instruksi jelas lalu EXIT tanpa memulai loop** (tak pernah freeze, tak pernah no-op diam). Ini menjadikan notify & allowlist **sodara kembar** dengan pola identik (proaktif di wire/upgrade, backstop di drive.sh).
4. **Build headless tak pernah nanya:** pertanyaan run-mode/approval/kanal di unattended = otomatis `outcome: halt` (sudah jadi prinsip di `reference.md` §G ≈baris 106). **allowlist kosong** dijadikan **reason `halt` yang jelas** (mis. *"lengkapi allowlist / jalankan wire 5.5"*), bukan freeze prompt diam — selaras dengan WARN yang sudah ada di `reference.md` (≈baris 59) tapi naik dari WARN ke reason terstruktur.

### Komponen D — Catatan migrasi fitur lama + transparansi

- **Fitur lama yang terlanjur ke-floor `high`** (di-intake sebelum perubahan ini) tetap halt setelah fix; intake tak meng-usul ulang, dan `upgrade` **haram menyentuh `feature.yaml`** (itu `control/`). Maka: **dokumentasikan pemulihan manual** secara menonjol — edit `feature.yaml` `risk: high → normal` untuk fitur pii-only, atau re-run intake.
- **Reason halt dibedakan:** `last-run.md` membedakan *"floored karena benar-benar berbahaya (auth/uang/migrasi)"* vs *"floored karena `risk` di-set high"* — agar user tahu apakah perlu menurunkan `risk` lalu lanjut, atau memang biarkan attended. Hari ini reason `"risk:high butuh attended"` identik untuk keduanya.
- **Banner "BUILT UNATTENDED":** segmen yang auto-approve unattended dan menyentuh area sensitif → tandai di `last-run.md` / body PR (mis. *"DIBANGUN UNATTENDED — review security-critic wajib sebelum merge"*), agar backstop manusia tertunda (Security Gate `ship`) tak diam-diam dilewati/di-rubber-stamp.

---

## 4. Invarian keamanan yang DIJAGA (tak boleh kendor)

1. **Security Gate `ship` utuh** — `ship/SKILL.md` security-critic atas diff payments/pii tetap jalan; tag `sensitivity` + maknanya di ship **byte-identik**.
2. **Degrade fail-safe terhadap sensitivity** — bila `risk` absen/typo pada fitur yang `sensitivity`-nya memuat `payments` → degrade ke **`high`** (bukan `normal`); fitur pii-only absen `risk` → `normal` (aman, karena floor-scan B tetap menjaga). Default degrade dihitung ulang terhadap `sensitivity`, sebab logika "normal = lebih banyak review" terbalik begitu floor dipersempit.
3. **Floor-scan B** = jaring deterministik yang tak bergantung judgment intake — itu syarat yang bikin decouple A aman.
4. **Floor lama tetap berdiri** — `migrate` (step 3), `needs_human` (step 2), `blocked` (step 5), penyimpangan-dari-maksud, circuit-breaker + cap-volume (§D). Komponen A/B **melonggarkan cadence**, **bukan** menghapus gate.
5. **Prasyarat konsistensi lintas-fitur** — `control/invariants.md` yang **terkunci** adalah jaring agar fitur sekuensial (mis. login & profil) tak bikin kontrak bentrok. Bila slot relevan masih `<belum dikunci>`, munculkan **WARN** sebelum unattended (advisory, sejajar precheck allowlist) — sebab backstop security-critic ompong tanpa baseline terkunci.
6. **Scaffold comment byte-identik** — `intake/SKILL.md` (≈baris 21) dan `feature/SKILL.md` (≈baris 21) **wajib identik** (spec M7 §4a) dan **tanpa `: ` (colon-space) bocor** ke value YAML (BUG-GUARD). Edit dalam satu commit + grep-verify kesetaraan.

---

## 5. Alternatif yang DITOLAK

- **Mode "supervised" (`outcome: pause` + file `.approve`)** — DITOLAK (verdict review: *unsound*). Mesin baru banyak (marker re-arming, driver pause-aware, exempt nol-kemajuan) dan approve payments/pii lewat tulis file = batas otentikasi lemah. Tak sepadan.
- **Auto-bikin `notify.sh` no-op diam** — DITOLAK. Bikin user terbang buta tanpa sadar; lebih jahat dari freeze (freeze setidaknya kelihatan). Diganti pola wire/upgrade/drive.sh-precheck (Komponen C).
- **Surgical-only (decouple tanpa floor-scan B)** — DITOLAK. Meninggalkan lubang auth-underclassify (fitur auth salah-tag `normal` → kode auth auto-commit tanpa jaring).

---

## 6. Di luar scope (fase lanjutan, BUKAN sekarang)

- **Risk granularitas per-segmen/per-milestone** (login/checkout dapat sebagian unattended) — lebih berat: nambah field `tasks.yaml`, `breakdown` nge-tag per-milestone, **wajib eval akurasi tagger** dulu, plus masalah *topological collapse* (UI aman depend ke API sensitif). Dicatat sebagai kandidat lanjutan; tidak dikerjakan di iterasi ini. **Menyusul 2026-08-27:** kebutuhan ini terpenuhi lewat jalur BERBEDA — antrian gate `gates.yaml` (gate ditunda, bukan tag per-task), lihat `2026-08-27-build-deferred-gate-review-queue-design.md`.

---

## 7. Daftar file yang berubah (konfirmasi anchor saat planning)

| File | Perubahan |
|---|---|
| `plugin/skills/intake/SKILL.md` | Redefinisi `risk` (build-danger) + persempit floor jadi payments-movement-only (≈baris 57); scaffold comment (≈baris 21). Heuristik `sensitivity` **tak diubah**. |
| `plugin/skills/feature/SKILL.md` | Scaffold comment (≈baris 21) — **byte-identik** dgn intake. |
| `plugin/skills/build/SKILL.md` | Step 6 (≈baris 48): tambah **floor-scan B** + migrasi-tak-terdeklarasi → STOP; step 1 (≈baris 15): degrade default vs sensitivity + WARN invariants; lapor-keluar (≈baris 19): allowlist-kosong → reason halt jelas, reason halt dibedakan, banner BUILT-UNATTENDED. |
| `plugin/skills/build/reference.md` | §D (≈58–60): floor-scan + degrade + allowlist-as-halt; §G (notif): setup keluar dari headless + tak-pernah-nanya; §H (≈104): reason halt + precheck drive.sh. |
| `plugin/template/.claude/drive.sh` | Blok **precheck** (notify.sh + allowlist) sebelum loop → backstop Y (stop + instruksi, no-freeze/no-silent). |
| `plugin/skills/wire/SKILL.md` | Step 5.5 (allowlist): tambah setup `notify.sh` (skippable). |
| `plugin/skills/upgrade/SKILL.md` | Tawarkan setup notify + cek allowlist untuk produk lama (domain `.claude/`). |
| `plugin/skills/init/SKILL.md` | Pastikan `notify.sh` ter-gitignore (sebagian besar sudah) — verifikasi, bukan tambah prompt. |
| `docs/superpowers/specs/2026-06-06-m7-graduated-autonomy-design.md` | **Append** catatan bertanggal yang menyusul D4 (jangan tulis-ulang sejarah): floor borongan dipersempit ke payments-movement; pii-read-only tak lagi floor. |

**Doc-sync:** perubahan ini **tidak menambah skill** → jumlah skill (README/induk §17/plugin.json/marketplace) **tak berubah**. Yang berubah = *perilaku* intake/build/wire/upgrade + driver; pastikan deskripsi trigger skill tetap akurat (cek ringan, kemungkinan tak perlu ubah).

---

## 8. Verifikasi (rencana, dirinci di plan)

- **Skenario kanonik** (login/profil/checkout/dashboard/settings): pastikan profil/settings/dashboard (pii-only) **lolos** jadi `risk: normal` → unattended jalan; checkout (uang-beneran) & auth tetap di-gate.
- **Floor-scan B**: fitur auth yang sengaja di-tag `normal` → segmen yang menyentuh `session/token`/`tenant_id` tetap **STOP**.
- **Migrasi tak-terdeklarasi**: diff ber-DDL tanpa `actions: migrate` → STOP.
- **Precheck drive.sh**: produk tanpa notify.sh / allowlist kosong → **exit dgn instruksi**, bukan freeze.
- **Degrade**: `risk` absen + `sensitivity: payments` → diperlakukan `high`.
- **Byte-identik**: grep kesetaraan scaffold comment intake vs feature + tak ada colon-space leak.
- **Ship Security Gate**: tak berubah — diff payments/pii tetap kena security-critic.

---

## 9. Ringkas

Kembalikan `risk` ke makna build-blast-radius (niat D1), persempit floor ke uang-beneran, pasang **floor-scan deterministik** sebagai jaring, dan tutup **dua jalur freeze ronde-1 lain** (notify + allowlist) lewat setup-saat-ada-manusia (`wire`/`upgrade`) + backstop transparan (`drive.sh`). Hasil: loop unattended **benar-benar terpakai end-to-end** untuk fitur pii-umum, sementara auth/uang/migrasi tetap di-gate di **build dan ship**.
