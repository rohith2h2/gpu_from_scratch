# GPU Architecture Guide

This document provides a detailed explanation of the GPU architecture implemented in this project. It includes visual representations of how the different components fit together and how data flows through the system.

## Overall System Architecture

The GPU is structured as a hierarchical system with the following levels:

```
                               +-------------------+
                               |       GPU         |
                               +-------------------+
                               |                   |
                      +--------+  Dispatcher       +--------+
                      |        |                   |        |
                      |        +-------------------+        |
                      |                                     |
           +----------v-----------+           +-----------v-----------+
           |        Core 0        |           |        Core 1        |
           +----------------------+           +----------------------+
           |                      |           |                      |
     +-----+  Thread 0  Thread 1  +-----+     +-----+  Thread 0  Thread 1  +-----+
     |     |  Thread 2  Thread 3  |     |     |     |  Thread 2  Thread 3  |     |
     |     +----------------------+     |     |     +----------------------+     |
     |                                  |     |                                  |
+----v-----+                      +-----v----++----v-----+                      +-----v----+
|  Memory  |                      |  Memory  ||  Memory  |                      |  Memory  |
|Controller|                      |Controller||Controller|                      |Controller|
+---------++                      +----------++---------++                      +----------+
          |                                             |
          |                                             |
          v                                             v
    +----------+                                  +----------+
    | Program  |                                  |  Data    |
    | Memory   |                                  |  Memory  |
    +----------+                                  +----------+
```

### Key Components

1. **GPU**: The top-level module that integrates all components
2. **Dispatcher**: Distributes work (blocks of threads) to available cores
3. **Cores**: Process blocks of threads, each core handling one block at a time
4. **Threads**: The smallest execution units, each with dedicated processing elements
5. **Memory Controllers**: Manage access to program and data memory
6. **Memories**: Store program instructions and data

## Thread Execution Model

Threads are organized into blocks, and blocks are scheduled to cores:

```
                   +----------------+
                   |      Grid      |
                   +----------------+
                   |                |
           +-------+  Block 0       +-------+
           |       |  Block 1       |       |
           |       |  Block 2       |       |
           |       +----------------+       |
           |                                |
           v                                v
   +---------------+                +---------------+
   |    Block 0    |                |    Block 1    |
   +---------------+                +---------------+
   | Thread 0      |                | Thread 0      |
   | Thread 1      |                | Thread 1      |
   | Thread 2      |                | Thread 2      |
   | Thread 3      |                | Thread 3      |
   +-------+-------+                +-------+-------+
           |                                |
           v                                v
      Scheduled to                     Scheduled to
         Core 0                           Core 1
```

Each thread processes one element of data, and threads within a block execute the same instruction on different data (SIMD model).

## Core Architecture

A single core contains multiple thread processing units and shared control logic:

```
+------------------------------------------+
|                  CORE                    |
+------------------------------------------+
|                                          |
|   +-------------+      +-------------+   |
|   |  Scheduler  |<---->|   Fetcher   |   |
|   +-------------+      +------+------+   |
|         ^                     |          |
|         |                     v          |
|   +-----+-------+      +------+------+   |
|   |    Core     |      |   Decoder   |   |
|   | State Machine|     +------+------+   |
|   +-------------+             |          |
|                               v          |
|   +------+------+      +------+------+   |
|   | Thread Unit 0|      | Thread Unit 1|  |
|   +-------------+      +-------------+   |
|   | ALU | LSU   |      | ALU | LSU   |   |
|   | PC  | Regs  |      | PC  | Regs  |   |
|   +-------------+      +-------------+   |
|                                          |
|   +-------------+      +-------------+   |
|   | Thread Unit 2|      | Thread Unit 3|  |
|   +-------------+      +-------------+   |
|   | ALU | LSU   |      | ALU | LSU   |   |
|   | PC  | Regs  |      | PC  | Regs  |   |
|   +-------------+      +-------------+   |
|                                          |
+------------------------------------------+
```

### Core Components:

1. **Scheduler**: Controls the execution flow of the core through different states
2. **Fetcher**: Retrieves instructions from program memory
3. **Decoder**: Translates instructions into control signals
4. **Thread Units**: Each thread has its own:
   - **ALU**: Performs arithmetic and comparison operations
   - **LSU**: Handles memory operations
   - **PC**: Tracks program execution flow
   - **Registers**: Stores thread-local data

## Thread Processing Unit

A thread processing unit contains the components needed for a single thread's execution:

```
+------------------------------------------+
|           THREAD PROCESSING UNIT         |
+------------------------------------------+
|                                          |
|   +-------------+      +-------------+   |
|   |  Register   |----->|     ALU     |   |
|   |    File     |      |             |   |
|   +---+---------+      +------+------+   |
|       |                       |          |
|       |                       v          |
|       |                +------+------+   |
|       |                |  Register   |   |
|       |                |   Write     |   |
|       |                +-------------+   |
|       v                                  |
|   +---+---------+      +-------------+   |
|   |    LSU      |----->|   Memory    |   |
|   | (Load-Store)|      |  Controller |   |
|   +-------------+      +-------------+   |
|                                          |
|   +-------------+                        |
|   |  Program    |                        |
|   |  Counter    |                        |
|   +-------------+                        |
|                                          |
+------------------------------------------+
```

## Execution Pipeline

The core goes through multiple states to execute each instruction:

```
+----------+     +----------+     +----------+
|  FETCH   |---->|  DECODE  |---->| REQUEST  |
+----------+     +----------+     +----------+
                                       |
+----------+     +----------+     +----------+
|  UPDATE  |<----|  EXECUTE |<----|   WAIT   |
+----------+     +----------+     +----------+
     |
     v
  Next instruction
```

1. **FETCH**: Get the next instruction from program memory
2. **DECODE**: Convert the instruction into control signals
3. **REQUEST**: Initiate memory operations if needed
4. **WAIT**: Wait for memory operations to complete (skipped if no memory op)
5. **EXECUTE**: Perform ALU operations
6. **UPDATE**: Write results back to registers and update PC

## Memory System

The memory system includes multiple controllers that arbitrate access to shared memory:

```
+----------------------------------------------------------+
|                     MEMORY SYSTEM                        |
+----------------------------------------------------------+
|                                                          |
|  +---------------+   +---------------+   +-------------+ |
|  | Core 0 Thread 0|   | Core 0 Thread 1|   |    ...     | |
|  +-------+-------+   +-------+-------+   +------+------+ |
|          |                   |                  |        |
|          v                   v                  v        |
|  +-------+-------------------+------------------+------+ |
|  |                 MEMORY CONTROLLER                   | |
|  +--------------------------------------------------------+
|  |                                                      | |
|  |  +--------------+  +--------------+  +--------------+ | |
|  |  | Request Queue |  | Request Queue |  | Request Queue | | |
|  |  +--------------+  +--------------+  +--------------+ | |
|  |                                                      | |
|  |  +--------------+  +--------------+  +--------------+ | |
|  |  |   Channel 0   |  |   Channel 1   |  |   Channel 2   | | |
|  |  +--------------+  +--------------+  +--------------+ | |
|  |         |                 |                 |        | |
|  +---------+-----------------+-----------------+--------+ |
|            |                 |                 |          |
|            v                 v                 v          |
|  +-----------------------+                                |
|  |        MEMORY         |                                |
|  +-----------------------+                                |
|                                                          |
+----------------------------------------------------------+
```

1. **Memory Controllers**: Arbitrate between multiple threads' memory requests
2. **Request Queues**: Buffer memory requests waiting to be serviced
3. **Channels**: Independent paths to memory for parallel access
4. **Memory**: The actual storage for data or program instructions

## Instruction Set Architecture (ISA)

Our GPU implements a 16-bit instruction set with 11 instructions:

```
+-------------------------------+
| Instruction Format (16 bits)  |
+-------+-------+-------+-------+
| 15-12 | 11-8  |  7-4  |  3-0  |
+-------+-------+-------+-------+
|Opcode |  Rd   |  Rs   |  Rt   |
+-------+-------+-------+-------+
```

For some instructions, the format varies:
- **CONST**: Immediate value in bits [7:0]
- **BRnzp**: Branch condition in bits [10:8], target in bits [7:0]

### Supported Instructions:

1. **Arithmetic**:
   - ADD Rd, Rs, Rt: Rd = Rs + Rt
   - SUB Rd, Rs, Rt: Rd = Rs - Rt
   - MUL Rd, Rs, Rt: Rd = Rs * Rt
   - DIV Rd, Rs, Rt: Rd = Rs / Rt

2. **Memory**:
   - LDR Rd, Rs: Load from memory address Rs into Rd
   - STR Rs, Rt: Store Rt to memory address Rs

3. **Control**:
   - CMP Rs, Rt: Compare Rs and Rt, set NZP flags
   - BRnzp #immediate: Branch to immediate address if condition matches

4. **Other**:
   - CONST Rd, #immediate: Load immediate value into Rd
   - RET: End thread execution

## Register File

Each thread has 16 registers, including special purpose registers:

```
+------------------------+
|     REGISTER FILE      |
+------+----------------+
| Addr |    Purpose     |
+------+----------------+
| R0   | General purpose|
| ...  | General purpose|
| R12  | General purpose|
| R13  | Block ID       |
| R14  | Block Dim      |
| R15  | Thread ID      |
+------+----------------+
```

The special registers (R13-R15) contain thread metadata:
- **R13** (%blockIdx): The ID of the block being processed
- **R14** (%blockDim): The number of threads per block
- **R15** (%threadIdx): The thread's ID within its block

## Data Flow Example: Matrix Addition

Let's trace the execution of a matrix addition kernel:

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

### Data Flow Through the System:

1. **Thread Index Calculation**:
   - Each thread calculates its unique index based on block ID and thread ID
   - Threads process different elements in parallel

2. **Memory Access**:
   - Each thread computes memory addresses
   - LSUs send memory read requests to memory controller
   - Memory controller arbitrates access and returns data

3. **Computation**:
   - ALUs perform addition on the loaded data
   - Results are stored in registers

4. **Result Storage**:
   - Each thread computes the destination address
   - LSUs send memory write requests to memory controller
   - Memory controller writes results to data memory

## Parallel Execution Example

With two cores each running four threads, here's how matrix addition executes in parallel:

```
Core 0 (Block 0):
  Thread 0: Process element 0
  Thread 1: Process element 1
  Thread 2: Process element 2
  Thread 3: Process element 3

Core 1 (Block 1):
  Thread 0: Process element 4
  Thread 1: Process element 5
  Thread 2: Process element 6
  Thread 3: Process element 7
```

All threads run the same kernel code, but on different data elements. The special registers (%blockIdx, %blockDim, %threadIdx) help each thread determine which data element to process.

## Limitations and Future Improvements

1. **No Branch Divergence**:
   - All threads in a block must follow the same execution path
   - Could be improved by adding a thread mask and PC per thread

2. **Limited Memory Hierarchy**:
   - No caches or shared memory
   - Could add L1/L2 caches and shared memory per core

3. **Simple Scheduling**:
   - Basic round-robin scheduling of blocks to cores
   - Could implement more sophisticated scheduling algorithms

4. **Fixed Parameters**:
   - Fixed number of threads per block
   - Could make more parameters configurable at runtime

## Reference Diagrams

For more detailed diagrams and visual explanations, refer to:
1. [Module Connections Diagram](images/module_connections.png)
2. [Memory Hierarchy Diagram](images/memory_hierarchy.png)
3. [Execution Pipeline Diagram](images/execution_pipeline.png)

These diagrams will be added in a future update to enhance the documentation. 