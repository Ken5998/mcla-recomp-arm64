#!/usr/bin/env bash
# Builds the Midnight Club: Los Angeles recomp for linux-arm64 from your own
# disc image, start to finish: the toolchain, the patched ReXGlue SDK, the
# game files from the ISO, the recompiled code, the game, and a folder to play
# from, added to Steam. Made for the handheld itself (ArmadaOS on the Retroid
# Pocket 6, or any aarch64 Linux). MCLA_ADD_TO_STEAM=0 leaves Steam alone.
#
#   scripts/build.sh ISO [DIR]
#
# ISO  your Midnight Club: Los Angeles Complete Edition (Xbox 360, USA/Europe,
#      title 545407F8) disc image, or - to use the game files an earlier
#      build extracted (to update)
# DIR  where everything goes (default ~/.local/share/MCLA-recomp-arm64);
#      about 30 GB free is needed while building
#
# Run it again after updating this repository: finished steps are skipped
# when nothing they depend on changed, and the game build recompiles only the
# files a change touches. The game is DIR/game-dist; nothing made here may be
# published (it is built from your copy of the game).
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
[ $# -ge 1 ] && { [ "$1" = - ] || [ -f "$1" ]; } || { echo "usage: $0 ISO|- [DIR]" >&2; exit 2; }
iso=-
[ "$1" = - ] || iso="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
dir="${2:-$HOME/.local/share/MCLA-recomp-arm64}"
mkdir -p "$dir"
dir="$(cd "$dir" && pwd)"
tc="$dir/toolchain"
mcla="$dir/mcla-recomp"
sdk_src="$dir/rexglue-sdk"
sdk="$sdk_src/out/install/linux-arm64"
build="$mcla/out/build/linux-arm64"
dist="$dir/game-dist"
stamps="$dir/.stamps"
mkdir -p "$stamps"

step() { printf '\n==> %s\n' "$*"; }
key() { cat "$@" | sha256sum | cut -d' ' -f1; }  # key FILE...: a hash of their contents
done_with() { [ -f "$stamps/$1" ] && [ "$(cat "$stamps/$1")" = "$2" ]; }
mark() { echo "$2" > "$stamps/$1"; }

case "$(uname -m)" in
    aarch64|arm64) ;;
    *) echo "error: build on the handheld (aarch64 Linux)" >&2; exit 1 ;;
esac

step "Toolchain"
"$repo/scripts/fetch-toolchain.sh" "$tc"
export PATH="$tc/bin:$PATH"

prepare_key="$(key "$repo/upstream.json" "$repo/scripts/prepare.sh" \
    "$repo"/patches/sdk/*.patch "$repo"/patches/game/*.patch)"
if done_with prepare "$prepare_key"; then
    echo "mcla-recomp and the SDK already prepared - skipping."
else
    step "mcla-recomp and the ReXGlue SDK"
    "$repo/scripts/prepare.sh" "$dir"
    mark prepare "$prepare_key"
fi

# The SDK, and the code recompiled with it, depend on the SDK patches (and on
# the fork's, which upstream.json pins), not on ours for the game.
sdk_key="$(key "$repo/upstream.json" "$repo/scripts/prepare.sh" "$repo"/patches/sdk/*.patch \
    "$repo/toolchain.json" "$repo/scripts/build-sdk.sh" "$repo/cmake/toolchains/linux-arm64.cmake")"
if done_with sdk "$sdk_key"; then
    echo "ReXGlue SDK already built - skipping."
else
    step "Building the ReXGlue SDK (this takes a while)"
    "$repo/scripts/build-sdk.sh" "$sdk_src" "$tc" "$sdk"
    mark sdk "$sdk_key"
fi

game="$mcla/game"
if [ -f "$game/default.xex" ] && { [ "$iso" = - ] || done_with extract "$iso"; }; then
    echo "Game files already extracted to $game - skipping."
elif [ "$iso" = - ]; then
    echo "error: no game files in $game yet: give your disc image instead of -" >&2
    exit 1
else
    step "Extracting the game from $iso"
    rm -rf "$game"
    python3 "$mcla/scripts/extract_game.py" "$iso" "$game"
    [ -f "$game/default.xex" ] || {
        echo "error: the disc image has no default.xex - is it the Xbox 360 game disc?" >&2; exit 1; }
    mark extract "$iso"
fi
xex_sha1="$(sha1sum "$game/default.xex" | cut -d' ' -f1)"

# The code depends on the SDK (its recompiler), the fork's configuration
# (upstream.json) and the game.
codegen_key="$sdk_key $xex_sha1"
if done_with codegen "$codegen_key" && [ -f "$mcla/generated/default/sources.cmake" ]; then
    echo "Recompiled code already generated - skipping."
else
    step "Recompiling default.xex (PowerPC to C++)"
    (cd "$mcla" && LD_LIBRARY_PATH="$sdk/lib" "$sdk/bin/rexglue" codegen mcla_manifest.toml)
    mark codegen "$codegen_key"
fi

step "Building the game (compiles ~30,000 functions; an hour or more on a handheld)"
"$repo/scripts/build-game.sh" "$mcla" "$sdk" "$tc" "$build"

step "Putting the game together in $dist"
mkdir -p "$dist"
cp -f "$build/mcla" "$sdk/lib/librexruntime.so" "$sdk/lib/librexgpu-xenos.so" "$dist/"
ln -sfn "$game" "$dist/game"
rm -rf "$dist/shaderpack"
cp -r "$mcla/shaderpack" "$dist/shaderpack"
cp -f "$repo/scripts/mcla.sh" "$dist/mcla.sh"
chmod +x "$dist/mcla.sh"
# Settings for the handheld, only where mcla.toml does not set them already:
# yours (and the pause menu's) are kept.
python3 "$repo/scripts/configure.py" "$dist/mcla.toml"

steam=no
if [ "${MCLA_ADD_TO_STEAM:-1}" = 1 ]; then
    step "Adding the game to Steam"
    if python3 "$repo/scripts/add-to-steam.py" "$dist"; then
        steam=yes
    else
        echo "Warning: the game was not added to Steam; scripts/add-to-steam.py tries again."
    fi
fi

echo
echo "Done! The game is in $dist."
if [ "$steam" = yes ]; then
    echo "Play it from Steam (\"Midnight Club: Los Angeles (Recomp)\"): the handheld's controls reach it only from there."
else
    echo "Play it from Steam (scripts/add-to-steam.py $dist adds it) so the controls work,"
    echo "or run $dist/mcla.sh from a terminal."
fi
