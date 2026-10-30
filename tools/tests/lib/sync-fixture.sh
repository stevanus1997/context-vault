# Fixture produk multi-repo untuk test sync (di-source; bukan dijalankan langsung).
# Dipakai tools/tests/sync.test.sh dan plugin/hooks/tests/sync-check.test.sh.
#
#   mkprod <dir>                         → produk: control/workspace.yaml (app api + web), tiap app repo git
#                                          hasil clone dari bare origin lokal di <dir>.origin/<nama>.git
#   gcommit <repo-dir> <author> <pesan>  → commit (ubah berkas log.txt) atas nama <author>
#   remote_commit <dir> <app> <author> <pesan>  → commit + push ke origin <app> lewat clone kerja terpisah
#                                          (repo produk belum lihat sampai di-fetch)
#   remote_head <dir> <app>              → sha HEAD origin <app>

gcommit() { # gcommit <repo-dir> <author> <pesan>
  local d="$1" who="$2" msg="$3"
  printf '%s %s\n' "$who" "$msg" >> "$d/log.txt"
  git -C "$d" add log.txt
  git -C "$d" -c user.name="$who" -c user.email="$who@x" commit -q -m "$msg"
}

_mkrepo() { # _mkrepo <dir> <app>
  local dir="$1" app="$2" org="$1.origin"
  mkdir -p "$org"
  git init -q --bare -b main "$org/$app.git"
  git clone -q "$org/$app.git" "$dir/$app" 2>/dev/null
  gcommit "$dir/$app" alice "init $app"
  [ "$app" = api ] && gcommit "$dir/$app" ci-bot "chore: bump"
  git -C "$dir/$app" push -q -u origin main 2>/dev/null
  git -C "$dir/$app" remote set-head origin -a >/dev/null 2>&1
}

mkprod() { # mkprod <dir>
  local dir="$1"
  mkdir -p "$dir/control"
  cat > "$dir/control/workspace.yaml" <<'YAML'
product: Demo
topology: multi-repo
apps:
  - name: api
    path: api
    type: be
    capabilities:
      - jadwal
  - name: web
    path: web
    type: fe
packages: []
YAML
  _mkrepo "$dir" api
  _mkrepo "$dir" web
}

remote_commit() { # remote_commit <dir> <app> <author> <pesan>
  local dir="$1" app="$2" who="$3" msg="$4" w="$1.work/$2"
  [ -d "$w" ] || git clone -q "$dir.origin/$app.git" "$w" 2>/dev/null
  git -C "$w" pull -q --ff-only origin main 2>/dev/null
  gcommit "$w" "$who" "$msg"
  git -C "$w" push -q origin HEAD:main 2>/dev/null
}

remote_head() { git --git-dir="$1.origin/$2.git" rev-parse main; }
