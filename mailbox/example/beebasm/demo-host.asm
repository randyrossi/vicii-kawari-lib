; Mailbox demo and self-test, host side: a C64 program (RUN it). It uploads
; demo-cpu.bin to the co-processor and exercises every part of the library.
; On success it prints MAILBOX OK and writes 0 to VICE's debug cartridge
; ($D7FF); on failure it prints FAIL and writes 16 + the test number.
CPU 0
INCLUDE "example/beebasm/demo-defs.asm"
CHROUT = $FFD2
DEBUGCART = $D7FF

ORG $07FF
 EQUW $0801
 EQUW $080B, 1              ; 1 SYS2061
 EQUB $9E
 EQUS "2061"
 EQUB 0
 EQUW 0
.start
 JSR MBX_ACTIVATE
 JSR MBX_RESET
 LDA #LO(MBX_CPU_ENTRY)     ; upload the co-processor program
 LDY #HI(MBX_CPU_ENTRY)
 JSR MBX_SEEK
 LDA #LO(cpu_image)
 LDY #HI(cpu_image)
 LDX #(cpu_end-cpu_image+255) DIV 256
 JSR MBX_UPLOAD
 JSR MBX_START              ; returns once the co-processor is ready

 ; Test 1: one command, and its result.
 LDA #1
 STA test
 JSR MBX_OPEN
 LDA #CMD_ADD
 STA MBX_VAL
 LDA #100
 STA MBX_VAL
 LDA #200
 STA MBX_VAL
 JSR MBX_CLOSE
 JSR MBX_FLUSH              ; run it and wait
 LDA #LO(RES_ADD)
 LDY #HI(RES_ADD)
 JSR MBX_SEEK
 LDA #LO(300)
 JSR expect
 LDA #HI(300)
 JSR expect
 JSR MBX_ERROR
 BEQ no_error
 JMP fail
.no_error

 ; Test 2: 600 one-byte commands, started as they are queued, so the
 ; host fills one buffer while the co-processor runs the other.
 INC test
.count_loop
 JSR MBX_OPEN
 LDA #CMD_COUNT
 STA MBX_VAL
 JSR MBX_CLOSE
 JSR MBX_KICK
 INC count
 BNE count_next
 INC count+1
.count_next
 LDA count
 CMP #LO(600)
 BNE count_loop
 LDA count+1
 CMP #HI(600)
 BNE count_loop
 JSR MBX_FLUSH
 LDA #LO(RES_COUNT)
 LDY #HI(RES_COUNT)
 JSR MBX_SEEK
 LDA #LO(600)
 JSR expect
 LDA #HI(600)
 JSR expect

 ; Test 3: long variable-length commands that run past a buffer's first
 ; page. Three times the sum of 0..199 is 59700.
 INC test
 LDY #3
.sum_loop
 JSR MBX_OPEN
 LDA #CMD_SUM
 STA MBX_VAL
 LDA #200
 STA MBX_VAL
 LDX #0
.sum_byte
 STX MBX_VAL
 INX
 CPX #200
 BNE sum_byte
 JSR MBX_CLOSE
 DEY
 BNE sum_loop
 JSR MBX_FLUSH
 LDA #LO(RES_SUM)
 LDY #HI(RES_SUM)
 JSR MBX_SEEK
 LDA #LO(59700)
 JSR expect
 LDA #HI(59700)
 JSR expect

 ; Test 4: an urgent request overtakes a long command that is running.
 INC test
 JSR MBX_OPEN
 LDA #CMD_SLOW
 STA MBX_VAL
 LDA #8
 STA MBX_VAL
 JSR MBX_CLOSE
 JSR MBX_KICK               ; start it, don't wait
 JSR MBX_URGENT_OPEN
 LDA #$5A
 STA MBX_VAL
 LDA #$FF
 STA MBX_VAL
 JSR MBX_URGENT_GO          ; returns when the urgent result is ready
 LDA #LO(RES_SLOW)
 LDY #HI(RES_SLOW)
 JSR MBX_SEEK
 LDA #0                     ; the long command is still running
 JSR expect
 LDA #$A5                   ; RES_URGENT follows RES_SLOW
 JSR expect
 JSR MBX_FLUSH
 LDA #LO(RES_SLOW)
 LDY #HI(RES_SLOW)
 JSR MBX_SEEK
 LDA #1
 JSR expect

 ; Test 5: an unknown command sets the diagnostic and drops the rest of
 ; its list; the next list runs normally.
 INC test
 JSR MBX_OPEN
 LDA #99
 STA MBX_VAL
 JSR MBX_CLOSE
 JSR add_1_2                ; in the same list: dropped
 JSR MBX_FLUSH
 JSR MBX_ERROR
 CMP #$FF
 BEQ had_error
 JMP fail
.had_error
 LDA #LO(RES_ADD)
 LDY #HI(RES_ADD)
 JSR MBX_SEEK
 LDA #LO(300)               ; unchanged
 JSR expect
 JSR add_1_2
 JSR MBX_FLUSH
 LDA #LO(RES_ADD)
 LDY #HI(RES_ADD)
 JSR MBX_SEEK
 LDA #3
 JSR expect

 LDX #0
.pass_message
 LDA pass_text,X
 BEQ pass_done
 JSR CHROUT
 INX
 BNE pass_message
.pass_done
 LDA #0
 STA DEBUGCART
 RTS

.expect                     ; the next VRAM byte must be A
 CMP MBX_VAL
 BNE fail
 RTS
.fail
 LDX #0
.fail_message
 LDA fail_text,X
 BEQ fail_done
 JSR CHROUT
 INX
 BNE fail_message
.fail_done
 CLC
 LDA test
 ADC #16
 STA DEBUGCART
.fail_stop
 JMP fail_stop

.add_1_2
 JSR MBX_OPEN
 LDA #CMD_ADD
 STA MBX_VAL
 LDA #1
 STA MBX_VAL
 LDA #2
 STA MBX_VAL
 JMP MBX_CLOSE

.test
 EQUB 0
.count
 EQUW 0
.pass_text
 EQUS "MAILBOX OK", 13, 0
.fail_text
 EQUS "MAILBOX FAIL", 13, 0

INCLUDE "beebasm/mbx-host.asm"

.cpu_image
 INCBIN "build/beebasm/demo-cpu.bin"
.cpu_end
 SAVE "build/beebasm/demo.prg", $07FF, cpu_end
