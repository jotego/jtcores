/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-3-2022 */

module jtngp_scr #( parameter
    SIMFILE = "scr1.bin"
)(
    input             rst,
    input             clk,
    input             pxl_cen,

    input      [ 8:0] hdump,
    input      [ 7:0] vdump,
    input      [ 7:0] hpos,
    input      [ 7:0] vpos,
    // CPU access
    input      [10:1] cpu_addr,
    output     [15:0] cpu_din,
    input      [15:0] cpu_dout,
    input      [ 1:0] dsn,
    input             scr_cs,
    // Character RAM
    output reg [12:1] chram_addr,
    input      [15:0] chram_data,
    // video output
    input             en,
    output     [ 6:0] pxl
);

wire [ 1:0] we;
reg  [ 9:0] scan_addr;
wire [15:0] scan_dout;
reg  [15:0] pxl_data;
reg  [ 8:0] heff;
reg  [ 7:0] veff;
reg  [ 3:0] pcol0, pcol;
reg         hflip, pal, hflip0, pal0;

assign we = ~dsn & {2{scr_cs}};

always @* begin
    heff = hdump + hpos;
    veff = vdump + vpos;
    scan_addr = { veff[7:3], heff[7:3] };
end
`ifdef SIMULATION
reg [15:0] chk_d=0;
reg [ 9:0] chk_a=0;
always @(posedge clk) if(we!=0) { chk_a, chk_d } <= { cpu_addr, cpu_dout & {{8{we[1]}},{8{we[0]}}} };
`endif
// 2048 bytes = 32x32 characters
jtframe_dual_ram16 #(
    .AW      (  10      ),
    .SIMFILE ( SIMFILE  )
) u_ram(
    // Port 0
    .clk0   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_addr  ),
    .we0    ( we        ),
    .q0     ( cpu_din   ),
    // Port 1
    .clk1   ( clk       ),
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 2'b0      ),
    .q1     ( scan_dout )
);

assign pxl = en ? { pcol, pal, hflip ? pxl_data[1:0] : pxl_data[15:14] } : 7'd0;

// scanner
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        chram_addr <= 0;
        hflip      <= 0;
        pal        <= 0;
        pxl_data   <= 0;
    end else if(pxl_cen) begin
        if( heff[1:0]==0 ) begin
            chram_addr <= { scan_dout[8:0], veff[2:0] ^ {3{scan_dout[14]}} };
            hflip0     <= scan_dout[15];
            pal0       <= scan_dout[13];
            pcol0      <= scan_dout[12-:4]; // color palette
            pxl_data   <= chram_data;
            hflip      <= hflip0;
            pal        <= pal0;
            pcol       <= pcol0;
            if( !heff[2] )
                pxl_data <= hflip ? {2{chram_data[15:8]}} : {2{chram_data[7:0]}};
        end else begin
            pxl_data   <= hflip ? pxl_data>>2 : pxl_data<<2;
        end
    end
end

endmodule