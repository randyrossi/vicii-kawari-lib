; Mailbox demo, co-processor side: linked at its VRAM address with
; ld65 -t none -S 0x0200 (see ../../Makefile).
.include "demo-defs.inc"
MBX_CMD_COUNT = 4
MBX_URGENT = 1
slow_n = $10                ; co-processor zero page

entry:
 SEI
 CLD
 LDX #$FF
 TXS
 LDA #0
 LDX #7
clear_results:
 STA RESULTS,X
 DEX
 BPL clear_results
 JMP mbx_main

.include "mbx-cpu.inc"

mbx_cmd_table:
 .word cmd_add, cmd_count, cmd_sum, cmd_slow

cmd_add:
 INY
 LDA (MBX_CMD),Y
 INY
 CLC
 ADC (MBX_CMD),Y
 STA RES_ADD
 LDA #0
 ROL A
 STA RES_ADD+1
 LDA #3
 RTS

cmd_count:
 INC RES_COUNT
 BNE cmd_count_done
 INC RES_COUNT+1
cmd_count_done:
 LDA #1
 RTS

cmd_sum:                   ; a variable-length command
 INY
 LDA (MBX_CMD),Y
 TAX
cmd_sum_byte:
 INY
 CLC
 LDA (MBX_CMD),Y
 ADC RES_SUM
 STA RES_SUM
 BCC cmd_sum_next
 INC RES_SUM+1
cmd_sum_next:
 DEX
 BNE cmd_sum_byte
 INY                        ; Y = n + 1: the length is one more
 TYA
 RTS

cmd_slow:                  ; a long job that lets urgent requests in
 INY
 LDA (MBX_CMD),Y
 STA slow_n
 LDX #0
 LDY #0
cmd_slow_loop:
 DEY
 BNE cmd_slow_loop
 MBX_POLL_URGENT            ; corrupts A only
 DEX
 BNE cmd_slow_loop
 DEC slow_n
 BNE cmd_slow_loop
 LDA #1
 STA RES_SLOW
 LDA #2
 RTS

mbx_urgent_handler:
 LDA MBX_URGENT_ARGS
 EOR MBX_URGENT_ARGS+1
 STA RES_URGENT
 RTS

