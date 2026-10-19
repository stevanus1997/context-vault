# Titik Tunggu Attended lewat `AskUserQuestion` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Di mode attended, tiap titik tunggu skill (gate approve/revisi, Q&A keputusan, konfirmasi) ditanya lewat `AskUserQuestion`, supaya push native Remote Control ("Push when actions required") bunyi di HP user. Pengecualiannya `discovery` dan `init`.

**Architecture:** Satu aturan terpusat `plugin/rules/ask-user.md` (cara penyajian; isi Q&A tetap di `elicitation.md`). Tiap `SKILL.md` yang punya titik tunggu mendapat SATU baris rujukan yang identik, tepat di bawah H1. Baris itu memuat inti instruksinya juga, jadi tetap jalan walau model tidak membuka file aturan. Satu edit khusus di drain pagi `build`, tip setup push di `guide` + README, catatan di harness Kimi, lalu bump versi.

**Tech Stack:** Markdown skill (Claude Code plugin) · test bash (`tools/tests/*.test.sh`, pola counter PASS/FAIL) · Python 3 stdlib (skrip sisip sekali-jalan) · generator `tools/build-kimi.sh`.

**Spec:** `docs/superpowers/specs/2026-10-19-attended-ask-push-design.md`. Baca dulu: plan ini berargumen dari spec itu.

## Global Constraints

- Basis: `main` sesudah `0e7acf9` (commit spec). Skill `share` sudah landed (`9ee57b4`), jadi ikut cakupan.
- File aturan: `plugin/rules/ask-user.md`.
- **Baris rujukan SKILL.md, persis byte-per-byte (satu baris):**
  ```
  > **Titik tunggu attended → `AskUserQuestion`:** tiap gate approve/revisi, Q&A keputusan, & konfirmasi yang nunggu jawaban user — tulis konten (draft/diff/ringkasan) sebagai teks DULU, lalu tanya lewat tool `AskUserQuestion` (pertanyaan pendek, opsi bawa konsekuensi); JANGAN akhiri turn dengan pertanyaan teks (tak memicu push Remote Control). Unattended/headless tetap tak pernah bertanya. Detail: `${CLAUDE_PLUGIN_ROOT}/rules/ask-user.md`.
  ```
  Posisinya: H1 → baris kosong → baris rujukan → baris kosong → isi lama (`Tujuan: …`). Artinya nomor barisnya = nomor baris H1 + 2.
- **Skill TANPA baris rujukan:** `discovery`, `init` (dikecualikan user, spec D10), `render-docs` (tidak punya titik tunggu; grep cue gate/approve/tanya/tawar/konfirmasi = 0). Ketiga `SKILL.md` itu TIDAK disentuh sama sekali. Ke-23 skill lainnya wajib punya baris rujukan.
- Baris rujukan **tidak boleh memuat kata "subagent"**. `tools/build-kimi.sh` menyuntik pointer harness ke tiap `SKILL.md` yang memuat kata itu.
- Jangan sentuh hook (`plugin/template/.claude/hooks/*`), `drive.sh`, `notify.sh`, atau perilaku unattended apa pun (spec §7).
- Jangan edit `plugin-kimi/` langsung. Selalu regen lewat `bash tools/build-kimi.sh` (test `build-kimi.test.sh` juga menjalankan generator).
- Versi rilis: naik minor dari versi saat eksekusi (`0.24.0` → `0.25.0`, kalau masih `0.24.0`).
- Bahasa Indonesia (santai, sesuai skill lain). Commit tanpa trailer `Co-Authored-By`. Footer `Claude-Session:` diisi id sesi yang mengeksekusi (bila ada).
- Semua edit "Ganti … dengan …" di plan ini **persis**. Anchor `old` sudah dicek muncul tepat 1× di file saat plan ditulis.

## Review Focus

1. **Run unattended/headless membaca baris rujukan baru.** Run itu tetap tidak boleh memanggil `AskUserQuestion` (beku/tak ada yang jawab). Pin: Task 1 R2 (`Unattended/headless: DILARANG` di aturan), Task 2 S2 (baris persis memuat "Unattended/headless tetap tak pernah bertanya").
2. **Skill punya menu lebih dari 4 pilihan** (batas tool 2–4 opsi). Model harus mengelompokkan/memecah, bukan memotong diam-diam. Pin: Task 1 R2 (`Pilihan > 4`).
3. **Skill baru ditambah nanti tanpa baris rujukan.** Push diam-diam mati untuk skill itu. Pin: Task 2 S2 mengenumerasi SEMUA folder `plugin/skills/*/`, jadi skill baru gagal test sampai diberi baris atau dimasukkan ke daftar pengecualian.
4. **Kata "subagent" masuk ke baris rujukan.** Generator Kimi lalu menyuntik pointer harness ke 23 skill yang tidak men-dispatch apa pun. Pin: Task 2 S0 + test pointer XOR yang sudah ada di `build-kimi.test.sh`.
5. **Kotak menutupi konten gate yang panjang** (bug yang pernah user alami). Pin: Task 1 R2 (`Konten dulu, kotak belakangan`) + uji penerimaan manual langkah 3.

---

## File Structure

| Path | Tanggung jawab |
|---|---|
| `plugin/rules/ask-user.md` (BARU) | Kontrak penyajian titik tunggu attended: kapan pakai kotak, urutan konten→kotak, gate, Q&A, pertanyaan terbuka, batas tool, pengecualian. |
| `plugin/rules/elicitation.md` | Pointer: penyajian diatur `ask-user.md`, isi tetap di sini. |
| `plugin/skills/<23 skill>/SKILL.md` | Satu baris rujukan di bawah H1. |
| `plugin/skills/build/reference.md` | Drain pagi: satu gate = satu panggilan. |
| `plugin/skills/guide/reference.md`, `README.md` | Tip setup push. |
| `tools/build-kimi.sh`, `tools/tests/build-kimi.test.sh` | Catatan `AskUserQuestion` di `kimi-harness.md` hasil generate + test-nya. |
| `tools/tests/ask-user.test.sh` (BARU) | Satu runner: bagian R (aturan), S (rujukan skill), D (tip docs). |
| `plugin/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` | Bump versi. |
| `plugin-kimi/` | Regenerate. |

---

### Task 1: Aturan `rules/ask-user.md` + pointer di `elicitation.md`

**Files:**
- Create: `plugin/rules/ask-user.md`
- Modify: `plugin/rules/elicitation.md` (paragraf pembuka)
- Test: `tools/tests/ask-user.test.sh` (BARU)

**Interfaces:**
- Produces: file `plugin/rules/ask-user.md` yang memuat frasa kunci (masing-masing utuh dalam SATU baris): `AskUserQuestion`, `Konten dulu, kotak belakangan`, `Push when actions required`, `Unattended/headless: DILARANG`, ``Dikecualikan: `discovery` & `init` ``, `Subagent tidak memanggil`, `Pilihan > 4`. Runner `tools/tests/ask-user.test.sh` berakhir dengan baris `echo "---"; echo "pass=$PASS fail=$FAIL"`, yang jadi anchor sisip bagian test di Task 2 dan 3.

- [ ] **Step 1: Tulis test (failing)**

Create `tools/tests/ask-user.test.sh` (`chmod +x`):
```bash
#!/usr/bin/env bash
# Test aturan titik tunggu attended (rules/ask-user.md) — jalanin: bash tools/tests/ask-user.test.sh (exit 0 = semua lulus)
# Pola sama dengan tools/tests/build-kimi.test.sh (counter PASS/FAIL).
# Spec: docs/superpowers/specs/2026-10-19-attended-ask-push-design.md
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/plugin"
RULE="$SRC/rules/ask-user.md"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; }

# --- R. aturan rules/ask-user.md ---
[ -f "$RULE" ] && ok "R1 rules/ask-user.md ada" || bad "R1 rules/ask-user.md hilang"
for kw in 'AskUserQuestion' 'Konten dulu, kotak belakangan' 'Push when actions required' 'Unattended/headless: DILARANG' 'Dikecualikan: `discovery` & `init`' 'Subagent tidak memanggil' 'Pilihan > 4'; do
  grep -qF -- "$kw" "$RULE" 2>/dev/null && ok "R2 aturan memuat: $kw" || bad "R2 aturan tanpa: $kw"
done
grep -qF 'rules/ask-user.md' "$SRC/rules/elicitation.md" \
  && ok "R3 elicitation.md menunjuk ask-user.md" || bad "R3 elicitation.md tanpa pointer ask-user.md"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `bash tools/tests/ask-user.test.sh`
Expected: R1, ketujuh R2, dan R3 `FAIL`; exit ≠ 0.

- [ ] **Step 3: Buat `plugin/rules/ask-user.md`**

Isi persis:
````markdown
# Ask-user — Titik Tunggu Attended lewat `AskUserQuestion`

Dirujuk semua skill yang berhenti nunggu jawaban user di mode attended (kecuali
`discovery` & `init` — lihat Batas). Tujuan: user yang nyetir sesi dari HP
(Remote Control) DIKABARI tiap kali skill nunggu dia. Push native Claude Code
(**Push when actions required** di `/config`) cuma bunyi untuk permission prompt
dan kotak `AskUserQuestion`. Turn yang berakhir dengan pertanyaan teks TIDAK
memicu push, jadi user nggak tahu ada yang nunggu.

`elicitation.md` mengatur ISI Q&A (apa yang ditanya, opsi bawa konsekuensi);
file ini mengatur PENYAJIAN-nya (lewat apa & urutannya).

## Kontrak
- **Titik tunggu = `AskUserQuestion`, bukan akhir turn ber-pertanyaan teks.**
  Titik tunggu = gate approve/revisi, Q&A keputusan, konfirmasi (yes/no, pilih
  fitur/opsi, "lanjut `/ship`?") — apa pun yang bikin skill berhenti sampai
  user jawab.
- **Konten dulu, kotak belakangan.** Di turn yang sama: tulis dulu semua yang
  harus dibaca sebagai teks biasa (draft/artifact, ringkasan diff, Challenge
  Checklist, tradeoff panjang), BARU panggil `AskUserQuestion`. Pertanyaan di
  kotak pendek & merujuk konten di atas (mis. *"Approve draft business.md di
  atas?"*). Kotak TIDAK mengulang/menggantikan konten — kotak bisa nutupin
  teks panjang.
- **Gate approve/revisi:** minimal opsi **Approve** & **Revisi**; `description`
  tiap opsi = konsekuensinya (mis. "Approve → tulis business.md, lanjut
  fanout"). Catatan revisi lewat "Other" (disediakan otomatis oleh tool). Opsi
  khas skill (Drop/Regen/…) boleh, total tetap 2–4.
- **Q&A keputusan** (isi tetap `elicitation.md`): satu keputusan-bercabang =
  satu panggilan, satu pertanyaan; 2–4 opsi, `description` = 1 baris
  konsekuensi; "Other" = jalan keluar menu ("ceritain versimu sendiri"); TANPA
  label "(Recommended)" untuk keputusan high-impact/ireversibel. Konfirmasi
  sepele boleh digabung — maks 4 pertanyaan per panggilan.
- **Pertanyaan terbuka** ("ceritain alurnya"): susun 2–4 tebakan dari
  knowledge/kode sebagai opsi + "Other" buat versi user. Pertanyaan teks HANYA
  bila benar-benar tak ada tebakan bermakna (konsekuensi: tanpa push).
- **Input bebas yang bukan keputusan** (mis. paste blok feedback `share`, tempel
  log/error) → minta lewat teks biasa; keputusan SESUDAH input itu → kotak.
- **Batas tool:** 1–4 pertanyaan per panggilan, 2–4 opsi per pertanyaan,
  `header` ≤ 12 karakter, `multiSelect` bila pilihan tak saling eksklusif.
  JANGAN bikin opsi "Lainnya/Other" sendiri — sudah otomatis.
- **Pilihan > 4** (mis. menu bagian `guide`, daftar fitur): kelompokkan jadi
  ≤ 4 opsi (sisanya disebut di teks konten, bisa dipilih lewat "Other") ATAU
  pecah jadi 2 pertanyaan berurutan. Jangan memotong pilihan diam-diam.
- **Bukan titik tunggu → teks biasa.** Laporan selesai yang tak nunggu apa-apa
  = teks. Laporan yang ditutup pertanyaan → pertanyaannya masuk kotak.

## Batas
- **Unattended/headless: DILARANG.** Tetap berlaku aturan "JANGAN PERNAH nanya
  interaktif" (`build`): pertanyaan jadi entri `queued`/`hold:`, notif lewat
  hook + `notify.sh` seperti biasa.
- **Subagent tidak memanggil `AskUserQuestion`** — implementer/reviewer/critic
  mengembalikan pertanyaan ke controller (pola existing); controller yang
  bertanya ke user lewat kotak.
- **Dikecualikan: `discovery` & `init`** — tetap bertanya dengan teks biasa.
  `discovery` sengaja elicit-first (operator cerita bebas; AI baru mengusulkan
  isi saat operator bilang "gak tau/terserah" → `AI-usul`); sebelum `init`
  belum ada knowledge/kode buat bahan tebakan, jadi opsi akan mengarang dan
  menyetir jawaban. Skill yang di-chain dari situ (mis. `discovery` →
  `roadmap`) ikut aturan skill-nya sendiri.
- **Gate ≠ interogasi** (`elicitation.md`) tetap berlaku: kotak tidak mengubah
  gate jadi tanya-jawab beruntun.
- **Push butuh setup user, sekali:** app Claude login di akun yang sama + izin
  notif OS + `/config` → Push when actions required. Tanpa itu kotak tetap
  jalan (cuma HP nggak bunyi). Push di-skip selama user fokus/ngetik di
  terminal yang terhubung.
- **Plan B (belum dipakai):** kalau kotak sering nutupin penjelasan → hook
  `Stop` → `notify.sh` di attended, lewat spec terpisah. Spec asal:
  `docs/superpowers/specs/2026-10-19-attended-ask-push-design.md`.
````

- [ ] **Step 4: Pointer di `plugin/rules/elicitation.md`**

Ganti:
```
tembakan, bukan "asal pilih recommended".
```
dengan:
```
tembakan, bukan "asal pilih recommended".

**Penyajian** (kanal tanya `AskUserQuestion`, urutan konten-dulu-kotak-belakangan,
batas tool) diatur `rules/ask-user.md`; file ini mengatur ISI-nya.
```

- [ ] **Step 5: Jalankan test, pastikan lulus**

Run: `bash tools/tests/ask-user.test.sh`
Expected: `pass=9 fail=0`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add plugin/rules/ask-user.md plugin/rules/elicitation.md tools/tests/ask-user.test.sh
git commit -m "feat(rules): ask-user — titik tunggu attended lewat AskUserQuestion (push Remote Control)"
```

---

### Task 2: Baris rujukan di 23 skill + drain pagi `build`

**Files:**
- Modify: `plugin/skills/{add-app,add-integration,add-package,architect,ask,breakdown,build,debt,design-system,drop,extract,fanout,feature,fix,guide,intake,plan,roadmap,share,ship,tweak,upgrade,wire}/SKILL.md` (sisip 2 baris di bawah H1)
- Modify: `plugin/skills/build/reference.md` (§I drain pagi, kalimat "approve / revisi — per gate")
- Test: `tools/tests/ask-user.test.sh` (sisip bagian S)

**Interfaces:**
- Consumes: `plugin/rules/ask-user.md` (Task 1). Anchor ringkasan runner (Task 1).
- Produces: baris rujukan persis (Global Constraints) di 23 skill.

> Catatan: spec §6 minta frasa gate per-skill diselaraskan bila bertentangan. Grep frasa yang menyuruh mengakhiri turn dengan pertanyaan teks di jalur attended (`akhiri turn|ketik |balas |jawab dengan|reply`, di luar `discovery`/`init`) = nihil saat plan ditulis. Satu-satunya hit adalah larangan unattended di `build/reference.md` §G. Jadi tak ada frasa gate per-skill yang perlu diubah: edit minimal, alur skill tidak ditulis ulang.

- [ ] **Step 1: Tulis test bagian S (failing)**

Di `tools/tests/ask-user.test.sh`:

Ganti:
```
echo "---"; echo "pass=$PASS fail=$FAIL"
```
dengan:
```
# --- S. baris rujukan di SKILL.md (tepat sekali, 2 baris di bawah H1) ---
LINE='> **Titik tunggu attended → `AskUserQuestion`:** tiap gate approve/revisi, Q&A keputusan, & konfirmasi yang nunggu jawaban user — tulis konten (draft/diff/ringkasan) sebagai teks DULU, lalu tanya lewat tool `AskUserQuestion` (pertanyaan pendek, opsi bawa konsekuensi); JANGAN akhiri turn dengan pertanyaan teks (tak memicu push Remote Control). Unattended/headless tetap tak pernah bertanya. Detail: `${CLAUDE_PLUGIN_ROOT}/rules/ask-user.md`.'
EXCL=" discovery init render-docs "   # discovery/init = keputusan user (spec D10); render-docs = tanpa titik tunggu
case "$LINE" in
  *subagent*) bad "S0 baris rujukan memuat 'subagent' (generator kimi bakal nyuntik pointer)";;
  *)          ok  "S0 baris rujukan bebas kata 'subagent'";;
esac
for f in "$SRC"/skills/*/SKILL.md; do
  name="$(basename "$(dirname "$f")")"
  if [[ "$EXCL" == *" $name "* ]]; then
    grep -qF 'rules/ask-user.md' "$f" && bad "S1 $name dikecualikan tapi merujuk ask-user.md" || ok "S1 $name dikecualikan, bersih"
    continue
  fi
  n="$(grep -cxF -- "$LINE" "$f")"
  h="$(grep -n '^# ' "$f" | head -1 | cut -d: -f1)"
  l="$(grep -nxF -- "$LINE" "$f" | head -1 | cut -d: -f1)"
  if [ "$n" = 1 ] && [ -n "$h" ] && [ "$l" = "$((h+2))" ]; then
    ok "S2 $name: baris rujukan tepat sekali, 2 baris di bawah H1"
  else bad "S2 $name: baris rujukan (n=$n h1=$h baris=$l)"; fi
done
grep -qF 'Satu gate = satu panggilan `AskUserQuestion`' "$SRC/skills/build/reference.md" \
  && ok "S3 drain pagi: satu gate per panggilan" || bad "S3 drain pagi tanpa aturan satu gate per panggilan"

echo "---"; echo "pass=$PASS fail=$FAIL"
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `bash tools/tests/ask-user.test.sh`
Expected: S0 dan tiga S1 (`discovery`, `init`, `render-docs`) `ok`. Ke-23 S2 dan S3 `FAIL`. Bagian R tetap `ok`.

- [ ] **Step 3: Sisipkan baris rujukan ke 23 skill**

Jalankan sekali dari root repo. Skrip ini menolak jalan kalau rujukan sudah ada, atau kalau baris sesudah H1 tidak kosong:
```bash
python3 -B - plugin <<'PY'
import sys, pathlib
LINE = "> **Titik tunggu attended → `AskUserQuestion`:** tiap gate approve/revisi, Q&A keputusan, & konfirmasi yang nunggu jawaban user — tulis konten (draft/diff/ringkasan) sebagai teks DULU, lalu tanya lewat tool `AskUserQuestion` (pertanyaan pendek, opsi bawa konsekuensi); JANGAN akhiri turn dengan pertanyaan teks (tak memicu push Remote Control). Unattended/headless tetap tak pernah bertanya. Detail: `${CLAUDE_PLUGIN_ROOT}/rules/ask-user.md`."
EXCL = {"discovery", "init", "render-docs"}
root = pathlib.Path(sys.argv[1])
for f in sorted(root.glob("skills/*/SKILL.md")):
    if f.parent.name in EXCL:
        continue
    lines = f.read_text().split("\n")
    if any("rules/ask-user.md" in l for l in lines):
        sys.exit(f"sudah ada rujukan: {f}")
    fm = [i for i, l in enumerate(lines) if l == "---"][:2]
    h = next(i for i in range(fm[1] + 1, len(lines)) if lines[i].startswith("# "))
    if lines[h + 1] != "":
        sys.exit(f"baris sesudah H1 tidak kosong: {f}")
    lines[h + 1:h + 1] = ["", LINE]
    f.write_text("\n".join(lines))
    print("ok", f.parent.name)
PY
```
Expected: 23 baris `ok <skill>`, exit 0.

- [ ] **Step 4: Drain pagi di `plugin/skills/build/reference.md`**

Ganti:
```
→ **approve / revisi** — **per gate, TANPA "approve semua"** (sticky-approve dilarang M7).
```
dengan:
```
→ **approve / revisi** — **per gate, TANPA "approve semua"** (sticky-approve dilarang M7). Satu gate = satu panggilan `AskUserQuestion` sesudah konten gate itu tampil sebagai teks — jangan gabung beberapa gate dalam satu panggilan (`rules/ask-user.md`).
```

- [ ] **Step 5: Jalankan test, pastikan lulus**

Run: `bash tools/tests/ask-user.test.sh`
Expected: `pass=37 fail=0` (R 9 + S0 1 + S1 3 + S2 23 + S3 1), exit 0.

- [ ] **Step 6: Cek tiga skill pengecualian tak tersentuh**

Run: `git diff --quiet -- plugin/skills/discovery plugin/skills/init plugin/skills/render-docs && echo bersih`
Expected: `bersih`.

- [ ] **Step 7: Commit**

```bash
git add plugin/skills tools/tests/ask-user.test.sh
git commit -m "feat(skills): rujuk rules/ask-user.md di 23 skill + drain pagi satu gate per kotak"
```

---

### Task 3: Tip push di `guide` + README, catatan harness Kimi, regen

**Files:**
- Modify: `plugin/skills/guide/reference.md` (tabel cheatsheet)
- Modify: `README.md` (seksi baru sebelum `## Tanya produk (read-only)`)
- Modify: `tools/build-kimi.sh` (heredoc `kimi-harness.md`)
- Modify: `tools/tests/build-kimi.test.sh` (sesudah cek "mapping explore")
- Test: `tools/tests/ask-user.test.sh` (sisip bagian D)
- Regenerate: `plugin-kimi/`

**Interfaces:**
- Consumes: aturan (Task 1), baris rujukan (Task 2). Kimi Code punya tool bawaan bernama sama, `AskUserQuestion` (pilihan ganda terstruktur, auto-allowed). Sumber: Kimi Code CLI Quick Reference, https://www.kimi.com/resources/kimi-code-cheat-sheet, dicek 2026-10-19. Push native Remote Control khusus Claude Code.

- [ ] **Step 1: Tulis test (failing)**

Di `tools/tests/ask-user.test.sh`:

Ganti:
```
echo "---"; echo "pass=$PASS fail=$FAIL"
```
dengan:
```
# --- D. tip setup push di guide + README ---
grep -qF 'Push when actions required' "$SRC/skills/guide/reference.md" \
  && ok "D1 guide cheatsheet: tip push" || bad "D1 guide cheatsheet tanpa tip push"
grep -qF 'Push when actions required' "$ROOT/README.md" \
  && ok "D2 README: tip push" || bad "D2 README tanpa tip push"

echo "---"; echo "pass=$PASS fail=$FAIL"
```

Di `tools/tests/build-kimi.test.sh`:

Ganti:
```
  && ok "rules/kimi-harness.md ada + mapping explore" || bad "rules/kimi-harness.md hilang/kosong"
```
dengan:
```
  && ok "rules/kimi-harness.md ada + mapping explore" || bad "rules/kimi-harness.md hilang/kosong"
grep -q 'AskUserQuestion' "$DST/rules/kimi-harness.md" \
  && ok "kimi-harness.md mencatat AskUserQuestion" || bad "kimi-harness.md tanpa catatan AskUserQuestion"
[ -f "$DST/rules/ask-user.md" ] && grep -qF '${KIMI_SKILL_DIR}/../../rules/ask-user.md' "$DST/skills/build/SKILL.md" \
  && ok "ask-user.md ikut + rujukan SKILL.md ter-rewrite" || bad "ask-user.md / rujukan SKILL.md belum ikut ke plugin-kimi/"
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `bash tools/tests/ask-user.test.sh; bash tools/tests/build-kimi.test.sh`
Expected:
- `ask-user`: D1 dan D2 `FAIL`.
- `build-kimi`: "kimi-harness.md mencatat AskUserQuestion" `FAIL`. Cek "ask-user.md ikut" sudah `ok`, karena test menjalankan generator yang menyalin `rules/` dan me-rewrite path.

- [ ] **Step 3: Cheatsheet `plugin/skills/guide/reference.md`**

Ganti:
```
| Susulin produk lama ke template terbaru | `/upgrade` |
```
dengan:
```
| Susulin produk lama ke template terbaru | `/upgrade` |
| Dikabarin di HP tiap skill nunggu lo (attended, Remote Control) | sekali: `/config` → **Push when actions required** |
```

- [ ] **Step 4: Seksi README**

Ganti:
```
## Tanya produk (read-only)
```
dengan:
```
## Notif di HP (mode attended)
Nyetir sesi dari HP lewat Remote Control? Nyalain sekali di terminal: `/config` → **Push when actions required** (app Claude login di akun yang sama + izin notif OS). Tiap skill nunggu lo — gate approve/revisi, Q&A keputusan, konfirmasi, permission prompt — HP bunyi, karena titik tunggu attended ditanya lewat kotak `AskUserQuestion` (`rules/ask-user.md`; `discovery`/`init` dikecualikan, tetap teks biasa). Push di-skip selama lo fokus di terminal. Mode unattended tetap lewat `notify.sh`.

## Tanya produk (read-only)
```

- [ ] **Step 5: Catatan di `tools/build-kimi.sh`**

Ganti:
```
Root plugin = dua level di atas folder skill yang sedang jalan (`${KIMI_SKILL_DIR}/../..`).
```
dengan:
```
Root plugin = dua level di atas folder skill yang sedang jalan (`${KIMI_SKILL_DIR}/../..`).

**Titik tunggu attended (`rules/ask-user.md`):** Kimi Code punya tool bawaan `AskUserQuestion` (nama sama, pilihan ganda terstruktur, auto-allowed) → pakai apa adanya. Push native Remote Control khusus Claude Code — di Kimi kotaknya tetap jalan, tanpa push HP.
```

- [ ] **Step 6: Jalankan kedua test, pastikan lulus**

Run: `bash tools/tests/ask-user.test.sh && bash tools/tests/build-kimi.test.sh`
Expected: `ask-user` `pass=39 fail=0`; `build-kimi` `fail=0`. Generator sudah me-regen `plugin-kimi/`.

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/guide/reference.md README.md tools/build-kimi.sh tools/tests/build-kimi.test.sh tools/tests/ask-user.test.sh plugin-kimi
git commit -m "docs(guide,readme): tip push Remote Control + kimi-harness catat AskUserQuestion, regen plugin-kimi"
```

---

### Task 4: Rilis

**Files:**
- Modify: `plugin/.claude-plugin/plugin.json` (`"version"`)
- Modify: `.claude-plugin/marketplace.json` (`metadata.version` + `plugins[0].version`)
- Regenerate: `plugin-kimi/` (manifest version)

**Interfaces:**
- Consumes: semua task sebelumnya hijau.

- [ ] **Step 1: Pastikan versi sekarang**

Run: `jq -r .version plugin/.claude-plugin/plugin.json`
Expected: `0.24.0`. Kalau beda, versi baru = minor + 1 dari angka itu, dan perintah di Step 2 disesuaikan.

- [ ] **Step 2: Bump**

Run:
```bash
perl -pi -e 's/"version": "0\.24\.0"/"version": "0.25.0"/g' plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json
grep -c '"version": "0.25.0"' plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json
```
Expected: `plugin/.claude-plugin/plugin.json:1` dan `.claude-plugin/marketplace.json:2`.

- [ ] **Step 3: Regen + semua test**

Run: `bash tools/build-kimi.sh && bash tools/tests/build-kimi.test.sh && bash tools/tests/ask-user.test.sh`
Expected: `build-kimi` `fail=0` (termasuk "version manifest == version source"); `ask-user` `pass=39 fail=0`.

- [ ] **Step 4: Commit**

```bash
git add plugin/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugin-kimi
git commit -m "chore(release): bump 0.25.0 — share + titik tunggu attended lewat AskUserQuestion"
```
Body commit: dua paragraf ringkas, sesuai pola `caef940`.
- `share`: file HTML review fitur untuk rekan + triase feedback.
- `rules/ask-user.md`: titik tunggu attended → `AskUserQuestion` supaya push Remote Control bunyi; 23 skill merujuk; `discovery`/`init` dikecualikan; unattended tak berubah.

---

## Uji penerimaan (manual, oleh user, sesudah plugin di-reload)

1. Nyalakan `/config` → **Push when actions required**. App Claude harus login di akun yang sama dan izin notif OS sudah diterima.
2. Di produk nyata, jalankan `/tweak <x>` atau `/feature <x>` lewat Remote Control dari HP, lalu tinggalkan terminal.
3. Di gate pertama:
   - HP bunyi.
   - Konten gate (draft/Challenge Checklist) kebaca utuh di atas kotak.
   - Kotak berisi pertanyaan pendek dengan opsi Approve/Revisi plus konsekuensi.
4. Jawab "Other" dengan catatan revisi. Skill harus memperlakukannya sebagai revisi.
5. Jalankan `/discovery` di folder kosong. Pertanyaan visi tetap teks biasa (pengecualian).
6. Kalau kotak sering menutupi penjelasan → buka spec Plan B (hook `Stop` → `notify.sh`).
