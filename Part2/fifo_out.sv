//// Stony Brook University
// Fall 2025 ESE 507 
// Professor Peter Milder
// Huabin Wu (115067644)
// Ryan Lin (114737153)

//top level module for fifo output
module fifo_out #(
    parameter OUTW = 24, // output width
    parameter DEPTH = 19 // FIFO depth
    localparam  = LOGDEPTH = $clog2(DEPTH)
)(
    input clk,
    input reset,
    input [OUTW-1:0] IN_AXIS_TDATA,
    input IN_AXIS_TVALID,
    output logic IN_AXIS_TREADY,
    output logic [OUTW-1:0] OUT_AXIS_TDATA,
    output logic OUT_AXIS_TVALID,
    input OUT_AXIS_TREADY
);
    //logic signals
    logic fifo_full, fifo_empty;

module memory_dual_port #(
    parameter WIDTH = 16, SIZE = 64
    localparam LOGSIZE = $clog2(SIZE)
)(
    input [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out,
    input [LOGSIZE-1:0] write_addr, read_addr,
    input clk, wr_en
);
    logic [SIZE-1:0][WIDTH-1:0] mem;

    always_ff @(posedge clk) begin
        if (wr_en && (read_addr == write_addr))
            data_out <= data_in; 
        else
            data_out <= mem[read_addr];
        if (wr_en)
            mem[write_addr] <= data_in;
    end
endmodule