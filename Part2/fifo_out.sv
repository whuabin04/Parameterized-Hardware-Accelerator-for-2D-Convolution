// Stony Brook University
// Fall 2025 ESE 507 
// Professor Peter Milder
// Huabin Wu (115067644)
// Ryan Lin (114737153)
// Project Part 2: Output FIFO


module fifo_out #(
    parameter   OUTW = 24,  // # of btis for each data word
    parameter   DEPTH = 19, // # of entries in the FIFO
    localparam  LOGDEPTH = $clog2(DEPTH)
)(
    input               clk, reset,

    input [OUTW-1 : 0]  IN_AXIS_TDATA,      // receiving interface
    input               IN_AXIS_TVALID, 
    output              IN_AXIS_TREADY,     

    output [OUTW-1 : 0] OUT_AXIS_TDATA,     // transmitting interface
    output              OUT_AXIS_TVALID
    input               OUT_AXIS_TREADY     
);

    logic wr_en, rd_en;
    assign wr_en = (IN_AXIS_TVALID && IN_AXIS_TREADY);    // write enable signal for receiving side
    assign rd_en = (OUT_AXIS_TVALID && OUT_AXIS_TREADY);  // read enable signal for transmitting side

  //----------------------------------------------------------
    //  Capacity counter  (0 = full, DEPTH = empty)
    //----------------------------------------------------------
    logic [$clog2(DEPTH+1)-1 : 0] capacity;             // capacity ranges from 0 to DEPTH   
                                                        // think how many spaces are available in the FIFO          

    assign OUT_AXIS_TVALID = (capacity < DEPTH);        // drives OUT_AXIS_TVALID - valid if *receiving* FIFO is not empty
    assign IN_AXIS_TREADY = (capacity >= 0);             // drives IN_AXIS_TREADY - ready if *receiving* FIFO is not full
    
    always_ff @(posedge clk) begin
        if(reset) begin

            capacity <= DEPTH;                      // think capacity as space available

        end else begin

            case ({rd_en, wr_en})
                2'b10: capacity <= capacity + 1;    // reading, but not writing, increase the capacity by 1
                2'b01: capacity <= capacity - 1;    // writing, but not reading, decrease the capacity by 1
                default: capacity <= capacity;      // no change
            endcase

        end
    end
    
    /////////////////////////////////////////////////////////////////////////



    logic [LOGDEPTH-1 : 0] read_ptr; 
    logic [LOGDEPTH-1 : 0] wr_addr, rd_addr;

    // assert IN_AXIS_TVALID to write
    // assert OUT_AXIS_TREADY to read

    // head write address logic 
    always_ff @(posedge clk) begin
        if(reset) begin
            wr_addr <= '0;
        end
        else if() begin
            wr_addr <= wr_addr + 1;
        end
    end

    // tail read address logic
    //read_pointer == tail on the graph
    always_comb begin
        if (rd_en) begin
            rd_addr = read_ptr + 1;
        end else begin
            rd_addr = read_ptr;
        end
    end
    always_ff @(posedge clk) begin
        if(reset) begin
            read_ptr <= '0;
        end else begin                  // advance the read address when reading
            read_ptr <= rd_addr;
        end
    end

    // main fifo logic
    always_ff @(posedge clk) begin
        if(reset) begin
            OUT_AXIS_TDATA <= '0;
        end
    end 

    memory_dual_port #(
        .WIDTH(OUTW),
        .SIZE(DEPTH)
    ) fifo_mem (
        .data_in(IN_AXIS_TDATA),
        .data_out(OUT_AXIS_TDATA),
        .write_addr(wr_addr),
        .read_addr(read_ptr),
        .clk(clk),
        .wr_en(wr_en)
    );


endmodule

module memory_dual_port #(
        parameter   WIDTH=16,  // bit width of each word
        parameter   SIZE=64,   // # of words stored in memory
        localparam  LOGSIZE=$clog2(SIZE)
    )(
        input [WIDTH-1:0]        data_in,
        output logic [WIDTH-1:0] data_out,
        input [LOGSIZE-1:0]      write_addr, read_addr,
        input                    clk, wr_en
    );

    logic [SIZE-1:0][WIDTH-1:0] mem;

    always_ff @(posedge clk) begin
        // if we are reading and writing to same address concurrently, 
        // then output the new data
        if (wr_en && (read_addr == write_addr))
            data_out <= data_in;
        else
            data_out <= mem[read_addr];

        if (wr_en)
            mem[write_addr] <= data_in;            
    end
endmodule