`default_nettype none
`timescale 1ns/1ns

// Import the GPU package with common definitions
import gpu_pkg::*;

// Scheduler
// Manages the execution flow of the core through different states
// Controls the progression of instructions through the pipeline
// Synchronizes all threads within a block
module scheduler #(
    parameter ADDR_WIDTH = 8,       // Width of program memory address
    parameter THREADS_PER_BLOCK = 4 // Number of threads per block
) (
    input  logic                    clk,
    input  logic                    rst_n,            // Active-low reset
    input  logic                    start,            // Start execution signal
    
    // Control inputs
    input  logic [2:0]              fetcher_state,    // Current state of the fetcher
    input  logic                    mem_read_en,      // Memory read enable
    input  logic                    mem_write_en,     // Memory write enable
    input  logic                    is_ret,           // Return from kernel
    input  lsu_state_t              lsu_state [THREADS_PER_BLOCK-1:0], // States of all LSUs
    
    // Program counter
    input  logic [ADDR_WIDTH-1:0]   next_pc [THREADS_PER_BLOCK-1:0], // Next PC values from all threads
    output logic [ADDR_WIDTH-1:0]   current_pc,       // Current program counter
    
    // Core state output
    output core_state_t             core_state,       // Current core state
    output logic                    done              // Execution complete signal
);

    // Internal signals
    core_state_t next_state;
    logic all_lsus_done;
    logic any_thread_ret;
    logic [ADDR_WIDTH-1:0] pc_reg;
    
    // Calculate if all LSUs are done with their operations
    always_comb begin
        all_lsus_done = 1'b1;
        for (int i = 0; i < THREADS_PER_BLOCK; i++) begin
            if ((mem_read_en || mem_write_en) && lsu_state[i] != LSU_DONE) begin
                all_lsus_done = 1'b0;
            end
        end
    end
    
    // Check if any thread has executed a RET instruction
    always_comb begin
        any_thread_ret = is_ret;
    end
    
    // Current PC value
    assign current_pc = pc_reg;
    
    // Core state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            core_state <= IDLE;
            done <= 1'b0;
            pc_reg <= '0;
        end
        else begin
            // State transitions
            case (core_state)
                IDLE: begin
                    // Wait for start signal
                    if (start) begin
                        core_state <= FETCH;
                        done <= 1'b0;
                        pc_reg <= '0;  // Start execution at address 0
                    end
                end
                
                FETCH: begin
                    // Fetch instruction from program memory
                    if (fetcher_state == 3'd3) begin  // FETCH_DONE state
                        core_state <= DECODE;
                    end
                end
                
                DECODE: begin
                    // Decode instruction
                    core_state <= REQUEST;
                end
                
                REQUEST: begin
                    // Initiate memory requests if needed
                    if (mem_read_en || mem_write_en) begin
                        core_state <= WAIT;
                    end
                    else begin
                        // Skip WAIT state if no memory operation
                        core_state <= EXECUTE;
                    end
                end
                
                WAIT: begin
                    // Wait for memory operations to complete
                    if (all_lsus_done) begin
                        core_state <= EXECUTE;
                    end
                end
                
                EXECUTE: begin
                    // Execute ALU operations
                    core_state <= UPDATE;
                end
                
                UPDATE: begin
                    // Update registers and prepare for next instruction
                    if (any_thread_ret) begin
                        // Return from kernel
                        core_state <= IDLE;
                        done <= 1'b1;
                    end
                    else begin
                        // Continue with next instruction
                        core_state <= FETCH;
                        // Assume all threads converge to the same PC (no branch divergence)
                        pc_reg <= next_pc[0];
                    end
                end
                
                default: begin
                    core_state <= IDLE;
                end
            endcase
        end
    end
    
endmodule 