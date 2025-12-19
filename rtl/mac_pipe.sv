// Stony Brook University
// Fall 2025 ESE 507 
// Professor Peter Milder
// Huabin Wu (115067644)
// Ryan Lin (114737153)
// Project: Hardware Accelerator for 2D Convolution
// Part 1: Multiply-Accumulate Computation Unit

module mac_pipe #(      // default
    parameter INW = 16, // input width
    parameter OUTW = 64 // output width
)(
    // IO signals
    input logic signed [INW-1 : 0] input0, input1,
    input logic signed [INW-1 : 0] init_value, // initialized value for accumulator after init_acc asserted
    output logic signed [OUTW-1 : 0] out,
    // control signals
    input logic clk,       
    input logic reset,    
    input logic init_acc,       // initialize the accumulator (synchronous)
    input logic input_valid     // new inputs available flag (synchronous)
);    
    
    localparam MULTI_PIPELINE_STAGES = 2;
    logic signed [INW-1 : 0] input0_reg, input1_reg;
    logic signed [OUTW-1 : 0] product_ext;
    logic signed [2*INW-1 : 0] piped_product;
    logic [MULTI_PIPELINE_STAGES-1:0] enable_pipe;
    logic enable_accumulate;

    always_ff @(posedge clk) begin
        if(reset) begin
            input0_reg <= '0;
            input1_reg <= '0;
        end
        else if(input_valid) begin
            input0_reg <= input0;
            input1_reg <= input1;
        end
        else begin
            input0_reg <= input0_reg;
            input1_reg <= input1_reg;
        end
    end

    DW02_mult_2_stage #(
        .A_width(INW),
        .B_width(INW)
    ) DW_mult_inst (
        .A(input0_reg),
        .B(input1_reg),
        .TC(1'b1),      // signed multiplication
        .CLK(clk),
        .PRODUCT(piped_product)
    );    

    assign product_ext = {{(OUTW-2*INW){piped_product[2*INW-1]}}, piped_product};   // ensure sign extension

    always_ff @(posedge clk) begin
        if(reset) begin
            enable_pipe <= '0;
        end else if(init_acc) begin
            enable_pipe <= '0;
        end else begin
            enable_pipe <= {enable_pipe[MULTI_PIPELINE_STAGES-2:0], input_valid};
        end
    end
    // shift out enable_pipe and take the MSB depending on # of stages
    assign enable_accumulate = enable_pipe[MULTI_PIPELINE_STAGES-1];

    always_ff @(posedge clk) begin
        if(reset) begin
            out <= '0;  // reset the accumulator to 0
        end
        else if(init_acc) begin // assume reset takes precedence
            out <= init_value;  // Sign-extend
        end
        else if(enable_accumulate) begin
            out <= out + product_ext; // accumulate the product
        end
        // else holds current accumulator value
    end
endmodule