/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 5-7-2021 */

module jtoutrun_snd(
    input                rst,
    input                clk,
    input                snd_rstb,

    input                cen_fm,    // 4MHz
    input                cen_fm2,   // 2MHz
    input                cen_pcm,   // 8MHz
    input         [ 1:0] game_id,

    // options
    input         [ 1:0] fxlevel,
    input                enable_fm,
    input                enable_psg,
    input                mute,

    // Mapper device 315-5195
    output               mapper_rd,
    output               mapper_wr,
    output [7:0]         mapper_din,
    input  [7:0]         mapper_dout,
    input                mapper_pbf, // pbf signal == buffer full ?

    input         [ 7:0] debug_bus,
    output        [ 7:0] st_dout,
    // ROM
    output        [15:0] rom_addr,
    output    reg        rom_cs,
    input         [ 7:0] rom_data,
    input                rom_ok,

    output        [18:0] pcm_addr,
    input         [ 7:0] pcm_data,
    input                pcm_ok,
    output               pcm_cs,

    // Sound output
    output signed [15:0] snd_left,
    output signed [15:0] snd_right,
    output               sample,
    output reg           peak
);

localparam [7:0] FMGAIN=8'h08;

wire [15:0] A;
reg         fm_cs, mapper_cs, ram_cs, pcm_ce;
wire        mreq_n, iorq_n, int_n;
reg  [ 7:0] cpu_din, pcmgain, fmgain;
wire [ 7:0] cpu_dout, fm_dout, ram_dout, pcm_dout;
wire        nmi_n, wr_n, rd_n, m1_n;
reg  [ 5:0] rom_msb;
wire        peak_left, peak_right;
wire        mix_rst, pcm_sample;
wire [18:0] pcm_pre;

wire signed [15:0] fm_left, fm_right, mixed, pcm_left, pcm_right;

assign rom_addr   = A;
assign mapper_rd  = mapper_cs && !rd_n;
assign mapper_wr  = mapper_cs && !wr_n;
assign mapper_din = cpu_dout;
assign nmi_n      = ~mapper_pbf;
assign mix_rst    = rst | ~snd_rstb;
assign pcm_addr   =
    game_id != 2 ? // Games other than Turbo Out Run use 32kB ROMs
    { pcm_pre[18:16], 1'b0, pcm_pre[14:0] } : pcm_pre;

always @(*) begin
    ram_cs = !mreq_n && &A[15:11]; // 0xf8~
    rom_cs = !mreq_n &&  A[15:12]!=4'hf;
    pcm_ce = !mreq_n &&  A[15:11]==5'b11110;

    // Port Map
    fm_cs     = !iorq_n && m1_n && A[7:6]==0;
    mapper_cs = !iorq_n && m1_n && A[7:6]==1;
end

always @(posedge clk) begin
    peak     <= peak_left | peak_right;
    cpu_din  <= rom_cs    ? rom_data :
                ram_cs    ? ram_dout :
                fm_cs     ? fm_dout  :
                pcm_ce    ? pcm_dout :
                mapper_cs ? mapper_dout :
                    8'hff;
end

// Volume control
always @(posedge clk ) begin
    fmgain <= enable_fm ? FMGAIN : 8'h0;
    case( fxlevel )
        2'd0: pcmgain <= 8'h04;
        2'd1: pcmgain <= 8'h08;
        2'd2: pcmgain <= 8'h0C;
        2'd3: pcmgain <= 8'h10;
    endcase

    if( !enable_psg ) pcmgain <= 0;
    if( mute ) begin
        pcmgain <= 0;
        fmgain  <= 0;
    end
end

jtframe_mixer u_mixer_left(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    // input signals
    .ch0    ( pcm_left  ),
    .ch1    ( fm_left   ),
    .ch2    ( 16'd0     ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( pcmgain   ),
    .gain1  ( fmgain    ),
    .gain2  ( 8'h00     ),
    .gain3  ( 8'h00     ),
    .mixed  ( snd_left  ),
    .peak   ( peak_left )
);

jtframe_mixer u_mixer_right(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    // input signals
    .ch0    ( pcm_right ),
    .ch1    ( fm_right  ),
    .ch2    ( 16'd0     ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( pcmgain   ),
    .gain1  ( fmgain    ),
    .gain2  ( 8'h00     ),
    .gain3  ( 8'h00     ),
    .mixed  ( snd_right ),
    .peak   ( peak_right)
);

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n      ( ~mix_rst    ),
    .clk        ( clk         ),
    .cen        ( cen_fm      ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),  // this connection seems irrelevant. The schematics have it, MAME doesn't
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     (             ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( cpu_din     ),
    .cpu_dout   ( cpu_dout    ),
    .ram_dout   ( ram_dout    ),
    // manage access to ROM data from SDRAM
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);

jt51 u_jt51(
    .rst        ( mix_rst   ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( !fm_cs    ), // chip select
    .wr_n       ( wr_n      ), // write
    .a0         ( A[0]      ),
    .din        ( cpu_dout  ),
    .dout       ( fm_dout   ),
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      ( int_n     ),
    // Low resolution output (same as real chip)
    .sample     ( sample    ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_left   ),
    .xright     ( fm_right  )
);

jtoutrun_pcm u_pcm(
    .rst        ( mix_rst       ),
    .clk        ( clk           ),
    .cen        ( cen_pcm       ),

    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_dout       ),
    // CPU interface
    .cpu_addr   ( A[7:0]        ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_din    ( pcm_dout      ),
    .cpu_rnw    ( wr_n          ),
    .cpu_cs     ( pcm_ce        ),

    // ROM interface
    .rom_addr   ( pcm_pre       ),
    .rom_data   ( pcm_data      ),
    .rom_ok     ( pcm_ok        ),
    .rom_cs     ( pcm_cs        ),

    .snd_left   ( pcm_left      ),
    .snd_right  ( pcm_right     ),
    .sample     ( pcm_sample    )
);

endmodule
