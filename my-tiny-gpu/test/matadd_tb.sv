`default_nettype none
`timescale 1ns/1ns

// Import the GPU package with common definitions
import gpu_pkg::*;

// Test bench for Matrix Addition Kernel
// Simulates the execution of a matrix addition kernel on our GPU
module matadd_tb();
    // Parameters
    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 8;
    localparam INSTR_WIDTH = 16;
    localparam DATA_MEM_CHANNELS = 4;
    localparam PROG_MEM_CHANNELS = 1;
    localparam NUM_CORES = 2;
    localparam THREADS_PER_BLOCK = 4;
    localparam CLK_PERIOD = 10; // 10ns = 100MHz
    
    // Clock and reset
    logic clk;
    logic rst_n;
    
    // GPU control
    logic start;
    logic done;
    
    // Device control register
    logic dcr_write_enable;
    logic [DATA_WIDTH-1:0] dcr_write_data;
    
    // Program memory interface
    logic [PROG_MEM_CHANNELS-1:0] prog_mem_read_valid;
    logic [ADDR_WIDTH-1:0] prog_mem_read_addr [PROG_MEM_CHANNELS-1:0];
    logic [PROG_MEM_CHANNELS-1:0] prog_mem_read_ready;
    logic [INSTR_WIDTH-1:0] prog_mem_read_data [PROG_MEM_CHANNELS-1:0];
    
    // Data memory interface
    logic [DATA_MEM_CHANNELS-1:0] data_mem_read_valid;
    logic [ADDR_WIDTH-1:0] data_mem_read_addr [DATA_MEM_CHANNELS-1:0];
    logic [DATA_MEM_CHANNELS-1:0] data_mem_read_ready;
    logic [DATA_WIDTH-1:0] data_mem_read_data [DATA_MEM_CHANNELS-1:0];
    
    logic [DATA_MEM_CHANNELS-1:0] data_mem_write_valid;
    logic [ADDR_WIDTH-1:0] data_mem_write_addr [DATA_MEM_CHANNELS-1:0];
    logic [DATA_WIDTH-1:0] data_mem_write_data [DATA_MEM_CHANNELS-1:0];
    logic [DATA_MEM_CHANNELS-1:0] data_mem_write_ready;
    
    // Matrix addition program
    // Similar to the program in the original project:
    // 1. Calculate thread index (i = blockIdx * blockDim + threadIdx)
    // 2. Load element A[i] from memory
    // 3. Load element B[i] from memory
    // 4. Calculate C[i] = A[i] + B[i]
    // 5. Store result C[i] to memory
    // 6. Return
    localparam int PROG_SIZE = 13;
    logic [INSTR_WIDTH-1:0] program [PROG_SIZE-1:0] = '{
        {OPCODE_MUL,  4'd0, REG_BLOCK_IDX, REG_BLOCK_DIM}, // MUL R0, %blockIdx, %blockDim
        {OPCODE_ADD,  4'd0, 4'd0, REG_THREAD_IDX},         // ADD R0, R0, %threadIdx  ; i = blockIdx * blockDim + threadIdx
        {OPCODE_CONST, 4'd1, 8'h00},                        // CONST R1, #0           ; baseA (matrix A base address)
        {OPCODE_CONST, 4'd2, 8'h08},                        // CONST R2, #8           ; baseB (matrix B base address)
        {OPCODE_CONST, 4'd3, 8'h10},                        // CONST R3, #16          ; baseC (matrix C base address)
        {OPCODE_ADD,  4'd4, 4'd1, 4'd0},                    // ADD R4, R1, R0         ; addr(A[i]) = baseA + i
        {OPCODE_LDR,  4'd4, 4'd4, 4'd0},                    // LDR R4, R4             ; load A[i] from memory
        {OPCODE_ADD,  4'd5, 4'd2, 4'd0},                    // ADD R5, R2, R0         ; addr(B[i]) = baseB + i
        {OPCODE_LDR,  4'd5, 4'd5, 4'd0},                    // LDR R5, R5             ; load B[i] from memory
        {OPCODE_ADD,  4'd6, 4'd4, 4'd5},                    // ADD R6, R4, R5         ; C[i] = A[i] + B[i]
        {OPCODE_ADD,  4'd7, 4'd3, 4'd0},                    // ADD R7, R3, R0         ; addr(C[i]) = baseC + i
        {OPCODE_STR,  4'd0, 4'd7, 4'd6},                    // STR R7, R6             ; store C[i] in memory
        {OPCODE_RET,  4'd0, 4'd0, 4'd0}                     // RET                    ; end of kernel
    };
    
    // Matrix data
    localparam int MATRIX_SIZE = 8;
    logic [DATA_WIDTH-1:0] matrix_a [MATRIX_SIZE-1:0] = '{0, 1, 2, 3, 4, 5, 6, 7};
    logic [DATA_WIDTH-1:0] matrix_b [MATRIX_SIZE-1:0] = '{7, 6, 5, 4, 3, 2, 1, 0};
    logic [DATA_WIDTH-1:0] matrix_c [MATRIX_SIZE-1:0];
    
    // Initialize data memory with matrices
    logic [DATA_WIDTH-1:0] data_mem_init [256-1:0];
    
    // Expected results
    logic [DATA_WIDTH-1:0] expected_results [MATRIX_SIZE-1:0] = '{7, 7, 7, 7, 7, 7, 7, 7};
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT instantiation
    gpu #(
        .DATA_WIDTH(DATA_WIDTH),
        .DATA_ADDR_WIDTH(ADDR_WIDTH),
        .DATA_MEM_CHANNELS(DATA_MEM_CHANNELS),
        .PROG_ADDR_WIDTH(ADDR_WIDTH),
        .PROG_WIDTH(INSTR_WIDTH),
        .PROG_MEM_CHANNELS(PROG_MEM_CHANNELS),
        .NUM_CORES(NUM_CORES),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .dcr_write_enable(dcr_write_enable),
        .dcr_write_data(dcr_write_data),
        .prog_mem_read_valid(prog_mem_read_valid),
        .prog_mem_read_addr(prog_mem_read_addr),
        .prog_mem_read_ready(prog_mem_read_ready),
        .prog_mem_read_data(prog_mem_read_data),
        .data_mem_read_valid(data_mem_read_valid),
        .data_mem_read_addr(data_mem_read_addr),
        .data_mem_read_ready(data_mem_read_ready),
        .data_mem_read_data(data_mem_read_data),
        .data_mem_write_valid(data_mem_write_valid),
        .data_mem_write_addr(data_mem_write_addr),
        .data_mem_write_data(data_mem_write_data),
        .data_mem_write_ready(data_mem_write_ready)
    );
    
    // Program memory model
    memory_model #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(INSTR_WIDTH),
        .NUM_CHANNELS(PROG_MEM_CHANNELS),
        .DEPTH(256),
        .READ_LATENCY(2),
        .WRITE_LATENCY(2)
    ) prog_mem (
        .clk(clk),
        .rst_n(rst_n),
        .read_valid(prog_mem_read_valid),
        .read_addr(prog_mem_read_addr),
        .read_ready(prog_mem_read_ready),
        .read_data(prog_mem_read_data),
        .write_valid('0),  // Program memory is read-only
        .write_addr('0),
        .write_data('0),
        .write_ready()
    );
    
    // Data memory model
    memory_model #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_CHANNELS(DATA_MEM_CHANNELS),
        .DEPTH(256),
        .READ_LATENCY(2),
        .WRITE_LATENCY(2)
    ) data_mem (
        .clk(clk),
        .rst_n(rst_n),
        .read_valid(data_mem_read_valid),
        .read_addr(data_mem_read_addr),
        .read_ready(data_mem_read_ready),
        .read_data(data_mem_read_data),
        .write_valid(data_mem_write_valid),
        .write_addr(data_mem_write_addr),
        .write_data(data_mem_write_data),
        .write_ready(data_mem_write_ready)
    );
    
    // Initialize memories
    initial begin
        // Initialize program memory with matrix addition kernel
        for (int i = 0; i < PROG_SIZE; i++) begin
            prog_mem.memory[i] = program[i];
        end
        
        // Initialize data memory with input matrices
        for (int i = 0; i < MATRIX_SIZE; i++) begin
            data_mem_init[i] = matrix_a[i];          // Matrix A at offset 0
            data_mem_init[i+MATRIX_SIZE] = matrix_b[i]; // Matrix B at offset 8
        end
        
        // Initialize the full data memory
        data_mem.initialize_memory(data_mem_init);
    end
    
    // Test sequence
    initial begin
        // Start with reset
        rst_n = 0;
        start = 0;
        dcr_write_enable = 0;
        
        // Release reset after 5 clock cycles
        repeat (5) @(posedge clk);
        rst_n = 1;
        
        // Set thread count to 8 (matrix size)
        @(posedge clk);
        dcr_write_enable = 1;
        dcr_write_data = MATRIX_SIZE;
        @(posedge clk);
        dcr_write_enable = 0;
        
        // Start the kernel
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        // Wait for kernel to complete
        @(posedge done);
        
        // Wait a few cycles to allow final writes to complete
        repeat (10) @(posedge clk);
        
        // Check results
        for (int i = 0; i < MATRIX_SIZE; i++) begin
            matrix_c[i] = data_mem.memory[i+MATRIX_SIZE*2]; // Matrix C at offset 16
            if (matrix_c[i] !== expected_results[i]) begin
                $display("ERROR: Result mismatch at index %0d. Expected: %0d, Got: %0d", 
                         i, expected_results[i], matrix_c[i]);
            end else begin
                $display("Result %0d OK: %0d", i, matrix_c[i]);
            end
        end
        
        $display("Test completed");
        $finish;
    end
    
    // Monitor for timeout
    initial begin
        repeat (5000) @(posedge clk);  // Reasonable timeout
        $display("ERROR: Test timed out");
        $finish;
    end
    
endmodule 