`default_nettype none
`timescale 1ns/1ns

// Import the GPU package with common definitions
import gpu_pkg::*;

// Compute Core
// A single compute core that processes one block of threads at a time
// Contains a scheduler, fetcher, decoder, and dedicated resources for each thread
module core #(
    parameter DATA_WIDTH = 8,       // Width of data
    parameter ADDR_WIDTH = 8,       // Width of memory address
    parameter INSTR_WIDTH = 16,     // Width of instruction
    parameter THREADS_PER_BLOCK = 4 // Number of threads per block
) (
    input  logic                    clk,
    input  logic                    rst_n,             // Active-low reset
    
    // Kernel execution control
    input  logic                    start,             // Start signal
    output logic                    done,              // Block execution complete
    
    // Block metadata
    input  logic [DATA_WIDTH-1:0]   block_id,          // ID of the block being processed
    input  logic [$clog2(THREADS_PER_BLOCK)+1:0] thread_count, // Number of threads in this block
    
    // Program memory interface
    output logic                    prog_mem_read_valid, // Program memory read valid
    output logic [ADDR_WIDTH-1:0]   prog_mem_read_addr,  // Program memory address
    input  logic                    prog_mem_read_ready, // Program memory read ready
    input  logic [INSTR_WIDTH-1:0]  prog_mem_read_data,  // Program memory data
    
    // Data memory interface
    output logic [THREADS_PER_BLOCK-1:0] data_mem_read_valid, // Data memory read valid
    output logic [ADDR_WIDTH-1:0]   data_mem_read_addr [THREADS_PER_BLOCK-1:0], // Data memory address
    input  logic [THREADS_PER_BLOCK-1:0] data_mem_read_ready, // Data memory read ready
    input  logic [DATA_WIDTH-1:0]   data_mem_read_data [THREADS_PER_BLOCK-1:0], // Data memory data
    
    output logic [THREADS_PER_BLOCK-1:0] data_mem_write_valid, // Data memory write valid
    output logic [ADDR_WIDTH-1:0]   data_mem_write_addr [THREADS_PER_BLOCK-1:0], // Data memory address
    output logic [DATA_WIDTH-1:0]   data_mem_write_data [THREADS_PER_BLOCK-1:0], // Data memory data
    input  logic [THREADS_PER_BLOCK-1:0] data_mem_write_ready // Data memory write ready
);

    // Internal signals
    core_state_t core_state;                  // Current state of the core
    logic [2:0] fetcher_state;                // Current state of the fetcher
    logic [INSTR_WIDTH-1:0] instruction;      // Current instruction
    
    // Program counter signals
    logic [ADDR_WIDTH-1:0] current_pc;        // Current program counter
    logic [ADDR_WIDTH-1:0] next_pc [THREADS_PER_BLOCK-1:0]; // Next PC from each thread
    
    // Decoder outputs
    logic [3:0] rd_addr;                      // Destination register address
    logic [3:0] rs_addr;                      // Source register 1 address
    logic [3:0] rt_addr;                      // Source register 2 address
    logic [2:0] branch_condition;             // Branch condition (NZP bits)
    logic [DATA_WIDTH-1:0] immediate;         // Immediate value
    
    // Control signals
    logic reg_write_en;                       // Register write enable
    logic mem_read_en;                        // Memory read enable
    logic mem_write_en;                       // Memory write enable
    logic nzp_write_en;                       // NZP register write enable
    reg_src_t reg_src;                        // Source for register write
    alu_op_t alu_op;                          // ALU operation
    logic is_compare;                         // Is this a comparison operation
    logic branch_enable;                      // Enable branch operations
    logic is_ret;                             // Return from kernel
    
    // Thread-specific signals
    logic [DATA_WIDTH-1:0] rs_data [THREADS_PER_BLOCK-1:0]; // Data from source register 1
    logic [DATA_WIDTH-1:0] rt_data [THREADS_PER_BLOCK-1:0]; // Data from source register 2
    logic [DATA_WIDTH-1:0] alu_result [THREADS_PER_BLOCK-1:0]; // Result from ALU
    logic [DATA_WIDTH-1:0] lsu_result [THREADS_PER_BLOCK-1:0]; // Result from LSU
    lsu_state_t lsu_state [THREADS_PER_BLOCK-1:0]; // State of each LSU
    
    // Instruction Fetcher
    fetcher #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .INSTR_WIDTH(INSTR_WIDTH)
    ) fetcher_inst (
        .clk(clk),
        .rst_n(rst_n),
        .core_state(core_state),
        .current_pc(current_pc),
        .prog_mem_read_valid(prog_mem_read_valid),
        .prog_mem_read_addr(prog_mem_read_addr),
        .prog_mem_read_ready(prog_mem_read_ready),
        .prog_mem_read_data(prog_mem_read_data),
        .fetcher_state(fetcher_state),
        .instruction(instruction)
    );
    
    // Instruction Decoder
    decoder #(
        .INSTR_WIDTH(INSTR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) decoder_inst (
        .clk(clk),
        .rst_n(rst_n),
        .core_state(core_state),
        .instruction(instruction),
        .rd_addr(rd_addr),
        .rs_addr(rs_addr),
        .rt_addr(rt_addr),
        .branch_condition(branch_condition),
        .immediate(immediate),
        .reg_write_en(reg_write_en),
        .mem_read_en(mem_read_en),
        .mem_write_en(mem_write_en),
        .nzp_write_en(nzp_write_en),
        .reg_src(reg_src),
        .alu_op(alu_op),
        .is_compare(is_compare),
        .branch_enable(branch_enable),
        .is_ret(is_ret)
    );
    
    // Core Scheduler
    scheduler #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) scheduler_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .fetcher_state(fetcher_state),
        .mem_read_en(mem_read_en),
        .mem_write_en(mem_write_en),
        .is_ret(is_ret),
        .lsu_state(lsu_state),
        .next_pc(next_pc),
        .current_pc(current_pc),
        .core_state(core_state),
        .done(done)
    );
    
    // Generate thread processing units
    genvar i;
    generate
        for (i = 0; i < THREADS_PER_BLOCK; i = i + 1) begin : thread_units
            // Thread enable signal based on thread count
            logic thread_enable;
            assign thread_enable = (i < thread_count);
            
            // ALU (Arithmetic Logic Unit)
            alu #(
                .DATA_WIDTH(DATA_WIDTH)
            ) alu_inst (
                .clk(clk),
                .rst_n(rst_n),
                .enable(thread_enable),
                .core_state(core_state),
                .alu_op(alu_op),
                .is_compare(is_compare),
                .rs_data(rs_data[i]),
                .rt_data(rt_data[i]),
                .alu_out(alu_result[i])
            );
            
            // LSU (Load-Store Unit)
            lsu #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH)
            ) lsu_inst (
                .clk(clk),
                .rst_n(rst_n),
                .enable(thread_enable),
                .core_state(core_state),
                .mem_read_en(mem_read_en),
                .mem_write_en(mem_write_en),
                .rs_data(rs_data[i]),
                .rt_data(rt_data[i]),
                .mem_read_valid(data_mem_read_valid[i]),
                .mem_read_addr(data_mem_read_addr[i]),
                .mem_read_ready(data_mem_read_ready[i]),
                .mem_read_data(data_mem_read_data[i]),
                .mem_write_valid(data_mem_write_valid[i]),
                .mem_write_addr(data_mem_write_addr[i]),
                .mem_write_data(data_mem_write_data[i]),
                .mem_write_ready(data_mem_write_ready[i]),
                .lsu_state(lsu_state[i]),
                .lsu_out(lsu_result[i])
            );
            
            // Register File
            registers #(
                .DATA_WIDTH(DATA_WIDTH),
                .THREAD_ID(i)
            ) registers_inst (
                .clk(clk),
                .rst_n(rst_n),
                .enable(thread_enable),
                .block_id(block_id),
                .block_dim(thread_count),
                .core_state(core_state),
                .reg_write_en(reg_write_en),
                .reg_src(reg_src),
                .rd_addr(rd_addr),
                .rs_addr(rs_addr),
                .rt_addr(rt_addr),
                .immediate(immediate),
                .alu_result(alu_result[i]),
                .lsu_result(lsu_result[i]),
                .rs_data(rs_data[i]),
                .rt_data(rt_data[i])
            );
            
            // PC (Program Counter)
            pc #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH)
            ) pc_inst (
                .clk(clk),
                .rst_n(rst_n),
                .enable(thread_enable),
                .core_state(core_state),
                .branch_enable(branch_enable),
                .nzp_write_enable(nzp_write_en),
                .branch_condition(branch_condition),
                .alu_result(alu_result[i]),
                .branch_target(immediate),
                .current_pc(current_pc),
                .next_pc(next_pc[i])
            );
        end
    endgenerate
    
endmodule 