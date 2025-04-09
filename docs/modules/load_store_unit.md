# Load-Store Unit Documentation

## Overview

The Load-Store Unit (LSU) is responsible for handling all memory access operations in the GPU pipeline. It provides the interface between the execution units and memory system, enabling the GPU to load data from memory into registers and store data from registers back to memory.

## Key Features

- Handles both load and store operations
- Supports various data sizes (byte, half-word, word)
- Performs address calculation and alignment checks
- Manages memory access for all threads
- Handles memory access synchronization
- Implements data forwarding for load-after-store operations

## Interface

```systemverilog
module load_store_unit #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MAX_THREADS = 32
) (
    input  logic                          clk,
    input  logic                          reset,
    
    // Thread control
    input  logic [$clog2(MAX_THREADS)-1:0] thread_id,
    input  logic [MAX_THREADS-1:0]         thread_mask,
    
    // Control signals
    input  logic                          is_load,
    input  logic                          is_store,
    input  logic [1:0]                    data_size,  // 00: byte, 01: half-word, 10: word
    input  logic                          is_signed,  // For load operations
    
    // Address and data inputs
    input  logic [ADDR_WIDTH-1:0]         base_addr,
    input  logic [ADDR_WIDTH-1:0]         offset,
    input  logic [DATA_WIDTH-1:0]         store_data,
    
    // Register interface for loads
    output logic                          reg_write_en,
    output logic [DATA_WIDTH-1:0]         load_data,
    
    // Memory interface
    output logic                          mem_read_en,
    output logic                          mem_write_en,
    output logic [ADDR_WIDTH-1:0]         mem_addr,
    output logic [DATA_WIDTH-1:0]         mem_write_data,
    output logic [3:0]                    mem_byte_enable,
    input  logic [DATA_WIDTH-1:0]         mem_read_data,
    input  logic                          mem_busy,
    
    // Status signals
    output logic                          lsu_busy
);
```

## Parameters

| Parameter      | Default | Description                                      |
|----------------|---------|--------------------------------------------------|
| DATA_WIDTH     | 32      | Width of data path in bits                       |
| ADDR_WIDTH     | 32      | Width of memory address in bits                  |
| MAX_THREADS    | 32      | Maximum number of threads supported              |

## Inputs and Outputs

| Port           | Direction | Width                  | Description                                 |
|----------------|-----------|------------------------|---------------------------------------------|
| clk            | input     | 1                      | System clock signal                         |
| reset          | input     | 1                      | Active high reset signal                    |
| thread_id      | input     | $clog2(MAX_THREADS)    | Current thread ID being processed           |
| thread_mask    | input     | MAX_THREADS            | Bit mask of active threads                  |
| is_load        | input     | 1                      | Indicates a load operation                  |
| is_store       | input     | 1                      | Indicates a store operation                 |
| data_size      | input     | 2                      | Size of data to load/store                  |
| is_signed      | input     | 1                      | Sign extension for loads                    |
| base_addr      | input     | ADDR_WIDTH             | Base address for memory access              |
| offset         | input     | ADDR_WIDTH             | Address offset for memory access            |
| store_data     | input     | DATA_WIDTH             | Data to store to memory                     |
| reg_write_en   | output    | 1                      | Enable signal for register write            |
| load_data      | output    | DATA_WIDTH             | Data loaded from memory                     |
| mem_read_en    | output    | 1                      | Enable signal for memory read               |
| mem_write_en   | output    | 1                      | Enable signal for memory write              |
| mem_addr       | output    | ADDR_WIDTH             | Memory address for access                   |
| mem_write_data | output    | DATA_WIDTH             | Data to write to memory                     |
| mem_byte_enable| output    | 4                      | Byte enable signals for memory              |
| mem_read_data  | input     | DATA_WIDTH             | Data read from memory                       |
| mem_busy       | input     | 1                      | Indicates memory system is busy             |
| lsu_busy       | output    | 1                      | Indicates LSU is processing a request       |

## Implementation Details

### Address Calculation

The LSU calculates the effective address by adding the base address and offset:

```systemverilog
// Calculate effective address
logic [ADDR_WIDTH-1:0] effective_addr;
assign effective_addr = base_addr + offset;
```

### Byte Enable Generation

For store operations, the LSU generates byte enable signals based on the data size and address alignment:

```systemverilog
// Generate byte enables based on data size and address
always_comb begin
    mem_byte_enable = 4'b0000;
    
    if (is_store) begin
        case (data_size)
            2'b00: begin // Byte
                case (effective_addr[1:0])
                    2'b00: mem_byte_enable = 4'b0001;
                    2'b01: mem_byte_enable = 4'b0010;
                    2'b10: mem_byte_enable = 4'b0100;
                    2'b11: mem_byte_enable = 4'b1000;
                endcase
            end
            
            2'b01: begin // Half-word
                case (effective_addr[1])
                    1'b0: mem_byte_enable = 4'b0011;
                    1'b1: mem_byte_enable = 4'b1100;
                endcase
            end
            
            2'b10: begin // Word
                mem_byte_enable = 4'b1111;
            end
            
            default: mem_byte_enable = 4'b0000;
        endcase
    end
end
```

### Data Alignment for Stores

The LSU aligns the data to be stored based on the address alignment:

```systemverilog
// Align data for store operations
always_comb begin
    mem_write_data = '0;
    
    if (is_store) begin
        case (data_size)
            2'b00: begin // Byte
                case (effective_addr[1:0])
                    2'b00: mem_write_data = {24'b0, store_data[7:0]};
                    2'b01: mem_write_data = {16'b0, store_data[7:0], 8'b0};
                    2'b10: mem_write_data = {8'b0, store_data[7:0], 16'b0};
                    2'b11: mem_write_data = {store_data[7:0], 24'b0};
                endcase
            end
            
            2'b01: begin // Half-word
                case (effective_addr[1])
                    1'b0: mem_write_data = {16'b0, store_data[15:0]};
                    1'b1: mem_write_data = {store_data[15:0], 16'b0};
                endcase
            end
            
            2'b10: begin // Word
                mem_write_data = store_data;
            end
            
            default: mem_write_data = '0;
        endcase
    end
end
```

### Data Extraction and Sign Extension for Loads

The LSU extracts and potentially sign-extends data for load operations:

```systemverilog
// Extract and sign-extend data for load operations
always_comb begin
    load_data = '0;
    
    if (is_load && !mem_busy) begin
        case (data_size)
            2'b00: begin // Byte
                case (effective_addr[1:0])
                    2'b00: load_data = is_signed ? {{24{mem_read_data[7]}}, mem_read_data[7:0]} : {24'b0, mem_read_data[7:0]};
                    2'b01: load_data = is_signed ? {{24{mem_read_data[15]}}, mem_read_data[15:8]} : {24'b0, mem_read_data[15:8]};
                    2'b10: load_data = is_signed ? {{24{mem_read_data[23]}}, mem_read_data[23:16]} : {24'b0, mem_read_data[23:16]};
                    2'b11: load_data = is_signed ? {{24{mem_read_data[31]}}, mem_read_data[31:24]} : {24'b0, mem_read_data[31:24]};
                endcase
            end
            
            2'b01: begin // Half-word
                case (effective_addr[1])
                    1'b0: load_data = is_signed ? {{16{mem_read_data[15]}}, mem_read_data[15:0]} : {16'b0, mem_read_data[15:0]};
                    1'b1: load_data = is_signed ? {{16{mem_read_data[31]}}, mem_read_data[31:16]} : {16'b0, mem_read_data[31:16]};
                endcase
            end
            
            2'b10: begin // Word
                load_data = mem_read_data;
            end
            
            default: load_data = '0;
        endcase
    end
end
```

### Memory Access Control

The LSU controls memory access operations and handles busy states:

```systemverilog
// Memory access control
always_comb begin
    mem_read_en = is_load && !lsu_busy && thread_mask[thread_id];
    mem_write_en = is_store && !lsu_busy && thread_mask[thread_id];
    mem_addr = effective_addr;
    reg_write_en = is_load && !mem_busy && !lsu_busy;
end

// LSU busy state tracking
always_ff @(posedge clk or posedge reset) begin
    if (reset)
        lsu_busy <= 1'b0;
    else if ((is_load || is_store) && !lsu_busy && thread_mask[thread_id])
        lsu_busy <= 1'b1;
    else if (lsu_busy && !mem_busy)
        lsu_busy <= 1'b0;
end
```

## Memory Access Timing

The LSU coordinates the timing of memory operations in coordination with the memory controller:

1. **Initiation**: When a load or store instruction is received, the LSU calculates the effective address and initiates the memory operation.

2. **Memory Access**: The LSU asserts the appropriate control signals to the memory system and waits for the operation to complete.

3. **Completion**: For loads, the LSU processes the returned data and forwards it to the register file. For stores, the LSU simply waits for confirmation of completion.

## Memory Alignment and Requirements

The LSU supports both aligned and unaligned memory accesses, but unaligned accesses may require additional cycles to complete. For optimal performance, memory accesses should be naturally aligned:

- Byte accesses (8-bit): Any address
- Half-word accesses (16-bit): Addresses divisible by 2
- Word accesses (32-bit): Addresses divisible by 4

## Performance Considerations

1. **Latency**: Memory operations typically take multiple cycles to complete, which can stall the pipeline.

2. **Bandwidth**: The memory system has limited bandwidth, which can become a bottleneck for memory-intensive workloads.

3. **Cache Interaction**: In a system with caches, the LSU works with the cache controller to optimize memory access patterns.

4. **Memory Coalescing**: For GPU architectures, memory coalescing (combining memory accesses from multiple threads) is critical for performance.

## Design Decisions

1. **Byte Enables**: The design uses byte enable signals to support partial word writes, which allows for more efficient memory usage.

2. **Sign Extension**: The LSU supports both signed and unsigned loads, which is important for handling different data types.

3. **Thread Masking**: The LSU respects the thread mask to ensure memory operations are only performed for active threads.

4. **Busy Handling**: The LSU tracks both its own busy state and the memory system's busy state to manage pipelining and stalls.

## Usage Example

Here's an example of how the LSU is used in the GPU core:

```systemverilog
load_store_unit #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .MAX_THREADS(MAX_THREADS)
) lsu_inst (
    .clk(clk),
    .reset(reset),
    .thread_id(current_thread_id),
    .thread_mask(active_thread_mask),
    .is_load(is_load_op),
    .is_store(is_store_op),
    .data_size(mem_data_size),
    .is_signed(is_signed_load),
    .base_addr(base_address),
    .offset(address_offset),
    .store_data(store_data_value),
    .reg_write_en(lsu_reg_write_en),
    .load_data(loaded_data),
    .mem_read_en(memory_read_en),
    .mem_write_en(memory_write_en),
    .mem_addr(memory_address),
    .mem_write_data(memory_write_data),
    .mem_byte_enable(memory_byte_enables),
    .mem_read_data(memory_read_data),
    .mem_busy(memory_system_busy),
    .lsu_busy(load_store_unit_busy)
);
```

## Pipeline Integration

The LSU integrates with other pipeline components:

1. **From Instruction Decoder**: Receives operation type, data size, and register information
2. **From Register File**: Receives base address and store data
3. **To Register File**: Sends loaded data and write enable signals
4. **To/From Memory System**: Coordinates all memory accesses

## Future Improvements

1. **Memory Coalescing**: Implement hardware to coalesce memory accesses from multiple threads to the same memory region

2. **Address Translation**: Add support for virtual memory with address translation

3. **Cache Interface**: Add a direct interface to a cache system for improved performance

4. **Atomic Operations**: Implement atomic memory operations for thread synchronization

5. **Memory Prefetching**: Add prefetching capabilities to hide memory latency 