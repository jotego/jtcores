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
    Date: 20-4-2024 */

module jts18_sound(
    input                rst,
    input                clk,

    input                cen_fm,    //  8 MHz
    input                cen_pcm,   // 10 MHz

    // Mapper device 315-5195
    output               mapper_rd,
    output               mapper_wr,
    output [7:0]         mapper_din,
    input  [7:0]         mapper_dout,
    input                mapper_pbf, // pbf signal == buffer full ?

    // ROM
    output reg    [20:0] rom_addr,
    input         [ 7:0] rom_data,
    input                rom_ok,
    output reg           rom_cs,

    // ADPCM RAM
    output        [15:0] pcm0_addr,
    input         [ 7:0] pcm0_dout,

    output        [15:0] pcm1_addr,
    output               pcm1_we,
    input         [ 7:0] pcm1_dout,
    output        [ 7:0] pcm1_din,

    // Sound output
    output signed [15:0] fm0_l, fm0_r, fm1_l, fm1_r,
    output signed [ 9:0] pcm
);
`ifndef NOSOUND

wire        io_wrn, rd_n, wr_n, int_n, mreq_n, iorq_n, m1_n, nmi_n;
wire [15:0] A;
wire [ 7:0] dout, ram_dout, din, pcmctl_dout, fm0_dout, fm1_dout;
reg  [ 7:0] bank, dmux;
reg         ram_cs, bkreg_cs, bank_cs, mapper_cs,
            fm0_cs, fm1_cs, pcm_cs;

assign io_wrn     = iorq_n | wr_n;
assign mapper_rd  = mapper_cs && !rd_n;
assign mapper_wr  = mapper_cs && !wr_n;
assign mapper_din = dout;
assign din        = rom_cs ? rom_data : dmux;
assign nmi_n      = ~mapper_pbf;
// right channel is disconnected on the PCB
assign fm0_r      = 0;
assign fm1_r      = 0;

// ROM bank address
always @(*) begin
    rom_addr = { 5'd0, A };
    if( bank_cs ) rom_addr[20-:8] = bank;
end

wire underA = A[15:12]<4'ha;
wire underC = A[15:12]<4'hc;

always @(*) begin
    ram_cs  = !mreq_n && &A[15:13];
    bank_cs = !mreq_n && (!underA && underC);
    pcm_cs  = !mreq_n && (!underC && A[15:12]<4'he);
    rom_cs  = !mreq_n &&   underC;

    // Port Map
    { fm0_cs, fm1_cs, bkreg_cs, mapper_cs } = 0;
    if( !iorq_n && m1_n ) begin
        case( A[7:5] )
            4: begin
                fm0_cs = !A[4];
                fm1_cs =  A[4];
            end
            5: bkreg_cs  = ~wr_n;
            6: mapper_cs = 1;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    dmux <= fm0_cs    ? fm0_dout    :
            fm1_cs    ? fm1_dout    :
            mapper_cs ? mapper_dout :
            ram_cs    ? ram_dout    :
            pcm_cs    ? pcmctl_dout : 8'hff;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank <= 0;
    end else begin
        if( bkreg_cs ) bank <= dout;
    end
end
/* verilator tracing_off */
jt12 u_fm0(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_fm        ),
    .din        ( dout          ),
    .addr       ( A[1:0]        ),
    .cs_n       ( ~fm0_cs       ),
    .wr_n       ( io_wrn        ),

    .dout       ( fm0_dout      ),
    .irq_n      ( int_n         ),
    // configuration
    .en_hifi_pcm( 1'b1          ),
    // combined output
    .snd_right  (               ),
    .snd_left   ( fm0_l         ),
    .snd_sample (               )
);

jt12 u_fm1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_fm        ),
    .din        ( dout          ),
    .addr       ( A[1:0]        ),
    .cs_n       ( ~fm1_cs       ),
    .wr_n       ( io_wrn        ),

    .dout       ( fm1_dout      ),
    .irq_n      (               ),
    // configuration
    .en_hifi_pcm( 1'b1          ),
    // combined output
    .snd_right  (               ),
    .snd_left   ( fm1_l         ),
    .snd_sample (               )
);
/* verilator tracing_on */
jtpcm568 u_pcm(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_pcm       ),

    // CPU interface
    .wr         ( ~wr_n         ),
    .cs         ( pcm_cs        ),
    .addr       ( A[12:0]       ),
    .din        ( dout          ),
    .dout       ( pcmctl_dout   ),

    // ADPCM RAM
    // Access by PCM logic
    .ram0_addr  ( pcm0_addr     ),
    .ram0_dout  ( pcm0_dout     ),
    // Access by CPU
    .ram1_addr  ( pcm1_addr     ),
    .ram1_we    ( pcm1_we       ),
    .ram1_dout  ( pcm1_dout     ),
    .ram1_din   ( pcm1_din      ),

    .snd_l      ( pcm           ),
    .snd_r      (               )
);

// Need more than 48MHz clock for using RECOVERY
// on an 8MHz Z80
jtframe_sysz80 #(.RAM_AW(13),.RECOVERY(1)) u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( cen_fm      ),
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
    .cpu_din    ( din         ),
    .cpu_dout   ( dout        ),
    .ram_dout   ( ram_dout    ),
    // manage access to ROM data from SDRAM
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);
`else
initial rom_addr  = 0;
initial rom_cs    = 0;
assign mapper_rd  = 0;
assign mapper_wr  = 0;
assign mapper_din = 0;
assign pcm0_addr  = 0;
assign pcm1_addr  = 0;
assign pcm1_we    = 0;
assign pcm1_din   = 0;
assign fm0_l      = 0;
assign fm0_r      = 0;
assign fm1_l      = 0;
assign fm1_r      = 0;
assign pcm        = 0;
`endif
endmodule