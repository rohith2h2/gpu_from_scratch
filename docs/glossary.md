# GPU and Parallel Computing Glossary

This glossary provides definitions for key terms used in GPU architecture and parallel computing, with specific references to our implementation where applicable.

## A

**ALU (Arithmetic Logic Unit)**  
The hardware component that performs arithmetic and logical operations. In our GPU, each thread has its own ALU that can perform ADD, SUB, MUL, and DIV operations.

**Arbitration**  
The process of determining which of multiple requesters gets access to a shared resource. The memory controller in our GPU arbitrates memory access from multiple threads.

## B

**Block**  
A group of threads that execute together on a single core. In our implementation, each core processes one block at a time, and each block contains a configurable number of threads (default: 4).

**Branch Divergence**  
Occurs when threads within a warp/block take different execution paths due to conditional statements. Our simplified GPU doesn't handle branch divergence; all threads in a block follow the same execution path.

**Branch Prediction**  
A technique used by processors to guess the outcome of conditional branches before they are executed. Our GPU doesn't implement branch prediction.

## C

**Cache**  
A small, fast memory close to the processor that stores recently accessed data to reduce memory access latency. Our implementation doesn't include caches but could be extended to include them.

**Compute Core**  
A processing unit that executes instructions. Our GPU has multiple cores (default: 2), each capable of processing one block of threads.

**Concurrent Execution**  
Multiple operations happening at the same time, possibly on different processing units. Our GPU achieves concurrency by running multiple threads in parallel across different cores.

**Control Flow**  
The order in which instructions are executed, including branches and loops. In our GPU, the scheduler manages control flow through different execution states.

## D

**Data Memory**  
Memory used to store data that the kernel operates on. In our implementation, this is a separate memory from program memory.

**Data Parallelism**  
A form of parallelization where the same operation is performed on multiple data elements simultaneously. Our GPU implements SIMD (Same Instruction, Multiple Data) parallelism.

**Decoder**  
A component that translates instructions into control signals. Our decoder converts 16-bit instructions into signals that control the ALU, memory operations, and other components.

**Dispatcher**  
A component that distributes work to compute resources. In our GPU, the dispatcher assigns blocks of threads to available cores.

**Device Control Register (DCR)**  
A register that stores configuration information for the GPU. In our implementation, the DCR primarily stores the thread count.

## E

**Execution Model**  
The way a system organizes and executes computational tasks. Our GPU follows a SIMD execution model where multiple threads execute the same instruction on different data.

**Execution Pipeline**  
A series of stages through which instructions pass during execution. Our core implements a pipeline with stages: FETCH, DECODE, REQUEST, WAIT, EXECUTE, and UPDATE.

## F

**Fetcher**  
A component that retrieves instructions from program memory. Our fetcher handles the asynchronous retrieval of instructions based on the program counter.

## G

**Grid**  
In GPU programming, a collection of thread blocks that make up the entire computation. In our implementation, the dispatcher manages the execution of blocks across the available cores.

**GPU (Graphics Processing Unit)**  
A specialized processor designed for parallel computation, originally for graphics rendering but now used for general-purpose computing as well.

## I

**Instruction Set Architecture (ISA)**  
The set of instructions that a processor can execute. Our GPU implements a custom ISA with 11 basic instructions: ADD, SUB, MUL, DIV, LDR, STR, CMP, BRnzp, CONST, and RET.

**Instruction Fetcher**  
See "Fetcher."

**Instruction Decoder**  
See "Decoder."

## K

**Kernel**  
A program that runs on a GPU, typically designed for parallel execution. In our implementation, a kernel is a sequence of instructions stored in program memory.

## L

**Load-Store Unit (LSU)**  
A component that handles memory operations. Each thread in our GPU has its own LSU for reading from and writing to data memory.

**Load Balancing**  
The distribution of workload across multiple computing resources to optimize performance. Our dispatcher attempts to distribute blocks evenly across cores.

## M

**Memory Controller**  
A component that manages access to memory, handling read and write requests. Our memory controller arbitrates between multiple threads' memory requests.

**Memory Coalescing**  
A technique to combine multiple memory accesses into fewer transactions. Our current implementation doesn't implement memory coalescing.

**Memory Hierarchy**  
The organization of different types of memory in a computing system, typically arranged by speed and size. Our implementation has a simple hierarchy with program memory and data memory.

**Memory Latency**  
The time delay between initiating a memory access and receiving the data. Our memory model simulates latency with configurable parameters.

**Memory Model**  
A specification of how memory operations interact with each other. Our memory model is a behavioral simulation of external memory with configurable latency.

## N

**NZP (Negative, Zero, Positive) Register**  
A special register that stores the result of comparison operations. In our implementation, the PC unit uses this for conditional branching.

## P

**Parallel Computing**  
A type of computation where many calculations or processes are carried out simultaneously. Our GPU is designed for parallel execution of threads.

**Pipeline**  
See "Execution Pipeline."

**Program Counter (PC)**  
A register that contains the address of the next instruction to be executed. Each thread in our GPU has its own PC unit to track execution flow.

**Program Memory**  
Memory used to store the instructions of a program. In our implementation, this is separate from data memory.

## R

**Register File**  
A small, fast memory within a processor that stores data being actively used. Each thread in our GPU has its own register file with 16 registers.

**Round-Robin Scheduling**  
A scheduling algorithm that assigns time slices to each process in equal portions and in circular order. Our memory controller uses round-robin to arbitrate between multiple memory requests.

## S

**Scheduler**  
A component that determines the order of execution of instructions or tasks. Our core includes a scheduler that manages the progression through different execution states.

**SIMD (Same Instruction, Multiple Data)**  
A parallel execution model where a single instruction operates on multiple data elements simultaneously. Our GPU follows this model, with all threads in a block executing the same instruction.

**SIMT (Single Instruction, Multiple Thread)**  
An extension of SIMD where individual threads can have some independence in execution. Our implementation is primarily SIMD but has elements of SIMT in how threads index memory.

**Special Registers**  
Registers with dedicated purposes beyond general computation. In our GPU, registers R13-R15 are special registers for thread metadata (%blockIdx, %blockDim, %threadIdx).

**Synchronization**  
Coordination between parallel processes to ensure correct execution. Our implementation synchronizes threads within a block at each execution state.

## T

**Thread**  
The smallest unit of execution. In our GPU, each thread has its own ALU, LSU, PC unit, and register file.

**Thread Block**  
See "Block."

**Thread Divergence**  
See "Branch Divergence."

**Thread Hierarchy**  
The organization of threads into groups (blocks) and groups of groups (grids). Our GPU organizes threads into blocks, which are distributed across cores.

**Thread ID**  
A unique identifier for each thread. In our implementation, thread IDs are used to calculate memory addresses for data-parallel operations.

**Throughput**  
The amount of computation that can be performed in a given time. Our GPU achieves high throughput by executing multiple threads in parallel.

## W

**Warp**  
In NVIDIA GPUs, a group of 32 threads that execute together in lockstep. Our implementation doesn't use the term "warp" but our blocks function similarly (with fewer threads).

**Work Distribution**  
The assignment of computational tasks to processing units. Our dispatcher handles work distribution by assigning blocks to cores.

## Additional Resources

For more detailed information on these concepts and how they apply to our GPU implementation, refer to:
- [Architecture Guide](architecture.md)
- [Module-by-Module Documentation](modules/README.md)
- [Kernel Development Walkthrough](kernel_walkthrough.md) 