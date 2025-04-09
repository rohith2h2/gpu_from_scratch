# My Tiny GPU

A minimal GPU implementation in SystemVerilog, based on the [tiny-gpu](https://github.com/adamjmurray/tiny-gpu) project, designed for learning the principles of GPU architecture.

## Overview

This project is a SystemVerilog implementation of a minimal GPU that demonstrates the core principles of GPU architecture, including:

- SIMD (Same Instruction Multiple Data) parallelism
- Thread and block-based execution model
- Memory controllers for managing access to shared resources
- Instruction execution pipeline

The GPU is designed to be simple yet complete, capable of running basic kernels like matrix addition.

## Project Structure

```
my-tiny-gpu/
├── src/              # Source files for the GPU implementation
│   ├── gpu_pkg.sv    # Common definitions and types
│   ├── alu.sv        # Arithmetic Logic Unit
│   ├── pc.sv         # Program Counter
│   ├── lsu.sv        # Load-Store Unit
│   ├── registers.sv  # Register File
│   ├── fetcher.sv    # Instruction Fetcher
│   ├── decoder.sv    # Instruction Decoder
│   ├── scheduler.sv  # Execution Scheduler
│   ├── controller.sv # Memory Controller
│   ├── dcr.sv        # Device Control Register
│   ├── dispatch.sv   # Thread Dispatcher
│   └── gpu.sv        # Top-level GPU Module
├── test/             # Test files
│   ├── memory_model.sv # Memory model for simulation
│   └── matadd_tb.sv  # Matrix addition test bench
├── docs/             # Documentation
│   └── design_specs.md # Design specifications
└── Makefile          # Build system
```

## Architecture

The GPU follows a hierarchical architecture:

1. **GPU (Top Level)** - Contains:
   - Device Control Register: Stores metadata for kernel execution
   - Dispatcher: Distributes threads to cores
   - Memory Controllers: Manage access to data and program memory
   - Multiple Compute Cores: Process blocks of threads

2. **Cores** - Each core contains:
   - Scheduler: Manages execution flow
   - Fetcher: Retrieves instructions from program memory
   - Decoder: Translates instructions into control signals
   - Thread Processing Units: ALU, LSU, PC, and registers for each thread

## Instruction Set Architecture (ISA)

The ISA consists of 11 instructions:
- Arithmetic: `ADD`, `SUB`, `MUL`, `DIV`
- Memory: `LDR` (load), `STR` (store)
- Control flow: `BRnzp` (branch), `CMP` (compare)
- Other: `CONST` (load constant), `RET` (return)

Each thread has access to 16 registers (R0-R15), with R13-R15 being special registers that contain block ID, block dimensions, and thread ID.

## Execution Model

The GPU follows a SIMD (Same Instruction Multiple Data) execution model:
1. Threads are organized into blocks
2. Each core processes one block at a time
3. All threads in a block execute the same instruction on different data
4. Threads can access their ID to compute memory addresses for data access

## Memory System

The memory system includes:
- Program Memory: Stores kernel instructions
- Data Memory: Stores the data being processed
- Memory Controllers: Arbitrate access to memory from multiple cores

## Building and Running

### Prerequisites

- Icarus Verilog (`iverilog`) or other Verilog simulator
- GTKWave (optional, for viewing waveforms)

### Compilation

To compile the project:

```bash
make compile
```

### Running Tests

To run the matrix addition test:

```bash
make test_matadd
```

### Viewing Waveforms

After running a test, you can view the waveforms:

```bash
make wave
```

## Example Kernel: Matrix Addition

The project includes a matrix addition kernel that adds two 1x8 matrices. Each thread computes one element of the result matrix:

```
MUL R0, %blockIdx, %blockDim     ; Calculate base index
ADD R0, R0, %threadIdx           ; i = blockIdx * blockDim + threadIdx
CONST R1, #0                     ; baseA (matrix A base address)
CONST R2, #8                     ; baseB (matrix B base address)
CONST R3, #16                    ; baseC (matrix C base address)
ADD R4, R1, R0                   ; addr(A[i]) = baseA + i
LDR R4, R4                       ; load A[i] from memory
ADD R5, R2, R0                   ; addr(B[i]) = baseB + i
LDR R5, R5                       ; load B[i] from memory
ADD R6, R4, R5                   ; C[i] = A[i] + B[i]
ADD R7, R3, R0                   ; addr(C[i]) = baseC + i
STR R7, R6                       ; store C[i] to memory
RET                              ; end of kernel
```

## Future Improvements

Potential improvements to explore:
- Add a cache implementation
- Implement branch divergence handling
- Add memory coalescing for better memory access efficiency
- Implement warp scheduling for improved core utilization
- Add support for synchronization barriers between threads

## License

This project is for educational purposes and is released under the MIT License.

## Acknowledgments

This project is inspired by the [tiny-gpu](https://github.com/adamjmurray/tiny-gpu) project by Adam Murray. 