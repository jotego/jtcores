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
    Date: 24-7-2023 */

module jtsimson_obj(
    input             rst,
    input             clk,

    input             pxl_cen,
    input             pxl2_cen,
    input      [ 8:0] hdump,
    input      [ 8:0] vdump,
    input             hs,
    input             vs,
    input             lvbl, // not an input in the original
    input             lhbl, // not an input in the original

    // CPU interface
    input             ram_cs,
    input             reg_cs,
    input             cpu_we,
    input      [15:0] cpu_dout, // 16-bit interface
    input      [13:1] cpu_addr, // 16 kB (?)
    output     [15:0] cpu_din,
    input      [ 1:0] cpu_dsn,
    output            dma_bsy,

    // ROM addressing
    output     [21:2] rom_addr,
    input      [31:0] rom_data,
    output            rom_cs,
    input             rom_ok,
    input             objcha_n,

    // pixel output
    output     [ 1:0] shd,      // shadow
    output     [ 4:0] prio,
    output     [ 8:0] pxl,

    // debug
    input             ioctl_ram,
    input      [13:0] ioctl_addr,
    output     [ 7:0] dump_ram,
    output     [ 7:0] dump_reg,
    output     [ 7:0] st_obj,
    input      [ 7:0] debug_bus
);

wire [ 1:0] ram_we, pre_shd;
wire [15:0] ram_data, dma_data;
wire [22:2] pre_addr;
wire [21:1] rmrd_addr;
wire [13:1] dma_addr;
wire [15:0] pre_pxl;

// Draw module
wire        dr_start, dr_busy;
wire [15:0] code;
wire [ 9:0] attr;     // OC pins
wire        hflip, vflip, hz_keep, pre_cs;
wire [ 8:0] hpos;
wire [ 3:0] ysub;
wire [ 9:0] hzoom;
wire [31:0] sorted;

wire irq_en, scr_hflip, scr_vflip;

assign ram_we    = {2{cpu_we&ram_cs}} & ~{cpu_dsn[0],cpu_dsn[1]};
assign rom_cs    = ~objcha_n | pre_cs;
assign rom_addr  = objcha_n ? { pre_addr[21:7], pre_addr[5:2], pre_addr[6] } :
                              rmrd_addr[21:2];
assign cpu_din   = objcha_n ? ram_data :
                   rmrd_addr[1] ? rom_data[31:16] : rom_data[15:0];
assign st_obj    = 0;

assign { shd, prio, pxl } = pre_pxl;
assign sorted = {
    rom_data[15], rom_data[11], rom_data[7], rom_data[3], rom_data[31], rom_data[27], rom_data[23], rom_data[19],
    rom_data[14], rom_data[10], rom_data[6], rom_data[2], rom_data[30], rom_data[26], rom_data[22], rom_data[18],
    rom_data[13], rom_data[ 9], rom_data[5], rom_data[1], rom_data[29], rom_data[25], rom_data[21], rom_data[17],
    rom_data[12], rom_data[ 8], rom_data[4], rom_data[0], rom_data[28], rom_data[24], rom_data[20], rom_data[16]
};

jt053246 u_scan(    // sprite logic
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),

    // CPU interface
    .cs         ( reg_cs    ),
    .cpu_we     ( cpu_we    ),
    .cpu_addr   (cpu_addr[2:1]),
    .cpu_dsn    ( cpu_dsn   ),
    .cpu_dout   ( cpu_dout  ),
    .rmrd_addr  ( rmrd_addr ),

    // External RAM
    .dma_addr   ( dma_addr  ), // up to 16 kB
    .dma_data   ( dma_data  ),
    .dma_bsy    ( dma_bsy   ),

    // ROM addressing 22 bits in total
    .code       ( code      ),
    .attr       ( attr      ),     // OC pins
    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .hpos       ( hpos      ),
    .ysub       ( ysub      ),
    .hzoom      ( hzoom     ),
    .hz_keep    ( hz_keep   ),

    // control
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .vs         ( vs        ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),

    // shadow
    .pxl        ( pxl       ),
    .shd        ( pre_shd   ),

    // draw module / 053247
    .dr_start   ( dr_start  ),
    .dr_busy    ( dr_busy   ),

    // Debug
    .debug_bus  ( debug_bus ),
    .st_addr    (ioctl_addr[7:0]),
    .st_dout    ( dump_reg  )
);

jtframe_objdraw #(
    .CW(16),.PW(4+10+2),.LATCH(1),.SWAPH(1),.ZW(7),.FLIP_OFFSET(9'h12)
) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( hs        ),
    .flip       ( 1'b0      ),
    .hdump      ( hdump     ),

    .draw       ( dr_start  ),
    .busy       ( dr_busy   ),
    .code       ( code      ),
    .xpos       ( hpos      ),
    .ysub       ( ysub      ),
    .hz_keep    ( 1'b0      ),
    .hzoom      ( 7'd0      ),
    // .hz_keep    ( hz_keep   ),
    // .hzoom      ({1'b0,hzoom}),

    .hflip      ( ~hflip    ),
    .vflip      ( vflip     ),
    .pal        ({pre_shd, attr}),

    .rom_addr   ( pre_addr  ),
    .rom_cs     ( pre_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( sorted    ),

    .pxl        ( pre_pxl   )
);


localparam RAMW=12;

jtframe_dual_nvram16 #(
    .AW        ( RAMW       ),
    .SIMFILE_LO("obj_lo.bin"),
    .SIMFILE_HI("obj_hi.bin")
) u_ram( // 8 or 16kB? check PCB. Game seems to work on 8kB ok
    // Port 0 - CPU access
    .clk0   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_addr[RAMW:1] ),
    .we0    ( ram_we    ),
    .q0     ( ram_data  ),
    // Port 1 - Video access
    .clk1   ( clk       ),
    .addr1a ( dma_addr[RAMW:1] ),
    .q1a    ( dma_data  ),
    // 8-bit IOCTL access
    .data1  ( 8'd0      ),
    .addr1b ( ioctl_addr[RAMW:0] ),
    .we1b   ( 1'd0      ),
    .q1b    ( dump_ram  ),
    .sel_b  ( ioctl_ram )
);

endmodule