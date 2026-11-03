# MCLA recomp for ARM64 Linux handhelds

Native **linux-arm64** build of the *Midnight Club: Los Angeles Complete Edition*
static recompilation ([RenanQueiroz/mcla-recomp](https://github.com/RenanQueiroz/mcla-recomp),
the maintained fork of [holdmysocks/mcla-recomp](https://github.com/holdmysocks/mcla-recomp)),
for ArmadaOS on the Retroid Pocket 6 (Snapdragon, Adreno 740 with Turnip) and other
aarch64 Linux devices.

This repository holds only build scripts and patches. **It contains no game code,
assets or keys**: the game is extracted from your own disc image and recompiled on
your device. What you build is for you, not for sharing.

> **Status: experimental.** The SDK and the game build for arm64 (CI checks it with
> placeholder code); whether the game runs, and how fast, on the RP6 is what this
> port is testing. For the same game with a new engine see
> [rusty-mcla-arm64](https://github.com/Ken5998/rusty-mcla-arm64).

## How it works

The game's PowerPC code is translated to C++ by the [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk)
v0.10.0, which also emulates the Xbox 360 kernel, GPU (on Vulkan) and audio.
`scripts/prepare.sh` checks out the fork at the commit in `upstream.json` and patches the
SDK exactly as the fork's own build does (its patches, in the order of its
`scripts/make_pc.ps1`), then adds what arm64 needs:

| Patch | What it does |
|---|---|
| `patches/sdk/0001`, `0002` | Guest fault handling on AArch64 (instruction aborts, SVE registers), from the Saints Reborn port |
| `patches/sdk/0003` | Optional lighter multiply rule in translated shaders (`spirv_ieee_vertex_math`) |
| `patches/sdk/0004`, `patches/game/0001` | Recompiled code generated as its own step, not inside the build |

FSR 3.1 and frame generation are left out (`-DREXGLUE_ENABLE_FSR=OFF`); FSR 1 and CAS
scaling (`present_effect`) are still there.

## Install on the RP6

You need your **Midnight Club: Los Angeles Complete Edition** disc image (Xbox 360,
USA/Europe, title `545407F8`), about 30 GB free, and Steam set up. In Desktop Mode,
open a terminal:

```sh
git clone https://github.com/Ken5998/mcla-recomp-arm64.git
cd mcla-recomp-arm64
scripts/build.sh /path/to/mcla.iso
```

It downloads the pinned toolchain (LLVM 20 and a sysroot: nothing is installed on the
system), builds the SDK, extracts the game, recompiles it (an hour or more on the
handheld) and adds **Midnight Club: Los Angeles (Recomp)** to Steam. Everything lives in
`~/.local/share/MCLA-recomp-arm64`; the game is in `game-dist/` there. Start it from Steam,
even in Desktop Mode, so the handheld's controls reach it. No artwork is added: set it in
Steam as you like.

To update: `git pull`, then `scripts/build.sh -` (it reuses the extracted game and only
rebuilds what changed).

## Settings

The first build writes these into `game-dist/mcla.toml`, only where the file does not set
them already (the pause menu's Settings tab changes the same file):

| Setting | Value | Why |
|---|---|---|
| `vulkan_allow_present_mode_immediate`, `..._mailbox` | `false` | Otherwise the game presents ~1,000 times a second on Wayland/gamescope |
| `resolution_scale`, `mcla_fps`, `fullscreen` | `1`, `30`, `true` | 720p at 30 FPS, as on the console |
| `mcla_preset` | `"low"` | No MSAA or full-screen blur, environment map every 4th frame |
| `spirv_ieee_vertex_math`, `force_convert_quad_lists_to_triangle_lists` | `true` | What helped the same SDK on the Adreno 740 in Saints Reborn |

`mcla.sh` sets `IR3_SHADER_DEBUG=nopreamble` and writes the game's output to
`game-dist/mcla.log`. The fork's other settings are in its
[docs/settings.md](https://github.com/RenanQueiroz/mcla-recomp/blob/main/docs/settings.md).

## License

GPL-3.0, as mcla-recomp. ReXGlue SDK is BSD-3-Clause.
