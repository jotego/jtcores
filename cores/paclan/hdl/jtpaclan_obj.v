/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-5-2025 */

// The PCB shows the memories for a double-line buffer
// The CPU seems free to write the object LUT at any time
module jtpaclan_obj(
    input             rst,
    input             clk, pxl_cen, hs, lvbl,
                      flip, rot,
    input      [ 8:0] hdump, vdump,

    // Look-up table
    output     [12:1] ram_addr,
    input      [15:0] ram_dout,
    // Palette ROM
    output     [ 9:0] pal_addr,
    input      [ 7:0] pal_data,

    output            rom_cs,
    output     [15:2] rom_addr,
    input      [31:0] rom_data,
    input             rom_ok,

    output     [ 7:0] pxl,

    // Debug
    input      [7:0] debug_bus
);

parameter SKYKID=0;

wire [31:0] sorted, pl_sorted, sk_sorted;
wire [ 9:0] buf_pred;
wire [ 7:0] sk_msb;
wire [ 8:0] addr_hi;
wire [ 3:0] addr_v;
wire        addr_h, hmsb;
wire        hflip, vflip, draw, dr_busy, dr_draw;
wire [ 8:0] code, hpos;
wire [ 5:0] pal;
wire [ 4:0] ysub;
wire [ 1:0] nc;
wire        vsize, hsize;
reg         blankn;

assign rom_addr = { addr_hi[8:2],
    vsize ? ysub[4]^vflip : addr_hi[1],    // V16
    hsize ?   ~hmsb^hflip : addr_hi[0],    // H16
    addr_v,
    addr_h
};

assign pl_sorted = {
    rom_data[ 7], rom_data[ 6], rom_data[ 5], rom_data[ 4], rom_data[23], rom_data[22], rom_data[21], rom_data[20],
    rom_data[ 3], rom_data[ 2], rom_data[ 1], rom_data[ 0], rom_data[19], rom_data[18], rom_data[17], rom_data[16],
    rom_data[15], rom_data[14], rom_data[13], rom_data[12], rom_data[31], rom_data[30], rom_data[29], rom_data[28],
    rom_data[11], rom_data[10], rom_data[ 9], rom_data[ 8], rom_data[27], rom_data[26], rom_data[25], rom_data[24]
};

assign sk_msb    = addr_hi[8] ? 8'd0 : addr_hi[7] ? pl_sorted[15:8] : pl_sorted[7:0];
assign sk_sorted = { 8'd0, sk_msb, pl_sorted[31:16] };
assign sorted    = SKYKID==1 ? sk_sorted : pl_sorted;
assign pal_addr  = SKYKID==1 ? {1'b0,buf_pred[9:4],buf_pred[2:0]} : buf_pred;

always @(posedge clk) blankn <= !(vdump>9'hf8 && vdump<9'h11d);

jtpaclan_objscan #(.SKYKID(SKYKID)) u_scan(
    .clk        ( clk       ),
    .hs         ( hs        ),
    .blankn     ( blankn    ),
    .flip       ( flip      ),
    .rot        ( rot       ),
    .vrender    ( vdump     ),

    .code       ( code      ),
    .hsize      ( hsize     ),
    .vsize      ( vsize     ),
    .ysub       ( ysub      ),
    .pal        ( pal       ),
    .hpos       ( hpos      ),
    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .hmsb       ( hmsb      ),

    // Look-up table
    .ram_addr   ( ram_addr  ),
    .ram_dout   ( ram_dout  ),

    .dr_busy    ( dr_busy   ),
    .dr_draw    ( dr_draw   ),

    .debug_bus  ( debug_bus )
);

jtframe_objdraw_gate #(.CW(9),.PW(6+4),.LATCH(1),
    .HFIX(0),.SWAPH(1),
    // the full palette data is used as alpha
    .ALPHA(255),
    .ALPHAW(8),
    .BUFDLY(1)
) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( flip && SKYKID==0 ),
    .hdump      ( hdump     ),

    .draw       ( dr_draw   ),
    .busy       ( dr_busy   ),
    .code       ( code      ),
    .xpos       ( hpos      ),
    .ysub       ( ysub[3:0] ),
    // optional zoom, keep at zero for no zoom
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'b0      ),
    .trunc      ( 2'b0      ),

    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( pal       ),

    .buf_pred   ( buf_pred  ),
    .buf_din    ({2'd0,pal_data}),

    .rom_addr   ( {addr_hi,addr_h,addr_v}  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( sorted    ),

    .pxl        ( {nc,pxl}  )
);

endmodule