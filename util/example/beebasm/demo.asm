; Utility library demo and self-test: a C64 program (RUN it). It prints the
; Kawari firmware version, or says that there is no Kawari.
;
; For automated tests it also writes a result to VICE's debug cartridge
; ($D7FF): 0 = a Kawari with firmware 1.20 or later, 2 = an older Kawari,
; 3 = no Kawari, and 16 + n if check n of the library gave a wrong answer.
CPU 0
CHROUT = $FFD2
DEBUGCART = $D7FF
major = $FB                 ; C64 zero page
minor = $FC

ORG $07FF
 EQUW $0801
 EQUW $080B, 1              ; 1 SYS2061
 EQUB $9E
 EQUS "2061"
 EQUB 0
 EQUW 0
.start
 JSR KAWARI_INIT
 JSR KAWARI_VERSION
 STA major
 STX minor
 CMP #$FF
 BNE present

 ; No Kawari: every check must fail, even the lowest possible one.
 LDA #0
 TAX
 JSR KAWARI_CHECK_VERSION
 LDY #16
 BCS wrong
 LDX #absent_text-text
 JSR print
 LDA #3
 BNE exit

.present
 LDX #version_text-text
 JSR print
 LDA major
 JSR print_number
 LDA #'.'
 JSR CHROUT
 LDA minor
 JSR print_number
 LDA #13
 JSR CHROUT

 ; Check 1: the version found is acceptable, and is returned in A and X.
 LDA major
 LDX minor
 JSR KAWARI_CHECK_VERSION
 LDY #17
 BCC wrong
 CMP major
 BNE wrong
 CPX minor
 BNE wrong
 ; Check 2: a lower major version with a higher minor is acceptable.
 LDA #0
 LDX #$FE
 JSR KAWARI_CHECK_VERSION
 LDY #18
 BCC wrong
 ; Check 3: a higher major version with a lower minor is not.
 LDA #$FE
 LDX #0
 JSR KAWARI_CHECK_VERSION
 LDY #19
 BCS wrong
 ; Check 4: the same major version with a higher minor is not.
 LDA major
 LDX #$FE
 JSR KAWARI_CHECK_VERSION
 LDY #20
 BCS wrong

 ; What a program would actually do:
 LDA #KAWARI_COPROC_MAJOR
 LDX #KAWARI_COPROC_MINOR
 JSR KAWARI_CHECK_VERSION
 BCC too_old
 LDX #ok_text-text
 JSR print
 LDA #0
 BEQ exit
.too_old
 LDX #old_text-text
 JSR print
 LDA #2
.exit
 STA DEBUGCART
 RTS
.wrong
 STY DEBUGCART
 RTS

.print                      ; print the zero-terminated text at text + X
 LDA text,X
 BEQ print_done
 JSR CHROUT
 INX
 BNE print
.print_done
 RTS

.print_number               ; print A in decimal, 0..255
 LDX #'0'-1
 SEC
.print_hundreds
 INX
 SBC #100
 BCS print_hundreds
 ADC #100
 CPX #'0'
 BEQ print_tens_start       ; no hundreds: no leading zero
 PHA
 TXA
 JSR CHROUT
 PLA
.print_tens_start
 LDX #'0'-1
 SEC
.print_tens
 INX
 SBC #10
 BCS print_tens
 ADC #10
 PHA
 TXA
 JSR CHROUT                 ; always two digits: 1.5 would mean 1.50
 PLA
 ORA #'0'
 JMP CHROUT

.text
.version_text
 EQUS "KAWARI FIRMWARE ", 0
.absent_text
 EQUS "NO KAWARI FOUND", 13, 0
.ok_text
 EQUS "CO-PROCESSOR SUPPORTED", 13, 0
.old_text
 EQUS "1.20 OR LATER IS REQUIRED", 13, 0

INCLUDE "beebasm/kawari-util.asm"
.end
 SAVE "build/beebasm/demo.prg", $07FF, end
