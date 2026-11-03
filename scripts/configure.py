#!/usr/bin/env python3
"""Writes the handheld's starting settings into the game's mcla.toml, only
for the keys it does not set yet: a value you (or the pause menu) set is
kept. Delete a line to have it written again on the next build.

    scripts/configure.py MCLA_TOML
"""
import re
import sys
from pathlib import Path

DEFAULTS = (
    ("# Wayland/gamescope: without these the game presents about 1,000 times a",),
    ("# second and keeps the GPU busy (mcla-recomp's docs/building.md).",),
    ("vulkan_allow_present_mode_immediate", "false"),
    ("vulkan_allow_present_mode_mailbox", "false"),
    ("# 720p at 30 FPS, as on the console, fullscreen.",),
    ("resolution_scale", "1"),
    ("mcla_fps", "30"),
    ("fullscreen", "true"),
    ("# Low-end: no MSAA or full-screen blur, environment map every 4th frame.",),
    ("mcla_preset", '"low"'),
    ("# What made the same SDK faster on the Adreno 740 in the Saints Reborn port.",),
    ("spirv_ieee_vertex_math", "true"),
    ("force_convert_quad_lists_to_triangle_lists", "true"),
)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    path = Path(argv[1])
    text = path.read_text() if path.is_file() else ""
    have = set(re.findall(r"^\s*([A-Za-z0-9_]+)\s*=", text, flags=re.M))
    lines, comment = [], []
    for entry in DEFAULTS:
        if len(entry) == 1:
            comment.append(entry[0])
            continue
        if entry[0] not in have:
            lines += comment + [f"{entry[0]} = {entry[1]}"]
            print(f"mcla.toml: {entry[0]} = {entry[1]}")
        comment = []
    if lines:
        if text and not text.endswith("\n"):
            text += "\n"
        path.write_text(text + "\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
