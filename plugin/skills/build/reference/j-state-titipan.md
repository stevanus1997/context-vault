## J. Ringkasan state (`build_status.py`) + titipan (`carry.yaml`)

### Ringkasan state — controller pegang PETA, bukan isi file
`python3 .claude/build_status.py --root . --format <f> --work-item <work-item>` (read-only, stdlib; salinan template di produk lewat `init`/`upgrade`):
- `controller` — teks ringkas. Baris:
  - `work-item:` (kind · risk efektif · sensitivity · `scratch <wi>` = folder brief/report/review/`_rules` work-item ini);
  - `staleness:` (`STALE <file> > tasks.yaml` / `WARN business.md > tasks.yaml` / `OK`);
  - `repos:`;
  - `READY:` per repo, urut dokumen; `(sibuk <id>)` = repo punya task in-flight;
  - `in_progress:`, `hold:`, `blocked:`, `gates queued:`;
  - `korup:` — `deps` ke id tak dikenal, ≥2 `in_progress` di satu repo → state korup (SKILL step 1: attended tanya user, unattended `halt`);
  - `reuse basi:`;
  - `carry:` (jumlah titipan aktif per target + `next C<n>`, atau `legacy`);
  - `map:` — milestone kelar dilipat 1 baris, sisanya 1 baris per task: id · unit · status · deps · penanda `[manual]`/`[migrate:<kind>]`/`[actions]`/`[mockup]` (task belum done) · desc ≤ 80 karakter.
  Jalankan ulang tiap scheduler tick (murah).
- `task --task <id>[,<id>…]` — JSON entri task lengkap (+ `milestone`, dan `line`/`end_line` = rentang blok task di `tasks.yaml` buat Read offset/limit + Edit, §E). Dipakai brief-writer, gate step 6, dan waktu controller butuh detail satu task.
- `carry --for <target>[,<target>…]` — JSON titipan AKTIF untuk target itu (+ `line` tiap entri `carry.yaml`).

Kalau exit ≠ 0 dengan `invalid choice` (salinan lama), atau mode unattended tanpa entri allowlist `Bash(python3 .claude/build_status.py:*)`, controller degrade ke cara lama (SKILL step 1).

### Titipan — `<work-item>/carry.yaml`
Isinya keputusan/temuan yang ngaruh ke task LAIN, ke gate, ke `ship`, atau ke simplify 7a. File ini ikut ke-commit, karena ini state resume, setara `tasks.yaml`/`gates.yaml`. Controller membuatnya waktu ada titipan pertama, dengan header persis ini:
```yaml
# carry.yaml — titipan antar-task build. Penulis tunggal: controller build. Entri terbaru di ATAS.
legacy_converted: 2026-10-20  # opsional — diset subagent konversi legacy (lihat "Legacy" di bawah)
notes:
  - id: C2
    for: T75            # id task | gate:<M> | gate:<M>/<unit> | ship | simplify — boleh list: [T3, T5]
    from: review T66    # review Tn | preflight | gate <M> | drain | user <YYYY-MM-DD> | legacy
    at: 2026-10-20
    note: "pratinjau daftar nama sebelum simpan"
  - id: C1
    for: gate:M4
    from: review T52
    at: 2026-10-19
    note: "urutan deploy: migrasi PR-1 terbukti di production dulu"
    closed: 2026-10-20  # opsional — titipan gate/ship/simplify yang sudah dipakai
```
- **Kapan tulis (WAJIB).** Sebelum scheduler tick berikutnya (urutan atomik SKILL step 2), tiap ada keputusan/temuan yang ngaruh ke task/gate/ship/simplify lain. Sumbernya: pre-flight sweep, verdict reviewer, gate, drain pagi, jawaban user, atau jawaban ambigu brief-writer. Yang cuma relevan buat task berjalan → JANGAN dititip. Brief-writer cuma tahu yang tertulis di sini.
- **Cara tulis (tanpa baca file utuh).**
  - Titipan pertama → Write file dengan header di atas.
  - Selanjutnya → Read `limit: 3` (Edit butuh file sudah di-Read), lalu Edit ganti baris `notes:` dengan `notes:` + entri baru. Id-nya = `next` dari baris `carry:` ringkasan state.
  - Menutup entri: `line` entri dari `--format carry` → Read `offset: <line>` `limit: 6` → Edit tambah baris `closed: <tanggal>`.
- **Siapa baca.** Brief-writer `--for <task>`; gate step 6 `--for gate:<M>/<unit>`; 7a `--for simplify`; `ship` `--for ship`. Controller cuma melihat JUMLAH (baris `carry:`).
- **Target gate.** `gate:<M>` berlaku untuk semua segmen milestone itu; `gate:<M>/<unit>` cuma segmen itu. Minta `--for gate:M4/api` → dapat `gate:M4` + `gate:M4/api`.
- **Aktif.** Titipan ber-`for:` task yang sudah `done`, dan titipan ber-`closed:`, tidak dikeluarkan `--format carry`. Entrinya tetap di file sebagai jejak audit.
- **Penulis tunggal = controller.** Satu-satunya pengecualian: subagent konversi legacy (sekali, attended, sebelum dispatch apa pun).
- **Kandidat debt BUKAN titipan** → langsung `control/debt.yaml` (pintu ke-4, SKILL step 6).

### Legacy `_carry-notes.md`
`<wi>/_carry-notes.md` (`<wi>` = scratch di baris `work-item:`; catatan bebas buatan run lama, belum resmi) tetap AKTIF selama `carry.yaml` belum ber-`legacy_converted:` — juga kalau `carry.yaml` sudah ada karena titipan baru ditulis duluan. Baris `carry:` bertanda `legacy` (`… · legacy _carry-notes.md aktif (<n> baris)` bila `carry.yaml` sudah ada).
- **Attended:** SEKALI, sebelum dispatch pertama DAN sebelum titipan pre-flight ditulis. Dispatch subagent konversi (prompt §K) → entri `from: legacy` DITAMBAH ke `carry.yaml` (file sudah ada → id lanjut dari `next`, entri lama tak ditimpa) + set `legacy_converted: <tanggal>` → balik jumlah per target. Tunjukkan JUMLAH-nya ke user, bukan isinya. File lama tetap ada sebagai arsip.
- **Unattended, atau belum dikonversi:** `--format carry` menggabung baris `_carry-notes.md` yang menyebut token target (`T75`; `gate:M4` → `M4`; `ship`; `simplify` → `simplify`/`7a`) — `source: legacy`, atau `carry.yaml+legacy` bila `carry.yaml` sudah ada.
