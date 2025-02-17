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
    Date: 21-8-2020 */

// ADPCM samples have sound codes starting at $81 in the service menu
module jtsf_adpcm(
    input           rst,
    input           clk,
    input           cpu_cen,
    input           cenp384, //  384 kHz
    // Interface with second CPU
    input   [7:0]   snd_latch,
    // ADPCM ROM
    output  [17:0]  rom2_addr,
    output          rom2_cs,
    input   [ 7:0]  rom2_data,
    input           rom2_ok,

    // Sound output
    output          sample,
    output signed [11:0] pcm0, pcm1
);

// ADPCM CPU
wire        [15:0] A;
reg         [ 7:0] din;
wire        [ 7:0] dout;
reg         [ 2:0] bank, rom_msb;
reg                last_rom2_cs, int_n;
wire               wr_n, rd_n, iorq_n, rfsh_n, mreq_n, m1_n;

assign rom2_cs   = !mreq_n && rfsh_n;
assign rom2_addr = { rom_msb, A[14:0] };


always @(*) begin
    din = !iorq_n && !rd_n && A[0] ? snd_latch : rom2_data;
end

always @(*) begin
    if( !A[15] )
        rom_msb = 3'd0;
    else
        rom_msb = bank+1'd1;
end

reg [3:0] pcm0_data, pcm1_data;
reg       pcm0_rst,  pcm1_rst;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pcm0_rst  <= 1'b0;
        pcm1_rst  <= 1'b0;
        pcm0_data <= 4'd0;
        pcm1_data <= 4'd0;
        bank      <= 3'd0;
    end else begin
        if( !iorq_n && !wr_n ) begin
            case( A[1:0] )
                2'd0: begin
                    pcm0_rst  <= dout[7];
                    pcm0_data <= dout[3:0];
                end
                2'd1: begin
                    pcm1_rst  <= dout[7];
                    pcm1_data <= dout[3:0];
                end
                2'd2: begin
                    bank <= dout[2:0];
                end
                default:;
            endcase
        end
    end
end

wire       irq_st, irq0, irq1;
wire [1:0] fsel = 2'b10; // 8kHz
reg  [5:0] cencnt;

assign     irq_st = irq0; // | irq1;

jt5205 #(.INTERPOL(0)) u_adpcm0(
    .rst        ( pcm0_rst      ),
    .clk        ( clk           ),
    .cen        ( cenp384       ),
    .sel        ( fsel          ),
    .din        ( pcm0_data     ),
    .sound      ( pcm0          ),
    .irq        ( irq0          ),
    .sample     ( sample        ),
    .vclk_o     (               )
);

jt5205 #(.INTERPOL(0)) u_adpcm1(
    .rst        ( pcm1_rst      ),
    .clk        ( clk           ),
    .cen        ( cenp384       ),
    .sel        ( fsel          ),
    .din        ( pcm1_data     ),
    .sound      ( pcm1          ),
    .sample     (               ),
    .irq        ( irq1          ),
    .vclk_o     (               )
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

jtframe_z80_romwait u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( cpu_cen     ),
    .cpu_cen    (             ),
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
    .dout       ( dout        ),
    .rom_cs     ( rom2_cs     ),
    .rom_ok     ( rom2_ok     )
);

endmodule