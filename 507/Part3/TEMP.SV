// ESE-507, Peter Milder
// Example from Topic 9
// This system assumes a 1024-word memory is pre-loaded with 16-bit unsigned values.
// The system will find the largest word from the memory, and store it to address 0.

// Since we are assuming the memory is pre-loaded, we can model this in simulation
// using an initial block. (See "memory" module.)
// This initial block is not synthesizable, and would not be an appropriate way to
// build anything you intend to synthesize.

// To build a real version of this for synthesis, you would also need to
// include the mechanism to load the values into the memory.
// (And you would also want to use a real memory module.)


module top(input reset, clk);
    
    logic we, clr, inc, done;

    datapath d(clk, we, clr, inc, done);
    ctrlpath c(clk, reset, done, we, clr, inc);

endmodule


// Datapath contains: 
//  - memory
//  - a register to store the largest value seen so far
//  - a comparator to set the register's load signal
//  - the counter for the memory address
//  - a comparator to set the done signal

module datapath(
        input        clk, we, clr, inc,
        output       done
    );

    logic [15:0] data_out;
    reg   [9:0]  addr;  
    logic        load;
    logic [15:0] largest;
    
    memory #(16, 1024) m(clk, we, addr, largest, data_out);

    always_ff @(posedge clk) begin
        if (clr == 1)
            largest <= 16'h0;
        else if (load)
            largest <= data_out;      
    end
    
    assign load = data_out > largest;
    
    always_ff @(posedge clk) begin
        if (clr == 1)
            addr <= 0;
        else if (inc == 1)
            addr <= addr+1;      
    end
    
    assign done = (addr == 1023);
  
endmodule


module memory #(
        parameter  WIDTH=16, SIZE=256, 
        localparam LOGSIZE = $clog2(SIZE)
    )(
        input                clk, we,
        input  [LOGSIZE-1:0] addr,
        input  [WIDTH-1:0]   data_in,
        output [WIDTH-1:0]   data_out
    );

    logic [SIZE-1:0][WIDTH-1:0] mem;
    
    // -------------- Simulation only ----------------------- 
    // The following initial block is for simulation only!
    // It initializes the memory to random values, except
    // for the last location, which gets loaded with ffff.
    // In synthesis, this block is completely ignored.
    initial begin
        integer i;      
        for (i=0; i<1023; i=i+1)
            mem[i] = $random;
        
        mem[1023] = 16'hffff;      
    end
    // -------------------------------------------------------

    assign data_out = mem[addr];

    // I used "always" instead of "always_ff" here because SystemVerilog mandates
    // that always_ff be used only on structures that are synthesizable. In this case,
    // the simulation-only initial block above means that this structure is not
    // synthesizable, so QuestaSim gives an error with "always_ff". With normal
    // logic, you should use always_ff.
    always @(posedge clk) begin
        if (we)
            mem[addr] <= data_in;
    end

endmodule 

module ctrlpath(
        input       clk, reset, done,
        output      we, clr, inc
    );

    // parameter [1:0] STATE_INIT = 0, STATE_READING = 1, STATE_WRITING = 2, STATE_IDLE = 3;
    // logic [1:0] state, next_state;

    enum logic [1:0] {STATE_INIT, STATE_READING, STATE_WRITING, STATE_IDLE} state, next_state;

    always_ff @(posedge clk) begin
        if (reset == 1)
            state <= STATE_INIT;
        else
            state <= next_state;      
    end

    always_comb begin
        if (state == STATE_INIT)
            next_state = STATE_READING;
        else if (state == STATE_READING) 
            if (done == 1)
                next_state = STATE_WRITING;
            else
                next_state = STATE_READING;
        else
            next_state = STATE_IDLE;
    end

    assign we  = (state == STATE_WRITING);
    assign clr = (state == STATE_INIT);
    assign inc = (state == STATE_READING);

endmodule 

// Testbench to start system. To observe system behavior,
// use simulator to view waveforms.
module testbench();

    logic reset, clk;

    top dut(reset, clk);

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        reset = 0;      
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        #1; reset = 1;      
        @(posedge clk);
        #1;
        reset = 0;
        
        #10350;
        $stop;
        
    end 
endmodule 
