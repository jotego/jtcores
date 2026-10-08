/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 9-9-2024 */

// Following Trojan schematics, although it is not
// used in Trojan but Avengers

module jttrojan_mcu(
    input                rst,
    input                clk_rom,
    input                clk,
    input                cen,       //  6   MHz
    input                LVBL,
    input        [ 8:0]  vdump,
    // CPU interface
    input                mwr,
    input                mrd,
    output reg  [ 7:0]  to_main,
    input        [ 7:0]  from_main,

    input                swr,
    input                srd,
    output reg   [ 7:0]  to_snd,
    input        [ 7:0]  from_snd,
    // ROM programming
    input        [11:0]  prog_addr,
    input        [ 7:0]  prom_din,
    input                prom_we
);
`ifndef NOMCU
wire [ 7:0] p0_o, p2_o, p3_i, p3_o;
reg         p36l;
wire        p3_strobe = p3_o[6] && !p36l;

assign p3_i = {2'b11,~mrd,LVBL,LVBL,~mwr,1'b1,~srd};

always @(posedge clk) begin
    if( rst ) begin
        p36l    <= 0;
        to_main <= 0;
        to_snd  <= 0;
    end else begin
        p36l <= p3_o[6];
        if( p3_strobe ) begin
            to_main <= p0_o;
            to_snd <= p2_o;
        end
    end
end

jtframe_8751mcu u_mcu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    // external memory: connected to main CPU
    .x_din      ( 8'd0      ),
    .x_dout     (           ),
    .x_addr     (           ),
    .x_wr       (           ),
    .x_acc      (           ),
    // interrupts
    .int0n      ( ~mwr      ), // P32
    .int1n      ( LVBL      ), // P33, /INT in sch, but it's basically LVBL
    // Ports
    .p0_i       ( !p3_o[7] ? from_main : 8'hff ),
    .p0_o       ( p0_o      ),

    .p1_i       ( vdump[7:0]),
    .p1_o       (           ),

    .p2_i       ( !p3_o[7] ? from_snd : 8'hff ), // main CPU sound latch
    .p2_o       ( p2_o      ),

    .p3_i       ( p3_i      ),
    .p3_o       ( p3_o      ),

    .clk_rom    ( clk_rom   ),
    .prog_addr  ( prog_addr ),
    .prom_din   ( prom_din  ),
    .prom_we    ( prom_we   )
);
`else // NOMCU
    assign to_main = 0;
    initial to_snd = 0;
`endif
endmodule
