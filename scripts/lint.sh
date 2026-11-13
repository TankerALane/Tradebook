#!/usr/bin/env bash
# Local lint: luacheck on every addon and test Lua file (excluding embedded libs).
# On Windows without luafilesystem, uses scripts/lfs_shim.
set -euo pipefail
cd "$(dirname "$0")/.."

files=$(find Tradebook tests -name '*.lua' -not -path 'Tradebook/Libs/*' | sort)
LUACHECK=${LUACHECK:-luacheck}
if ! command -v "$LUACHECK" >/dev/null 2>&1; then
    LUACHECK="$HOME/.luarocks/bin/luacheck.bat"
    export LUA_PATH="$(pwd -W 2>/dev/null || pwd)/scripts/lfs_shim/?.lua;${LUA_PATH:-;}"
fi
"$LUACHECK" --no-cache $files "$@"
