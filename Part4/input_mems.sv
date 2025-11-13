// Stony Brook University
// Fall 2025 ESE 507 
// Professor Peter Milder
// Huabin Wu (115067644)
// Ryan Lin (114737153)
// Project: Hardware Accelerator for 2D Convolution
// Project Part 3: Input Memories

module input_mems #(
    parameter INW = 10,
    parameter R = 15,
    parameter C = 13,
    parameter MAXK = 7,
    localparam K_BITS = $clog2(MAXK+1),
    
    localparam X_ADDR_BITS = $clog2(R*C),
    localparam W_ADDR_BITS = $clog2(MAXK*MAXK)
)(
    input                clk, reset,

    input [INW-1:0]      AXIS_TDATA,
    input                AXIS_TVALID,
    input [K_BITS:0]     AXIS_TUSER,    // check breakdown below
    output logic         AXIS_TREADY,

    output logic         inputs_loaded, 
    //tells the module when the system is done computing the convolutionn 
    //on the matricies stored in memory. When asserted on pos edge, set 
    //inputs_loaded to 0 and go to initial statte to begin loading new inputs
    input                compute_finished, 
            
    output logic [K_BITS-1:0]       K,          // kernel size - send when inputs_loaded = 1

    output logic signed [INW-1:0]   B,          // bias value - send when inputs_loadeed = 1

    // Interface for X memory
    input [X_ADDR_BITS-1:0]         X_read_addr,    // read data from X input matrix memory
    output logic signed [INW-1:0]   X_data,             //

    // Interface for W memory
    input [W_ADDR_BITS-1:0]         W_read_addr,    // read data from W weight matrix memory
    output logic signed [INW-1:0]   W_data              //
);

    //-----AXIS_TUSER breakdown-----
    // - new_W is only meaningful (checked) on the first cycle of input data transfer
    // - new_W is read at the same time as TUSER_K
    // - new_W = 1 -> AXIS_TDATA starts with W matrix data
    // - new_W = 0 -> AXIS_TDATA starts with X matrix data, and uses previously stored
    //  W matrix + B value
    //             -> K value is treated as 'don't care' but should be same as previous K

    logic [K_BITS-1 : 0]    TUSER_K;    // size of the kernel K variable
    logic                   new_W;      // control bit to indicate whether a new W matrix is being sent

    assign TUSER_K = AXIS_TUSER[K_BITS : 1];
    assign new_W = AXIS_TUSER[0];   
    //-----END OF AXIS_TUSER breakdown-----

    logic enable;
    assign enable = (AXIS_TVALID && AXIS_TREADY);

    logic W_wr_en;
    logic X_wr_en;
    
    typedef enum logic [2:0] {
        idle_state = 3'd0,
        input_W_matrix_state = 3'd1,
        input_B_value_state = 3'd2,
        input_X_matrix_state = 3'd3,
        inputs_loaded_state = 3'd4
    } state_t;
    
    state_t current_state, next_state;

    logic W_is_done;
    logic B_is_done;
    logic X_is_done;

    logic [W_ADDR_BITS-1 : 0] W_write_counter;
    logic [X_ADDR_BITS-1 : 0] X_write_counter;
    logic [W_ADDR_BITS-1 : 0] internal_w_addr;
    logic [X_ADDR_BITS-1 : 0] internal_x_addr;

    //------------------NEXT STATE LOGIC--------------------
    always_comb begin
        next_state = current_state;

        case(current_state)
            idle_state: begin   // "first cycle" of input data transfer
                if(new_W) begin
                    next_state = input_W_matrix_state;
                end
                else if(new_W == 0) begin
                    next_state = input_X_matrix_state;
                end
                else begin
                    next_state = idle_state;
                end
            end
 
            input_W_matrix_state: begin
                if(W_is_done) begin
                    next_state = input_B_value_state;
                end
                else begin
                    next_state = input_W_matrix_state;
                end
            end
            /* Input B: In this phase, the module will take in the B (bias) value via the AXI-Stream input
            interface. Remember, B is a single (scalar) value, so only one word is received. This word
            will be stored in the B register. This phase is complete after one word is loaded. This step
            is skipped if new_W was 0 at the start of the input operation above. */
            input_B_value_state: begin
                if(B_is_done) begin
                    next_state = input_X_matrix_state;
                end
                else begin
                    next_state = input_B_value_state;
                end
            end
            /* Input X Matrix: In this phase, the module will take in X matrix data via its AXI-Stream
            input interface. This data will be stored in the X memory. This phase is complete after the
            entire X matrix is loaded (R*C values). */
            input_X_matrix_state: begin
                if(X_is_done) begin
                    next_state = inputs_loaded_state;
                end
                else begin
                    next_state = input_X_matrix_state;
                end
            end
            /* Inputs Loaded: The inputs_loaded phase begins after the inputs are complete. Your system
            will output inputs_loaded=1 during this phase. In this phase, your system should ensure
            that the K and B output signals hold the correct value of K and B. During this phase, your
            system is not ready to receive new inputs, so it must output AXIS_TREADY=0.
            During this phase, your system will allow the memory read interfaces (on the right side of
            Figure 3.1) to read data from the matrix memories. This means that during this phase, the
            X_read_addr and W_read_addr input signals should be used to provide addresses to
            their respective memories.
            While in this phase, your system should monitor the compute_finished input signal.
            When compute_finished==1 on a positive clock edge, your system should exit this
            phase, set inputs_loaded to 0, and go back to the beginning, waiting for new input data. */
            inputs_loaded_state: begin
                if(compute_finished) begin
                    next_state = idle_state;
                end
                else begin
                    next_state = inputs_loaded_state;
                end
            end

            default: begin
                next_state = idle_state;
            end
        endcase
    end
    //------------------END OF NEXT STATE LOGIC--------------------


    //-------------------OUTPUT LOGIC--------------------
    always_comb begin
        inputs_loaded = 0;      // extra measure
        internal_w_addr = W_read_addr;
        internal_x_addr = X_read_addr;
        W_wr_en = 0;
        X_wr_en = 0;

        // logic to look ahead
        if((next_state == input_W_matrix_state) && enable) begin
            W_wr_en = 1;
            internal_w_addr = W_write_counter;
        end
        
        if((next_state == input_X_matrix_state) && enable) begin
            X_wr_en = 1;
            internal_x_addr = X_write_counter;
        end
        //
        
        case(current_state) 
            idle_state: begin
                AXIS_TREADY = 1;
            end

            input_W_matrix_state: begin
                AXIS_TREADY = 1;
                internal_w_addr = W_write_counter;
                W_wr_en = enable;

                if(next_state == input_B_value_state) begin
                    W_wr_en = 0;
                end
            end

            input_B_value_state: begin
                AXIS_TREADY = 1;
            end

            input_X_matrix_state: begin
                AXIS_TREADY = 1;
                internal_x_addr = X_write_counter;
                X_wr_en = enable;

                if(next_state == inputs_loaded_state) begin
                    AXIS_TREADY = 0;            // should pull X_wr_en low at the same time
                end
            end
                                                                // during input loaded state, the convolution module will read from this memory
            inputs_loaded_state: begin                          // based on the read addresses provided (W_read_addr and X_read_addr)
                if(compute_finished) begin
                    inputs_loaded = 0;
                end

                inputs_loaded = 1;              
                AXIS_TREADY = 0;
            end
        endcase
    end
    //-------------------END OF OUTPUT LOGIC--------------------



    //------------------REGISTER AND MEMORY LOGIC--------------------
    // K register logic
    always_ff @(posedge clk) begin
        if(reset) begin
            K <= '0;
        end
        else if((current_state == idle_state) && enable && new_W) begin
            K <= TUSER_K;
        end             
        else begin
            K <= K;     
        end
    end

    // B register logic
    always_ff @(posedge clk) begin
        if(reset) begin
            B <= '0;
            B_is_done <= 0;
        end 
        else if((current_state == input_B_value_state) && (next_state != input_B_value_state)) begin
            B_is_done <= 0;
        end
        else if(((current_state == input_W_matrix_state) && (next_state == input_B_value_state) || (current_state == input_B_value_state )) && enable) begin
            B <= AXIS_TDATA;
            B_is_done <= 1;
        end
    end

    // W matrix register logic
    memory #(
        .WIDTH(INW),
        .SIZE(MAXK*MAXK)
    ) W_memory_inst (
        .data_in(AXIS_TDATA),
        .data_out(W_data),
        .addr(internal_w_addr),
        .clk(clk),
        .wr_en(W_wr_en)
    );

    // X matrix register logic
    memory #(
        .WIDTH(INW),
        .SIZE(R*C)
    ) X_memory_inst (
        .data_in(AXIS_TDATA),
        .data_out(X_data),
        .addr(internal_x_addr),
        .clk(clk),
        .wr_en(X_wr_en)
    );
    //------------------END OF REGISTER AND MEMORY LOGIC--------------------


    //------------------COUNTER LOGIC--------------------
 // W address pointer + done signal
    always_ff @(posedge clk) begin
        if(reset) begin
            W_is_done <= '0;
            W_write_counter <= 0;
        end
        else if((current_state != input_W_matrix_state) && 
                !((current_state == idle_state) && (next_state == input_W_matrix_state) && enable)) begin
            W_is_done <= 0;
            W_write_counter <= 0;
        end
        else if (enable && ((current_state == input_W_matrix_state) || 
                ((current_state == idle_state) && (next_state == input_W_matrix_state))) && !W_is_done) begin
            W_write_counter <= W_write_counter + 1;
            
            if (W_write_counter == (K*K - 1)) begin  // Set done BEFORE last write
                W_is_done <= 1;
            end
        end
    end

     // X address Pointer + done signal
    always_ff @(posedge clk) begin
        if(reset) begin
            X_is_done <= 0;
            X_write_counter <= 0;
        end
        else if((current_state != input_X_matrix_state) && 
                !(((current_state == input_B_value_state) && (next_state == input_X_matrix_state)) || 
                ((current_state == idle_state) && (next_state == input_X_matrix_state)) && enable)) begin
            X_is_done <= 0;
            X_write_counter <= 0;
        end
        else if (enable && ((current_state == input_X_matrix_state) || 
                ((current_state == idle_state) && (next_state == input_X_matrix_state)) ||
                ((current_state == input_B_value_state) && (next_state == input_X_matrix_state))) && !X_is_done) begin
            X_write_counter <= X_write_counter + 1;

            if (X_write_counter == (R*C - 1)) begin  // Set done BEFORE last write
                X_is_done <= 1;
            end
        end
    end
    //------------------END OF COUNTER LOGIC--------------------
            
    // sequential block
    always_ff @(posedge clk) begin
        if(reset) begin
            current_state <= idle_state;
        end 
        else begin
            current_state <= next_state;
        end
    end
endmodule

module memory #(
    parameter   WIDTH = 16, SIZE = 64,
    localparam  LOGSIZE = $clog2(SIZE)
)(
    input [WIDTH-1:0]           data_in,
    output logic [WIDTH-1:0]    data_out,
    input [LOGSIZE-1:0]         addr,
    input                       clk, wr_en
);
    logic [SIZE-1:0][WIDTH-1:0] mem;

    always_ff @(posedge clk) begin
        data_out <= mem[addr];
        if(wr_en) 
            mem[addr] <= data_in;
        end
endmodule