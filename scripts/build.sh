#!/usr/bin/env bash
set -euo pipefail

# Project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Target configuration
SQLITE_VERSION="${1:-${SQLITE_VERSION:-3.54.1}}"
SQLITE_YEAR="${2:-${SQLITE_YEAR:-2026}}"
WASI_SDK_VERSION="${WASI_SDK_VERSION:-25}"

echo "=========================================================="
echo " Building sqlite-wasi for WASI Preview 1"
echo " SQLite Version:  ${SQLITE_VERSION}"
echo " Release Year:    ${SQLITE_YEAR}"
echo " WASI SDK Ver:    ${WASI_SDK_VERSION}"
echo "=========================================================="

BUILD_DIR="${ROOT_DIR}/build"
DIST_DIR="${ROOT_DIR}/dist"
INCLUDE_DIR="${ROOT_DIR}/include"
LIB_DIR="${ROOT_DIR}/lib"
BIN_DIR="${ROOT_DIR}/bin"
SRC_DIR="${ROOT_DIR}/src"

mkdir -p "${BUILD_DIR}" "${DIST_DIR}" "${INCLUDE_DIR}" "${LIB_DIR}" "${BIN_DIR}" "${SRC_DIR}"

# 1. Compute 7-digit SQLite version code (e.g. 3.54.1 -> 3540100)
VERSION_CODE=$(node -e '
  const [maj = "3", min = "0", patch = "0", sub = "0"] = process.argv[1].split(".");
  console.log(String(maj) + String(min).padStart(2, "0") + String(patch).padStart(2, "0") + String(sub).padStart(2, "0"));
' "${SQLITE_VERSION}")

echo "Computed SQLite version code: ${VERSION_CODE}"

# 2. Download and unpack SQLite amalgamation
AMALGAMATION_NAME="sqlite-amalgamation-${VERSION_CODE}"
AMALGAMATION_DIR="${BUILD_DIR}/${AMALGAMATION_NAME}"
AMALGAMATION_ZIP="${BUILD_DIR}/${AMALGAMATION_NAME}.zip"
SQLITE_URL="https://www.sqlite.org/${SQLITE_YEAR}/${AMALGAMATION_NAME}.zip"

if [ ! -d "${AMALGAMATION_DIR}" ]; then
  if [ ! -f "${AMALGAMATION_ZIP}" ]; then
    echo "Downloading SQLite amalgamation from ${SQLITE_URL}..."
    curl -fsSL "${SQLITE_URL}" -o "${AMALGAMATION_ZIP}"
  fi
  echo "Extracting SQLite amalgamation..."
  unzip -q -o "${AMALGAMATION_ZIP}" -d "${BUILD_DIR}"
fi

if [ ! -f "${AMALGAMATION_DIR}/sqlite3.c" ] || [ ! -f "${AMALGAMATION_DIR}/shell.c" ]; then
  echo "Error: Amalgamation files not found in ${AMALGAMATION_DIR}" >&2
  exit 1
fi

# 3. Locate or download wasi-sdk
if [ -z "${WASI_SDK_PATH:-}" ]; then
  LOCAL_WASI_SDK="${BUILD_DIR}/wasi-sdk-${WASI_SDK_VERSION}.0"
  if [ -d "${LOCAL_WASI_SDK}" ]; then
    WASI_SDK_PATH="${LOCAL_WASI_SDK}"
  else
    OS_NAME="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH_NAME="$(uname -m)"
    case "${ARCH_NAME}" in
      x86_64|amd64)
        WASI_ARCH="x86_64"
        ;;
      aarch64|arm64)
        WASI_ARCH="arm64"
        ;;
      *)
        echo "Unsupported architecture: ${ARCH_NAME}" >&2
        exit 1
        ;;
    esac

    case "${OS_NAME}" in
      linux)
        WASI_OS="linux"
        ;;
      darwin)
        WASI_OS="macos"
        ;;
      *)
        echo "Unsupported operating system: ${OS_NAME}" >&2
        exit 1
        ;;
    esac

    WASI_TAR_NAME="wasi-sdk-${WASI_SDK_VERSION}.0-${WASI_ARCH}-${WASI_OS}.tar.gz"
    WASI_TAR_PATH="${BUILD_DIR}/${WASI_TAR_NAME}"
    WASI_URL="https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_SDK_VERSION}/${WASI_TAR_NAME}"

    if [ ! -f "${WASI_TAR_PATH}" ]; then
      echo "Downloading wasi-sdk from ${WASI_URL}..."
      curl -fsSL "${WASI_URL}" -o "${WASI_TAR_PATH}"
    fi

    echo "Extracting wasi-sdk..."
    tar -xzf "${WASI_TAR_PATH}" -C "${BUILD_DIR}"
    WASI_SDK_PATH="${BUILD_DIR}/wasi-sdk-${WASI_SDK_VERSION}.0-${WASI_ARCH}-${WASI_OS}"
    if [ ! -d "${WASI_SDK_PATH}" ]; then
      # Fallback to directory name pattern if unpacked folder name varies
      WASI_SDK_PATH=$(find "${BUILD_DIR}" -maxdepth 1 -type d -name "wasi-sdk-${WASI_SDK_VERSION}.0*" | head -n 1)
    fi
  fi
fi

CC="${WASI_SDK_PATH}/bin/clang"
AR="${WASI_SDK_PATH}/bin/llvm-ar"
SYSROOT="${WASI_SDK_PATH}/share/wasi-sysroot"

if [ ! -x "${CC}" ] || [ ! -x "${AR}" ]; then
  echo "Error: Clang or llvm-ar not found in WASI_SDK_PATH (${WASI_SDK_PATH})" >&2
  exit 1
fi

echo "Using compiler: ${CC}"
echo "Using sysroot:  ${SYSROOT}"

# 4. Copy headers to include/
echo "Copying SQLite headers to include/..."
cp "${AMALGAMATION_DIR}/sqlite3.h" "${INCLUDE_DIR}/"
cp "${AMALGAMATION_DIR}/sqlite3ext.h" "${INCLUDE_DIR}/"

# 5. Compile SQLite static library (libsqlite3.a)
CFLAGS=(
  "-O3"
  "--target=wasm32-wasi"
  "--sysroot=${SYSROOT}"
  "-DSQLITE_THREADSAFE=0"
  "-DSQLITE_OMIT_LOAD_EXTENSION=1"
  "-DSQLITE_OS_UNIX=1"
  "-DSQLITE_ENABLE_MATH_FUNCTIONS"
)

echo "Compiling sqlite3.o..."
"${CC}" "${CFLAGS[@]}" -c "${AMALGAMATION_DIR}/sqlite3.c" -o "${BUILD_DIR}/sqlite3.o"

echo "Creating libsqlite3.a..."
"${AR}" rcs "${LIB_DIR}/libsqlite3.a" "${BUILD_DIR}/sqlite3.o"

# 6. Compile SQLite CLI executable (sqlite3.wasm)
echo "Compiling sqlite3.wasm..."
CLI_CFLAGS=(
  "${CFLAGS[@]}"
  "-DSQLITE_NOHAVE_SYSTEM"
  "-D_WASI_EMULATED_SIGNAL"
  "-D_WASI_EMULATED_PROCESS_CLOCKS"
  "-D_WASI_EMULATED_GETPID"
)
CLI_LDFLAGS=(
  "-lwasi-emulated-signal"
  "-lwasi-emulated-process-clocks"
  "-lwasi-emulated-getpid"
)
"${CC}" "${CLI_CFLAGS[@]}" \
  "${AMALGAMATION_DIR}/shell.c" \
  "${SRC_DIR}/wasi_compat.c" \
  "${BUILD_DIR}/sqlite3.o" \
  "${CLI_LDFLAGS[@]}" \
  -o "${BIN_DIR}/sqlite3.wasm"

echo "Build completed successfully."
echo "  - Header:     ${INCLUDE_DIR}/sqlite3.h"
echo "  - Header:     ${INCLUDE_DIR}/sqlite3ext.h"
echo "  - Static lib: ${LIB_DIR}/libsqlite3.a"
echo "  - CLI binary: ${BIN_DIR}/sqlite3.wasm"

# 7. Update package.json version and pack npm package
echo "Updating package.json version to ${SQLITE_VERSION}..."
cd "${ROOT_DIR}"
npm version "${SQLITE_VERSION}" --no-git-tag-version --allow-same-version

echo "Packaging npm tarball..."
TGZ_NAME=$(npm pack --pack-destination="${DIST_DIR}")
echo "Generated package: ${DIST_DIR}/${TGZ_NAME}"
