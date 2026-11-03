#!/usr/bin/env bash
# Checks out the MCLA recomp (RenanQueiroz/mcla-recomp, the fork of
# holdmysocks/mcla-recomp) and ReXGlue SDK v0.10.0, then patches the SDK the
# way the fork's own build does: upstream's patches, the two Linux patches,
# the fork's patches in the order of the table in its scripts/make_pc.ps1,
# and then this repository's patches/sdk/*.patch (what linux-arm64 needs on
# top). patches/game/*.patch go on the game project.
#
#   scripts/prepare.sh WORKDIR [MCLA_REF]
#
# WORKDIR/mcla-recomp  the game project at the commit in upstream.json (or
#                      REF), patched; its game/ and generated/default/
#                      folders are left alone
# WORKDIR/rexglue-sdk  the patched SDK
#
# Run again, it checks out and patches both again; files that end up the same
# keep their times (scripts/keep-times.py), so a build afterwards recompiles
# only what the new patches change. No game files are involved.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mkdir -p "$1" && cd "$1" && pwd)"

field() {
    python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' \
        "$repo/upstream.json" "$1"
}
ref="${2:-$(field commit)}"
mcla="$work/mcla-recomp"
sdk="$work/rexglue-sdk"
times="$work/.prepare-times.json"
python3 "$repo/scripts/keep-times.py" save "$times" "$mcla" "$sdk"

if [ ! -d "$mcla/.git" ]; then
    git clone -q "$(field repository)" "$mcla"
fi
git -C "$mcla" fetch -q origin "$ref" 2>/dev/null || git -C "$mcla" fetch -q origin
git -C "$mcla" -c advice.detachedHead=false checkout -q --force "$ref"
# Files an earlier patch added; checkout --force leaves them.
git -C "$mcla" clean -fdq -- src config scripts CMakeLists.txt
echo "mcla-recomp $(git -C "$mcla" rev-parse --short HEAD)"

if [ ! -d "$sdk/.git" ]; then
    git clone -q -c core.autocrlf=false "$(field sdk_repository)" "$sdk"
fi
sdk_commit="$(field sdk_commit)"
git -C "$sdk" fetch -q origin "$sdk_commit" 2>/dev/null || git -C "$sdk" fetch -q --tags origin
git -C "$sdk" -c advice.detachedHead=false checkout -q --force "$sdk_commit"
git -C "$sdk" clean -fdq -- include src resources cmake tools
git -C "$sdk" submodule update --init --recursive --force --depth 1 -q ||
    git -C "$sdk" submodule update --init --recursive --force -q
git -C "$sdk/thirdparty/FFmpeg" checkout -q --force . 2>/dev/null || true
echo "ReXGlue SDK $(git -C "$sdk" describe --tags --always)"

patches="$mcla/patches"
apply() {  # apply DIR PATCH
    git -C "$1" apply --whitespace=nowarn "$2"
    echo "Applied ${2#"$work"/}"
}
apply "$sdk" "$patches/rexglue-v0.10.0-mcla.patch"
apply "$sdk" "$patches/rexglue-minmax-blend-factor.patch"
apply "$sdk/thirdparty/FFmpeg" "$patches/rexglue-ffmpeg-ps5-config.patch"
apply "$sdk" "$patches/rexglue-linux-procmap-query.patch"
apply "$sdk" "$patches/rexglue-linux-wait-sleep.patch"
# The fork's own patches, in its table's order (several touch neighbouring
# lines). The llvm-mingw FFmpeg config is for Windows only.
order="$(sed -n 's/^ *@{ Patch = "\(rexglue-[^"]*\.patch\)".*/\1/p' "$mcla/scripts/make_pc.ps1" |
    grep -v ffmpeg)"
[ -n "$order" ] || { echo "error: no patch table in mcla-recomp's scripts/make_pc.ps1" >&2; exit 1; }
for name in $order; do
    apply "$sdk" "$patches/$name"
done
for patch in "$repo"/patches/sdk/*.patch; do
    [ -e "$patch" ] || continue
    apply "$sdk" "$patch"
done

for patch in "$repo"/patches/game/*.patch; do
    [ -e "$patch" ] || continue
    apply "$mcla" "$patch"
done

python3 "$repo/scripts/keep-times.py" restore "$times"
