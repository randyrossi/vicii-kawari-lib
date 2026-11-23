; ******************************************************************************
;
; VIC-II Kawari mailbox library: HOST side (C64 6510), BeebAsm syntax
;
; The 6510 queues commands for the Kawari 6502 co-processor in video RAM
; (VRAM) and the co-processor runs them. See ../README.md for the protocol
; and a walk-through. This file is byte-for-byte equivalent to
; ../ca65/mbx-host.inc; keep the two in step (make check compares them).
;
; Usage: define any overrides, then INCLUDE this file where the routines
; should be assembled (about 370 bytes). It needs beebasm 1.10 or later
; (conditional assignment, =?).
;
; Rules for callers (all of them matter):
;   * I/O must be mapped in at $D000 when any routine here is called.
;   * Every routine uses VRAM port 1 ($D035, $D039-$D03B) and rewrites
;     VIDEO_MEM_FLAGS ($D03F) as a whole, so port 2's function bits are
;     reset to "none" and the register overlay is left disabled. Interrupt
;     handlers must not touch these registers (or must save and restore them).
;   * All routines corrupt A and the flags; MBX_START, MBX_URGENT_OPEN and
;     MBX_ERROR also corrupt Y; MBX_UPLOAD corrupts A, X and Y.
;     Nothing else is touched apart from the three MBX_STATE bytes.
;
; ******************************************************************************

; ------------------------------------------------------------------------------
; Configuration. These must match the values given to mbx-cpu.asm; put any
; overrides in one project file that is included before both.
; ------------------------------------------------------------------------------

MBX_MAILBOX =? $7FF0        ; VRAM: +0 mailbox, +1 diagnostic, +2 urgent flag
MBX_BUF_A =? $1C00          ; VRAM: command buffer A (page aligned)
MBX_BUF_B =? $1E00          ; VRAM: command buffer B (page aligned)
MBX_URGENT_ARGS =? $7FC0    ; VRAM: urgent lane arguments
MBX_CPU_ENTRY =? $0200      ; VRAM: co-processor start address
MBX_CPU_SPEED =? 0          ; CPU_SPEED: 0 = fastest ... 3 = slowest
MBX_STATE =? $FB            ; C64 zero page: three bytes of host state

 ASSERT LO(MBX_BUF_A) = 0 AND LO(MBX_BUF_B) = 0
 ASSERT HI(MBX_BUF_A) <> HI(MBX_BUF_B)
 ASSERT HI(MBX_BUF_A) <> 0 AND HI(MBX_BUF_B) <> 0
 ASSERT MBX_STATE <= $FD

MBX_WRITE = MBX_STATE       ; (2 bytes) VRAM address of the next command
MBX_BUF = MBX_STATE+2       ; start page of the buffer the host is filling

MBX_FLAGS = $D03F           ; VIDEO_MEM_FLAGS
MBX_IDX = $D035             ; VIDEO_MEM_1_IDX
MBX_LO = $D039              ; VIDEO_MEM_1_LO
MBX_HI = $D03A              ; VIDEO_MEM_1_HI
MBX_VAL = $D03B             ; VIDEO_MEM_1_VAL: the byte at the port address

; ------------------------------------------------------------------------------
; MBX_ACTIVATE: unlock Kawari's extended registers ("VIC2" to $D03F).
; Call once before anything else, unless the program has already done it.
; ------------------------------------------------------------------------------
.MBX_ACTIVATE
 LDA #86                ; "V"
 STA MBX_FLAGS
 LDA #73                ; "I"
 STA MBX_FLAGS
 LDA #67                ; "C"
 STA MBX_FLAGS
 LDA #50                ; "2"
 STA MBX_FLAGS
 RTS

; ------------------------------------------------------------------------------
; MBX_RESET: hold the co-processor in reset. Do this before uploading code
; over a co-processor that may be running.
; ------------------------------------------------------------------------------
.MBX_RESET
 LDA #$20               ; register overlay on, no auto-increment
 STA MBX_FLAGS
 LDA #0
 STA MBX_IDX
 STA MBX_HI
 LDA #$22               ; CPU_CTRL
 STA MBX_LO
 LDA #1                 ; bit 0: RESET
 STA MBX_VAL
 LDA #0
 STA MBX_FLAGS
 RTS

; ------------------------------------------------------------------------------
; MBX_SEEK: point VRAM port 1 at address (Y A) (Y = high byte), with
; auto-increment and the register overlay off. Then read or write the bytes
; one after another through MBX_VAL ($D03B). Use it to read results, or to
; write data that is not a command. Preserves X and Y.
; ------------------------------------------------------------------------------
.MBX_SEEK
 PHA
 LDA #1                 ; port 1 auto-increment, overlay off
 STA MBX_FLAGS
 LDA #0
 STA MBX_IDX
 PLA
 STA MBX_LO
 STY MBX_HI
 RTS

; ------------------------------------------------------------------------------
; MBX_UPLOAD: copy X whole pages from C64 memory at (Y A) to the VRAM port.
; Call MBX_SEEK with the VRAM destination first; the co-processor should be
; in reset (MBX_RESET). Uses MBX_WRITE as its pointer, so it must not be
; called once MBX_START has run and commands are queued.
; ------------------------------------------------------------------------------
.MBX_UPLOAD
 STA MBX_WRITE
 STY MBX_WRITE+1
 LDY #0
.MBX_UPLOAD_BYTE
 LDA (MBX_WRITE),Y
 STA MBX_VAL
 INY
 BNE MBX_UPLOAD_BYTE
 INC MBX_WRITE+1
 DEX
 BNE MBX_UPLOAD_BYTE
 RTS

; ------------------------------------------------------------------------------
; MBX_START: (re)start the co-processor at MBX_CPU_ENTRY and wait until its
; mbx_main has acknowledged. Also empties the host's command buffers.
;
; Startup handshake: the host puts $FF in the mailbox, the co-processor
; clears it when it is ready for commands.
; ------------------------------------------------------------------------------
.MBX_START
 JSR MBX_RESET
 LDA #0
 STA MBX_WRITE
 LDA #HI(MBX_BUF_A)
 STA MBX_WRITE+1
 STA MBX_BUF
 LDA #LO(MBX_MAILBOX)
 LDY #HI(MBX_MAILBOX)
 JSR MBX_SEEK
 LDA #$FF
 STA MBX_VAL            ; mailbox: startup handshake
 LDA #0
 STA MBX_VAL            ; diagnostic: none
 STA MBX_VAL            ; urgent flag: none
 LDA #$20               ; register overlay on
 STA MBX_FLAGS
 LDA #0
 STA MBX_HI
 LDA #$20               ; CPU_START_LO
 STA MBX_LO
 LDA #LO(MBX_CPU_ENTRY)
 STA MBX_VAL
 INC MBX_LO             ; CPU_START_HI
 LDA #HI(MBX_CPU_ENTRY)
 STA MBX_VAL
 LDA #$2B               ; CPU_SPEED
 STA MBX_LO
 LDA #MBX_CPU_SPEED
 STA MBX_VAL
 LDA #$22               ; CPU_CTRL
 STA MBX_LO
 LDA #0
 STA MBX_VAL            ; release reset
                        ; fall through and wait for the acknowledgement

; ------------------------------------------------------------------------------
; MBX_WAIT: wait until the co-processor is idle (the submitted list is done).
; Commands still queued in the host's current buffer are NOT started; use
; MBX_FLUSH for that. Do not call between MBX_OPEN and MBX_CLOSE.
; ------------------------------------------------------------------------------
.MBX_WAIT
 JSR MBX_IDLE
 BNE MBX_WAIT
 RTS

; ------------------------------------------------------------------------------
; MBX_IDLE: Z set (A = 0) when the co-processor is idle, that is, when the
; mailbox is clear. Do not call between MBX_OPEN and MBX_CLOSE.
; ------------------------------------------------------------------------------
.MBX_IDLE
 LDA #0                 ; no auto-increment, overlay off
 STA MBX_FLAGS
 LDA #LO(MBX_MAILBOX)
 STA MBX_LO
 LDA #HI(MBX_MAILBOX)
 STA MBX_HI
 LDA MBX_VAL
 RTS

; ------------------------------------------------------------------------------
; MBX_OPEN: start writing a command. Afterwards write the command byte
; (1..MBX_CMD_COUNT) and its payload to MBX_VAL ($D03B), then call MBX_CLOSE.
;
; A command may only START in its buffer's first page. If the current buffer
; is past that, this waits for the co-processor to finish the other buffer,
; submits this one and switches. So a buffer needs 256 bytes, plus the
; longest command, plus one (the END byte).
; ------------------------------------------------------------------------------
.MBX_OPEN
 LDA MBX_WRITE+1
 CMP MBX_BUF
 BEQ MBX_SPACE          ; still in the first page: always room
 JSR MBX_WAIT
 JSR MBX_SUBMIT
.MBX_SPACE
 LDA #1                 ; port 1 auto-increment, overlay off
 STA MBX_FLAGS
 LDA #0
 STA MBX_IDX
 LDA MBX_WRITE
 STA MBX_LO
 LDA MBX_WRITE+1
 STA MBX_HI
 RTS

; ------------------------------------------------------------------------------
; MBX_CLOSE: finish the command begun with MBX_OPEN (records where the port
; has got to). The command is queued, not started: see MBX_KICK, MBX_FLUSH.
; ------------------------------------------------------------------------------
.MBX_CLOSE
 LDA MBX_LO
 STA MBX_WRITE
 LDA MBX_HI
 STA MBX_WRITE+1
 RTS

; ------------------------------------------------------------------------------
; MBX_KICK: start the queued commands if the co-processor is idle, and return
; at once either way. Use it after queueing work whose results are not needed
; yet, so that the co-processor works while the host carries on.
; ------------------------------------------------------------------------------
.MBX_KICK
 LDA MBX_WRITE
 BNE MBX_KICK_QUEUED
 LDA MBX_WRITE+1
 CMP MBX_BUF
 BEQ MBX_KICK_DONE      ; nothing is queued
.MBX_KICK_QUEUED
 JSR MBX_IDLE
 BNE MBX_KICK_DONE      ; busy: the commands stay queued
 JMP MBX_SUBMIT
.MBX_KICK_DONE
 RTS

; ------------------------------------------------------------------------------
; MBX_FLUSH: run everything queued and wait until the co-processor has
; finished it all. Call it before reading results, or to present a frame.
; ------------------------------------------------------------------------------
.MBX_FLUSH
 LDA MBX_WRITE
 BNE MBX_FLUSH_QUEUED
 LDA MBX_WRITE+1
 CMP MBX_BUF
 BEQ MBX_WAIT           ; nothing is queued: wait for what is running
.MBX_FLUSH_QUEUED
 JSR MBX_WAIT
 JSR MBX_SUBMIT
 JMP MBX_WAIT

; ------------------------------------------------------------------------------
; MBX_SUBMIT: hand the current buffer to the co-processor and switch to the
; other one. INTERNAL: the co-processor must be idle (MBX_KICK and MBX_FLUSH
; ensure that), or it could still be reading the buffer switched to.
; ------------------------------------------------------------------------------
.MBX_SUBMIT
 LDA #1
 STA MBX_FLAGS
 LDA MBX_WRITE
 STA MBX_LO
 LDA MBX_WRITE+1
 STA MBX_HI
 LDA #0
 STA MBX_VAL            ; END, committed before the mailbox is written
 STA MBX_FLAGS
 LDA #LO(MBX_MAILBOX)
 STA MBX_LO
 LDA #HI(MBX_MAILBOX)
 STA MBX_HI
 LDA MBX_BUF
 STA MBX_VAL            ; mailbox = start page: the co-processor is off
 EOR #HI(MBX_BUF_A) EOR HI(MBX_BUF_B)
 STA MBX_BUF
 STA MBX_WRITE+1
 LDA #0
 STA MBX_WRITE
 RTS

; ------------------------------------------------------------------------------
; MBX_ERROR: A = the diagnostic byte, Z set if there is none. $FF means the
; co-processor met an unknown command byte and dropped the rest of that
; list. The byte stays set until MBX_START. Call after MBX_FLUSH.
; ------------------------------------------------------------------------------
.MBX_ERROR
 LDA #LO(MBX_MAILBOX+1)
 LDY #HI(MBX_MAILBOX+1)
 JSR MBX_SEEK
 LDA MBX_VAL
 RTS

; ------------------------------------------------------------------------------
; Urgent lane: one request that overtakes queued and running commands.
;
;   JSR MBX_URGENT_OPEN   ; then write the arguments to MBX_VAL ($D03B)
;   JSR MBX_URGENT_GO     ; raises the flag and waits for the co-processor
;   LDA #LO(result): LDY #HI(result): JSR MBX_SEEK: LDA MBX_VAL ...
;
; The co-processor runs mbx_urgent_handler at its next poll point and clears
; the flag. Nothing queued is flushed. May be used between commands, but not
; between MBX_OPEN and MBX_CLOSE.
; ------------------------------------------------------------------------------
.MBX_URGENT_OPEN
 LDA #LO(MBX_URGENT_ARGS)
 LDY #HI(MBX_URGENT_ARGS)
 JMP MBX_SEEK

.MBX_URGENT_GO
 LDA #0                 ; no auto-increment while polling
 STA MBX_FLAGS
 LDA #LO(MBX_MAILBOX+2)
 STA MBX_LO
 LDA #HI(MBX_MAILBOX+2)
 STA MBX_HI
 LDA #1
 STA MBX_VAL            ; urgent flag
.MBX_URGENT_WAIT
 LDA MBX_VAL
 BNE MBX_URGENT_WAIT
 RTS
