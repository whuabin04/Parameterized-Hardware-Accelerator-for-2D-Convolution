// ESE 507 Stony Brook University
// Peter Milder
// You may not redistribute this code.
// Testbench for mac_pipe and mac_unpipe modules

// To use this testbench:
// Compile it and your accompanying design with:
//   vlog -64 +acc mac_tb.sv [add your other .sv files to simulate here]
//   vsim -64 -c mac_tb -sv_seed random 
//      [options]:
//       - If you want to run in GUI mode, remove -c

// Note that this testbench relies on params.sv, which can be generated 
// using the ./genParams1 script. See instructions in the project description.

// Please see the project description for a high-level description of this testbench and how to run it. Comments are also included throughout to help understand how the testbench works.

// Import the C functions (from mac_tb.c) that will calculate the expected outputs of the MAC unit, for pipelined and unpipelined MACs.
import "DPI-C" function void sim_cycle_pipelined(input int input0, input int input1, input int init_value, input bit input_valid, input bit init_acc, output longint res, input int OUTW);
import "DPI-C" function void sim_cycle_unpipelined(input int input0, input int input1, input int init_value, input bit input_valid, input bit init_acc, output longint res, input int OUTW);

// Include the params.sv file, which holds the parameter values
`include "params.sv"

// A class to hold one instance of test data and associated control logic.
// When we call  .randomize() on an object of this class, it will randomly 
// generate values for the inputs input0, input1, and control signals input_valid and 
// init_acc. The init_acc signal will be constrained such that it is usually 
// (99%) of the time 0.
class testdata #(parameter INW=8, OUTW=20);
    rand logic signed [INW-1:0] input0, input1, init_value;
    rand bit input_valid;
    rand bit init_acc;
    constraint c {init_acc dist {0:=99, 1:=1};}
endclass

    

module mac_tb();
    
    parameter TESTS = 10000;             // the number of cycles of input to simulate
    parameter INW   = `INWVAL;           // the number of bits in the inputs
    parameter OUTW  = `OUTWVAL;          // the number of bits in the output
    parameter PIPELINED = `PIPELINEDVAL; // 0 for unpipelined design, 1 for pipelined design

    logic clk, reset;
    initial clk = 0;
    always #5 clk = ~clk;

    logic signed [INW-1:0] input0, input1, init_value;
    logic signed [OUTW-1:0] out, out_exp;
    logic input_valid, init_acc;

    // Instantiate the DUT based on PIPELINED parameter
    generate 
        if (PIPELINED == 1)
            mac_pipe #(INW, OUTW) dut(input0, input1, init_value, out, clk, reset, init_acc, input_valid);
        else
            mac #(INW, OUTW) dut(input0, input1, init_value, out, clk, reset, init_acc, input_valid);
    endgenerate

    // An object of class "testdata" (See class definition above)
    testdata #(INW, OUTW) td;

    // Count how many times the testbench identifies errors in the design.
    logic [31:0] errors;

    // Check and display simulation parameters
    initial begin
        if ((INW < 2) || (INW >= 32)) begin
            $error("PARAMETER ERROR: INW must be >= 2 and < 32");
            $stop;
        end
        
        if ((OUTW < 2) || (OUTW > 64)) begin
            $error("PARAMETER ERROR: OUTW must be >= 2 and <= 64");
            $stop;
        end

        $display("--------------------------------------------------------");
        $display("Starting MAC unit simulation: %d tests", TESTS);
        $display("Pipelining: %d", PIPELINED);            
        $display("Input %d bits\nOutput: %d bits", INW, OUTW);
        $display("--------------------------------------------------------");
    end


    initial begin
        errors = 0;
        reset = 1;
        input_valid = 0;
        init_acc = 0;
        @(posedge clk);
        #1;

        td = new();

        // For each test, randomize the td object. Then set the DUT inputs
        // to match. Lastly, call the appropriate C function using the DPI
        // interface, which will compute the expected output for this
        // cycle, and check that the result matches.
        repeat(TESTS) begin
            reset = 0;
            assert(td.randomize());
            input0 = td.input0;
            input1 = td.input1;
            init_value = td.init_value;
            input_valid = td.input_valid;
            init_acc = td.init_acc;            

            if (PIPELINED == 1)
                sim_cycle_pipelined(td.input0, td.input1, td.init_value, td.input_valid, td.init_acc, out_exp, OUTW);
            else 
                sim_cycle_unpipelined(td.input0, td.input1, td.init_value, td.input_valid, td.init_acc, out_exp, OUTW);

            @(posedge clk);
            #1;

            if (out !== out_exp) begin
                $display($time,, "ERROR: MAC output: %d. Expected output: %d", out, out_exp);
                errors = errors+1;

                if (errors >= 100) begin
                    $display($time,, "100 errors reached. Stopping simulation early.");
                    $finish;
                end
            end

        end

        $display("Simulation finished with %d errors", errors);

        #10;
        $finish;
    end

endmodule

