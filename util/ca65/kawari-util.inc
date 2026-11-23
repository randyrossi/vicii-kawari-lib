; ******************************************************************************
;
; VIC-II Kawari utility library, ca65 syntax
;
; Common routines for C64 (6510) programs that use Kawari. See ../README.md.
; Byte-for-byte equivalent to ../beebasm/kawari-util.asm; keep the two in step
; (make check compares them).
;
; Usage: .include this file where the routines should be assembled (95 bytes).
; I/O must be mapped in at $D000 when a routine is called. The routines use
; no memory apart from the stack, so they can run from ROM.
;
; ******************************************************************************

KAWARI_FLAGS = $D03F        ; VIDEO_MEM_FLAGS
KAWARI_LO = $D039           ; VIDEO_MEM_1_LO
KAWARI_HI = $D03A           ; VIDEO_MEM_1_HI
KAWARI_VAL = $D03B          ; VIDEO_MEM_1_VAL

KAWARI_REG_MAJOR = $83      ; extra register: firmware major version
KAWARI_REG_MINOR = $84      ; extra register: firmware minor version

; The first firmware with the 6502 co-processor is 1.20.
KAWARI_COPROC_MAJOR = 1
KAWARI_COPROC_MINOR = 20

; ------------------------------------------------------------------------------
; KAWARI_INIT: unlock Kawari's extended registers ($D02F-$D03F) by writing
; "VIC2" to $D03F, and leave VIDEO_MEM_FLAGS at 0 (no auto-increment, register
; overlay off). Until this is done the chip behaves as a plain VIC-II. It is
; harmless on a C64 without a Kawari, so call it first and then check the
; version. Corrupts A and the flags.
; ------------------------------------------------------------------------------
KAWARI_INIT:
 LDA #86                ; "V"
 STA KAWARI_FLAGS
 LDA #73                ; "I"
 STA KAWARI_FLAGS
 LDA #67                ; "C"
 STA KAWARI_FLAGS
 LDA #50                ; "2"
 STA KAWARI_FLAGS
 LDA #0
 STA KAWARI_FLAGS
 RTS

; ------------------------------------------------------------------------------
; KAWARI_VERSION: read the firmware version: A = major, X = minor, both
; binary (version 1.20 gives A = 1, X = 20). A C64 without a Kawari, or one
; where KAWARI_INIT has not been called, gives A = X = $FF.
;
; Uses VRAM port 1's address ($D039, $D03A) and leaves VIDEO_MEM_FLAGS at 0.
; Corrupts the flags; preserves Y.
; ------------------------------------------------------------------------------
KAWARI_VERSION:
 LDA #$20               ; extra register overlay on, no auto-increment
 STA KAWARI_FLAGS
 LDA #0
 STA KAWARI_HI          ; the overlay is VRAM page 0 only
 LDA #KAWARI_REG_MINOR
 STA KAWARI_LO
 LDX KAWARI_VAL
 LDA #KAWARI_REG_MAJOR
 STA KAWARI_LO
 LDA KAWARI_VAL
 PHA
 LDA #0
 STA KAWARI_FLAGS       ; overlay off
 PLA
 RTS

; ------------------------------------------------------------------------------
; KAWARI_CHECK_VERSION: is there a Kawari with firmware A.X or later?
; Call with A = the lowest acceptable major version and X = the minor.
;
; Returns C set if so, and C clear if the firmware is older or there is no
; Kawari at all. Either way A = the major and X = the minor version found
; ($FF, $FF if no Kawari). Call KAWARI_INIT first. Corrupts Y.
;
;   JSR KAWARI_INIT
;   LDA #KAWARI_COPROC_MAJOR
;   LDX #KAWARI_COPROC_MINOR
;   JSR KAWARI_CHECK_VERSION
;   BCC too_old           ; tell the user, and do not carry on
; ------------------------------------------------------------------------------
KAWARI_CHECK_VERSION:
 PHA                    ; required major
 TXA
 PHA                    ; required minor
 JSR KAWARI_VERSION
 TAY                    ; Y = major found
 TXA
 PHA                    ; minor found
 TSX                    ; $0101,X found minor, $0102,X required minor,
                        ; $0103,X required major
 CPY #$FF
 BEQ KAWARI_CHECK_BAD   ; no Kawari
 TYA
 CMP $0103,X
 BNE KAWARI_CHECK_DONE  ; majors differ: C set if newer, clear if older
 LDA $0101,X
 CMP $0102,X
 BCS KAWARI_CHECK_DONE  ; same major: C set if the minor is high enough
KAWARI_CHECK_BAD:
 CLC
KAWARI_CHECK_DONE:
 PLA
 TAX                    ; X = minor found
 PLA
 PLA
 TYA                    ; A = major found
 RTS
