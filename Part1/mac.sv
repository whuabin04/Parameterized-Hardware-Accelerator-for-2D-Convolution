// Stony Brook University
// Fall 2025 ESE 507 
// Professor Peter Milder
// Huabin Wu (115067644)
// Ryan Lin (114737153)

module mac #(      // default
    parameter INW = 16, // input width
    parameter OUTW = 64 // output width
)(
    // IO signals
    input signed [INW-1 : 0] input0, input1,
    input signed [INW-1 : 0] init_value, // initialized value for accumulator after init_acc asserted
    output logic signed [OUTW-1 : 0] out,
    // control signals
    input logic clk,       
    input logic reset,    
    input logic init_acc,       // initialize the accumulator (synchronous)
    input logic input_valid     // new inputs available flag (synchronous)
);

    logic signed [2*INW-1 : 0] product;

    always_comb begin
        product = input0 * input1;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            out <= '0;  // reset the accumulator to 0
        end

        else if (init_acc) // assume reset takes precedence
            out <= init_value;  // load the initial value into the accumulator

        else if (input_valid)
            out <= product + out;
    end
endmodule
