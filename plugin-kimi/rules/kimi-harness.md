# Harness Kimi Code — mapping subagent

Kimi Code TIDAK punya custom agent file (padanan `agents/*.md` Claude tak ada).
Sub-agent yang tersedia hanya built-in: `coder` (baca+tulis+shell), `explore`
(read-only), `plan` (desain, tanpa shell). Sub-agent TIDAK menerima custom
system prompt → seluruh isi file agent dimasukkan sebagai bagian PROMPT tugas.

| Dispatch di skill | Di Kimi Code |
|---|---|
| subagent `context-vault:critic` | sub-agent `explore` (read-only); prompt = SELURUH isi `agents/critic.md` di root plugin (baca via Read) + konteks tugas |
| subagent `context-vault:security-critic` | sub-agent `explore`; prompt = SELURUH isi `agents/security-critic.md` di root plugin + diff/konteks |
| implementer / worker nulis-kode (build, fix, dst) | sub-agent `coder` |
| reviewer / reader read-only | sub-agent `explore` |

Root plugin = dua level di atas folder skill yang sedang jalan (`${KIMI_SKILL_DIR}/../..`).

**Titik tunggu attended (`rules/ask-user.md`):** Kimi Code punya tool bawaan `AskUserQuestion` (nama sama, pilihan ganda terstruktur, auto-allowed) → pakai apa adanya. Push native Remote Control khusus Claude Code — di Kimi kotaknya tetap jalan, tanpa push HP. Kimi versi lama tanpa tool itu → tanya dengan teks biasa.
