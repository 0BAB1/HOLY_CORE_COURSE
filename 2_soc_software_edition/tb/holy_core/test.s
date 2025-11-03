    .section .text
    .globl _start
_start:
    # Configuration: change this immediate to change the limit (MAX).
    li   t0, 100          # MAX = 100 (find primes 2..MAX)
    li   s0, 0            # primes_count = 0 (s0 used as count)

    # Reserve stack space to store primes (MAX * 4 bytes). 512 is safe for MAX=100.
    addi sp, sp, -512

    li   t1, 2            # n = 2  (current number to test)

loop_n:
    bgt  t1, t0, done_n   # if n > MAX -> done

    # --- test whether n is prime ---
    li   t2, 2            # d = 2 (divisor candidate)
    # We'll loop while d < n
test_divisor:
    blt  t2, t1, do_rem   # if d < n -> check remainder, else no divisor found -> prime
    # d >= n : no divisor found
    j    record_prime

do_rem:
    mv   t4, t1           # t4 = rem = n
rem_loop:
    blt  t4, t2, rem_nonzero # if rem < d, remainder != 0 -> not divisible by d
    sub  t4, t4, t2       # rem -= d
    beqz t4, composite    # if rem == 0 -> divisible -> composite
    j    rem_loop

rem_nonzero:
    addi t2, t2, 1        # d++
    j    test_divisor

composite:
    # Not prime: skip storing
    addi t1, t1, 1        # n++
    j    loop_n

record_prime:
    # Store n at stack[ primes_count ] (each prime is a 32-bit word)
    slli t5, s0, 2        # t5 = primes_count * 4
    add  t6, sp, t5       # t6 = address to store
    sw   t1, 0(t6)        # store n
    addi s0, s0, 1        # primes_count++
    addi t1, t1, 1        # n++
    j    loop_n

done_n:
    # primes_count is in s0. Return it as process exit status.
    mv   a0, s0
    li   a7, 93           # syscall: exit (RISC-V Linux)
    ecall

    # (Program never reaches below, but keep stack balanced if linker/runtime inspects)
    addi sp, sp, 512
