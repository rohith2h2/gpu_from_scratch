`default_nettype none
`timescale 1ns/1ns

// Import the GPU package with common definitions
import gpu_pkg::*;

// LSU (Load-Store Unit)
// Handles memory read and write operations for a single thread
// Each thread has its own dedicated LSU
// Memory operations are asynchronous, requiring state tracking
module lsu #(
    parameter ADDR_WIDTH = 8,  // Width of memory address
    parameter DATA_WIDTH = 8   // Width of the data being processed
) (
    input  logic                    clk,
    input  logic                    rst_n,        // Active-low reset
    input  logic                    enable,       // Enable signal for this LSU
    
    // State and control signals
    input  core_state_t             core_state,   // Current state of the core
    input  logic                    mem_read_en,  // Memory read enable
    input  logic                    mem_write_en, // Memory write enable
    
    // Data inputs
    input  logic [DATA_WIDTH-1:0]   rs_data,      // Source register 1 data (address)
    input  logic [DATA_WIDTH-1:0]   rt_data,      // Source register 2 data (write data)
    
    // Memory interface
    output logic                    mem_read_valid,  // Valid memory read request
    output logic [ADDR_WIDTH-1:0]   mem_read_addr,   // Memory read address
    input  logic                    mem_read_ready,  // Memory read response ready
    input  logic [DATA_WIDTH-1:0]   mem_read_data,   // Memory read data
    
    output logic                    mem_write_valid, // Valid memory write request
    output logic [ADDR_WIDTH-1:0]   mem_write_addr,  // Memory write address
    output logic [DATA_WIDTH-1:0]   mem_write_data,  // Memory write data
    input  logic                    mem_write_ready, // Memory write response ready
    
    // Outputs
    output lsu_state_t              lsu_state,    // Current state of this LSU
    output logic [DATA_WIDTH-1:0]   lsu_out       // Data output from LSU
);

    // LSU state and data registers
    lsu_state_t current_state;
    logic [DATA_WIDTH-1:0] data_reg;
    
    // Assign outputs
    assign lsu_state = current_state;
    assign lsu_out = data_reg;
    
    // Memory operation state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            current_state <= LSU_IDLE;
            data_reg <= '0;
            mem_read_valid <= 1'b0;
            mem_read_addr <= '0;
            mem_write_valid <= 1'b0;
            mem_write_addr <= '0;
            mem_write_data <= '0;
        end 
        else if (enable) begin
            // Handle memory read operations
            if (mem_read_en) begin
                case (current_state)
                    LSU_IDLE: begin
                        // Start memory read in REQUEST state
                        if (core_state == REQUEST) begin
                            current_state <= LSU_REQUESTING;
                        end
                    end
                    
                    LSU_REQUESTING: begin
                        // Send read request to memory
                        mem_read_valid <= 1'b1;
                        mem_read_addr <= rs_data; // Use rs_data as address
                        current_state <= LSU_WAITING;
                    end
                    
                    LSU_WAITING: begin
                        // Wait for read response
                        if (mem_read_ready) begin
                            // Read data received
                            mem_read_valid <= 1'b0;
                            data_reg <= mem_read_data;
                            current_state <= LSU_DONE;
                        end
                    end
                    
                    LSU_DONE: begin
                        // Reset operation when core moves to UPDATE state
                        if (core_state == UPDATE) begin
                            current_state <= LSU_IDLE;
                        end
                    end
                endcase
            end
            
            // Handle memory write operations
            if (mem_write_en) begin
                case (current_state)
                    LSU_IDLE: begin
                        // Start memory write in REQUEST state
                        if (core_state == REQUEST) begin
                            current_state <= LSU_REQUESTING;
                        end
                    end
                    
                    LSU_REQUESTING: begin
                        // Send write request to memory
                        mem_write_valid <= 1'b1;
                        mem_write_addr <= rs_data;  // Use rs_data as address
                        mem_write_data <= rt_data;  // Use rt_data as data to write
                        current_state <= LSU_WAITING;
                    end
                    
                    LSU_WAITING: begin
                        // Wait for write completion
                        if (mem_write_ready) begin
                            // Write completed
                            mem_write_valid <= 1'b0;
                            current_state <= LSU_DONE;
                        end
                    end
                    
                    LSU_DONE: begin
                        // Reset operation when core moves to UPDATE state
                        if (core_state == UPDATE) begin
                            current_state <= LSU_IDLE;
                        end
                    end
                endcase
            end
        end
    end
    
endmodule 