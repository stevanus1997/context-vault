# Desain — kerja tim: `sync` (nyusulin `control/` pasca-pull) + `review-pr` (review PR rekan)

**Tanggal:** 2026-10-29
**Status:** Draf (menunggu review user → `writing-plans`)
**Scope:** skill baru `sync` + `review-pr` (masing-masing `SKILL.md` · `reference.md` · `template.html` · `assemble.py`) · hook plugin `SessionStart` (`plugin/hooks/hooks.json` + skrip deteksi) · penjaga basi di `feature` · `plan` · `fix` · `tweak` · penanda fitur di `intake` · `fanout` (+ `ship`/`drop` melepas penanda, `ship` mencatat nomor PR) · `guide/reference.md` · `ask` (tabel route) · `init` + `upgrade` (`.gitignore`) · README dua bahasa · `plugin.json` · tes `tools/tests/` · regen `plugin-kimi/`
**Mockup acuan (disetujui user):** `docs/superpowers/specs/2026-10-29-sync-review-pr-mockup.html` (dua tab: laporan review PR dan ringkasan sinkron)
**Produk acuan:** BFI LORA (`~/Developer/BFI/lora`) — multi-repo, 11 repo, root bukan repo git

---

## 1. Masalah

context-vault lahir untuk developer solo: `control/` bergerak hanya lewat skill yang dijalankan user sendiri. User sekarang memakainya di kantor (LORA). Di sana `control/` cuma ada di laptop user, sedangkan kodenya digarap banyak squad. Dalam 30 hari terakhir, tiap repo inti (LTS, LGS, LBOFE, LSS) menerima commit dari 6+ orang, ditambah `bfibravo-bot` sebagai committer terbanyak.

Dua masalah yang muncul:

1. **`control/` selalu basi.** Tiap kali user pull lalu mengerjakan task, ada knowledge yang tidak cocok lagi dengan kode. Ketahuannya baru di `/feature`: intake/critic bilang rencana user "menyalahi invariant" padahal invariant-nya yang sudah diubah rekan. Tidak ada catatan "knowledge ini terakhir sinkron dengan commit mana", jadi sistem tidak bisa menghitung selisihnya.
2. **User sekarang ikut mereview PR**, tapi tidak semua. Satu repo dikerjakan banyak squad, dan user hanya mereview PR yang diminta. Kekhawatiran utama: alur lintas-repo yang terlewat (misal LBOFE salah memakai schema) dan kejelasan kontrak di LSS (repo tempat semua kontrak/schema LORA).

Kedua masalah saling bergantung. Review yang dicek terhadap `control/` basi akan salah menuduh PR rekan, persis seperti `/feature` salah menuduh user sekarang. Karena itu **sinkron dibangun dulu, review di atasnya.**

## 2. Hasil yang diharapkan

**Sinkron.** Begitu user membuka sesi di produk yang `control/`-nya ketinggalan, Claude tahu tanpa biaya token. Saat user memanggil skill yang bergantung ke knowledge, skill itu bertanya dulu apakah mau sinkron. Kalau ya: semua perubahan yang sudah merge ke branch utama dicatat lengkap ke `control/`, lalu satu halaman HTML ringkasan **level bisnis** terbuka (fitur baru, aturan bisnis berubah, aturan coding baru).

**Review.** `/review-pr` menampilkan PR yang meminta review user di semua repo produk. User memilih, lalu PR itu (beserta PR saudaranya di repo lain dengan kode tiket yang sama) direview pada empat lapis. Hasilnya satu halaman HTML: vonis di atas, skor per lapis, kartu temuan dengan bukti visual dan draft komentar yang tinggal di-copy. Tidak ada yang otomatis di-post ke GitHub.

Kriteria berhasil:
- `/feature` tidak lagi menuduh pelanggaran yang sebenarnya hanya akibat catatan basi, baik karena sinkron sudah jalan, atau karena temuannya diberi label "mungkin karena catatan basi".
- User paham isi 40+ commit baru dalam satu layar tanpa membaca daftar commit.
- User bisa memutuskan approve/minta ubah PR rekan dari satu halaman, dan ketidakcocokan lintas-repo (field LBOFE vs schema LSS, transisi status vs `invariants.md`) tertangkap walaupun perubahannya tersebar di beberapa PR.

## 3. Goals, non-goals, anti-goals

**Goals**
- Patokan sinkron per repo (commit terakhir di branch utama remote yang sudah dicatat).
- Deteksi basi yang gratis (git saja, tanpa LLM) di awal sesi.
- Penjaga basi di skill yang membaca knowledge untuk memutuskan sesuatu.
- Sinkron menulis lengkap ke `control/`, sedangkan user hanya melihat ringkasan bisnis.
- Review PR empat lapis, PR satu tiket digabung lintas-repo, laporan HTML lokal.

**Non-goals (v1)**
- Memposting komentar ke GitHub (user yang menyalin dan menulis sendiri).
- Membuat `control/` dipakai bersama tim (tetap milik pribadi user).
- Sinkron dari branch selain branch utama (branch kerja user tetap urusan `/build`).
- Mendeteksi repo baru yang belum terdaftar di `workspace.yaml` (itu tugas `add-app`).
- Memberi tahu bahwa **kode** rekan menyenggol file yang sedang digarap fitur aktif user (ide untuk nanti, lihat §9). Bentrok di level **knowledge** sudah ditangani D25.

**Anti-goals** (gagal walaupun secara teknis jalan)
- Ringkasan sinkron berupa tembok teks atau daftar commit. User secara eksplisit tidak mau membaca teks panjang.
- Sinkron jalan diam-diam dan memakan token/menit saat user tidak sedang bekerja di produk itu.
- Review menuduh PR rekan karena `control/` basi tanpa memberi tahu bahwa catatannya mungkin basi.
- `git pull` user jadi lambat.

## 4. Keputusan desain

| # | Keputusan | Alasan / sumber |
|---|-----------|-----------------|
| D1 | Dua skill baru: `sync` dan `review-pr` | User. Nama `review-pr` (bukan `review`) dipilih **[call Claude]** agar tidak bentrok dengan `/code-review` bawaan dan skill review superpowers. |
| D2 | Patokan per repo disimpan di **`control/sync.yaml`** (file baru), satu entri per app/package: `base_ref` (mis. `origin/master`), `synced_sha`, `synced_at`. Juga ada daftar `bot_authors` (default diisi otomatis saat sinkron pertama dari pola `*-bot`/`*[bot]`, bisa diedit; LORA: `bfibravo-bot`, `github-actions[bot]`) dan `contracts_repos` (D19) | **[call Claude]** File terpisah dari `workspace.yaml`, karena `workspace.yaml` punya penulis lain (`add-app`/`architect`/`fanout`) dan patokan ini berubah tiap sinkron. Absen = belum pernah sinkron (presence-based, tidak butuh `/upgrade`). |
| D3 | Branch utama per repo dideteksi pakai cara `ship`: `git -C <path> symbolic-ref refs/remotes/origin/HEAD`. Gagal/ambigu → tanya user sekali, simpan sebagai `base_ref` | Konsisten dengan `ship` step 2. |
| D4 | **Deteksi = hook `SessionStart` level plugin** (`plugin/hooks/hooks.json`), bukan hook template produk. Skripnya: keluar diam-diam kalau tidak ada `control/workspace.yaml`. Selain itu, untuk tiap entri `sync.yaml` bandingkan `git rev-parse <base_ref>` dengan `synced_sha` dan hitung `git rev-list --count`. Ada selisih → tulis satu baris konteks: "`control/` ketinggalan N commit di LGS, LBOFE, LSS sejak <tanggal>. Skill yang baca knowledge bakal nawarin `/sync`." Tanpa `fetch`, tanpa LLM, harus selesai <1 detik untuk 11 repo | User: "otomatis how to nya gmna". Level plugin **[call Claude]** agar langsung aktif di semua produk tanpa `/upgrade`. Tanpa `fetch` karena `git pull` user (refspec default) sudah memperbarui `origin/<branch utama>`, dan jaringan tidak boleh memperlambat buka sesi. |
| D5 | `sync.yaml` absen → hook diam. Sinkron pertama (manual `/sync`, atau ditawari penjaga) menetapkan baseline. User ditanya sekali lewat `AskUserQuestion`: "anggap `control/` sekarang sudah sinkron dengan kode" (patokan = HEAD sekarang, tanpa ringkasan), atau "sinkron sejak tanggal X" (ambil commit pertama ≥ X per repo sebagai titik mulai) | **[call Claude]** Tanpa patokan, tidak ada selisih yang bisa dihitung. LORA sendiri sudah ketinggalan dalam jumlah yang tidak diketahui. |
| D6 | **Penjaga basi** di awal `feature`, `plan`, `fix`, `tweak`, dan `review-pr`. Logikanya sama dengan hook (dibungkus satu helper, lihat D14). Ada repo basi yang relevan → tanya via `AskUserQuestion`: "`control/` ketinggalan N commit di <repo>. Sinkron sekarang?" **Ya** → jalankan `sync`, buka ringkasan, lalu lanjutkan skill semula. **Skip** → skill jalan terus, dan setiap temuan/tuduhan "melanggar aturan" yang bersandar pada knowledge dari repo basi diberi label **"mungkin karena catatan basi"** | User: "tanya dl sih". Label saat skip = **[call Claude]**, langsung menjawab anti-goal ke-3. "Relevan" = repo yang disentuh fitur/fix/PR. Untuk `feature` di tahap awal (sebelum fanout) = semua repo. |
| D7 | `sync` menulis **lengkap** ke file pemiliknya di `control/` **tanpa gate per item**: `invariants.md`, `conventions.md`, `business/flows.md`·`domain.md`·`glossary.md`·`risks.md`, `integrations.md`, `workspace.yaml` (`capabilities`, `stack` bila berubah), `schema/<app>.md` (migrasi), `design-system.md` (bila komponen/token berubah). Setiap perubahan diberi jejak `<!-- sync <sha-pendek> <tanggal> -->` (atau komentar YAML) supaya bisa ditelusuri | User: "ttep smua di catat full di control nya". |
| D8 | **Pengecualian prinsip penulis-tunggal.** `sync` boleh menulis file milik skill lain karena yang dicatatnya adalah **realita yang sudah merge**, bukan usulan. Gate dan critic pemilik file ada untuk menilai rencana, sedangkan di sini tidak ada yang bisa ditolak. Batasnya: `sync` hanya mencatat perilaku yang terbukti di kode. Ia tidak menambah entri app/package/vendor baru (route ke `add-app`/`add-package`/`add-integration` lewat ringkasan), tidak mengubah `features/*`, dan **tidak menimpa catatan bertanda fitur yang belum ship** (D25) | **[call Claude]** Diturunkan dari keputusan D7 user + prinsip `ask` §Catatan ("kode = realita saat beda"). Tabel route `ask` §5 ditambah baris: drift akibat kode rekan → `/sync`. |
| D9 | Yang dianalisis: `git log <synced_sha>..<base_ref>` per repo (setelah `git fetch`, karena `sync` boleh pakai jaringan). Commit `bot_authors` dan perubahan yang hanya versi/lockfile dihitung tanpa dibaca. Sisanya dikelompokkan per PR (nomor PR dari judul squash/merge commit) lalu diklasifikasi: **fitur baru** · **aturan bisnis berubah** · **aturan coding baru** · **kontrak berubah** · **sisanya** (refactor/fix kecil, cukup dihitung) | User: "cukup tau apa aja yang brubah tapi secara bisnis aja … nambah fitur apa atau ada aturan code yang baru". |
| D10 | Analisis per repo dijalankan **subagent** (satu per repo yang berubah, paralel), dan balikannya pendek terstruktur (klasifikasi + usulan tulis per file). Controller yang menulis ke `control/` | **[call Claude]** Menjaga konteks controller tetap ramping, mengikuti pelajaran `build` lean-controller (balikan subagent dikirim sekali, ringkas). |
| D11 | `synced_sha` sebuah repo hanya maju setelah semua tulisan repo itu berhasil. Sinkron yang terputus di tengah tetap aman diulang | **[call Claude]** |
| D12 | Commit hasil `ship` user sendiri yang sudah tercatat di fitur shipped dilewati agar tidak dicatat dobel. Dicocokkan lewat nomor PR yang dicatat `ship` | Diusulkan Claude di playback, user tidak keberatan. Detail pencocokan diserahkan ke builder. |
| D13 | **Ringkasan sinkron** = HTML lokal `.claude/sync/<tanggal-jam>.html` (di-gitignore), dibuka otomatis (`open` di macOS, fallback cetak path). Isi sesuai mockup tab 2: judul "<N> hal baru sejak <tanggal>", kartu per repo (bar commit orang vs bot), tiga kolom (fitur baru · aturan bisnis berubah dengan visual sebelum→sesudah bila angka/enum · aturan coding baru), lalu satu baris "Ditulis ke control/" dan hitungan commit sisanya. Item yang butuh skill lain (repo/vendor baru) tampil sebagai pointer | User: format HTML, tidak capek dibaca, dibuat dengan `frontend-design`, dan mockup disetujui. |
| D14 | Logika "repo mana basi" ditulis **sekali** sebagai skrip `plugin/hooks/sync-status.py` (atau `.sh`). Dipakai hook (D4) dan penjaga (D6), dengan output teks untuk hook dan `--json` untuk skill | **[call Claude]** Satu sumber logika, bisa dites. Pola sama dengan `build_status.py`. |
| D15 | `/review-pr` tanpa argumen → `gh search prs --review-requested=@me --state=open` dibatasi ke `repo_url` di `workspace.yaml`. Hasilnya tabel (repo, judul, penulis, umur, sudah pernah direview?) lalu user memilih lewat `AskUserQuestion`. `/review-pr <url|repo#nomor>` → langsung | User: maunya otomatis tapi mengakui ada banyak repo. Rekomendasi Claude (panggil manual, cari PR otomatis) diterima. |
| D16 | Kalau `gh` mengembalikan 404/izin ditolak → beri tahu user bahwa akun `gh` aktif mungkin bukan akun kerja dan sarankan `gh auth switch`. Jangan berganti akun sendiri | User punya dua akun `gh` (pribadi + kantor). |
| D17 | **Gabung per tiket.** Ambil kode tiket (pola `[A-Z]+-\d+`) dari nama branch atau judul PR terpilih, lalu cari PR terbuka dengan kode sama di repo lain produk. Semuanya direview sebagai satu perubahan (diff gabungan per repo), dan hasilnya tetap **satu laporan**. Tanpa kode tiket → satu PR saja | User: "bisa kek gt juga kok". |
| D18 | **Empat lapis review:** (1) **Konsistensi**: pola repo itu (`conventions.md` + kode sekitar diff). (2) **Best practice**: error handling, test, keamanan, performa. `security-critic` dipanggil atas diff (seperti `ship` 4.5) **bila diff menyentuh** data pribadi (field/identitas/KTP/kontak), pembayaran/uang, auth/role/tenant, secret/konfigurasi, atau vendor yang terdaftar di `integrations.md` **[call Claude: produk tidak punya `sensitivity` level produk, `sensitivity` hanya ada per `feature.yaml`, dan PR rekan tidak punya fitur]**. (3) **Alur lintas-repo**: dicek ke `business/flows.md`, `invariants.md`, plus consumer/producer di app lain (`workspace.yaml`) yang mestinya ikut berubah tapi tidak. (4) **Kontrak**: untuk PR di repo pemilik kontrak (LORA: LSS), nilai kejelasannya (nama field, wajib/opsional, versi, dampak ke consumer). Untuk PR consumer, cocokkan field/tipe yang dipakai dengan kontrak di branch utama **ditambah** PR saudara yang belum merge | User: konsistensi, best practice, alur ("LBOFE salah pke schema"), kejelasan kontrak LSS. |
| D19 | Repo "pemilik kontrak" tidak di-hardcode. Disimpan di `control/sync.yaml` → `contracts_repos: [<app>]` dan **ditanya sekali saat sinkron pertama** (baseline D5; Claude mengusulkan kandidat dari `responsibility` di `workspace.yaml`, user mengonfirmasi, boleh kosong). Bila `review-pr` jalan dan `sync.yaml` belum punya kunci itu, ia menganggap tidak ada repo kontrak dan menyarankan `/sync` | **[call Claude]** Plugin generik dan tidak boleh tahu soal LSS. Disimpan di file milik `sync` agar `review-pr` tetap read-only dan `workspace.yaml` tidak butuh penulis baru. |
| D20 | `review-pr` **read-only terhadap `control/` dan kode**. Knowledge dari PR baru masuk lewat `sync` setelah merge | Diusulkan Claude di playback dan disetujui ("lgtm"). |
| D25 | **Fitur aktif user menang atas master.** `intake` dan `fanout` menandai tiap catatan yang mereka tulis ke knowledge bersama (`business/*`, `invariants.md`, `conventions.md`, `workspace.yaml` capabilities, `integrations.md`) dengan nama fitur: `<!-- feature:<f> -->` di Markdown, komentar `# feature:<f>` di YAML. `ship` melepas penanda (kode sudah merge = realita). `drop` melepas penanda bersama review promosi yang sudah ada. **`sync`** tidak menimpa catatan bertanda fitur berstatus `draft`/`active`. Bila perubahan master bentrok dengannya, tampilkan sebagai kartu **"bentrok sama fitur lo"** di ringkasan (aturan master vs aturan fitur, dan fiturnya), lalu catat versi master **di samping** (tidak menggantikan) dengan penanda `sync`. User membereskannya saat ship/tweak. **`review-pr`** tidak memakai catatan bertanda fitur yang belum ship sebagai dasar tuduhan, karena aturannya belum berlaku di master. Bila PR rekan bentrok dengan catatan itu, tampilkan sebagai kartu **Info** "bakal bentrok sama fitur lo" yang **tidak** memengaruhi vonis **[call Claude: bentuk kartu Info]** | User memilih opsi A ("fitur aktif lo menang") setelah reviewer menunjukkan bahwa `intake`/`fanout` sudah menulis knowledge sebelum ship (LORA: `df4w-credit-task-detail` aktif di `feat/BLCS-5285`). |
| D21 | **Laporan review** = HTML lokal `.claude/review/<repo>-<nomor>.html` (di-gitignore), dibuka otomatis. Isi sesuai mockup tab 1, bentuk "A" pilihan user: kepala PR (judul, penulis, tiket, chip PR saudara), **vonis besar** (`Perlu ubah` / `Siap approve` / `Approve dengan saran`), empat skor lapis, **peta repo** yang disentuh tiket (jalur bermasalah merah), lalu kartu temuan (kiri: judul, tingkat `Harus dibenerin`/`Saran`, lokasi, draft komentar + tombol Copy; kanan: **bukti visual** sesuai jenis: tabel "X ngirim vs Y minta" untuk kontrak, rantai status untuk alur, potongan kode dengan baris disorot untuk best practice/konsistensi). Lapis tanpa temuan cukup satu baris centang | User memilih A, "jgn kebnyakan text, pke diagram". |
| D22 | Vonis: ada ≥1 `Harus dibenerin` → `Perlu ubah`. Hanya `Saran` → `Approve dengan saran`. Kosong → `Siap approve` | **[call Claude]** |
| D23 | Kedua HTML mengikuti pola `share`: **`template.html` beku + `assemble.py`** yang menerima JSON data dari Claude. Claude menulis isi (penilaian), sedangkan perakitan, escape, dan penyematan ditangani script yang deterministik dan bisa dites. Visual mengikuti mockup (palet abu-kebiruan/navy, Schibsted Grotesk + JetBrains Mono khusus kode, merah/amber/hijau hanya untuk status). Template final dibangun dengan skill `frontend-design` | User meminta `frontend-design`. Pola `share` sudah terbukti. |
| D24 | Draft komentar ditulis dalam bahasa Indonesia santai-sopan, berbentuk pertanyaan/usulan (bukan perintah), satu-dua kalimat, menyebut file/field konkret | **[call Claude]** Draft ini akan ditempel atas nama user ke rekan kerja. |

## 5. Alur

### 5.1 Sinkron
```
buka sesi ──► hook SessionStart ──► sync-status.py
                                  ├─ sync.yaml absen / semua sama → diam
                                  └─ ada selisih → 1 baris konteks ke Claude

/feature|/plan|/fix|/tweak|/review-pr
   └─ penjaga: sync-status.py --json (repo relevan basi?)
        ├─ tidak → lanjut
        └─ ya → AskUserQuestion "sinkron sekarang?"
              ├─ skip → lanjut, temuan dari repo basi diberi label "mungkin karena catatan basi"
              └─ ya → /sync → lanjut skill semula

/sync
  1. sync.yaml absen → tetapkan baseline (D5)
  2. git fetch per repo; hitung <synced_sha>..<base_ref>
  3. buang bot/bump; kelompokkan per PR; lewati PR hasil ship sendiri
  4. subagent per repo → klasifikasi + usulan tulis
  5. controller tulis ke control/ (jejak sha), lewati catatan bertanda fitur aktif
     (bentrok → kartu "bentrok sama fitur lo") → majukan synced_sha per repo
  6. rakit + buka ringkasan HTML
```

### 5.2 Review
```
/review-pr [pr]
  1. penjaga basi (D6)
  2. tanpa argumen → daftar PR review-requested → pilih
  3. kode tiket → PR saudara di repo lain
  4. kumpulkan diff gabungan per repo + konteks control/ + kontrak di base & PR saudara
  5. empat lapis (security-critic bila sensitivity menuntut)
  6. vonis → rakit + buka laporan HTML
```

## 6. Batasan

- Skill mengikuti konvensi plugin: Bahasa Indonesia, `AskUserQuestion` di titik tunggu (`rules/ask-user.md`), `rules/anti-yes-man.md` (temuan nyata, bukan selera), dan `rules/elicitation.md` untuk pertanyaan bercabang.
- CC 2.1.30x tidak punya Grep/Glob, dan `claude -p` menolak Read di luar root. Skrip harus memakai Bash/Read biasa.
- Subagent mengirim balikan via `SendMessage` ke "main" satu kali, dengan teks akhir ringkas (pelajaran 0.28.1).
- Hook harus aman di produk yang bukan context-vault, di repo tanpa remote, dan di direktori yang bukan repo git (root LORA). Kalau gagal, hook diam; ia tidak pernah memblokir sesi.
- Kimi: hook `SessionStart` dan `gh` mungkin berbeda. Port mengikuti ritual `docs/maintaining.md`. Bila hook tak didukung Kimi, penjaga di skill tetap bekerja (D6 tidak bergantung pada hook).
- HTML dibuka offline. Hanya font Google Fonts yang butuh jaringan (fallback `system-ui`/`ui-monospace`).
- `.gitignore` produk: `init` + `upgrade` menambah `.claude/sync/` dan `.claude/review/`. `control/sync.yaml` **di-commit** bila `control/` ada di repo (knowledge).

## 7. Yang diserahkan ke builder

- Skema persis `sync.yaml` dan bentuk JSON input `assemble.py` kedua laporan.
- Heuristik klasifikasi commit/PR (prompt subagent), dan batas ukuran diff sebelum dipotong/diringkas.
- Cara mencocokkan PR hasil `ship` sendiri (D12), termasuk bila `ship` belum mencatat nomor PR, dengan menambah pencatatan itu di `ship`.
- Cara pasti menentukan "repo relevan" untuk penjaga di tiap skill.
- Penempatan helper (`plugin/hooks/` vs `plugin/skills/sync/`) asal satu sumber (D14).
- Detail visual template final dalam koridor mockup (lewat `frontend-design`), termasuk dark mode dan tampilan mobile.
- Apakah hitungan basi di hook/penjaga mengabaikan commit `bot_authors` (disarankan ya, agar commit rilis bot tidak memicu tawaran sinkron).
- Patokan baseline "anggap sinkron sekarang" (D5) = `base_ref` saat itu.
- Repo di folder produk yang tidak terdaftar di `workspace.yaml` (LORA: `lora-process-sdk`, `lora-tools`) diabaikan sinkron. Ringkasan cukup menyebut "ada repo tak terdaftar" sekali, dengan pointer ke `add-app`/`add-package`.
- Cara membaca diff/berkas PR tanpa menyentuh working tree user (mis. `gh pr diff`, `git fetch origin pull/<n>/head` ke ref sementara).
- Catatan fitur aktif yang ditulis **sebelum** penanda D25 ada (LORA: `df4w-credit-task-detail`) tidak bisa dikenali otomatis. Cukup sediakan jalan keluar sederhana, misalnya sinkron pertama menyebut fitur `active` yang ada dan menyarankan user menandai/memeriksanya.
- Isi tes (`tools/tests/sync.test.sh`, `review-pr.test.sh`): minimal skrip status (selisih/kosong/bukan repo/tanpa remote), `assemble.py` (escape, bagian kosong dilewati), dan hook diam di luar produk.

## 8. Urutan

0. Penanda fitur (D25) di `intake`/`fanout` + pelepasan di `ship`/`drop` + `ship` mencatat nomor PR (D12). Ini prasyarat agar sinkron pertama tidak menimpa catatan fitur aktif.
1. `sync`: `sync.yaml` + `sync-status` + hook + skill + ringkasan HTML.
2. Penjaga basi di `feature`/`plan`/`fix`/`tweak` + label "mungkin basi" + baris route di `ask`.
3. `review-pr`: daftar PR, gabung tiket, empat lapis, laporan HTML (penjaga sudah tersedia dari langkah 2).
4. `guide`, README dua bahasa, `plugin.json` (versi minor naik), `init`/`upgrade` `.gitignore`, regen `plugin-kimi/`.

## 9. Untuk nanti (bukan v1)

- Ringkasan sinkron menandai "perubahan ini nyenggol fitur lo yang lagi aktif" (bila file yang berubah beririsan dengan `plans/` fitur `active`).
- Opsi memposting komentar terpilih ke GitHub sebagai draft review.
- Riwayat review per PR (re-review setelah rekan push perbaikan, hanya menampilkan yang berubah).
