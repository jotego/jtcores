module test;

`include "test_tasks.vh"

reg signed [15:0] xoff=0;
reg  [15:0] ax=0;
reg  [ 9:0] mant=0, xlog, exp;
wire [ 8:0] xfrac;
wire [14:0] lin;
wire [ 4:0] k;
wire        cen, clk;
wire signed [15:0] err, lins;

function [15:0] abs(input [15:0] x); begin
    abs = x[15] ? -x : x;
    if(abs[15]) abs=16'h7fff;
end endfunction

assign err  = abs(lins-xoff);
assign lins = xoff[15] ? -{1'b0,lin} : {1'b0,lin};


always @(*) begin
    ax   = xoff[15] ? -xoff : xoff;
    if(ax[15]) ax=16'h7fff;
    mant = ax[14] ? ax[14-:10]:
           ax[13] ? ax[13-:10]:
           ax[12] ? ax[12-:10]:
           ax[11] ? ax[11-:10]:
           ax[10] ? ax[10-:10]:
                    ax[ 9-:10];
    exp  = ax[14] ? 10'd256 :
           ax[13] ? 10'd204 :
           ax[12] ? 10'd153 :
           ax[11] ? 10'd102 :
           ax[10] ? 10'd051 : 10'd0;
end

reg waive = 1;
reg cen2=0;

always @(posedge clk) if(cen) begin
    cen2 <= ~cen2;
    xlog <= {1'b0,xfrac} + exp;
    if(cen2) begin
        xoff <= xoff+16'd1;
        waive <= 0;
        if (err > 16'd16 && err > (ax>>4) && !waive) begin
            $display("mismatched results");
            fail();
        end
        if(xoff==-1) begin
            pass();
        end
    end
end

jtframe_dual_ram #(
    .DW        ( 9                  ),
    .SYNFILE   ("../../hdl/log2.hex")
)u_log(
    .clk0       ( clk               ),
    .clk1       ( clk               ),
    // Port 0
    .data0      ( 9'h0              ),
    .addr0      ( mant              ),
    .we0        ( 1'b0              ),
    .q0         ( xfrac             ),
    // Port 1
    .data1      ( 9'h0              ),
    .addr1      ( 10'b0             ),
    .we1        ( 1'b0              ),
    .q1         (                   )
);

jtframe_dual_ram #(
    .DW        ( 15                 ),
    .AW        ( 10                 ),
    .SYNFILE   ("../../hdl/exp2.hex")
)u_exp(
    .clk0       ( clk               ),
    .clk1       ( clk               ),
    // Port 0
    .data0      ( 15'h0             ),
    .addr0      ( xlog[9:0]         ),
    .we0        ( 1'b0              ),
    .q0         ( lin               ),
    // Port 1
    .data1      ( 15'h0             ),
    .addr1      ( 10'b0             ),
    .we1        ( 1'b0              ),
    .q1         (                   )
);

jtframe_test_clocks clocks(
    .rst        (               ),
    .clk        ( clk           ),
    .pxl_cen    ( cen           ),
    .lhbl       (               ),
    .lvbl       (               ),
    .v          (               ),  // for faster simulation
    .framecnt   (               )
);

endmodule
