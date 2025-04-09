`default_nettype none
`timescale 1ns/1ns

// Memory Controller
// Manages access to external memory from multiple cores
// Arbitrates between multiple consumer requests and routes them to available memory channels
// Handles both read and write operations
module controller #(
    parameter ADDR_WIDTH = 8,      // Width of memory address
    parameter DATA_WIDTH = 8,      // Width of the data
    parameter NUM_CONSUMERS = 8,   // Number of cores/threads accessing memory
    parameter NUM_CHANNELS = 4,    // Number of parallel memory channels
    parameter WRITE_ENABLE = 1     // Whether write operations are enabled
) (
    input  logic                    clk,
    input  logic                    rst_n,              // Active-low reset
    
    // Consumer (core) interface
    input  logic [NUM_CONSUMERS-1:0]                 consumer_read_valid,   // Read request valid
    input  logic [ADDR_WIDTH-1:0]                    consumer_read_addr [NUM_CONSUMERS-1:0], // Read addresses
    output logic [NUM_CONSUMERS-1:0]                 consumer_read_ready,   // Read response ready
    output logic [DATA_WIDTH-1:0]                    consumer_read_data [NUM_CONSUMERS-1:0], // Read data
    
    input  logic [NUM_CONSUMERS-1:0]                 consumer_write_valid,  // Write request valid
    input  logic [ADDR_WIDTH-1:0]                    consumer_write_addr [NUM_CONSUMERS-1:0], // Write addresses
    input  logic [DATA_WIDTH-1:0]                    consumer_write_data [NUM_CONSUMERS-1:0], // Write data
    output logic [NUM_CONSUMERS-1:0]                 consumer_write_ready,  // Write complete
    
    // External memory interface
    output logic [NUM_CHANNELS-1:0]                  mem_read_valid,        // Memory read valid
    output logic [ADDR_WIDTH-1:0]                    mem_read_addr [NUM_CHANNELS-1:0], // Memory read addresses
    input  logic [NUM_CHANNELS-1:0]                  mem_read_ready,        // Memory read response ready
    input  logic [DATA_WIDTH-1:0]                    mem_read_data [NUM_CHANNELS-1:0], // Memory read data
    
    output logic [NUM_CHANNELS-1:0]                  mem_write_valid,       // Memory write valid
    output logic [ADDR_WIDTH-1:0]                    mem_write_addr [NUM_CHANNELS-1:0], // Memory write addresses
    output logic [DATA_WIDTH-1:0]                    mem_write_data [NUM_CHANNELS-1:0], // Memory write data
    input  logic [NUM_CHANNELS-1:0]                  mem_write_ready        // Memory write complete
);

    // Request queue for managing pending memory operations
    typedef struct packed {
        logic                    valid;     // Valid entry
        logic                    is_write;  // Is this a write operation
        logic [$clog2(NUM_CONSUMERS)-1:0] consumer_id; // Source consumer ID
        logic [ADDR_WIDTH-1:0]   addr;      // Memory address
        logic [DATA_WIDTH-1:0]   data;      // Write data (for write operations)
    } request_t;
    
    // Queue state
    request_t request_queue [NUM_CHANNELS-1:0];
    logic [NUM_CHANNELS-1:0] channel_busy;
    
    // Arbitration state
    logic [$clog2(NUM_CONSUMERS)-1:0] read_arbiter;
    logic [$clog2(NUM_CONSUMERS)-1:0] write_arbiter;
    
    // Process memory requests and responses
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            read_arbiter <= '0;
            write_arbiter <= '0;
            
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                request_queue[i].valid <= 1'b0;
                channel_busy[i] <= 1'b0;
                mem_read_valid[i] <= 1'b0;
                mem_write_valid[i] <= 1'b0;
            end
            
            for (int i = 0; i < NUM_CONSUMERS; i++) begin
                consumer_read_ready[i] <= 1'b0;
                consumer_read_data[i] <= '0;
                consumer_write_ready[i] <= 1'b0;
            end
        end
        else begin
            // Handle read responses
            for (int i = 0; i < NUM_CHANNELS; i++) begin
                if (mem_read_ready[i]) begin
                    // Memory read response received
                    mem_read_valid[i] <= 1'b0;
                    
                    if (request_queue[i].valid && !request_queue[i].is_write) begin
                        // Forward read data to the requesting consumer
                        consumer_read_data[request_queue[i].consumer_id] <= mem_read_data[i];
                        consumer_read_ready[request_queue[i].consumer_id] <= 1'b1;
                        
                        // Free the channel
                        request_queue[i].valid <= 1'b0;
                        channel_busy[i] <= 1'b0;
                    end
                end
                
                // Clear read ready signal after one cycle
                for (int j = 0; j < NUM_CONSUMERS; j++) begin
                    if (consumer_read_ready[j]) begin
                        consumer_read_ready[j] <= 1'b0;
                    end
                end
            end
            
            // Handle write responses
            if (WRITE_ENABLE) begin
                for (int i = 0; i < NUM_CHANNELS; i++) begin
                    if (mem_write_ready[i]) begin
                        // Memory write completed
                        mem_write_valid[i] <= 1'b0;
                        
                        if (request_queue[i].valid && request_queue[i].is_write) begin
                            // Notify the requesting consumer that write is complete
                            consumer_write_ready[request_queue[i].consumer_id] <= 1'b1;
                            
                            // Free the channel
                            request_queue[i].valid <= 1'b0;
                            channel_busy[i] <= 1'b0;
                        end
                    end
                end
                
                // Clear write ready signal after one cycle
                for (int j = 0; j < NUM_CONSUMERS; j++) begin
                    if (consumer_write_ready[j]) begin
                        consumer_write_ready[j] <= 1'b0;
                    end
                end
            end
            
            // Process new read requests with round-robin arbitration
            for (int i = 0; i < NUM_CONSUMERS; i++) begin
                int consumer = (read_arbiter + i) % NUM_CONSUMERS;
                
                if (consumer_read_valid[consumer]) begin
                    // Find an available channel
                    for (int j = 0; j < NUM_CHANNELS; j++) begin
                        if (!channel_busy[j]) begin
                            // Assign request to this channel
                            request_queue[j].valid <= 1'b1;
                            request_queue[j].is_write <= 1'b0;
                            request_queue[j].consumer_id <= consumer;
                            request_queue[j].addr <= consumer_read_addr[consumer];
                            
                            // Send read request to memory
                            mem_read_valid[j] <= 1'b1;
                            mem_read_addr[j] <= consumer_read_addr[consumer];
                            
                            // Mark channel as busy
                            channel_busy[j] <= 1'b1;
                            
                            // Update arbiter
                            read_arbiter <= (read_arbiter + 1) % NUM_CONSUMERS;
                            
                            break;
                        end
                    end
                end
            end
            
            // Process new write requests with round-robin arbitration
            if (WRITE_ENABLE) begin
                for (int i = 0; i < NUM_CONSUMERS; i++) begin
                    int consumer = (write_arbiter + i) % NUM_CONSUMERS;
                    
                    if (consumer_write_valid[consumer]) begin
                        // Find an available channel
                        for (int j = 0; j < NUM_CHANNELS; j++) begin
                            if (!channel_busy[j]) begin
                                // Assign request to this channel
                                request_queue[j].valid <= 1'b1;
                                request_queue[j].is_write <= 1'b1;
                                request_queue[j].consumer_id <= consumer;
                                request_queue[j].addr <= consumer_write_addr[consumer];
                                request_queue[j].data <= consumer_write_data[consumer];
                                
                                // Send write request to memory
                                mem_write_valid[j] <= 1'b1;
                                mem_write_addr[j] <= consumer_write_addr[consumer];
                                mem_write_data[j] <= consumer_write_data[consumer];
                                
                                // Mark channel as busy
                                channel_busy[j] <= 1'b1;
                                
                                // Update arbiter
                                write_arbiter <= (write_arbiter + 1) % NUM_CONSUMERS;
                                
                                break;
                            end
                        end
                    end
                end
            end
        end
    end
    
endmodule 