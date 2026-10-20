## C. Pilih model (hemat biaya & cepat)
- Task mekanikal (1-2 file, spec jelas) → tier terendah yang lolos floor di bawah.
- Integrasi multi-file / pattern-matching → model standar.
- Butuh judgment desain → model paling kuat. **Task ber-`mockup:` masuk kategori ini** — menerjemahkan mockup (yang teknologinya bisa ≠ stack project) ke komponen existing tanpa transplant markup butuh judgment desain.
- **Turn count beats token price (upstream ≥6.1):** model termurah rutin makan 2–3× turn di kerja multi-step — total malah lebih lambat & lebih mahal. **Floor mid-tier untuk reviewer DAN implementer yang kerja dari prosa.** Task `tasks.yaml` = prosa (desc/approach/test, TANPA kode) → praktisnya implementer hampir selalu floor mid-tier; tier termurah HANYA bila teks task memuat kode lengkap tinggal transkripsi+test, atau fix mekanikal 1-file. Reviewer JANGAN pernah di bawah mid-tier (rubber-stamp + deteksi entity-equivalence butuh judgment).
