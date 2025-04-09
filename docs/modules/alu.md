# Arithmetic Logic Unit (ALU) Documentation

## Overview

The Arithmetic Logic Unit (ALU) is the computational core of the GPU pipeline, responsible for executing arithmetic, logical, and comparison operations. It performs the calculations required by the shader programs, processing data from the register file and producing results that are written back to registers.

## Key Features

- Supports a wide range of arithmetic operations (ADD, SUB, MUL, DIV)
- Implements logical operations (AND, OR, XOR, NOT)
- Performs comparison operations (EQ, NE, LT, LE, GT, GE)
- Handles shift operations (SHL, SHR, SAR)
- Supports data type conversion operations
- Processes operations for multiple threads in a SIMD fashion

## Interface

```systemverilog
module alu #(
    parameter DATA_WIDTH = 32,
    parameter MAX_THREADS = 32
) (
    input  logic                          clk,
    input  logic                          reset,
    
    // Thread control
    input  logic [$clog2(MAX_THREADS)-1:0] thread_id,
    input  logic [MAX_THREADS-1:0]         thread_mask,
    
    // Operation inputs
    input  logic [3:0]                    op_code,
    input  logic [DATA_WIDTH-1:0]         operand_a,
    input  logic [DATA_WIDTH-1:0]         operand_b,
    
    // Result outputs
    output logic [DATA_WIDTH-1:0]         result,
    output logic                          result_valid,
    
    // Flags
    output logic                          zero_flag,
    output logic                          negative_flag,
    output logic                          overflow_flag,
    output logic                          carry_flag
);
```

## Parameters

| Parameter      | Default | Description                                       |
|----------------|---------|---------------------------------------------------|
| DATA_WIDTH     | 32      | Width of operands and result in bits              |
| MAX_THREADS    | 32      | Maximum number of threads supported               |

## Inputs and Outputs

| Port           | Direction | Width                  | Description                                 |
|----------------|-----------|------------------------|---------------------------------------------|
| clk            | input     | 1                      | System clock signal                         |
| reset          | input     | 1                      | Active high reset signal                    |
| thread_id      | input     | $clog2(MAX_THREADS)    | Current thread ID being processed           |
| thread_mask    | input     | MAX_THREADS            | Bit mask of active threads                  |
| op_code        | input     | 4                      | Operation code specifying the ALU function  |
| operand_a      | input     | DATA_WIDTH             | First operand                               |
| operand_b      | input     | DATA_WIDTH             | Second operand                              |
| result         | output    | DATA_WIDTH             | Result of the ALU operation                 |
| result_valid   | output    | 1                      | Indicates the result is valid               |
| zero_flag      | output    | 1                      | Set when result is zero                     |
| negative_flag  | output    | 1                      | Set when result is negative                 |
| overflow_flag  | output    | 1                      | Set when arithmetic overflow occurs         |
| carry_flag     | output    | 1                      | Set when carry occurs in arithmetic ops     |

## Operation Codes

| Op Code | Mnemonic | Description                          |
|---------|----------|--------------------------------------|
| 4'b0000 | ADD      | Addition: A + B                      |
| 4'b0001 | SUB      | Subtraction: A - B                   |
| 4'b0010 | MUL      | Multiplication: A * B                |
| 4'b0011 | DIV      | Division: A / B                      |
| 4'b0100 | AND      | Bitwise AND: A & B                   |
| 4'b0101 | OR       | Bitwise OR: A \| B                   |
| 4'b0110 | XOR      | Bitwise XOR: A ^ B                   |
| 4'b0111 | NOT      | Bitwise NOT: ~A (B ignored)          |
| 4'b1000 | SHL      | Shift left: A << B                   |
| 4'b1001 | SHR      | Logical shift right: A >> B          |
| 4'b1010 | SAR      | Arithmetic shift right: A >>> B      |
| 4'b1011 | CMP      | Compare (sets flags, result is A-B)  |
| 4'b1100 | MIN      | Minimum: (A < B) ? A : B             |
| 4'b1101 | MAX      | Maximum: (A > B) ? A : B             |
| 4'b1110 | ABS      | Absolute value: |A| (B ignored)      |
| 4'b1111 | MOV      | Move: B (A ignored)                  |

## Implementation Details

### Operation Execution

The ALU executes operations based on the provided op_code:

```systemverilog
// ALU operation execution
always_comb begin
    // Default values
    result_temp = 0;
    carry_temp = 0;
    overflow_temp = 0;
    
    if (thread_mask[thread_id]) begin
        case (op_code)
            // Arithmetic operations
            4'b0000: begin // ADD
                {carry_temp, result_temp} = {1'b0, operand_a} + {1'b0, operand_b};
                overflow_temp = (~operand_a[DATA_WIDTH-1] & ~operand_b[DATA_WIDTH-1] & result_temp[DATA_WIDTH-1]) |
                              (operand_a[DATA_WIDTH-1] & operand_b[DATA_WIDTH-1] & ~result_temp[DATA_WIDTH-1]);
            end
            
            4'b0001: begin // SUB
                {carry_temp, result_temp} = {1'b0, operand_a} - {1'b0, operand_b};
                overflow_temp = (~operand_a[DATA_WIDTH-1] & operand_b[DATA_WIDTH-1] & result_temp[DATA_WIDTH-1]) |
                              (operand_a[DATA_WIDTH-1] & ~operand_b[DATA_WIDTH-1] & ~result_temp[DATA_WIDTH-1]);
            end
            
            4'b0010: begin // MUL
                result_temp = operand_a * operand_b;
                // Overflow detection for multiplication is more complex
                // This is a simplified version
                overflow_temp = (operand_a != 0 && operand_b != 0) && 
                             ((operand_a * operand_b) / operand_b != operand_a);
            end
            
            4'b0011: begin // DIV
                // Check for division by zero
                if (operand_b == 0) begin
                    result_temp = {DATA_WIDTH{1'b1}}; // Set all bits to 1 for error indication
                    overflow_temp = 1;
                end else begin
                    result_temp = operand_a / operand_b;
                    overflow_temp = 0;
                end
            end
            
            // Logical operations
            4'b0100: result_temp = operand_a & operand_b; // AND
            4'b0101: result_temp = operand_a | operand_b; // OR
            4'b0110: result_temp = operand_a ^ operand_b; // XOR
            4'b0111: result_temp = ~operand_a; // NOT
            
            // Shift operations
            4'b1000: begin // SHL
                result_temp = operand_a << operand_b[4:0]; // Only use 5 bits of operand_b for shift amount
                // Carry is the last bit shifted out
                if (operand_b[4:0] > 0 && operand_b[4:0] < DATA_WIDTH)
                    carry_temp = operand_a[DATA_WIDTH - operand_b[4:0]];
            end
            
            4'b1001: begin // SHR (logical)
                result_temp = operand_a >> operand_b[4:0];
                // Carry is the last bit shifted out
                if (operand_b[4:0] > 0 && operand_b[4:0] < DATA_WIDTH)
                    carry_temp = operand_a[operand_b[4:0] - 1];
            end
            
            4'b1010: begin // SAR (arithmetic)
                // Maintain the sign bit when shifting
                result_temp = $signed(operand_a) >>> operand_b[4:0];
                if (operand_b[4:0] > 0 && operand_b[4:0] < DATA_WIDTH)
                    carry_temp = operand_a[operand_b[4:0] - 1];
            end
            
            // Comparison operations
            4'b1011: begin // CMP
                result_temp = operand_a - operand_b;
                // Flags are set based on the comparison
                carry_temp = (operand_a < operand_b);
                overflow_temp = (~operand_a[DATA_WIDTH-1] & operand_b[DATA_WIDTH-1] & result_temp[DATA_WIDTH-1]) |
                              (operand_a[DATA_WIDTH-1] & ~operand_b[DATA_WIDTH-1] & ~result_temp[DATA_WIDTH-1]);
            end
            
            // Other operations
            4'b1100: result_temp = (operand_a < operand_b) ? operand_a : operand_b; // MIN
            4'b1101: result_temp = (operand_a > operand_b) ? operand_a : operand_b; // MAX
            4'b1110: result_temp = operand_a[DATA_WIDTH-1] ? -operand_a : operand_a; // ABS
            4'b1111: result_temp = operand_b; // MOV
            
            default: result_temp = 0;
        endcase
    end
end
```

### Flag Generation

The ALU generates flags based on the result of each operation:

```systemverilog
// Flag generation
always_comb begin
    if (thread_mask[thread_id]) begin
        zero_flag = (result_temp == 0);
        negative_flag = result_temp[DATA_WIDTH-1];
        overflow_flag = overflow_temp;
        carry_flag = carry_temp;
    end else begin
        zero_flag = 0;
        negative_flag = 0;
        overflow_flag = 0;
        carry_flag = 0;
    end
end
```

### Result and Validity

The result is registered and validity is tracked:

```systemverilog
// Register the result and generate valid signal
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        result <= 0;
        result_valid <= 0;
    end else begin
        result <= result_temp;
        result_valid <= thread_mask[thread_id];
    end
end
```

## Single-Cycle vs. Multi-Cycle Operations

The ALU supports both single-cycle and multi-cycle operations:

1. **Single-Cycle Operations**: Most logical operations (AND, OR, XOR, NOT) and simple arithmetic operations (ADD, SUB) can be completed in a single clock cycle.

2. **Multi-Cycle Operations**: Complex operations like multiplication and division may require multiple clock cycles to complete. The ALU can be extended to handle these operations in a pipelined fashion.

## Thread Handling

The ALU processes operations for multiple threads based on the thread_mask input, which indicates which threads are active. The implementation ensures that operations are only performed for active threads, and the result_valid output is set accordingly.

## Performance Considerations

1. **Latency**: Different operations have different latencies, with simple logical operations typically taking 1 cycle, while complex arithmetic operations like division might take multiple cycles.

2. **Throughput**: For a GPU architecture, it's important to optimize the ALU for high throughput to handle multiple threads efficiently.

3. **Resource Usage**: The implementation balances resource usage (logic gates) with performance requirements.

## Design Decisions

1. **Operation Set**: The ALU supports a comprehensive set of operations tailored for GPU workloads, including both standard CPU-like operations and specialized GPU operations like MIN and MAX.

2. **Error Handling**: The ALU handles error conditions like division by zero by returning a specific result and setting the appropriate flags.

3. **Flag Generation**: Flags (zero, negative, overflow, carry) provide additional information about the result of operations, which is useful for conditional execution and branch operations.

4. **Thread Masking**: The ALU respects the thread mask to ensure operations are only performed for active threads, which is essential for efficient SIMD execution.

## Usage Example

Here's an example of how the ALU is used in the GPU core:

```systemverilog
alu #(
    .DATA_WIDTH(DATA_WIDTH),
    .MAX_THREADS(MAX_THREADS)
) alu_inst (
    .clk(clk),
    .reset(reset),
    .thread_id(current_thread_id),
    .thread_mask(active_thread_mask),
    .op_code(alu_operation),
    .operand_a(src_reg1_data),
    .operand_b(src_reg2_data),
    .result(alu_result),
    .result_valid(alu_result_valid),
    .zero_flag(alu_zero),
    .negative_flag(alu_negative),
    .overflow_flag(alu_overflow),
    .carry_flag(alu_carry)
);
```

## Pipeline Integration

The ALU integrates with other pipeline components:

1. **From Instruction Decoder**: Receives operation type and operation code
2. **From Register File**: Receives operand data
3. **To Register File**: Sends result data
4. **To Scheduler**: Provides flag information for branching decisions

## Future Improvements

1. **Pipelined Implementation**: Enhance the ALU to support pipelined execution of complex operations like division

2. **Floating-Point Support**: Add a floating-point unit or extend the ALU to handle floating-point operations

3. **SIMD Extensions**: Implement SIMD extensions to process multiple data elements in parallel within a single thread

4. **Specialized Functions**: Add support for specialized functions like square root, reciprocal, and trigonometric functions

5. **Instruction Fusion**: Add support for fused operations like multiply-add (MAD) to improve performance and precision

6. **Dynamic Power Management**: Implement power-saving features like clock gating for unused ALU components 