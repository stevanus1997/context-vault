# Debt-Aware — Resurface Utang Teknis by Locality (aturan share)

Dirujuk skill yang menetapkan SCOPE kerjaan di sebuah area kode (`plan`, `fix`). **BUKAN langkah baru** yang berdiri sendiri — ia **rider** pada read kode-per-area yang skill itu sudah lakukan. Tujuan: utang teknis di `control/debt.yaml` dilunasi **di tempat ia mengganggu**, tanpa nyangkut selamanya.

## Kontrak
- **Sebelum mulai kerja di area X**, baca `control/debt.yaml`; saring entri yang `area`-nya beririsan dengan footprint X (app/module yang akan disentuh).
- Ambil yang berstatus **`open`** (status diturunkan — lihat header `control/debt.yaml`).
- Untuk tiap utang `open` di area itu, **tawarkan melunasi di gate** skill ini: *"area ini punya N utang open: `<ringkas observed>`. Lipat ke kerjaan ini? (+N task)"*
- **Setuju** → bergantung host: host yang PUNYA `tasks.yaml` (`fix`) → langsung buat task `kind: debt, pays_debt: <id>` (refactor — jaga perilaku TETAP sama, test regresi hijau; BUKAN ubah perilaku) di `tasks.yaml`-nya; host yang BELUM punya `tasks.yaml` (`plan`) → tulis baris marker **"Utang dilunasi: `<id>`"** di `plans/<app>.md`, dan `breakdown`-lah yang menerjemahkan marker itu jadi task `kind: debt, pays_debt: <id>` (breakdown SKILL step 4). **Tidak** → biarkan `open` (tetap muncul di render-docs "Known Issues" — tak hilang).

## Batas
- **Owner-aware.** Hanya tangani utang `owner: feature` (kode app). Utang `owner: foundation` (stack/convention/package/integration) **bukan** jatah `plan`/`fix` — itu sudah diputus saat capture (decide-now di `build`; **kecuali** entri ber-`observed:` berawalan "UNATTENDED — belum diputuskan:" — capture unattended, route-nya diputuskan di drain pagi `build/reference.md` §I; sampai saat itu perlakukan sebagai BELUM diputus: tampilkan apa adanya, jangan anggap final — amandemen 2026-08-28) & di-resurface saat skill fondasi (`architect`/`add-*`/`wire`) berjalan.
- **Bukan auto-fix.** Menawarkan, bukan memaksa. Pelunasan selalu lewat gate / persetujuan eksplisit — capture & resurface tak boleh diam-diam melebarkan scope.
- **Tidak menulis `debt.yaml`.** Status diturunkan; entri dimiliki skill `/debt`. Skill yang merujuk rule ini hanya MEMBACA registry + menulis task `kind: debt` ke `tasks.yaml`-nya sendiri (atau, jalur `plan`: marker "Utang dilunasi" di `plans/<app>.md` — lihat Kontrak).
