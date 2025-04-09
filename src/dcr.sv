`default_nettype none
`timescale 1ns/1ns

// Device Control Register (DCR)
// Stores metadata for GPU kernel execution
// In this simplified implementation, it mainly stores the thread count
// More complex implementations would store grid dimensions, kernel memory locations, etc.
module dcr #(
    parameter DATA_WIDTH = 8   // Width of control registers
) (
    input  logic                    clk,
    input  logic                    rst_n,             // Active-low reset
    
    // Control register interface
    input  logic                    write_enable,      // Write enable for control register
    input  logic [DATA_WIDTH-1:0]   write_data,        // Data to write to control register
    
    // Output registers
    output logic [DATA_WIDTH-1:0]   thread_count       // Total number of threads to launch
);

    // Thread count register
    logic [DATA_WIDTH-1:0] thread_count_reg;
    
    // Assign output
    assign thread_count = thread_count_reg;
    
    // Control register update logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            thread_count_reg <= '0;
        end
        else if (write_enable) begin
            // Update thread count when write is enabled
            thread_count_reg <= write_data;
        end
    end
    
endmodule 