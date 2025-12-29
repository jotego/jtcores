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
    Date: 20-12-2025 */

module jtprmr_psac(
    input              rst, clk,
                       pxl_cen,  // use cen instead (see below)
                       hs, vs, dtackn,
                       cs,

    input       [ 8:0] hdump,

    input       [15:0] din,        // from CPU
    input       [ 4:1] addr,
    input       [ 1:0] dsn,
    input              tmap_bank,
    output             dma_n,
    // Lines RAM
    output      [10:1] line_addr,
    input       [15:0] line_dout,
    // Tile map
    output      [17:1] pscmap_addr,
    input       [15:0] pscmap_data,
    input              pscmap_ok,
    output             pscmap_cs,
    // Tiles
    output      [18:0] rom_addr,
    input       [ 7:0] rom_data,
    output reg         rom_cs,
    input              rom_ok,

    output      [ 7:0] pxl,
    // IOCTL dump
    input       [ 4:0] ioctl_addr,
    output      [ 7:0] ioctl_din,
    input       [ 7:0] debug_bus
);

reg  [17:1] pscmapaddr_l;
wire [ 8:0] la;
wire [ 2:1] lh;
wire [11:0] code;
wire [12:0] x, y;
wire        ob,cen;
wire [ 7:0] buf_din;
wire [ 3:0] pal;
wire [ 3:0] dmux;
reg         cen2=0;

assign line_addr = {la[7:0],lh};

assign rom_addr    = {code,y[3:0],x[3:1]}; // 12+4+4=20
assign dmux        = x[0] ? rom_data[7:4] : rom_data[3:0];
assign buf_din     = ob   ? 8'b0          : {pal,dmux};
assign pscmap_addr = {y[11:4], x[12:4]};
assign code        = pscmap_data[11:0];
assign pal         = {ob,pscmap_data[15:13]};
assign pscmap_cs   =~ob;

always @(posedge clk) begin
    cen2 <= ~cen2;

    pscmapaddr_l <= pscmap_addr;
    rom_cs       <= pscmapaddr_l == pscmap_addr && pscmap_ok;
end

/* verilator tracing_on */
jt053936 u_xy(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),

    .din        ( din       ),        // from CPU
    .addr       ( addr      ),

    .hs         ( hs        ),
    .vs         ( vs        ),
    .cs         ( cs        ),
    .dtackn     ( dtackn    ),
    .dsn        ( dsn       ),
    .dma_n      ( dma_n     ),

    .ldout      ( line_dout ),  // shared with CPU data pins on original
    .lh         ( lh        ),  // lh[0] always zero for 16-bit memories
    .la         ( la        ),

    .x          ( x         ),
    .xh         (           ),
    .y          ( y         ),
    .yh         (           ),
    .ob         ( ob        ), // out of bonds, original pin: NOB

    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din )
);

wire sdram_cs = pscmap_cs | rom_cs;
wire sdram_ok = pscmap_ok & rom_ok;

jtframe_linebuf_gate #(.RD_DLY(21), .RST_CT(9'h044)) u_linebuf(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .pxl_cen  ( pxl_cen   ),
    .cen      ( cen2      ),
    .lvbl     ( 1'b1      ),
    .hs       ( hs        ),
    .cnt_cen  ( cen       ),
  //  New line writting
    .we       ( cen       ),
    .hdump    ( hdump     ),
    .vdump    ( 9'h0      ),
  //  Previous line reading
    .rom_cs   ( sdram_cs  ),
    .rom_ok   ( sdram_ok  ),

    .pxl_data ( buf_din   ),
    .pxl_dump ( pxl       )
);

`ifdef SIMULATION
reg [8:0] ln_cnt, pxl_cnt, ln_tot, pxl_tot;
reg       hs_l, start;
wire      cnt_check;

always @(posedge clk) hs_l <= hs;
assign cnt_check = ln_tot==pxl_tot;

always @(posedge clk) begin
    if(rst) begin
        {ln_cnt,pxl_cnt, ln_tot, pxl_tot} <= 0;
        start  <= 0;
    end else if( ~hs & hs_l ) begin
        start <= 1;
        if(start) begin
            ln_cnt    <= 0;      pxl_cnt   <= 0;
            ln_tot    <= ln_cnt; pxl_tot   <= pxl_cnt;
            if( !cnt_check) begin
                $display("ERROR: not enough cen pulses provided to psac");
                $display("Received=%d. Needed=%d", ln_tot, pxl_tot);
                $finish;
            end
        end
    end else if(start) begin
        if(cen)
            ln_cnt  <= ln_cnt +1'd1;
        if(pxl_cen)
            pxl_cnt <= pxl_cnt+1'd1;
    end
end
`endif

endmodule
