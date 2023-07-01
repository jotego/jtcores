`timescale 1ns / 1ps

module test;

reg        rst, clk, init_done, waiting;

reg [22:0] addr_req;
reg        rd_req, wr_req, rfsh_en;
reg [ 1:0] ba_req, din_m;
reg [15:0] din;

wire [31:0] dout;
wire        ack, rdy;
wire [ 1:0] ba_rdy;

// sdram pins
wire [15:0] sdram_dq;
wire [12:0] sdram_a;
wire [ 1:0] sdram_dqm;
wire [ 1:0] sdram_ba;
wire        sdram_nwe;
wire        sdram_ncas;
wire        sdram_nras;
wire        sdram_ncs;
wire        sdram_cke;

`ifndef PERIOD
`define PERIOD 10.416
`endif

localparam PERIOD=`PERIOD;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        addr_req <= 23'd0;
        rd_req   <= 0;
        wr_req   <= 0;
        ba_req   <= 2'd0;
        waiting  <= 0;
        rfsh_en  <= 1;
    end else if(init_done) begin
        `ifdef MAX_THROUGHPUT
        if(ack || !rd_req) begin
            rd_req <= 1;
            addr_req[19:0] <= $random;
            ba_req   <= ba_req + 2'd1;
            waiting  <= 1;
        end
        `else
        if( !waiting ) begin
            if( $random%100 > 50 ) begin
                addr_req[19:0] <= $random;
                if( $random%100>95 ) begin
                    rd_req <= 0;
                    wr_req <= 1;
                    din    <= $random;
                    din_m  <= $random;
                end else begin
                    rd_req <= 1;
                    wr_req <= 0;
                end
                ba_req   <= $random;
                waiting  <= 1;
            end
        end else if( ack ) begin
            waiting <= 0;
            wr_req <= 0;
            rd_req <= 0;
        end
        `endif
    end
end

jtframe_sdram_bank_core #(.AW(23)) uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .addr       ( addr_req      ),
    .rd         ( rd_req        ),
    .wr         ( wr_req        ),
    .rfsh_en    ( rfsh_en       ),
    .ba_rq      ( ba_req        ),
    .ack        ( ack           ),
    .rdy        ( rdy           ),
    .ba_rdy     ( ba_rdy        ),
    .din        ( din           ),
    .din_m      ( din_m         ),
    .dout       ( dout          ),
    // SDRAM pins
    .sdram_dq   ( sdram_dq      ),
    .sdram_a    ( sdram_a       ),
    .sdram_dqml ( sdram_dqm[0]  ),
    .sdram_dqmh ( sdram_dqm[1]  ),
    .sdram_ba   ( sdram_ba      ),
    .sdram_nwe  ( sdram_nwe     ),
    .sdram_ncas ( sdram_ncas    ),
    .sdram_nras ( sdram_nras    ),
    .sdram_ncs  ( sdram_ncs     ),
    .sdram_cke  ( sdram_cke     )
);


mt48lc16m16a2 sdram(
    .Clk        ( clk       ),
    .Cke        ( sdram_cke ),
    .Dq         ( sdram_dq  ),
    .Addr       ( sdram_a   ),
    .Ba         ( sdram_ba  ),
    .Cs_n       ( sdram_ncs ),
    .Ras_n      ( sdram_nras),
    .Cas_n      ( sdram_ncas),
    .We_n       ( sdram_nwe ),
    .Dqm        ( sdram_dqm ),
    .downloading( 1'b0      ),
    .VS         ( 1'b0      ),
    .frame_cnt  ( 0         )
);

initial begin
    clk=0;
    forever #(PERIOD/2) clk=~clk;
end

initial begin
    init_done = 0;
    #104_500 init_done = 1;
end

initial begin
    rst=1;
    #100 rst=0;
    #500_000 $finish;
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end

endmodule