# Instruction Decoder Documentation

## Overview

The Instruction Decoder is a critical component in the GPU pipeline that translates raw instruction bits into control signals that drive the execution of operations. It parses each instruction to identify its type, extract operand addresses, determine operation codes, and generate control signals for other pipeline components. The decoder effectively serves as the interpreter between the compact binary instruction format and the detailed control signals needed by the execution units.

## Key Features

- Decodes binary instructions into control signals
- Extracts operation codes, register addresses, and immediate values
- Supports various instruction formats (arithmetic, memory, branch, etc.)
- Generates appropriate control signals for each instruction type
- Provides immediate values with proper sign or zero extension
- Detects illegal instructions and generates appropriate error signals

## Interface

```systemverilog
module instruction_decoder #(
    parameter INSTR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter REG_ADDR_WIDTH = 4
) (
    input  logic                        clk,
    input  logic                        reset,
    
    // Pipeline control
    input  logic                        decode_en,
    output logic                        decode_valid,
    
    // Instruction input
    input  logic [INSTR_WIDTH-1:0]      instruction,
    
    // Decoded outputs - ALU control
    output logic [3:0]                  alu_op,
    output logic                        alu_en,
    
    // Decoded outputs - Memory control
    output logic                        is_load,
    output logic                        is_store,
    output logic [1:0]                  mem_size,    // 00: byte, 01: half-word, 10: word
    output logic                        mem_signed,  // Sign extension for loads
    
    // Decoded outputs - Control flow
    output logic                        is_branch,
    output logic                        is_jump,
    output logic                        is_conditional,
    output logic [3:0]                  branch_condition,
    
    // Decoded outputs - Special instructions
    output logic                        is_barrier,
    output logic                        is_halt,
    
    // Decoded outputs - Register addresses
    output logic [REG_ADDR_WIDTH-1:0]   dest_reg,
    output logic [REG_ADDR_WIDTH-1:0]   src_reg1,
    output logic [REG_ADDR_WIDTH-1:0]   src_reg2,
    
    // Decoded outputs - Immediate value
    output logic [DATA_WIDTH-1:0]       immediate,
    output logic                        use_immediate,
    
    // Error output
    output logic                        illegal_instruction
);
```

## Parameters

| Parameter        | Default | Description                                      |
|------------------|---------|--------------------------------------------------|
| INSTR_WIDTH      | 32      | Width of instruction word in bits                |
| DATA_WIDTH       | 32      | Width of data path in bits                       |
| REG_ADDR_WIDTH   | 4       | Width of register address field in bits          |

## Inputs and Outputs

| Port               | Direction | Width           | Description                                      |
|--------------------|-----------|----------------|--------------------------------------------------|
| clk                | input     | 1              | System clock signal                              |
| reset              | input     | 1              | Active high reset signal                         |
| decode_en          | input     | 1              | Enable signal for decoder operation              |
| decode_valid       | output    | 1              | Indicates decoded outputs are valid              |
| instruction        | input     | INSTR_WIDTH    | Raw instruction to decode                        |
| alu_op             | output    | 4              | ALU operation code                               |
| alu_en             | output    | 1              | Enable signal for ALU operation                  |
| is_load            | output    | 1              | Indicates a load instruction                     |
| is_store           | output    | 1              | Indicates a store instruction                    |
| mem_size           | output    | 2              | Memory access size (byte, half-word, word)       |
| mem_signed         | output    | 1              | Sign extension for load operations               |
| is_branch          | output    | 1              | Indicates a branch instruction                   |
| is_jump            | output    | 1              | Indicates an unconditional jump instruction      |
| is_conditional     | output    | 1              | Indicates a conditional branch/jump              |
| branch_condition   | output    | 4              | Condition code for conditional branches          |
| is_barrier         | output    | 1              | Indicates a barrier synchronization instruction  |
| is_halt            | output    | 1              | Indicates a halt instruction                     |
| dest_reg           | output    | REG_ADDR_WIDTH | Destination register address                     |
| src_reg1           | output    | REG_ADDR_WIDTH | First source register address                    |
| src_reg2           | output    | REG_ADDR_WIDTH | Second source register address                   |
| immediate          | output    | DATA_WIDTH     | Immediate value (sign/zero extended)             |
| use_immediate      | output    | 1              | Indicates immediate should be used as operand    |
| illegal_instruction| output    | 1              | Indicates an illegal instruction was detected    |

## Instruction Format

The instruction decoder supports the following instruction format:

```
31      28 27      24 23      20 19      16 15                          0
+----------+----------+----------+----------+--------------------------+
| Op Code  | Dest Reg | Src Reg1 | Src Reg2 |       Immediate         |
+----------+----------+----------+----------+--------------------------+
```

- **Op Code (bits 31-28)**: Determines the operation to perform
- **Dest Reg (bits 27-24)**: Destination register address
- **Src Reg1 (bits 23-20)**: First source register address
- **Src Reg2 (bits 19-16)**: Second source register address
- **Immediate (bits 15-0)**: Immediate value or offset

### Alternative Formats

For certain instruction types, the fields are interpreted differently:

- **Branch Format**:
  ```
  31      28 27      24 23      20 19           0
  +----------+----------+----------+---------------+
  | Op Code  | Condition| Src Reg  |    Offset     |
  +----------+----------+----------+---------------+
  ```

- **Jump Format**:
  ```
  31      28 27                                   0
  +----------+----------------------------------------+
  | Op Code  |               Target Address           |
  +----------+----------------------------------------+
  ```

## Operation Codes

| Op Code | Mnemonic  | Description                          | Format Type |
|---------|-----------|--------------------------------------|-------------|
| 0x0     | NOP       | No operation                         | Standard    |
| 0x1     | ADD       | Integer addition                     | Standard    |
| 0x2     | SUB       | Integer subtraction                  | Standard    |
| 0x3     | MUL       | Integer multiplication               | Standard    |
| 0x4     | DIV       | Integer division                     | Standard    |
| 0x5     | AND       | Bitwise AND                          | Standard    |
| 0x6     | OR        | Bitwise OR                           | Standard    |
| 0x7     | XOR       | Bitwise XOR                          | Standard    |
| 0x8     | SHL       | Shift left                           | Standard    |
| 0x9     | SHR       | Shift right logical                  | Standard    |
| 0xA     | SAR       | Shift right arithmetic               | Standard    |
| 0xB     | CMP       | Compare                              | Standard    |
| 0xC     | LDR       | Load from memory                     | Standard    |
| 0xD     | STR       | Store to memory                      | Standard    |
| 0xE     | BR        | Conditional branch                   | Branch      |
| 0xF     | JMP       | Unconditional jump                   | Jump        |

## Implementation Details

### Instruction Decoding Logic

The decoder extracts fields from the instruction word:

```systemverilog
// Extract fields from instruction
wire [3:0] opcode = instruction[31:28];
wire [3:0] rd = instruction[27:24];
wire [3:0] rs1 = instruction[23:20];
wire [3:0] rs2 = instruction[19:16];
wire [15:0] imm = instruction[15:0];
```

### Instruction Type Determination

The decoder identifies the instruction type based on the opcode:

```systemverilog
// Determine instruction type based on opcode
always_comb begin
    // Default values
    alu_en = 1'b0;
    is_load = 1'b0;
    is_store = 1'b0;
    is_branch = 1'b0;
    is_jump = 1'b0;
    is_barrier = 1'b0;
    is_halt = 1'b0;
    illegal_instruction = 1'b0;
    
    case (opcode)
        4'h0: begin // NOP
            // No operation, all default values are correct
        end
        
        4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7, 4'h8, 4'h9, 4'hA, 4'hB: begin
            // ALU operations
            alu_en = 1'b1;
        end
        
        4'hC: begin // LDR
            is_load = 1'b1;
        end
        
        4'hD: begin // STR
            is_store = 1'b1;
        end
        
        4'hE: begin // BR
            is_branch = 1'b1;
            is_conditional = 1'b1;
        end
        
        4'hF: begin // JMP
            is_jump = 1'b1;
            is_conditional = 1'b0;
        end
        
        default: begin
            illegal_instruction = 1'b1;
        end
    endcase
end
```

### ALU Operation Code Generation

For ALU instructions, the opcode is translated to an ALU operation code:

```systemverilog
// Generate ALU operation code
always_comb begin
    case (opcode)
        4'h1: alu_op = 4'h0; // ADD
        4'h2: alu_op = 4'h1; // SUB
        4'h3: alu_op = 4'h2; // MUL
        4'h4: alu_op = 4'h3; // DIV
        4'h5: alu_op = 4'h4; // AND
        4'h6: alu_op = 4'h5; // OR
        4'h7: alu_op = 4'h6; // XOR
        4'h8: alu_op = 4'h8; // SHL
        4'h9: alu_op = 4'h9; // SHR
        4'hA: alu_op = 4'hA; // SAR
        4'hB: alu_op = 4'hB; // CMP
        default: alu_op = 4'h0;
    endcase
end
```

### Immediate Value Processing

The decoder handles immediate values, including sign extension:

```systemverilog
// Process immediate value
always_comb begin
    use_immediate = 1'b0;
    
    if (opcode inside {4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7, 4'h8, 4'h9, 4'hA}) begin
        // ALU operations with immediate
        immediate = {{16{imm[15]}}, imm}; // Sign extend
        use_immediate = 1'b1;
    end
    else if (opcode == 4'hC || opcode == 4'hD) begin
        // Load/store operations
        immediate = {{16{imm[15]}}, imm}; // Sign extend for address offset
        use_immediate = 1'b1;
    end
    else if (opcode == 4'hE) begin
        // Branch operations
        immediate = {{16{imm[15]}}, imm}; // Sign extend for branch offset
    end
    else if (opcode == 4'hF) begin
        // Jump operations
        immediate = {8'b0, instruction[23:0]}; // Jump target address
    end
    else begin
        immediate = '0;
    end
end
```

### Memory Access Control

For load and store instructions, the decoder generates memory control signals:

```systemverilog
// Generate memory control signals
always_comb begin
    mem_size = 2'b10; // Default to word
    mem_signed = 1'b1; // Default to signed
    
    if (is_load || is_store) begin
        // Memory size based on bits in the instruction
        mem_size = rs2[1:0];
        mem_signed = rs2[2];
    end
end
```

### Branch Condition Decoding

For conditional branch instructions, the decoder extracts the condition code:

```systemverilog
// Branch condition decoding
always_comb begin
    branch_condition = 4'h0;
    
    if (is_branch) begin
        branch_condition = rd; // Condition code in rd field
    end
end
```

## Instruction Timing

The decoder operates in a single clock cycle, receiving the instruction and producing control signals within the same cycle:

```systemverilog
// Pipeline control
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        decode_valid <= 1'b0;
    end
    else begin
        decode_valid <= decode_en && !illegal_instruction;
    end
end
```

## Usage with Other Modules

The Instruction Decoder interfaces with other pipeline components:

1. **Instruction Fetcher**: Provides the raw instruction data to the decoder
2. **Register File**: Receives register addresses for operand fetching
3. **ALU**: Receives operation codes and control signals
4. **Load-Store Unit**: Receives memory operation control signals
5. **Program Counter**: Receives branch and jump control signals

## Branch and Jump Handling

For branch and jump instructions, the decoder generates appropriate control signals:

```systemverilog
// Branch condition codes
// 0000: Equal (EQ)
// 0001: Not Equal (NE)
// 0010: Less Than (LT)
// 0011: Greater Than (GT)
// 0100: Less Than or Equal (LE)
// 0101: Greater Than or Equal (GE)
// 0110: Zero (Z)
// 0111: Non-Zero (NZ)
// 1000: Always (AL)
// ...
```

## Pipeline Integration

Within the pipeline, the Instruction Decoder receives instructions after they've been fetched and generates control signals that drive subsequent pipeline stages:

1. **Fetch Stage**: The instruction is fetched from memory
2. **Decode Stage**: The instruction is decoded by this module
3. **Execute Stage**: ALU, memory, and branch operations execute based on decoder outputs

## Performance Considerations

1. **Critical Path**: The decoder's logic can often be in the critical path of the pipeline, affecting maximum clock frequency.

2. **Instruction Grouping**: For advanced implementations, grouping similar instruction types can optimize the decoder's logic.

3. **Pipelining**: For higher clock rates, the decoder itself can be pipelined, though this introduces additional latency.

## Design Decisions

1. **Fixed-Width Instructions**: The design uses fixed-width 32-bit instructions for simplicity and uniformity.

2. **Field Allocation**: Field sizes (4 bits for register addresses, 16 bits for immediates) balance the needs of different instruction types.

3. **Opcode Assignment**: Operation codes are assigned to maximize the similarity of related operations and simplify decoding logic.

4. **Immediate Handling**: Immediate values are sign-extended by default, simplifying the most common use cases.

## Instruction Set Extensions

The decoder architecture allows for extensions:

1. **Additional Operations**: New operations can be added by assigning unused opcode values.

2. **Special Instructions**: Special system control instructions can be added with unique opcodes.

3. **Vector Extensions**: Vector operations can be supported by reinterpreting instruction fields.

## Usage Example

Here's an example of how the Instruction Decoder is used in the GPU core:

```systemverilog
instruction_decoder #(
    .INSTR_WIDTH(32),
    .DATA_WIDTH(32),
    .REG_ADDR_WIDTH(4)
) id_inst (
    .clk(clk),
    .reset(reset),
    .decode_en(pipeline_stage == DECODE),
    .instruction(fetched_instruction),
    .alu_op(alu_operation),
    .alu_en(alu_enable),
    .is_load(is_load_op),
    .is_store(is_store_op),
    .mem_size(memory_access_size),
    .mem_signed(is_signed_load),
    .is_branch(is_branch_instruction),
    .is_jump(is_jump_instruction),
    .is_conditional(is_conditional_branch),
    .branch_condition(branch_cond_code),
    .dest_reg(destination_register),
    .src_reg1(source_register1),
    .src_reg2(source_register2),
    .immediate(immediate_value),
    .use_immediate(use_imm_as_operand),
    .decode_valid(decoder_output_valid),
    .illegal_instruction(illegal_instr_detected)
);
```

## Future Improvements

1. **Compressed Instructions**: Add support for 16-bit compressed instructions to improve code density

2. **Predicated Execution**: Implement predication to reduce branch overhead

3. **Instruction Fusion**: Support combining multiple instructions into compound operations

4. **Advanced Addressing Modes**: Add more sophisticated addressing modes for memory operations

5. **SIMD Instructions**: Add support for Single Instruction, Multiple Data operations

6. **Custom Instructions**: Support for application-specific custom instructions

7. **Instruction Decoding Cache**: Cache recently decoded instructions to save power 