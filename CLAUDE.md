# Crimson Skies: High Road to Revenge - Static Recompilation

## Project Overview
Static recompilation of the original Xbox game "Crimson Skies: High Road to Revenge"
(2003, FASA Studio) into a native Windows executable using the xboxrecomp toolkit.

Uniquely on this platform, Microsoft shipped their own static recompilation of this
game for Xbox backward compatibility. Their implementation was torn down before this
project started; see the "Standing on Microsoft's Shoulders" section of README.md and
the three `ms-fusion-*.md` documents in xboxrecomp/docs/technical/.

## Game Info
- **Title:** Crimson Skies: High Road to Revenge
- **Title ID:** 0x4D530021
- **Developer:** FASA Studio
- **Publisher:** Microsoft Game Studios
- **Release:** October 2003
- **Genre:** Arcade aerial combat
- **Platform:** Xbox exclusive

## XBE Analysis
- **XBE Size:** 3,219,456 bytes (~3.2 MB)
- **Build Date:** 2003-09-21 00:02:19 UTC
- **Build Path:** `c:\ca\xproduction\default.exe`
- **Base Address:** 0x00010000
- **Entry Point:** 0x001C7CA9
- **Image Size:** 0x00339C60 (3.23 MB)
- **Kernel Thunk Table:** 0x0028E480
- **TLS Index Addr:** 0x00327FD0
- **Sections:** 32 (including 11 BINK video codec sections)
- **Kernel Imports:** 147
- **Functions:** 12,083 (12,083 translated, 0 failed = 100%)
- **Generated C:** 1,329,736 lines across 13 source files
- **Unresolved call-target stubs:** 17

### Memory Map
```
0x00011000  .text       1978 KB   Game code
0x001FF980  D3D           78 KB
0x002133E0  D3DX         133 KB
0x00234A40  XGRPH          9 KB
0x00236EA0  DSOUND        50 KB
0x00243740  BINK*        ~85 KB   11 sections
0x00258FE0  XONLINE      105 KB
0x00273420  XNET          72 KB
0x002857E0  XPP           35 KB
0x0028E480  .rdata       340 KB
0x002E3780  .data        299 KB
0x0032E6A0  DOLBY         28 KB
0x00335820  BINKDATA      61 KB
0x00346460  $$XTIMAGE     10 KB
0x00348C60  $$XSIMAGE      4 KB
```

## Important: this title is FPO-heavy

Function detection breakdown:

| Method | Count | Share |
|--------|------:|------:|
| `call_target` | 6,112 | 51% |
| `cc_boundary` | 4,418 | 37% |
| `prologue` | 1,444 | **12%** |
| `tail_jump_target` | 105 | 1% |

Only 12% of functions have a standard `push ebp; mov ebp, esp` prologue, against 71% for
Halo 2276. This build uses aggressive frame-pointer omission, which has direct consequences:

- **Do not assume `ebp` is a frame pointer.** Most functions use it as scratch. The lifter
  keeps `ebp` as a C local for exactly this reason; `g_ebp` / `g_seh_ebp` bridge it where a
  frame genuinely crosses a call boundary.
- **`cc_boundary` detection is load-bearing here.** Changes to `int3`-padding handling in
  `tools/disasm/functions.py` will move the function count on this title far more than on
  a prologue-heavy one. Good regression target for that code.
- Expect stack-depth bugs to present as corrupted callee-saved registers rather than
  obvious crashes.

## Pipeline

Order matters; `disasm` rewrites `functions.json` from scratch so every naming pass has to
run after it. `./regen.sh [--disasm]` encodes the correct order.

```
xbe_parser  -> game/crimsonskies_analysis.json
disasm      -> build/disasm/{functions,strings,xrefs,labels}.json + asm/
func_id     -> build/func_id/{identified_functions,crt_functions}.json
recomp      -> src/game/recomp/gen/*.c
```

## Current State
- Pipeline runs clean end to end: 12,083/12,083 functions translated, 0 failures.
- Kernel layer not started. 147 imports to map. Nothing has been built or run yet.
- `src/game/` has no CMakeLists yet; the top-level `add_subdirectory(src/game)` is
  commented out until there is something to build.

## Next Steps
1. Kernel layer: map the 147 imports onto xboxrecomp's `xbox_kernel`.
2. `src/game/main.c` + `recomp_manual.c` from `xboxrecomp/templates/new-game/`.
3. First build, then first boot.
4. Turn on `-DCS_ICALL_FEEDBACK=ON` for the first runs and feed
   `tools.recomp.icall_feedback` back into detection -- the 17 stubs plus whatever
   indirect targets show up.

## Conventions
- Generated C is never committed (1.3M lines, reproducible in ~30s).
- The XBE is never committed.
- Toolkit fixes belong in xboxrecomp, not here. If something needs a title-specific
  workaround, it goes in `game/*.json` config or `src/game/recomp_manual.c`, not in a
  patched copy of the toolkit.
