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
    input              clk96,
    input              clk48,
    input              pxl_cen,
    // S16 video
    input       [ 8:0] hdump,
    input       [ 8:0] vdump,
    input              s16b_hs,
    input              s16b_vs,
    // Main CPU interface
    input       [23:1] addr,
    input       [15:0] din,
    output      [15:0] dout,
    input              rnw,
    input              asn,
    input       [ 1:0] dsn,
    output             dtackn,
    // Video output
    output             video_en,
    output             hs,
    output             vs,
    output             vde,
    output             hde,
    output             spa_b,
    output             ys_n,
    output      [ 7:0] red,
    output      [ 7:0] green,
    output      [ 7:0] blue,
    // Debug
    input       [ 7:0] debug_bus,
    output reg  [ 7:0] st_dout
);
`ifndef NOVDP
wire        ras0, cas0, ras1, cas1, we0, we1, CLK1_o, SPA_B_pull,
            oe1, sc, se0, vs_n, CD_d,
            ym_RD_d, ym_AD_d, vram1_AD_d, vram1_SD_d,
            CSYNC_pull, HSYNC_pull, dtack_pull;
wire [ 7:0] vram_dout, vram1_AD_o, vram1_SD_o,
            RD, AD, SD, ym_RD_o, ym_AD_o;
reg  [ 7:0] AD_mem, SD_mem; // , RD_mem;
wire [15:0] CD;
wire        EDCLK_d, EDCLK_o, BGACK_pull, nc, cen20, nc2, slow,
            cen12x, clk16, clk12, reg_m5, csync, hsync, s16_cs;
reg         rst_n, edclk_l, clk2=0, hsl, clk12xl;
reg  [ 1:0] dtackr;
reg  [ 2:0] cnt8=0, cnt6=0;
reg  [ 7:0] hbcnt=0, hsaux;
reg         clk10=0, clk12x=0, vs_eff, hsn_eff;
reg         rnw_r, asn_r;
reg  [ 1:0] dsn_r;
initial st_dout = 0;

assign vs     = ~vs_n;
assign spa_b  = ~SPA_B_pull;
assign CD     = CD_d ? din : dout;
assign RD     = ym_RD_o;
assign dtackn = !dtackr[0];
assign clk16  = cnt6<3;
assign clk12  = cnt8[2];
assign slow   = hbcnt==8'ha2;//+debug_bus;
assign video_en = reg_m5;
assign s16_cs = hsn_eff ^ vs_eff;
assign csync  = ~CSYNC_pull &  s16_cs;
assign hsync  = ~HSYNC_pull & hsn_eff;

// _d signals: 0 for output, 1 for input
assign AD =
    (~ym_AD_d ? ym_AD_o : 8'h0) |
    (~vram1_AD_d ? vram1_AD_o : 8'h0) |
    ((ym_AD_d & vram1_AD_d) ? AD_mem : 8'h0);
assign SD =
    vram1_SD_d ? SD_mem : vram1_SD_o;

always @(posedge clk48) if(pxl_cen) begin
    if( vdump==9'he8 ) vs_eff  <= 1;
    if( vdump==9'heb ) vs_eff  <= 0;
    if( hdump==9'h76 ) hsn_eff <= 0;
    if( hdump==9'h94 ) hsn_eff <= 1;
    // if( hdump==9'h70+{1'b0,debug_bus} ) hsn_eff <= 0;
    // if( hdump==9'h8e+{1'b0,debug_bus} ) hsn_eff <= 1;
end

always @(posedge clk96) begin
    // RD_mem    <= RD;
    AD_mem    <= AD;
    SD_mem    <= SD;
    edclk_l   <= EDCLK_d ? EDCLK_o : clk12x; // 8/16 MHz input (reverse rule for _d)
    if( cen20  ) clk10  <= ~clk10;
end

// The VDP pixel clock is set in the PCB at
// 12MHz for 56.66us
// 16MHz for 10   us
// Giving an average of ~12.6MHz
always @(posedge clk96) begin
    hsl <= hs;
    clk12xl  <= clk12x;
    cnt6 <= cnt6==5 ? 3'd0 : cnt6+3'd1;
    cnt8 <= cnt8 + 3'd1;
    clk12x <= slow ? clk12 : clk16;
    if( hs && !hsl ) hbcnt <= 0;
    if( !slow && clk12x && !clk12xl ) hbcnt <= hbcnt + 1'd1;
end

always @(posedge clk96) dtackr <= {dtackr[0], dtack_pull};//dtackn <= ~dtack_pull;

always @(posedge clk96) clk2 <= ~clk2;

always @(posedge clk96) begin
    asn_r <= asn;
    dsn_r <= dsn;
    rnw_r <= rnw;
end

always @(negedge clk96) rst_n <= ~rst;
/* verilator lint_off PINMISSING */
/* verilator tracing_off */
ym7101 u_vdp(
    .RESET      ( rst_n     ),
    .MCLK       ( clk96     ),
    .MCLK_e     ( clk2      ),
    .EDCLK_i    ( edclk_l   ),
    .EDCLK_o    ( EDCLK_o   ),
    .EDCLK_d    ( EDCLK_d   ),
    .reg_m5     ( reg_m5    ), // high when the VDP accepts the external pixel clock
    // M68000
    .CA_i       ( addr      ),
    .CA_o       (           ),
    .CA_d       (           ),
    .CD_i       ( CD        ),
    .CD_o       ( dout      ),
    .CD_d       ( CD_d      ),
    .RW         ( rnw_r     ),
    .LDS        ( dsn_r[0]  ),
    .UDS        ( dsn_r[1]  ),
    .AS         ( asn_r     ),
    .IPL1_pull  (           ),
    .IPL2_pull  (           ),
    .DTACK_i    ( dtackr[1] ),
    .DTACK_pull ( dtack_pull),
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
    .RAS0       ( ras0      ),
    .CAS0       ( cas0      ),
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
    .PAL        ( 1'b0      ),
    .ext_test_2 ( 1'b0      ),
    .CLK1_o     ( CLK1_o    ),
    .CLK1_i     ( clk10     ),
    .BGACK_i    (~BGACK_pull),
    .BGACK_pull ( BGACK_pull),
    .INTAK      ( 1'b0      ),
    .SPA_B_i    (spa_b      ),
    .SPA_B_pull (SPA_B_pull ),
    .vdp_cramdot_dis( 1'b0  ),
    // other unconnected pins
    .RA         (           ),
    .RD_d       ( ym_RD_d   ),
    .RD_o       ( ym_RD_o   ),
    .RD_i       ( RD        ),
    // video and sound outputs
    .HSYNC_i    ( hsync     ),
    .HSYNC_pull ( HSYNC_pull),
    .CSYNC_i    ( csync     ),
    .CSYNC_pull ( CSYNC_pull),
    .VSYNC      (           ), // used as pixel clock output via test register setting
    .SOUND      (           ),
    .YS         ( ys_n      ), // /blank
    .DAC_R      ( red       ),
    .DAC_G      ( green     ),
    .DAC_B      ( blue      ),
    .vdp_hsync2 ( hs        ), // hsync without 'fast' lines in vblank
    .vdp_vsync2 ( vs_n      ), // vsync regardless of test bit
    .vdp_de_h   ( hde       ),
    .vdp_de_v   ( vde       )
);

vram u_vram(
    .MCLK       ( clk96     ),
    .RAS        ( ras1      ),
    .CAS        ( cas1      ),
    .WE         ( we0       ),
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

jtframe_frac_cen #(.WC(5)) u_cen20(
    .clk    ( clk96     ),
    .n      ( 5'd5      ),
    .m      ( 5'd24     ),
    .cen    ( {nc,cen20}),
    .cenb   (           )
);

`else
reg [15:0] mem;
reg [ 7:0] mmr[0:31];
reg [31:0] ptr;
reg        csl;
wire       cs;
integer    cnt;

assign hs=0, vs=0;
assign red=0, green=0, blue=0;
assign cs=(addr>>4 == 23'h60_000) && !asn;
assign dout=mem|{{8{dsn[1]}},{8{dsn[0]}}};
assign dtackn=0, vde=0, hde=0, spa_b=0, video_en=0, ys_n=0;

always @(posedge clk48) st_dout <= debug_bus[0] ? mem[0+:8] : mem[8+:8];

always @(posedge clk48, posedge rst) begin
    if( rst ) begin
        mem <= 0;
        cnt <= 0;
        csl <= 0;
    end else begin
        csl <= cs;
        if(cs) begin
            if( !rnw ) begin
                case( addr[3:1] )
                    3'd0: begin
                        if(!dsn[0]) mem[0+:8]<=din[0+:8];
                        if(!dsn[1]) mem[8+:8]<=din[8+:8];
                        if( cs && !csl ) begin
                            $display("%X <- %X",ptr,din);
                            cnt <= cnt+1;
                        end
                    end
                    3'd2: if( din[15:13]==3'b100) begin
                        mmr[din[12:8]]<=din[7:0];
                    end else begin
                        ptr[16+:16] <= din;
                        cnt <= 0;
                    end
                    3'd3: ptr[ 0+:16] <= din;
                    default:;
                endcase
            end else begin
                case( addr[3:1] )
                    3'd0: if( cs && !csl ) begin
                        cnt <= cnt+1;
                        $display("%X -> %X",ptr,mem);
                    end
                    default:;
                endcase
            end
        end
    end
end

`endif
endmodule
