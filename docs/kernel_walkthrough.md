# GPU Kernel Development Walkthrough

This guide provides a step-by-step walkthrough of developing and running a new kernel on our GPU implementation. We'll cover the entire process from designing the algorithm to analyzing the results.

## Table of Contents
1. [Understanding the GPU Programming Model](#understanding-the-gpu-programming-model)
2. [Designing Your Kernel Algorithm](#designing-your-kernel-algorithm)
3. [Writing the Kernel Code](#writing-the-kernel-code)
4. [Setting Up the Test Environment](#setting-up-the-test-environment)
5. [Running and Debugging the Kernel](#running-and-debugging-the-kernel)
6. [Optimizing Kernel Performance](#optimizing-kernel-performance)
7. [Case Study: Matrix Multiplication Kernel](#case-study-matrix-multiplication-kernel)

## Understanding the GPU Programming Model

Before writing a kernel, it's essential to understand the GPU's programming model:

### Thread Hierarchy
- **Threads**: Individual execution units that run the same code on different data
- **Blocks**: Groups of threads that execute together on a single core
- **Grid**: Collection of blocks that make up the entire computation

### Memory Model
- **Data Memory**: Global memory accessible by all threads
- **Register File**: Thread-local storage for fast access

### Execution Model
- **SIMD (Same Instruction, Multiple Data)**: All threads in a block execute the same instruction at the same time
- **No Branch Divergence**: All threads must follow the same execution path

### Special Registers
- **%blockIdx (R13)**: Block ID
- **%blockDim (R14)**: Number of threads per block
- **%threadIdx (R15)**: Thread ID within the block

## Designing Your Kernel Algorithm

1. **Identify Parallel Components**:
   - Break down the problem into elements that can be processed independently
   - Determine how many threads you'll need

2. **Map Thread IDs to Data Elements**:
   - Create a mapping from thread IDs to data indices
   - For typical data-parallel operations: `global_idx = blockIdx * blockDim + threadIdx`

3. **Define Memory Access Patterns**:
   - Determine which memory locations each thread will read from and write to
   - Identify any potential memory conflicts

4. **Outline the Computational Steps**:
   - Break down the algorithm into discrete operations
   - Consider how these operations map to the GPU's instruction set

## Writing the Kernel Code

Our GPU uses a simple assembly-like language. Here's the process for writing a kernel:

### 1. Calculate Thread Index

First, calculate the global index for each thread:

```
MUL R0, %blockIdx, %blockDim     ; R0 = blockIdx * blockDim
ADD R0, R0, %threadIdx           ; R0 = blockIdx * blockDim + threadIdx
```

### 2. Define Memory Address Constants

Set up base addresses for your data:

```
CONST R1, #0                     ; Base address for input data 1
CONST R2, #64                    ; Base address for input data 2
CONST R3, #128                   ; Base address for output data
```

### 3. Calculate Memory Addresses

Compute specific addresses for each thread:

```
ADD R4, R1, R0                   ; Address of input1[thread_idx]
ADD R5, R2, R0                   ; Address of input2[thread_idx]
ADD R6, R3, R0                   ; Address of output[thread_idx]
```

### 4. Load Input Data

Retrieve input data from memory:

```
LDR R7, R4                       ; Load input1[thread_idx] into R7
LDR R8, R5                       ; Load input2[thread_idx] into R8
```

### 5. Perform Computation

Execute the core computation of your kernel:

```
ADD R9, R7, R8                   ; Example: R9 = input1[i] + input2[i]
```

### 6. Store Results

Write the results back to memory:

```
STR R6, R9                       ; Store result to output[thread_idx]
```

### 7. End Kernel Execution

Always end your kernel with a return instruction:

```
RET                              ; End kernel execution
```

### Complete Example: Vector Addition Kernel

```
; Vector Addition Kernel
; C[i] = A[i] + B[i]

MUL R0, %blockIdx, %blockDim     ; Calculate base offset
ADD R0, R0, %threadIdx           ; Add thread index
CONST R1, #0                     ; Base address of array A
CONST R2, #64                    ; Base address of array B
CONST R3, #128                   ; Base address of array C
ADD R4, R1, R0                   ; Address of A[i]
LDR R4, R4                       ; Load A[i] into R4
ADD R5, R2, R0                   ; Address of B[i]
LDR R5, R5                       ; Load B[i] into R5
ADD R6, R4, R5                   ; Compute A[i] + B[i]
ADD R7, R3, R0                   ; Address of C[i]
STR R7, R6                       ; Store result to C[i]
RET                              ; End kernel execution
```

## Setting Up the Test Environment

To run your kernel, you need to:

### 1. Create a Test Bench

Create a new test bench file in `test/my_kernel_tb.sv`. This file will:
- Initialize memory with test data
- Configure the GPU with the appropriate parameters
- Start kernel execution
- Verify the results

Here's a skeleton test bench:

```systemverilog
`default_nettype none
`timescale 1ns/1ns

module my_kernel_tb;
    // Parameters
    localparam CLK_PERIOD = 10;
    localparam NUM_THREADS = 8;
    
    // Signals
    logic clk;
    logic reset;
    logic start;
    logic done;
    
    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // GPU instance
    gpu gpu_inst (
        .clk(clk),
        .reset(reset),
        .start(start),
        .thread_count(NUM_THREADS),
        .done(done)
    );
    
    // Memory initialization
    initial begin
        // Initialize input data in data memory
        gpu_inst.data_mem.memory[0] = 8'd1;  // A[0] = 1
        gpu_inst.data_mem.memory[1] = 8'd2;  // A[1] = 2
        // ... more initialization
        
        // Initialize program memory with kernel instructions
        gpu_inst.program_mem.memory[0] = 16'h0000;  // Instruction 0
        gpu_inst.program_mem.memory[1] = 16'h0000;  // Instruction 1
        // ... more instructions
    end
    
    // Test sequence
    initial begin
        // Initialize
        clk = 0;
        reset = 1;
        start = 0;
        
        // Reset system
        #20 reset = 0;
        
        // Start kernel
        #10 start = 1;
        #10 start = 0;
        
        // Wait for completion
        wait(done);
        
        // Verify results
        if (gpu_inst.data_mem.memory[128] == 8'd3) // C[0] = A[0] + B[0] = 1 + 2 = 3
            $display("Test PASSED: C[0] = %d", gpu_inst.data_mem.memory[128]);
        else
            $display("Test FAILED: C[0] = %d, expected 3", gpu_inst.data_mem.memory[128]);
        
        // End simulation
        #100 $finish;
    end
    
    // Optional: Generate waveform dump
    initial begin
        $dumpfile("my_kernel.vcd");
        $dumpvars(0, my_kernel_tb);
    end
    
endmodule
```

### 2. Encode Kernel Instructions

To manually encode instructions:

1. Use the opcode definitions from `gpu_pkg.sv`:
   - ADD = 4'b0011
   - SUB = 4'b0100
   - MUL = 4'b0101
   - etc.

2. Construct 16-bit instructions:
   - [15:12] = opcode
   - [11:8] = destination register (Rd)
   - [7:4] = source register 1 (Rs)
   - [3:0] = source register 2 (Rt)

Example:
- `ADD R6, R4, R5` becomes:
  - opcode = 4'b0011 (ADD)
  - Rd = 4'b0110 (R6)
  - Rs = 4'b0100 (R4)
  - Rt = 4'b0101 (R5)
  - Instruction = 16'b0011_0110_0100_0101 = 16'h3645

3. Fill the program memory with these encoded instructions

### 3. Update Makefile

Add your test to the Makefile:

```makefile
test_my_kernel:
	@$(MAKE) test TOPLEVEL=my_kernel_tb
```

## Running and Debugging the Kernel

### 1. Compile and Run

```bash
make test_my_kernel
```

### 2. Analyze Waveforms

```bash
make wave
```

In GTKWave, focus on these signals for debugging:
- `core_state`: Track the execution state
- `instruction`: See which instruction is being executed
- `registers`: Monitor register values
- `memory`: Check memory read/write operations

### 3. Common Issues and Solutions

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| Kernel doesn't start | Incorrect start signal | Check the timing of the start signal |
| Incorrect results | Wrong memory addressing | Verify address calculations |
| Simulation hangs | Infinite loop or missing RET | Ensure proper branching and RET instruction |
| Memory corruption | Out-of-bounds access | Verify address calculations and bounds |
| RET instruction not working | Wrong opcode | Check RET encoding (4'b1111) |

## Optimizing Kernel Performance

While our GPU is simplified, you can still optimize your kernels:

### 1. Minimize Memory Access

- Reuse data in registers when possible
- Group related memory operations together

### 2. Efficient Register Usage

- Plan register allocation to minimize usage
- R0-R12 are general-purpose registers

### 3. Loop Unrolling

- If processing multiple elements per thread, unroll loops to reduce branching

### 4. Coalesced Memory Access

- Design memory access patterns to be sequential

## Case Study: Matrix Multiplication Kernel

Let's walk through the development of a matrix multiplication kernel.

### Problem Definition:
- Multiply two 4×4 matrices: C = A × B

### Algorithm Design:
1. Each thread computes one element of the output matrix
2. Thread (i,j) computes C[i,j] = sum(A[i,k] * B[k,j]) for all k

### Thread Index Calculation:
- For a 4×4 output, we need 16 threads (4 rows × 4 columns)
- Map thread ID to matrix coordinates: 
  - row = thread_idx / 4
  - col = thread_idx % 4

### Kernel Pseudocode:
```
// Calculate thread index
global_idx = blockIdx * blockDim + threadIdx
row = global_idx / 4
col = global_idx % 4

// Initialize sum
sum = 0

// Perform dot product
for (k = 0; k < 4; k++) {
    a_idx = row * 4 + k
    b_idx = k * 4 + col
    sum += A[a_idx] * B[b_idx]
}

// Store result
C[row * 4 + col] = sum
```

### Encoded Kernel Instructions:

```
; Matrix Multiplication Kernel
; Thread with ID t computes C[t/4][t%4]

; Calculate global thread index
MUL R0, %blockIdx, %blockDim   ; R0 = blockIdx * blockDim
ADD R0, R0, %threadIdx         ; R0 = global thread index

; Calculate row and column
CONST R1, #4                   ; Matrix width
DIV R2, R0, R1                 ; R2 = row = thread_idx / 4
MUL R3, R2, R1                 ; R3 = row * 4
SUB R4, R0, R3                 ; R4 = col = thread_idx % 4

; Initialize base addresses and sum
CONST R5, #0                   ; R5 = base address of A
CONST R6, #16                  ; R6 = base address of B
CONST R7, #32                  ; R7 = base address of C
CONST R8, #0                   ; R8 = sum = 0
CONST R9, #0                   ; R9 = loop counter k

; Loop start
; Calculate A[row][k] address
MUL R10, R2, R1                ; R10 = row * 4
ADD R10, R10, R9               ; R10 = row * 4 + k
ADD R10, R10, R5               ; R10 = base_A + row * 4 + k
LDR R11, R10                   ; R11 = A[row][k]

; Calculate B[k][col] address
MUL R12, R9, R1                ; R12 = k * 4
ADD R12, R12, R4               ; R12 = k * 4 + col
ADD R12, R12, R6               ; R12 = base_B + k * 4 + col
LDR R12, R12                   ; R12 = B[k][col]

; Multiply and accumulate
MUL R11, R11, R12              ; R11 = A[row][k] * B[k][col]
ADD R8, R8, R11                ; R8 = sum + A[row][k] * B[k][col]

; Increment loop counter
ADD R9, R9, #1                 ; k++
CMP R9, R1                     ; Compare k with 4
BRp #26                        ; If k < 4, jump back to loop start

; Calculate output address and store result
MUL R10, R2, R1                ; R10 = row * 4
ADD R10, R10, R4               ; R10 = row * 4 + col
ADD R10, R10, R7               ; R10 = base_C + row * 4 + col
STR R10, R8                    ; C[row][col] = sum

RET                            ; End kernel
```

This kernel demonstrates:
1. Thread indexing for 2D matrices
2. Iterative computation using loops
3. Proper memory addressing
4. Accumulation of results

### Testing the Kernel:

Set up the test bench with test matrices:
```systemverilog
// Initialize matrix A
gpu_inst.data_mem.memory[0] = 8'd1;  // A[0][0]
gpu_inst.data_mem.memory[1] = 8'd2;  // A[0][1]
// ...

// Initialize matrix B
gpu_inst.data_mem.memory[16] = 8'd5;  // B[0][0]
gpu_inst.data_mem.memory[17] = 8'd6;  // B[0][1]
// ...
```

Verify the results:
```systemverilog
// Check one element of the output matrix
if (gpu_inst.data_mem.memory[32] == expected_value)
    $display("Test PASSED: C[0][0] = %d", gpu_inst.data_mem.memory[32]);
else
    $display("Test FAILED: C[0][0] = %d, expected %d", 
             gpu_inst.data_mem.memory[32], expected_value);
```

## Conclusion

Developing kernels for our GPU implementation involves:
1. Understanding the thread and memory model
2. Designing your algorithm for parallel execution
3. Encoding instructions for the GPU architecture
4. Setting up a test environment
5. Running and debugging the kernel

While this GPU is simplified compared to commercial GPUs, it demonstrates the core principles of GPU programming and parallel computation. The skills learned here can be transferred to programming real GPUs using languages like CUDA or OpenCL. 