# Register File Documentation

## Overview

The Register File is a fundamental component of the GPU that provides temporary storage for operands and results during instruction execution. It consists of multiple general-purpose registers that can be read and written by various instructions, enabling data manipulation and calculation within the GPU pipeline.

## Key Features

- Multiple read and write ports to support parallel access
- Per-thread register set to enable independent thread execution
- Fast access time to minimize pipeline stalls
- Configurable number of registers and register width
- Supports both scalar and vector operations

## Interface

```systemverilog
module register_file #(
    parameter DATA_WIDTH = 32,
    parameter NUM_REGISTERS = 16,
    parameter MAX_THREADS = 32
) (
    input  logic                            clk,
    input  logic                            reset,
    
    // Thread control
    input  logic [$clog2(MAX_THREADS)-1:0]  thread_id,
    
    // Read ports
    input  logic [$clog2(NUM_REGISTERS)-1:0] rd_addr_a,
    input  logic [$clog2(NUM_REGISTERS)-1:0] rd_addr_b,
    output logic [DATA_WIDTH-1:0]            rd_data_a,
    output logic [DATA_WIDTH-1:0]            rd_data_b,
    
    // Write port
    input  logic                             wr_en,
    input  logic [$clog2(NUM_REGISTERS)-1:0] wr_addr,
    input  logic [DATA_WIDTH-1:0]            wr_data
);
```

## Parameters

| Parameter      | Default | Description                                      |
|----------------|---------|--------------------------------------------------|
| DATA_WIDTH     | 32      | Width of each register in bits                   |
| NUM_REGISTERS  | 16      | Number of registers per thread                   |
| MAX_THREADS    | 32      | Maximum number of threads supported              |

## Inputs and Outputs

| Port           | Direction | Width                    | Description                                 |
|----------------|-----------|--------------------------|---------------------------------------------|
| clk            | input     | 1                        | System clock signal                         |
| reset          | input     | 1                        | Active high reset signal                    |
| thread_id      | input     | $clog2(MAX_THREADS)      | Current thread ID being processed           |
| rd_addr_a      | input     | $clog2(NUM_REGISTERS)    | Address for first read port                 |
| rd_addr_b      | input     | $clog2(NUM_REGISTERS)    | Address for second read port                |
| rd_data_a      | output    | DATA_WIDTH               | Data output from first read port            |
| rd_data_b      | output    | DATA_WIDTH               | Data output from second read port           |
| wr_en          | input     | 1                        | Write enable signal                         |
| wr_addr        | input     | $clog2(NUM_REGISTERS)    | Address for write port                      |
| wr_data        | input     | DATA_WIDTH               | Data to write to register                   |

## Implementation Details

The Register File implements a multi-dimensional register array to store data for each thread:

```systemverilog
// 3D array: [thread][register][bit]
logic [DATA_WIDTH-1:0] registers [MAX_THREADS-1:0][NUM_REGISTERS-1:0];
```

### Read Operations

Read operations are asynchronous, allowing for immediate access to register values:

```systemverilog
// Read operations are asynchronous
always_comb begin
    // Handle register 0 special case (hardwired to zero)
    rd_data_a = (rd_addr_a == '0) ? '0 : registers[thread_id][rd_addr_a];
    rd_data_b = (rd_addr_b == '0) ? '0 : registers[thread_id][rd_addr_b];
end
```

### Write Operations

Write operations are synchronous, occurring on the rising edge of the clock:

```systemverilog
// Write operation is synchronous
always_ff @(posedge clk) begin
    if (reset) begin
        // Initialize all registers to zero
        for (int t = 0; t < MAX_THREADS; t++) begin
            for (int r = 0; r < NUM_REGISTERS; r++) begin
                registers[t][r] <= '0;
            end
        end
    end
    else if (wr_en && wr_addr != '0) begin  // Register 0 is read-only
        registers[thread_id][wr_addr] <= wr_data;
    end
end
```

## Register Convention

The register file follows a specific convention for register usage:

| Register | Name    | Purpose                                           | Preserved Across Calls |
|----------|---------|---------------------------------------------------|------------------------|
| r0       | zero    | Hardwired to zero, writes are ignored             | N/A                    |
| r1-r3    | a0-a2   | Function arguments and return values              | No                     |
| r4-r8    | t0-t4   | Temporary registers                               | No                     |
| r9-r12   | s0-s3   | Saved registers                                   | Yes                    |
| r13      | sp      | Stack pointer                                     | Yes                    |
| r14      | ra      | Return address                                    | No                     |
| r15      | tid     | Thread ID (read-only)                             | N/A                    |

### Special Registers

- **Register 0 (zero)**: Always reads as zero, writes are ignored
- **Register 15 (tid)**: Contains the thread ID, automatically loaded at thread initialization

## Performance Considerations

1. **Access Time**: The register file is designed for single-cycle access to minimize pipeline stalls.

2. **Forwarding**: The actual implementation may need forwarding logic to handle read-after-write hazards within the pipeline.

3. **Scalability**: The design scales with the number of threads and registers, but larger register files may impact clock frequency.

4. **Power Consumption**: Register files are typically high-power components in a processor; power gating can be used for inactive threads.

## Design Decisions

1. **Dual Read Ports**: Two read ports are provided to support most ALU operations that require two source operands.

2. **Single Write Port**: A single write port is sufficient for most operations, as only one result is produced per instruction.

3. **Per-Thread Registers**: Each thread has its own set of registers to maintain independent execution contexts.

4. **Register Zero**: Register 0 is hardwired to zero, a common convention that simplifies certain operations and provides a constant zero value.

## Register File Access Patterns

The Register File is accessed during different stages of the pipeline:

1. **Instruction Decode**: Register addresses are extracted from the instruction
2. **Register Read**: Register values are read from the register file
3. **Execute**: ALU operations are performed on the register values
4. **Write Back**: Results are written back to the register file

## Usage Example

Here's an example of how the Register File is used in the GPU core:

```systemverilog
register_file #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_REGISTERS(NUM_REGISTERS),
    .MAX_THREADS(MAX_THREADS)
) rf_inst (
    .clk(clk),
    .reset(reset),
    .thread_id(current_thread_id),
    .rd_addr_a(decoded_src1),
    .rd_addr_b(decoded_src2),
    .rd_data_a(reg_data_src1),
    .rd_data_b(reg_data_src2),
    .wr_en(reg_write_enable),
    .wr_addr(reg_write_addr),
    .wr_data(reg_write_data)
);
```

## Pipeline Integration

The Register File interacts with other pipeline components:

1. **From Instruction Decoder**: Receives register addresses for reading operands and writing results
2. **To ALU**: Provides source operands for computation
3. **From Load-Store Unit**: Receives data loaded from memory to write to registers
4. **From Write-Back Stage**: Receives computation results to write to registers

## Future Improvements

1. **Bank Organization**: Implement register banks to reduce power consumption and increase parallelism

2. **Multi-Issue Support**: Add more read and write ports to support superscalar execution

3. **Register Renaming**: Implement register renaming to eliminate false dependencies between instructions

4. **Vector Register Support**: Extend the design to support SIMD operations with vector registers

5. **Register Spilling**: Add hardware support for register spilling when more registers are needed than available 