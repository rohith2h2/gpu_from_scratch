package gpu_pkg;
  // Core state definitions
  typedef enum logic [2:0] {
    IDLE    = 3'b000,
    FETCH   = 3'b001,
    DECODE  = 3'b010,
    REQUEST = 3'b011,
    WAIT    = 3'b100,
    EXECUTE = 3'b101,
    UPDATE  = 3'b110
  } core_state_t;
  
  // LSU state definitions
  typedef enum logic [1:0] {
    LSU_IDLE       = 2'b00, 
    LSU_REQUESTING = 2'b01, 
    LSU_WAITING    = 2'b10, 
    LSU_DONE       = 2'b11
  } lsu_state_t;
  
  // ALU operation definitions
  typedef enum logic [1:0] {
    ALU_ADD = 2'b00,
    ALU_SUB = 2'b01,
    ALU_MUL = 2'b10,
    ALU_DIV = 2'b11
  } alu_op_t;
  
  // Instruction type definitions
  // Instructions are 16 bits wide
  // Format depends on instruction type
  typedef struct packed {
    logic [3:0] opcode;   // Operation code
    logic [3:0] rd;       // Destination register
    logic [3:0] rs;       // Source register 1
    logic [3:0] rt;       // Source register 2 or immediate field extension
  } instruction_t;
  
  // Opcode definitions
  localparam OPCODE_ADD   = 4'b0011;
  localparam OPCODE_SUB   = 4'b0100;
  localparam OPCODE_MUL   = 4'b0101;
  localparam OPCODE_DIV   = 4'b0110;
  localparam OPCODE_LDR   = 4'b0111;
  localparam OPCODE_STR   = 4'b1000;
  localparam OPCODE_CONST = 4'b1001;
  localparam OPCODE_CMP   = 4'b1010;
  localparam OPCODE_BR    = 4'b1011;
  localparam OPCODE_RET   = 4'b1111;
  
  // Special register addresses
  localparam REG_BLOCK_IDX  = 4'd13;  // %blockIdx
  localparam REG_BLOCK_DIM  = 4'd14;  // %blockDim
  localparam REG_THREAD_IDX = 4'd15;  // %threadIdx
  
  // NZP control bits
  localparam NZP_N = 3'b100;  // Negative
  localparam NZP_Z = 3'b010;  // Zero
  localparam NZP_P = 3'b001;  // Positive
  
  // Register input source selection
  typedef enum logic [1:0] {
    REG_SRC_ALU      = 2'b00,  // From ALU result
    REG_SRC_LSU      = 2'b01,  // From LSU (memory load)
    REG_SRC_IMM      = 2'b10,  // From immediate value
    REG_SRC_RESERVED = 2'b11   // Reserved
  } reg_src_t;
  
endpackage 