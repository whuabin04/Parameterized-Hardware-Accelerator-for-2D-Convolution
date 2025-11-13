// Stony Brook University
// Fall 2025 ESE 507 
// Professor Peter Milder
// Huabin Wu (115067644)
// Ryan Lin (114737153)
// Project: Hardware Accelerator for 2D Convolution
// Part 4: 2D Convolution with Bias

module Conv #(
    parameter   INW = 18,
    parameter   R = 8,
    parameter   C = 8,
    parameter   MAXK = 5,
    localparam  OUTW = $clog2(MAXK*MAXK*(128'd1 << 2*INW-2) + (1<<(INW-1)))+1,
    localparam  K_BITS = $clog2(MAXK+1)
)(
    input clk,
    input reset,

    input [INW-1:0]     INPUT_TDATA,
    input               INPUT_TVALID,
    input [K_BITS:0]    INPUT_TUSER,
    output              INPUT_TREADY,
    
    output [OUTW-1:0]   OUTPUT_TDATA,
    output              OUTPUT_TVALID,
    input               OUTPUT_TREADY
);

    logic [$clog(R*C)-1 : 0]        internal_x_read_address;
    logic [$clog2(MAXK*MAXK)-1 : 0] internal_w_read_address;

    // inputs_mem module will pipe the output values to our internal logic signals 
    // below if the module instantiation expects an output signal
    logic                       INPUTS_MEM_INPUTS_LOADED;  
    logic [K_BITS-1 : 0]        INPUTS_MEM_K;   // kernel size
    logic signed [INW-1 : 0]    INPUTS_MEM_B_DATA_OUT;   // bias value
    logic signed [INW-1 : 0]    INPUTS_MEM_X_DATA_OUT;
    logic signed [INW-1 : 0]    INPUTS_MEM_W_DATA_OUT;

    // mac product result to pipe to the fifo
    logic [OUTW-1 : 0]          MAC_PIPE_OUT; 

    logic MAC_OUTPUT_VALID;
    logic COMPUTE_FINISHED; 
    // *maybe compute finish when the last element of x is multiplied?*
    assign COMPUTE_FINISHED = (internal_x_read_address == (R*C)); 

    always_ff @(posedge clk) begin
        if(reset == 1) begin
            internal_x_read_address <= 0;
            internal_w_read_address <= 0;
        end
        else begin
            inputs_mem #(
                .INW(INW),
                .R(R),
                .C(C),
                .MAXK(MAXK)
            ) input_mem_instantiation(
                .clk(clk),                                  // input
                .reset(reset),                              // input 
                
                .AXIS_TDATA(INPUT_TDATA),                   // input
                .AXIS_TVALID(INPUT_TVALID),                 // input
                .AXIS_TUSER(INPUT_TUSER),                   // input
                .AXIS_TREADY(INPUT_TREADY),                 // output to this (top-level) input interface
                // *note: INPUT_TREADY let's us know that mem has room to begin accepting TDATA
                
                .inputs_loaded(INPUTS_MEM_INPUTS_LOADED),   // output to mac_pipe
                .compute_finished(COMPUTE_FINISHED),        // input from
                .K(INPUTS_MEM_K),                           // output to 
                .B(INPUTS_MEM_B_DATA_OUT),                  // output to mac_pipe
                .X_read_addr(),                             // input from mac_pipe
                .X_data(INPUTS_MEM_X_DATA_OUT),             // output to mac_pipe
                .W_read_addr(),                             // input from mac_pipe
                .W_data(INPUTS_MEM_W_DATA_OUT)              // output to mac_pipe
            );
        end
    end

    always_ff @(posedge clk) begin
        if(reset) begin

        end

        else if(INPUTS_MEM_INPUTS_LOADED) begin
            // when inputs are loaded we can start/init accumulation in mac_pipe
            MAC_OUTPUT_VALID <= INPUTS_MEM_INPUTS_LOADED;
        end
    end

    mac_pipe #(
        .INW(INW),
        .OUTW(OUTW)
    ) mac_pipe_instantiation(
        .input0(INPUTS_MEM_X_DATA_OUT),
        .input1(INPUTS_MEM_W_DATA_OUT),
        // sign-extend the bias (INW) up to OUTW and feed it as the initial accumulator value
        .init_value({{(OUTW-INW){INPUTS_MEM_B_DATA_OUT[INW-1]}}, INPUTS_MEM_B_DATA_OUT}),
        .out(MAC_PIPE_OUT),

        .clk(clk),
        .reset(reset),
        // assert init_acc when inputs are loaded so mac_pipe will initialize accumulator with bias
        .init_acc(INPUTS_MEM_INPUTS_LOADED),
        .input_valid(INPUTS_MEM_INPUTS_LOADED)
    );

    .fifo_out #(
        .OUTW(OUTW),
        .DEPTH()
    ) fifo_out_instantiation(
        .IN_AXIS_TDATA(MAC_PIPE_OUT),
        .IN_AXIS_TVALID(MAC_OUTPUT_VALID),
        .IN_AXIS_TREADY(),

        .OUT_AXIS_TDATA(OUTPUT_TDATA),
        .OUT_AXIS_TVALID(OUTPUT_TVALID),
        .OUT_AXIS_TREADY(OUTPUT_TREADY)
    );
endmodule