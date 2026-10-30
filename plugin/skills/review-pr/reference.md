# review-pr — reference

## §1. Checklist per lapis

**Konsistensi (`konsistensi`)**
- Struktur folder, penamaan file/fungsi/komponen ikut pola repo itu (lihat 2–3 file tetangga di `origin/<base>`).
- Helper bersama yang sudah ada dipakai, bukan ditulis ulang (`conventions.md`).
- Gaya error/log/response sama dengan modul sejenis.

**Best practice (`best_practice`)**
- Error ditelan (`catch` kosong, `null` diam-diam), retry tanpa batas, timeout absen.
- Test: perilaku baru tanpa test, test yang cuma menguji mock.
- Keamanan: input tak divalidasi, endpoint tanpa cek role/tenant, secret di kode, PII di log. Area sensitif → `security-critic` (SKILL langkah 5).
- Performa: N+1 query, loop berat di path request, data besar tanpa paging.

**Alur lintas-repo (`alur`)**
- Transisi status / aturan di `business/flows.md` & `invariants.md` dilanggar.
- Producer berubah tapi consumer (di `workspace.yaml` / kontrak) tidak ikut berubah di PR mana pun, atau sebaliknya.
- Urutan panggilan antar-app berubah (mis. FE memanggil service yang bukan backend-nya).

**Kontrak (`kontrak`)**
- PR di repo `contracts_repos`: nama field jelas, wajib/opsional eksplisit, versi naik bila breaking, dampak ke consumer disebut.
- PR consumer: field/tipe yang dikirim/dibaca cocok dengan kontrak di `origin/<base>` **atau** di PR saudara satu tiket.

## §2. Temuan baik vs buruk

| Lapis | Baik | Buruk |
|---|---|---|
| kontrak | "Nama field beda sama schema LSS" — `surveyDate` vs `survey_schedule_at` wajib, lokasi `reschedule-form.tsx:88`, bukti tabel. | "Kontraknya kurang rapi." (tanpa field, tanpa lokasi) |
| alur | "Survey yang udah dikirim masih bisa dijadwal ulang" — `SUBMITTED` ikut diizinkan, bentrok `invariants.md`, bukti rantai status. | "Mungkin ada masalah alur." |
| best_practice | "Error dari server nggak keliatan ke user" — `.catch(() => null)` di `survey.ts:41`, bukti kode. | "Sebaiknya pakai async/await." (selera) |
| konsistensi | "Datasource baru pakai `fetch` langsung, modul lain lewat `createDatasource()`." | "Nama variabel kurang bagus." (selera) |

Temuan yang bersandar ke entri knowledge ber-penanda fitur aktif → bukan `harus`/`saran`, tapi `info` "bakal bentrok sama fitur lo <f>".

## §3. JSON laporan (input `assemble.py`)

Kunci wajib `title`, `prs`, `findings`. `lane` ∈ `konsistensi|best_practice|alur|kontrak`, `level` ∈ `harus|saran|info` (selain itu → exit 1).

```json
{"title": "Jadwal ulang survey dari backoffice", "author": "jocelyntjahyadi26", "opened": "2 hari lalu", "ticket": "BLCS-5302",
 "prs": [{"label": "LBOFE", "number": 1482, "url": "…"}],
 "stale_repos": [],
 "map": {"nodes": [{"id": "LBOFE", "sub": "#1482", "touched": true, "problem": true}, {"id": "LGS", "touched": false}],
         "edges": [{"from": "LBOFE", "to": "LTS", "label": "surveyDate", "problem": true}]},
 "lane_ok": {"konsistensi": "Struktur folder, nama datasource, dan pola form ikut yang udah ada di LBOFE."},
 "findings": [
   {"lane": "kontrak", "level": "harus", "title": "…", "location": "LBOFE src/…:88", "comment": "…", "stale": false,
    "evidence": {"type": "contract", "left": "LBOFE ngirim", "right": "LSS minta", "rows": [{"l": "surveyDate", "r": "survey_schedule_at wajib", "bad": true}]}},
   {"lane": "alur", "level": "harus", "…": "…",
    "evidence": {"type": "states", "states": [{"name": "NEW", "ok": true}, {"name": "SUBMITTED", "flag": true}], "ok_label": "boleh jadwal ulang", "flag_label": "PR ini ikut izinin"}},
   {"lane": "best_practice", "level": "saran", "…": "…",
    "evidence": {"type": "code", "lines": [{"n": 41, "text": "  .catch(() => null)", "hl": true}]}}
 ]}
```

- `opened` = umur PR dalam bahasa santai ("2 hari lalu"). `prs[].label` = label repo (singkatan di komentar `workspace.yaml`, selain itu nama app).
- `comment` boleh memakai `backtick` untuk kode (dirender `<code>`, disalin apa adanya). Temuan `info` boleh `comment: ""`.
- `stale: true` → chip "mungkin karena catatan basi". `stale_repos` (label repo) → banner di bawah kepala.
- `lane_ok[lapis]` = satu kalimat kenapa lapis itu aman. Hanya tampil bila lapis itu tanpa temuan `harus`/`saran`.
- Vonis, subjudul, angka lapis, urutan kartu (`harus` → `saran` → `info`), dan escape diurus `assemble.py`.

## §4. Memilih `evidence.type`
- `contract` — dua sisi yang harus cocok (pengirim vs penerima, kontrak vs consumer). Baris `bad: true` = yang tidak cocok. Sertakan 1–2 baris yang cocok di sekitarnya sebagai konteks.
- `states` — aturan transisi/status. `ok: true` = status yang diizinkan aturan, `flag: true` = yang dilanggar PR, sisanya netral.
- `code` — potongan 2–6 baris dari diff dengan baris bermasalah `hl: true`, nomor baris asli.
- Tanpa bukti visual yang jujur → hilangkan `evidence` (kartu satu kolom). Jangan bikin bukti yang tidak ada di diff.

## §5. Membangun `map`
- Node = app yang disentuh tiket (`touched: true`, `sub` = `#<nomor PR>`) + tetangga langsung di `workspace.yaml` (consumer/producer/backend yang disebut `responsibility`/`stack`), `touched: false`. Maksimal 5 node touched.
- Edge = arah panggilan yang diketahui (`from` memanggil/mengirim ke `to`) dari `responsibility`/`stack`/kontrak. Edge yang membawa temuan `harus` → `problem: true` + `label` field/endpoint-nya. Node asal temuan `harus` → `problem: true`.
- Hanya 1 app tersentuh dan tanpa tetangga relevan → hilangkan `map` (peta tidak dirender).
