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
    // Main CPU interface
    input       [23:1] addr,
    input       [15:0] din,
    output      [15:0] dout,
    input              rnw,
    input              asn,
    input       [ 1:0] dsn,
    output             dtackn,
    // Video output
    output             hs,
    output             vs,
    output             vde,
    output             hde,
    output      [ 7:0] red,
    output      [ 7:0] green,
    output      [ 7:0] blue,
    // Debug
    input       [ 7:0] debug_bus,
    output reg  [ 7:0] st_dout
);
`ifndef NOVDP
wire        ras0, cas0, ras1, cas1, we0, we1, CLK1_o, SPA_B_pull, SPA_B,
            oe1, sc, se0, vs_n, CD_d,
            ym_RD_d, ym_AD_d, vram1_AD_d, vram1_SD_d,
            CSYNC_pull, HSYNC_pull, dtack_pull;
wire [ 7:0] vram_dout, vram1_AD_o, vram1_SD_o,
            RD, AD, SD, ym_RD_o, ym_AD_o;
reg  [ 7:0] AD_mem, SD_mem; // , RD_mem;
wire [15:0] CD;
wire        EDCLK_d, EDCLK_o, BGACK_pull;
reg         rst_n, edclk_l, clk2=0;
reg  [ 2:0] edclk_cnt;
reg  [ 1:0] dtackr;

assign vs     = ~vs_n;
assign SPA_B  = ~SPA_B_pull;
assign CD     = CD_d ? din : dout;
assign RD     = ym_RD_o;
assign dtackn = !dtackr[0];

// _d signals: 0 for output, 1 for input
assign AD =
    (~ym_AD_d ? ym_AD_o : 8'h0) |
    (~vram1_AD_d ? vram1_AD_o : 8'h0) |
    ((ym_AD_d & vram1_AD_d) ? AD_mem : 8'h0);
assign SD =
    vram1_SD_d ? SD_mem : vram1_SD_o;

always @(posedge clk96) begin
    // RD_mem    <= RD;
    AD_mem    <= AD;
    SD_mem    <= SD;
    edclk_cnt <= edclk_cnt + 1'd1;
    edclk_l   <= EDCLK_d ? EDCLK_o : edclk_cnt[2]; // 12 MHz input (reverse rule for _d)
end

always @(posedge clk96) dtackr <= {dtackr[0], dtack_pull};//dtackn <= ~dtack_pull;

always @(posedge clk96) clk2 <= ~clk2;

always @(negedge clk96) rst_n <= ~rst;
/* verilator lint_off PINMISSING */
/* xxxverilator tracing_on */
ym7101 u_vdp(
    .RESET      ( rst_n     ),
    .MCLK       ( clk96     ),
    .MCLK_e     ( clk2      ),
    .EDCLK_i    ( edclk_l   ),
    .EDCLK_o    ( EDCLK_o   ),
    .EDCLK_d    ( EDCLK_d   ),
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
    .CLK1_i     ( CLK1_o    ),
    .BGACK_i    (~BGACK_pull),
    .BGACK_pull ( BGACK_pull),
    .INTAK      ( 1'b0      ),
    .SPA_B_i    (SPA_B      ),
    .SPA_B_pull (SPA_B_pull ),
    .vdp_cramdot_dis( 1'b0  ),
    // other unconnected pins
    .RA         (           ),
    .RD_d       ( ym_RD_d   ),
    .RD_o       ( ym_RD_o   ),
    .RD_i       ( RD        ),
    // video and sound outputs
    .HSYNC_i    (~HSYNC_pull),
    .HSYNC_pull ( HSYNC_pull),
    .CSYNC_i    (~CSYNC_pull),
    .CSYNC_pull ( CSYNC_pull),
    .VSYNC      (           ), // used as pixel clock output via test register setting
    .SOUND      (           ),
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
assign dtackn=0, vde=0, hde=0;

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
