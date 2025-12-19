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
    logic [$clog2(R*C)-1 : 0]   internal_x_read_address;
    logic [$clog2(MAXK*MAXK)-1 : 0] internal_w_read_address;
    // input_mems => mac unit 
    // INPUT_mem module will pipe the output values to our internal logic signals 
    // below if the module instantiation expects an output signal
    logic                       INPUT_MEMS_INPUT_LOADED_DATA_OUT; 
    logic                       DATA_AVAILABLE; 
    logic [K_BITS-1 : 0]        INPUT_MEMS_K_DATA_OUT;   // kernel size
    logic [K_BITS-1 : 0]        k_latched;
    logic signed [INW-1 : 0]    INPUT_MEMS_B_DATA_OUT;   // bias value
    logic signed [INW-1 : 0]    INPUT_MEMS_X_DATA_OUT;
    logic signed [INW-1 : 0]    INPUT_MEMS_W_DATA_OUT;
    logic                       INITIALIZE_ACCUMULATOR;
    logic signed [$clog2(MAXK*MAXK) : 0] kernel_counter_for_acc;

    logic [OUTW-1 : 0] MAC_PIPE_DATA_OUT;   // mac accumulator to pipe to the fifo
    logic MAC_OUTPUT_VALID;             // output valid for FIFO after first multiply accumulate result is calculated     
    logic COMPUTE_FINISHED_DATA_IN; 
    logic FIFO_READY_TO_RECEIVE;    // use this to throttle mac_pipe output if fifo is full

    typedef enum logic [2:0] {
        IDLE_STATE =            3'd0,       // wait for input_mems buffer to finish loading
        INIT_PIXEL_STATE =      3'd1,       // initialize accumulator with bias value + set up read addresses/counters
        COMPUTING_ACC_STATE =   3'd2,       // perform multiply-accumulate operation loop for one output pixel
        WRITE_PIXEL_STATE =     3'd3,       // write the computed pixel to FIFO + assert output valid signal + update r/c for next pixel
        WAIT_FIRST_ADDR =       3'd4,       // wait state to ensure correct read addresses are set before next pixel computation
        DONE_STATE =            3'd5        // all output pixels are written to FIFO + compute finished for next input_mems load
    } state_type;
    
    state_type CURRENT_STATE, NEXT_STATE;    
    logic [$clog2(R)-1 : 0] r;
    logic [$clog2(C)-1 : 0] c;
    logic [$clog2(R)-1 : 0] R_out;
    logic [$clog2(C)-1 : 0] C_out;
    logic [$clog2(MAXK)-1 : 0] i;
    logic [$clog2(MAXK)-1 : 0] j;
    assign R_out = R - INPUT_MEMS_K_DATA_OUT + 1;     // R_out = R - K + 1
    assign C_out = C - INPUT_MEMS_K_DATA_OUT + 1;     // C_out = C - K + 1
    localparam NUM_ENTRIES_FIFO = (R - 1)*(C - 1);

    // =================== STATE OUTPUT LOGIC =====================
    always_comb begin
        case(CURRENT_STATE) 
            IDLE_STATE: begin
                // do nothing for now
            end
            INIT_PIXEL_STATE: begin
                INITIALIZE_ACCUMULATOR = 1'b1;  // set accumulator to bias value (happens next cycle)
                MAC_OUTPUT_VALID = 1'b0;
                COMPUTE_FINISHED_DATA_IN = 1'b0;
                DATA_AVAILABLE = 1'b0;
            end

            COMPUTING_ACC_STATE: begin
                INITIALIZE_ACCUMULATOR = 1'b0;
                MAC_OUTPUT_VALID = 1'b0;
                COMPUTE_FINISHED_DATA_IN = 1'b0;
                DATA_AVAILABLE = 1'b1;        // start multiplying then accumulate on the next cycle
            end

            WRITE_PIXEL_STATE: begin
                INITIALIZE_ACCUMULATOR = 1'b0;
                MAC_OUTPUT_VALID = 1'b1;
                COMPUTE_FINISHED_DATA_IN = 1'b0;
                DATA_AVAILABLE = 1'b0;
            end

            WAIT_FIRST_ADDR: begin
                INITIALIZE_ACCUMULATOR = 1'b0;
                MAC_OUTPUT_VALID = 1'b0;
                COMPUTE_FINISHED_DATA_IN = 1'b0;
                DATA_AVAILABLE = 1'b0;
            end

            DONE_STATE: begin
                INITIALIZE_ACCUMULATOR = 1'b0;
                MAC_OUTPUT_VALID = 1'b0;
                COMPUTE_FINISHED_DATA_IN = 1'b1;        // input_mems enters idle state and can start loading new data
                DATA_AVAILABLE = 1'b0;
            end
        endcase
    end

    // ==================== END OF STATE OUTPUT LOGIC ======================

    // =================== NEXT STATE LOGIC =====================
    always_ff @(posedge clk) begin
        if(reset == 1) begin
            CURRENT_STATE <= IDLE_STATE;
        end
        else begin
            CURRENT_STATE <= NEXT_STATE;
        end
    end

    always_comb begin
        NEXT_STATE = CURRENT_STATE;

        case(CURRENT_STATE)
            IDLE_STATE: begin
                if(INPUT_MEMS_INPUT_LOADED_DATA_OUT) begin
                    NEXT_STATE = INIT_PIXEL_STATE;
                end
            end
            INIT_PIXEL_STATE: begin
                NEXT_STATE = COMPUTING_ACC_STATE;
            end
            COMPUTING_ACC_STATE: begin
                // MAC_OUTPUT_VALID should update on next edge but we look ahead here
                if(kernel_counter_for_acc >= (k_latched * k_latched)) begin     
                    NEXT_STATE = WRITE_PIXEL_STATE;
                end else begin
                    NEXT_STATE = COMPUTING_ACC_STATE;
                end
            end
            WRITE_PIXEL_STATE: begin
                // COMPUTE_FINISHED_DATA_IN should update on next edge but we look ahead here
                if((r >= R_out - 1) && (c >= C_out - 1) && (kernel_counter_for_acc == (k_latched * k_latched))) begin      
                    NEXT_STATE = DONE_STATE;
                end else begin
                    NEXT_STATE = WAIT_FIRST_ADDR;
                end
            end

            WAIT_FIRST_ADDR: begin
                NEXT_STATE = INIT_PIXEL_STATE;
            end

            DONE_STATE: begin
                NEXT_STATE = IDLE_STATE;
            end

            default: begin
                NEXT_STATE = IDLE_STATE;
            end
        endcase
    end
    // =================== END OF NEXT STATE LOGIC ======================
    
    // =================== SEQUENTIAL DATAPATH LOGIC =====================
    /*
            handle convolution computation logic here
            PSEUDOCODE:
            for r=0 to Rout-1:
                for c=0 to Cout-1:
                    accumulator_reg = b
                    for i=0 to K-1:
                        for j=0 to K-1:
                            accumulator_reg += X[r+i][c+j] * W[i][j]
                    store accumulator_reg to FIFO                           
    */    
    always_ff @(posedge clk) begin
        if(reset == 1) begin
            kernel_counter_for_acc <= '0;
            r <= '0;
            c <= '0;
            internal_x_read_address <= '0;
            internal_w_read_address <= '0;
            i <= '0;
            j <= '0;
            k_latched <= '0;
        end

        case(CURRENT_STATE) 
            IDLE_STATE: begin
                r <= '0;
                c <= '0;
                i <= '0;
                j <= '0;
                internal_x_read_address <= '0;
                internal_w_read_address <= '0;
                k_latched <= INPUT_MEMS_K_DATA_OUT;
                kernel_counter_for_acc <= '0;
            end

            INIT_PIXEL_STATE: begin         
                // rmemeber that the bias value is loaded into the accumulator in the next cycle
                kernel_counter_for_acc <= 0;
                i <= '0;
                j <= 1;
                internal_x_read_address <= r * C + c + 1;
                internal_w_read_address <= 1;
                // input_valid is set and first multiply operation takes place in the next cycle
                // mac_pipe will also have the bias value inside accumulator_reg in the next cycle
            end

            COMPUTING_ACC_STATE: begin
                if(kernel_counter_for_acc >= (k_latched * k_latched)) begin
                    kernel_counter_for_acc <= kernel_counter_for_acc;
                end else begin
                    kernel_counter_for_acc <= kernel_counter_for_acc + 1;
                end

                // continue multiply-accumulation handled by mac_pipe module
                //  for i=0 to K-1:
                //      for j=0 to K-1:
                //          accumulator_reg += X[r+i][c+j] * W[i][j]

                if(j >= k_latched - 1) begin
                    j <= '0;
                    if(i < k_latched - 1) begin
                        i <= i + 1;
                    end
                end else begin
                    j <= j + 1;
                end

                if(kernel_counter_for_acc < k_latched * k_latched - 2) begin    // LOTS OF QUESTIONS MARKS HERE
                    // *note [0][0] was already handled in INIT_PIXEL_STATE*
                    if(j >= k_latched - 1) begin
                        // move to next row of kernel
                        internal_x_read_address <= ((r + i + 1) * C) + c; 
                        internal_w_read_address <= ((i + 1) * k_latched);
                    end else begin
                        // move to next column of kernel
                        internal_x_read_address <= ((r + i) * C) + (c + j + 1); 
                        internal_w_read_address <= (i * k_latched) + (j + 1);
                    end
                end
                // accumulate operation of pixel takes place on the next cycle
            end

            WRITE_PIXEL_STATE: begin
                // should take one cycle to write/pipe output pixel to FIFO
                // finished one output pixel
                //  for r=0 to Rout-1:
                //      for c=0 to Cout-1:
                //          accumulator_reg = b
                //          store accumulator_reg to FIFO
                if(FIFO_READY_TO_RECEIVE == 1) begin
                    if (c < C_out - 1) begin
                        c <= c + 1;
                    end else begin
                        c <= '0;
                        if(r < R_out - 1) begin
                            r <= r + 1;
                        end
                    end
                end
            end

            WAIT_FIRST_ADDR: begin
                internal_x_read_address <= (r * C) + c;
                internal_w_read_address <= '0;
            end

            DONE_STATE: begin
                r <= '0;
                c <= '0;
                i <= '0;
                j <= '0;
                kernel_counter_for_acc <= '0;
            end
        endcase
    end
    // =================== END OF SEQUENTIAL DATAPATH LOGIC =====================

    input_mems #(
        .INW(INW),
        .R(R),
        .C(C),
        .MAXK(MAXK)
    ) input_mems_instantiation(
        .clk(clk),                                  // input
        .reset(reset),                              // input 
        
        .AXIS_TDATA(INPUT_TDATA),                   // input
        .AXIS_TVALID(INPUT_TVALID),                 // input
        .AXIS_TUSER(INPUT_TUSER),                   // input
        .AXIS_TREADY(INPUT_TREADY),                 // output to this (top-level) input interface
        // *note: INPUT_TREADY let's us know that mem has room to begin accepting TDATA*
        
        .inputs_loaded(INPUT_MEMS_INPUT_LOADED_DATA_OUT),    // output to mac_pipe
        .compute_finished(COMPUTE_FINISHED_DATA_IN),        // input from 
        .K(INPUT_MEMS_K_DATA_OUT),                          // output to 
        .B(INPUT_MEMS_B_DATA_OUT),                          // output to mac_pipe
        .X_read_addr(internal_x_read_address),              // input from mac_pipe
        .X_data(INPUT_MEMS_X_DATA_OUT),                     // output to mac_pipe
        .W_read_addr(internal_w_read_address),              // input from mac_pipe
        .W_data(INPUT_MEMS_W_DATA_OUT)                      // output to mac_pipe
    );

    mac_pipe #(
        .INW(INW),
        .OUTW(OUTW)
    ) mac_pipe_instantiation(
        .input0(INPUT_MEMS_X_DATA_OUT),
        .input1(INPUT_MEMS_W_DATA_OUT),
        // sign-extend the bias (INW) up to OUTW and feed it as the initial accumulator value
        .init_value(INPUT_MEMS_B_DATA_OUT),   // accumulator_reg <= B
        .out(MAC_PIPE_DATA_OUT),        // FIFO <= accumulator_reg if IN_AXIS_TVALID==1

        .clk(clk),
        .reset(reset),
        .init_acc(INITIALIZE_ACCUMULATOR),    // dictated by the kernel size
        .input_valid(DATA_AVAILABLE)  // dictated by inputs loaded signal (when w, b, x are finished loading)
    );    

    fifo_out #(
        .OUTW(OUTW),
        .DEPTH(NUM_ENTRIES_FIFO)
    ) fifo_out_instantiation(
        .clk(clk),
        .reset(reset),
        // input interface from mac_pipe
        .IN_AXIS_TDATA(MAC_PIPE_DATA_OUT),
        .IN_AXIS_TVALID(MAC_OUTPUT_VALID),
        .IN_AXIS_TREADY(FIFO_READY_TO_RECEIVE),
        // this top-level output interface
        .OUT_AXIS_TDATA(OUTPUT_TDATA),
        .OUT_AXIS_TVALID(OUTPUT_TVALID),
        .OUT_AXIS_TREADY(OUTPUT_TREADY)
    );
endmodule