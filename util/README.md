# Kawari utility library

Common routines for C64 (6510) programs that use VIC-II Kawari. For now there
are two jobs: switching Kawari's extensions on, and checking that the firmware
is new enough. Both come from Elite for VIC-II Kawari's boot loader
(`elite-source-code-commodore-64/1-source-files/main-sources/kawari-boot.asm`),
which keeps its own copy and does not use this library.

| Path | Purpose |
| --- | --- |
| `beebasm/kawari-util.asm`, `ca65/kawari-util.inc` | The routines, 95 bytes |
| `example/beebasm/demo.asm`, `example/ca65/demo.s` | Prints the firmware version; also the self-test |
| `Makefile` | `make` builds the demo; `make check` tests the library |

The BeebAsm and ca65 versions produce identical code. **If you change one,
change the other**; `make check` fails if the two demo builds differ.

## Background

- After reset a Kawari behaves as a plain VIC-II. Its extended registers
  (`$D02F–$D03F`) only respond after the four bytes `"VIC2"` (86, 73, 67, 50)
  have been written to `$D03F`. On a C64 with an ordinary VIC-II these writes
  do nothing.
- The firmware version is in two read-only "extra registers": `$83` major and
  `$84` minor, both plain binary numbers (firmware 1.20 is major 1, minor 20,
  not `$20`). Extra registers are read through the video memory port with the
  register overlay enabled (`$D03F` = `$20`, address in `$D039`/`$D03A`, value
  at `$D03B`); see `vicii-kawari/doc/REGISTERS.md`.
- Without a Kawari, or before the `"VIC2"` sequence, `$D03B` reads `$FF`, so
  the version reads as 255.255. The routines treat a major version of `$FF`
  as "no Kawari".

## Routines

I/O must be mapped in at `$D000` (`$01` bit 2 set, with CHAREN) when any of
them is called. They use no memory except the stack.

### `KAWARI_INIT`

Unlocks the extended registers by writing `"VIC2"` to `$D03F`, then sets
`$D03F` (VIDEO_MEM_FLAGS) to 0: no auto-increment, register overlay off.

- In: nothing. Out: nothing. Corrupts A.
- Call it once, before anything else that uses Kawari. It is safe on a
  machine without a Kawari, so call it first and check the version second.
- It does not change the video mode, palette or the co-processor.

### `KAWARI_VERSION`

Reads the firmware version.

- Out: A = major, X = minor. A = X = `$FF` if there is no Kawari or
  `KAWARI_INIT` has not been called. Preserves Y.
- Side effects: sets port 1's address (`$D039`, `$D03A`) and leaves `$D03F`
  at 0.

### `KAWARI_CHECK_VERSION`

Checks for a Kawari with at least a given firmware version.

- In: A = lowest acceptable major version, X = lowest acceptable minor.
- Out: **C set** if a Kawari is present and its firmware is that version or
  later; **C clear** if it is older or there is no Kawari. A = major and
  X = minor actually found (`$FF`, `$FF` for no Kawari), so the caller can
  tell the two failures apart or print the version. Corrupts Y.
- Side effects: as `KAWARI_VERSION`.

The comparison is major first, then minor: 2.0 satisfies a request for 1.20,
and 1.5 does not.

### Constants

`KAWARI_COPROC_MAJOR` = 1 and `KAWARI_COPROC_MINOR` = 20: the first firmware
with the 6502 co-processor. `KAWARI_REG_MAJOR` = `$83` and
`KAWARI_REG_MINOR` = `$84`: the extra register numbers.

## Using it in a project

BeebAsm (the path is relative to the directory beebasm runs in):

```
 INCLUDE "../vicii-kawari-lib/util/beebasm/kawari-util.asm"
```

ca65 (assemble with `-I <path>/vicii-kawari-lib/util/ca65`):

```
 .include "kawari-util.inc"
```

Include it where the code should be placed; it assembles straight into the
program. Then, at start-up:

```
 JSR KAWARI_INIT
 LDA #KAWARI_COPROC_MAJOR   ; or whatever the program needs
 LDX #KAWARI_COPROC_MINOR
 JSR KAWARI_CHECK_VERSION
 BCC too_old                ; A.X = version found, $FF.$FF = no Kawari
 ...                        ; safe to use Kawari features from here
```

On failure, tell the user and return to BASIC (or stop) rather than carrying
on: a program that goes on to start the co-processor on old firmware, or to
wait for it on a plain VIC-II, hangs with no explanation. Elite prints
"Kawari firmware v1.20 or higher is required." and returns to `READY.`

## Things to know

- **Interrupts.** `KAWARI_VERSION` and `KAWARI_CHECK_VERSION` use the VRAM
  port. Call them at start-up before any interrupt handler that uses
  `$D039–$D03B` or `$D03F` is installed.
- **Port state.** After these routines port 1's address is `$0083` and
  `$D03F` is 0. Code that relied on auto-increment or the overlay being on
  must set `$D03F` again.
- **With the mailbox library.** `MBX_ACTIVATE` in `../mailbox` writes the same
  `"VIC2"` sequence as `KAWARI_INIT`; calling both is harmless. Check for
  `KAWARI_COPROC_MAJOR`.`KAWARI_COPROC_MINOR` before `MBX_START`, which
  otherwise waits for ever for a co-processor that is not there.
- **Variants and capabilities are not checked.** A fork of the firmware may
  report a suitable version without having a given feature. The variant name
  (extra registers `$90–$9F`) and capability bits (`$87`, `$88`) are described
  in `REGISTERS.md`; there are no routines for them yet.
- **A minor version is binary.** Print it as a two-digit decimal number
  (`print_number` in the demo), or 1.5 and 1.50 look different.

## Testing

`make check` builds the demo with both assemblers, requires identical output,
and runs it headless twice: in `../../vicii-kawari-vice/src/x64sc`, where it
must find firmware 1.20 or later and four comparison checks must give the
right answers, and in a VICE without Kawari (`STOCK_X64SC`, default
`/usr/bin/x64sc`; skipped if missing), where it must report that there is no
Kawari. The exit codes are listed in the `Makefile`.

Tested in the emulators only, not on a physical board.
