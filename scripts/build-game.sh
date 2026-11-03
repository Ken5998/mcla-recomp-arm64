#!/usr/bin/env bash
# Builds the game (the mcla program) for linux-arm64 against the SDK that
# build-sdk.sh installed: natively on aarch64, or cross-compiled on x86-64.
#
#   scripts/build-game.sh MCLA SDK_INSTALL TOOLCHAIN [BUILD]
#
# MCLA         the project made by prepare.sh, with the recompiled code already in
#              MCLA/generated/default (from `rexglue codegen`, or from
#              placeholder-codegen.py to check the build without the game)
# SDK_INSTALL  build-sdk.sh's install prefix (SDK/out/install/linux-arm64)
# TOOLCHAIN    fetch-toolchain.sh's folder
# BUILD        build folder (default MCLA/out/build/linux-arm64)
#
# Parallel jobs: MCLA_JOBS, else one per logical CPU but at most one per 2 GB
# of memory (the recompiled files are huge).
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
mcla="$(cd "$1" && pwd)"
sdk="$(cd "$2" && pwd)"
export MCLA_ARM64_TOOLCHAIN="$(cd "$3" && pwd)"
build="${4:-$mcla/out/build/linux-arm64}"
llvm="$MCLA_ARM64_TOOLCHAIN/llvm/bin"
export PATH="$MCLA_ARM64_TOOLCHAIN/bin:$PATH"

if [ -n "${MCLA_JOBS:-}" ]; then
    jobs="$MCLA_JOBS"
else
    mem_gb=$(( $(sed -n 's/^MemTotal: *\([0-9]*\) kB/\1/p' /proc/meminfo) / 1048576 ))
    jobs=$(( mem_gb / 2 ))
    [ "$jobs" -le "$(nproc)" ] || jobs="$(nproc)"
    [ "$jobs" -ge 1 ] || jobs=1
fi
echo "Building with $jobs parallel jobs ($(nproc) CPU threads)"

[ -f "$mcla/generated/default/sources.cmake" ] || {
    echo "error: no recompiled code in $mcla/generated/default (run rexglue codegen first)" >&2; exit 1; }

arch="-march=armv8.2-a+rcpc -mtune=cortex-a715"
# find_package(rexglue) looks only inside the sysroot and the SDK
# (CMAKE_FIND_ROOT_PATH); "/" makes it search the SDK's lib/cmake there.
cmake -S "$mcla" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    "-DCMAKE_C_FLAGS=$arch" "-DCMAKE_CXX_FLAGS=$arch" \
    "-DCMAKE_TOOLCHAIN_FILE=$repo/cmake/toolchains/linux-arm64.cmake" \
    "-DCMAKE_C_COMPILER=$llvm/clang" "-DCMAKE_CXX_COMPILER=$llvm/clang++" \
    "-DCMAKE_FIND_ROOT_PATH=$sdk" -DCMAKE_PREFIX_PATH=/ -DREXGLUE_EXTERNAL_CODEGEN=ON
cmake --build "$build" --target mcla --parallel "$jobs"

f="$build/mcla"
# ELF machine 183 (0xb7): AArch64.
[ "$(od -An -tx1 -j18 -N2 "$f" | tr -d ' \n')" = b700 ] || { echo "error: $f is not aarch64" >&2; exit 1; }
echo "OK $f (aarch64)"
