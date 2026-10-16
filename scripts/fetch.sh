#!/usr/bin/env bash
# Materialise the sources a build needs.
#
# Only ONE component is self-built (`rustdesk-webclient`). The rest are upstream
# repositories plus a small patch, so instead of vendoring three large trees we
# clone upstream at the exact commit each patch was made against and apply the
# patch. An upstream bump is then a one-line change here.
#
#   fetch.sh <component> [<component>...]
#
# Components: webclient rustdesk-server rustdesk api-server-pro
#
# Sources land in $SRC_DIR/<name> (default ./src/<name>).
set -euo pipefail

SRC_DIR="${SRC_DIR:-$PWD/src}"
PATCH_DIR="${PATCH_DIR:-$PWD/patches}"
WEB_CLIENT_REPO="${WEB_CLIENT_REPO:-https://github.com/cxxzhang/rustdesk-webclient.git}"

# Pinned upstream commits (see the "initial:" message of each patch).
RUSTDESK_SERVER_COMMIT="${RUSTDESK_SERVER_COMMIT:-873230e}"      # 1.1.17
RUSTDESK_CLIENT_COMMIT="${RUSTDESK_CLIENT_COMMIT:-9997b7a3b}"    # 1.5.1
API_SERVER_PRO_COMMIT="${API_SERVER_PRO_COMMIT:-1ab27a4}"        # 1.3.20

mkdir -p "$SRC_DIR"
log() { printf '== %s\n' "$*"; }

# Clone a public upstream repo and check out one commit.
clone_upstream() {
  local url="$1" commit="$2" dest="$3"
  log "cloning $url @ ${commit:0:10}"
  rm -rf "$dest"
  # A full clone rather than --depth 1: fetching an arbitrary commit needs it
  # unless the server allows shallow fetches by SHA (many do not).
  git clone --quiet "$url" "$dest"
  git -C "$dest" checkout --quiet "$commit"
  log "  at $(git -C "$dest" rev-parse --short HEAD)"
}

# Apply every patch matching the component, in name order.
#
# `git apply` rather than `git am`: the rustdesk-server patch touches
# libs/hbb_common, which upstream keeps as a *submodule*. git refuses to write
# through a submodule boundary via the index, but `git apply` edits the working
# tree directly, which is all a build needs. The patches are plain diffs, so
# nothing is lost by not recording them as commits.
apply_patches() {
  local dest="$1" pattern="$2"
  shopt -s nullglob
  local patches=("$PATCH_DIR"/$pattern)
  shopt -u nullglob
  if [ ${#patches[@]} -eq 0 ]; then
    log "no patches matching '$pattern'"
    return 0
  fi
  for p in "${patches[@]}"; do
    log "applying $(basename "$p")"
    # NOT --3way: that needs the target files in the index, and hbb_common is a
    # gitlink (mode 160000) there, so git reports "does not exist in index".
    # A plain apply edits the working tree, which is all the build needs.
    git -C "$dest" apply "$p" || {
      echo "!! failed to apply $(basename "$p")" >&2
      return 1
    }
  done
}

# --- components ------------------------------------------------------------

fetch_webclient() {
  local dest="$SRC_DIR/rustdesk-webclient"
  [ -d "$dest/.git" ] && { log "webclient present"; return 0; }
  log "cloning rustdesk-webclient (self-built, no upstream)"
  git clone --quiet --depth 1 "$WEB_CLIENT_REPO" "$dest"
}

fetch_rustdesk_server() {
  local dest="$SRC_DIR/rustdesk-server"
  [ -d "$dest/.git" ] && { log "rustdesk-server present"; return 0; }
  clone_upstream https://github.com/rustdesk/rustdesk-server.git "$RUSTDESK_SERVER_COMMIT" "$dest"
  # hbb_common is a submodule upstream and the patch edits it, so it has to be
  # populated before the patch can apply.
  if [ -f "$dest/.gitmodules" ]; then
    log "initialising submodule libs/hbb_common"
    git -C "$dest" submodule update --init --depth 1 libs/hbb_common
  fi
  apply_patches "$dest" 'rustdesk-server*.patch'
}

fetch_rustdesk() {
  local dest="$SRC_DIR/rustdesk"
  [ -d "$dest/.git" ] && { log "rustdesk present"; return 0; }
  clone_upstream https://github.com/rustdesk/rustdesk.git "$RUSTDESK_CLIENT_COMMIT" "$dest"
  apply_patches "$dest" 'rustdesk.patch'
}

fetch_api_server_pro() {
  local dest="$SRC_DIR/rustdesk-api-server-pro"
  [ -d "$dest/.git" ] && { log "api-server-pro present"; return 0; }
  clone_upstream https://github.com/liyan-lucky/rustdesk-api-server-pro.git "$API_SERVER_PRO_COMMIT" "$dest"
  apply_patches "$dest" 'rustdesk-api-server-pro*.patch'
}

# --- dispatch --------------------------------------------------------------

for component in "$@"; do
  case "$component" in
    webclient)       fetch_webclient ;;
    rustdesk-server) fetch_rustdesk_server ;;
    rustdesk)        fetch_rustdesk ;;
    api-server-pro)  fetch_api_server_pro ;;
    *) echo "unknown component: $component" >&2; exit 2 ;;
  esac
done

log "sources under $SRC_DIR:"; ls -1 "$SRC_DIR"
