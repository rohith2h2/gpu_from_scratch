# Module-by-Module Documentation

This directory contains detailed documentation for each module in the GPU implementation. Each file provides a thorough explanation of the module's purpose, functionality, and implementation details.

## Core Modules

1. [ALU (Arithmetic Logic Unit)](alu.md)
   - Performs arithmetic and logical operations
   - Handles comparison operations

2. [Program Counter (PC)](pc.md)
   - Manages program execution flow
   - Controls branching based on conditions

3. [Load-Store Unit (LSU)](lsu.md)
   - Handles memory operations
   - Manages asynchronous memory requests

4. [Register File](registers.md)
   - Stores data for each thread
   - Manages special-purpose registers

## Control Modules

5. [Instruction Fetcher](fetcher.md)
   - Retrieves instructions from program memory
   - Handles instruction caching

6. [Instruction Decoder](decoder.md)
   - Parses instruction opcodes
   - Generates control signals

7. [Scheduler](scheduler.md)
   - Controls execution state transitions
   - Synchronizes thread execution

## Memory Modules

8. [Memory Controller](controller.md)
   - Arbitrates memory access
   - Handles multiple concurrent requests

9. [Memory Model](memory_model.md)
   - Simulates external memory behavior
   - Implements memory access latency

## Integration Modules

10. [Core](core.md)
    - Integrates thread processing units
    - Manages block execution

11. [Device Control Register (DCR)](dcr.md)
    - Stores kernel execution metadata
    - Controls GPU initialization

12. [Dispatcher](dispatch.md)
    - Distributes work across cores
    - Tracks kernel completion

13. [GPU (Top Level)](gpu.md)
    - Integrates all components
    - Provides external interface

## Common Definitions

14. [GPU Package](gpu_pkg.md)
    - Defines common types and constants
    - Centralizes shared definitions

## Reading Guide

If you're new to the project, we recommend reading the modules in this order:

1. Start with [GPU Package](gpu_pkg.md) to understand common definitions
2. Read the basic processing units: [ALU](alu.md), [PC](pc.md), [LSU](lsu.md), [Register File](registers.md)
3. Continue with control flow modules: [Fetcher](fetcher.md), [Decoder](decoder.md), [Scheduler](scheduler.md)
4. Learn about memory management: [Memory Controller](controller.md), [Memory Model](memory_model.md)
5. Understand integration: [Core](core.md), [DCR](dcr.md), [Dispatcher](dispatch.md), [GPU](gpu.md)

Each module documentation follows a consistent structure:
- Purpose and functionality
- Interface description (parameters, inputs, outputs)
- Internal architecture
- State machines and control logic (if applicable)
- Line-by-line code explanation
- Examples of usage
- Common pitfalls and debugging tips 