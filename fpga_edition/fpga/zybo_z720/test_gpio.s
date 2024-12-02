    .section .text
    .globl _start
_start:
    lui x6, 0x2                 # 00002337
    addi x18, x0, 0x1           # 00100913
    sw x18, 0(x6)               # 01232023
    lw x18, 0(x0)               # 00002903