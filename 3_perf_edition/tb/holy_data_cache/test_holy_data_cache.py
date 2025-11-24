# CACHE TESTBENCH - Simple Random Read Stress Test
#
# BRH 11/25
# Functional stress testing based tb
#
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
import random
from cocotbext.axi import AxiBus, AxiRam, AxiLiteBus, AxiLiteRam

CPU_PERIOD = 10
MEMORY_SIZE = 2**22
NUM_READS = 1000
NUM_WRITES = 1000
NUM_R_W = 100

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
    dut.cpu_read_enable.value = 0
    dut.cpu_write_enable.value = 0
    dut.cpu_address.value = 0
    dut.cpu_write_data.value = 0
    dut.cpu_byte_enable.value = 0
    
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut._log.info("Reset complete")

async def wait_cache_ready(dut, timeout=1000):
    """Wait for cache to become ready (not busy)"""
    count = 0
    while dut.cpu_cache_busy.value == 1:
        await RisingEdge(dut.clk)
        count += 1
        if count > timeout:
            raise Exception(f"Cache busy timeout after {timeout} cycles")

async def cpu_read(dut, address):
    """Perform a CPU read operation"""
    # Set address and enable read
    dut.cpu_address.value = address
    dut.cpu_read_enable.value = 1
    dut.cpu_write_enable.value = 0
    await RisingEdge(dut.clk)
    
    # Wait for cache to complete
    await wait_cache_ready(dut)
    
    # Capture result
    result = int(dut.cpu_read_data.value)
    
    # Deassert read enable
    dut.cpu_read_enable.value = 0
    await RisingEdge(dut.clk)
    
    return result

async def cpu_write(dut, address, data, byte_enable=0xF):
    """Perform a CPU write operation"""
    dut.cpu_address.value = address
    dut.cpu_write_data.value = data
    dut.cpu_write_enable.value = 1
    dut.cpu_read_enable.value = 0
    dut.cpu_byte_enable.value = byte_enable
    await RisingEdge(dut.clk)
    
    # Wait for cache to be ready
    await wait_cache_ready(dut)
    
    dut.cpu_write_enable.value = 0
    dut.cpu_byte_enable.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def main_test(dut):
    """Random read stress test - 10000 reads with golden reference"""
    dut._log.info("=" * 60)
    dut._log.info("MAIN TEST: Random Read Stress Test")
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
    
    axi_lite_ram = AxiLiteRam(
        AxiLiteBus.from_prefix(dut, "axi_lite"), 
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
        else:
            # Log progress every 1000 reads
            if (i + 1) % 1000 == 0:
                dut._log.info(f"Progress: {i + 1}/{NUM_READS} reads completed ✓")
    
    # ==================================
    # RANDOM WRITE STRESS TEST
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info(f"Starting {NUM_WRITES} random writes...")
    dut._log.info("=" * 60)
    
    write_errors = 0
    
    for i in range(NUM_WRITES):
        # Generate random word-aligned address
        word_index = random.randint(0, len(mem_golden_ref) - 1)
        address = word_index * 4
        
        # Generate random data to write
        write_data = random.randint(0, 0xFFFFFFFF)
        
        # Perform write
        await cpu_write(dut, address, write_data)
        
        # Update golden reference
        mem_golden_ref[word_index] = write_data
        
        # Log progress every 1000 writes
        if (i + 1) % 1000 == 0:
            dut._log.info(f"Progress: {i + 1}/{NUM_WRITES} writes completed ✓")
    
    dut._log.info(f"Write test completed: {NUM_WRITES} writes performed")
    
    # ==================================
    # FLUSH CACHE
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info("Flushing cache to write back all dirty lines...")
    dut._log.info("=" * 60)
    
    # Set flush order high
    dut.cache_system.csr_flush_order.value = 1
    await RisingEdge(dut.clk)
    
    # Wait for flush to complete (cache should go back to IDLE)
    await wait_cache_ready(dut, timeout=5000)
    
    # Clear flush order
    dut.cache_system.csr_flush_order.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.cpu_cache_busy.value == 0
    
    dut._log.info("Cache flush completed ✓")

    # ==================================
    # VERIFY MEMORY CONSISTENCY
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info("Verifying golden reference vs AXI RAM...")
    dut._log.info("=" * 60)
    
    memory_errors = 0
    
    for address in range(0, MEMORY_SIZE, 4):
        word_index = int(address / 4)
        expected_data = mem_golden_ref[word_index]
        
        # Read from AXI RAM
        mem_data = axi_ram.read(address, 4)
        actual_data = bytes_to_int(mem_data)
        
        if actual_data != expected_data:
            dut._log.error(f"MEMORY MISMATCH at 0x{address:08X}: " +
                          f"expected 0x{expected_data:08X}, got 0x{actual_data:08X}")
            memory_errors += 1

    # ==================================
    # RANDOM R/W stress test
    # ==================================
    # this test read and write similar block of memory.
    # eg the test will, for each test that is random, not only perform multiple random r:w,
    # but also make them close in space from each other to allow the cache system to actually
    # be used
    dut._log.info("=" * 60)
    dut._log.info(f"Starting {NUM_R_W} random R/W tests...")
    dut._log.info("=" * 60)
    
    read_write_errors = 0
    CLOSE_TESTS = 10
    
    for i in range(NUM_R_W):
        # Generate random word-aligned address
        word_index = random.randint(0, len(mem_golden_ref) - 1)
        glob_address = word_index * 4

        for _ in range(CLOSE_TESTS):
            # generate a slighly offsetted address fot this nested test
            address = glob_address + (random.randint(0,4) * 4)
            op_type = random.choice(["r", "w"])
            
            if op_type == "r":
                expected_data = mem_golden_ref[address >> 2]
                read_data = await cpu_read(dut, address)
                assert expected_data == read_data
            else:
                # Write random data
                write_data = random.randint(0, 0xFFFFFFFF)
                await cpu_write(dut, address, write_data)
                
                # Update golden reference
                mem_golden_ref[address >> 2] = write_data
    
    dut._log.info(f"R/W stress test completed: {NUM_WRITES} writes performed")

    # ==================================
    # FLUSH CACHE
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info("Flushing cache to write back all dirty lines...")
    dut._log.info("=" * 60)
    
    # Set flush order high
    dut.cache_system.csr_flush_order.value = 1
    await RisingEdge(dut.clk)
    
    # Wait for flush to complete (cache should go back to IDLE)
    await wait_cache_ready(dut, timeout=5000)
    
    # Clear flush order
    dut.cache_system.csr_flush_order.value = 0
    await RisingEdge(dut.clk)
    
    dut._log.info("Cache flush completed ✓")
    
    # ==================================
    # VERIFY MEMORY CONSISTENCY
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info("Verifying golden reference vs AXI RAM...")
    dut._log.info("=" * 60)
    
    memory_errors = 0
    
    for address in range(0, MEMORY_SIZE, 4):
        word_index = int(address / 4)
        expected_data = mem_golden_ref[word_index]
        
        # Read from AXI RAM
        mem_data = axi_ram.read(address, 4)
        actual_data = bytes_to_int(mem_data)
        
        if actual_data != expected_data:
            dut._log.error(f"MEMORY MISMATCH at 0x{address:08X}: " +
                          f"expected 0x{expected_data:08X}, got 0x{actual_data:08X}")
            memory_errors += 1

    # ==================================
    # FINAL REPORT
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info(f"TEST COMPLETE")
    dut._log.info(f"Read test: {NUM_READS} reads, {errors} errors")
    dut._log.info(f"Write test: {NUM_WRITES} writes")
    dut._log.info(f"Memory verification: {memory_errors} mismatches")
    dut._log.info(f"Overall success: {errors == 0 and memory_errors == 0}")
    dut._log.info("=" * 60)
    
    # Assert test passed
    assert errors == 0, f"Read test failed with {errors} errors"
    assert memory_errors == 0, f"Memory verification failed with {memory_errors} mismatches"
    dut._log.info("✓ ALL TESTS PASSED")

@cocotb.test()
async def non_cachable_test(dut):
    """Test with 3/4 of memory range set as non-cachable"""
    dut._log.info("=" * 60)
    dut._log.info("NON-CACHABLE REGION TEST")
    dut._log.info("Setting 3/4 of memory as non-cachable")
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
    
    axi_lite_ram = AxiLiteRam(
        AxiLiteBus.from_prefix(dut, "axi_lite"), 
        dut.clk, 
        dut.rst_n, 
        size=MEMORY_SIZE, 
        reset_active_level=False
    )
    
    await RisingEdge(dut.clk)
    await reset(dut)
    
    # ==================================
    # SET NON-CACHABLE RANGE
    # ==================================
    # Set 3/4 of memory as non-cachable (upper 3/4)
    cachable_limit = MEMORY_SIZE // 4
    non_cachable_base = cachable_limit
    non_cachable_limit = MEMORY_SIZE
    
    dut.cache_system.non_cachable_base.value = non_cachable_base
    dut.cache_system.non_cachable_limit.value = non_cachable_limit
    
    dut._log.info(f"Cachable region:     0x{0:08X} - 0x{cachable_limit:08X}")
    dut._log.info(f"Non-cachable region: 0x{non_cachable_base:08X} - 0x{non_cachable_limit:08X}")
    
    # ==================================
    # MEMORY INIT WITH RANDOM VALUES
    # ==================================
    dut._log.info("Initializing memory with random data...")
    
    mem_golden_ref = []
    
    # Fill AXI RAM (cachable region)
    for address in range(0, MEMORY_SIZE, 4):
        word_bytes = generate_random_bytes(4)
        axi_ram.write(address, word_bytes)
        mem_golden_ref.append(bytes_to_int(word_bytes))
    
    # Fill AXI LITE RAM (non-cachable region) with same data
    for address in range(0, MEMORY_SIZE, 4):
        word_bytes = int_to_bytes(mem_golden_ref[int(address / 4)])
        axi_lite_ram.write(address, word_bytes)
    
    dut._log.info(f"Memory initialized: {len(mem_golden_ref)} words")
    
    # ==================================
    # RANDOM READ STRESS TEST (MIXED)
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info(f"Starting {NUM_READS} random reads (cachable + non-cachable)...")
    dut._log.info("=" * 60)
    
    errors = 0
    cachable_reads = 0
    non_cachable_reads = 0
    
    for i in range(NUM_READS):
        # Generate random word-aligned address (can be anywhere)
        word_index = random.randint(0, len(mem_golden_ref) - 1)
        address = word_index * 4
        
        # Track if cachable or not
        is_cachable = address < cachable_limit
        if is_cachable:
            cachable_reads += 1
        else:
            non_cachable_reads += 1
        
        # Expected data from golden reference
        expected_data = mem_golden_ref[word_index]
        
        # Perform read
        read_data = await cpu_read(dut, address)
        
        # Compare
        if read_data != expected_data:
            region = "CACHABLE" if is_cachable else "NON-CACHABLE"
            dut._log.error(f"[{i}] {region} MISMATCH at 0x{address:08X}: " +
                          f"expected 0x{expected_data:08X}, got 0x{read_data:08X}")
            errors += 1
        else:
            # Log progress every 1000 reads
            if (i + 1) % 1000 == 0:
                dut._log.info(f"Progress: {i + 1}/{NUM_READS} reads completed ✓")
    
    dut._log.info(f"Read test: {cachable_reads} cachable, {non_cachable_reads} non-cachable")
    
    # ==================================
    # RANDOM R/W STRESS TEST (MIXED)
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info(f"Starting {NUM_WRITES} random R/W tests (mixed regions)...")
    dut._log.info("=" * 60)
    
    read_write_errors = 0
    CLOSE_TESTS = 10
    
    for i in range(NUM_WRITES):
        # Generate random word-aligned base address
        base_word_index = random.randint(0, len(mem_golden_ref) - CLOSE_TESTS - 1)
        base_address = base_word_index * 4
        
        for _ in range(CLOSE_TESTS):
            # Generate a slightly offset address for this nested test
            offset_words = random.randint(0, 4)
            address = base_address + (offset_words * 4)
            word_index = int(address / 4)
            
            # Randomly choose read or write
            op_type = random.choice(["r", "w"])
            
            if op_type == "r":
                # Read and verify
                expected_data = mem_golden_ref[word_index]
                read_data = await cpu_read(dut, address)
                
                if expected_data != read_data:
                    is_cachable = address < cachable_limit
                    region = "CACHABLE" if is_cachable else "NON-CACHABLE"
                    dut._log.error(f"R/W test [{i}] {region} READ MISMATCH at 0x{address:08X}: " +
                                  f"expected 0x{expected_data:08X}, got 0x{read_data:08X}")
                    read_write_errors += 1
            else:
                # Write random data
                write_data = random.randint(0, 0xFFFFFFFF)
                await cpu_write(dut, address, write_data)
                
                # Update golden reference
                mem_golden_ref[word_index] = write_data
                
                # Update the appropriate RAM
                if address < cachable_limit:
                    axi_ram.write(address, int_to_bytes(write_data))
                else:
                    axi_lite_ram.write(address, int_to_bytes(write_data))
        
        # Log progress every 100 iterations
        if (i + 1) % 100 == 0:
            dut._log.info(f"Progress: {i + 1}/{NUM_WRITES} R/W blocks completed ✓")
    
    dut._log.info(f"R/W stress test completed: {NUM_WRITES} blocks, {read_write_errors} errors")
    
    # ==================================
    # FLUSH CACHE
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info("Flushing cache to write back all dirty lines...")
    dut._log.info("=" * 60)
    
    # Set flush order high
    dut.cache_system.csr_flush_order.value = 1
    await RisingEdge(dut.clk)
    
    # Wait for flush to complete (cache should go back to IDLE)
    await wait_cache_ready(dut, timeout=10000)
    
    # Clear flush order
    dut.cache_system.csr_flush_order.value = 0
    await RisingEdge(dut.clk)
    
    dut._log.info("Cache flush completed ✓")
    
    # ==================================
    # VERIFY MEMORY CONSISTENCY
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info("Verifying golden reference vs RAMs...")
    dut._log.info("=" * 60)
    
    memory_errors = 0
    
    for address in range(0, MEMORY_SIZE, 4):
        word_index = int(address / 4)
        expected_data = mem_golden_ref[word_index]
        
        # Read from appropriate RAM
        if address < cachable_limit:
            mem_data = axi_ram.read(address, 4)
        else:
            mem_data = axi_lite_ram.read(address, 4)
        
        actual_data = bytes_to_int(mem_data)
        
        if actual_data != expected_data:
            is_cachable = address < cachable_limit
            region = "CACHABLE" if is_cachable else "NON-CACHABLE"
            dut._log.error(f"{region} MEMORY MISMATCH at 0x{address:08X}: " +
                          f"expected 0x{expected_data:08X}, got 0x{actual_data:08X}")
            memory_errors += 1
    
    # ==================================
    # FINAL REPORT
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info(f"NON-CACHABLE TEST COMPLETE")
    dut._log.info(f"Read test: {NUM_READS} reads, {errors} errors")
    dut._log.info(f"  - Cachable reads: {cachable_reads}")
    dut._log.info(f"  - Non-cachable reads: {non_cachable_reads}")
    dut._log.info(f"R/W test: {NUM_WRITES} blocks, {read_write_errors} errors")
    dut._log.info(f"Memory verification: {memory_errors} mismatches")
    dut._log.info(f"Overall success: {errors == 0 and memory_errors == 0 and read_write_errors == 0}")
    dut._log.info("=" * 60)
    
    # Assert test passed
    assert errors == 0, f"Read test failed with {errors} errors"
    assert read_write_errors == 0, f"R/W test failed with {read_write_errors} errors"
    assert memory_errors == 0, f"Memory verification failed with {memory_errors} mismatches"
    dut._log.info("✓ ALL NON-CACHABLE TESTS PASSED")

# =======================================================================
# =======================================================================
# =======================================================================

@cocotb.test()
async def test_cache_thrashing(dut):
    """Test LRU with addresses mapping to same set (conflict misses)"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Cache Thrashing (Conflict Misses)")
    dut._log.info("=" * 60)
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n, 
                     size=2**13, reset_active_level=False)
    axi_lite_ram = AxiLiteRam(AxiLiteBus.from_prefix(dut, "axi_lite"), dut.clk, dut.rst_n,
                              size=2**13, reset_active_level=False)
    
    await reset(dut)
    
    # Three addresses mapping to set 0 (bits [8:6] = 000)
    # Address format: [TAG | SET(3bits) | WORD_OFFSET(4bits) | BYTE_OFFSET(2bits)]
    addr_a = 0x000  # Set 0, tag 0
    addr_b = 0x200  # Set 0, tag 1  
    addr_c = 0x400  # Set 0, tag 2
    
    data_a = 0xAAAAAAAA
    data_b = 0xBBBBBBBB
    data_c = 0xCCCCCCCC
    
    # Initialize memory
    axi_ram.write(addr_a, int_to_bytes(data_a))
    axi_ram.write(addr_b, int_to_bytes(data_b))
    axi_ram.write(addr_c, int_to_bytes(data_c))
    
    # Load A and B (fills both ways of set 0)
    dut._log.info("Loading A and B into set 0")
    result = await cpu_read(dut, addr_a)
    assert result == data_a
    result = await cpu_read(dut, addr_b)
    assert result == data_b
    
    # Access A again to make B the LRU
    dut._log.info("Accessing A again (makes B LRU)")
    result = await cpu_read(dut, addr_a)
    assert result == data_a
    
    # Load C - should evict B (LRU)
    dut._log.info("Loading C (should evict B)")
    result = await cpu_read(dut, addr_c)
    assert result == data_c
    
    # A should still be cached
    dut._log.info("Verifying A still cached")
    result = await cpu_read(dut, addr_a)
    assert result == data_a
    
    # B should cause a miss (was evicted)
    dut._log.info("Reading B (should MISS - was evicted)")
    result = await cpu_read(dut, addr_b)
    assert result == data_b
    
    dut._log.info("✓ Cache thrashing test passed")

# =======================================================================
# =======================================================================
# =======================================================================

@cocotb.test()
async def test_dirty_line_eviction(dut):
    """Test that dirty lines are written back on eviction"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Dirty Line Eviction")
    dut._log.info("=" * 60)
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=2**13, reset_active_level=False)
    axi_lite_ram = AxiLiteRam(AxiLiteBus.from_prefix(dut, "axi_lite"), dut.clk, dut.rst_n,
                              size=2**13, reset_active_level=False)
    
    await reset(dut)
    
    addr1 = 0x000
    addr2 = 0x200  # Same set as addr1
    addr3 = 0x400  # Same set, will evict
    
    initial_data = 0x11111111
    modified_data = 0x99999999
    addr2_data = 0x22222222
    addr3_data = 0x33333333
    
    # Initialize
    axi_ram.write(addr1, int_to_bytes(initial_data))
    axi_ram.write(addr2, int_to_bytes(addr2_data))
    axi_ram.write(addr3, int_to_bytes(addr3_data))
    
    # Load and modify addr1 (makes it dirty)
    dut._log.info("Loading and modifying addr1 (dirty)")
    await cpu_read(dut, addr1)
    await cpu_write(dut, addr1, modified_data)
    
    # Load addr2 (fills second way)
    dut._log.info("Loading addr2")
    await cpu_read(dut, addr2)
    
    # Access addr2 again to make addr1 LRU
    await cpu_read(dut, addr2)
    
    # Load addr3 - should evict dirty addr1 with write-back
    dut._log.info("Loading addr3 (should evict dirty addr1 with WB)")
    await cpu_read(dut, addr3)
    
    # Wait for potential write-back
    await ClockCycles(dut.clk, 50)
    
    # Verify addr1 was written back to memory
    mem_data = axi_ram.read(addr1, 4)
    actual = bytes_to_int(mem_data)
    
    dut._log.info(f"Checking memory: expected 0x{modified_data:08X}, got 0x{actual:08X}")
    assert actual == modified_data, f"Dirty line not written back!"
    
    dut._log.info("✓ Dirty line eviction test passed")

# =======================================================================
# =======================================================================
# =======================================================================

@cocotb.test()
async def test_burst_boundaries(dut):
    """Test reading multiple words within same cache line"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Burst Boundaries (Same Line Access)")
    dut._log.info("=" * 60)
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=2**13, reset_active_level=False)
    axi_lite_ram = AxiLiteRam(AxiLiteBus.from_prefix(dut, "axi_lite"), dut.clk, dut.rst_n,
                              size=2**13, reset_active_level=False)
    
    await reset(dut)
    
    base_addr = 0x100
    
    # Initialize a full cache line (16 words = 64 bytes)
    golden = []
    for i in range(16):
        data = 0x1000 + i
        axi_ram.write(base_addr + (i * 4), int_to_bytes(data))
        golden.append(data)
    
    # First read should MISS
    dut._log.info(f"First read at 0x{base_addr:08X} (should MISS)")
    result = await cpu_read(dut, base_addr)
    assert result == golden[0]
    
    # All subsequent reads in same line should HIT
    dut._log.info("Reading all 16 words in same line (should all HIT)")
    for i in range(1, 16):
        addr = base_addr + (i * 4)
        result = await cpu_read(dut, addr)
        assert result == golden[i], f"Word {i} mismatch"

    # TODO : add actual hit assertions, for now, data integrity will do
    
    dut._log.info("✓ Burst boundaries test passed")


# =======================================================================
# =======================================================================
# =======================================================================

@cocotb.test()
async def test_cachable_non_cachable_boundary(dut):
    """Test boundary between cachable and non-cachable regions"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Cachable/Non-Cachable Boundary")
    dut._log.info("=" * 60)
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=2**13, reset_active_level=False)
    axi_lite_ram = AxiLiteRam(AxiLiteBus.from_prefix(dut, "axi_lite"), dut.clk, dut.rst_n,
                              size=2**13, reset_active_level=False)
    
    await reset(dut)
    
    # Set boundary at 0x1000
    boundary = 0x1000
    dut.cache_system.non_cachable_base.value = boundary
    dut.cache_system.non_cachable_limit.value = 0x2000
    
    addr_cachable = boundary - 4      # Just before boundary
    addr_non_cachable = boundary      # At boundary
    
    data_cachable = 0xCACA0000
    data_non_cachable = 0xBABA0000
    
    # Initialize both RAMs
    axi_ram.write(addr_cachable, int_to_bytes(data_cachable))
    axi_lite_ram.write(addr_non_cachable, int_to_bytes(data_non_cachable))
    
    # Read cachable
    dut._log.info(f"Reading cachable at 0x{addr_cachable:08X}")
    result = await cpu_read(dut, addr_cachable)
    assert result == data_cachable
    
    # Read non-cachable
    dut._log.info(f"Reading non-cachable at 0x{addr_non_cachable:08X}")
    result = await cpu_read(dut, addr_non_cachable)
    assert result == data_non_cachable
    
    # Read cachable again (should still work)
    result = await cpu_read(dut, addr_cachable)
    assert result == data_cachable

    # Write set of data between boundaries
    await cpu_write(dut, boundary - 4, 0xAAAAAAAA)
    await cpu_write(dut, boundary, 0XBBBBBBBB)
    await cpu_write(dut, boundary + 4, 0xCCCCCCCC)

    # Verify to 2 uncached ranges writes are in the actual RAM
    result = axi_lite_ram.read(boundary, 4)
    assert result == int_to_bytes(0xBBBBBBBB)
    result = axi_lite_ram.read(boundary + 4, 4)
    assert result == int_to_bytes(0xCCCCCCCC)
    
    dut._log.info("✓ Cachable/non-cachable boundary test passed")

# =======================================================================
# =======================================================================
# =======================================================================

@cocotb.test()
async def test_write_after_read_same_line(dut):
    """Test write-after-read on same cache line"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Write-After-Read Same Line")
    dut._log.info("=" * 60)
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=2**13, reset_active_level=False)
    axi_lite_ram = AxiLiteRam(AxiLiteBus.from_prefix(dut, "axi_lite"), dut.clk, dut.rst_n,
                              size=2**13, reset_active_level=False)
    
    await reset(dut)
    
    base_addr = 0x200
    
    # Initialize memory
    for i in range(16):
        axi_ram.write(base_addr + (i * 4), int_to_bytes(0x1000 + i))
    
    # 1. Read address (miss, loads line)
    dut._log.info(f"Read 0x{base_addr:08X} (MISS)")
    result = await cpu_read(dut, base_addr)
    assert result == 0x1000
    
    # 2. Write to base_addr+4 (same line, should HIT)
    new_data = 0xDEADBEEF
    dut._log.info(f"Write to 0x{base_addr+4:08X} (should HIT, same line)")
    await cpu_write(dut, base_addr + 4, new_data)
    
    # 3. Read base_addr+8 (same line, should HIT)
    dut._log.info(f"Read 0x{base_addr+8:08X} (should HIT, same line)")
    result = await cpu_read(dut, base_addr + 8)
    assert result == 0x1002
    
    # 4. Verify the write stuck
    result = await cpu_read(dut, base_addr + 4)
    assert result == new_data
    
    dut._log.info("✓ Write-after-read same line test passed")

# =======================================================================
# =======================================================================
# =======================================================================

@cocotb.test()
async def test_cache_saturation(dut):
    """Test filling all cache lines then forcing replacement"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Cache Saturation")
    dut._log.info("=" * 60)
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=2**13, reset_active_level=False)
    axi_lite_ram = AxiLiteRam(AxiLiteBus.from_prefix(dut, "axi_lite"), dut.clk, dut.rst_n,
                              size=2**13, reset_active_level=False)
    
    await reset(dut)
    
    # Fill entire cache: 2 ways × 8 sets = 16 unique cache lines
    # Each line is 64 bytes, so addresses 0x000, 0x040, 0x080, ... for set 0
    # Then 0x200, 0x240, 0x280, ... for set 0 way 1
    # Then 0x040, 0x080, ... for set 1, etc.
    
    filled_addresses = []
    
    # Fill way 0: 8 sets
    dut._log.info("Filling way 0 (8 sets)")
    for set_idx in range(8):
        addr = (set_idx << 6)  # Set index in bits [8:6]
        data = 0x1000 + set_idx
        axi_ram.write(addr, int_to_bytes(data))
        result = await cpu_read(dut, addr)
        assert result == data
        filled_addresses.append((addr, data))
    
    # Fill way 1: 8 sets (different tags)
    dut._log.info("Filling way 1 (8 sets)")
    for set_idx in range(8):
        addr = (0x200) | (set_idx << 6)  # Different tag
        data = 0x2000 + set_idx
        axi_ram.write(addr, int_to_bytes(data))
        result = await cpu_read(dut, addr)
        assert result == data
        filled_addresses.append((addr, data))
    
    # Cache is now full (16 lines)
    dut._log.info("Cache full with 16 lines")
    
    # Load a 17th line - should evict one line
    new_addr = 0x400  # Maps to set 0, will evict LRU
    new_data = 0x9999
    axi_ram.write(new_addr, int_to_bytes(new_data))
    
    dut._log.info(f"Loading 17th line at 0x{new_addr:08X} (forces eviction)")
    result = await cpu_read(dut, new_addr)
    assert result == new_data
    
    # Verify one line was evicted (would cause a miss)
    # The first address in set 0 should have been evicted
    dut._log.info("Verifying eviction occurred")
    result = await cpu_read(dut, filled_addresses[0][0])
    assert result == filled_addresses[0][1]
    
    dut._log.info("✓ Cache saturation test passed")


@cocotb.test()
async def test_read_modify_write_sequence(dut):
    """Test read-modify-write pattern"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Read-Modify-Write Sequence")
    dut._log.info("=" * 60)
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=2**13, reset_active_level=False)
    axi_lite_ram = AxiLiteRam(AxiLiteBus.from_prefix(dut, "axi_lite"), dut.clk, dut.rst_n,
                              size=2**13, reset_active_level=False)
    
    await reset(dut)
    
    addr = 0x300
    initial = 0x12345678
    
    axi_ram.write(addr, int_to_bytes(initial))
    
    # Read
    dut._log.info(f"Read: 0x{addr:08X}")
    old_val = await cpu_read(dut, addr)
    assert old_val == initial
    
    # Modify
    new_val = old_val ^ 0xAAAAAAAA
    dut._log.info(f"Modify: 0x{old_val:08X} XOR 0xAAAAAAAA = 0x{new_val:08X}")
    
    # Write
    await cpu_write(dut, addr, new_val)
    
    # Verify
    result = await cpu_read(dut, addr)
    assert result == new_val
    
    dut._log.info("✓ Read-modify-write sequence test passed")


@cocotb.test()
async def test_all_sets_access(dut):
    """Test accessing all sets in random order"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: All Sets Random Access")
    dut._log.info("=" * 60)
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=2**13, reset_active_level=False)
    axi_lite_ram = AxiLiteRam(AxiLiteBus.from_prefix(dut, "axi_lite"), dut.clk, dut.rst_n,
                              size=2**13, reset_active_level=False)
    
    await reset(dut)
    
    # Create addresses for all 8 sets with random tags
    set_addresses = []
    for set_idx in range(8):
        addr = (set_idx << 6)  # Juste le set index, tag = 0
        data = 0xA000 + set_idx
        axi_ram.write(addr, data.to_bytes(4, byteorder='little'))
        set_addresses.append((addr, data))
    
    # Shuffle and access
    random.shuffle(set_addresses)
    
    dut._log.info("Accessing all 8 sets in random order")
    for addr, expected in set_addresses:
        result = await cpu_read(dut, addr)
        assert result == expected, f"Set access failed at 0x{addr:08X}"
    
    dut._log.info("✓ All sets random access test passed")


@cocotb.test()
async def test_rapid_read_write_toggle(dut):
    """Test rapid toggling between reads and writes"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Rapid Read/Write Toggle")
    dut._log.info("=" * 60)
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    axi_ram = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n,
                     size=2**13, reset_active_level=False)
    axi_lite_ram = AxiLiteRam(AxiLiteBus.from_prefix(dut, "axi_lite"), dut.clk, dut.rst_n,
                              size=2**13, reset_active_level=False)
    
    await reset(dut)
    
    addr = 0x400
    
    # Initialize
    axi_ram.write(addr, int_to_bytes(0))
    
    # Rapid R/W/R/W pattern
    dut._log.info("Performing rapid R/W/R/W pattern")
    for i in range(10):
        # Read
        val = await cpu_read(dut, addr)
        # Write
        await cpu_write(dut, addr, val + 1)
        # Read again
        val = await cpu_read(dut, addr)
        assert val == i + 1
    
    dut._log.info("✓ Rapid read/write toggle test passed")

# =======================================================================
# =======================================================================
# =======================================================================

@cocotb.test()
async def test_cachable_non_cachable_double_read(dut):
    """
    When two reads happen in a row on non cachable, but on a DIFFERENT ADDRESS
    We should refetch, oviously...
    """
    dut._log.info("=" * 60)
    dut._log.info("TEST: Non-Cachable double read")
    dut._log.info("=" * 60)
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    axi_lite_ram = AxiLiteRam(AxiLiteBus.from_prefix(dut, "axi_lite"), dut.clk, dut.rst_n,
                              size=2**13, reset_active_level=False)
    
    await reset(dut)
    
    # Set boundary at 0x1000
    dut.cache_system.non_cachable_base.value = 0x0
    dut.cache_system.non_cachable_limit.value = 0xFFFFFFFF
    
    test_addr = 0x1000
    data1 = 0xDEADBEEF
    data2 = 0xABCD1234
    
    # Initialize RAM
    axi_lite_ram.write(test_addr, int_to_bytes(data1))
    axi_lite_ram.write(test_addr + 4, int_to_bytes(data2))
    axi_lite_ram.read(test_addr, 4)
    # Read 2 datas in a row
    dut.cpu_address.value = test_addr
    dut.cpu_read_enable.value = 1
    dut.cpu_write_enable.value = 0
    await Timer(1, units="ns")
    while dut.cpu_cache_busy.value == 1:
        await Timer(1, units="ns")
    result1 = int(dut.cpu_read_data.value)

    dut.cpu_address.value = test_addr + 4
    await Timer(1, units="ns")
    while dut.cpu_cache_busy.value == 1:
        await Timer(1, units="ns")
    result2 = await cpu_read(dut, test_addr + 4)

    assert result1 == data1
    assert result2 == data2
    
    dut._log.info("✓ Cachable/non-cachable boundary test passed")

# =======================================================================
# =======================================================================
# =======================================================================

@cocotb.test()
async def test_cachable_non_cachable_double_write(dut):
    """
    same as double read but for write
    """
    dut._log.info("=" * 60)
    dut._log.info("TEST: Non-Cachable double read")
    dut._log.info("=" * 60)
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    axi_lite_ram = AxiLiteRam(AxiLiteBus.from_prefix(dut, "axi_lite"), dut.clk, dut.rst_n,
                              size=2**13, reset_active_level=False)
    
    await reset(dut)
    
    # Set boundary at 0x1000
    dut.cpu_byte_enable.value = 0xF
    dut.cache_system.non_cachable_base.value = 0x0
    dut.cache_system.non_cachable_base.value = 0x0
    dut.cache_system.non_cachable_limit.value = 0xFFFFFFFF
    
    test_addr = 0x1000
    data1 = 0xDEADBEEF
    data2 = 0xABCD1234
    
    # Write 2 datas in a row
    dut.cpu_address.value = test_addr
    dut.cpu_write_data.value = data1
    dut.cpu_read_enable.value = 0
    dut.cpu_write_enable.value = 1
    await Timer(1, units="ns")
    while dut.cpu_cache_busy.value == 1:
        await Timer(1, units="ns")

    # change instruction
    await RisingEdge(dut.clk)

    dut.cpu_address.value = test_addr + 4
    dut.cpu_write_data.value = data2
    await Timer(1, units="ns")
    while dut.cpu_cache_busy.value == 1:
        await Timer(1, units="ns")

    result1 = bytes_to_int(axi_lite_ram.read(test_addr, 4))
    result2 = bytes_to_int(axi_lite_ram.read(test_addr + 4, 4))

    await Timer(20, units="ns")

    assert result1 == data1
    assert result2 == data2
    
    dut._log.info("✓ Cachable/non-cachable boundary test passed")