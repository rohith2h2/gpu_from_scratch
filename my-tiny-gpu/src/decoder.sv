`default_nettype none
`timescale 1ns/1ns

// Import the GPU package with common definitions
import gpu_pkg::*;

// Instruction Decoder
// Converts raw instruction bits into control signals for the CPU
// Extracts fields like opcode, register addresses, and immediate values
// Generates control signals for all units based on the instruction type
module decoder #(
    parameter INSTR_WIDTH = 16,  // Width of instructions
    parameter DATA_WIDTH = 8     // Width of data
) (
    input  logic                    clk,
    input  logic                    rst_n,          // Active-low reset
    
    // Core state and instruction
    input  core_state_t             core_state,     // Current state of the core
    input  logic [INSTR_WIDTH-1:0]  instruction,    // Instruction to decode
    
    // Decoded instruction fields
    output logic [3:0]              rd_addr,        // Destination register address
    output logic [3:0]              rs_addr,        // Source register 1 address
    output logic [3:0]              rt_addr,        // Source register 2 address
    output logic [2:0]              branch_condition, // Branch condition (NZP bits)
    output logic [DATA_WIDTH-1:0]   immediate,      // Immediate value
    
    // Control signals
    output logic                    reg_write_en,   // Register write enable
    output logic                    mem_read_en,    // Memory read enable
    output logic                    mem_write_en,   // Memory write enable
    output logic                    nzp_write_en,   // NZP register write enable
    output reg_src_t                reg_src,        // Source for register write
    output alu_op_t                 alu_op,         // ALU operation
    output logic                    is_compare,     // Is this a comparison operation
    output logic                    branch_enable,  // Enable branch operations
    output logic                    is_ret          // Return from kernel
);

    // Instruction fields
    logic [3:0] opcode;
    
    // Temporary signals for pipeline registers
    logic reg_write_en_tmp;
    logic mem_read_en_tmp;
    logic mem_write_en_tmp;
    logic nzp_write_en_tmp;
    reg_src_t reg_src_tmp;
    alu_op_t alu_op_tmp;
    logic is_compare_tmp;
    logic branch_enable_tmp;
    logic is_ret_tmp;
    
    // Parse instruction fields - combinational logic
    always_comb begin
        // Extract main instruction fields
        opcode = instruction[15:12];
        rd_addr = instruction[11:8];
        rs_addr = instruction[7:4];
        rt_addr = instruction[3:0];
        
        // Extract immediate value (for CONST and BR instructions)
        immediate = instruction[7:0];  // Lower 8 bits
        
        // Extract branch condition (for BR instruction)
        branch_condition = instruction[10:8];  // N, Z, P bits
        
        // Default control signal values
        reg_write_en_tmp = 1'b0;
        mem_read_en_tmp = 1'b0;
        mem_write_en_tmp = 1'b0;
        nzp_write_en_tmp = 1'b0;
        reg_src_tmp = REG_SRC_ALU;
        alu_op_tmp = ALU_ADD;
        is_compare_tmp = 1'b0;
        branch_enable_tmp = 1'b0;
        is_ret_tmp = 1'b0;
        
        // Determine control signals based on opcode
        case (opcode)
            OPCODE_ADD: begin
                // ADD Rd, Rs, Rt
                reg_write_en_tmp = 1'b1;   // Write to register
                reg_src_tmp = REG_SRC_ALU; // Use ALU result
                alu_op_tmp = ALU_ADD;     // Perform addition
            end
            
            OPCODE_SUB: begin
                // SUB Rd, Rs, Rt
                reg_write_en_tmp = 1'b1;   // Write to register
                reg_src_tmp = REG_SRC_ALU; // Use ALU result
                alu_op_tmp = ALU_SUB;     // Perform subtraction
            end
            
            OPCODE_MUL: begin
                // MUL Rd, Rs, Rt
                reg_write_en_tmp = 1'b1;   // Write to register
                reg_src_tmp = REG_SRC_ALU; // Use ALU result
                alu_op_tmp = ALU_MUL;     // Perform multiplication
            end
            
            OPCODE_DIV: begin
                // DIV Rd, Rs, Rt
                reg_write_en_tmp = 1'b1;   // Write to register
                reg_src_tmp = REG_SRC_ALU; // Use ALU result
                alu_op_tmp = ALU_DIV;     // Perform division
            end
            
            OPCODE_LDR: begin
                // LDR Rd, Rs
                reg_write_en_tmp = 1'b1;   // Write to register
                reg_src_tmp = REG_SRC_LSU; // Use LSU result
                mem_read_en_tmp = 1'b1;    // Read from memory
            end
            
            OPCODE_STR: begin
                // STR Rs, Rt
                mem_write_en_tmp = 1'b1;   // Write to memory
            end
            
            OPCODE_CONST: begin
                // CONST Rd, #imm
                reg_write_en_tmp = 1'b1;   // Write to register
                reg_src_tmp = REG_SRC_IMM; // Use immediate value
            end
            
            OPCODE_CMP: begin
                // CMP Rs, Rt
                is_compare_tmp = 1'b1;     // Perform comparison
                nzp_write_en_tmp = 1'b1;   // Update NZP register
            end
            
            OPCODE_BR: begin
                // BRnzp #imm
                branch_enable_tmp = 1'b1;  // Enable branching
            end
            
            OPCODE_RET: begin
                // RET
                is_ret_tmp = 1'b1;         // Return from kernel
            end
            
            default: begin
                // Unknown opcode - all control signals default to 0
            end
        endcase
    end
    
    // Register control signals (pipeline registers)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all control signals
            reg_write_en <= 1'b0;
            mem_read_en <= 1'b0;
            mem_write_en <= 1'b0;
            nzp_write_en <= 1'b0;
            reg_src <= REG_SRC_ALU;
            alu_op <= ALU_ADD;
            is_compare <= 1'b0;
            branch_enable <= 1'b0;
            is_ret <= 1'b0;
        end
        else if (core_state == DECODE) begin
            // Update control signals in DECODE state
            reg_write_en <= reg_write_en_tmp;
            mem_read_en <= mem_read_en_tmp;
            mem_write_en <= mem_write_en_tmp;
            nzp_write_en <= nzp_write_en_tmp;
            reg_src <= reg_src_tmp;
            alu_op <= alu_op_tmp;
            is_compare <= is_compare_tmp;
            branch_enable <= branch_enable_tmp;
            is_ret <= is_ret_tmp;
        end
    end
    
endmodule 