#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="${TMPDIR:-/tmp}/lepus-webview-build"
WEBVIEW_REPO="${WORK_DIR}/webview"
USE_ZIG="${USE_ZIG:-0}"
ZIG_AR="${WORK_DIR}/zig-ar"
ZIG_RANLIB="${WORK_DIR}/zig-ranlib"

TARGETS=("${@}")
if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=("darwin_arm64" "darwin_x86_64")
fi

mkdir -p "${WORK_DIR}"
if [ ! -d "${WEBVIEW_REPO}/.git" ]; then
  git clone --depth 1 https://github.com/webview/webview "${WEBVIEW_REPO}"
else
  git -C "${WEBVIEW_REPO}" fetch --depth 1 origin
  git -C "${WEBVIEW_REPO}" reset --hard origin/HEAD
fi

build_target() {
  local target="$1"
  local build_dir="${WORK_DIR}/build-${target}"
  local out_dir="${ROOT_DIR}/${target}"
  local cmake_args=(
    -S "${WEBVIEW_REPO}"
    -B "${build_dir}"
    -DWEBVIEW_BUILD_STATIC_LIBRARY=ON
    -DWEBVIEW_BUILD_EXAMPLES=OFF
    -DWEBVIEW_BUILD_TESTS=OFF
  )

  case "${target}" in
    darwin_arm64)
      if [ "${USE_ZIG}" = "1" ]; then
        export CC='zig cc -target aarch64-macos'
        export CXX='zig c++ -target aarch64-macos'
      fi
      cmake_args+=(-DCMAKE_OSX_ARCHITECTURES=arm64)
      ;;
    darwin_x86_64)
      if [ "${USE_ZIG}" = "1" ]; then
        export CC='zig cc -target x86_64-macos'
        export CXX='zig c++ -target x86_64-macos'
      fi
      cmake_args+=(-DCMAKE_OSX_ARCHITECTURES=x86_64)
      ;;
    linux_arm64)
      if [ "${USE_ZIG}" = "1" ]; then
        export CC='zig cc -target aarch64-linux-gnu'
        export CXX='zig c++ -target aarch64-linux-gnu'
      fi
      cmake_args+=(-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64)
      ;;
    linux_x86_64)
      if [ "${USE_ZIG}" = "1" ]; then
        export CC='zig cc -target x86_64-linux-gnu'
        export CXX='zig c++ -target x86_64-linux-gnu'
      fi
      cmake_args+=(-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=x86_64)
      ;;
    windows_x86_64)
      if [ "${USE_ZIG}" = "1" ]; then
        export CC='zig cc -target x86_64-windows-gnu'
        export CXX='zig c++ -target x86_64-windows-gnu'
      fi
      cmake_args+=(-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=x86_64)
      ;;
    windows_arm64)
      if [ "${USE_ZIG}" = "1" ]; then
        export CC='zig cc -target aarch64-windows-gnu'
        export CXX='zig c++ -target aarch64-windows-gnu'
      fi
      cmake_args+=(-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=ARM64)
      ;;
    *)
      echo "Unsupported target: ${target}" >&2
      return 1
      ;;
  esac

  if [ "${USE_ZIG}" = "1" ]; then
    cat >"${ZIG_AR}" <<'EOF'
#!/usr/bin/env bash
exec zig ar "$@"
EOF
    cat >"${ZIG_RANLIB}" <<'EOF'
#!/usr/bin/env bash
exec zig ranlib "$@"
EOF
    chmod +x "${ZIG_AR}" "${ZIG_RANLIB}"
    cmake_args+=(-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY)
    cmake_args+=(-DCMAKE_AR="${ZIG_AR}" -DCMAKE_RANLIB="${ZIG_RANLIB}")
  fi

  cmake "${cmake_args[@]}"
  cmake --build "${build_dir}" --config Release -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"

  mkdir -p "${out_dir}"
  cp "${build_dir}/core/libwebview.a" "${out_dir}/libwebview.a"
  echo "built ${target}: ${out_dir}/libwebview.a"
}

for target in "${TARGETS[@]}"; do
  build_target "${target}"
done
