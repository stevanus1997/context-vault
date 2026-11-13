#!/usr/bin/env bash
# Test tools/release.sh — draft & publish di repo sementara + remote bare lokal + gh palsu.
# Jalanin: bash tools/tests/release.test.sh  (exit 0 = semua lulus)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REL="$ROOT/tools/release.sh"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL - $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
command -v jq >/dev/null 2>&1 || { echo "butuh jq"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL="$T/gitconfig" GIT_CONFIG_NOSYSTEM=1
git config --global user.name test; git config --global user.email test@example.com
git config --global init.defaultBranch main

# gh palsu: izin dari $FAKE_PERM, release tercatat di $T/releases/<tag>
mkdir -p "$T/bin" "$T/releases"
cat > "$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "repo view") echo "${FAKE_PERM:-WRITE}" ;;
  "release view") [ -f "$FAKE_REL/$3" ] ;;
  "release create")
    tag="$3"; shift 3; out="$FAKE_REL/$tag"; : > "$out.args"
    while [ $# -gt 0 ]; do
      case "$1" in --notes-file) cp "$2" "$out.body"; shift 2 ;; *) printf '%s\n' "$1" >> "$out.args"; shift ;; esac
    done
    touch "$out" ;;
  "auth git-credential") exit 0 ;;
  *) echo "gh palsu: tak dikenal: $*" >&2; exit 2 ;;
esac
EOF
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH" FAKE_REL="$T/releases"

git init -q --bare "$T/remote.git"
R="$T/repo"; git init -q "$R"; cd "$R" || exit 1
git remote add origin "$T/remote.git"
mkdir -p plugin/.claude-plugin .claude-plugin
setver() {  # setver <plugin.json> <marketplace>
  printf '{"name":"context-vault","version":"%s"}\n' "$1" > plugin/.claude-plugin/plugin.json
  printf '{"metadata":{"version":"%s"},"plugins":[{"name":"context-vault","version":"%s"}]}\n' "$2" "$2" > .claude-plugin/marketplace.json
}
commit() { git add -A; GIT_COMMITTER_DATE="$1" GIT_AUTHOR_DATE="$1" git commit -q -m "$2"; }

setver 0.1.0 0.1.0; commit 2026-01-10T10:00:00+07:00 "chore: rilis 0.1.0"; C1="$(git rev-parse HEAD)"
echo a > a.txt;      commit 2026-01-11T10:00:00+07:00 "feat: fitur a"
setver 0.1.0 0.2.0;  commit 2026-01-12T10:00:00+07:00 "chore: bump marketplace 0.2.0"; C2="$(git rev-parse HEAD)"
setver 0.3.0 0.3.0;  commit 2026-01-13T10:00:00+07:00 "chore: rilis 0.3.0"; C3="$(git rev-parse HEAD)"
git push -q origin main

notes() { printf 'title: %s\n\n\nReleased x.\n\n- item\n' "$2" > "$1"; }
notes "$T/n1.md" "First one"; notes "$T/n2.md" "Second"; notes "$T/n3.md" "Third"

# --- draft ---
out="$(bash "$REL" draft --ref "$C1" 2>&1)"
echo "$out" | grep -q '^VERSION v0.1.0' && echo "$out" | grep -q '^PREVIOUS (none)' \
  && ok "draft rilis pertama: versi + tanpa tag sebelumnya" || bad "draft rilis pertama" "$out"

out="$(bash "$REL" draft --ref "$C2" 2>&1)"; rc=$?
[ $rc -ne 0 ] && echo "$out" | grep -q 'tak sinkron' && ok "draft menolak manifest tak sinkron tanpa --version" || bad "draft manifest tak sinkron" "$out"

# --- publish: validasi ---
out="$(bash "$REL" publish "$T/n1.md" --ref "$C1" --dry-run 2>&1)"; rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q 'dry-run' && ! git rev-parse -q --verify refs/tags/v0.1.0 >/dev/null \
  && ok "publish --dry-run tidak bikin tag" || bad "publish --dry-run" "$out"

printf 'judul tanpa prefix\n\nisi\n' > "$T/bad.md"
out="$(bash "$REL" publish "$T/bad.md" --ref "$C1" 2>&1)"; rc=$?
[ $rc -ne 0 ] && echo "$out" | grep -q "title:" && ok "publish menolak file catatan tanpa 'title:'" || bad "publish tanpa title" "$out"

out="$(FAKE_PERM=READ bash "$REL" publish "$T/n1.md" --ref "$C1" 2>&1)"; rc=$?
[ $rc -ne 0 ] && echo "$out" | grep -q 'akses tulis' && ok "publish menolak akun gh tanpa akses tulis" || bad "publish izin READ" "$out"

echo b > b.txt; commit 2026-01-14T10:00:00+07:00 "feat: belum di-push"; CL="$(git rev-parse HEAD)"
out="$(bash "$REL" publish "$T/n3.md" --ref "$CL" --version 0.3.0 2>&1)"; rc=$?
[ $rc -ne 0 ] && echo "$out" | grep -q 'push dulu' && ok "publish menolak commit yang belum ada di remote" || bad "publish commit lokal" "$out"

out="$(bash "$REL" publish "$T/n2.md" --ref "$C2" --version 0.9.0 2>&1)"; rc=$?
[ $rc -ne 0 ] && echo "$out" | grep -q 'tidak ada di manifest' && ok "publish --version yang tak ada di manifest ditolak" || bad "publish --version salah" "$out"

# --- publish: beneran ---
out="$(bash "$REL" publish "$T/n1.md" --ref "$C1" --not-latest 2>&1)"; rc=$?
[ $rc -eq 0 ] && [ -f "$FAKE_REL/v0.1.0" ] && ok "publish v0.1.0 bikin Release" || bad "publish v0.1.0" "$out"
[ "$(git ls-remote --tags origin 'refs/tags/v0.1.0^{}' | cut -f1)" = "$C1" ] && ok "tag v0.1.0 ter-push & menunjuk commit yang benar" || bad "tag v0.1.0 di remote"
[ "$(git for-each-ref --format='%(objecttype)' refs/tags/v0.1.0)" = tag ] && ok "tag beranotasi" || bad "tag bukan annotated"
[ "$(git for-each-ref --format='%(taggerdate:short)' refs/tags/v0.1.0)" = 2026-01-10 ] && ok "tanggal tag = tanggal commit" \
  || bad "tanggal tag" "$(git for-each-ref --format='%(taggerdate:iso)' refs/tags/v0.1.0)"
grep -qx -- '--latest=false' "$FAKE_REL/v0.1.0.args" && grep -qx 'v0.1.0 — First one' "$FAKE_REL/v0.1.0.args" \
  && ok "Release: judul 'v<versi> — <title>' + --latest=false" || bad "argumen Release" "$(cat "$FAKE_REL/v0.1.0.args")"
[ "$(head -n 1 "$FAKE_REL/v0.1.0.body")" = "Released x." ] && ! grep -q '^title:' "$FAKE_REL/v0.1.0.body" \
  && ok "isi Release tanpa baris title & baris kosong di depan" || bad "isi Release" "$(cat "$FAKE_REL/v0.1.0.body")"

out="$(bash "$REL" publish "$T/n1.md" --ref "$C1" 2>&1)"; rc=$?
[ $rc -ne 0 ] && echo "$out" | grep -q 'sudah ada' && ok "Release yang sudah ada tidak dibikin ulang" || bad "publish ulang" "$out"

out="$(bash "$REL" publish "$T/n2.md" --ref "$C2" --version 0.2.0 --not-latest 2>&1)"; rc=$?
[ $rc -eq 0 ] && [ "$(git rev-parse 'v0.2.0^{commit}')" = "$C2" ] && ok "backfill --version di manifest tak sinkron" || bad "backfill --version" "$out"

out="$(bash "$REL" draft --ref "$C3" 2>&1)"
echo "$out" | grep -q '^PREVIOUS v0.2.0' && echo "$out" | grep -q '^COMMITS 1' && echo "$out" | grep -q 'compare/v0.2.0...v0.3.0' \
  && ok "draft: commit sejak tag sebelumnya + link compare" || bad "draft sesudah tag" "$out"

# tag sisa (gh gagal sebelumnya) dipakai ulang; tag di commit lain ditolak
git tag -a v0.3.0 "$C3" -m "v0.3.0 — Third"
out="$(bash "$REL" publish "$T/n3.md" --ref "$C3" 2>&1)"; rc=$?
[ $rc -eq 0 ] && grep -qx -- '--latest' "$FAKE_REL/v0.3.0.args" && ok "tag lokal yang sudah ada dipakai ulang, Release jadi Latest" || bad "resume tag lokal" "$out"
git tag -d v0.3.0 >/dev/null; git tag v0.3.0 "$C2"; rm -f "$FAKE_REL"/v0.3.0*
out="$(bash "$REL" publish "$T/n3.md" --ref "$C3" 2>&1)"; rc=$?
[ $rc -ne 0 ] && echo "$out" | grep -q 'commit lain' && ok "tag yang menunjuk commit lain ditolak" || bad "tag beda commit" "$out"

echo "---"; echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
