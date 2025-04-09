`default_nettype none
`timescale 1ns/1ns

// Dispatcher
// Distributes thread blocks to available compute cores
// Manages the overall kernel execution across multiple cores
// Tracks block completion and signals when the entire kernel is done
module dispatch #(
    parameter DATA_WIDTH = 8,      // Width of the data
    parameter NUM_CORES = 2,       // Number of cores
    parameter THREADS_PER_BLOCK = 4 // Number of threads per block
) (
    input  logic                    clk,
    input  logic                    rst_n,            // Active-low reset
    
    // Kernel execution control
    input  logic                    start,            // Start kernel execution
    input  logic [DATA_WIDTH-1:0]   thread_count,     // Total number of threads to launch
    input  logic [NUM_CORES-1:0]    core_done,        // Signals from cores indicating block completion
    
    // Core control outputs
    output logic [NUM_CORES-1:0]    core_start,       // Start signal for each core
    output logic [NUM_CORES-1:0]    core_reset,       // Reset signal for each core
    output logic [DATA_WIDTH-1:0]   core_block_id [NUM_CORES-1:0], // Block ID for each core
    output logic [$clog2(THREADS_PER_BLOCK)+1:0] core_block_size [NUM_CORES-1:0], // Number of threads per block
    
    // Kernel completion
    output logic                    done              // Kernel execution complete
);

    // Dispatcher state
    typedef enum logic [1:0] {
        DISP_IDLE = 2'b00,
        DISP_RUNNING = 2'b01,
        DISP_COMPLETE = 2'b10
    } dispatcher_state_t;
    
    // Internal state
    dispatcher_state_t current_state;
    logic [DATA_WIDTH-1:0] next_block_id;
    logic [DATA_WIDTH-1:0] total_blocks;
    logic [NUM_CORES-1:0] core_active;
    
    // Calculate the total number of blocks based on thread count
    // Each block has THREADS_PER_BLOCK threads, rounded up
    function logic [DATA_WIDTH-1:0] calculate_blocks(logic [DATA_WIDTH-1:0] threads);
        logic [DATA_WIDTH-1:0] blocks;
        blocks = threads / THREADS_PER_BLOCK;
        if (threads % THREADS_PER_BLOCK != 0) begin
            blocks = blocks + 1;
        end
        return blocks;
    endfunction
    
    // Calculate threads in the last block
    function logic [$clog2(THREADS_PER_BLOCK)+1:0] last_block_size(
        logic [DATA_WIDTH-1:0] threads,
        logic [DATA_WIDTH-1:0] blocks
    );
        logic [$clog2(THREADS_PER_BLOCK)+1:0] size;
        if (threads % THREADS_PER_BLOCK == 0) begin
            size = THREADS_PER_BLOCK;
        end
        else begin
            size = threads % THREADS_PER_BLOCK;
        end
        return size;
    endfunction
    
    // Dispatcher logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            current_state <= DISP_IDLE;
            next_block_id <= '0;
            total_blocks <= '0;
            core_active <= '0;
            done <= 1'b0;
            
            for (int i = 0; i < NUM_CORES; i++) begin
                core_start[i] <= 1'b0;
                core_reset[i] <= 1'b1;  // Active-low reset, so this is asserting reset
                core_block_id[i] <= '0;
                core_block_size[i] <= '0;
            end
        end
        else begin
            case (current_state)
                DISP_IDLE: begin
                    // Wait for start signal
                    if (start) begin
                        // Calculate total blocks needed
                        total_blocks <= calculate_blocks(thread_count);
                        next_block_id <= '0;
                        
                        // Reset all cores
                        for (int i = 0; i < NUM_CORES; i++) begin
                            core_reset[i] <= 1'b0;  // Release reset
                            core_active[i] <= 1'b0;
                            core_start[i] <= 1'b0;
                        end
                        
                        current_state <= DISP_RUNNING;
                        done <= 1'b0;
                    end
                end
                
                DISP_RUNNING: begin
                    // Check for completed cores
                    for (int i = 0; i < NUM_CORES; i++) begin
                        if (core_active[i] && core_done[i]) begin
                            // Core has finished its block
                            core_active[i] <= 1'b0;
                            core_start[i] <= 1'b0;
                        end
                    end
                    
                    // Dispatch new blocks to available cores
                    for (int i = 0; i < NUM_CORES; i++) begin
                        if (!core_active[i] && next_block_id < total_blocks) begin
                            // Assign a new block to this core
                            core_active[i] <= 1'b1;
                            core_start[i] <= 1'b1;
                            core_block_id[i] <= next_block_id;
                            
                            // Check if this is the last block (might have fewer threads)
                            if (next_block_id == total_blocks - 1) begin
                                core_block_size[i] <= last_block_size(thread_count, total_blocks);
                            end
                            else begin
                                core_block_size[i] <= THREADS_PER_BLOCK;
                            end
                            
                            // Move to next block
                            next_block_id <= next_block_id + 1;
                        end
                    end
                    
                    // Check if all blocks have completed
                    if (next_block_id >= total_blocks && core_active == '0) begin
                        current_state <= DISP_COMPLETE;
                    end
                end
                
                DISP_COMPLETE: begin
                    // Signal kernel completion
                    done <= 1'b1;
                    
                    // Reset state for next kernel
                    if (!start) begin
                        current_state <= DISP_IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: begin
                    current_state <= DISP_IDLE;
                end
            endcase
        end
    end
    
endmodule 