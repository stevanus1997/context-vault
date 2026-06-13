# Handoff — evolusi context-vault → loop engineering (M7) + skill upgrade

Fresh session: baca ini, langsung act. 2026-06-13. Repo `/Users/stevanus/Developer/ai-boilerplate`, branch `main` = `origin/main` @ `ce49377` (sudah push, sinkron).

## Next (opsional — semua sudah di titik stabil; lanjut hanya bila user mau)
1. **Langkah 4 — PR babysitter**: pasca-`ship`, loop kecil baca `gh pr checks` + status merge → tulis ke `feature.yaml` + notif kalau CI merah. Nutup gap "shipped ≠ merged/live".
2. **Langkah 5 — discovery loop (usul-SAJA)**: triage terjadwal baca `debt.yaml`+`feedback/` → susun antrian kandidat intake buat di-approve manusia. Loop boleh nemu kerjaan, TAK boleh mutusin (penulis `feedback/` tetap manusia).
3. **Upgrade produk lama user**: produk milik user yang di-init versi plugin lama belum di-migrasi. Jalankan `/upgrade` dari root produk itu (gw bisa pandu). User minta dipandu, bukan auto.
4. **Live `/plugin install` end-to-end test**: plugin ini BELUM PERNAH di-test live (risiko tertua, semua fase). Worth dicoba beneran.

Pola tiap langkah: gw jelasin → user nyerna/nanya → user bilang "gas" → edit langsung → smoke-test → adversarial-verify workflow (4-5 lensa, skeptik per-temuan) → beresin must/should-fix → commit.

## State (SELESAI, pushed)
- `3553610` Langkah 1: `template/.claude/settings.json` allowlist (git read-only + add/commit) + deny foot-gun; `wire` step 5.5 append perintah verifikasi per-stack (GATE); build reference §D rem run-level (circuit breaker 2-blocked + cap-volume 10-task) + cek allowlist awal run.
- `fbeba86` Langkah 2: hooks `on-stop.sh`/`on-permission.sh` (notif deterministik; on-permission TIDAK auto-approve); build tulis `last-run.md` + penanda `.unattended`/`.unattended-stop`; Q&A first-unattended tulis `notify.sh`; `init` salin `.claude/`+gitignore. Sumber-kebenaran = laporan disk, notif best-effort.
- `6f6f83a` Langkah 3: build tulis header `outcome: continue|done|halt` (+done/pending/reason) baris-1 `last-run.md`; reference §H resep dua engkol `drive.sh` (bash, fresh `claude -p`/putaran, backstop halt/nol-kemajuan/deadline) + `/schedule`; `init` salin+chmod drive.sh.
- `ce49377` skill **`upgrade`** (ke-22): migrasi produk lama → template terbaru, presence-based, idempoten, nol-sentuh-knowledge, GATE tiap tulis.

## Decisions (terkunci)
- Driver = resep terdokumentasi + skrip ter-ship (`drive.sh`), BUKAN skill — loop hidup di luar (bash/cron). `/loop` BUKAN engkol: akumulatif sesi-sama, bukan fresh; fresh context cuma dari PROSES BARU.
- Notif via HOOK (deterministik), bukan model-panggil-sendiri — model tak bisa kabari diri saat beku.
- Cap = jumlah-task (proxy), bukan ukur context (tak ada meteran context yang kebaca model).
- `upgrade` scope LEBAR: `.claude/` + tambah `control/` skeleton HILANG; tapi `control/` existing HARAM disentuh. `control/schema/` = generated runtime (wire/build), BUKAN skeleton template.
- Nol gate keamanan dilonggarin di semua langkah. Floor (needs_human/blocked/migrate/security) = tembok; driver tak pernah restart `halt`; tak ada auto-merge/auto-ship.
- Skill auto-discovered (tak ada registry fungsional); nambah skill = doc-sync ke: README, induk spec §17 count + §8 tree, plugin.json desc, marketplace.json desc.

## Pointers
- Roadmap + status detail: memory `loop-engineering-roadmap.md` (di `~/.claude/projects/.../memory/`).
- Pola kerja user: memory `explain-before-changing.md` — user belajar konsep sambil bangun; "jelasin dulu" = STOP setelah jelasin, jangan edit sampai "gas".
- Skill baru: `plugin/skills/upgrade/SKILL.md`. Driver: `plugin/template/.claude/drive.sh` + hooks. Mekanik M7: `plugin/skills/build/reference.md` §G (notif) + §H (driver), §D (rem).
- Spec M7: `docs/superpowers/specs/2026-06-06-m7-graduated-autonomy-design.md` (ada amendemen pasca-spec untuk notif + driver di bawah §7).

## Gotchas
- Workflow JS: `${...}` mentah di string prompt ke-eval JS → parse error/crash. Escape `\${...}` atau parafrase (kena 2× sesi ini: `CLAUDE_PROJECT_DIR`, `${done_now:-0}`).
- Headless `claude -p` (drive.sh) TAK bisa Q&A interaktif → notify.sh harus diset via 1× `build --unattended` interaktif DULU sebelum drive.sh.
- Skill-count "21" di `docs/superpowers/plans/*` lama = dok historis frozen, JANGAN diedit (bukan staleness; nyatet scope-nya sendiri). Yang living (induk §17) = 22.
- Verify langganan nemu "parent-doc staleness" (README/plugin.json/marketplace/induk) tiap nambah file/skill — selalu cek 5 titik.
