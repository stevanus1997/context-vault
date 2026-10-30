# Penanda fitur di knowledge bersama

Knowledge bersama (`control/business/*`, `invariants.md`, `conventions.md`, `integrations.md`, `workspace.yaml` capabilities) kadang ditulis **sebelum** kodenya merge (intake/fanout). Supaya `sync` tidak menimpanya dengan perilaku master yang lama, dan `review-pr` tidak memakainya untuk menuduh PR rekan, tiap entri yang ditulis atas nama fitur yang belum ship diberi penanda.

- Markdown: tambahkan ` <!-- feature:<fitur> -->` di ujung baris/bullet entri (entri multi-baris: di ujung baris pertamanya).
- YAML: tambahkan ` # feature:<fitur>` di ujung baris nilai yang ditambahkan.
- Update entri yang sudah ada atas nama fitur → penanda ikut ditambahkan ke baris itu.
- Penulis penanda: `intake` (promosi ke `business/*`) dan `fanout` (`capabilities`/`consumers`).
- Pelepas penanda: `ship` (setelah PR dibuat, karena kode = realita) → `python3 -B ${CLAUDE_PLUGIN_ROOT}/skills/sync/sync_status.py unmark --root . --feature <fitur>`. `drop` → lihat langkah 3 drop.
- Pembaca: `sync` (jangan timpa entri ber-penanda fitur `draft`/`active` → tampilkan "bentrok sama fitur lo") dan `review-pr` (entri ber-penanda fitur yang belum ship **bukan** dasar tuduhan → kartu Info).
- Daftar penanda: `python3 -B ${CLAUDE_PLUGIN_ROOT}/skills/sync/sync_status.py markers --root . [--feature <f>] [--status active,draft]`.
