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

    logic signed [2*INW-1 : 0] piped_product;
    logic enable_accumulate;

    // more determistic approach
    always_ff @(posedge clk) begin // multiply to be independent of init_acc control signal
        if (reset) begin
            piped_product <= '0;
            enable_accumulate <= 1'b0;
        end

        else begin
            piped_product <= input0 * input1;
            enable_accumulate <= input_valid; // pipe the input_valid signal
        end
    end

    always_ff @(posedge clk) begin
        unique if (reset) begin
            out <= '0;  // reset the accumulator to 0
        end

        else if (init_acc) begin // assume reset takes precedence
            out <= init_value;  // load the initial value into the accumulator
        end

        else if (enable_accumulate) begin
            out <= piped_product + out;
        end

        // else holds current accumulator value
    end
endmodule