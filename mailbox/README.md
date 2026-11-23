# Kawari mailbox library

A reusable version of the mechanism that Elite for VIC-II Kawari uses to make
the C64's 6510 and Kawari's 6502 co-processor work together. The 6510 (the
**host**) queues commands in video RAM; the co-processor runs them, about 16
times faster than the 6510, while the host carries on.

It was generalised from `elite-source-code-commodore-64` (`kawari-host.asm`,
`kawari-cpu.asm`, `kawari-move.asm`; protocol described in its `KAWARI.md`).
Elite keeps its own copy and does not use this library.

## Background: what the two CPUs can see

Read "6502 Co-Processor" in `vicii-kawari/doc/REGISTERS.md` first. In short:

- The co-processor's whole 64K address space **is** Kawari's video RAM (VRAM).
  Its zero page and stack are VRAM `$0000–$01FF`. It cannot see C64 memory or
  any I/O register.
- The 6510 reaches VRAM only through the port registers: set an address in
  `$D039`/`$D03A`, then read or write the byte at `$D03B`, with optional
  auto-increment (`$D03F` bit 0).
- So VRAM is the only shared medium, and the co-processor has no way to
  signal the host. Everything is done by the host writing bytes and polling.
- It needs a bitstream built with `WITH_CPU_COPROC`, or the
  `vicii-kawari-vice` emulator (not `vicii-vice-3.4`).

## The protocol

Three bytes of VRAM at `MBX_MAILBOX` (default `$7FF0`) coordinate everything:

| Byte | Name | Written by host | Written by co-processor |
| --- | --- | --- | --- |
| +0 | mailbox | start page of a command list: "run this" | 0: "done, idle" |
| +1 | diagnostic | 0 at start-up | `$FF`: unknown command met |
| +2 | urgent flag | 1: "run the urgent request" | 0: "urgent result ready" |

**Command lists.** A command is a command byte (1–127) followed by its
payload. A list is commands one after another, ended by a 0 byte (END),
starting at offset 0 of a page. To run a list the host writes END, then the
list's start page to the mailbox. The co-processor runs the list and clears the
mailbox.

**Double buffering.** There are two buffers, `MBX_BUF_A` and `MBX_BUF_B`. The
host fills one while the co-processor may be running the other, and only
switches when the co-processor is idle, so it never writes a buffer that is
being read. This is what lets drawing overlap the host's own work.

**Buffer size.** A command may only *start* in its buffer's first page. When
the host's write position has passed the first page, the next `MBX_OPEN` waits
for the co-processor, submits the buffer and switches. A buffer therefore needs
`256 + longest command + 1` bytes of VRAM, and a command can be at most 255
bytes.

**Urgent lane.** One request that must not wait behind queued work (Elite:
moving a ship while earlier ships are still being drawn). The host writes
arguments to `MBX_URGENT_ARGS`, sets the urgent flag and polls until it
clears. The co-processor checks the flag when idle, between commands, and
wherever a handler places `MBX_POLL_URGENT`.

**Start-up handshake.** The host writes `$FF` to the mailbox and releases the
co-processor from reset; `mbx_main` clears the mailbox when it is ready.

## Files

| Path | Purpose |
| --- | --- |
| `beebasm/mbx-host.asm`, `ca65/mbx-host.inc` | Host (6510) routines, about 370 bytes |
| `beebasm/mbx-cpu.asm`, `ca65/mbx-cpu.inc` | Co-processor dispatcher, about 105 bytes |
| `example/beebasm/`, `example/ca65/` | A complete demo that is also the self-test |
| `Makefile` | `make` builds the demo; `make check` tests the library |

The BeebAsm and ca65 versions produce identical code. **If you change one,
change the other**; `make check` fails if the two demo builds differ.

## Using it in a project

Copy the demo's structure: `example/<assembler>/demo-defs`, `demo-cpu` and
`demo-host`. The steps are:

### 1. Decide the VRAM layout

Put the layout in one definitions file that is included before the library on
both sides. Anything not defined takes the default.

| Symbol | Default | Side | Meaning |
| --- | --- | --- | --- |
| `MBX_MAILBOX` | `$7FF0` | both | The three coordination bytes |
| `MBX_BUF_A`, `MBX_BUF_B` | `$1C00`, `$1E00` | host | Command buffers, page aligned, not in page 0 |
| `MBX_URGENT_ARGS` | `$7FC0` | host | Where urgent arguments go (the project's handler reads them) |
| `MBX_CPU_ENTRY` | `$0200` | host | Co-processor start address |
| `MBX_CPU_SPEED` | `0` | host | `CPU_SPEED` register: 0 fastest |
| `MBX_STATE` | `$FB` | host | Three bytes of **C64** zero page |
| `MBX_CMD`, `MBX_VEC` | `$00`, `$02` | co-processor | Two bytes each of **co-processor** zero page |
| `MBX_CMD_COUNT` | (required) | co-processor | Highest command number |
| `MBX_URGENT` | off | co-processor | BeebAsm `TRUE` / ca65 `1` to assemble the urgent lane |

Keep the buffers, the mailbox, the urgent arguments, results, the
co-processor's code and the displayed image from overlapping. Nothing checks
this for you.

### 2. Write the co-processor program

It is assembled at its VRAM address as a separate binary (BeebAsm: `ORG` and
`SAVE`; ca65: its own `ld65 -t none -S <address>` link).

```
MBX_CMD_COUNT = 2
 ORG MBX_CPU_ENTRY
.entry
 SEI
 CLD
 LDX #$FF
 TXS                    ; stack in VRAM $0100-$01FF
 ...                    ; own initialisation
 JMP mbx_main           ; never returns
 INCLUDE "../vicii-kawari-lib/mailbox/beebasm/mbx-cpu.asm"
.mbx_cmd_table
 EQUW cmd_one, cmd_two  ; handlers for commands 1, 2, ...
```

A handler is called with `Y = 0` and `(MBX_CMD),Y` pointing at its command
byte, so the payload is read with `INY` / `LDA (MBX_CMD),Y`. It returns with
`A` = the command's total length including the command byte. That is how
variable-length commands work (`cmd_sum` in the demo). It must not change
`MBX_CMD`.

For the urgent lane, define `mbx_urgent_handler` (a subroutine that reads
`MBX_URGENT_ARGS`, leaves its result somewhere in VRAM and returns), and put
`MBX_POLL_URGENT` in the loops of long handlers. `MBX_POLL_URGENT` corrupts A.
An urgent handler interrupts other handlers mid-job, so it must save and
restore any zero page or workspace it shares with them (A, X and Y are saved
for it).

Use only legal NMOS 6502 instructions, and **not `BIT`**: the co-processor
core in `vicii-kawari-vice` sets the carry on `BIT`.

### 3. Start it from the host

BeebAsm paths are relative to the directory beebasm runs in. For ca65 pass
`-I <path>/vicii-kawari-lib/mailbox/ca65` and `.include "mbx-host.inc"`.

```
 JSR MBX_ACTIVATE       ; unlock the extended registers ("VIC2")
 JSR MBX_RESET          ; hold the co-processor while its code is replaced
 LDA #LO(MBX_CPU_ENTRY) ; VRAM destination
 LDY #HI(MBX_CPU_ENTRY)
 JSR MBX_SEEK
 LDA #LO(cpu_image)     ; C64 source, X = whole pages
 LDY #HI(cpu_image)
 LDX #pages
 JSR MBX_UPLOAD
 JSR MBX_START          ; start it and wait for the handshake
```

`MBX_UPLOAD` copies whole pages, so up to 255 bytes after the image are
overwritten in VRAM. Repeat `MBX_SEEK` / `MBX_UPLOAD` for further blocks or
tables before `MBX_START`.

### 4. Send commands and read results

```
 JSR MBX_OPEN           ; then write the command to $D03B (MBX_VAL)
 LDA #CMD_ADD
 STA MBX_VAL
 LDA #100
 STA MBX_VAL
 LDA #200
 STA MBX_VAL
 JSR MBX_CLOSE          ; queued, not started

 JSR MBX_FLUSH          ; run everything queued and wait
 LDA #LO(RES_ADD)       ; results: wherever the handler put them in VRAM
 LDY #HI(RES_ADD)
 JSR MBX_SEEK
 LDA MBX_VAL            ; successive reads step through VRAM
```

| Routine | Use |
| --- | --- |
| `MBX_OPEN` … `MBX_CLOSE` | Queue one command. Write exactly the bytes the handler will consume |
| `MBX_KICK` | Start what is queued if the co-processor is idle; never waits. Call it after queueing work whose result is not needed yet |
| `MBX_FLUSH` | Run everything queued and wait for it. Call it before reading results or showing a frame |
| `MBX_IDLE` | Z set if the co-processor is idle |
| `MBX_WAIT` | Wait for the running list only (queued commands are not started) |
| `MBX_SEEK` | Point the port at VRAM address (Y A) for reading or writing |
| `MBX_ERROR` | A = diagnostic; `$FF` after an unknown command |
| `MBX_URGENT_OPEN`, `MBX_URGENT_GO` | Write urgent arguments; then raise the flag and wait for the result |
| `MBX_SUBMIT` | Internal. Do not call it: it is only safe when the co-processor is idle |

The usual pattern for speed is `OPEN`/`CLOSE`/`KICK` for each piece of work
through a frame, and one `MBX_FLUSH` at the end.

## Rules that are easy to get wrong

- **I/O must be banked in** (`$01` bit 2 set, with CHAREN) whenever a routine
  is called or `$D03B` is touched. Elite wraps each call to save and restore
  its banking; see `KW_SAVE`/`KW_RESTORE` in its `kawari-defs.asm`.
- **Only one context may use the VRAM port.** Every routine sets port 1's
  address and rewrites `$D03F`. An interrupt handler that touches `$D035`,
  `$D039–$D03B` or `$D03F` will corrupt a command being written. Either keep
  interrupts away from them (Elite's raster IRQ only writes `$D037`) or save
  and restore all of them.
- **Port 2 and the overlay.** `$D03F` is written as a whole, so port 2's
  function bits return to "none" and the register overlay (`$20`)
  is switched off after every call. Set them again if needed, for example
  before a DMA copy.
- **Nothing between `MBX_OPEN` and `MBX_CLOSE`** except writes to `MBX_VAL`:
  no `MBX_IDLE`, `MBX_WAIT`, `MBX_SEEK`, `MBX_ERROR`, urgent calls or
  anything else that moves the port.
- **The byte count must match.** If the host writes fewer or more bytes than
  the handler's returned length, every later command in the list is
  misread. An unknown command byte sets the diagnostic and drops the rest of
  that list (checking `MBX_ERROR` after a flush is a cheap assertion while
  developing).
- **Read results only after `MBX_FLUSH`** (or after `MBX_URGENT_GO` for the
  urgent lane). Otherwise the command may not have run, or a multi-byte
  result may be half written.
- **All routines corrupt A**; see the header of `mbx-host` for X and Y.
- **One urgent request at a time**, and the host waits for it. If its result
  depends on queued commands, `MBX_FLUSH` first; if queued work should start
  before the host blocks, `MBX_KICK` first (Elite does this).
- `MBX_UPLOAD` borrows `MBX_STATE`; use it only before `MBX_START`.
  `MBX_START` may be called again to restart the co-processor; it discards
  anything still queued.

## Testing

`make check` assembles the demo with both assemblers, requires identical
output, and runs it headless in `../../vicii-kawari-vice/src/x64sc` with the
debug cartridge. The demo covers: start-up, a command and its result, 600
commands with `MBX_KICK` (buffer switching while the co-processor runs),
variable-length commands crossing a buffer's first page, an urgent request
overtaking a running command, and the unknown-command diagnostic. Exit code
`16 + n` names the failed test in `demo-host`; `1` means it hung.

To test a project's own co-processor code without the whole emulator, see
Elite's `2-build-files/tests/cpu_bridge.c` and `test_kawari.py`, which run an
assembled VRAM image on the emulator's 6502 core from Python.

Tested in the emulator only, not on a physical board. On real hardware the
co-processor stalls briefly whenever the 6510 touches `$D02F–$D03F` (not
modelled by the emulator), so tight polling loops slow it slightly.
