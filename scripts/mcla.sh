#!/bin/sh
# Starts the game from its folder (build.sh copies this next to mcla). The SDK
# loads its GPU plugin from the executable's folder; the options are passed
# on to mcla, and its output goes to mcla.log there too.
cd "$(dirname "$0")" || exit 1
# Turnip: the shader preamble made the Saints Reborn port (the same SDK)
# slower on the Adreno 740.
export IR3_SHADER_DEBUG="${IR3_SHADER_DEBUG:-nopreamble}"
LD_LIBRARY_PATH="$PWD${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" exec ./mcla "$@" > mcla.log 2>&1
