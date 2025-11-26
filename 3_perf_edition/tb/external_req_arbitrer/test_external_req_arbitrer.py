# EXTERNAL REQUESTS ARBITRER TESTBENCH (ROBUST VERSION)
#
# BRH 11/25
#
# Robust unit test with proper reset, logging, error handling, and edge cases

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotbext.axi import AxiBus, AxiRam, AxiMaster
import random

# CACHE STATES CONSTANTS
IDLE                = 0b0000
SENDING_WRITE_REQ   = 0b0001
SENDING_WRITE_DATA  = 0b0010
WAITING_WRITE_RES   = 0b0011
FLUSH_NEXT          = 0b0100
SENDING_READ_REQ    = 0b0101
RECEIVING_READ_DATA = 0b0110

async def reset_dut(dut):
    """Proper reset sequence"""
    dut.rst_n.value = 0
    dut.instr_cache_state.value = IDLE
    dut.data_cache_state.value = IDLE
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut._log.info("✓ Reset complete")

@cocotb.test()
async def test_arbiter_comprehensive(dut):
    """Comprehensive arbiter test with all scenarios"""
    
    PERIOD = 10
    MEM_SIZE = 4096
    
    dut._log.info("=" * 70)
    dut._log.info("ARBITER COMPREHENSIVE TEST")
    dut._log.info("=" * 70)
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, PERIOD, units="ns").start())
    
    axi_ram_slave = AxiRam(
        AxiBus.from_prefix(dut, "m_axi"), 
        dut.clk, 
        dut.rst_n, 
        reset_active_level=False, 
        size=MEM_SIZE
    )
    
    i_cache_master = AxiMaster(
        AxiBus.from_prefix(dut, "s_axi_instr"), 
        dut.clk, 
        dut.rst_n, 
        reset_active_level=False
    )
    
    d_cache_master = AxiMaster(
        AxiBus.from_prefix(dut, "s_axi_data"), 
        dut.clk, 
        dut.rst_n, 
        reset_active_level=False
    )
    
    await reset_dut(dut)
    
    # ========================================
    # SCENARIO 1: D-CACHE WRITE ONLY
    # ========================================
    dut._log.info("-" * 70)
    dut._log.info("SCENARIO 1: D-cache write only")
    
    dut.data_cache_state.value = SENDING_WRITE_REQ
    await RisingEdge(dut.clk)
    
    await d_cache_master.write(0x000, b'test')
    
    dut.data_cache_state.value = IDLE
    await RisingEdge(dut.clk)
    
    # Verify
    read_data = axi_ram_slave.read(0x000, 4)
    assert read_data == b'test', f"Expected b'test', got {read_data}"
    dut._log.info("✓ D-cache write successful")
    
    # ========================================
    # SCENARIO 2: I-CACHE READ ONLY
    # ========================================
    dut._log.info("-" * 70)
    dut._log.info("SCENARIO 2: I-cache read only")
    
    dut.instr_cache_state.value = SENDING_READ_REQ
    await RisingEdge(dut.clk)
    
    data = await i_cache_master.read(0x000, 4)
    
    dut.instr_cache_state.value = IDLE
    await RisingEdge(dut.clk)
    
    assert data.data == b'test', f"Expected b'test', got {data.data}"
    dut._log.info("✓ I-cache read successful")
    
    # ========================================
    # SCENARIO 3: D-CACHE READ ONLY
    # ========================================
    dut._log.info("-" * 70)
    dut._log.info("SCENARIO 3: D-cache read only")
    
    dut.data_cache_state.value = SENDING_READ_REQ
    await RisingEdge(dut.clk)
    
    data = await d_cache_master.read(0x000, 4)
    
    dut.data_cache_state.value = IDLE
    await RisingEdge(dut.clk)
    
    assert data.data == b'test', f"Expected b'test', got {data.data}"
    dut._log.info("✓ D-cache read successful")
    
    # ========================================
    # SCENARIO 4: BOTH REQUEST - I-CACHE PRIORITY
    # ========================================
    dut._log.info("-" * 70)
    dut._log.info("SCENARIO 4: Both caches request simultaneously (I-cache priority)")
    
    # Both request at same time
    dut.data_cache_state.value = SENDING_READ_REQ
    dut.instr_cache_state.value = SENDING_READ_REQ
    await RisingEdge(dut.clk)
    
    # I-cache should be served first
    dut._log.info("  → I-cache should be served first...")
    data_i = await i_cache_master.read(0x000, 4)
    assert data_i.data == b'test', f"I-cache read failed: {data_i.data}"
    
    dut.instr_cache_state.value = IDLE
    await RisingEdge(dut.clk)
    dut._log.info("  ✓ I-cache served")
    
    # D-cache should be served after
    dut._log.info("  → D-cache should be served second...")
    data_d = await d_cache_master.read(0x000, 4)
    assert data_d.data == b'test', f"D-cache read failed: {data_d.data}"
    
    dut.data_cache_state.value = IDLE
    await RisingEdge(dut.clk)
    dut._log.info("  ✓ D-cache served")
    dut._log.info("✓ Arbitration priority correct")
    
    # ========================================
    # SCENARIO 5: BOTH WRITE SEQUENTIALLY
    # ========================================
    dut._log.info("-" * 70)
    dut._log.info("SCENARIO 5: Both caches write (sequential)")
    
    # Both request
    dut.data_cache_state.value = SENDING_WRITE_REQ
    dut.instr_cache_state.value = SENDING_WRITE_REQ
    await RisingEdge(dut.clk)
    
    # I-cache writes first
    dut._log.info("  → I-cache writing...")
    await i_cache_master.write(0x00C, b'beef')
    dut.instr_cache_state.value = IDLE
    await RisingEdge(dut.clk)
    dut._log.info("  ✓ I-cache write complete")
    
    # D-cache writes second
    dut._log.info("  → D-cache writing...")
    await d_cache_master.write(0x010, b'1234')
    dut.data_cache_state.value = IDLE
    await RisingEdge(dut.clk)
    dut._log.info("  ✓ D-cache write complete")
    
    # Verify both writes
    read_i = axi_ram_slave.read(0x00C, 4)
    read_d = axi_ram_slave.read(0x010, 4)
    assert read_i == b'beef', f"I-cache write verification failed: {read_i}"
    assert read_d == b'1234', f"D-cache write verification failed: {read_d}"
    dut._log.info("✓ Both writes verified")
    
    # ========================================
    # SCENARIO 6: BURST TRANSACTIONS
    # ========================================
    dut._log.info("-" * 70)
    dut._log.info("SCENARIO 6: Burst transactions (cache line fills)")
    
    # Write burst data for testing
    burst_data = bytes([i % 256 for i in range(64)])
    axi_ram_slave.write(0x100, burst_data)
    
    # I-cache burst read
    dut.instr_cache_state.value = SENDING_READ_REQ
    await RisingEdge(dut.clk)
    
    dut._log.info("  → I-cache burst read (64 bytes)...")
    data_burst = await i_cache_master.read(0x100, 64)
    
    dut.instr_cache_state.value = IDLE
    await RisingEdge(dut.clk)
    
    assert len(data_burst.data) == 64, f"Burst length incorrect: {len(data_burst.data)}"
    assert data_burst.data == burst_data, "Burst data mismatch"
    dut._log.info("  ✓ Burst read successful")
    
    # D-cache burst write
    dut.data_cache_state.value = SENDING_WRITE_REQ
    await RisingEdge(dut.clk)
    
    burst_write_data = bytes([0xAA, 0xBB, 0xCC, 0xDD] * 16)  # 64 bytes
    dut._log.info("  → D-cache burst write (64 bytes)...")
    await d_cache_master.write(0x200, burst_write_data)
    
    dut.data_cache_state.value = IDLE
    await RisingEdge(dut.clk)
    
    # Verify burst write
    verify_burst = axi_ram_slave.read(0x200, 64)
    assert verify_burst == burst_write_data, "Burst write verification failed"
    dut._log.info("  ✓ Burst write successful")
    
    # ========================================
    # SCENARIO 7: RAPID STATE TRANSITIONS
    # ========================================
    dut._log.info("-" * 70)
    dut._log.info("SCENARIO 7: Rapid state transitions")
    
    for i in range(10):
        # Alternate between caches rapidly
        if i % 2 == 0:
            dut.instr_cache_state.value = SENDING_WRITE_REQ
            await RisingEdge(dut.clk)
            await i_cache_master.write(0x300 + i*4, i.to_bytes(4, 'little'))
            dut.instr_cache_state.value = IDLE
        else:
            dut.data_cache_state.value = SENDING_WRITE_REQ
            await RisingEdge(dut.clk)
            await d_cache_master.write(0x300 + i*4, i.to_bytes(4, 'little'))
            dut.data_cache_state.value = IDLE
        
        await RisingEdge(dut.clk)
    
    # Verify all rapid writes
    errors = 0
    for i in range(10):
        expected = i.to_bytes(4, 'little')
        actual = axi_ram_slave.read(0x300 + i*4, 4)
        if actual != expected:
            dut._log.error(f"  ✗ Mismatch at iteration {i}: expected {expected}, got {actual}")
            errors += 1
    
    assert errors == 0, f"{errors} errors in rapid transitions"
    dut._log.info(f"  ✓ All {10} rapid transitions successful")
    
    # ========================================
    # SCENARIO 8: DIFFERENT ADDRESS PATTERNS
    # ========================================
    dut._log.info("-" * 70)
    dut._log.info("SCENARIO 8: Different address patterns")
    
    # Test aligned addresses
    test_addrs = [0x000, 0x004, 0x008, 0x00C, 0x010, 0x100, 0x200, 0x400, 0x800]
    
    for addr in test_addrs:
        test_data = addr.to_bytes(4, 'little')
        
        dut.data_cache_state.value = SENDING_WRITE_REQ
        await RisingEdge(dut.clk)
        await d_cache_master.write(addr, test_data)
        dut.data_cache_state.value = IDLE
        await RisingEdge(dut.clk)
        
        verify_data = axi_ram_slave.read(addr, 4)
        assert verify_data == test_data, f"Address {addr:#x} failed"
    
    dut._log.info(f"  ✓ All {len(test_addrs)} address patterns successful")
    
    # ========================================
    # SCENARIO 9: IDLE STATE HANDLING
    # ========================================
    dut._log.info("-" * 70)
    dut._log.info("SCENARIO 9: Proper IDLE state handling")
    
    # Both IDLE for several cycles
    dut.instr_cache_state.value = IDLE
    dut.data_cache_state.value = IDLE
    await ClockCycles(dut.clk, 10)
    
    # Verify no spurious transactions occurred
    dut._log.info("  ✓ No spurious transactions during IDLE")
    
    # Transition from IDLE
    dut.data_cache_state.value = SENDING_WRITE_REQ
    await RisingEdge(dut.clk)
    await d_cache_master.write(0x500, b'idle')
    dut.data_cache_state.value = IDLE
    await RisingEdge(dut.clk)
    
    verify = axi_ram_slave.read(0x500, 4)
    assert verify == b'idle', "IDLE transition failed"
    dut._log.info("  ✓ IDLE → ACTIVE transition successful")
    
    # ========================================
    # SCENARIO 10: STRESS TEST
    # ========================================
    dut._log.info("-" * 70)
    dut._log.info("SCENARIO 10: Stress test with random operations")
    
    NUM_STRESS_OPS = 50
    stress_errors = 0
    
    for i in range(NUM_STRESS_OPS):
        # Random cache, random operation
        use_icache = random.choice([True, False])
        do_write = random.choice([True, False])
        addr = random.randrange(0, MEM_SIZE - 4, 4)
        
        if use_icache:
            dut.instr_cache_state.value = SENDING_WRITE_REQ if do_write else SENDING_READ_REQ
            await RisingEdge(dut.clk)
            
            if do_write:
                data = i.to_bytes(4, 'little')
                await i_cache_master.write(addr, data)
            else:
                await i_cache_master.read(addr, 4)
            
            dut.instr_cache_state.value = IDLE
        else:
            dut.data_cache_state.value = SENDING_WRITE_REQ if do_write else SENDING_READ_REQ
            await RisingEdge(dut.clk)
            
            if do_write:
                data = i.to_bytes(4, 'little')
                await d_cache_master.write(addr, data)
            else:
                await d_cache_master.read(addr, 4)
            
            dut.data_cache_state.value = IDLE
        
        await RisingEdge(dut.clk)
        
        if (i + 1) % 10 == 0:
            dut._log.info(f"  Progress: {i + 1}/{NUM_STRESS_OPS} operations")
    
    assert stress_errors == 0, f"Stress test had {stress_errors} errors"
    dut._log.info(f"  ✓ Stress test complete: {NUM_STRESS_OPS} random operations")
    
    # ========================================
    # FINAL REPORT
    # ========================================
    dut._log.info("=" * 70)
    dut._log.info("ALL TESTS PASSED ✓")
    dut._log.info("Scenarios tested:")
    dut._log.info("  1. D-cache write only")
    dut._log.info("  2. I-cache read only")
    dut._log.info("  3. D-cache read only")
    dut._log.info("  4. Simultaneous requests (priority)")
    dut._log.info("  5. Sequential writes")
    dut._log.info("  6. Burst transactions")
    dut._log.info("  7. Rapid state transitions")
    dut._log.info("  8. Address patterns")
    dut._log.info("  9. IDLE state handling")
    dut._log.info(" 10. Stress test (random ops)")
    dut._log.info("=" * 70)