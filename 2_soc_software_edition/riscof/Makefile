.PHONY: clean

clean:
	@find ./holy_core_tb -type d -name "__pycache__" -exec rm -rf {} +
	@find ./holy_core_tb -type d -name "sim_build" -exec rm -rf {} +
	@find ./holy_core_tb -type f -name "results.xml" -exec rm -f {} +
	@find ./holy_core_tb -type f -name "*.None" -exec rm -f {} +
	@find ./holy_core_tb -type d -name ".pytest_cache" -exec rm -rf {} +
	@find ./holy_core_tb -type f -name "dump.vcd" -exec rm -f {} +