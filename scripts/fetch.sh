#!/usr/bin/env bash
# Clone the AnDesk source repos this pipeline builds.
#
# All of them are private, so the clone needs a token. It is taken from
# GITCODE_TOKEN, which the workflows pass in from repository secrets.
#
#   fetch.sh <repo> [<repo>...]
#
# Each repo lands in $SRC_DIR/<repo> (default: ./src/<repo>).
set -euo pipefail

: "${GITCODE_TOKEN:?GITCODE_TOKEN is not set - add it as a repository secret}"
OWNER="${GITCODE_OWNER:-rustzhang}"
SRC_DIR="${SRC_DIR:-$PWD/src}"
BRANCH="${SRC_BRANCH:-main}"

mkdir -p "$SRC_DIR"

for repo in "$@"; do
  dest="$SRC_DIR/$repo"
  if [ -d "$dest/.git" ]; then
    echo "== $repo already present, fetching"
    git -C "$dest" fetch --depth 1 origin "$BRANCH"
    git -C "$dest" checkout -q FETCH_HEAD
    continue
  fi
  echo "== cloning $repo @ $BRANCH"
  # Shallow: these pipelines build, they do not need history. The token is in
  # the URL only for the lifetime of this command.
  git clone --depth 1 --branch "$BRANCH" \
    "https://${OWNER}:${GITCODE_TOKEN}@gitcode.com/${OWNER}/${repo}.git" "$dest"
  # Drop the credential back out of the remote so it is not left on disk in
  # .git/config for later steps (or in an uploaded artifact) to pick up.
  git -C "$dest" remote set-url origin "https://gitcode.com/${OWNER}/${repo}.git"
done

echo "== fetched into $SRC_DIR:"
ls -1 "$SRC_DIR"
