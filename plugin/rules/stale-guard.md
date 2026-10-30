# Penjaga basi — tawarkan /sync sebelum memutuskan pakai knowledge

Dipakai skill yang membaca `control/` untuk MEMUTUSKAN sesuatu (feature, plan, fix, tweak, review-pr). Tujuannya: jangan menuduh "melanggar aturan" berdasarkan catatan yang sudah dilangkahi kode rekan.

1. Jalankan `python3 -B ${CLAUDE_PLUGIN_ROOT}/skills/sync/sync_status.py status --root . --format json --repos <repo relevan>` (tanpa `--repos` = semua). Script absen / exit ≠ 0 / `initialized: false` → lanjut tanpa tawaran (boleh satu kalimat: "belum pernah sinkron — `/sync` kapan-kapan").
2. `stale` kosong → lanjut.
3. `stale` terisi → tampilkan "control/ ketinggalan <n> commit di <repo> (<n>)…" lalu `AskUserQuestion`: **Sinkron sekarang** (jalankan skill `sync`, lalu LANJUTKAN skill ini dari langkah yang sama) / **Skip** (lanjut pakai catatan apa adanya).
4. Skip → ingat daftar repo basi. Setiap temuan/tuduhan "melanggar aturan/invariant/konvensi" yang bersandar pada knowledge yang menyangkut repo basi itu diberi label **"mungkin karena catatan basi"** dan disebut repo-nya.
5. Unattended/headless → jangan pernah bertanya dan jangan sinkron: perlakukan sebagai Skip (label tetap berlaku).
6. Entri knowledge ber-penanda fitur lain yang belum ship (`${CLAUDE_PLUGIN_ROOT}/rules/feature-marker.md`) = aturan yang belum berlaku di master. Jangan jadikan dasar tuduhan terhadap kode master/PR rekan.
