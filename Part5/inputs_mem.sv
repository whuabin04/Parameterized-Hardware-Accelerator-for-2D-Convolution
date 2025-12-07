// Stony Brook University
// Fall 2025 ESE 507 
// Professor Peter Milder
// Huabin Wu (115067644)
// Ryan Lin (114737153)
// Project: Hardware Accelerator for 2D Convolution
// Project Part 3: Input Memories

module input_mems #(
    parameter INW = 24,
    parameter R = 9,
    parameter C = 8,
    parameter MAXK = 4,
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
    //Tells the module when the system is done computing the convolution 
    //on the matrices stored in memory. When asserted on pos edge, set 
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
    //-----END OF AXIS_TUSER breakdown-----

    logic [K_BITS-1 : 0]    TUSER_K;    // size of the kernel K variable
    logic                   new_W;      // control bit to indicate whether a new W matrix is being sent

    assign TUSER_K = AXIS_TUSER[K_BITS : 1];
    assign new_W = AXIS_TUSER[0];   

    logic data_receivable;
    assign data_receivable = (AXIS_TVALID && AXIS_TREADY);

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

    logic unsigned [W_ADDR_BITS-1 : 0] W_write_counter;
    logic unsigned [X_ADDR_BITS-1 : 0] X_write_counter;
    logic unsigned [W_ADDR_BITS-1 : 0] internal_w_addr;
    logic unsigned [X_ADDR_BITS-1 : 0] internal_x_addr;
            
    // sequential logic to handle state transitions
    always_ff @(posedge clk) begin
        if(reset) begin
            current_state <= idle_state;
        end 
        else begin
            current_state <= next_state;
        end
    end

    // next state logic
    always_comb begin
        next_state = current_state;

        case(current_state)
            idle_state: begin
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
                if(data_receivable && (W_write_counter == (K*K - 1))) begin // ensure last data is written
                    next_state = input_B_value_state;
                end
                else begin
                    next_state = input_W_matrix_state;
                end
            end

            input_B_value_state: begin
                if(data_receivable) begin
                    next_state = input_X_matrix_state;
                end
            end

            input_X_matrix_state: begin
                if(data_receivable && (X_write_counter == (R*C - 1))) begin
                    next_state = inputs_loaded_state;
                end
                else begin
                    next_state = input_X_matrix_state;
                end
            end

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

    // output state logic
    always_comb begin
        W_wr_en = 1'b0;     // immediately disable write enables outside of write states
        X_wr_en = 1'b0;
        inputs_loaded = 1'b0;
        AXIS_TREADY = 1'b0;
        internal_w_addr = W_write_counter;
        internal_x_addr = X_write_counter;

        case(current_state)
            idle_state: begin
                AXIS_TREADY = 1'b1;
                inputs_loaded = 1'b0;

                // handle the case where data starts arriving immediately after reset
                if(data_receivable) begin
                    if(new_W) begin
                        W_wr_en = 1'b1;
                    end
                    else if(new_W == 0) begin
                        X_wr_en = 1'b1;
                    end
                end
            end

            input_W_matrix_state: begin
                AXIS_TREADY = 1'b1;
                W_wr_en = data_receivable;
            end

            input_B_value_state: begin
                AXIS_TREADY = 1'b1;
            end

            input_X_matrix_state: begin
                AXIS_TREADY = 1'b1;
                X_wr_en = data_receivable;
            end

            inputs_loaded_state: begin
                inputs_loaded = 1'b1;
                AXIS_TREADY = 1'b0;    // not ready to accept new data
                internal_w_addr = W_read_addr;
                internal_x_addr = X_read_addr;
            end
        endcase
    end
    
    // counter and register logic
    always_ff @(posedge clk) begin
        if(reset) begin
            W_write_counter <= '0;
            X_write_counter <= '0;
            B <= '0;
            K <= '0;
        end

        case(current_state)
            idle_state: begin
                // handle the case where we start receiving data
                // immediately after reset with lookahead counting
                if(new_W) begin
                    W_write_counter <= 1;
                    K <= TUSER_K;
                end
                else if(new_W == 0) begin
                    X_write_counter <= 1;
                end
            end

            input_W_matrix_state: begin
                if(data_receivable) begin
                    W_write_counter <= W_write_counter + 1;
                end
                // W <= AXIS_TDATA;   // handled in memory write
            end

            input_B_value_state: begin
                if(data_receivable) begin
                    B <= AXIS_TDATA;
                end
            end

            input_X_matrix_state: begin
                if(data_receivable) begin
                    X_write_counter <= X_write_counter + 1;
                end
                // X <= AXIS_TDATA;   // handled in memory write
            end

            inputs_loaded_state: begin
                // makes sure counters are reset right before idle_state
                if(compute_finished) begin
                    W_write_counter <= '0;
                    X_write_counter <= '0;
                end
            end
        endcase
    end

    // W matrix register instance
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

    // X matrix register instance
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