#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/oboard/Development/lepus-apps/lepus"
BUILD_ROOT="$ROOT/_build/native/release/build/examples/custom_window"
C_FILE="${1:-$BUILD_ROOT/custom_window.c}"
OUT_EXE="${2:-$BUILD_ROOT/custom_window_win_x64.exe}"
WORK_DIR="${3:-$ROOT/_build/win-x64-link}"
FORCE="${FORCE:-0}"

mkdir -p "$WORK_DIR"

if ! command -v zig >/dev/null 2>&1; then
  echo "zig not found"
  exit 1
fi

if [ ! -f "$C_FILE" ]; then
  echo "C file not found: $C_FILE"
  exit 1
fi

# This C file is backend-specific. If it still references io_unix symbols,
# it was generated for Unix/macOS and cannot be linked to a valid Windows exe.
if [ "$FORCE" != "1" ] && rg -q "io__unix|moonbitlang_async_set_cloexec|moonbitlang_async_set_nonblocking" "$C_FILE"; then
  cat <<'EOF'
Detected Unix-specific symbols in custom_window.c.
This file is not a Windows-target MoonBit C output, so cross-linking to win-x64
will fail even if zig/webview libs are present.

Please first generate Windows-target C output, then rerun this script.
If you still want to force link attempt: FORCE=1 ./build_custom_window_win_x64.sh
EOF
  exit 2
fi

TARGET="x86_64-windows-gnu"
INC="-I/Users/oboard/.moon/include"

zig cc -target "$TARGET" $INC -c /Users/oboard/.moon/lib/runtime.c -o "$WORK_DIR/runtime.o"
zig cc -target "$TARGET" $INC -c /Users/oboard/.moon/lib/runtime_core.c -o "$WORK_DIR/runtime_core.o"

zig cc -target "$TARGET" $INC -c "$C_FILE" -o "$WORK_DIR/custom_window.o"

zig c++ -target "$TARGET" -o "$OUT_EXE" \
  "$WORK_DIR/custom_window.o" \
  "$WORK_DIR/runtime.o" \
  "$WORK_DIR/runtime_core.o" \
  "$ROOT/cli/cc/windows_x86_64/libwebview.a" \
  -luser32 -lshell32 -lshlwapi -lversion -lole32 -loleaut32 -luuid \
  -lcomdlg32 -lcomctl32 -lgdi32 -ladvapi32 -lws2_32 -lntdll -lkernel32

echo "Built: $OUT_EXE"
