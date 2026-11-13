#!/usr/bin/env bash
# Rilis versi plugin: tag v<versi> + GitHub Release berisi catatan update (bahasa Inggris).
#
#   bash tools/release.sh draft   [--ref <rev>]
#       Cetak versi di <rev> (default HEAD), tag sebelumnya, dan semua commit sejak tag itu,
#       plus kerangka file catatan. Bahan buat nulis catatan rilis.
#
#   bash tools/release.sh publish <notes.md> [--ref <rev>] [--version <v>] [--not-latest] [--dry-run]
#       <notes.md>: baris pertama `title: <judul>`, sisanya isi Release (markdown).
#       Bikin tag beranotasi v<versi> di <rev> (tanggal tag = tanggal commit), push tag, lalu
#       `gh release create`. Aman diulang: tag yang sudah ada di commit yang sama dipakai lagi.
#       --version  buat backfill commit lama yang manifest-nya belum sinkron (cukup salah satu
#                  versi manifest = <v>). Tanpa ini, plugin.json & marketplace.json wajib sama.
#       --not-latest  jangan jadikan Release ini "Latest" (backfill versi lama).
#
# Akun gh aktif harus punya akses tulis ke repo (cek lewat `gh repo view`). Push tag lewat
# credential helper gh, jadi ikut akun gh yang aktif. Ritual lengkap: docs/maintaining.md.
set -uo pipefail

REMOTE="${CV_RELEASE_REMOTE:-origin}"
PJ="plugin/.claude-plugin/plugin.json"
MJ=".claude-plugin/marketplace.json"

die() { echo "release: $*" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || die "butuh jq"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "jalankan dari dalam repo context-vault"
cd "$ROOT" || exit 1

# versi-versi manifest di <rev>, satu per baris (plugin.json, metadata marketplace, entri plugin)
manifest_versions() {
  git show "$1:$PJ" 2>/dev/null | jq -r '.version // empty' 2>/dev/null
  git show "$1:$MJ" 2>/dev/null | jq -r '.metadata.version // empty, (.plugins[]? | select(.name == "context-vault") | .version // empty)' 2>/dev/null
}

prev_tag() {  # tag v* terdekat sebelum <rev>, kosong bila tidak ada
  git describe --tags --abbrev=0 --match 'v[0-9]*' "$1^" 2>/dev/null || true
}

cmd="${1:-}"; shift || true
REF="HEAD"; VERSION=""; LATEST=1; DRY=0; NOTES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) REF="${2:-}"; shift 2 ;;
    --version) VERSION="${2:-}"; shift 2 ;;
    --not-latest) LATEST=0; shift ;;
    --dry-run) DRY=1; shift ;;
    -*) die "opsi tak dikenal: $1" ;;
    *) [ -z "$NOTES" ] || die "argumen kelebihan: $1"; NOTES="$1"; shift ;;
  esac
done

SHA="$(git rev-parse --verify --quiet "$REF^{commit}")" || die "ref tak ditemukan: $REF"
versions="$(manifest_versions "$SHA" | sort -u)"
[ -n "$versions" ] || die "tidak ada versi di manifest pada $REF"

if [ -n "$VERSION" ]; then
  printf '%s\n' "$versions" | grep -qxF "$VERSION" \
    || die "versi $VERSION tidak ada di manifest pada $REF (ada: $(printf '%s' "$versions" | tr '\n' ' '))"
else
  [ "$(printf '%s\n' "$versions" | wc -l | tr -d ' ')" = 1 ] \
    || die "versi manifest tak sinkron pada $REF: $(printf '%s' "$versions" | tr '\n' ' ')(pakai --version buat backfill)"
  VERSION="$versions"
fi
TAG="v$VERSION"
PREV="$(prev_tag "$SHA")"
SLUG="$(git remote get-url "$REMOTE" 2>/dev/null | sed -nE 's#^.*github\.com[:/]([^/]+/[^/]+)$#\1#p' | sed 's/\.git$//')"
[ -n "$SLUG" ] || SLUG="<owner>/<repo>"

case "$cmd" in
draft)
  [ -z "$NOTES" ] || die "draft tidak menerima file catatan"
  if git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null; then
    echo "catatan: tag $TAG sudah ada" >&2
  fi
  echo "VERSION $TAG  at $(git rev-parse --short "$SHA")  $(git log -1 --format=%cs "$SHA")"
  if [ -n "$PREV" ]; then
    echo "PREVIOUS $PREV"; range="$PREV..$SHA"
    diff_line="**Full diff:** https://github.com/$SLUG/compare/$PREV...$TAG"
  else
    echo "PREVIOUS (none)"; range="$SHA"
    diff_line="**Commits:** https://github.com/$SLUG/commits/$TAG"
  fi
  echo "COMMITS $(git rev-list --count "$range")"
  echo
  git log --reverse --format='=== %h %cs%n%s%n%b' "$range"
  echo
  echo "--- kerangka notes.md ---"
  printf 'title: <judul singkat, maks 60 karakter>\n\nReleased %s.\n\n<satu-dua kalimat>\n\n### New\n- **/<skill>**: ...\n\n### Changed\n\n### Fixed\n\n### Docs\n\n%s\n' \
    "$(git log -1 --format=%cs "$SHA")" "$diff_line"
  ;;

publish)
  [ -n "$NOTES" ] || die "pakai: release.sh publish <notes.md> [--ref <rev>] [--version <v>] [--not-latest] [--dry-run]"
  [ -f "$NOTES" ] || die "file catatan tidak ada: $NOTES"
  first="$(head -n 1 "$NOTES")"
  case "$first" in title:*) ;; *) die "baris pertama $NOTES harus 'title: <judul>'" ;; esac
  TITLE="$(printf '%s' "${first#title:}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -n "$TITLE" ] || die "judul kosong di $NOTES"
  BODY="$(mktemp)"; trap 'rm -f "$BODY"' EXIT
  tail -n +2 "$NOTES" | sed '/./,$!d' > "$BODY"
  [ -s "$BODY" ] || die "isi catatan kosong di $NOTES"

  command -v gh >/dev/null 2>&1 || die "butuh gh"
  git fetch --quiet "$REMOTE" || die "gagal fetch $REMOTE"
  [ -n "$(git branch -r --contains "$SHA" 2>/dev/null | grep -F "$REMOTE/")" ] \
    || die "commit $(git rev-parse --short "$SHA") belum ada di $REMOTE — push dulu"

  perm="$(gh repo view --json viewerPermission -q .viewerPermission 2>/dev/null)" || perm=""
  case "$perm" in ADMIN|MAINTAIN|WRITE) ;;
    *) die "akun gh aktif tak punya akses tulis ke repo (izin: ${perm:-?}) — gh auth switch --user <pemilik repo>" ;;
  esac

  if gh release view "$TAG" >/dev/null 2>&1; then die "Release $TAG sudah ada"; fi

  local_tag="$(git rev-parse --verify --quiet "refs/tags/$TAG^{commit}" || true)"
  remote_tag="$(git ls-remote --tags "$REMOTE" "refs/tags/$TAG^{}" | cut -f1)"
  [ -n "$remote_tag" ] || remote_tag="$(git ls-remote --tags "$REMOTE" "refs/tags/$TAG" | cut -f1)"
  for t in "$local_tag" "$remote_tag"; do
    [ -z "$t" ] || [ "$t" = "$SHA" ] || die "tag $TAG sudah ada di commit lain ($t)"
  done

  latest_flag="--latest"; [ "$LATEST" = 1 ] || latest_flag="--latest=false"
  echo "$TAG — $TITLE"
  echo "  commit   $(git rev-parse --short "$SHA") ($(git log -1 --format=%cs "$SHA"))  previous ${PREV:-none}"
  echo "  tag      $([ -n "$local_tag" ] && echo 'sudah ada (lokal)' || echo 'dibuat')  push $([ -n "$remote_tag" ] && echo 'sudah' || echo "ke $REMOTE")"
  echo "  release  $latest_flag"
  [ "$DRY" = 1 ] && { echo "(dry-run: tidak ada yang dibuat)"; exit 0; }

  if [ -z "$local_tag" ]; then
    GIT_COMMITTER_DATE="$(git log -1 --format=%cI "$SHA")" \
      git tag -a "$TAG" "$SHA" -m "$TAG — $TITLE" || die "gagal bikin tag"
  fi
  if [ -z "$remote_tag" ]; then
    git -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
      push --quiet "$REMOTE" "refs/tags/$TAG" || die "gagal push tag $TAG (jalankan ulang perintah yang sama)"
  fi
  gh release create "$TAG" --verify-tag --title "$TAG — $TITLE" --notes-file "$BODY" "$latest_flag" \
    || die "gagal bikin Release (tag sudah ter-push; jalankan ulang perintah yang sama)"
  ;;

*) die "pakai: release.sh draft|publish ... (lihat kepala file)" ;;
esac
