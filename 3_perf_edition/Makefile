.PHONY: clean

clean:
	@find ./ -type d -name "__pycache__" -exec rm -rf {} +
	@find ./ -type d -name "sim_build" -exec rm -rf {} +
	@find ./ -type f -name "results.xml" -exec rm -f {} +
	@find ./ -type f -name "*.None" -exec rm -f {} +
	@find ./ -type d -name ".pytest_cache" -exec rm -rf {} +
	@find ./ -type f -name "dump.vcd" -exec rm -f {} +
	@find ./ -type d -name "*.bin" -exec rm -rf {} +
	@find ./ -type d -name "*.elf" -exec rm -rf {} +
	@find ./ -type d -name "riscof_work" -exec rm -rf {} +
	@find ./ -type d -name "riscof-arch-test" -exec rm -rf {} +
	@find ./ -type d -name ".Xil" -exec rm -rf {} +
	@find ./fpga -type f -name "vivado.*" -exec rm -rf {} +