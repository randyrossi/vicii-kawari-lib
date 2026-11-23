; Shared by demo-cpu.s and demo-host.s: the mailbox layout (here simply
; the library defaults, spelled out) and the demo's own commands and results.
; A project keeps one file like this and includes it before the library on
; both sides, so that the two can never disagree.

MBX_MAILBOX = $7FF0         ; mailbox, diagnostic, urgent flag
MBX_BUF_A = $1C00           ; command buffers: 256 + 202 + 1 bytes are used
MBX_BUF_B = $1E00
MBX_URGENT_ARGS = $7FC0     ; two argument bytes
MBX_CPU_ENTRY = $0200

CMD_ADD = 1                 ; a, b: RES_ADD = a + b (16 bits)
CMD_COUNT = 2               ; RES_COUNT = RES_COUNT + 1 (16 bits)
CMD_SUM = 3                 ; n, n bytes (1..253): RES_SUM += the bytes
CMD_SLOW = 4                ; n: a long delay, then RES_SLOW = 1

RESULTS = $7C00             ; VRAM
RES_ADD = RESULTS
RES_COUNT = RESULTS+2
RES_SUM = RESULTS+4
RES_SLOW = RESULTS+6
RES_URGENT = RESULTS+7      ; urgent lane: argument 0 EOR argument 1
