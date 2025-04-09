`default_nettype none
`timescale 1ns/1ns

// Import the GPU package with common definitions
import gpu_pkg::*;

// Instruction Fetcher
// Retrieves instructions from program memory based on the program counter
// Handles asynchronous memory requests
module fetcher #(
    parameter ADDR_WIDTH = 8,      // Width of program memory address
    parameter INSTR_WIDTH = 16     // Width of instructions
) (
    input  logic                    clk,
    input  logic                    rst_n,            // Active-low reset
    
    // Core state and program counter
    input  core_state_t             core_state,       // Current state of the core
    input  logic [ADDR_WIDTH-1:0]   current_pc,       // Current program counter value
    
    // Program memory interface
    output logic                    prog_mem_read_valid, // Valid program memory read request
    output logic [ADDR_WIDTH-1:0]   prog_mem_read_addr,  // Program memory address to read
    input  logic                    prog_mem_read_ready, // Program memory read response ready
    input  logic [INSTR_WIDTH-1:0]  prog_mem_read_data,  // Program memory read data
    
    // Fetcher outputs
    output logic [2:0]              fetcher_state,    // Current state of the fetcher
    output logic [INSTR_WIDTH-1:0]  instruction       // Fetched instruction
);

    // Fetcher states
    typedef enum logic [2:0] {
        FETCH_IDLE = 3'd0,
        FETCH_REQUESTING = 3'd1,
        FETCH_WAITING = 3'd2,
        FETCH_DONE = 3'd3
    } fetcher_state_t;
    
    // Internal state tracking
    fetcher_state_t current_state;
    logic [INSTR_WIDTH-1:0] instruction_reg;
    
    // Assign outputs
    assign fetcher_state = current_state;
    assign instruction = instruction_reg;
    
    // Instruction fetching state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            current_state <= FETCH_IDLE;
            instruction_reg <= '0;
            prog_mem_read_valid <= 1'b0;
            prog_mem_read_addr <= '0;
        end
        else begin
            case (current_state)
                FETCH_IDLE: begin
                    // Start fetch when core enters FETCH state
                    if (core_state == FETCH) begin
                        current_state <= FETCH_REQUESTING;
                    end
                end
                
                FETCH_REQUESTING: begin
                    // Send read request to program memory
                    prog_mem_read_valid <= 1'b1;
                    prog_mem_read_addr <= current_pc;
                    current_state <= FETCH_WAITING;
                end
                
                FETCH_WAITING: begin
                    // Wait for program memory response
                    if (prog_mem_read_ready) begin
                        // Instruction received
                        prog_mem_read_valid <= 1'b0;
                        instruction_reg <= prog_mem_read_data;
                        current_state <= FETCH_DONE;
                    end
                end
                
                FETCH_DONE: begin
                    // Reset when core leaves FETCH state
                    if (core_state != FETCH) begin
                        current_state <= FETCH_IDLE;
                    end
                end
                
                default: begin
                    current_state <= FETCH_IDLE;
                end
            endcase
        end
    end
    
endmodule 