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
    input               IN_AXIS_TVALID,     // *think - the transmitter is telling us that there is some data coming in*
    output              IN_AXIS_TREADY,     // *think - this receiver has available space to receive data*

    output logic [OUTW-1 : 0]   OUT_AXIS_TDATA,     // transmitting interface
    output logic                OUT_AXIS_TVALID,    // *think - this transmitter has some valid data to be read*
    input                       OUT_AXIS_TREADY     // *think - the receiving end has available space to take in data from us*
);

    logic wr_en, rd_en;
    assign wr_en = (IN_AXIS_TVALID && IN_AXIS_TREADY);    // write enable signal for receiving side
    assign rd_en = (OUT_AXIS_TVALID && OUT_AXIS_TREADY);  // read enable signal for transmitting side

    //----------------------------------------------------------
    //  capacity logic  (0 = full, DEPTH = empty)
    //----------------------------------------------------------
    logic unsigned [$clog2(DEPTH+1)-1 : 0] capacity;             // capacity ranges from 0 to DEPTH   
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
    //----------------------------------------------------------

    logic [LOGDEPTH-1 : 0] read_ptr; 
    logic [LOGDEPTH-1 : 0] wr_addr, rd_addr;

    //----------------------------------------------------------
    //  head write address logic 
    //----------------------------------------------------------
    always_ff @(posedge clk) begin
        if(reset) begin

            wr_addr <= '0;

        end else if(wr_en) begin

            if(wr_addr == DEPTH - 1) begin

                wr_addr <= '0;

            end else begin

                wr_addr <= wr_addr + 1;

            end
        end
    end
    //----------------------------------------------------------


    //----------------------------------------------------------
    // tail read address logic
    //----------------------------------------------------------
    always_ff @(posedge clk) begin
        if(reset) begin

            read_ptr <= '0;         // read_pointer == tail on the graph

        end else if(rd_en) begin 

            if(read_ptr == DEPTH - 1) begin

                read_ptr <= '0;

            end else begin

                read_ptr <= read_ptr + 1;

            end
        end
    end

    always_comb begin
        if(rd_en == 0) begin

            rd_addr = read_ptr;

        end else begin

            if(read_ptr == DEPTH - 1) begin

                rd_addr = '0;

            end else begin

                rd_addr = read_ptr + 1;
                
            end
        end
    end
    //----------------------------------------------------------

    memory_dual_port #(
        .WIDTH(OUTW),
        .SIZE(DEPTH)
    ) fifo_mem (
        .data_in(IN_AXIS_TDATA),
        .data_out(OUT_AXIS_TDATA),
        .write_addr(wr_addr),
        .read_addr(rd_addr),
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