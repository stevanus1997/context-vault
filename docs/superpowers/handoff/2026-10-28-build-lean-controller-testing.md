# Handoff — uji lanjutan "controller build ramping" (0.28.x)

Dokumen ini buat melanjutkan pengujian di sesi baru. Baca dulu, lalu jalankan langkah di bagian **Cara cek ulang**.

- **Spec:** `docs/superpowers/specs/2026-10-20-build-lean-controller-design.md`. §9 berisi tabel baseline vs sesudah + evaluasi; §10 berisi amandemen D13–D17.
- **Plan (sudah dieksekusi):** `docs/superpowers/plans/2026-10-20-build-lean-controller.md`
- **Versi sekarang:** 0.28.2 (`f73d676` di `origin/main`).

## Apa yang dibangun (ringkas)

Tujuannya: sesi controller `/context-vault:build` mulai kecil dan context-nya nggak numpuk per task.

- **`build_status.py --format controller|task|carry`.** Controller membaca peta 1 baris per task plus READY/hold/gate/staleness/reuse basi/korup/titipan, tanpa baca `tasks.yaml` utuh. `task` membawa `line`/`end_line` dan `carry` membawa `line_no` (pengganti Grep).
- **Agent `context-vault:brief-writer`** (`plugin/agents/brief-writer.md`, `model: inherit`) yang merakit brief. Controller nggak baca kode demi brief.
- **`reference.md` = indeks**, isinya di `plugin/skills/build/reference/{a..k}-*.md` dan dibaca per step. §J = ringkasan state + titipan, §K = bentuk prompt dispatch.
- **Titipan antar-task resmi** di `<work-item>/carry.yaml`, entri terbaru di atas. `_carry-notes.md` lama dikonversi sekali.
- **Reviewer:** paket diff selalu lewat git, reviewer dikasih path template, verdict ringkas + `catatan:`, dan batas 3 ronde nggak diubah (keputusan desain user).
- **Allowlist template:** `Bash(python3 .claude/build_status.py:*)`, `Read(~/.claude/plugins/cache/**)`, `Read(~/.claude/plugins/installed_plugins.json)`.

## Rilis susulan & alasannya

| Versi | Commit | Isi |
|---|---|---|
| 0.28.0 | `856084a`…`55115c2` | eksekusi plan + 2 ronde review independen (fix Read headless, tanpa Grep/Glob, penanda peta, for: multi-target, dst.) |
| — | `65182e5` | alat ukur kenali format CC 2.1.30x (`agent_id:`/`name:`, `<teammate-message teammate_id>`) |
| 0.28.1 | `7b2a4b9` | balikan subagent dikirim SEKALI (agent bernama: SendMessage + teks akhir `.`) · brief-writer pakai default sebelum lapor `ambigu:` · metrik total kenaikan ÷ task |
| 0.28.2 | `f73d676` | balikan implementer maks 6 baris (template superpowers bolehkan 15) · reviewer dilarang ⚠️ untuk klaim test/lint/commit · spec §9 kolom Sesudah diisi |

## Status produk

- **mahjong** (`~/Developer/project/mahjong`) dan **lora** (`~/Developer/BFI/lora`): sudah di-`/upgrade`. `build_status.py` = template terbaru, ketiga allowlist ada. venue-tables sudah punya `carry.yaml` (157 entri, 143 dari legacy, `legacy_converted`).
- Plugin dipasang dari **marketplace directory** (`~/Developer/project/context-vault`). CC menjalankannya **dari folder repo** `…/context-vault/plugin`, BUKAN dari cache. Lihat follow-up #1.
- Supaya perubahan prosa terpakai: `/plugin marketplace update context-vault` lalu `/reload-plugins`. Produk nggak perlu di-upgrade ulang kecuali `template/.claude/*` berubah.

## Angka terakhir (2026-10-28)

Baseline = 50 sesi build mahjong sebelum perubahan. "Sesudah" = 4 sesi dengan ≥3 task, 53 task (mahjong `6de3fd82` 0.28.0, `4d5ab4f2` 0.28.0, `7aae28da` 0.28.1; lora `1c654c73` 0.28.1).

| Metrik | Baseline | Sesudah | Target spec |
|---|---|---|---|
| **Total kenaikan context ÷ task** (metrik utama) | 50.2K | **28.6K (−43%)**; lora 22K, mahjong 0.28.1 26K | — |
| Context di dispatch implementer pertama | 181.5K | median 158K; 104K di sesi yang langsung dispatch | ≤95K ✗ |
| Pertumbuhan per dispatch implementer | 27.6K | 23.1K; lora 13.9K | ≤10K ✗ |
| Ronde review / task | 0.97 | 1.0 | ✓ (±20%) |
| NEEDS_CONTEXT / task | 0.04 | 0.04 | ✓ |
| blocked / task | 0.0026 | 0 | ✓ |
| ⚠️ / review | 0.25 | **1.38** | ✗ → diperbaiki di 0.28.2 |
| `ambigu:` brief-writer / task | — | 0.48 (0.8 di 0.28.0) | — |

**Catatan cara membaca:**
- ctx@impl1 bias kalau sesi dibuka gate/mockup/pre-flight (smoke, screenshot, keputusan user). Contohnya: `6de3fd82` gate M4 → 178K, `4d5ab4f2` mockup T73 → 153K, lora pre-flight 3 keputusan → 163K. Pakai **total kenaikan ÷ task** sebagai metrik utama.
- Pembanding "(NEEDS_CONTEXT + ambigu) vs NEEDS_CONTEXT baseline" di §9 tidak setara. Dulu ambiguitas yang sama diputus diam-diam oleh controller. Sudah dicatat di §9.

**Yang harus turun di sesi 0.28.2 berikutnya:**
- ⚠️/review (sebelumnya 1.38; ≈separuh adalah "klaim report");
- ukuran balikan implementer (median 3K karakter / 23 baris → target ≤6 baris);
- `ambigu/task`.

## Cara cek ulang

1. **Cari sesi build sesudah tanggal tertentu** + versi plugin yang dipakai. Penanda: teks `Balikan SEKALI` = ≥0.28.1, `MAKS 6 baris` = ≥0.28.2.
   ```bash
   python3 -I - <<'EOF'
   import glob, os, time
   cut = time.mktime(time.strptime('2026-10-28 12:00', '%Y-%m-%d %H:%M'))
   for f in sorted(glob.glob(os.path.expanduser('~/.claude/projects/*/*.jsonl')), key=os.path.getmtime):
       if os.path.getmtime(f) < cut: continue
       t = open(f, errors='replace').read()
       if '<command-name>/context-vault:build' in t or '"skill":"context-vault:build"' in t:
           v = '0.28.2' if 'MAKS 6 baris' in t else '0.28.1' if 'Balikan SEKALI' in t else '≤0.28.0'
           print(time.strftime('%m-%d %H:%M', time.localtime(os.path.getmtime(f))), f.split('/projects/')[1][:70], v)
   EOF
   ```
2. **Ukur.** Jalankan dari root repo context-vault. Di zsh, path glob jangan dikumpulkan ke satu variabel; panggil per file atau per direktori.
   ```bash
   python3 tools/measure-build-context.py ~/.claude/projects/-Users-mac-098506-Developer-project-mahjong/<id>*.jsonl
   python3 tools/measure-build-context.py --json <file.jsonl> | python3 -m json.tool | less
   ```
   Field per sesi: `ctx_first_impl`, `growth_median`, `growth_per_task_total`, `tasks`, `brief_tasks`, `ambiguity_tasks`, `review_dispatches`, `needs_context_tasks`, `blocked_tasks`, `cannot_verify`, `attribution{skillref,state,code,agent,other}` (karakter).
3. **Bedah ukuran balikan subagent** (cek 0.28.2 bekerja): median ukuran hand-back per jenis dispatch.
   ```bash
   python3 -I - <session.jsonl> <<'EOF'
   import json, sys, re, statistics as st
   recs = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
   kind, aid = {}, {}
   for r in recs:
       if r.get('type') == 'assistant':
           for b in r['message'].get('content', []):
               if b.get('type') == 'tool_use' and b['name'] == 'Agent':
                   i = b['input']; p = i.get('prompt') or ''
                   kind[b['id']] = 'brief' if i.get('subagent_type') == 'context-vault:brief-writer' else 'review' if '.diff' in p and '-report.md' in p else 'impl' if '-report.md' in p else (i.get('subagent_type') or 'other')
       if r.get('type') == 'user' and isinstance(r['message'].get('content'), list):
           for b in r['message']['content']:
               if b.get('type') == 'tool_result' and b['tool_use_id'] in kind:
                   for a in re.findall(r'(?:agentId|agent_id):\s*([A-Za-z0-9_-]+)', json.dumps(b.get('content'))): aid[a] = kind[b['tool_use_id']]
   sizes = {}
   for r in recs:
       if r.get('type') != 'user': continue
       c = r['message'].get('content'); t = c if isinstance(c, str) else json.dumps(c, ensure_ascii=False)
       m = re.search(r'<(?:agent-message from|teammate-message teammate_id)="([^"]+)"', t)
       if not m: continue
       i = t.find('The report follows:'); body = t[i + 19:] if i > 0 else t
       sizes.setdefault(aid.get(m.group(1), m.group(1).split('-')[0]), []).append((len(body), body.count('\n')))
   for k, v in sorted(sizes.items(), key=lambda x: -sum(n for n, _ in x[1])):
       print(f"{k:10} n={len(v):3} total={sum(n for n,_ in v):6} median={int(st.median([n for n,_ in v]))} baris_med={int(st.median([l for _,l in v]))}")
   EOF
   ```
4. **Trace pertumbuhan context per tool call** buat mencari biang kenaikan:
   ```bash
   python3 -I - <session.jsonl> <<'EOF'
   import json, sys
   prev = 0
   for l in open(sys.argv[1]):
       r = json.loads(l) if l.strip() else {}
       if r.get('type') != 'assistant': continue
       u = r['message'].get('usage', {}); c = sum(u.get(k, 0) for k in ('input_tokens', 'cache_read_input_tokens', 'cache_creation_input_tokens'))
       for b in r['message'].get('content', []):
           if b.get('type') == 'tool_use':
               i = b['input']; print(c, f"(+{c - prev})", b['name'], i.get('subagent_type', ''), '|', (i.get('description') or i.get('command') or i.get('file_path') or '')[:100].replace('\n', ' ')); prev = c
   EOF
   ```
5. Kalau ada ≥3 sesi 0.28.2 baru: perbarui tabel §9 spec (tambah kolom/baris 0.28.2), lalu putuskan follow-up.

## Fakta harness yang sudah terbukti (jangan diulang)

Detail ada di memori `claude-code-headless-read-and-tools.md`.

- CC 2.1.27x–2.1.312 **tidak punya tool Grep/Glob**. Prosa plugin jangan menyuruhnya.
- `claude -p --permission-mode acceptEdits` (jalur `drive.sh`) **menolak Read di luar root produk**, baik dari sesi utama maupun subagent, termasuk file plugin sendiri. Ini dibuka dengan aturan `Read(~/.claude/plugins/cache/**)`. Probe dengan `claude -p … --settings '{"permissions":{"allow":[…]}}'` dari temp dir `git init`.
- **Agent bernama** (`name:`) di CC 2.1.30x adalah teammate. Hasilnya datang lewat `<teammate-message>` + `idle_notification` yang membawa teks akhir → bisa dobel. Di 0.28.1 controller dispatch **tanpa `name`** → nol duplikat. Pembungkus hand-back harness ~550 karakter per dispatch tak bisa dihindari.
- `installed_plugins.json` → `plugins["<nama>@<marketplace>"][0].installPath` untuk path plugin bernomor versi tanpa Bash `ls`.

## Follow-up yang masih ditunda (urut usulan)

Juga dicatat di memori `build-lean-controller-followups.md`.

1. **Plugin dari marketplace directory jalan dari folder repo** → `Read(~/.claude/plugins/cache/**)` tak menyakup file plugin user → di unattended, brief-writer dan reference tetap ditolak (degrade (c)). Probe 2026-10-20: `Read(~/Developer/project/context-vault/plugin/**)` lolos. Fix: `upgrade`/`init` menambah `Read(<CLAUDE_PLUGIN_ROOT>/**)` bila root plugin di luar `~/.claude/plugins/cache`; degrade (c) SKILL ikut mengenalinya.
2. **Resmikan fallback attended:** kalau salinan produk `build_status.py` lama, controller boleh pakai `python3 ${CLAUDE_PLUGIN_ROOT}/template/.claude/build_status.py --root . …` + WARN upgrade. Model sudah mengimprovisasi ini di dua sesi.
3. **SKILL.md bengkak** (44.4K → 51.2K karakter, ~15.6K token di tiap awal sesi). Sesi resume tetap membaca ~37K dari 64K karakter reference (terbesar §D 11.4K, §I 9.4K). Ini poin 4 lama: pisah cabang unattended ke file sendiri + rampingkan §D/§K. Butuh spec sendiri.
4. **7a `git symbolic-ref` tak di-allowlist** di unattended, dan fallback-nya "TANYA" yang mustahil di unattended. Kandidat: `git -C <P> rev-parse --abbrev-ref origin/HEAD` (sudah di-allowlist), selaraskan dengan `ship`.
5. **Audit superpowers 6.2–7.0** + putuskan adopsi re-review scoped / resume implementer. **Batas 3 ronde = keputusan desain user, jangan diubah tanpa persetujuan.**

## Aturan kerja di repo ini

- **Commit:** pesan Indonesian + prefix conventional-commits, **tanpa** trailer `Co-Authored-By`.
- **Rilis:** bump `plugin/.claude-plugin/plugin.json` **dan** dua field `version` di `.claude-plugin/marketplace.json`, lalu `bash tools/build-kimi.sh` (jangan edit `plugin-kimi/` dengan tangan).
- **Test semua sebelum commit:**
  ```bash
  for t in tools/tests/*.test.sh plugin/hooks/tests/*.test.sh; do bash "$t" >/dev/null 2>&1 && echo "ok $t" || echo "FAIL $t"; done
  claude plugin validate plugin
  ```
  Hapus `plugin/**/__pycache__` kalau `share.test` gagal di S7.
- **Edit prosa:** anchor kutipan teks harus muncul tepat sekali (`count == 1`) sebelum diganti. Untuk patch banyak pasangan, tulis script ke file; heredoc bertumpuk kutip gampang rusak.
- **Push:** remote butuh akun `stevanus1997`. Akun aktif harus balik ke `stevanusbfi` sesudahnya:
  ```bash
  bash -c 'set -e; trap "gh auth switch --user stevanusbfi >/dev/null 2>&1" EXIT
  gh auth switch --user stevanus1997 >/dev/null
  git -c credential.helper="!gh auth git-credential" fetch -q origin
  git merge-base --is-ancestor origin/main main || { echo STOP; exit 1; }
  git -c credential.helper="!gh auth git-credential" push -q origin main'
  ```
