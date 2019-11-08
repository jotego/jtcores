/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

module jttora_sound(
    input           rst,
    input           clk,
    input           cen3,    //  3   MHz
    input           cenfm,   //  3.57   MHz
    input           cenp384, //  384 kHz
    input           jap,
    // Interface with main CPU
    input           sres_b, // Z80 reset
    input   [7:0]   snd_latch,
    // Sound control
    input           enable_psg,
    input           enable_fm,
    input   [7:0]   psg_gain,
    // ROM
    output  [14:0]  rom_addr,
    output          rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM
    output  [14:0]  rom2_addr,
    output          rom2_cs,
    input   [ 7:0]  rom2_data,
    input           rom2_ok,    

    // Sound output
    output  reg signed [15:0] ym_snd,
    output  sample
);

wire signed [15:0] fm_snd;
wire signed [11:0] adpcm;
wire               cen_cpu3  = jap & cen3;
wire               cen_adpcm = jap & cenp384;

always @(posedge clk) begin
    ym_snd <= jap ?
    fm_snd + { {2{adpcm[11]}}, adpcm, 2'd0 }:
    fm_snd;
end

wire [ 7:0] cmd;

jtgng_sound #(.LAYOUT(3)) u_fmcpu (
    .rst        (  rst          ),
    .clk        (  clk          ),
    .cen3       (  cenfm        ),
    .cen1p5     (  1'b0         ), // unused
    .sres_b     (  sres_b       ),
    .snd_latch  (  snd_latch    ),
    .snd2_latch (  cmd          ),
    .snd_int    (  1'b0         ), // unused
    .enable_psg (  enable_psg   ),
    .enable_fm  (  enable_fm    ),
    .psg_gain   (  psg_gain     ),
    .rom_addr   (  rom_addr     ),
    .rom_cs     (  rom_cs       ),
    .rom_data   (  rom_data     ),
    .rom_ok     (  rom_ok       ),
    .ym_snd     (  fm_snd       ),
    .sample     (  sample       )
);

// ADPCM CPU
reg  wait_n, last_rom2_cs, int_n;
wire wr_n, rd_n, iorq_n, rfsh_n, mreq_n, m1_n;
assign rom2_cs = !mreq_n && rfsh_n;
wire [15:0] A;
reg  [ 7:0] din;
wire [ 7:0] dout;

assign rom2_addr = A[14:0];

always @(posedge clk or posedge rst) begin
    if( rst )
        wait_n <= 1'b1;
    else begin
        last_rom2_cs <= rom2_cs;
        if( rom2_cs && !last_rom2_cs ) wait_n <= 1'b0;
        if( rom2_ok ) wait_n <= 1'b1;
    end
end

always @(*) begin
    din = !iorq_n ? cmd : rom_data;
end

reg [3:0] pcm_data;

always @(posedge clk)
    if( !iorq_n && A[0] && !wr_n ) pcm_data <= dout[3:0];

wire irq_st;

jt5205 u_adpcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_adpcm ),
    .sel        ( 2'b0      ),
    .din        ( pcm_data  ),
    .sound      ( adpcm     ),
    .irq        ( irq_st    )
);

reg last_irq_st;

always @(posedge clk, posedge rst) begin
    if(rst) begin
        int_n <= 1'b1;
    end else begin
        last_irq_st <= irq_st;
        if( !last_irq_st && irq_st )
            int_n <= 1'b0;
        if( !iorq_n && !m1_n )
            int_n <= 1'b1;
    end
end

jtframe_z80 u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( cen_cpu3    ),
    .wait_n     ( wait_n      ),
    .int_n      ( int_n       ),
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .din        ( din         ),
    .dout       ( dout        )
);


endmodule // jtgng_sound