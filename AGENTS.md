# vicii-kawari-lib

Reusable 6502 assembly libraries for C64 programs that use VIC-II Kawari
extensions. Projects import the sources directly; nothing here is built into
a binary library.

mailbox
    Communication between the C64's 6510 and Kawari's 6502 co-processor:
    double-buffered command lists in video RAM, a mailbox byte, and an
    urgent lane. Read mailbox/README.md before using or changing it.

util
    Common start-up routines: unlock Kawari's extended registers
    (KAWARI_INIT) and check for a minimum firmware version
    (KAWARI_CHECK_VERSION). Read util/README.md. New general-purpose
    routines that several projects would want belong here.

## Using util from another project

- BeebAsm: `INCLUDE "<path>/vicii-kawari-lib/util/beebasm/kawari-util.asm"`.
- ca65: assemble with `-I <path>/vicii-kawari-lib/util/ca65`, then
  `.include "kawari-util.inc"`.
- A program should call `KAWARI_INIT`, then `KAWARI_CHECK_VERSION`, before it
  uses any Kawari feature, and stop with a message if the check fails.

## Using the mailbox from another project

- BeebAsm projects: `INCLUDE "<path>/vicii-kawari-lib/mailbox/beebasm/mbx-host.asm"`
  on the 6510 side and `.../mbx-cpu.asm` in the co-processor program. Paths
  are relative to the directory beebasm is run from. Needs the newer beebasm
  in `../tools/beebasm-new` (the `=?` operator).
- ca65 projects: assemble with `-I <path>/vicii-kawari-lib/mailbox/ca65`, then
  `.include "mbx-host.inc"` and `.include "mbx-cpu.inc"`.
- Start from the demo in `mailbox/example/`: copy `demo-defs`, `demo-cpu` and
  `demo-host` and replace the commands.
- Do not copy the library into the project; include it in place so fixes are
  shared.

## Changing the library

- The BeebAsm and ca65 sources must stay equivalent. Edit both, then run
  `make check` in the library's directory (`mailbox/` or `util/`); it
  compares the two builds and runs the self-test in
  `../vicii-kawari-vice/src/x64sc`.
- When adding a routine to `util`, add it to both sources, document it in
  `util/README.md` (inputs, outputs, registers corrupted, side effects on
  the VRAM port) and exercise it in the demo.
- Co-processor code: legal NMOS 6502 only, and no `BIT`.
- `elite-source-code-commodore-64` has its own copies of this code and does
  not use these libraries. Do not change it to match.
