/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2017 */

module jttora_adpcm(
    input           rst,
    input           clk,
    input           cen3,    //  3   MHz
    input           cenp384, //  384 kHz
    // Interface with second CPU
    input   [7:0]   snd2_latch,
    // ADPCM ROM
    output  [15:0]  rom2_addr,
    output          rom2_cs,
    input   [ 7:0]  rom2_data,
    input           rom2_ok,
    // `ifdef VERILATOR
    // output  [ 3:0]  adpcm_din,
    // output          adpcm_irq,
    // `endif

    // Sound output
    output signed [11:0] snd
);

// ADPCM CPU
reg  last_rom2_cs, int_n;
wire wr_n, rd_n, iorq_n, rfsh_n, mreq_n, m1_n;
assign rom2_cs = !mreq_n && rfsh_n;
wire [15:0] A;
reg  [ 7:0] din;
wire [ 7:0] dout;
wire        sample;

assign rom2_addr = A;

always @(*) begin
    din = !iorq_n && !rd_n && !A[0] ? snd2_latch : rom2_data;
end

reg [3:0] pcm_data;
reg       pcm_rst;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pcm_rst  <= 1'b0;
        pcm_data <= 4'd0;
    end else begin
        if( !iorq_n && A[0] && !wr_n ) begin
            pcm_rst  <= dout[7];
            pcm_data <= dout[3:0];
        end
    end
end

wire irq_st;

jt5205 u_adpcm(
    .rst        ( rst | pcm_rst ),
    .clk        ( clk           ),
    .cen        ( cenp384       ),
    .sel        ( 2'b0          ),
    .din        ( pcm_data      ),
    .sound      ( snd           ),
    .irq        ( irq_st        ),
    .sample     ( sample        ),
    .vclk_o     (               )
);

// `ifdef VERILATOR
// assign adpcm_din = pcm_data;
// assign adpcm_irq = irq_st;
// `endif

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
    .cen        ( cen3        ),
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