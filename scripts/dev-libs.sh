#!/usr/bin/env bash
# Copy the four embedded libraries into Tradebook/Libs for local testing.
# Releases get them from .pkgmeta externals instead; Tradebook/Libs is git-ignored.
# usage: scripts/dev-libs.sh "<path to an installed addon's Libs folder that has them>"
set -euo pipefail
src="${1:?path to a Libs folder containing LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0}"
dest="$(dirname "$0")/../Tradebook/Libs"
mkdir -p "$dest"
for lib in LibStub CallbackHandler-1.0 LibDataBroker-1.1 LibDBIcon-1.0; do
    rm -rf "$dest/$lib"
    cp -r "$src/$lib" "$dest/$lib"
    echo "copied $lib"
done
