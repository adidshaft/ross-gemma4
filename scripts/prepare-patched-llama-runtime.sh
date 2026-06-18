#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/prepare-patched-llama-runtime.sh [options]

Options:
  --swift-package-path <path>   Swift package root to prepare. Default: ios
  --xcode-project <path>        Xcode project to resolve. Default: ios/Ross.xcodeproj
  --scheme <name>               Xcode scheme for package resolution. Default: Ross
  --derived-data-path <path>    DerivedData path whose SourcePackages artifact cache should be patched.
                                Default: ios/build-device
  --cache-root <path>           Cache root for the patched llama.cpp checkout/build. Default: ios/tmp/patched-llama-runtime
  --skip-swiftpm                Skip `swift package resolve` and the SwiftPM artifact cache overlay.
  --skip-xcode                  Skip `xcodebuild -resolvePackageDependencies` and the Xcode artifact cache overlay.
  --rebuild                     Force a fresh patched xcframework rebuild even if a cached one exists.
  -h, --help                    Show this help.

This helper recreates the patched llama.cpp Apple xcframework Ross currently
needs for constrained Quick Start GGUF device stability, then overlays that
xcframework into the local SwiftPM and Xcode artifact caches that still resolve
mattt/llama.swift from upstream.
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

for tool_dir in \
  "/opt/homebrew/opt/cmake/bin" \
  "/usr/local/opt/cmake/bin" \
  "/Applications/CMake.app/Contents/bin"
do
  if [[ -d "${tool_dir}" && ":${PATH}:" != *":${tool_dir}:"* ]]; then
    PATH="${tool_dir}:${PATH}"
  fi
done
export PATH

swift_package_path="${repo_root}/ios"
xcode_project_path="${repo_root}/ios/Ross.xcodeproj"
xcode_scheme="Ross"
derived_data_path="${repo_root}/ios/build-device"
cache_root="${repo_root}/ios/tmp/patched-llama-runtime"
prepare_swiftpm="1"
prepare_xcode="1"
force_rebuild="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --swift-package-path)
      swift_package_path="${2:-}"
      shift 2
      ;;
    --xcode-project)
      xcode_project_path="${2:-}"
      shift 2
      ;;
    --scheme)
      xcode_scheme="${2:-}"
      shift 2
      ;;
    --derived-data-path)
      derived_data_path="${2:-}"
      shift 2
      ;;
    --cache-root)
      cache_root="${2:-}"
      shift 2
      ;;
    --skip-swiftpm)
      prepare_swiftpm="0"
      shift
      ;;
    --skip-xcode)
      prepare_xcode="0"
      shift
      ;;
    --rebuild)
      force_rebuild="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${prepare_swiftpm}" == "0" && "${prepare_xcode}" == "0" ]]; then
  echo "Nothing to do: both SwiftPM and Xcode overlays were skipped." >&2
  exit 2
fi

require_tool() {
  local tool="$1"
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "Required tool not found: ${tool}" >&2
    exit 2
  fi
}

require_tool git
require_tool rsync
require_tool swift
require_tool xcodebuild
require_tool xcrun
require_tool shasum

patch_file="${repo_root}/third_party/patches/llama.cpp/ggml-count-new-split-inputs.patch"
llama_tag="b9672"
llama_repo_url="https://github.com/ggml-org/llama.cpp.git"
source_root="${cache_root}/src"
artifact_root="${cache_root}/artifacts"
artifact_path="${artifact_root}/llama.xcframework"
stamp_file="${artifact_root}/build.stamp"
patch_sha="$(shasum -a 256 "${patch_file}" | awk '{print $1}')"
expected_stamp="${llama_tag}:${patch_sha}"
seed_xcframework_path="${LLAMA_PREBUILT_XCFRAMEWORK_PATH:-/tmp/llama-cpp-b9672/build-apple/llama.xcframework}"

prepare_checkout() {
  mkdir -p "${cache_root}" "${artifact_root}"

  if [[ ! -d "${source_root}/.git" ]]; then
    echo "Cloning llama.cpp ${llama_tag} into ${source_root}"
    rm -rf "${source_root}"
    git clone --branch "${llama_tag}" --depth 1 "${llama_repo_url}" "${source_root}"
  else
    echo "Refreshing cached llama.cpp checkout at ${source_root}"
    git -C "${source_root}" fetch --depth 1 origin "refs/tags/${llama_tag}:refs/tags/${llama_tag}"
    git -C "${source_root}" reset --hard
    git -C "${source_root}" clean -fdx
    git -C "${source_root}" checkout -f "${llama_tag}"
  fi

  git -C "${source_root}" apply "${patch_file}"
}

build_patched_xcframework() {
  local needs_rebuild="${force_rebuild}"

  if [[ "${needs_rebuild}" != "1" && -d "${artifact_path}" && -f "${stamp_file}" ]]; then
    if [[ "$(cat "${stamp_file}")" == "${expected_stamp}" ]]; then
      echo "Reusing cached patched llama xcframework at ${artifact_path}"
      return
    fi
    needs_rebuild="1"
  fi

  if [[ "${needs_rebuild}" == "1" ]]; then
    rm -rf "${artifact_path}" "${stamp_file}"
  fi

  if ! command -v cmake >/dev/null 2>&1; then
    if [[ -d "${seed_xcframework_path}" ]]; then
      echo "cmake is unavailable; seeding the repo-owned llama artifact cache from ${seed_xcframework_path}"
      rm -rf "${artifact_path}"
      mkdir -p "${artifact_root}"
      rsync -a --delete "${seed_xcframework_path}/" "${artifact_path}/"
      printf 'seeded-local:%s:%s\n' "${seed_xcframework_path}" "${patch_sha}" > "${stamp_file}"
      return
    fi
    echo "cmake is required to rebuild the patched llama xcframework, and no seed artifact was found at ${seed_xcframework_path}." >&2
    exit 2
  fi

  prepare_checkout

  echo "Building patched llama xcframework from ${llama_tag}"
  (
    cd "${source_root}"
    ./build-xcframework.sh
  )

  rm -rf "${artifact_path}"
  mkdir -p "${artifact_root}"
  rsync -a --delete "${source_root}/build-apple/llama.xcframework/" "${artifact_path}/"
  printf '%s\n' "${expected_stamp}" > "${stamp_file}"
}

overlay_xcframework() {
  local destination="$1"
  mkdir -p "$(dirname "${destination}")"
  rm -rf "${destination}"
  rsync -a --delete "${artifact_path}/" "${destination}/"
  echo "Patched llama xcframework -> ${destination}"
}

build_patched_xcframework

if [[ "${prepare_swiftpm}" == "1" ]]; then
  echo "Resolving SwiftPM packages at ${swift_package_path}"
  swift package --package-path "${swift_package_path}" resolve
  overlay_xcframework "${swift_package_path}/.build/artifacts/llama.swift/llama-cpp/llama.xcframework"
fi

if [[ "${prepare_xcode}" == "1" ]]; then
  echo "Resolving Xcode package dependencies at ${xcode_project_path}"
  xcodebuild \
    -resolvePackageDependencies \
    -project "${xcode_project_path}" \
    -scheme "${xcode_scheme}" \
    -derivedDataPath "${derived_data_path}" \
    >/dev/null
  overlay_xcframework "${derived_data_path}/SourcePackages/artifacts/llama.swift/llama-cpp/llama.xcframework"
fi

echo "Patched llama runtime preparation complete."
