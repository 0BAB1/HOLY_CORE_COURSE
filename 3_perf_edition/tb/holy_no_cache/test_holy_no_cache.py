# UNCACHED MODULE TESTBENCH - Random Read/Write Stress Test
#
# BRH 11/25
#
# Functional stress testing based tb with handshake protocol for AXI Lite

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer
import random
from cocotbext.axi import AxiLiteBus, AxiLiteRam

CPU_PERIOD = 10
MEMORY_SIZE = 2**20
NUM_READS = 500
NUM_WRITES = 500
NUM_R_W = 500
# close test = number of near addr R/W tests
CLOSE_TESTS = 10

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
    dut.cpu_req_write.value = 0
    dut.cpu_address.value = 0
    dut.cpu_write_data.value = 0
    dut.cpu_byte_enable.value = 0
    dut.cpu_read_ack.value = 0
    
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut._log.info("Reset complete")

async def wait_for_ready(dut, timeout=1000):
    """Wait for module to become ready"""
    count = 0
    while dut.cpu_req_ready.value == 0:
        await RisingEdge(dut.clk)
        count += 1
        if count > timeout:
            raise Exception(f"Ready timeout after {timeout} cycles")

async def cpu_read(dut, address):
    """Perform a CPU read operation with handshake"""
    # Set up read request
    dut.cpu_address.value = address
    dut.cpu_req_valid.value = 1
    dut.cpu_req_write.value = 0  # 0 = read
    dut.cpu_byte_enable.value = 0xF
    dut.cpu_read_ack.value = 1
    
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
    
    await RisingEdge(dut.clk)
    
    return result

async def cpu_write(dut, address, data, byte_enable=0xF):
    """Perform a CPU write operation with handshake"""
    # Set up write request
    dut.cpu_address.value = address
    dut.cpu_write_data.value = data
    dut.cpu_req_valid.value = 1
    dut.cpu_req_write.value = 1  # 1 = write
    dut.cpu_byte_enable.value = byte_enable
    
    # Wait for handshake (req_valid && req_ready)
    await RisingEdge(dut.clk)
    while dut.cpu_req_ready.value == 0:
        await RisingEdge(dut.clk)
    
    # Request accepted, deassert valid
    dut.cpu_req_valid.value = 0
    dut.cpu_req_write.value = 0
    
    await RisingEdge(dut.clk)

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
        axi_lite_ram.write(address, word_bytes)
        mem_golden_ref.append(bytes_to_int(word_bytes))
    
    dut._log.info(f"Memory initialized: {len(mem_golden_ref)} words")
    
    # Verify memory initialization
    for address in range(0, MEMORY_SIZE, 4):
        word_index = int(address / 4)
        mem_data = axi_lite_ram.read(address, 4)
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
async def test_random_writes(dut):
    """Random write stress test with verification"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Random Write Stress Test")
    dut._log.info(f"Will perform {NUM_WRITES} random writes")
    dut._log.info("=" * 60)
    
    # ==================================
    # CLOCKS & RAM DECLARATION
    # ==================================
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    
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
        axi_lite_ram.write(address, word_bytes)
        mem_golden_ref.append(bytes_to_int(word_bytes))
    
    dut._log.info(f"Memory initialized: {len(mem_golden_ref)} words")
    
    # ==================================
    # RANDOM WRITE STRESS TEST
    # ==================================
    dut._log.info(f"Starting {NUM_WRITES} random writes...")
    
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
        
        # Log progress every 100 writes
        if (i + 1) % 100 == 0:
            dut._log.info(f"Progress: {i + 1}/{NUM_WRITES} writes completed ✓")
    
    dut._log.info(f"Write test completed: {NUM_WRITES} writes performed")

    # wait for very last write to happen
    await ClockCycles(dut.clk, 10)
    
    # ==================================
    # VERIFY MEMORY CONSISTENCY
    # ==================================
    # No flush needed for uncached module - writes go directly to memory
    dut._log.info("=" * 60)
    dut._log.info("Verifying golden reference vs AXI Lite RAM...")
    dut._log.info("=" * 60)
    
    memory_errors = 0
    
    for address in range(0, MEMORY_SIZE, 4):
        word_index = int(address / 4)
        expected_data = mem_golden_ref[word_index]
        
        # Read from AXI Lite RAM
        mem_data = axi_lite_ram.read(address, 4)
        actual_data = bytes_to_int(mem_data)
        
        if actual_data != expected_data:
            dut._log.error(f"MEMORY MISMATCH at 0x{address:08X}: " +
                          f"expected 0x{expected_data:08X}, got 0x{actual_data:08X}")
            memory_errors += 1

    # ==================================
    # FINAL REPORT
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info(f"WRITE TEST COMPLETE")
    dut._log.info(f"Total writes: {NUM_WRITES}")
    dut._log.info(f"Memory verification: {memory_errors} mismatches")
    dut._log.info("=" * 60)
    
    # Assert test passed
    assert memory_errors == 0, f"Memory verification failed with {memory_errors} mismatches"
    dut._log.info("✓ WRITE TEST PASSED")


@cocotb.test()
async def test_random_read_write_mixed(dut):
    """Random read/write mixed stress test with locality"""
    dut._log.info("=" * 60)
    dut._log.info("TEST: Random Read/Write Mixed Stress Test")
    dut._log.info(f"Will perform {NUM_R_W} test blocks with locality")
    dut._log.info("=" * 60)
    
    # ==================================
    # CLOCKS & RAM DECLARATION
    # ==================================
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    
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
        axi_lite_ram.write(address, word_bytes)
        mem_golden_ref.append(bytes_to_int(word_bytes))
    
    dut._log.info(f"Memory initialized: {len(mem_golden_ref)} words")
    
    # ==================================
    # RANDOM R/W STRESS TEST
    # ==================================
    dut._log.info(f"Starting {NUM_R_W} random R/W test blocks...")
    
    for i in range(NUM_R_W):
        # Generate random word-aligned base address
        word_index = random.randint(0, len(mem_golden_ref) - 5)
        glob_address = word_index * 4

        for _ in range(CLOSE_TESTS):
            # Generate a slightly offset address for this nested test
            address = glob_address + (random.randint(0, 4) * 4)
            op_type = random.choice(["r", "w"])
            
            if op_type == "r":
                expected_data = mem_golden_ref[address >> 2]
                read_data = await cpu_read(dut, address)
                assert expected_data == read_data, \
                    f"Read mismatch at 0x{address:08X}: expected 0x{expected_data:08X}, got 0x{read_data:08X}"
            else:
                # Write random data
                write_data = random.randint(0, 0xFFFFFFFF)
                await cpu_write(dut, address, write_data)
                
                # Update golden reference
                mem_golden_ref[address >> 2] = write_data
        
        # Log progress every 10 test blocks
        if (i + 1) % 10 == 0:
            dut._log.info(f"Progress: {i + 1}/{NUM_R_W} test blocks completed ✓")
    
    dut._log.info(f"R/W stress test completed: {NUM_R_W} test blocks performed")

    # wait for eventual very last write to happen
    await ClockCycles(dut.clk, 10)
    
    # ==================================
    # VERIFY MEMORY CONSISTENCY
    # ==================================
    # No flush needed for uncached module
    dut._log.info("=" * 60)
    dut._log.info("Verifying golden reference vs AXI Lite RAM...")
    dut._log.info("=" * 60)
    
    memory_errors = 0
    
    for address in range(0, MEMORY_SIZE, 4):
        word_index = int(address / 4)
        expected_data = mem_golden_ref[word_index]
        
        # Read from AXI Lite RAM
        mem_data = axi_lite_ram.read(address, 4)
        actual_data = bytes_to_int(mem_data)
        
        if actual_data != expected_data:
            dut._log.error(f"MEMORY MISMATCH at 0x{address:08X}: " +
                          f"expected 0x{expected_data:08X}, got 0x{actual_data:08X}")
            memory_errors += 1

    # ==================================
    # FINAL REPORT
    # ==================================
    dut._log.info("=" * 60)
    dut._log.info(f"READ/WRITE MIXED TEST COMPLETE")
    dut._log.info(f"Total test blocks: {NUM_R_W}")
    dut._log.info(f"Memory verification: {memory_errors} mismatches")
    dut._log.info("=" * 60)
    
    # Assert test passed
    assert memory_errors == 0, f"Memory verification failed with {memory_errors} mismatches"
    dut._log.info("✓ READ/WRITE MIXED TEST PASSED")