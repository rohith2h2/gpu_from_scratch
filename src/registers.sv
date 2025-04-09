`default_nettype none
`timescale 1ns/1ns

// Import the GPU package with common definitions
import gpu_pkg::*;

// Register File
// Contains 16 registers for each thread: 13 general purpose (R0-R12) and 3 special (R13-R15)
// Special registers contain thread metadata:
// - R13 (%blockIdx): Block index being processed
// - R14 (%blockDim): Number of threads per block
// - R15 (%threadIdx): Thread index within the block
module registers #(
    parameter DATA_WIDTH = 8,     // Width of the data being processed
    parameter THREAD_ID = 0,      // ID of the thread this register file belongs to
    parameter NUM_REGISTERS = 16  // Total number of registers
) (
    input  logic                    clk,
    input  logic                    rst_n,          // Active-low reset
    input  logic                    enable,         // Enable signal for this register file
    
    // Block metadata
    input  logic [DATA_WIDTH-1:0]   block_id,       // ID of the block being processed
    input  logic [DATA_WIDTH-1:0]   block_dim,      // Dimension (size) of the block
    
    // State and control signals
    input  core_state_t             core_state,     // Current state of the core
    input  logic                    reg_write_en,   // Register write enable
    input  reg_src_t                reg_src,        // Source for register write
    
    // Register addresses
    input  logic [3:0]              rd_addr,        // Destination register address
    input  logic [3:0]              rs_addr,        // Source register 1 address
    input  logic [3:0]              rt_addr,        // Source register 2 address
    
    // Data inputs
    input  logic [DATA_WIDTH-1:0]   immediate,      // Immediate value
    input  logic [DATA_WIDTH-1:0]   alu_result,     // Result from ALU
    input  logic [DATA_WIDTH-1:0]   lsu_result,     // Result from LSU (memory load)
    
    // Data outputs
    output logic [DATA_WIDTH-1:0]   rs_data,        // Data from source register 1
    output logic [DATA_WIDTH-1:0]   rt_data         // Data from source register 2
);

    // Register file memory
    logic [DATA_WIDTH-1:0] registers [NUM_REGISTERS-1:0];
    
    // Read operations (combinational)
    always_comb begin
        // Special registers - read only
        if (rs_addr == REG_BLOCK_IDX) begin
            rs_data = block_id;
        end
        else if (rs_addr == REG_BLOCK_DIM) begin
            rs_data = block_dim;
        end
        else if (rs_addr == REG_THREAD_IDX) begin
            rs_data = THREAD_ID;
        end
        else begin
            rs_data = registers[rs_addr];
        end
        
        // Same logic for rt_data
        if (rt_addr == REG_BLOCK_IDX) begin
            rt_data = block_id;
        end
        else if (rt_addr == REG_BLOCK_DIM) begin
            rt_data = block_dim;
        end
        else if (rt_addr == REG_THREAD_IDX) begin
            rt_data = THREAD_ID;
        end
        else begin
            rt_data = registers[rt_addr];
        end
    end
    
    // Write operations (sequential)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            for (int i = 0; i < NUM_REGISTERS-3; i++) begin
                registers[i] <= '0;
            end
        end 
        else if (enable && core_state == UPDATE && reg_write_en) begin
            // Only write to general purpose registers (not special registers)
            if (rd_addr < REG_BLOCK_IDX) begin
                // Select data source based on reg_src
                case (reg_src)
                    REG_SRC_ALU: registers[rd_addr] <= alu_result;
                    REG_SRC_LSU: registers[rd_addr] <= lsu_result;
                    REG_SRC_IMM: registers[rd_addr] <= immediate;
                    default: ; // Do nothing for reserved case
                endcase
            end
        end
    end
    
endmodule 