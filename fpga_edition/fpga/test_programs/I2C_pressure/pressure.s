# HOLY CORE PROGRAM
#
# Read the I2C BMP280 sensor and print value to UART as hexadecimal
#
# BRH - 30/05/25

.section .text
.align 1
.global _start

# NOTES :
# 100h => Control
# 104h => Sattus
# 108h => TX_FIFO
# 10Ch => RX_FIFO

# I²C READ (from BMP280 datasheet)
#
# To be able to read registers, first the register address must be sent in write mode (slave address
# 111011X - 0). Then either a stop or a repeated start condition must be generated. After this the
# slave is addressed in read mode (RW = ‘1’) at address 111011X - 1, after which the slave sends
# out data from auto-incremented register addresses until a NOACKM and stop condition occurs.
# This is depicted in Figure 8, where two bytes are read from register 0xF6 and 0xF7.
#
# Protocol :
#
# 1. we START
# 2. we transmit slave addr 0x77 and ask write mode
# 3. After ACK_S we transmit register to read address
# 4. After ACK_S, we RESTART ot STOP + START and initiate a read request on 0x77, ACK_S
# 5. Regs are transmitted 1 by 1 until NO ACK_M + STOP

_start:
    # Setup uncached MMIO region from 0x2000 to 0x3800
    lui x6, 0x2                 # x6 = 0x2000
    lui x7, 0x3
    ori x7, x7, -1              # x7 = 0x3800
    csrrw x0, 0x7C1, x6         # MMIO base
    csrrw x0, 0x7C2, x7         # MMIO limit

###########################
# config I2C AXI IP Core
###########################

    # Load the AXI_L - I2C IP's base address
    lui x10, 0x3                # x10 = 0x3000

    # Soft reset AXI- I2C IP core
    li x14, 0xA
    sw x14, 0x040(x10)          # soft reset

    # Reset TX_FIFO
    # Enable the AXI IIC, remove the TX_FIFO reset, disable the general call
    li x14, 0x3     # EN = 1, Reset = 1
    sw x14, 0x100(x10)

    li x14, 0x1     # EN = 1, Reset = 0
    sw x14, 0x100(x10)

###########################
# configure the sensor : 
###########################

check_loop_configure_one:
    # Check all FIFOs empty and bus not bus
    lw x14, 0x104(x10)
    andi x14, x14, 0x34         # check flags : RX_FIFO_FULL, TX_FIFO_FULL, BB (Bus Busy)
    bnez x14, check_loop_configure_one

    # 1st, we configure with 0xF5
    # Write to the TX_FIFO to specify the reg we'll read
    li x14, 0x1EE               # start : specify IIC slave base addr and write
    li x15, 0xF5                # specify reg address as data
    li x16, 0x200               # data = 00 + stop
    sw x14, 0x108(x10)          
    sw x15, 0x108(x10)
    sw x16, 0x108(x10)

check_loop_configure_two:
    # Check all FIFOs empty and bus not bus
    lw x14, 0x104(x10)
    andi x14, x14, 0x34         # check flags : RX_FIFO_FULL, TX_FIFO_FULL, BB (Bus Busy)
    bnez x14, check_loop_configure_two

    # 2nd, we configure measure with 0xF4
    # here we only FORCE 1 measure
    # Write to the TX_FIFO to specify the reg we'll read
    li x14, 0x1EE               # start : specify IIC slave base addr and write
    li x15, 0xF4                # specify reg address as data
    li x16, 0x209               # data = 09 (os = x2 and force mode) + stop
    sw x14, 0x108(x10)          
    sw x15, 0x108(x10)
    sw x16, 0x108(x10)

###########################
# WAit for measurement
###########################
# We then poll 0xF3 bit' #3 (0x8 as value) until its done (0)

wait_for_measurement:
measure_loop_one:
    # Check all FIFOs empty and bus not bus
    lw x14, 0x104(x10)
    andi x14, x14, 0x34         # check flags : RX_FIFO_FULL, TX_FIFO_FULL, BB (Bus Busy)
    bnez x14, measure_loop_one

    # Write to the TX_FIFO to specify the reg we'll read : (0xF3 = status)
    li x14, 0x1EE               # start : specify IIC slave base addr and write
    li x15, 0x2F3               # specify reg address as data : stop
    sw x14, 0x108(x10)
    sw x15, 0x108(x10)

# WAIT TEST
    li t0, 2500         # each loop = 4 cycles → 2500 × 4 = ~10,000
delay_loop:
    addi t0, t0, -1
    bnez t0, delay_loop

measure_loop_two:
    # Same here
    lw x14, 0x104(x10)
    andi x14, x14, 0x34         # bit 2 = BB (Bus Busy)
    bnez x14, measure_loop_two

    # Write to the TX fifo to request read ans specify want want 1 byte
    li x14, 0x1EF               # start : request read on IIC slave
    li x15, 0x201               # master reciever mode : set stop after 1 byte
    sw x14, 0x108(x10)
    sw x15, 0x108(x10)

measure_read_loop:
    # Wait for RX_FIFO not empty
    lw x14, 0x104(x10)
    andi x14, x14, 0x40         # check flags : RX_FIFO_EMPTY
    bnez x14, measure_read_loop

    # Read the RX byte
    lb x16, 0x10C(x10)
    # Check bit 3, if it's high, then the sensor is still emasuring.
    andi x16, x16, 0x8
    bnez x16, wait_for_measurement


###############################
# read measurement
###############################

# WAIT TEST
    li t0, 2500         # each loop = 4 cycles → 2500 × 4 = ~10,000
delay_loop_a:
    addi t0, t0, -1
    bnez t0, delay_loop_a

check_loop_one:
    # Check all FIFOs empty and bus not bus
    lw x14, 0x104(x10)
    andi x14, x14, 0x34         # check flags : RX_FIFO_FULL, TX_FIFO_FULL, BB (Bus Busy)
    bnez x14, check_loop_one

    # Write to the TX_FIFO to specify the reg we'll read : (0xF7 = press_msb)
    li x14, 0x1EE               # start : specify IIC slave base addr and write
    li x15, 0x2F8               # specify reg address as data : stop
    sw x14, 0x108(x10)
    sw x15, 0x108(x10)

# WAIT TEST
    li t0, 2500         # each loop = 4 cycles → 2500 × 4 = ~10,000
delay_loop_b:
    addi t0, t0, -1
    bnez t0, delay_loop_b

check_loop_two:
    # Same here
    lw x14, 0x104(x10)
    andi x14, x14, 0x34         # bit 2 = BB (Bus Busy)
    bnez x14, check_loop_two

    # Write to the TX fifo to request read ans specify want want 1 byte
    li x14, 0x1EF               # start : request read on IIC slave
    li x15, 0x201               # master reciever mode : set stop after 1 byte
    sw x14, 0x108(x10)
    sw x15, 0x108(x10)

# WAIT TEST
    li t0, 2500         # each loop = 4 cycles → 2500 × 4 = ~10,000
delay_loop_c:
    addi t0, t0, -1
    bnez t0, delay_loop_c

read_loop:
    # Wait for RX_FIFO not empty
    lw x14, 0x104(x10)
    andi x14, x14, 0x40         # check flags : RX_FIFO_EMPTY
    bnez x14, read_loop

    # Read the RX byte
    lb x16, 0x10C(x10)

    # ==============================
    # Write it to UART
    # ==============================

    li x17, 0x2800              # x17 = UART base

    # ---------- High nibble ----------
    srli x14, x16, 4     # x14 = high nibble (bits 7:4)
    andi x14, x14, 0xF   # mask to 4 bits
    li x15, '0'          # ASCII base
    add x14, x14, x15    # x14 = ASCII character
    li t1, 58
    blt x14, t1, send_hi # 58 = '9' + 1
    addi x14, x14, 7     # jump to 'A' for 10–15
send_hi:
wait_hi:
    lw t0, 8(x17)
    andi t0, t0, 0x8
    bnez t0, wait_hi
    sb x14, 4(x17)

    # ---------- Low nibble ----------
    andi x14, x16, 0xF   # x14 = low nibble (bits 3:0)
    li x15, '0'
    add x14, x14, x15
    li t1, 58
    blt x14, t1, send_lo # 58 = '9' + 1
    addi x14, x14, 7
send_lo:
wait_lo:
    lw t0, 8(x17)
    andi t0, t0, 0x8
    bnez t0, wait_lo
    sb x14, 4(x17)

    # ---------- Newline ----------
    li x14, 0x0A
wait_nl:
    lw t0, 8(x17)
    andi t0, t0, 0x8
    bnez t0, wait_nl
    sb x14, 4(x17)

    # ---------- return ----------
    li x14, '\r'
wait_ret:
    lw t0, 8(x17)
    andi t0, t0, 0x8
    bnez t0, wait_ret
    sb x14, 4(x17)

    j .