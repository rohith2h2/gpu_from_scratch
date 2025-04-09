# Beginner's Guide to GPU Implementation

This guide is designed to help beginners understand the SystemVerilog GPU implementation. It breaks down complex concepts into digestible pieces and provides step-by-step explanations of how everything works.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Getting Started](#getting-started)
3. [Understanding GPU Architecture](#understanding-gpu-architecture)
4. [SystemVerilog Basics](#systemverilog-basics)
5. [How to Run Your First Simulation](#how-to-run-your-first-simulation)
6. [Walkthrough: Matrix Addition Kernel](#walkthrough-matrix-addition-kernel)
7. [FAQ](#faq)

## Prerequisites

Before diving into this project, it would be helpful to have a basic understanding of:

- **Digital Logic**: Understanding of basic logic gates, flip-flops, and state machines
- **Computer Architecture**: Basic knowledge of processors, memory, and instruction execution
- **Programming**: Familiarity with any programming language will help understand the concepts

Don't worry if you're not an expert in these areas - we'll explain the concepts as we go along!

### Required Software Tools

To run and simulate the GPU, you'll need:

1. **Icarus Verilog**: A Verilog/SystemVerilog simulator
   - Installation on Linux: `sudo apt-get install iverilog`
   - Installation on macOS: `brew install icarus-verilog`
   - Installation on Windows: Download from [Icarus Verilog website](http://iverilog.icarus.com/)

2. **GTKWave**: For viewing simulation waveforms
   - Installation on Linux: `sudo apt-get install gtkwave`
   - Installation on macOS: `brew install gtkwave`
   - Installation on Windows: Download from [GTKWave website](http://gtkwave.sourceforge.net/)

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/rohith2h2/gpu_from_scratch.git
cd gpu_from_scratch
```

### 2. Project Structure Overview

The project is organized into the following directories:

- **`src/`**: Contains all the SystemVerilog source files
  - `gpu_pkg.sv`: Common definitions and types
  - `alu.sv`: Arithmetic Logic Unit
  - `pc.sv`: Program Counter
  - `lsu.sv`: Load-Store Unit
  - ... and more

- **`test/`**: Contains test files and simulation models
  - `memory_model.sv`: Behavioral model of memory
  - `matadd_tb.sv`: Matrix addition test bench

- **`docs/`**: Documentation files
  - This guide and other documentation

- **`Makefile`**: Build scripts for compiling and simulating

### 3. Compiling and Running Your First Test

To compile the project:
```bash
make compile
```

To run the matrix addition test:
```bash
make test_matadd
```

To view the simulation waveforms:
```bash
make wave
```

## Understanding GPU Architecture

### What is a GPU?

A Graphics Processing Unit (GPU) is a specialized processor designed to handle parallel computations efficiently. Unlike CPUs that excel at sequential tasks, GPUs are optimized for simultaneously processing many similar operations on different data (SIMD - Same Instruction, Multiple Data).

### This GPU's Architecture

Our GPU implementation follows a simplified but complete architecture:

1. **Thread-Based Parallelism**: The GPU organizes work into threads and blocks
   - Each thread processes one piece of data
   - Multiple threads form a block
   - Multiple blocks form a grid

2. **Hierarchical Structure**:
   - **GPU**: The top-level module containing multiple cores
   - **Core**: Processes one block of threads at a time
   - **Thread**: The smallest execution unit with its own ALU, registers, etc.

3. **Memory Model**:
   - **Program Memory**: Stores the kernel instructions
   - **Data Memory**: Stores the data being processed

4. **Execution Pipeline**:
   - FETCH: Get the next instruction
   - DECODE: Parse the instruction into control signals
   - REQUEST: Issue memory operations if needed
   - WAIT: Wait for memory operations to complete
   - EXECUTE: Perform the actual computation
   - UPDATE: Write results back to registers

### Key Components Explained

#### 1. ALU (Arithmetic Logic Unit)
The ALU performs arithmetic operations (ADD, SUB, MUL, DIV) and comparisons.

#### 2. Load-Store Unit (LSU)
The LSU handles memory operations, reading and writing data.

#### 3. Register File
Each thread has its own set of registers:
- General-purpose registers (R0-R12)
- Special registers (R13-R15) for thread/block information

#### 4. Program Counter (PC)
Tracks the execution flow and handles branching.

#### 5. Instruction Fetcher
Retrieves instructions from program memory.

#### 6. Instruction Decoder
Converts raw instruction bits into control signals.

#### 7. Scheduler
Manages the execution state of the core and synchronizes threads.

#### 8. Memory Controller
Arbitrates memory access between multiple threads.

## SystemVerilog Basics

SystemVerilog is a hardware description and verification language that extends Verilog. Here are some key concepts used in our GPU implementation:

### Modules

Modules are the basic building blocks in SystemVerilog, similar to classes in object-oriented programming:

```systemverilog
module module_name #(
    parameter PARAM1 = default_value
) (
    input  logic signal1,
    output logic signal2
);
    // Module implementation
endmodule
```

### Data Types

- **`logic`**: Used for digital signals (similar to `wire` but more flexible)
- **`enum`**: Defines a set of named values (e.g., states in a state machine)
- **`struct`**: Groups related signals together
- **`typedef`**: Creates custom type definitions

### Packages

Packages contain shared definitions used across multiple modules:

```systemverilog
package gpu_pkg;
    typedef enum logic [2:0] {
        IDLE    = 3'b000,
        FETCH   = 3'b001
        // ...
    } core_state_t;
    // More definitions...
endpackage
```

### Always Blocks

- **`always_ff`**: For sequential logic (registers)
- **`always_comb`**: For combinational logic

### Parameters

Parameters allow for configurable designs:

```systemverilog
module memory #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 8
) (
    // Ports...
);
```

## How to Run Your First Simulation

### Step 1: Understand the Test Bench

A test bench is a SystemVerilog file that instantiates your design and provides inputs to test it. The `matadd_tb.sv` file tests matrix addition:

```systemverilog
// Simplified example
module matadd_tb;
    // Declare signals
    logic clk, rst_n, start, done;
    
    // Instantiate the GPU
    gpu gpu_inst(...);
    
    // Generate clock
    always #5 clk = ~clk;
    
    // Test sequence
    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        #10 rst_n = 1;
        
        // Start execution
        start = 1;
        #10 start = 0;
        
        // Wait for completion
        wait(done);
        $display("Matrix addition completed!");
        // ...
    end
endmodule
```

### Step 2: Run the Simulation

Run the matrix addition test:

```bash
make test_matadd
```

This compiles your design and the test bench, then runs the simulation.

### Step 3: View the Waveforms

To understand what's happening inside your design:

```bash
make wave
```

This opens GTKWave with the simulation results. Key signals to look for:
- `clk`: The system clock
- `core_state`: Current execution state
- `instruction`: Current instruction being executed
- Memory read/write signals
- Register values

## Walkthrough: Matrix Addition Kernel

Let's walk through how matrix addition is implemented in our GPU:

### The Kernel Code

The matrix addition kernel adds two arrays element by element:

```
// Pseudocode
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

### How It Works

1. **Thread Index Calculation**:
   - Each thread calculates its global index `i` based on its thread ID and block ID
   
2. **Memory Address Calculation**:
   - The kernel calculates the memory addresses for the input and output data
   
3. **Data Loading**:
   - Each thread loads its element from matrices A and B
   
4. **Computation**:
   - Each thread adds its elements
   
5. **Result Storage**:
   - Each thread stores its result to matrix C

### Parallel Execution

The key to GPU performance is that all threads execute the same instruction, but on different data:
- Thread 0 processes element 0
- Thread 1 processes element 1
- And so on...

All threads run in parallel, significantly speeding up the computation compared to a sequential CPU implementation.

## FAQ

### Q: How does this GPU compare to commercial GPUs?

A: This is a greatly simplified GPU for educational purposes. Commercial GPUs have:
- Thousands of cores (vs. our 2-4)
- Complex memory hierarchies (L1/L2 caches, shared memory, etc.)
- Advanced scheduling algorithms
- Hardware-accelerated functions for graphics
- Branch divergence handling
- Memory coalescing and other optimizations

### Q: Why SystemVerilog?

A: SystemVerilog is an industry-standard hardware description language that allows us to describe hardware at different levels of abstraction, from low-level gates to high-level behavioral models.

### Q: How can I modify the GPU design?

A: Start by understanding the existing code and the architecture. Then, you can:
- Change parameters (e.g., increase the number of cores)
- Add new instructions to the ISA
- Modify the memory system
- Implement new features like caching

### Q: What are some good next steps after understanding this project?

A: You could:
1. Implement a more complex kernel (e.g., matrix multiplication)
2. Add a cache implementation
3. Implement branch divergence handling
4. Add more advanced scheduling
5. Try to synthesize the design for an FPGA
6. Extend the instruction set with new operations

### Q: I'm having trouble understanding a specific part. Where can I get help?

A: Check the detailed module-by-module documentation in this repository. Each file in the `src/` directory has a corresponding detailed explanation in the `docs/modules/` directory.

## Next Steps

Now that you have a basic understanding of the GPU architecture, you can:

1. Continue to the [Module-by-Module Walkthrough](modules/README.md) for detailed explanations of each component
2. Look at the [Implementation Guide](implementation_guide.md) for a comprehensive understanding of how everything fits together
3. Try the hands-on exercises to test your understanding 