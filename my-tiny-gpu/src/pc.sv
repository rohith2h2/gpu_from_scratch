`default_nettype none
`timescale 1ns/1ns

// Import the GPU package with common definitions
import gpu_pkg::*;

// PC (Program Counter)
// Manages program execution flow for a single thread
// Handles branching logic based on NZP (negative, zero, positive) comparisons
module pc #(
    parameter ADDR_WIDTH = 8,  // Width of program memory address
    parameter DATA_WIDTH = 8   // Width of the data being processed
) (
    input  logic                    clk,
    input  logic                    rst_n,        // Active-low reset
    input  logic                    enable,       // Enable signal for this PC
    
    // State and control signals
    input  core_state_t             core_state,   // Current state of the core
    input  logic                    branch_enable, // Enable branch operations
    input  logic                    nzp_write_enable, // Write to NZP register
    input  logic [2:0]              branch_condition, // Branch condition (NZP bits)
    
    // Data inputs
    input  logic [DATA_WIDTH-1:0]   alu_result,    // Result from ALU (for NZP)
    input  logic [ADDR_WIDTH-1:0]   branch_target, // Target address for branch
    input  logic [ADDR_WIDTH-1:0]   current_pc,    // Current program counter value
    
    // Output
    output logic [ADDR_WIDTH-1:0]   next_pc       // Next program counter value
);

    // NZP register holds the result of the last comparison
    // Bit 2: Negative (N), Bit 1: Zero (Z), Bit 0: Positive (P)
    logic [2:0] nzp_reg;
    
    // Logic for determining the next PC
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            next_pc <= '0;
            nzp_reg <= '0;
        end 
        else if (enable) begin
            // Update PC in EXECUTE state
            if (core_state == EXECUTE) begin
                // Determine the next PC value
                if (branch_enable && (nzp_reg & branch_condition) != '0) begin
                    // Branch taken if the branch_condition matches the nzp_reg
                    next_pc <= branch_target;
                end 
                else begin
                    // Normal execution - increment PC
                    next_pc <= current_pc + 1'b1;
                end
            end
            
            // Update NZP register in UPDATE state
            if (core_state == UPDATE && nzp_write_enable) begin
                // Extract NZP bits from the ALU result
                // In the ALU, we set these in bits [2:0] during comparison
                nzp_reg <= alu_result[2:0];
            end
        end
    end
    
endmodule 