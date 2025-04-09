# Program Counter (PC) Documentation

## Overview

The Program Counter (PC) is a critical component in the GPU pipeline that manages the execution flow by tracking the current instruction address for each thread. It maintains the address of the next instruction to be fetched for execution, allowing for both sequential progression and control flow changes through branch instructions.

## Key Features

- Maintains separate program counters for multiple threads in a SIMD/SIMT architecture
- Supports sequential instruction execution with automatic increment
- Handles jump and branch operations for program flow control
- Manages control flow divergence between threads
- Provides synchronization capabilities for thread convergence
- Configurable for different address widths and thread counts

## Interface

```systemverilog
module program_counter #(
    parameter ADDR_WIDTH = 32,
    parameter MAX_THREADS = 32
) (
    input  logic                        clk,
    input  logic                        reset,
    
    // Thread control
    input  logic [MAX_THREADS-1:0]      thread_mask,
    input  logic [$clog2(MAX_THREADS)-1:0] active_thread_id,
    
    // Control signals
    input  logic                        pc_write_en,
    input  logic                        pc_branch_en,
    input  logic [ADDR_WIDTH-1:0]       pc_branch_addr,
    
    // Current PC output
    output logic [ADDR_WIDTH-1:0]       current_pc,
    output logic [ADDR_WIDTH-1:0]       next_pc,
    
    // Thread state
    output logic [MAX_THREADS-1:0]      active_threads,
    output logic                        thread_active
);
```

## Parameters

| Parameter   | Default | Description                                |
|-------------|--------|--------------------------------------------|
| ADDR_WIDTH  | 32     | Width of the program counter address in bits |
| MAX_THREADS | 32     | Maximum number of threads supported         |

## Inputs and Outputs

| Port            | Direction | Width                 | Description                                 |
|-----------------|-----------|----------------------|---------------------------------------------|
| clk             | input     | 1                    | System clock signal                         |
| reset           | input     | 1                    | Active high reset signal                    |
| thread_mask     | input     | MAX_THREADS          | Bit mask indicating active threads          |
| active_thread_id| input     | $clog2(MAX_THREADS)  | ID of the currently active thread           |
| pc_write_en     | input     | 1                    | Enable signal for writing to PC             |
| pc_branch_en    | input     | 1                    | Enable signal for branch operations         |
| pc_branch_addr  | input     | ADDR_WIDTH           | Target address for branch operations        |
| current_pc      | output    | ADDR_WIDTH           | Current PC value for active thread          |
| next_pc         | output    | ADDR_WIDTH           | Next PC value (current_pc + 4) for active thread |
| active_threads  | output    | MAX_THREADS          | Bit mask of threads that are currently active |
| thread_active   | output    | 1                    | Indicates if the current thread is active   |

## Implementation Details

### PC Storage

The PC values for all threads are stored in a register array:

```systemverilog
// PC storage for each thread
logic [ADDR_WIDTH-1:0] pc_reg [MAX_THREADS-1:0];
```

### PC Update Logic

The PC is updated on each clock cycle based on control signals:

```systemverilog
// PC update logic
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        // Reset all PCs to the start address
        for (int i = 0; i < MAX_THREADS; i++) begin
            pc_reg[i] <= START_ADDR;
        end
        active_threads <= '0;
    end else begin
        // Update active threads based on thread mask
        active_threads <= thread_mask;
        
        // Only update PC for the active thread
        if (thread_active && pc_write_en) begin
            if (pc_branch_en) begin
                // Branch operation - set PC to branch target
                pc_reg[active_thread_id] <= pc_branch_addr;
            end else begin
                // Sequential execution - increment PC
                pc_reg[active_thread_id] <= pc_reg[active_thread_id] + 4;
            end
        end
    end
end
```

### Thread Activity Logic

Thread activity is determined by the thread mask:

```systemverilog
// Determine if the current thread is active
assign thread_active = thread_mask[active_thread_id];

// Output the current PC for the active thread
assign current_pc = pc_reg[active_thread_id];
assign next_pc = current_pc + 4;
```

## PC Operation Modes

The PC operates in several modes depending on the control signals:

1. **Sequential Mode**: When `pc_write_en` is high and `pc_branch_en` is low, the PC increments sequentially.
2. **Branch Mode**: When both `pc_write_en` and `pc_branch_en` are high, the PC jumps to the branch target address.
3. **Hold Mode**: When `pc_write_en` is low, the PC maintains its current value.

## Control Flow Divergence

The PC module handles control flow divergence, which occurs when different threads follow different code paths due to conditional branches:

1. **Divergence Point**: When a branch instruction is encountered, threads that take the branch update their PCs to the branch target, while other threads continue sequential execution.
2. **Execution Mask**: The `thread_mask` is updated to reflect which threads are active in the current execution path.
3. **Reconvergence**: Threads reconverge when all diverged paths reach a common point in the code.

## Branch Handling

When a branch instruction is processed:

1. The branch condition is evaluated for each thread
2. For threads where the condition is true, `pc_branch_en` is set and `pc_branch_addr` contains the target address
3. For threads where the condition is false, `pc_branch_en` is cleared and PCs continue sequential execution
4. The thread mask may be updated to disable temporarily inactive threads 

## Performance Considerations

1. **Branch Divergence**: Branch divergence between threads can significantly impact performance due to SIMD execution. PC management strategies that minimize divergence are important.

2. **Branch Prediction**: For more advanced implementations, integrating branch prediction can improve performance by reducing branch penalties.

3. **Reconvergence Detection**: Efficient algorithms for detecting reconvergence points can improve thread utilization.

## Design Decisions

1. **Per-Thread PC Storage**: Each thread has its own PC register, enabling the execution of different code paths when threads diverge.

2. **Thread Masking**: Threads are masked to indicate which are currently active, allowing the scheduler to skip inactive threads during execution.

3. **Centralized Control**: The PC module centralizes control flow management, simplifying the interface with other pipeline components.

## Usage Example

Here's an example of how the PC module is used within the GPU core:

```systemverilog
program_counter #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .MAX_THREADS(MAX_THREADS)
) pc_inst (
    .clk(clk),
    .reset(reset),
    .thread_mask(active_thread_mask),
    .active_thread_id(current_thread_id),
    .pc_write_en(pc_update_en),
    .pc_branch_en(branch_taken),
    .pc_branch_addr(branch_target_addr),
    .current_pc(instruction_addr),
    .next_pc(next_instruction_addr),
    .active_threads(thread_status),
    .thread_active(thread_is_active)
);
```

## Pipeline Integration

The PC module integrates with other pipeline components:

1. **Instruction Fetcher**: Uses the PC value to fetch the next instruction
2. **Branch Unit**: Determines branch conditions and provides branch target addresses
3. **Scheduler**: Uses thread status information to schedule thread execution
4. **Core Control**: Manages overall execution flow based on PC state

## Future Improvements

1. **Call Stack Support**: Add a call stack to support function calls and returns

2. **Branch Prediction**: Implement branch prediction to reduce branch penalties

3. **Thread Preemption**: Add support for thread preemption to enable context switching

4. **PC Compression**: Implement compression techniques to reduce storage requirements for PC values

5. **Branch Target Buffer**: Add a branch target buffer (BTB) to cache branch target addresses

6. **Return Address Stack**: Implement a return address stack for efficient function returns

7. **Thread Convergence Optimization**: Implement advanced algorithms for detecting and managing thread convergence points 