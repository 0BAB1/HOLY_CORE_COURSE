# test_startup.S
#
# BRH 11/2025
#
# This code will only be executed at the beggining of each RISCOF
# test =, only on the HOLY CORE.
# (SHOULD CNTAIN A JUMP TO 0x80000000 in the end to start the test !)

_test_startup:
    # instructions cache setup
    li t0, 0x0
    li t1, 0x0
    csrrw x0, 0x7c3, t0
    csrrw x0, 0x7c4, t1

    # data cache setup
    li t0, 0x0
    li t1, 0x0
    csrrw x0, 0x7c1, t0
    csrrw x0, 0x7c2, t1

    # jump to the test
    li t0, 0x80000000
    jalr x0, 0(x5) # 0x00028067

_test_end:
    # flush the data cache
    li t0, 0x1
    csrrw x0, 0x7c0, t0
    j .