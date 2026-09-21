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

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 18-9-2026
*/

// Namco C116 + C156 palette/priority mixer for System FL
// 3 external 8kB RAMs (R,G,B) hold the palette; clip window and raster
// IRQ from 6 byte-wide register pairs (big endian, mirrored every 16B)
// ROZ mixes at its 4-bit prio, tilemaps at 2x their 3-bit prio,
// sprites win on obj_prio>=background prio; pen 0xffe casts a shadow

module jtc116(
    input             rst,
    input             clk,

    input             pxl_cen, lvbl, lhbl,
    input      [ 8:0] hdump, vdump,
    input             hs,
    output reg        raster_irqn,

    // pixels
    input      [11:0] scr_pxl, roz_pxl, obj_pxl,
    input      [ 2:0] scr_prio,
    input      [ 3:0] roz_prio, obj_prio,
    input             scr_blankn, roz_blankn, obj_blankn, obj_shd,

    input      [14:0] cpu_addr,
    input             cs, cpu_rnw,
    output     [12:0] rgb_addr, pal_addr,
    output            rpal_we, gpal_we, bpal_we,

    input      [ 7:0] cpu_dout,
                      red_dout,   rpal_dout,
                      green_dout, gpal_dout,
                      blue_dout,  bpal_dout,
    output reg [ 7:0] pal_dout,
    output     [ 7:0] red, green, blue,
    // Debug
    input      [ 3:0] ioctl_addr,
    output     [ 7:0] ioctl_din,
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

parameter SIMFILE="rest.bin", SEEK=96;


localparam [8:0] HOFFSET = 9'h00a, VOFFSET = 9'h100;

reg         mmr_cs, r_cs, g_cs, b_cs,
            vwin, // in vertical   window
            hwin; // in horizontal window
wire        blank, scr_g, roz_g, obj_g, scr_win,
            bg_opq, obj_win, sh_en, lyr_obj;
wire [ 3:0] scr_eff, bg_prio;
wire [12:0] bg_rgb;
wire [ 8:0] left, right, top, bottom, vtrig, hadj, vadj;
wire [15:0] mmr_left, mmr_right, mmr_top, mmr_bottom, mmr_vtrig;
wire [ 7:0] mmr_dout;

assign left    = mmr_left[8:0];
assign right   = mmr_right[8:0];
assign top     = mmr_top[8:0];
assign bottom  = mmr_bottom[8:0];
// raster IRQ at screen line reg5-33 (namcofl.cpp:400): in vdump space that
// is reg5-33+0x121 = reg5-VOFFSET (mod 512); MAME's -33 must not be applied
// on top of the vdump base or the IRQ fires 33 lines early (mirror band)
assign vtrig   = mmr_vtrig[8:0]-VOFFSET;
assign hadj    = hdump+HOFFSET;
assign vadj    = vdump<9'h100 ? 9'h100 : vdump+VOFFSET; // counter wrap row = bottom line

// C156 priority mix
`ifdef SIMULATION
reg [7:0] simlyr [0:0];
initial begin simlyr[0]=8'hff; $readmemh("lyrmask.hex", simlyr); end
assign scr_g   = scr_blankn & gfx_en[0];
assign roz_g   = roz_blankn & gfx_en[1] & simlyr[0][6];
assign obj_g   = obj_blankn & gfx_en[3] & simlyr[0][7];
`else
assign scr_g   = scr_blankn & gfx_en[0];
assign roz_g   = roz_blankn & gfx_en[1];
assign obj_g   = obj_blankn & gfx_en[3];
`endif
assign scr_eff = {scr_prio,1'b0};
assign scr_win = scr_g && (!roz_g || scr_eff>=roz_prio); // tilemap drawn after ROZ
assign bg_opq  = scr_g | roz_g;
assign bg_prio = !bg_opq ? 4'd0 : scr_win ? scr_eff : roz_prio;
assign bg_rgb  = scr_win ? {1'b1,scr_pxl} : 13'h1800+{1'b0,roz_pxl};
assign obj_win = obj_g && obj_prio>=bg_prio;
assign sh_en   = obj_win &&  obj_shd;
assign lyr_obj = obj_win && !obj_shd;
assign rgb_addr= lyr_obj ? {1'b0,obj_pxl} :
                 {bg_rgb[12],bg_rgb[11]|sh_en,bg_rgb[10:0]};

// CPU access: A13/A14 pass through the C156 as pen bank
assign pal_addr= {cpu_addr[14:13], cpu_addr[10:0]};
assign rpal_we = ~cpu_rnw & r_cs;
assign gpal_we = ~cpu_rnw & g_cs;
assign bpal_we = ~cpu_rnw & b_cs;

`ifdef GRAY
assign red   = blank ? 8'd0 : {8{scr_pxl[0]}};
assign green = blank ? 8'd0 : {8{scr_pxl[0]}};
assign blue  = blank ? 8'd0 : {8{scr_pxl[0]}};
`else
assign red   = blank ? 8'd0 : red_dout;
assign green = blank ? 8'd0 : green_dout;
assign blue  = blank ? 8'd0 : blue_dout;
`endif
assign blank = ~(lhbl & lvbl) | ~vwin | ~hwin | ~(bg_opq|lyr_obj);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pal_dout    <= 0;
        raster_irqn <= 1;
    end else begin
        raster_irqn <= !(vdump==vtrig && hs);
        pal_dout <= r_cs ? rpal_dout :
                    g_cs ? gpal_dout :
                    b_cs ? bpal_dout : mmr_dout;
    end
end

always @* begin
    vwin = vadj>=top  && vadj<bottom;
    hwin = hadj>=left && hadj<right;
end

jtsysfl_c116_mmr #(.SIMFILE(SIMFILE),.SEEK(SEEK)) u_mmr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cs         ( mmr_cs    ),
    .addr       (cpu_addr[3:0]),
    .rnw        ( cpu_rnw   ),
    .din        ( cpu_dout  ),
    .dout       ( mmr_dout  ),
    .left       ( mmr_left  ),
    .right      ( mmr_right ),
    .top        ( mmr_top   ),
    .bottom     ( mmr_bottom),
    .hirq       (           ),
    .vtrig      ( mmr_vtrig ),
    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_dout   )
);

always @* begin
    r_cs   = 0;
    g_cs   = 0;
    b_cs   = 0;
    mmr_cs = 0;
    if(cs) case( cpu_addr[12:11] )
        0: r_cs   = 1;
        1: g_cs   = 1;
        2: b_cs   = 1;
        3: mmr_cs = 1;
    endcase
end


endmodule
