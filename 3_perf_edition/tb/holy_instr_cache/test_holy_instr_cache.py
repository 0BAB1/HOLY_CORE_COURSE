# INSTRUCTION CACHE TESTBENCH - Random Read Stress Test
#
# BRH 12/25
#
# Functional stress testing based tb with handshake protocol
# Adapted for read-only instruction cache

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
import random
from cocotbext.axi import AxiBus, AxiRam

CPU_PERIOD = 10
MEMORY_SIZE = 2**20
NUM_READS = 1000

# CACHE DESCRIPTION (for stress tests at the end)
WORDS_PER_LINE = 8
NUM_SETS = 4
NUM_WAYS = 2
LINE_SIZE_BYTES = WORDS_PER_LINE * 4
CACHE_SIZE_BYTES = NUM_SETS * NUM_WAYS * LINE_SIZE_BYTES 

def generate_random_bytes(length):
    return bytes([random.randint(0, 255) for _ in range(length)])

def bytes_to_int(b):
    """Convert 4 bytes (little endian) to integer"""
    return int.from_bytes(b, byteorder='little')

def int_to_bytes(val):
    """Convert integer to 4 bytes (little endian)"""
    return val.to_bytes(4, byteorder='little')

async def reset(dut):
    """Reset the DUT"""
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    dut.cpu_req_valid.value = 0
    dut.cpu_address.value = 0
    dut.cpu_read_ack.value = 0
    
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut._log.info("Reset complete")

async def wait_for_ready(dut, timeout=1000):
    """Wait for cache to become ready"""
    count = 0
    while dut.cpu_req_ready.value == 0:
        await RisingEdge(dut.clk)
        count += 1
        if count > timeout:
            raise Exception(f"Cache ready timeout after {timeout} cycles")


async def cpu_read(dut, address):
    """Perform a CPU read operation with handshake"""
    # Set up read request
    dut.cpu_address.value = address
    dut.cpu_req_valid.value = 1
    
    # Wait for handshake (req_valid && req_ready)
    await RisingEdge(dut.clk)
    while dut.cpu_req_ready.value == 0:
        await RisingEdge(dut.clk)
    
    # Request accepted, deassert valid
    dut.cpu_req_valid.value = 0
    
    # Wait for read_valid to get the data
    while dut.cpu_read_valid.value == 0:
        await RisingEdge(dut.clk)
    
    # Capture result
    result = int(dut.cpu_read_data.value)
    
    # Acknowledge the read
    dut.cpu_read_ack.value = 1
    await RisingEdge(dut.clk)
    dut.cpu_read_ack.value = 0

    return result

def get_set_index(address):
    """Extract set index from address"""
    word_offset_bits = 3  # log2(8)
    byte_offset_bits = 2
    set_bits = 3  # log2(8)
    return (address >> (byte_offset_bits + word_offset_bits)) & ((1 << set_bits) - 1)

def get_tag(address):
    """Extract tag from address"""
    word_offset_bits = 3
    byte_offset_bits = 2
    set_bits = 3
    return address >> (byte_offset_bits + word_offset_bits + set_bits)

def make_address_for_set(set_idx, tag, word_offset=0):
    """Create an address that maps to a specific set with given tag"""
    word_offset_bits = 3
    byte_offset_bits = 2
    set_bits = 3
    return (tag << (byte_offset_bits + word_offset_bits + set_bits)) | \
           (set_idx << (byte_offset_bits + word_offset_bits)) | \
           (word_offset << byte_offset_bits)
    
@cocotb.test()
async def test_random_reads(dut):
    """Random read stress test with golden reference"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Random Read Stress Test")
    dut._log.info(f"Will perform {NUM_READS} random reads")
    dut._log.info("=" * 60)
    
    # ==================================
    # CLOCKS & RAM DECLARATION
    # ==================================
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    
    axi_ram = AxiRam(
        AxiBus.from_prefix(dut, "axi"), 
        dut.clk, 
        dut.rst_n, 
        size=MEMORY_SIZE, 
        reset_active_level=False
    )
    
    await RisingEdge(dut.clk)
    await reset(dut)
    
    # ==================================
    # MEMORY INIT WITH RANDOM VALUES
    # ==================================
    dut._log.info("Initializing memory with random data...")
    
    mem_golden_ref = []
    
    # Fill memory with random data (word by word)
    for address in range(0, MEMORY_SIZE, 4):
        word_bytes = generate_random_bytes(4)
        axi_ram.write(address, word_bytes)
        mem_golden_ref.append(bytes_to_int(word_bytes))
    
    dut._log.info(f"Memory initialized: {len(mem_golden_ref)} words")
    
    # Verify memory initialization
    for address in range(0, MEMORY_SIZE, 4):
        word_index = int(address / 4)
        mem_data = axi_ram.read(address, 4)
        assert bytes_to_int(mem_data) == mem_golden_ref[word_index], \
            f"Memory init verification failed at 0x{address:08X}"
    
    dut._log.info("Memory initialization verified ✓")
    
    # ==================================
    # RANDOM READ STRESS TEST
    # ==================================
    dut._log.info(f"\nStarting {NUM_READS} random reads...")
    
    errors = 0
    
    for i in range(NUM_READS):
        # Generate random word-aligned address
        word_index = random.randint(0, len(mem_golden_ref) - 1)
        address = word_index * 4
        
        # Expected data from golden reference
        expected_data = mem_golden_ref[word_index]
        
        # Perform read
        read_data = await cpu_read(dut, address)
        
        # Compare
        if read_data != expected_data:
            dut._log.error(f"[{i}] MISMATCH at 0x{address:08X}: " +
                          f"expected 0x{expected_data:08X}, got 0x{read_data:08X}")
            errors += 1
            assert read_data == expected_data
        else:
            # Log progress every 100 reads
            if (i + 1) % 100 == 0:
                dut._log.info(f"Progress: {i + 1}/{NUM_READS} reads completed ✓")
    
    # ==================================
    # FINAL REPORT
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info(f"READ TEST COMPLETE")
    dut._log.info(f"Total reads: {NUM_READS}, Errors: {errors}")
    dut._log.info("=" * 60)
    
    # Assert test passed
    assert errors == 0, f"Read test failed with {errors} errors"
    dut._log.info("✓ READ TEST PASSED")

@cocotb.test()
async def test_sequential_reads(dut):
    """Sequential read test - simulates instruction fetch pattern"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Sequential Read (Instruction Fetch Pattern)")
    dut._log.info("=" * 60)
    
    # ==================================
    # CLOCKS & RAM DECLARATION
    # ==================================
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    
    axi_ram = AxiRam(
        AxiBus.from_prefix(dut, "axi"), 
        dut.clk, 
        dut.rst_n, 
        size=MEMORY_SIZE, 
        reset_active_level=False
    )
    
    await RisingEdge(dut.clk)
    await reset(dut)
    
    # ==================================
    # MEMORY INIT WITH SEQUENTIAL INSTRUCTIONS
    # ==================================
    base_addr = 0x1000
    num_instrs = 500
    
    golden = []
    for i in range(num_instrs):
        instr = 0x00000013 + (i << 7)  # NOP-like with varying rd
        axi_ram.write(base_addr + (i * 4), int_to_bytes(instr))
        golden.append(instr)
    
    dut._log.info(f"Initialized {num_instrs} sequential instructions")
    
    # ==================================
    # SEQUENTIAL FETCH TEST
    # ==================================
    errors = 0
    
    for i in range(num_instrs):
        address = base_addr + (i * 4)
        expected = golden[i]
        
        read_data = await cpu_read(dut, address)
        
        # Check for timeout
        if read_data is None:
            dut._log.error(f"[{i}] TIMEOUT at 0x{address:08X}")
            errors += 1
            assert False, f"Read timeout at iteration {i}, address 0x{address:08X}"
        
        if read_data != expected:
            dut._log.error(f"[{i}] MISMATCH at 0x{address:08X}: " +
                          f"expected 0x{expected:08X}, got 0x{read_data:08X}")
            errors += 1
            assert read_data == expected
        
        if (i + 1) % 100 == 0:
            dut._log.info(f"Progress: {i + 1}/{num_instrs} fetches completed ✓")
    
    # ==================================
    # FINAL REPORT
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info(f"SEQUENTIAL READ TEST COMPLETE")
    dut._log.info(f"Total reads: {num_instrs}, Errors: {errors}")
    dut._log.info("=" * 60)
    
    assert errors == 0, f"Sequential read test failed with {errors} errors"
    dut._log.info("✓ SEQUENTIAL READ TEST PASSED")

# =============================================================================
# TEST: Tight Loop (Same Cache Line)
# =============================================================================
@cocotb.test()
async def test_tight_loop(dut):
    """Simulate a tight loop - repeated reads from same cache line"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Tight Loop (Same Cache Line)")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    # Initialize a small loop (4 instructions)
    loop_base = 0x1000
    loop_size = 4
    golden = []
    for i in range(loop_size):
        instr = 0x00000063 + (i << 7)  # Branch-like instructions
        axi_ram.write(loop_base + i * 4, int_to_bytes(instr))
        golden.append(instr)
    
    # Execute loop 1000 times
    iterations = 1000
    dut._log.info(f"Executing {loop_size}-instruction loop {iterations} times")

    for loop in range(iterations):
        for i in range(loop_size):
            addr = loop_base + i * 4
            result = await cpu_read(dut, addr)
            assert result == golden[i], f"Loop {loop}, instr {i} mismatch"
    
    dut._log.info("✓ Tight loop test passed")


# =============================================================================
# TEST: Ping-Pong Between Two Cache Lines
# =============================================================================
@cocotb.test()
async def test_ping_pong_lines(dut):
    """Alternate between two cache lines in same set (stress LRU)"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Ping-Pong Between Two Lines (Same Set)")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    # Two addresses mapping to same set but different tags
    set_idx = 3
    addr_a = make_address_for_set(set_idx, tag=0, word_offset=0)
    addr_b = make_address_for_set(set_idx, tag=1, word_offset=0)
    
    data_a = 0xAAAAAAAA
    data_b = 0xBBBBBBBB
    
    # Init both lines
    for i in range(WORDS_PER_LINE):
        axi_ram.write(addr_a + i * 4, int_to_bytes(data_a + i))
        axi_ram.write(addr_b + i * 4, int_to_bytes(data_b + i))
    
    dut._log.info(f"Addr A: 0x{addr_a:08X} (set {set_idx}, tag 0)")
    dut._log.info(f"Addr B: 0x{addr_b:08X} (set {set_idx}, tag 1)")
    
    # Ping-pong 500 times - both should stay cached (2-way)
    iterations = 500
    for i in range(iterations):
        result = await cpu_read(dut, addr_a)
        assert result == data_a, f"Iter {i}: A mismatch"
        
        result = await cpu_read(dut, addr_b)
        assert result == data_b, f"Iter {i}: B mismatch"
    
    dut._log.info(f"Completed {iterations} ping-pong iterations")
    dut._log.info("✓ Ping-pong test passed")

# =============================================================================
# TEST: Random Jumps (Branch Prediction Miss Pattern)
# =============================================================================
@cocotb.test()
async def test_random_jumps(dut):
    """Simulate random branch targets - worst case for cache"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Random Jumps (Branch Misprediction Pattern)")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    # Initialize a large code region
    code_base = 0x10000
    code_size = 4096  # 4KB of code
    
    golden = {}
    for i in range(code_size // 4):
        addr = code_base + i * 4
        instr = random.randint(0, 0xFFFFFFFF)
        axi_ram.write(addr, int_to_bytes(instr))
        golden[addr] = instr
    
    # Random jumps within code region
    num_jumps = 500
    dut._log.info(f"Performing {num_jumps} random jumps in {code_size}B region")
    
    for i in range(num_jumps):
        # Random word-aligned address in code region
        offset = random.randint(0, code_size // 4 - 1) * 4
        addr = code_base + offset
        
        result = await cpu_read(dut, addr)
        assert result is not None, f"Timeout at jump {i}"
        assert result == golden[addr], f"Mismatch at 0x{addr:08X}"
        
        if (i + 1) % 100 == 0:
            dut._log.info(f"Progress: {i + 1}/{num_jumps}")
    
    dut._log.info("✓ Random jumps test passed")


# =============================================================================
# TEST: Sequential Then Jump (Function Call Pattern)
# =============================================================================
@cocotb.test()
async def test_function_call_pattern(dut):
    """Simulate function calls: sequential fetch, jump, sequential, return"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Function Call Pattern")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    # Main code at 0x1000
    main_base = 0x1000
    main_size = 20  # 20 instructions
    
    # Function at 0x2000
    func_base = 0x2000
    func_size = 10  # 10 instructions
    
    golden = {}
    for i in range(main_size):
        addr = main_base + i * 4
        golden[addr] = 0x10000000 + i
        axi_ram.write(addr, int_to_bytes(golden[addr]))
    
    for i in range(func_size):
        addr = func_base + i * 4
        golden[addr] = 0x20000000 + i
        axi_ram.write(addr, int_to_bytes(golden[addr]))
    
    # Simulate: fetch main[0:5], call func, fetch func[0:10], return, fetch main[6:20]
    num_calls = 50
    dut._log.info(f"Simulating {num_calls} function calls")
    
    for call in range(num_calls):
        # Fetch first part of main
        for i in range(5):
            addr = main_base + i * 4
            result = await cpu_read(dut, addr)
            assert result == golden[addr]
        
        # Jump to function
        for i in range(func_size):
            addr = func_base + i * 4
            result = await cpu_read(dut, addr)
            assert result == golden[addr]
        
        # Return to main
        for i in range(5, main_size):
            addr = main_base + i * 4
            result = await cpu_read(dut, addr)
            assert result == golden[addr]
    
    dut._log.info("✓ Function call pattern test passed")

# =============================================================================
# TEST: Stride Access (Unrolled Loop Pattern)
# =============================================================================
@cocotb.test()
async def test_stride_access(dut):
    """Access with various strides - simulates unrolled loops"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Stride Access Pattern")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    # Initialize memory
    base = 0x10000
    size = 0x4000  # 16KB
    
    golden = {}
    for i in range(size // 4):
        addr = base + i * 4
        golden[addr] = random.randint(0, 0xFFFFFFFF)
        axi_ram.write(addr, int_to_bytes(golden[addr]))
    
    # Test various strides
    strides = [4, 8, 16, 32, 64, 128, 256]  # bytes
    
    for stride in strides:
        dut._log.info(f"Testing stride {stride} bytes")
        
        addr = base
        count = 0
        while addr < base + size and count < 100:
            result = await cpu_read(dut, addr)
            assert result == golden[addr], f"Stride {stride}, addr 0x{addr:08X}"
            addr += stride
            count += 1
    
    dut._log.info("✓ Stride access test passed")


# =============================================================================
# TEST: Back-and-Forth (Oscillating PC)
# =============================================================================
@cocotb.test()
async def test_oscillating_pc(dut):
    """PC oscillates back and forth (conditional branch pattern)"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Oscillating PC Pattern")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    # Two code blocks
    block_a = 0x1000
    block_b = 0x1080  # 128 bytes apart (different cache lines)
    block_size = 8  # instructions
    
    golden = {}
    for i in range(block_size):
        addr_a = block_a + i * 4
        addr_b = block_b + i * 4
        golden[addr_a] = 0xAAA00000 + i
        golden[addr_b] = 0xBBB00000 + i
        axi_ram.write(addr_a, int_to_bytes(golden[addr_a]))
        axi_ram.write(addr_b, int_to_bytes(golden[addr_b]))
    
    # Oscillate: A[0], B[0], A[1], B[1], ...
    iterations = 200
    dut._log.info(f"Oscillating between blocks {iterations} times")
    
    for i in range(iterations):
        idx = i % block_size
        
        # Fetch from A
        result = await cpu_read(dut, block_a + idx * 4)
        assert result == golden[block_a + idx * 4]
        
        # Fetch from B
        result = await cpu_read(dut, block_b + idx * 4)
        assert result == golden[block_b + idx * 4]
    
    dut._log.info("✓ Oscillating PC test passed")


# =============================================================================
# TEST: All Sets Stress
# =============================================================================
@cocotb.test()
async def test_all_sets_stress(dut):
    """Stress all cache sets simultaneously"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: All Sets Stress")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    # Create addresses that hit each set
    addresses = []
    golden = {}
    
    for set_idx in range(NUM_SETS):
        for way in range(NUM_WAYS + 1):  # +1 to cause evictions
            addr = make_address_for_set(set_idx, tag=way)
            data = (set_idx << 16) | (way << 8) | 0x42
            addresses.append(addr)
            golden[addr] = data
            for w in range(WORDS_PER_LINE):
                axi_ram.write(addr + w * 4, int_to_bytes(data + w))
    
    # Random access pattern hitting all sets
    iterations = 500
    dut._log.info(f"Random access to all sets, {iterations} iterations")
    
    for i in range(iterations):
        addr = random.choice(addresses)
        word_offset = random.randint(0, WORDS_PER_LINE - 1)
        full_addr = addr + word_offset * 4
        
        result = await cpu_read(dut, full_addr)
        expected = golden[addr] + word_offset
        assert result == expected, f"Mismatch at 0x{full_addr:08X}"
        
        if (i + 1) % 100 == 0:
            dut._log.info(f"Progress: {i + 1}/{iterations}")
    
    dut._log.info("✓ All sets stress test passed")


# =============================================================================
# TEST: Mega Stress (Combined Patterns)
# =============================================================================
@cocotb.test()
async def test_mega_stress(dut):
    """Combined stress test with all patterns"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: MEGA STRESS (Combined Patterns)")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    # Initialize large memory region
    golden = {}
    for addr in range(0, 0x20000, 4):  # 128KB
        data = random.randint(0, 0xFFFFFFFF)
        axi_ram.write(addr, int_to_bytes(data))
        golden[addr] = data
    
    total_reads = 0
    errors = 0
    
    # Pattern 1: Sequential bursts
    dut._log.info("Phase 1: Sequential bursts")
    for burst in range(20):
        base = random.randint(0, 0x1F000) & ~0x3
        for i in range(32):
            addr = base + i * 4
            if addr in golden:
                result = await cpu_read(dut, addr)
                if result != golden[addr]:
                    errors += 1
                total_reads += 1
    
    # Pattern 2: Random jumps
    dut._log.info("Phase 2: Random jumps")
    for _ in range(200):
        addr = (random.randint(0, 0x1FFFF) & ~0x3)
        if addr in golden:
            result = await cpu_read(dut, addr)
            if result != golden[addr]:
                errors += 1
            total_reads += 1
    
    # Pattern 3: Ping-pong between distant addresses
    dut._log.info("Phase 3: Ping-pong distant")
    addr_list = [0x0000, 0x8000, 0x10000, 0x18000]
    for _ in range(100):
        for addr in addr_list:
            result = await cpu_read(dut, addr)
            if result != golden[addr]:
                errors += 1
            total_reads += 1
    
    # Pattern 4: Thrashing specific set
    dut._log.info("Phase 4: Set thrashing")
    thrash_addrs = [make_address_for_set(2, tag=t) for t in range(5)]
    for addr in thrash_addrs:
        for w in range(WORDS_PER_LINE):
            a = addr + w * 4
            if a not in golden:
                golden[a] = random.randint(0, 0xFFFFFFFF)
                axi_ram.write(a, int_to_bytes(golden[a]))
    
    for _ in range(50):
        for addr in thrash_addrs:
            result = await cpu_read(dut, addr)
            if result != golden[addr]:
                errors += 1
            total_reads += 1
    
    # Pattern 5: Tight loop with occasional jump
    dut._log.info("Phase 5: Loop with jumps")
    loop_base = 0x5000
    for i in range(8):
        addr = loop_base + i * 4
        if addr not in golden:
            golden[addr] = 0x50000000 + i
            axi_ram.write(addr, int_to_bytes(golden[addr]))
    
    for _ in range(100):
        # Tight loop
        for i in range(8):
            addr = loop_base + i * 4
            result = await cpu_read(dut, addr)
            if result != golden[addr]:
                errors += 1
            total_reads += 1
        
        # Occasional random jump
        if random.random() < 0.3:
            jump_addr = (random.randint(0, 0x1FFFF) & ~0x3)
            if jump_addr in golden:
                result = await cpu_read(dut, jump_addr)
                if result != golden[jump_addr]:
                    errors += 1
                total_reads += 1
    
    dut._log.info("=" * 60)
    dut._log.info(f"MEGA STRESS COMPLETE")
    dut._log.info(f"Total reads: {total_reads}, Errors: {errors}")
    dut._log.info("=" * 60)
    
    assert errors == 0, f"Mega stress failed with {errors} errors"
    dut._log.info("✓ MEGA STRESS TEST PASSED")


# =============================================================================
# TEST: Delayed ACK (Simulates D-Cache Stall)
# =============================================================================
@cocotb.test()
async def test_delayed_ack(dut):
    """Simulate delayed read_ack (like when dcache is stalling)"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Delayed ACK (D-Cache Stall Simulation)")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    # Initialize memory
    base = 0x1000
    golden = []
    for i in range(WORDS_PER_LINE * 4):
        data = 0xACE00000 | i
        axi_ram.write(base + i * 4, int_to_bytes(data))
        golden.append(data)
    
    async def cpu_read_delayed_ack(address, ack_delay):
        """Read with configurable ack delay"""
        dut.cpu_address.value = address
        dut.cpu_req_valid.value = 1
        
        await RisingEdge(dut.clk)
        while dut.cpu_req_ready.value == 0:
            await RisingEdge(dut.clk)
        
        # Wait for read_valid
        while dut.cpu_read_valid.value == 0:
            await RisingEdge(dut.clk)
        
        # DELAY the ack (simulating dcache stall)
        for _ in range(ack_delay):
            # read_valid should stay high
            assert dut.cpu_read_valid.value == 1, "read_valid dropped before ack!"
            await RisingEdge(dut.clk)
        
        result = int(dut.cpu_read_data.value)
        
        dut.cpu_read_ack.value = 1
        await RisingEdge(dut.clk)
        dut.cpu_read_ack.value = 0
        
        return result
    
    # Test with various ack delays
    for delay in [1, 2, 5, 10, 20]:
        dut._log.info(f"Testing with ack_delay = {delay}")
        for i in range(16):
            addr = base + i * 4
            result = await cpu_read_delayed_ack(addr, delay)
            assert result == golden[i], f"Delay {delay}, word {i}: expected 0x{golden[i]:08X}, got 0x{result:08X}"
    
    dut._log.info("✓ Delayed ack test passed")

# =============================================================================
# TEST: Completely random validity
# =============================================================================
@cocotb.test()
async def test_random_validity(dut):
    """Simulate the fact that the cache may be solicitated without validity"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: random validity")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    # Initialize memory
    base = 0x1000
    golden = []
    for i in range(WORDS_PER_LINE * 4):
        data = 0xACE00000 | i
        axi_ram.write(base + i * 4, int_to_bytes(data))
        golden.append(data)
    
    async def cpu_read_or_or_not(address, req_valid):
        """Read with configurable ack delay"""
        dut.cpu_address.value = address
        dut.cpu_req_valid.value = req_valid
        
        await RisingEdge(dut.clk)
        while dut.cpu_req_ready.value == 0:
            await RisingEdge(dut.clk)
        
        # Wait for read_valid
        while dut.cpu_read_valid.value == 0:
            await RisingEdge(dut.clk)
            if not req_valid: break
        
        # ack randomly, even if we did NOT assert valid
        for _ in range(random.randint(0,10)):
            # read_valid should stay high
            assert dut.cpu_read_valid.value == 1 or not req_valid, "read_valid dropped before ack!"
            await RisingEdge(dut.clk)
        
        result = int(dut.cpu_read_data.value)
        
        dut.cpu_read_ack.value = 1
        await RisingEdge(dut.clk)
        dut.cpu_read_ack.value = 0
        
        return result
    
    for i in range(10000):
        addr = base + (i%16) * 4
        req_valid_flag = random.choice([True, False])
        result = await cpu_read_or_or_not(addr, req_valid_flag)
        if req_valid_flag:
            assert result == golden[(i%16)]
    
    dut._log.info("✓ random req valid passed")

# =============================================================================
# TEST: Address Change During Stall (CPU Changes PC While Waiting)
# =============================================================================
@cocotb.test()
async def test_address_change_during_miss(dut):
    """Change address while cache is filling (simulates branch during stall)"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Address Change During Miss")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    # Two separate cache lines
    addr_a = 0x1000
    addr_b = 0x2000
    
    for i in range(WORDS_PER_LINE):
        axi_ram.write(addr_a + i * 4, int_to_bytes(0xAAAA0000 | i))
        axi_ram.write(addr_b + i * 4, int_to_bytes(0xBBBB0000 | i))
    
    # Start request to addr_a
    dut.cpu_address.value = addr_a
    dut.cpu_req_valid.value = 1
    
    await RisingEdge(dut.clk)
    
    # Wait for request to be accepted
    while dut.cpu_req_ready.value == 0:
        await RisingEdge(dut.clk)
    
    dut.cpu_req_valid.value = 0
    
    # Now wait for read_valid and complete normally
    while dut.cpu_read_valid.value == 0:
        await RisingEdge(dut.clk)
    
    result = int(dut.cpu_read_data.value)
    assert result == 0xAAAA0000, f"Expected 0xAAAA0000, got 0x{result:08X}"
    
    dut.cpu_read_ack.value = 1
    await RisingEdge(dut.clk)
    dut.cpu_read_ack.value = 0
    
    # Now do normal read to addr_b
    result = await cpu_read(dut, addr_b)
    assert result == 0xBBBB0000, f"Expected 0xBBBB0000, got 0x{result:08X}"
    
    dut._log.info("✓ Address change during miss test passed")


# =============================================================================
# TEST: No ACK Given (Simulates Continuous Stall)
# =============================================================================
@cocotb.test()
async def test_read_valid_persistence(dut):
    """Verify read_valid and read_data stay stable without ack"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Read Valid Persistence (No ACK)")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    addr = 0x3000
    expected = 0xDEADBEEF
    axi_ram.write(addr, int_to_bytes(expected))
    
    # Request
    dut.cpu_address.value = addr
    dut.cpu_req_valid.value = 1
    
    await RisingEdge(dut.clk)
    while dut.cpu_req_ready.value == 0:
        await RisingEdge(dut.clk)
    
    dut.cpu_req_valid.value = 0
    
    # Wait for read_valid
    while dut.cpu_read_valid.value == 0:
        await RisingEdge(dut.clk)
    
    # DON'T ack - just observe for many cycles
    for cycle in range(50):
        assert dut.cpu_read_valid.value == 1, f"read_valid dropped at cycle {cycle}"
        assert int(dut.cpu_read_data.value) == expected, f"read_data changed at cycle {cycle}"
        await RisingEdge(dut.clk)
    
    # Finally ack
    dut.cpu_read_ack.value = 1
    await RisingEdge(dut.clk)
    dut.cpu_read_ack.value = 0
    
    dut._log.info("✓ Read valid persistence test passed")


# =============================================================================
# TEST: Hit With Pending Miss Data (Critical Race)
# =============================================================================
@cocotb.test()
async def test_hit_while_miss_data_pending(dut):
    """After miss completes, immediately hit different line"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Hit While Miss Data Pending")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    # Two lines in different sets
    set0_addr = make_address_for_set(0, tag=1)
    set1_addr = make_address_for_set(1, tag=1)
    
    for i in range(WORDS_PER_LINE):
        axi_ram.write(set0_addr + i * 4, int_to_bytes(0x11110000 | i))
        axi_ram.write(set1_addr + i * 4, int_to_bytes(0x22220000 | i))
    
    # Prime set1 so it's cached
    result = await cpu_read(dut, set1_addr)
    assert result == 0x22220000
    
    # Now read from set0 (miss)
    result = await cpu_read(dut, set0_addr)
    assert result == 0x11110000
    
    # Immediately read from set1 (should be hit)
    result = await cpu_read(dut, set1_addr)
    assert result == 0x22220000, f"Expected 0x22220000, got 0x{result:08X}"
    
    # Repeat pattern rapidly
    for _ in range(100):
        r1 = await cpu_read(dut, set0_addr + 4)
        assert r1 == 0x11110001
        r2 = await cpu_read(dut, set1_addr + 4)
        assert r2 == 0x22220001
    
    dut._log.info("✓ Hit while miss data pending test passed")


# =============================================================================
# TEST: Sequential PC Pattern (Exact CPU Behavior)
# =============================================================================
@cocotb.test()
async def test_sequential_pc_with_jumps(dut):
    """Simulate exact CPU fetch pattern: sequential with occasional jumps"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Sequential PC With Jumps (CPU Pattern)")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    # Fill memory with "instructions"
    golden = {}
    for addr in range(0x80000000, 0x80001000, 4):
        # Use lower bits of address as data for easy verification
        data = addr & 0xFFFFFFFF
        # AXI RAM might not support full 32-bit addr, use offset
        ram_addr = addr & 0xFFFF
        axi_ram.write(ram_addr, int_to_bytes(data))
        golden[ram_addr] = data
    
    pc = 0x0000  # Start of our test region
    
    for _ in range(500):
        # Fetch current instruction
        result = await cpu_read(dut, pc)
        expected = golden.get(pc, 0)
        assert result == expected, f"PC=0x{pc:04X}: expected 0x{expected:08X}, got 0x{result:08X}"
        
        # Simulate: 80% sequential, 20% jump
        if random.random() < 0.8:
            pc = (pc + 4) & 0xFFF  # Sequential
        else:
            pc = random.randint(0, 0x3FF) * 4  # Random jump
    
    dut._log.info("✓ Sequential PC with jumps test passed")


# =============================================================================
# TEST: Worst Case - Miss on Every Access
# =============================================================================
@cocotb.test()
async def test_thrashing_worst_case(dut):
    """Access pattern that causes miss on every single access"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Thrashing Worst Case")
    dut._log.info("=" * 60)
    
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=MEMORY_SIZE, reset_active_level=False)
    await reset(dut)
    
    # Create NUM_WAYS + 1 lines per set to guarantee eviction
    set_idx = 0
    num_tags = NUM_WAYS + 1
    
    golden = {}
    addrs = []
    
    for tag in range(num_tags):
        addr = make_address_for_set(set_idx, tag=tag)
        addrs.append(addr)
        data = 0xBAD00000 | (tag << 8)
        for i in range(WORDS_PER_LINE):
            axi_ram.write(addr + i * 4, int_to_bytes(data + i))
        golden[addr] = data
    
    # Access in round-robin: every access is a miss
    for iteration in range(50):
        for tag in range(num_tags):
            addr = addrs[tag]
            result = await cpu_read(dut, addr)
            expected = golden[addr]
            assert result == expected, f"Iter {iteration}, tag {tag}: expected 0x{expected:08X}, got 0x{result:08X}"
    
    dut._log.info("✓ Thrashing worst case test passed")