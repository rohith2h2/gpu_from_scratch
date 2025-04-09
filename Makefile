# Makefile for my-tiny-gpu project

# Tool configuration
SIM ?= xsim                # Simulator (xsim, questa, vcs, etc.)
TOPLEVEL ?= matadd_tb      # Default top-level module
SIMULATOR ?= iverilog      # Compile with Icarus Verilog

# Directory configuration
SRC_DIR = src
TEST_DIR = test
BUILD_DIR = build
LOG_DIR = logs

# Files
SV_FILES = $(wildcard $(SRC_DIR)/*.sv)
TEST_FILES = $(wildcard $(TEST_DIR)/*.sv)
COMMON_FILES = $(SRC_DIR)/gpu_pkg.sv

# Create necessary directories
$(shell mkdir -p $(BUILD_DIR) $(LOG_DIR))

# Default target
.PHONY: all
all: compile

# Compile all source files
.PHONY: compile
compile:
	@echo "Compiling all source files..."
	iverilog -g2012 -o $(BUILD_DIR)/gpu.vvp $(COMMON_FILES) $(SV_FILES)
	@echo "Compilation successful!"

# Compile the test bench
.PHONY: test_compile
test_compile: compile
	@echo "Compiling test bench..."
	iverilog -g2012 -o $(BUILD_DIR)/$(TOPLEVEL).vvp $(COMMON_FILES) $(SV_FILES) $(TEST_DIR)/memory_model.sv $(TEST_DIR)/$(TOPLEVEL).sv
	@echo "Test compilation successful!"

# Run the simulation
.PHONY: test
test: test_compile
	@echo "Running simulation for $(TOPLEVEL)..."
	vvp $(BUILD_DIR)/$(TOPLEVEL).vvp -lxt2
	@echo "Simulation completed!"

# Run the matrix addition test
.PHONY: test_matadd
test_matadd:
	@$(MAKE) test TOPLEVEL=matadd_tb

# Clean the build files
.PHONY: clean
clean:
	@echo "Cleaning build files..."
	rm -rf $(BUILD_DIR)/* $(LOG_DIR)/*
	@echo "Clean completed!"

# View waveform (assumes GTKWave is installed)
.PHONY: wave
wave:
	@echo "Opening waveform viewer..."
	gtkwave $(BUILD_DIR)/$(TOPLEVEL).lxt &

# Help command
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  all          - Default target, compiles source files"
	@echo "  compile      - Compile all source files"
	@echo "  test_compile - Compile test bench"
	@echo "  test         - Run simulation (set TOPLEVEL=<module> to specify test bench)"
	@echo "  test_matadd  - Run matrix addition test"
	@echo "  clean        - Clean build files"
	@echo "  wave         - View waveform (requires GTKWave)"
	@echo "  help         - Show this help message" 