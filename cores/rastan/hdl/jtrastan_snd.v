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
    Date: 3-4-2022 */

module jtrastan_snd(
    input                rst,
    input                clk, // 24 MHz

    // From main CPU
    input                rst48,
    input                clk48,
    input                main_addr,
    input         [ 3:0] main_dout,
    output        [ 3:0] main_din,
    input                main_rnw,
    input                sn_rd,
    input                sn_we,

    output        [15:0] rom_addr,
    output reg           rom_cs,
    input                rom_ok,
    input         [ 7:0] rom_data,

    output reg    [15:0] pcm_addr,
    output reg           pcm_cs,
    input                pcm_ok,
    input         [ 7:0] pcm_data,

    output signed [15:0] fm_l, fm_r,
    output signed [11:0] pcm
);

wire               cen4, cen2, pcm_cen, nc;
wire signed [15:0] pre_snd, left_opm, right_opm;
wire signed [11:0] pcm_snd;
wire               int_n;
wire        [15:0] A;
wire        [ 7:0] dout, opm_dout, ram_dout;
wire        [ 3:0] pc6_dout;
reg                opm_cs, opl_cs, ram_cs, pc6_cs;
reg                pcm_rst, pcm_stop, pcm_start, pcm_addr_cs;
wire               rd_n, wr_n, mreq_n, nmi_n;
wire               ct1, ct2, vclk, pc6_rst;
reg                nibble_sel, vclk_l, snd_rstn;
reg         [15:0] pcm_cnt;
wire        [ 3:0] pcm_nibble;
reg         [ 7:0] din;
wire               main_cs;

assign main_cs    = sn_rd | sn_we;
assign rom_addr   = A[14] ? { ct2, ct1, A[13:0]  } : A;
assign pcm_nibble = !nibble_sel ? pcm_data[7:4] : pcm_data[3:0];

always @(posedge clk) begin
    snd_rstn <= ~(rst | pc6_rst);
end

// PCM controller
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pcm_addr   <= 0;
        pcm_cs     <= 0;
        nibble_sel <= 0;
        pcm_rst    <= 1;
    end else begin
        vclk_l <= vclk;
        if( pcm_addr_cs ) pcm_addr[15:8] <= dout;
        if( pcm_start ) begin
            pcm_cs         <= 1;
            pcm_rst        <= 0;
            pcm_addr[ 7:0] <= 0;
            nibble_sel     <= 0;
        end
        if( pcm_stop    ) begin
            pcm_cs         <= 0;
            pcm_rst        <= 1;
        end
        if( vclk && ! vclk_l && !pcm_rst)
            { pcm_addr, nibble_sel } <= { pcm_addr, nibble_sel } + 1'd1;
    end
end

always @* begin
    rom_cs      = !A[15] && !rd_n;
    ram_cs      = 0;
    opm_cs      = 0;
    pc6_cs      = 0;
    pcm_addr_cs = 0;
    pcm_start   = 0;
    pcm_stop    = 0;
    if( !mreq_n && A[15]) begin
        case( A[14:12] )
            0: ram_cs = 1;
            1: opm_cs = 1;
            2: pc6_cs = 1;
            3: pcm_addr_cs = 1;
            4: pcm_start = 1;
            5: pcm_stop  = 1;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    din <=  rom_cs ? rom_data :
            ram_cs ? ram_dout :
            opm_cs ? opm_dout :
            pc6_cs ? { 4'hf, pc6_dout } :
            8'hff;
end

jtframe_frac_cen #(.WC(11)) u_cpucen(
    .clk  ( clk          ),
    .n    ( 11'd231      ),
    .m    ( 11'd1541     ),
    .cen  ( {cen2,cen4 } ),
    .cenb (              )
);

jtframe_frac_cen #(.WC(8)) u_pcmcen(
    .clk  ( clk          ), // clk = 24 *6.667/6.0 = 26.668 MHz
    .n    ( 8'd2         ), // 2/139*26.668 MHz = 384 kHz
    .m    ( 8'd139       ),
    .cen  ({nc,pcm_cen } ),
    .cenb (              )
);

jtrastan_pc060 u_pc060(
    .rst48      ( rst48     ),
    .clk48      ( clk48     ),
    .main_dout  ( main_dout ),
    .main_din   ( main_din  ),
    .main_addr  ( main_addr ),
    .main_rnw   ( main_rnw  ),
    .main_cs    ( main_cs   ),

    .rst24      ( rst       ),
    .clk24      ( clk       ),
    .snd_dout   ( dout[3:0] ),
    .snd_din    ( pc6_dout  ),
    .snd_addr   ( A[0]      ),
    .snd_rnw    ( wr_n      ),
    .snd_cs     ( pc6_cs    ),
    .snd_nmin   ( nmi_n     ),
    .snd_rst    ( pc6_rst   )
);

jtframe_sysz80 #(.RECOVERY(0)) u_cpu(
    .rst_n      ( snd_rstn  ),
    .clk        ( clk       ),
    .cen        ( cen4      ),
    .cpu_cen    (           ),
    .int_n      ( int_n     ),
    .nmi_n      ( nmi_n     ),
    .busrq_n    ( 1'b1      ),
    .m1_n       (           ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     (           ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     (           ),
    .halt_n     (           ),
    .busak_n    (           ),
    .A          ( A         ),
    .cpu_din    ( din       ),
    .cpu_dout   ( dout      ),
    .ram_dout   ( ram_dout  ),
    // ROM access
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
);
/*
jtopl u_opl(
    .rst    ( rst       ),        // rst should be at least 6 clk&cen cycles long
    .clk    ( clk       ),        // CPU clock
    .cen    ( cen       ),        // optional clock enable, it not needed leave as 1'b1
    .din    ( din       ),
    .addr   ( A[0]      ),
    .cs_n   ( cs_n      ),
    .wr_n   ( wr_n      ),
    .dout   ( opl_dout  ),
    .irq_n  ( irqn_opl  ),
    // combined output
    .snd    ( snd_opl   ),
    .sample ( spl_opl   )
);
*/
jt51 u_jt51(
    .rst    ( ~snd_rstn ),
    .clk    ( clk       ),
    .cen    ( cen4      ),
    .cen_p1 ( cen2      ),
    .cs_n   ( ~opm_cs   ),
    .wr_n   ( wr_n      ),
    .a0     ( A[0]       ),
    .din    ( dout      ),
    .dout   ( opm_dout  ),
    // peripheral control
    .ct1    ( ct1       ),
    .ct2    ( ct2       ),
    .irq_n  ( int_n     ),
    // Low resolution output (same as real chip)
    .sample (           ),
    .left   (           ),
    .right  (           ),
    // Full resolution output
    .xleft  ( fm_l      ),
    .xright ( fm_r      )
);

jt5205 u_5205( // 8kHz, 4 bits/sample
    .rst    ( pcm_rst   ),
    .clk    ( clk       ),
    .cen    ( pcm_cen   ),
    .sel    ( 2'b10     ),
    .din    ( pcm_nibble),
    .sound  ( pcm       ),
    .sample (           ),
    .irq    (           ),
    .vclk_o ( vclk      )
);

endmodule
