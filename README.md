# Crimson Skies: High Road to Revenge — Static Recompilation

A static recompilation of the original Xbox game **Crimson Skies: High Road to Revenge**
(2003, FASA Studio) into a native Windows executable.

The game's original x86-32 machine code is translated into portable C, which is then
compiled to a native x86-64 binary. **No emulation happens at runtime** — there is no
interpreter, no JIT, and no CPU loop. The game's own instructions become C statements
once, ahead of time, and the compiler optimises them like any other source file.

Built with the [xboxrecomp](https://github.com/sp00nznet/xboxrecomp) toolkit.

> **Why this title?** Microsoft shipped their *own* static recompilation of Crimson Skies
> for Xbox backward compatibility, which makes it the one game on the platform where our
> output can be compared against a professional implementation of the same idea. That
> teardown drove several toolkit fixes that landed before this project was even created —
> see [Standing on Microsoft's Shoulders](#standing-on-microsofts-shoulders).

---

## Status

| Phase | Status | Details |
|-------|--------|---------|
| XBE Parsing | **Done** | 32 sections, 147 kernel imports |
| Disassembly | **Done** | 12,083 functions, 78.6% reachable |
| Function ID | **Done** | 8,604 classified, 4,438 vtable thunks, 12 CRT |
| Recompilation | **Done** | 1,329,736 lines of C, 13 files, **0 failures** |
| Kernel Layer | Not started | 147 imports to map |
| First Build | Not started | Pending kernel layer |
| First Boot | Not started | |
| Graphics (D3D8 → D3D11) | Not started | |
| Audio (DSound → XAudio2) | Not started | |
| Input (XPP → XInput) | Not started | |
| Gameplay | Not started | |

**Translation coverage: 12,083 / 12,083 functions (100%), 0 failed.**
17 addresses are called but were not detected as functions, and are stubbed.

That last number is the one worth watching. Halo build 2276 started at 46. Crimson Skies
starts at 17 on a *larger* code section, because three toolkit fixes landed first.

---

## XBE Analysis

| Property | Value |
|----------|-------|
| Title | Crimson Skies: High Road to Revenge |
| Title ID | `0x4D530021` |
| Developer | FASA Studio |
| Publisher | Microsoft Game Studios |
| Release | October 2003 |
| Build date | 2003-09-21 00:02:19 UTC |
| Build path | `c:\ca\xproduction\default.exe` |
| Base address | `0x00010000` |
| Entry point | `0x001C7CA9` |
| Image size | `0x00339C60` (3.23 MB) |
| Kernel thunks | `0x0028E480` |
| `.text` size | 1,978 KB |
| Sections | 32 (11 of them Bink video codecs) |
| Kernel imports | 147 |
| TLS index addr | `0x00327FD0` |

### Memory map

```
0x00011000  .text       1978 KB   Game code
0x001FF980  D3D           78 KB   Direct3D 8
0x002133E0  D3DX         133 KB   D3DX extensions
0x00234A40  XGRPH          9 KB   Xbox graphics helpers
0x00236EA0  DSOUND        50 KB   DirectSound
0x00243740  BINK*        ~85 KB   Bink video codec (11 sections)
0x00258FE0  XONLINE      105 KB   Xbox Live
0x00273420  XNET          72 KB   Networking
0x002857E0  XPP           35 KB   Xbox Platform Plugin (input)
0x0028E480  .rdata       340 KB   Constants + kernel thunk table
0x002E3780  .data        299 KB   Data + BSS
0x0032E6A0  DOLBY         28 KB   Dolby audio
0x00335820  BINKDATA      61 KB   Bink tables
0x00346460  $$XTIMAGE     10 KB   Title image
0x00348C60  $$XSIMAGE      4 KB   Save image
```

### What the code looks like

The detection method breakdown says a lot about how this game was built:

| Method | Count | |
|--------|------:|---|
| `call_target` | 6,112 | reached by a direct `call` |
| `cc_boundary` | 4,418 | found after `int3` padding |
| `prologue` | 1,444 | classic `push ebp; mov ebp, esp` |
| `tail_jump_target` | 105 | only ever reached by `jmp` |
| `entry_point` | 1 | |

Only **12%** of functions have a standard prologue. Halo 2276, for comparison, is 71%
prologue-detected. Crimson Skies was compiled with aggressive frame-pointer omission, so
`cc_boundary` — walking the `int3` padding the linker leaves between functions — does more
work here than pattern-matching prologues ever could.

That also means this title leans hard on the parts of the toolkit that do *not* depend on
recognising a prologue, which is exactly where the recent fixes landed.

---

## Standing on Microsoft's Shoulders

Microsoft's Xbox BC package for this game is a static recompiler too — `ficompiler.exe`,
internally "Fission", lifting x86-32 into the Phoenix compiler backend. Tearing it down
produced findings that changed the toolkit before this project started. The full analysis
lives in xboxrecomp:

- [ms-fusion-recompiler.md](https://github.com/sp00nznet/xboxrecomp/blob/main/docs/technical/ms-fusion-recompiler.md) — pipeline, address map, HLE boundary
- [ms-fusion-codegen-teardown.md](https://github.com/sp00nznet/xboxrecomp/blob/main/docs/technical/ms-fusion-codegen-teardown.md) — IDA teardown of both their translators
- [ms-fusion-adoption-plan.md](https://github.com/sp00nznet/xboxrecomp/blob/main/docs/technical/ms-fusion-adoption-plan.md) — what we took, and what we measured and rejected

The short version of what they do differently:

| | Microsoft (x86 path) | xboxrecomp |
|---|---|---|
| Output | x86-64 machine code via Phoenix | **C source** |
| Guest registers | host registers, 1:1 | TLS globals |
| Guest flags | host flags, free | synthesised |
| Entry granularity | ~every byte (97.6% of the code span) | function starts |
| Host control flow | one flat arena, `jmp` only | real C functions |
| HLE boundary | `xboxkrnl` only; GPU emulated at register level | D3D8/DSound/XAPI reimplemented |

Their 41 MB DLL for this game contains a 20 MB address map and a `PrecompiledSymbolTable`
naming 2,997 guest functions. Notably, they **recompile the game's own statically-linked
D3D8, D3DX, DirectSound and XAPI verbatim** and replace nothing above the kernel — they can
afford that because they own a hardware-accurate NV2A consumer from 2007. We don't, so our
D3D8 layer is reimplemented rather than translated. That's forced, not a shortcut.

Three toolkit changes came directly out of that teardown and are why this project's stub
count starts at 17:

1. **Real guest return addresses** — `call` now pushes the address of the following
   instruction instead of `0`. Both of Microsoft's translators write the true value even
   though neither uses it for control transfer, because guest code *reads* it
   (`__SEH_prolog`'s scope table, `_alloca` probes, `mov eax, [esp]`).
2. **Indirect-branch target feedback** — record what the game actually branches to at
   runtime and feed it back as detection seeds, the local form of their
   `VirtualDispatchTraceFiles` + `UpdateEnlightenments`.
3. **Call-target realignment** — the linear sweep decodes each section as one stream and
   goes out of phase wherever it crosses data, which silently discarded provable function
   starts. Now it decodes at the target instead.

---

## Building

### Prerequisites

- Windows 11
- Visual Studio 2022 (MSVC)
- CMake 3.20+
- Python 3.10+ with `capstone` (`pip install capstone pefile`)
- [xboxrecomp](https://github.com/sp00nznet/xboxrecomp) cloned alongside this repo

### Get the XBE

Not redistributable — extract it from your own disc image:

```bash
cd ../xboxrecomp
py -3 -m tools.xiso get "Crimson Skies - High Road to Revenge (USA).iso" \
    default.xbe -o ../crimsonskies/game/
```

### Regenerate the C

```bash
./regen.sh          # or ./regen.sh --disasm after a tools/disasm change
```

The pipeline order is not arbitrary: `disasm` rewrites `functions.json` from scratch, so
every later naming pass has to run after it.

### Compile

```bash
cmake -S . -B build
cmake --build build --config Release
```

---

## Layout

```
game/       default.xbe (not committed) + analysis JSON
build/      disasm/, func_id/, recomp/ intermediates (not committed)
src/game/   main.c, hand-written overrides, and recomp/gen/ (not committed)
docs/       per-subsystem notes as they get written
tools/      title-specific helper scripts
```

Generated C is not committed. It is 1.3 million lines, it is reproducible from the XBE in
about 30 seconds, and a diff of it is unreadable. `regen.sh` is the source of truth.

---

## Legal

This repository contains **no game code, assets, or data**. It contains build scripts and
analysis metadata. Recompilation requires a legally obtained copy of the game, and the XBE
never enters version control.

Crimson Skies is a trademark of Microsoft. This is an unaffiliated preservation and
reverse-engineering project.
