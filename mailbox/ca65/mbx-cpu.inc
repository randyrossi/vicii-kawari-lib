; ******************************************************************************
;
; VIC-II Kawari mailbox library: CO-PROCESSOR side (Kawari 6502), ca65
;
; The command dispatcher that runs in video RAM (VRAM) on Kawari's 6502
; co-processor. See ../README.md. Byte-for-byte equivalent to
; ../beebasm/mbx-cpu.asm; keep the two in step (make check compares them).
;
; Usage, in a source file linked at its VRAM address (ca65 -I .../mailbox/ca65):
;
;   MBX_CMD_COUNT = 2               ; commands 1..2 (required, before .include)
;   .include "mbx-cpu.inc"
;   entry:                          ; = MBX_CPU_ENTRY on the host side
;    SEI
;    CLD
;    LDX #$FF
;    TXS
;    ...                            ; the program's own initialisation
;    JMP mbx_main                   ; never returns
;   mbx_cmd_table:
;    .word cmd_one, cmd_two         ; handlers for commands 1, 2, ...
;
; A handler is called with JSR, with Y = 0 and (MBX_CMD),Y addressing its own
; command byte, so its payload is at Y = 1 onwards. It must return with
; A = the command's total length in bytes, command byte included (1..255),
; and must leave MBX_CMD alone. X, Y and the flags may be corrupted.
;
; Only legal NMOS 6502 instructions are used, and no BIT (the VICE Kawari
; co-processor core sets the carry on BIT). Handlers should do the same.
;
; ******************************************************************************

; ------------------------------------------------------------------------------
; Configuration. MBX_MAILBOX must match the host side (mbx-host.inc).
; ------------------------------------------------------------------------------

.ifndef MBX_MAILBOX
MBX_MAILBOX = $7FF0         ; VRAM: +0 mailbox, +1 diagnostic, +2 urgent flag
.endif
.ifndef MBX_CMD
MBX_CMD = $00               ; co-processor zero page (2 bytes): this command
.endif
.ifndef MBX_VEC
MBX_VEC = $02               ; co-processor zero page (2 bytes): its handler
.endif
.ifndef MBX_URGENT
MBX_URGENT = 0              ; 1 to assemble the urgent lane, which needs
.endif                      ; the label mbx_urgent_handler to be defined

.assert MBX_CMD_COUNT >= 1 && MBX_CMD_COUNT <= 127, error, "MBX_CMD_COUNT must be 1..127"
.assert MBX_CMD < $FF && MBX_VEC < $FF, error, "MBX_CMD and MBX_VEC must be in zero page"

MBX_DIAG = MBX_MAILBOX+1
MBX_URGENT_FLAG = MBX_MAILBOX+2

; ------------------------------------------------------------------------------
; MBX_POLL_URGENT: run a pending urgent request now. Place it at points in
; long handlers where an interruption is safe (the dispatcher already polls
; when idle and between commands). Corrupts A and the flags only. Assembles
; nothing unless MBX_URGENT is 1.
; ------------------------------------------------------------------------------
.macro MBX_POLL_URGENT
 .local none
 .if MBX_URGENT
  LDA MBX_URGENT_FLAG
  BEQ none
  JSR mbx_urgent_run
 none:
 .endif
.endmacro

; ------------------------------------------------------------------------------
; mbx_main: acknowledge the host's startup handshake, then run command lists
; for ever. Jump here once the program has initialised itself.
;
; The mailbox holds the start page of a command list (0 = idle). The list is
; run from offset 0 of that page until an END (0) command byte, and then the
; mailbox is cleared, which tells the host the list is done.
; ------------------------------------------------------------------------------
mbx_main:
 LDA #0
 STA MBX_URGENT_FLAG
 STA MBX_MAILBOX        ; ready: acknowledges MBX_START
mbx_idle:
 MBX_POLL_URGENT
 LDA MBX_MAILBOX
 BEQ mbx_idle
 STA MBX_CMD+1          ; the mailbox holds the list's start page
 LDA #0
 STA MBX_CMD
mbx_dispatch:
 MBX_POLL_URGENT
 LDY #0
 LDA (MBX_CMD),Y
 BEQ mbx_complete       ; END
 CMP #MBX_CMD_COUNT+1
 BCS mbx_invalid
 ASL A
 TAX
 LDA mbx_cmd_table-2,X
 STA MBX_VEC
 LDA mbx_cmd_table-1,X
 STA MBX_VEC+1
 JSR mbx_call           ; returns A = the command's length
 CLC
 ADC MBX_CMD
 STA MBX_CMD
 BCC mbx_dispatch
 INC MBX_CMD+1
 BNE mbx_dispatch
mbx_invalid:
 ; Unknown command: leave a diagnostic and drop the rest of the list, as
 ; its length (and so the next command) cannot be known.
 LDA #$FF
 STA MBX_DIAG
mbx_complete:
 LDA #0
 STA MBX_MAILBOX        ; done: the host may submit the next list
 BEQ mbx_idle
mbx_call:
 JMP (MBX_VEC)          ; MBX_VEC is in zero page, so never at a page end

; ------------------------------------------------------------------------------
; mbx_urgent_run: call mbx_urgent_handler, then clear the urgent flag, which
; tells the host the result is ready. A, X and Y are preserved for the
; interrupted job; the handler must itself preserve any other workspace it
; shares with interruptible handlers.
; ------------------------------------------------------------------------------
.if MBX_URGENT
mbx_urgent_run:
 PHA
 TXA
 PHA
 TYA
 PHA
 JSR mbx_urgent_handler
 LDA #0
 STA MBX_URGENT_FLAG    ; the result is complete
 PLA
 TAY
 PLA
 TAX
 PLA
 RTS
.endif
