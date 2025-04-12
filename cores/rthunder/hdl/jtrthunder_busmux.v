/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-3-2025 */

module jtrthunder_busmux(
    input   rst, clk,
            cen_main, cen_sub,
            mavma,    savma,
    input   mrom_cs,  srom_cs,  mc30_cs,  ext_cs,
            mscr0_cs, mscr1_cs, moram_cs, mmbank_cs, msbank_cs, mlatch0_cs, mlatch1_cs,
            sscr0_cs, sscr1_cs, soram_cs, smbank_cs, ssbank_cs, slatch0_cs, slatch1_cs,
            mrnw,     srnw,

    output     latch0_cs, latch1_cs, brnw,
    output reg bsel,
    output     [1:0] mbank, sbank,
    output     [1:0] scr0_we, scr1_we, oram_we,

    input  [15:0] maddr,     saddr,
    input   [7:0] mdout,     sdout,     c30_dout,
                  mrom_data, srom_data, ext_data,
    input  [15:0] scr0_dout, scr1_dout, oram_dout,
    output [12:0] baddr,
    output  [7:0] bdout,

    output           ommr_cs,
    output reg       dmaon=0,
    output reg [7:0] mdin, sdin
);

wire [7:0] bdin;
wire       mbank_cs, sbank_cs,
           scr0_cs, scr1_cs, oram_cs, vma;
reg        mvma, svma;

assign vma       = bsel ? svma       : mvma;
assign mbank_cs  = bsel ? smbank_cs  : mmbank_cs;
assign sbank_cs  = bsel ? ssbank_cs  : msbank_cs;
assign scr0_cs   = bsel ? sscr0_cs   : mscr0_cs;
assign scr1_cs   = bsel ? sscr1_cs   : mscr1_cs;
assign oram_cs   = bsel ? soram_cs   : moram_cs;
assign ommr_cs   = oram_cs && baddr>13'h7f4 && baddr<13'h7f8;
assign latch0_cs = bsel ? slatch0_cs : mlatch0_cs;
assign latch1_cs = bsel ? slatch1_cs : mlatch1_cs;

assign bdout     = bsel ? sdout      : mdout;
assign brnw      = bsel ? srnw       : mrnw;
assign baddr     = bsel ? saddr[12:0]: maddr[12:0];

assign scr0_we   = {2{scr0_cs&~brnw}} & { baddr[0], ~baddr[0] };
assign scr1_we   = {2{scr1_cs&~brnw}} & { baddr[0], ~baddr[0] };
assign oram_we   = {2{oram_cs&~brnw}} & { baddr[0], ~baddr[0] };

function [7:0] w2b(input [15:0] w); begin
    w2b = baddr[0] ? w[15:8] : w[7:0];
end endfunction

jtframe_mmr_reg #(.W(2)) u_mbank(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( brnw      ),
    .din        ( bdout[1:0]),
    .cs         ( mbank_cs  ),
    .dout       ( mbank     )
);

jtframe_mmr_reg #(.W(2)) u_sbank(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .wr_n       ( brnw      ),
    .din        ( bdout[1:0]),
    .cs         ( sbank_cs  ),
    .dout       ( sbank     )
);

always @(posedge clk) begin
    dmaon <= !brnw && baddr==13'h1ff2;
end

// assign master = ~bsel;
// assign sub    =  bsel;
assign bdin   = scr0_cs ? w2b(scr0_dout) :
                scr1_cs ? w2b(scr1_dout) :
                oram_cs ? w2b(oram_dout) : 8'd0;

reg [7:0] mother;
reg       mc30_csl;

always @(posedge clk) begin
    mc30_csl <= mc30_cs;
    if( cen_main ) begin bsel <= 1; mvma <= mavma; end
    if( cen_sub  ) begin bsel <= 0; svma <= savma; end
    sdin   <= srom_cs ? srom_data : bdin;
    mother <= ext_cs  ? ext_data  :
              mrom_cs ? mrom_data : bdin;
end

always @* begin
    mdin =  mc30_csl ? c30_dout : mother; // c30_dout comes too late to register mdin
end

endmodule