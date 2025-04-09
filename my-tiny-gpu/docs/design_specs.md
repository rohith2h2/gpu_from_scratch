# Tiny GPU Design Specifications

## Memory Interface
- **Program Memory**: 
  - 8-bit addressing (256 instructions max)
  - 16-bit data width (instruction size)
  - Single read channel

- **Data Memory**:
  - 8-bit addressing (256 data elements)
  - 8-bit data width
  - Multiple read/write channels (4 by default)

## Core Parameters
- Configurable number of cores (default: 2)
- Each core processes one block at a time
- Each block contains configurable number of threads (default: 4)
- Each thread has dedicated ALU, LSU, PC unit, and registers

## Instruction Set Architecture (ISA)
- 16-bit instructions
- 11 basic instructions:
  - `ADD`, `SUB`, `MUL`, `DIV`: Arithmetic operations
  - `LDR`, `STR`: Memory operations
  - `CMP`: Comparison setting NZP register
  - `BRnzp`: Conditional branching
  - `CONST`: Load constant
  - `RET`: End thread execution

## Register File
- 16 registers per thread (4-bit addressing)
- Registers R0-R12: General purpose
- Registers R13-R15: Special purpose (block ID, block dimensions, thread ID)

## Control Flow
1. `FETCH`: Get instruction from program memory
2. `DECODE`: Convert instruction to control signals
3. `REQUEST`: Initiate memory requests if needed
4. `WAIT`: Wait for memory operations to complete
5. `EXECUTE`: Perform ALU operations
6. `UPDATE`: Update registers and program counter

## Execution Model
- SIMD (Same Instruction Multiple Data)
- All threads in a block execute the same instruction
- No branch divergence (simplification)
- Synchronous execution of threads 