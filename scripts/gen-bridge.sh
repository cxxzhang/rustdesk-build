#!/usr/bin/env bash
# Generate the Rust<->Dart bridge for the RustDesk client.
#
# Upstream commits neither the generated files nor a codegen config, so they
# have to be produced before `flutter build`. The invocation is the 1.x CLI
# (flags, not a yaml config) — `flutter_rust_bridge_codegen generate` is the
# 2.x interface and fails here with "Fail to find any configuration file".
#
# The version must match `flutter_rust_bridge` in Cargo.toml (pinned =1.80) and
# pubspec.yaml (1.80.1); a mismatch yields a Dart/Rust pair that will not
# compile.
#
#   gen-bridge.sh [<tree>]     default: src/rustdesk
set -euo pipefail

TREE="${1:-src/rustdesk}"
FRB_VERSION="${FRB_CODEGEN_VERSION:-1.80.1}"

cd "$TREE"

# Already present (e.g. restored from cache)? Nothing to do.
if [ -f src/bridge_generated.rs ] && [ -f flutter/lib/generated_bridge.dart ]; then
  echo "== bridge already generated"
  exit 0
fi

if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
  echo "== installing flutter_rust_bridge_codegen $FRB_VERSION"
  cargo install flutter_rust_bridge_codegen --version "$FRB_VERSION" --locked
fi

echo "== generating bridge"
ARGS=(
  --rust-input ./src/flutter_ffi.rs
  --dart-output ./flutter/lib/generated_bridge.dart
)
# The C header is only consumed by the macOS build; harmless elsewhere.
if [ -d flutter/macos ]; then
  ARGS+=(--c-output ./flutter/macos/Runner/bridge_generated.h)
fi
flutter_rust_bridge_codegen "${ARGS[@]}"

for f in src/bridge_generated.rs src/bridge_generated.io.rs \
         flutter/lib/generated_bridge.dart flutter/lib/generated_bridge.freezed.dart; do
  if [ -f "$f" ]; then
    printf '  %-44s %s bytes\n' "$f" "$(stat -c%s "$f")"
  else
    echo "!! missing $f" >&2
    exit 1
  fi
done
