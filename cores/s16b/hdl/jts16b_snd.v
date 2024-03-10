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
    Date: 5-7-2021 */

module jts16b_snd(
    input                rst,
    input                clk,

    input                cen_snd,   // 5MHz -- jumper to select 5 or 4MHz
    input                cen_fm,    // 4MHz
    input                cen_fm2,   // 2MHz
    input                cen_pcm,   // 0.640
    input  [7:0]         game_id,

    // Mapper device 315-5195
    output               mapper_rd,
    output               mapper_wr,
    output [7:0]         mapper_din,
    input  [7:0]         mapper_dout,
    input                mapper_pbf, // pbf signal == buffer full ?

    // ROM
    output    reg [18:0] rom_addr,
    output    reg        rom_cs,
    input         [ 7:0] rom_data,
    input                rom_ok,

    // MC8123 encoding
    input                dec_en,
    output        [12:0] key_addr,
    input         [ 7:0] key_data,

    // Sound output
    output signed [15:0] fm_l, fm_r,
    output signed [ 8:0] pcm
);
`ifndef NOSOUND
wire [15:0] A;
reg         fm_cs, mapper_cs, ram_cs, bank_cs,
            pcm_cs, misc_cs;
wire        mreq_n, iorq_n, int_n;
reg  [ 7:0] cpu_din, pcm_cmd;
reg         rom_ok2;
wire        rom_good, dec_ok;
wire [ 7:0] cpu_dout, fm_dout, ram_dout, rom_dec, dec_dout;
wire        nmi_n, pcm_busyn,
            wr_n, rd_n, m1_n;
reg         pcm_mdn, pcm_rst;
reg  [ 5:0] rom_msb;

assign mapper_rd   = mapper_cs && !rd_n;
assign mapper_wr   = mapper_cs && !wr_n;
assign mapper_din  = cpu_dout;

// ROM bank address
always @(*) begin
    rom_addr = { 4'd0, A[14:0] };
    if( bank_cs ) begin
        casez( game_id[7:3] )
            5'b001?_?: // 5797
                rom_addr[18:14] = { rom_msb[3], rom_msb[4], rom_msb[2:0] };
            5'b0001_?: begin // 5358
                rom_addr[15:14] = rom_msb[1:0];
                casez( ~rom_msb[5:2] ) // A11-A8 refer to the ROM label in the PCB:
                    4'b1000: rom_addr[17:16] = 3; // A11 at top
                    4'b0100: rom_addr[17:16] = 2; // A10
                    4'b0010: rom_addr[17:16] = 1; // A9
                    4'b0001: rom_addr[17:16] = 0; // A8
                    default: rom_addr[17:16] = 0;
                endcase
            end
            default: // 5521 & 5704
                rom_addr[17:14] = rom_msb[3:0];
        endcase
        rom_addr = rom_addr + 19'h10000;
    end
end

always @(*) begin
    ram_cs  = !mreq_n && &A[15:11];
    bank_cs = !mreq_n && (A[15:12]>=8 && A[15:12]<4'he);
    rom_cs  = (!mreq_n && !A[15]) || bank_cs;

    // Port Map
    { fm_cs, misc_cs, pcm_cs, mapper_cs } = 0;
    if( !iorq_n && m1_n ) begin
        case( A[7:6] )
            0: fm_cs     = 1;
            1: misc_cs   = 1;
            2: pcm_cs    = 1;
            3: mapper_cs = 1;
        endcase
    end else begin
        mapper_cs = (!mreq_n &&  A[15:12]==4'he && A[11]); // e800
    end
end

always @(posedge clk) begin
    rom_ok2  <= rom_ok;
    cpu_din  <= rom_cs    ? rom_dec  : ( // rom_data
                ram_cs    ? ram_dout : (
                fm_cs     ? fm_dout  : (
                pcm_cs    ? { pcm_busyn, ~7'd0 } : (
                mapper_cs ? mapper_dout : (
                    8'hff )))));
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_msb <= 0;
        pcm_mdn <= 1;
        pcm_rst <= 1;
    end else if(misc_cs & ~wr_n) begin
        rom_msb <= cpu_dout[5:0];
        pcm_rst <= ~cpu_dout[6];
        pcm_mdn <= ~cpu_dout[7];
    end
end

assign int_n = ~mapper_pbf;

// CPU encryption
assign rom_good = dec_en ? dec_ok : rom_ok2 & rom_ok;
assign rom_dec  = dec_en ? dec_dout : rom_data;

jtmc8123 u_dec(
    .clk        ( clk       ),

    // interface to Z80 CPU
    .m1_n       ( m1_n      ),
    .a          ( A         ),
    .enc_en     ( ~bank_cs  ),

    // connect to program ROM
    .enc        ( rom_data  ),
    .rom_ok     ( rom_ok2   ),

    // Decoded
    .dec        ( dec_dout  ),
    .dec_ok     ( dec_ok    ),

    // Keys
    .key_addr   ( key_addr  ),
    .key_data   ( key_data  )
);

jtframe_sysz80 #(.RAM_AW(11),.RECOVERY(1)) u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( cen_snd     ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
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
    .rom_ok     ( rom_good    )
);

//
//  YM2151 output port
//
//  D1 = /RESET line on 7751
//  D0 = /IRQ line on 7751
//

jt51 u_jt51(
    .rst        ( rst       ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( !fm_cs    ), // chip select
    .wr_n       ( wr_n      ), // write
    .a0         ( A[0]      ),
    .din        ( cpu_dout  ),
    .dout       ( fm_dout   ),
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      (           ),
    // Low resolution output (same as real chip)
    .sample     (           ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);

jt7759 u_pcm(
    .rst        ( pcm_rst   ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_pcm   ),  // 640kHz
    .stn        ( 1'b1      ),  // STart (active low)
    .cs         ( pcm_cs    ),
    .mdn        ( pcm_mdn   ),  // MODE: 1 for stand alone mode, 0 for slave mode
    .busyn      ( pcm_busyn ),
    // CPU interface
    .wrn        ( wr_n      ),  // for slave mode only
    .din        ( cpu_dout  ),
    .drqn       ( nmi_n     ),
    // ROM interface
    .rom_cs     (           ),      // equivalent to DRQn in original chip
    .rom_addr   (           ),
    .rom_data   (           ),
    .rom_ok     ( 1'b0      ),
    // Sound output
    .sound      ( pcm       )
);
`else
assign mapper_rd  = 0;
assign mapper_wr  = 0;
assign mapper_din = 0;
assign key_addr   = 0;
assign snd        = 0;
assign sample     = 0;
assign peak       = 0;
initial rom_addr  = 0;
initial rom_cs    = 0;
`endif
endmodule
