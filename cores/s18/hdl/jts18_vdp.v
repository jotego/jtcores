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
    Date: 29-4-2024 */

module jts18_vdp(
    input              rst,
    input              clk,
    output             ed_clk,

    // Main CPU interface
    input       [23:1] addr,
    input       [15:0] din,
    output      [15:0] dout,
    input              rnw,
    input              asn,
    input       [ 1:0] dsn,
    output reg         dtackn,
    // Video output
    output             hs,
    output             vs,
    output      [ 7:0] red,
    output      [ 7:0] green,
    output      [ 7:0] blue
);

wire        ras1, cas1, we0, we1, CLK1_o, SPA_B_pull, SPA_B,
            oe1, sc, se0, dtack, vs_n, CD_d,
            ym_RD_d, ym_AD_d, vram1_AD_d, vram1_SD_d;
wire [ 7:0] vram_dout, vram1_AD_o, vram1_SD_o,
            RD, AD, SD, ym_RD_o, ym_AD_o;
reg  [ 7:0] RD_mem, AD_mem, SD_mem;
wire [15:0] CD;
reg         rst_n;

// assign dtackn = ~dtack;
assign vs     = ~vs_n;
assign SPA_B  = ~SPA_B_pull;
assign CD     = CD_d ? din : dout;
assign RD =
    (~ym_RD_d ? ym_RD_o : 8'h0);// |
    // (~vram2_RD_d ? vram2_RD_o : 8'h0) |
    // ((ym_RD_d & vram2_RD_d) ? RD_mem : 8'h0);
assign AD =
    (~ym_AD_d ? ym_AD_o : 8'h0) |
    (~vram1_AD_d ? vram1_AD_o : 8'h0) |
    ((ym_AD_d & vram1_AD_d) ? AD_mem : 8'h0);
assign SD =
    vram1_SD_d ? SD_mem : vram1_SD_o;

always @(posedge clk) begin
    RD_mem <= RD;
    AD_mem <= AD;
    SD_mem <= SD;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dtackn <= 0;
    end else begin
        if( asn ) begin
            dtackn <= 1;
        end else begin
            if( dtack ) dtackn <= 0;
        end
    end
end
reg clk2=0;
always @(posedge clk) clk2 <= ~clk2;

always @(negedge clk) rst_n <= ~rst;
/* verilator lint_off PINMISSING */
ym7101 u_vdp(
    .RESET      ( rst_n     ),
    .MCLK       ( clk       ),
    .MCLK_e     ( clk2      ),
    .EDCLK_i    ( ed_clk    ),
    .EDCLK_o    ( ed_clk    ),
    .EDCLK_d    (           ),
    // M68000
    .CA_i       ( addr      ),
    .CA_o       (           ),
    .CA_d       (           ),
    .CD_i       ( CD        ),
    .CD_o       ( dout      ),
    .CD_d       ( CD_d      ),
    .RW         ( rnw       ),
    .LDS        ( dsn[0]    ),
    .UDS        ( dsn[1]    ),
    .AS         ( asn       ),
    .IPL1_pull  (           ),
    .IPL2_pull  (           ),
    .DTACK_i    ( dtackn    ),
    .DTACK_pull ( dtack     ),
    // Z80 interface is disabled
    .BR_pull    (           ),
    .INT_pull   (           ),
    .MREQ       ( 1'b1      ),
    .BG         ( 1'b1      ),
    .IORQ       ( 1'b1      ),
    .M1         ( 1'b1      ),
    .RD         ( 1'b1      ),
    .WR         ( 1'b1      ),
    // VRAM
    .AD_o       ( ym_AD_o   ),
    .AD_i       ( AD        ),
    .AD_d       ( ym_AD_d   ),
    .SD         ( SD        ),
    .SE1        (           ),
    .RAS1       ( ras1      ),
    .CAS1       ( cas1      ),
    .WE0        ( we0       ),      // shouldn't it be we1?
    .WE1        ( we1       ),
    .OE1        ( oe1       ),
    .SE0        ( se0       ),
    .SC         ( sc        ),
    // configuration
    .SEL0       ( 1'b1      ),      // always use M68k
    .HL         ( 1'b1      ),
    .PAL        ( 1'b1      ),
    .ext_test_2 ( 1'b0      ),
    .CLK1_o     ( CLK1_o    ),
    .CLK1_i     ( CLK1_o    ),
    .BGACK_i    ( 1'b1      ),
    .INTAK      ( 1'b1      ),
    .SPA_B_i    (SPA_B      ),
    .SPA_B_pull (SPA_B_pull ),
    .vdp_cramdot_dis( 1'b0  ),
    // other unconnected pins
    .RA         (           ),
    .RD_d       ( ym_RD_d   ),
    .RD_o       ( ym_RD_o   ),
    .RD_i       ( RD        ),
    // video and sound outputs
    .HSYNC_i    ( 1'b1      ),
    .HSYNC_pull ( hs        ),
    .CSYNC_i    ( 1'b1      ),
    .CSYNC_pull (           ),
    .VSYNC      ( vs_n      ),
    .SOUND      (           ),
    .DAC_R      ( red       ),
    .DAC_G      ( green     ),
    .DAC_B      ( blue      )
);

vram u_vram(
    .MCLK       ( clk     ),
    .RAS        ( ras1      ),
    .CAS        ( cas1      ),
    .WE         ( we1       ),
    .OE         ( oe1       ),
    .SC         ( sc        ),
    .SE         ( se0       ),
    .AD         ( AD        ),
    .RD_i       ( AD        ),
    .RD_o       ( vram1_AD_o),
    .RD_d       ( vram1_AD_d),
    .SD_o       ( vram1_SD_o),
    .SD_d       ( vram1_SD_d)
);
/* verilator lint_on PINMISSING */
endmodule
