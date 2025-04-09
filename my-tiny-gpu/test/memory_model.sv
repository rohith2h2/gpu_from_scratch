`default_nettype none
`timescale 1ns/1ns

// Memory Model
// Provides a behavioral model of external memory for simulation
// Supports both program memory and data memory configurations
module memory_model #(
    parameter ADDR_WIDTH = 8,      // Width of memory address
    parameter DATA_WIDTH = 8,      // Width of data
    parameter NUM_CHANNELS = 4,    // Number of parallel access channels
    parameter DEPTH = 256,         // Memory depth
    parameter READ_LATENCY = 2,    // Cycles of latency for read operations
    parameter WRITE_LATENCY = 2    // Cycles of latency for write operations
) (
    input  logic                    clk,
    input  logic                    rst_n,  // Active-low reset
    
    // Read port
    input  logic [NUM_CHANNELS-1:0] read_valid,
    input  logic [ADDR_WIDTH-1:0]   read_addr [NUM_CHANNELS-1:0],
    output logic [NUM_CHANNELS-1:0] read_ready,
    output logic [DATA_WIDTH-1:0]   read_data [NUM_CHANNELS-1:0],
    
    // Write port
    input  logic [NUM_CHANNELS-1:0] write_valid,
    input  logic [ADDR_WIDTH-1:0]   write_addr [NUM_CHANNELS-1:0],
    input  logic [DATA_WIDTH-1:0]   write_data [NUM_CHANNELS-1:0],
    output logic [NUM_CHANNELS-1:0] write_ready
);

    // Memory array
    logic [DATA_WIDTH-1:0] memory [DEPTH-1:0];
    
    // Read pipeline registers
    typedef struct {
        logic valid;
        logic [ADDR_WIDTH-1:0] addr;
        logic [READ_LATENCY-1:0] counter;
    } read_req_t;
    
    read_req_t read_reqs [NUM_CHANNELS-1:0];
    
    // Write pipeline registers
    typedef struct {
        logic valid;
        logic [ADDR_WIDTH-1:0] addr;
        logic [DATA_WIDTH-1:0] data;
        logic [WRITE_LATENCY-1:0] counter;
    } write_req_t;
    
    write_req_t write_reqs [NUM_CHANNELS-1:0];
    
    // Memory initialization function
    task initialize_memory(input logic [DATA_WIDTH-1:0] init_data [DEPTH-1:0]);
        for (int i = 0; i < DEPTH; i++) begin
            memory[i] = init_data[i];
        end
    endtask
    
    // Memory operation logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                read_reqs[i].valid <= 1'b0;
                read_reqs[i].counter <= '0;
                read_ready[i] <= 1'b0;
                read_data[i] <= '0;
                
                write_reqs[i].valid <= 1'b0;
                write_reqs[i].counter <= '0;
                write_ready[i] <= 1'b0;
            end
        end
        else begin
            // Process read requests
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                // Clear ready signal after one cycle
                read_ready[i] <= 1'b0;
                
                // Process new read request
                if (read_valid[i] && !read_reqs[i].valid) begin
                    read_reqs[i].valid <= 1'b1;
                    read_reqs[i].addr <= read_addr[i];
                    read_reqs[i].counter <= READ_LATENCY - 1;
                end
                
                // Process pending read request
                if (read_reqs[i].valid) begin
                    if (read_reqs[i].counter == 0) begin
                        // Read is complete, return data
                        read_data[i] <= memory[read_reqs[i].addr];
                        read_ready[i] <= 1'b1;
                        read_reqs[i].valid <= 1'b0;
                    end
                    else begin
                        // Decrement latency counter
                        read_reqs[i].counter <= read_reqs[i].counter - 1;
                    end
                end
            end
            
            // Process write requests
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                // Clear ready signal after one cycle
                write_ready[i] <= 1'b0;
                
                // Process new write request
                if (write_valid[i] && !write_reqs[i].valid) begin
                    write_reqs[i].valid <= 1'b1;
                    write_reqs[i].addr <= write_addr[i];
                    write_reqs[i].data <= write_data[i];
                    write_reqs[i].counter <= WRITE_LATENCY - 1;
                end
                
                // Process pending write request
                if (write_reqs[i].valid) begin
                    if (write_reqs[i].counter == 0) begin
                        // Write is complete, update memory
                        memory[write_reqs[i].addr] <= write_reqs[i].data;
                        write_ready[i] <= 1'b1;
                        write_reqs[i].valid <= 1'b0;
                    end
                    else begin
                        // Decrement latency counter
                        write_reqs[i].counter <= write_reqs[i].counter - 1;
                    end
                end
            end
        end
    end
    
endmodule 