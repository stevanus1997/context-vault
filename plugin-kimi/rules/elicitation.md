# Elicitation — Aturan Q&A & Penyajian Opsi

Dirujuk skill yang meng-elicit keputusan dari user lewat Q&A discovery/design
(discovery, intake, fanout, plan, tweak, fix, roadmap). Berlaku saat skill MENANYAKAN keputusan ke
user — BUKAN ke routing mekanis (mis. triage verba-list tweak/fix). Tujuan:
keputusan yang MENYETIR hasil diambil sadar oleh user — bukan keborong jadi satu
tembakan, bukan "asal pilih recommended".

## Kontrak
- **Keputusan-bercabang = satu pertanyaan per giliran.** Keputusan yang MENGUBAH
  ARAH hasil (siapa pengguna, flow/skenario, aturan bisnis, reuse-vs-NEW tabel,
  app/package/vendor baru, jalur Mockup) ditanya SATU per giliran. JANGAN gabung
  2+ keputusan-bercabang dalam satu tembakan. Konfirmasi sepele (ejaan nama,
  yes/no kecil, "ada lagi?") BOLEH digabung.
- **Tiap opsi bawa konsekuensi.** Tiap pilihan disertai 1 baris akibat/tradeoff
  ("kalau ini → ..."), BUKAN label telanjang. User harus bisa milih tanpa nebak
  maksud opsi.
- **Selalu sediakan jalan keluar dari menu.** Selain opsi yang ditawarkan, selalu
  beri ruang "ceritain versimu sendiri" — opsi bukan kurungan.
- **Jangan tandai *recommended* untuk keputusan ber-impact tinggi/ireversibel.**
  Sajikan tradeoff lalu minta user yang putuskan; default-recommend malah mancing
  "asal pilih". (Selaras `anti-yes-man.md`: persetujuan harus berdasar.)
- **Surface di gate.** Keputusan-bercabang yang sudah diambil HARUS kelihatan di
  artifact yang ditampilkan saat gate (slot di business.md/fanout.md/plans) — biar
  bisa di-review, bukan terkubur.

## Batas
- **Bukan pelarangan batch di mana-mana.** Skill yang sengaja mem-batch demi biaya
  manusia (mis. pre-flight conflict sweep `build`, build/SKILL.md:18) TIDAK
  dilanggar — itu konfirmasi-borong disengaja, bukan Q&A discovery bercabang.
- **Gate ≠ interogasi.** Gate yang menampilkan Challenge Checklist/diff TERISI untuk
  di-review (mis. `tweak` step 5 — "output terisi, BUKAN interogasi 4-ronde",
  tweak/SKILL.md:40; gate `intake`/`build`) BUKAN sasaran aturan ini. "Satu
  pertanyaan per giliran" mengatur Q&A discovery, bukan mengubah gate jadi
  tanya-jawab beruntun.
- **Proporsional.** Fitur 1-app/sepele tak perlu diregang jadi 10 giliran — aturan
  ini menyerang keputusan yang benar-benar bercabang, bukan bikin birokrasi.
