`default_nettype none
`timescale 1ns/1ns

// Import the GPU package with common definitions
import gpu_pkg::*;

// ALU (Arithmetic Logic Unit)
// This module performs arithmetic and comparison operations for a single thread
// Each thread has its own dedicated ALU
module alu #(
    parameter DATA_WIDTH = 8  // Width of the data being processed
) (
    input  logic                    clk,
    input  logic                    rst_n,       // Active-low reset
    input  logic                    enable,      // Enable signal for this ALU
    
    // Control signals
    input  core_state_t             core_state,  // Current state of the core
    input  alu_op_t                 alu_op,      // ALU operation to perform
    input  logic                    is_compare,  // Set if this is a comparison operation
    
    // Data inputs
    input  logic [DATA_WIDTH-1:0]   rs_data,     // Source register 1 data
    input  logic [DATA_WIDTH-1:0]   rt_data,     // Source register 2 data
    
    // Data output
    output logic [DATA_WIDTH-1:0]   alu_out      // ALU output result
);

    // Internal registers
    logic [DATA_WIDTH-1:0] result_reg;
    
    // Continuous assignment of output
    assign alu_out = result_reg;
    
    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            result_reg <= '0;
        end 
        else if (enable && core_state == EXECUTE) begin
            // Only execute operation when in the EXECUTE state
            if (is_compare) begin
                // Comparison operation sets result bits [2:0] with N,Z,P flags
                // N (bit 2): set if rs_data < rt_data
                // Z (bit 1): set if rs_data == rt_data
                // P (bit 0): set if rs_data > rt_data
                result_reg <= {
                    {(DATA_WIDTH-3){1'b0}},       // Upper bits set to 0
                    rs_data < rt_data,            // N flag (negative)
                    rs_data == rt_data,           // Z flag (zero)
                    rs_data > rt_data             // P flag (positive)
                };
            end
            else begin
                // Arithmetic operation
                case (alu_op)
                    ALU_ADD: result_reg <= rs_data + rt_data;
                    ALU_SUB: result_reg <= rs_data - rt_data;
                    ALU_MUL: result_reg <= rs_data * rt_data;
                    ALU_DIV: result_reg <= rs_data / rt_data;
                    default: result_reg <= '0;
                endcase
            end
        end
    end
    
endmodule 