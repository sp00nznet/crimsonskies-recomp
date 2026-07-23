#!/usr/bin/env bash
# Regenerate the recompiled C from the XBE, in the one order that works.
#
#   disasm         rewrites functions.json from scratch, so every name applied
#                  by a later step is lost and must be re-applied. Only run it
#                  when tools/disasm changed.
#   func_id        library-function identification (CRT, vtable thunks).
#   recomp         emits the C.
#
# Usage: ./regen.sh [--disasm]

set -uo pipefail

CS="$(cd "$(dirname "$0")" && pwd)"
RECOMP="$CS/../xboxrecomp"
XBE="$CS/game/default.xbe"

if [[ ! -f "$XBE" ]]; then
    echo "missing $XBE"
    echo "extract it from your own disc image:"
    echo "  cd $RECOMP && py -3 -m tools.xiso get <game>.iso default.xbe -o $CS/game/"
    exit 1
fi

cd "$RECOMP"

if [[ "${1:-}" == "--disasm" ]]; then
    echo "==> xbe_parser"
    py -3 -m tools.xbe_parser "$XBE" --json "$CS/game/crimsonskies_analysis.json" --quiet

    echo "==> disasm"
    # Add --seed-functions "$CS/game/icall_seeds.json" once a feedback run exists
    # (build with -DCS_ICALL_FEEDBACK=ON, then tools.recomp.icall_feedback).
    py -3 -m tools.disasm "$XBE" \
        --analysis-json "$CS/game/crimsonskies_analysis.json" \
        -o "$CS/build/disasm" -v | grep -E "Realigned|Total functions|Reachable"
fi

echo "==> func_id"
py -3 -m tools.func_id "$XBE" \
    --functions "$CS/build/disasm/functions.json" \
    --strings   "$CS/build/disasm/strings.json" \
    --xrefs     "$CS/build/disasm/xrefs.json" \
    -o "$CS/build/func_id" >/dev/null

echo "==> recomp"
py -3 -m tools.recomp "$XBE" --all --split 1000 \
    --disasm-dir  "$CS/build/disasm" \
    --func-id-dir "$CS/build/func_id" \
    --gen-dir     "$CS/src/game/recomp/gen" \
    -o "$CS/build/recomp" | grep -aE "unresolved|functions \(|Complete"

echo "==> done"
