/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 6-12-2019 */

///////////////////////////////////////////////////////////////////////////
// Fractional clock enable signal
// W refers to the number of divided down cen signals available
// each one is divided by 2

/* verilator tracing_off */

module jtframe_frac_cen #(parameter W=2,WC=10)(
    input         rst,
    input         clk,
    input   [WC-1:0] n,         // numerator
    input   [WC-1:0] m,         // denominator
    output     [W-1:0] cen,
    output     [W-1:0] cenb // 180 shifted
);

wire [WC:0] step={1'b0,n},
            lim ={1'b0,m},
            absmax = lim+step;

reg  [WC:0] cencnt=0,
            next, next2;

always @(*) begin
    next  = cencnt+step;
    next2 = next-lim;
end

reg  [W-1:0] cen_r=0, cenb_r=0;
reg  half    = 0;
reg  rst_r   = 0;
reg  rst_l   = 0;
wire restart = rst_l & ~rst_r;
wire over    = next>=lim;
wire halfway = next >= (lim>>1)  && !half;

assign cen  = cen_r  & ~{W{restart}};
assign cenb = cenb_r & ~{W{restart}};

reg  [W-1:0] edgecnt = 0;
wire [W-1:0] next_edgecnt = edgecnt + 1'd1;
wire [W-1:0] toggle = next_edgecnt & ~edgecnt;

reg  [W-1:0] edgecnt_b = 0;
wire [W-1:0] next_edgecnt_b = edgecnt_b + 1'd1;
wire [W-1:0] toggle_b = next_edgecnt_b & ~edgecnt_b;

`ifdef SIMULATION
initial begin
    if( n>(m>>1) ) $display("WARNING: %m will generate cen signals high for 2 cycles in a row");
end
`endif

always @(posedge clk) begin
    cen_r  <= 0;
    cenb_r <= 0;

    if( cencnt >= absmax ) begin
        // something went wrong: restart
        cencnt <= 0;
    end else
    if( halfway ) begin
        half <= 1'b1;
        edgecnt_b <= next_edgecnt_b;
        cenb_r <= { toggle_b[W-2:0], 1'b1 };
    end
    if( over ) begin
        cencnt <= next2;
        half <= 1'b0;
        edgecnt <= next_edgecnt;
        cen_r <= { toggle[W-2:0], 1'b1 };
    end else begin
        cencnt <= next;
    end
    rst_r <= rst;
    rst_l <= rst_r;
    if( restart ) begin
        cencnt    <= 0;
        half      <= 0;
        edgecnt   <= 0;
        edgecnt_b <= 0;
        cen_r     <= 0;
        cenb_r    <= 0;
    end
end


endmodule