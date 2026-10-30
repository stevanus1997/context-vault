# sync — reference

## §1. Usulan tulis dari `sync-reader`

Balikan subagent = JSON list. Satu elemen = satu perubahan yang terbukti di diff (biasanya satu PR):

```json
{"kind": "feature|business_rule|coding_rule|contract|other",
 "app": "LTS",
 "summary": "1 kalimat buat controller — apa yang berubah dan buktinya (file:baris)",
 "writes": [{"file": "control/…", "op": "add|update", "anchor": "teks heading/baris tempat menyisip"|null,
             "old": "baris lama persis (op update)"|null, "new": "baris baru tanpa jejak sync", "sha": "<sha commit/PR>"}],
 "summary_item": {"app": "LTS", "text": "…", "before": "2×", "after": "3×"}}
```

- `kind: contract` (perubahan kontrak/schema, terutama di `contracts_repos`) masuk kolom **aturan bisnis** di ringkasan.
- `kind: other` = dicatat ke knowledge (mis. kapabilitas) tapi tak perlu tampil. `summary_item: null`.
- `summary_item` mengikuti bentuk item §3 (`before`/`after` bila angka/enum berubah, `pill` untuk nama field/helper/token). Bahasa bisnis, satu kalimat, tanpa nama file.
- Commit yang tidak terbukti mengubah perilaku/aturan/pola (refactor, fix kecil, test, bump) → **tidak** jadi elemen. Ia masuk hitungan `other_commits`.

## §2. Menerapkan usulan (controller)

Peta file → jenis perubahan:

| Perubahan | File |
|---|---|
| Aturan domain/status | `business/domain.md` · `business/flows.md` |
| Istilah baru | `business/glossary.md` |
| Risiko baru yang eksplisit di kode | `business/risks.md` |
| Batasan lintas-app | `invariants.md` |
| Pola coding | `conventions.md` |
| Kapabilitas app/package existing | `workspace.yaml` `capabilities` (dan `stack` bila dependensi utama berubah) |
| Migrasi DB | `schema/<app>.md` |
| Vendor yang SUDAH terdaftar | `integrations.md` |
| Token/komponen | `design-system.md` |

Prosedur per `writes[]`:
1. `op: update` → `old` harus ketemu persis **satu kali** di file. Tidak ketemu / lebih dari satu → lewati, sebut di chat. Jangan menebak.
2. Baris `old` memuat penanda `<!-- feature:<f> -->` / `# feature:<f>` dengan `<f>` di daftar `markers --status active,draft` → **jangan ganti**. Sisipkan `new` di baris berikutnya (jejak sync), lalu tambah `conflicts`: `{"feature": f, "file": <file relatif control/>, "master": new, "yours": old tanpa penanda}`.
3. `op: add` → sisipkan setelah baris `anchor` (heading/bullet terakhir di bagian itu). `anchor: null` → akhir file. Hindari duplikat: fakta serupa sudah ada → ubah jadi `update` atau lewati.
4. Jejak: Markdown → tambahkan ` <!-- sync <sha7> <YYYY-MM-DD> -->` di ujung baris. YAML → ` # sync <sha7> <YYYY-MM-DD>` di ujung baris nilai. Baris YAML yang sudah punya komentar → ganti komentar lama dengan jejak sync (kecuali penanda fitur: lihat langkah 2).
5. Setelah menulis `workspace.yaml`, pastikan masih valid: `python3 -B ${KIMI_SKILL_DIR}/../../skills/sync/sync_status.py status --root .` tidak mengembalikan `reason` "gagal membaca control/…".
6. Kumpulkan `written`: per file, `{"file": "<relatif control/>", "change": "+2" | "1 diubah" | "+1 field" | "+2 kapabilitas"}`.

Larangan: entri app/package/vendor **baru**, `control/features/**`, `control/fixes/**`, dan `sync.yaml` (hanya via `sync_status.py`).

## §3. JSON ringkasan (input `assemble.py`)

Kunci wajib `since`, `generated`, `repos`; sisanya opsional (default `[]`/`0`/`null`).

```json
{"product": "BFI LORA", "since": "2026-10-21", "generated": "2026-10-29 09:12",
 "repos": [{"key": "lora-gateway-service", "label": "LGS", "human": 14, "bot": 11, "people": 3}],
 "features": [{"app": "LGS", "text": "…"}],
 "business_rules": [{"app": "LTS", "text": "…", "before": "2×", "after": "3×"}, {"app": "LSS", "text": "…", "pill": "+ reason_code wajib"}],
 "coding_rules": [{"app": "LBOFE", "text": "…", "pill": "createDatasource()"}],
 "conflicts": [{"feature": "df4w-credit-task-detail", "file": "business/flows.md", "master": "…", "yours": "…"}],
 "pointers": [{"text": "Repo belum terdaftar: lora-tools", "skill": "/add-app"}],
 "written": [{"file": "invariants.md", "change": "1 diubah"}],
 "other_commits": 37, "stale_note": null}
```

- `since` = `synced_at` paling lama di antara repo yang disinkron (sebelum `advance`). `generated` = waktu lokal `YYYY-MM-DD HH:MM`.
- `repos[]` (hanya repo yang punya commit di range): `human` = commit `bot: false`, `bot` = commit `bot: true`, `people` = author unik non-bot. Commit `own: true` dihitung sebagai `human`.
- `other_commits` = total commit semua range dikurangi jumlah item `features` + `business_rules` + `coding_rules`.
- `stale_note` = satu kalimat bila ada repo yang dilewati (error/fetch gagal), mis. "LGS dilewati: patokan hilang dari riwayat." Selain itu `null`.
- `pointers`: repo/vendor baru → skill pemiliknya. Repo tak terdaftar dideteksi dari folder `<root>/*` yang punya `.git` tapi tak ada di `workspace.yaml`.
- Judul, subjudul, kolom kosong, dan escape diurus `assemble.py`. Jangan menulis HTML di JSON.

## §4. Label repo
`label` = singkatan di komentar baris `- name:` app/package di `workspace.yaml` bila ada (mis. `- name: lora-gateway-service   # LGS` → `LGS`). Selain itu nama app (repo multi-app → nama app pertama). `summary_item.app` memakai label yang sama.
