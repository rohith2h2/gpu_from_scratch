`default_nettype none
`timescale 1ns/1ns

// Import the GPU package with common definitions
import gpu_pkg::*;

// Top-Level GPU Module
// Integrates all components including cores, memory controllers, and dispatcher
// This is the main interface between the external system and the GPU
module gpu #(
    parameter DATA_WIDTH = 8,        // Width of data
    parameter DATA_ADDR_WIDTH = 8,   // Width of data memory address
    parameter DATA_MEM_CHANNELS = 4, // Number of data memory channels
    parameter PROG_ADDR_WIDTH = 8,   // Width of program memory address
    parameter PROG_WIDTH = 16,       // Width of instruction
    parameter PROG_MEM_CHANNELS = 1, // Number of program memory channels
    parameter NUM_CORES = 2,         // Number of compute cores
    parameter THREADS_PER_BLOCK = 4  // Number of threads per block
) (
    input  logic                    clk,
    input  logic                    rst_n,            // Active-low reset
    
    // Kernel execution control
    input  logic                    start,            // Start kernel execution
    output logic                    done,             // Kernel execution complete
    
    // Device control register interface
    input  logic                    dcr_write_enable, // Write enable for control register
    input  logic [DATA_WIDTH-1:0]   dcr_write_data,   // Data to write to control register
    
    // Program memory interface
    output logic [PROG_MEM_CHANNELS-1:0] prog_mem_read_valid, // Program memory read valid
    output logic [PROG_ADDR_WIDTH-1:0]   prog_mem_read_addr [PROG_MEM_CHANNELS-1:0], // Program memory address
    input  logic [PROG_MEM_CHANNELS-1:0] prog_mem_read_ready, // Program memory read ready
    input  logic [PROG_WIDTH-1:0]        prog_mem_read_data [PROG_MEM_CHANNELS-1:0], // Program memory data
    
    // Data memory interface
    output logic [DATA_MEM_CHANNELS-1:0] data_mem_read_valid, // Data memory read valid
    output logic [DATA_ADDR_WIDTH-1:0]   data_mem_read_addr [DATA_MEM_CHANNELS-1:0], // Data memory address
    input  logic [DATA_MEM_CHANNELS-1:0] data_mem_read_ready, // Data memory read ready
    input  logic [DATA_WIDTH-1:0]        data_mem_read_data [DATA_MEM_CHANNELS-1:0], // Data memory data
    
    output logic [DATA_MEM_CHANNELS-1:0] data_mem_write_valid, // Data memory write valid
    output logic [DATA_ADDR_WIDTH-1:0]   data_mem_write_addr [DATA_MEM_CHANNELS-1:0], // Data memory address
    output logic [DATA_WIDTH-1:0]        data_mem_write_data [DATA_MEM_CHANNELS-1:0], // Data memory data
    input  logic [DATA_MEM_CHANNELS-1:0] data_mem_write_ready // Data memory write ready
);

    // Internal signals
    logic [DATA_WIDTH-1:0] thread_count;                // Total number of threads from DCR
    
    // Core control signals
    logic [NUM_CORES-1:0] core_start;                   // Start signal for each core
    logic [NUM_CORES-1:0] core_reset;                   // Reset signal for each core
    logic [NUM_CORES-1:0] core_done;                    // Done signal from each core
    logic [DATA_WIDTH-1:0] core_block_id [NUM_CORES-1:0]; // Block ID for each core
    logic [$clog2(THREADS_PER_BLOCK)+1:0] core_thread_count [NUM_CORES-1:0]; // Threads per block
    
    // Core to memory controller interfaces
    // LSU to Data Memory Controller
    localparam NUM_LSUS = NUM_CORES * THREADS_PER_BLOCK;
    logic [NUM_LSUS-1:0] lsu_read_valid;
    logic [DATA_ADDR_WIDTH-1:0] lsu_read_addr [NUM_LSUS-1:0];
    logic [NUM_LSUS-1:0] lsu_read_ready;
    logic [DATA_WIDTH-1:0] lsu_read_data [NUM_LSUS-1:0];
    logic [NUM_LSUS-1:0] lsu_write_valid;
    logic [DATA_ADDR_WIDTH-1:0] lsu_write_addr [NUM_LSUS-1:0];
    logic [DATA_WIDTH-1:0] lsu_write_data [NUM_LSUS-1:0];
    logic [NUM_LSUS-1:0] lsu_write_ready;
    
    // Fetcher to Program Memory Controller
    localparam NUM_FETCHERS = NUM_CORES;
    logic [NUM_FETCHERS-1:0] fetcher_read_valid;
    logic [PROG_ADDR_WIDTH-1:0] fetcher_read_addr [NUM_FETCHERS-1:0];
    logic [NUM_FETCHERS-1:0] fetcher_read_ready;
    logic [PROG_WIDTH-1:0] fetcher_read_data [NUM_FETCHERS-1:0];
    
    // Device Control Register
    dcr #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dcr_inst (
        .clk(clk),
        .rst_n(rst_n),
        .write_enable(dcr_write_enable),
        .write_data(dcr_write_data),
        .thread_count(thread_count)
    );
    
    // Dispatcher
    dispatch #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_CORES(NUM_CORES),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) dispatch_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .thread_count(thread_count),
        .core_done(core_done),
        .core_start(core_start),
        .core_reset(core_reset),
        .core_block_id(core_block_id),
        .core_block_size(core_thread_count),
        .done(done)
    );
    
    // Data Memory Controller
    controller #(
        .ADDR_WIDTH(DATA_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_CONSUMERS(NUM_LSUS),
        .NUM_CHANNELS(DATA_MEM_CHANNELS),
        .WRITE_ENABLE(1)
    ) data_mem_controller (
        .clk(clk),
        .rst_n(rst_n),
        
        // LSU interface
        .consumer_read_valid(lsu_read_valid),
        .consumer_read_addr(lsu_read_addr),
        .consumer_read_ready(lsu_read_ready),
        .consumer_read_data(lsu_read_data),
        .consumer_write_valid(lsu_write_valid),
        .consumer_write_addr(lsu_write_addr),
        .consumer_write_data(lsu_write_data),
        .consumer_write_ready(lsu_write_ready),
        
        // External memory interface
        .mem_read_valid(data_mem_read_valid),
        .mem_read_addr(data_mem_read_addr),
        .mem_read_ready(data_mem_read_ready),
        .mem_read_data(data_mem_read_data),
        .mem_write_valid(data_mem_write_valid),
        .mem_write_addr(data_mem_write_addr),
        .mem_write_data(data_mem_write_data),
        .mem_write_ready(data_mem_write_ready)
    );
    
    // Program Memory Controller
    controller #(
        .ADDR_WIDTH(PROG_ADDR_WIDTH),
        .DATA_WIDTH(PROG_WIDTH),
        .NUM_CONSUMERS(NUM_FETCHERS),
        .NUM_CHANNELS(PROG_MEM_CHANNELS),
        .WRITE_ENABLE(0)
    ) prog_mem_controller (
        .clk(clk),
        .rst_n(rst_n),
        
        // Fetcher interface
        .consumer_read_valid(fetcher_read_valid),
        .consumer_read_addr(fetcher_read_addr),
        .consumer_read_ready(fetcher_read_ready),
        .consumer_read_data(fetcher_read_data),
        .consumer_write_valid('0),  // No writes to program memory
        .consumer_write_addr('0),
        .consumer_write_data('0),
        .consumer_write_ready(),    // Unused
        
        // External memory interface
        .mem_read_valid(prog_mem_read_valid),
        .mem_read_addr(prog_mem_read_addr),
        .mem_read_ready(prog_mem_read_ready),
        .mem_read_data(prog_mem_read_data),
        .mem_write_valid(),         // Unused
        .mem_write_addr(),
        .mem_write_data(),
        .mem_write_ready('0)        // No writes to program memory
    );
    
    // Compute Cores
    genvar i;
    generate
        for (i = 0; i < NUM_CORES; i = i + 1) begin : cores
            // Core-specific LSU signals
            logic [THREADS_PER_BLOCK-1:0] core_lsu_read_valid;
            logic [DATA_ADDR_WIDTH-1:0] core_lsu_read_addr [THREADS_PER_BLOCK-1:0];
            logic [THREADS_PER_BLOCK-1:0] core_lsu_read_ready;
            logic [DATA_WIDTH-1:0] core_lsu_read_data [THREADS_PER_BLOCK-1:0];
            logic [THREADS_PER_BLOCK-1:0] core_lsu_write_valid;
            logic [DATA_ADDR_WIDTH-1:0] core_lsu_write_addr [THREADS_PER_BLOCK-1:0];
            logic [DATA_WIDTH-1:0] core_lsu_write_data [THREADS_PER_BLOCK-1:0];
            logic [THREADS_PER_BLOCK-1:0] core_lsu_write_ready;
            
            // Connect core LSU signals to global LSU signals
            always_comb begin
                for (int j = 0; j < THREADS_PER_BLOCK; j++) begin
                    // Map local core signals to global LSU array
                    int lsu_index = i * THREADS_PER_BLOCK + j;
                    
                    // Core to LSU connections
                    lsu_read_valid[lsu_index] = core_lsu_read_valid[j];
                    lsu_read_addr[lsu_index] = core_lsu_read_addr[j];
                    lsu_write_valid[lsu_index] = core_lsu_write_valid[j];
                    lsu_write_addr[lsu_index] = core_lsu_write_addr[j];
                    lsu_write_data[lsu_index] = core_lsu_write_data[j];
                    
                    // LSU to core connections
                    core_lsu_read_ready[j] = lsu_read_ready[lsu_index];
                    core_lsu_read_data[j] = lsu_read_data[lsu_index];
                    core_lsu_write_ready[j] = lsu_write_ready[lsu_index];
                end
            end
            
            // Compute Core Instance
            core #(
                .DATA_WIDTH(DATA_WIDTH),
                .ADDR_WIDTH(DATA_ADDR_WIDTH),
                .INSTR_WIDTH(PROG_WIDTH),
                .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
            ) core_inst (
                .clk(clk),
                .rst_n(core_reset[i]),        // Core-specific reset
                .start(core_start[i]),        // Core-specific start
                .done(core_done[i]),          // Core-specific done
                
                // Block metadata
                .block_id(core_block_id[i]),
                .thread_count(core_thread_count[i]),
                
                // Program memory interface
                .prog_mem_read_valid(fetcher_read_valid[i]),
                .prog_mem_read_addr(fetcher_read_addr[i]),
                .prog_mem_read_ready(fetcher_read_ready[i]),
                .prog_mem_read_data(fetcher_read_data[i]),
                
                // Data memory interface
                .data_mem_read_valid(core_lsu_read_valid),
                .data_mem_read_addr(core_lsu_read_addr),
                .data_mem_read_ready(core_lsu_read_ready),
                .data_mem_read_data(core_lsu_read_data),
                .data_mem_write_valid(core_lsu_write_valid),
                .data_mem_write_addr(core_lsu_write_addr),
                .data_mem_write_data(core_lsu_write_data),
                .data_mem_write_ready(core_lsu_write_ready)
            );
        end
    endgenerate
    
endmodule 