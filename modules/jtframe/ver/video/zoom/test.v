module test;

localparam
    ZW       =  12,    // zoom step width
    ZI       =  6, // integer part of the zoom, use for enlarging. ZI=ZW-1=no enlarging
    ZENLARGE =  1;    // enable zoom enlarging

reg [3:0] clks;
wire clk, clk8;

assign clk  = clks[0];
assign clk8 = clks==1;

wire [11:0] hzoom='h1b;

unit_counter  #(ZW,ZI,ZENLARGE) unit (clk,  hzoom);
eight_counter #(ZW,ZI,ZENLARGE) eight(clk8, hzoom);

initial begin
    clks=0;
    forever #10 clks=clks+1;
end

integer timeout=0;

always @(posedge clk) begin
    timeout <= timeout+1;
    if(timeout==512) $finish;
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

endmodule

module eight_counter #(parameter
    ZW       =  12,    // zoom step width
    ZI       =  ZW-1, // integer part of the zoom, use for enlarging. ZI=ZW-1=no enlarging
    ZENLARGE =  1     // enable zoom enlarging
)(
    input   clk,
    input  [ZW-1:0]  hzoom
);

localparam [ZW-1:0] HZONE = { {ZW-1{1'b0}},1'b1} << ZI;

reg    [ZW-1:0] hz_cnt=0, nx_hz;
wire  [ZW-1:ZI] hzint;
reg             cen=0, moveon, readon;
integer rd_addr=0,wr_addr=0;

assign hzint    = hz_cnt[ZW-1:ZI];

reg [ZW-1:ZI] step;

always @* begin
    step = hzint;
    if(step>8) step=8;
end

always @* begin
    if( ZENLARGE==1 ) begin
        readon = hzint >= 1; // tile pixels read (reduce)
        moveon = hzint <= 1; // buffer moves (enlarge)
        nx_hz = readon ? (hz_cnt - HZONE)*hzint : hz_cnt;
        if( moveon  ) nx_hz = nx_hz + hzoom*8;
    // end else begin
    //     readon = 1;
    //     { moveon, nx_hz } = {1'b1, hz_cnt}-{1'b0,hzoom};
    end
end

always @(posedge clk) begin
    hz_cnt   <= nx_hz;
    if( readon ) begin
        rd_addr <= rd_addr+step;
    end
    if( moveon ) wr_addr <= wr_addr+1'd1;
end

endmodule

/////////////////////////////////////////////////////
module unit_counter #(parameter
    ZW       =  12,    // zoom step width
    ZI       =  ZW-1, // integer part of the zoom, use for enlarging. ZI=ZW-1=no enlarging
    ZENLARGE =  1     // enable zoom enlarging
)(
    input   clk,
    input  [ZW-1:0]  hzoom
);

localparam [ZW-1:0] HZONE = { {ZW-1{1'b0}},1'b1} << ZI;

reg    [ZW-1:0] hz_cnt=0, nx_hz;
wire  [ZW-1:ZI] hzint;
reg             cen=0, moveon, readon;
integer rd_addr=0,wr_addr=0;

assign hzint    = hz_cnt[ZW-1:ZI];

always @* begin
    if( ZENLARGE==1 ) begin
        readon = hzint >= 1; // tile pixels read (reduce)
        moveon = hzint <= 1; // buffer moves (enlarge)
        nx_hz = readon ? hz_cnt - HZONE : hz_cnt;
        if( moveon  ) nx_hz = nx_hz + hzoom;
    end else begin
        readon = 1;
        { moveon, nx_hz } = {1'b1, hz_cnt}-{1'b0,hzoom};
    end
end

always @(posedge clk) begin
    hz_cnt   <= nx_hz;
    if( readon ) begin
        rd_addr      <= rd_addr+1'd1;
    end
    if( moveon ) wr_addr <= wr_addr+1'd1;
end
endmodule