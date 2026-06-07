# plan — Reference (UI-Contract + slot `Mockup:` 3-jalur)

Dibaca oleh skill `plan`. SKILL.md tetap ramping; detail UI-Contract, keputusan slot `Mockup:`, cross-check, dispatch generate, dan round-trip ada di sini.

## A. UI-Contract — artifact discovery

Section di `plans/<app>.md`, **HANYA** untuk app peran-UI (`type` ∈ {`fe`,`fullstack`} yang fitur ini **memunculkan/mengubah permukaan UI**-nya). App `be`/non-UI → **JANGAN** tulis section ini (degrade nol-biaya).

Diturunkan dari:
- `business.md` → keputusan provider/kebijakan (mis. "register pakai email + Google").
- `Model/Schema` (slot existing) → field ber-backing-data (email, password, name).
- `API/Komponen` (slot existing) → komponen/endpoint terlibat (RegisterForm, POST /register).

Format (section setelah `API/Komponen` di `plans/<app>.md`):
```
UI-Contract:
  <Komponen/Layar>:
    fields  : <nama(req|opt, constraint ringkas)>, ...
    actions : <aksi + provider, mis. submit, "Continue with Google">
    states  : <idle / loading / error(<kasus>) / success / empty ...>
    shows   : <data yang ditampilkan — layar baca/list; OPSIONAL>
```
- `shows` **opsional** (layar baca/list). Constraint per-field inline di `fields` (req/opt, min/max, format) — **TANPA** slot `validation`/`a11y` terpisah (a11y dijaga komponen design-system saat `build`).
- **SELALU** dibuat lebih dulu dari keputusan slot `Mockup:` — berfungsi di 3 jalur (§B): spec yang dipenuhi mockup (a), input generate (b), konteks build (c).
- **Tampilkan rapi di gate** sebagai blok mandiri yang bisa pengguna **copy** ke tool design eksternal (memenuhi "1 kontrak yang bisa dibawa" tanpa file baru).
- **Idempotent:** re-run `plan` yang sudah punya `UI-Contract:` → reuse, kecuali `business.md`/`Model/Schema`/`API/Komponen` berubah.

Contoh (`auth`/`web`):
```
UI-Contract:
  RegisterForm:
    fields  : email(req), password(req,min8), name(req)
    actions : submit, "Continue with Google"
    states  : idle / loading / error(email-taken) / success
```

## B. Slot `Mockup:` — 3 jalur

Bagian **sama** untuk ketiganya: `UI-Contract` (§A) sudah ditulis & ditampilkan. Lalu keputusan slot `Mockup:` (per app UI) — **tawarkan ketiga jalur** ke pengguna saat app UI belum punya mockup tersimpan; **default TIDAK auto-generate** (hindari biaya tak diminta):

1. **Bawa mockup** (sudah jadi / design sendiri): simpan verbatim ke `mockups/` (Spec A) → **cross-check** (§C) → isi pointer `Mockup:`.
2. **Generate**: §D → mockup-reference ke `mockups/` → **gate eyeball** → isi `Mockup:`.
3. **Degrade** (sengaja skip): `Mockup:` kosong, lanjut (perilaku sekarang); `UI-Contract` tetap ada sebagai konteks `build`.

## C. Cross-check (advisory, opacity terjaga)

Saat jalur **bawa-mockup**. **JANGAN** parse mockup jadi data — mockup tetap **byte-opaque** sepanjang pipeline (invariant Spec A). Yang dilakukan:
- Di gate, **tampilkan UI-Contract di samping pointer mockup** + minta pengguna konfirmasi coverage: *"pastikan mockup memuat: email, password, name, Continue-with-Google. `name` kelihatannya belum ada — tambahkan?"*
- Mockup **teks** (HTML/CSS): boleh **glance ringan** — heuristik nama-field (cari `<input>`/`<label>`/teks tombol yang tampak hilang vs `fields`/`actions`). **Selalu** dikonfirmasi manusia; tak disimpan/diprosa-kan.
- Mockup **non-teks** (gambar/Figma): murni konfirmasi-manusia, tanpa glance.
- Hasil cross-check **TIDAK** ditulis sebagai prosa ke `plans/<app>.md` (hanya `UI-Contract` + pointer `Mockup:` yang ditulis). Field otoritatif = `UI-Contract`.
- Sifat **ADVISORY, bukan palang** — pengguna boleh lanjut walau ada selisih (field bisa sengaja di layar lain).

## D. Generate (dispatch `frontend-design`)

- **Pemicu:** pengguna pilih "generate" di gate `Mockup:` untuk app UI tanpa mockup.
- **Prasyarat:** `control/design-system.md` ada & app dalam scope sebuah design system (cek `Berlaku buat`). Bila app UI belum bergaya, `fanout` sudah memicu `design-system` lebih dulu (existing). Bila `design-system.md` tetap kosong untuk app ini → **JANGAN ngarang fondasi**: degrade ke ad-hoc + peringatan arahkan jalankan `design-system` dulu.
- **Dispatch:** invoke skill **`frontend-design`** dengan konteks: isi `UI-Contract` (§A) + token + inventory komponen dari `design-system.md` + stack app dari `workspace.yaml`. Minta output **mockup HTML/CSS** (format yang mockup-thread sudah handle); URL/aset Figma sebagai alternatif bila relevan.
- **Persist:** simpan hasil **verbatim** ke `control/features/<fitur>/mockups/` (penulis = `plan`, konsisten Spec A).
- **Gate eyeball:** tampilkan hasil → pengguna **approve / regen-dengan-arahan** ("tombol Google lebih besar", "rapatkan spacing") / koreksi manual. Approve → isi pointer `Mockup:`.
- **Hilir:** identik jalur lain — hasil = **mockup-reference**; `build` tetap reproduksi via TDD (BUKAN kode produksi langsung). Karena generate sudah pakai komponen design-system, reproduksi `build` murah & akurat.

## E. Round-trip "design sendiri"

Pengguna pilih jalur **bawa-mockup** tapi belum design:
- **Sesi sama:** `plan` tampilkan `UI-Contract` → **menunggu di gate** → pengguna design di tool eksternal → paste/serahkan hasil → cross-check (§C) → isi `Mockup:`.
- **Sesi beda:** jalankan **`/plan <fitur>`** lagi (modular, tak menarik `intake`/`fanout`) → pengguna serahkan mockup → `UI-Contract` sudah ada (idempotent §A) → cross-check → isi.
- Selama `breakdown` belum jalan, tak ada yang basi. Bila sudah `breakdown`, aturan staleness existing berlaku (`plan` berubah → ingatkan `breakdown` ulang, yang mempertahankan status task `done`).
