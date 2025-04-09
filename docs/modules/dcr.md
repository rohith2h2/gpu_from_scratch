# Device Control Register (DCR) Documentation

## Overview

The Device Control Register (DCR) module serves as the configuration and control interface between the host system and the GPU. It provides a set of memory-mapped registers that allow the host to configure GPU operation, initiate kernel execution, monitor status, and retrieve results. The DCR acts as the primary means for external control of the GPU's behavior.

## Key Features

- Memory-mapped register interface for host access
- Configuration registers for setting up kernel execution
- Control registers for starting and stopping execution
- Status registers for monitoring GPU operation
- Support for multiple threads and cores configuration
- Interrupt generation for completion notifications

## Interface

```systemverilog
module dcr #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MAX_THREADS = 32,
    parameter NUM_CORES = 2
) (
    input  logic                      clk,
    input  logic                      reset,
    
    // Host interface
    input  logic                      dcr_write_en,
    input  logic [ADDR_WIDTH-1:0]     dcr_addr,
    input  logic [DATA_WIDTH-1:0]     dcr_write_data,
    input  logic                      dcr_read_en,
    output logic [DATA_WIDTH-1:0]     dcr_read_data,
    output logic                      dcr_ack,
    
    // GPU control signals
    output logic                      gpu_start,
    output logic [ADDR_WIDTH-1:0]     program_start_addr,
    output logic [MAX_THREADS-1:0]    initial_thread_mask,
    output logic [3:0]                kernel_id,
    
    // Status signals
    input  logic                      all_cores_idle,
    input  logic [NUM_CORES-1:0]      core_idle,
    output logic                      interrupt_request
);
```

## Parameters

| Parameter    | Default | Description                                |
|--------------|---------|-------------------------------------------|
| DATA_WIDTH   | 32      | Width of data path in bits                 |
| ADDR_WIDTH   | 32      | Width of address bus in bits               |
| MAX_THREADS  | 32      | Maximum number of threads supported        |
| NUM_CORES    | 2       | Number of GPU cores                        |

## Inputs and Outputs

| Port                | Direction | Width           | Description                                         |
|---------------------|-----------|----------------|-----------------------------------------------------|
| clk                 | input     | 1              | System clock signal                                 |
| reset               | input     | 1              | Active high reset signal                            |
| dcr_write_en        | input     | 1              | Enable signal for register writes                   |
| dcr_addr            | input     | ADDR_WIDTH     | Address of register to access                       |
| dcr_write_data      | input     | DATA_WIDTH     | Data to write to register                           |
| dcr_read_en         | input     | 1              | Enable signal for register reads                    |
| dcr_read_data       | output    | DATA_WIDTH     | Data read from register                             |
| dcr_ack             | output    | 1              | Acknowledge signal for completed register access    |
| gpu_start           | output    | 1              | Signal to start GPU execution                       |
| program_start_addr  | output    | ADDR_WIDTH     | Starting address of program in memory              |
| initial_thread_mask | output    | MAX_THREADS    | Bit mask of threads to activate                    |
| kernel_id           | output    | 4              | Identifier of the kernel to execute                |
| all_cores_idle      | input     | 1              | Signal indicating all cores are idle               |
| core_idle           | input     | NUM_CORES      | Bit mask of idle cores                             |
| interrupt_request   | output    | 1              | Interrupt request signal to host                   |

## Register Map

The DCR implements the following register map:

| Offset | Register Name             | Access  | Description                                        |
|--------|---------------------------|---------|--------------------------------------------------- |
| 0x00   | DCR_CONTROL              | RW      | Control register (start/stop/reset)                |
| 0x04   | DCR_STATUS               | RO      | Status register (busy/idle/error)                  |
| 0x08   | DCR_PROGRAM_ADDR         | RW      | Program start address                              |
| 0x0C   | DCR_THREAD_MASK_LOW      | RW      | Thread mask for threads 0-31                       |
| 0x10   | DCR_THREAD_MASK_HIGH     | RW      | Thread mask for threads 32-63 (if supported)       |
| 0x14   | DCR_KERNEL_ID            | RW      | Kernel identifier                                  |
| 0x18   | DCR_GRID_DIM_X           | RW      | Grid dimension X                                   |
| 0x1C   | DCR_GRID_DIM_Y           | RW      | Grid dimension Y                                   |
| 0x20   | DCR_BLOCK_DIM_X          | RW      | Block dimension X                                  |
| 0x24   | DCR_BLOCK_DIM_Y          | RW      | Block dimension Y                                  |
| 0x28   | DCR_PARAM_ADDR           | RW      | Kernel parameter buffer address                    |
| 0x2C   | DCR_PARAM_SIZE           | RW      | Kernel parameter buffer size                       |
| 0x30   | DCR_INTERRUPT_ENABLE     | RW      | Interrupt enable mask                              |
| 0x34   | DCR_INTERRUPT_STATUS     | RW      | Interrupt status (write 1 to clear)                |
| 0x38-0xFF | Reserved              |         | Reserved for future use                            |

## Implementation Details

### Register Access Logic

The DCR implements a straightforward memory-mapped register interface:

```systemverilog
// Register access logic
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        // Initialize registers to default values
        control_reg <= '0;
        program_addr_reg <= '0;
        thread_mask_low_reg <= '0;
        thread_mask_high_reg <= '0;
        kernel_id_reg <= '0;
        // ...other registers...
        dcr_ack <= 1'b0;
    end
    else begin
        // Default values
        dcr_ack <= 1'b0;
        
        // Write access
        if (dcr_write_en) begin
            case (dcr_addr[7:0])
                8'h00: control_reg <= dcr_write_data;
                8'h08: program_addr_reg <= dcr_write_data;
                8'h0C: thread_mask_low_reg <= dcr_write_data;
                8'h10: thread_mask_high_reg <= dcr_write_data;
                8'h14: kernel_id_reg <= dcr_write_data[3:0];
                // ...other registers...
            endcase
            dcr_ack <= 1'b1;
        end
        
        // Read access
        if (dcr_read_en) begin
            case (dcr_addr[7:0])
                8'h00: dcr_read_data <= control_reg;
                8'h04: dcr_read_data <= status_reg;
                8'h08: dcr_read_data <= program_addr_reg;
                8'h0C: dcr_read_data <= thread_mask_low_reg;
                8'h10: dcr_read_data <= thread_mask_high_reg;
                8'h14: dcr_read_data <= {28'h0, kernel_id_reg};
                // ...other registers...
                default: dcr_read_data <= '0;
            endcase
            dcr_ack <= 1'b1;
        end
    end
end
```

### Control Register Bits

The control register (DCR_CONTROL) has the following bit fields:

| Bit(s) | Field Name      | Description                                             |
|--------|----------------|---------------------------------------------------------|
| 0      | GPU_START      | Write 1 to start GPU execution                          |
| 1      | GPU_STOP       | Write 1 to stop GPU execution                           |
| 2      | GPU_RESET      | Write 1 to reset the GPU                                |
| 3-7    | Reserved       | Reserved for future use                                 |
| 8-15   | CORE_ENABLE    | Bit mask to enable/disable cores (1 bit per core)       |
| 16-31  | Reserved       | Reserved for future use                                 |

### Status Register Bits

The status register (DCR_STATUS) has the following bit fields:

| Bit(s) | Field Name       | Description                                            |
|--------|-----------------|--------------------------------------------------------|
| 0      | GPU_BUSY        | 1 when GPU is executing, 0 when idle                   |
| 1-7    | Reserved        | Reserved for future use                                |
| 8-15   | CORE_IDLE       | Bit mask of idle cores (1 bit per core)                |
| 16-23  | CORE_ERROR      | Bit mask of cores with errors (1 bit per core)         |
| 24-31  | ERROR_CODE      | Error code (if any error bit is set)                   |

### Control Signal Generation

The DCR generates control signals for the GPU based on register values:

```systemverilog
// Control signal generation
assign gpu_start = control_reg[0] & ~prev_control_reg[0]; // Rising edge detection
assign program_start_addr = program_addr_reg;
assign initial_thread_mask = thread_mask_low_reg;
assign kernel_id = kernel_id_reg;
```

### Interrupt Generation

The DCR can generate interrupts based on GPU events:

```systemverilog
// Interrupt generation
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        interrupt_status_reg <= '0;
        interrupt_request <= 1'b0;
    end
    else begin
        // Set interrupt status bits based on events
        if (prev_all_cores_busy && all_cores_idle)
            interrupt_status_reg[0] <= 1'b1; // Execution complete
            
        // Clear interrupt status bits when written with 1
        if (dcr_write_en && dcr_addr[7:0] == 8'h34)
            interrupt_status_reg <= interrupt_status_reg & ~dcr_write_data;
            
        // Generate interrupt if any enabled interrupt is pending
        interrupt_request <= |(interrupt_status_reg & interrupt_enable_reg);
    end
end
```

## Usage and Programming Model

### GPU Kernel Launch Sequence

To launch a GPU kernel, the host system follows this sequence:

1. **Configure kernel parameters**:
   - Write kernel program address to DCR_PROGRAM_ADDR
   - Write thread configuration to DCR_THREAD_MASK_LOW
   - Write kernel identifier to DCR_KERNEL_ID
   - Configure grid and block dimensions

2. **Start execution**:
   - Write 1 to the GPU_START bit in DCR_CONTROL

3. **Monitor execution**:
   - Poll DCR_STATUS to check GPU_BUSY bit, or
   - Enable interrupts and wait for completion interrupt

4. **Handle completion**:
   - Read results from memory
   - Clear any pending interrupts

### Thread Configuration

The thread mask registers determine which threads are active for kernel execution:

- Each bit in the thread mask corresponds to one thread
- Set bits indicate active threads, clear bits indicate inactive threads
- For kernels that don't use all threads, only set the bits for the threads needed

### Error Handling

The DCR provides error detection and reporting:

1. **Error Detection**:
   - The CORE_ERROR bits in DCR_STATUS indicate which cores encountered errors
   - The ERROR_CODE field provides more information about the error

2. **Error Recovery**:
   - Write 1 to the GPU_RESET bit in DCR_CONTROL to reset the GPU
   - Clear error status by writing to the appropriate registers

## Performance Considerations

1. **Register Access Latency**: Register access should be minimized during critical execution paths, as each access requires at least one clock cycle.

2. **Polling Overhead**: Polling the status register for completion consumes host CPU cycles; interrupt-based notification is more efficient for long-running kernels.

3. **Thread Configuration**: Optimal thread configuration depends on the kernel's characteristics; experimentation may be needed to find the best thread mask.

## Design Decisions

1. **Memory-Mapped Interface**: A memory-mapped register interface was chosen for compatibility with standard processor memory access methods.

2. **Separate Control and Status Registers**: Control and status are kept in separate registers to allow atomic operations on control bits without affecting status reporting.

3. **Interrupt-Based Notification**: Interrupts provide an efficient way to notify the host of completion, reducing polling overhead.

4. **Kernel Parameter Passing**: A separate parameter buffer is used for flexibility in passing variable-length parameter lists to kernels.

## Usage Example

Here's an example of how the DCR is used to control the GPU:

```systemverilog
// Instance of DCR in top-level design
dcr #(
    .DATA_WIDTH(32),
    .ADDR_WIDTH(32),
    .MAX_THREADS(32),
    .NUM_CORES(2)
) dcr_inst (
    .clk(system_clk),
    .reset(system_reset),
    .dcr_write_en(cpu_write_en),
    .dcr_addr(cpu_addr),
    .dcr_write_data(cpu_write_data),
    .dcr_read_en(cpu_read_en),
    .dcr_read_data(cpu_read_data),
    .dcr_ack(cpu_ack),
    .gpu_start(gpu_start_signal),
    .program_start_addr(program_addr),
    .initial_thread_mask(thread_mask),
    .kernel_id(kernel_identifier),
    .all_cores_idle(cores_idle),
    .core_idle(individual_core_idle),
    .interrupt_request(gpu_irq)
);
```

## Future Improvements

1. **Enhanced Error Reporting**: Add more detailed error information and recovery mechanisms

2. **Performance Counters**: Add registers for tracking performance metrics like execution time, memory utilization, etc.

3. **Power Management**: Add support for power states and clock gating control

4. **Advanced Thread Configuration**: Support for more complex thread hierarchy and scheduling

5. **DMA Engine**: Integrate a DMA engine for efficient data transfer between host and GPU memory

6. **Security Features**: Add protection mechanisms for privileged registers

7. **Hot-Plug Support**: Add support for dynamic core addition and removal 