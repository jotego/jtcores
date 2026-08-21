/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-6-2021 */

module jts16_shadow #(parameter VRAMW=14) (
    input             clk,
    input             clk_rom,

    // Capture SDRAM bank 0 inputs
    input   [VRAMW:1] addr,
    input             char_cs,    //  4k
    input             vram_cs,    // 32k
    input             pal_cs,     //  4k
    input             objram_cs,  //  2k
    input      [15:0] din,
    input      [ 1:0] dswn,  // write mask -active low

    input      [ 5:0] tile_bank,

    // Let data be dumped via NVRAM interface
    input      [16:0] ioctl_addr,
    output     [ 7:0] ioctl_din
);

`ifndef MISTER
    assign ioctl_din = 0;
`else

wire [15:0] vram_dout, char_dout, pal_dout, objram_dout;
reg  [15:0] dout, dout_latch;

wire [ 1:0] vram_we   = vram_cs   ? ~dswn : 2'b0;
wire [ 1:0] char_we   = char_cs   ? ~dswn : 2'b0;
wire [ 1:0] pal_we    = pal_cs    ? ~dswn : 2'b0;
wire [ 1:0] objram_we = objram_cs ? ~dswn : 2'b0;

assign ioctl_din = ~ioctl_addr[0] ? dout_latch[15:8] : dout_latch[7:0];

always @(*) begin
    if( VRAMW==14 ) begin
        casez( ioctl_addr[15:11] )
            5'b0???_?: dout = vram_dout;
            5'b1000_?: dout = char_dout;
            5'b1001_?: dout = pal_dout;
            5'b1010_0: dout = objram_dout;
            default:   dout = 16'hffff;
        endcase
    end else begin
        dout = vram_dout;
        if( ioctl_addr[16] ) begin
            casez( ioctl_addr[15:12] )
                4'b0000: dout = char_dout;    // 4kB
                4'b0001: dout = pal_dout;     // 4kB
                4'b0010:
                    dout = ioctl_addr[11] ? {10'd0, tile_bank} : objram_dout;  // 2kB
                default: dout = 16'hffff;
            endcase
        end
    end
end

always @(posedge clk_rom) begin
    if( ioctl_addr[0] )
        dout_latch <= dout;
end

jtframe_dual_ram16 #(.AW(VRAMW)) u_vram(
    .clk0       ( clk       ),
    .clk1       ( clk_rom   ),
    // CPU writes
    .data0      ( din       ),
    .addr0      ( addr      ),
    .we0        ( vram_we   ),
    .q0         (           ),
    // hps_io reads
    .data1      (           ),
    .addr1      ( ioctl_addr[VRAMW:1] ),
    .we1        ( 2'b0      ),
    .q1         ( vram_dout )
);

jtframe_dual_ram16 #(.AW(11)) u_char(
    .clk0       ( clk       ),
    .clk1       ( clk_rom   ),
    // CPU writes
    .data0      ( din       ),
    .addr0      ( addr[11:1]),
    .we0        ( char_we   ),
    .q0         (           ),
    // hps_io reads
    .data1      (           ),
    .addr1      ( ioctl_addr[11:1] ),
    .we1        ( 2'b0      ),
    .q1         ( char_dout )
);

jtframe_dual_ram16 #(.AW(11)) u_pal(
    .clk0       ( clk       ),
    .clk1       ( clk_rom   ),
    // CPU writes
    .data0      ( din       ),
    .addr0      ( addr[11:1]),
    .we0        ( pal_we    ),
    .q0         (           ),
    // hps_io reads
    .data1      (           ),
    .addr1      ( ioctl_addr[11:1] ),
    .we1        ( 2'b0      ),
    .q1         ( pal_dout )
);

jtframe_dual_ram16 #(.AW(10)) u_objram(
    .clk0       ( clk       ),
    .clk1       ( clk_rom   ),
    // CPU writes
    .data0      ( din       ),
    .addr0      ( addr[10:1]),
    .we0        ( objram_we ),
    .q0         (           ),
    // hps_io reads
    .data1      (           ),
    .addr1      ( ioctl_addr[10:1] ),
    .we1        ( 2'b0      ),
    .q1         ( objram_dout )
);

`endif
endmodule