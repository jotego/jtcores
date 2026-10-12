/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-8-2024 */

// 053244/5
module jtriders_obj #(parameter
    RAMW   = 12,
    CPU_ROM_REG = 0,
    CPU_8BIT = 0,
    HFLIP_OFFSET = 0,
    VFLIP_OFFSET = 0,
    DEBUG_FLICKER = 1,
    SHADOW = 0
)(
    input             rst,
    input             clk,

    input             pxl_cen,
    input             pxl2_cen,
    input      [ 8:0] hdump,
    input      [ 8:0] vdump,
    input             hs,
    input             lvbl,
    input             lgtnfght,

    // CPU interface
    input             ram_cs,
    input             reg_cs,
    input             mmr_we,
    input      [ 3:0] mmr_addr,
    input      [15:0] mmr_din,
    input      [ 1:0] mmr_dsn,
    input             mmr_noa1,

    input      [15:0] ram_din, // 16-bit interface
    input      [ 1:0] ram_we,
    input    [RAMW:1] ram_addr,
    output     [15:0] cpu_din,
    output            cpu_ok,
    output            dma_bsy,

    // ROM addressing
    output     [21:2] rom_addr,
    input      [31:0] rom_data,
    output            rom_cs,
    input             rom_ok,
    input             objcha_n,

    // pixel output
    output            shd,      // shadow
    output     [ 4:0] prio,
    output     [ 8:0] pxl,

    // debug
    input      [ 3:0] gfx_en,
    input             ioctl_ram,
    input      [13:0] ioctl_addr,
    output     [ 7:0] dump_ram,
    output     [ 7:0] dump_reg,
    input      [ 7:0] debug_bus
);

localparam SHADOW_PEN = SHADOW[0]==1 ? 4'd15 : 4'd0;

wire        pre_shd;
wire [ 3:0] pen_eff;
wire [15:0] ram_data, dma_data;
wire [22:2] pre_addr;
wire [21:1] rmrd_addr;
wire [13:1] scn_addr, dma_addr;
wire [15:0] pre_pxl;
wire        rom_read;
wire [15:0] rom_word;
wire [ 3:0] mmr_even;
wire [ 1:0] rom_lane;
reg  [ 7:0] rom_lo, rom_mid;
reg  [ 2:0] rom_hi;
reg         rom_read_l;
reg  [21:2] rom_addr_l;

// Draw module
wire        dr_start, dr_busy;
wire [15:0] code;
wire [ 6:0] attr;     // OC pins
wire        hflip, vflip, hz_keep, pre_cs;
wire [ 9:0] hpos;
wire [ 3:0] ysub;
wire [11:0] hzoom;
wire        pen15;

wire scr_hflip, scr_vflip;

function [5:0] paroda_conv(input [5:0]x);
    paroda_conv = { x[5], x[3], x[1], x[4], x[2], x[0] };
endfunction

assign rom_read  = CPU_ROM_REG && reg_cs && !mmr_we && mmr_addr[3:2]==2'b11;
assign rom_cs    = rom_read | ~objcha_n | pre_cs;
// The 053244 register pair 8/9 and register B address a 32-bit ROM word.
assign rom_addr  = rom_read ? {1'b0,rom_hi,rom_mid,rom_lo} :
                   !objcha_n ? rmrd_addr[21:2] :
    { pre_addr[21], pre_addr[20:13], paroda_conv(pre_addr[12:7]), pre_addr[5], pre_addr[6],  pre_addr[4:2] };
assign rom_word  = mmr_addr[1] ? rom_data[31:16] : rom_data[15:0];
// 053244 swaps the low address bit on CPU byte reads (C/D and E/F).
assign rom_lane  = mmr_addr[1:0] ^ 2'b01;
assign cpu_din   = rom_read  ? (CPU_8BIT || !mmr_noa1) ?
                   {8'd0,rom_data[{rom_lane,3'b000}+:8]} : rom_word :
                   !objcha_n ? rmrd_addr[1] ? rom_data[31:16] : rom_data[15:0] :
                   CPU_ROM_REG && reg_cs && !CPU_8BIT ? 16'd0 :
                    ram_data;
// JTFRAME's registered cache may keep rom_ok high for the old draw address
// during the first clock of a CPU read or after a word-address change.
assign cpu_ok    = !rom_read || (rom_read_l && rom_addr_l==rom_addr && rom_ok);
assign mmr_even  = {mmr_addr[3:1],1'b0};

always @(posedge clk) begin
    rom_read_l <= !rst && rom_read;
    rom_addr_l <= rst ? 20'd0 : rom_addr;
end

always @(posedge clk) begin
    if (rst) begin
        rom_lo  <= 0;
        rom_mid <= 0;
        rom_hi  <= 0;
    end else if (CPU_ROM_REG && reg_cs && mmr_we) begin
        if (CPU_8BIT) begin
            case (mmr_addr)
                4'h8: rom_mid <= mmr_din[7:0];
                4'h9: rom_lo  <= mmr_din[7:0];
                4'hb: rom_hi  <= mmr_din[2:0];
                default: ;
            endcase
        end else if (mmr_noa1) begin
            if (!mmr_dsn[1]) case (mmr_even)
                4'h8: rom_mid <= mmr_din[15:8];
                default: ;
            endcase
            if (!mmr_dsn[0]) case (mmr_even | 4'h1)
                4'h9: rom_lo <= mmr_din[7:0];
                4'hb: rom_hi <= mmr_din[2:0];
                default: ;
            endcase
        end else if (!mmr_dsn[0]) begin
            case (mmr_addr)
                4'h8: rom_mid <= mmr_din[7:0];
                4'h9: rom_lo  <= mmr_din[7:0];
                4'hb: rom_hi  <= mmr_din[2:0];
                default: ;
            endcase
        end
    end
end
assign dma_addr  = lgtnfght ? {scn_addr[10:4],2'b00,scn_addr[3:1],1'b0} : scn_addr;

// Shadow understanding so far
// The 053251 color mixer lets shadow pass based on numerical priority only
// and independently of what layer is selected. As the object layer should not
// be drawn directly over a shadow, it looks like the logic must be like this
// - in the LUT the shadow bits are set for the whole sprite
// - when drawing the sprite, if the shadow is enabled and the sprite pen is
//   15 (bits 3:0 high), output the shadow bits but set the pen to 0 (transparent)
// - otherwise, output 0 for shadow bits and let the pen go through unaltered
// - Some bits in upper byte of register 2 are unknown in MAME and could be
//   related to selecting shadow pens
// 053244 (parodius) has 7 palette bits, top 2 used for priority
assign pen15   = &pre_pxl[3:0];
assign pen_eff = (pre_pxl[15:14]==0 || !pen15) ? pre_pxl[3:0] : 4'd0; // real color or 0 if shadow
assign shd     =  pre_pxl[14];
assign prio    =  {1'd1,pre_pxl[10:9],2'd0} ;
assign pxl     = gfx_en[3] ? {pre_pxl[8:4], pen_eff} : 9'd0;

jt053244 #(.HFLIP_OFFSET(HFLIP_OFFSET),.VFLIP_OFFSET(VFLIP_OFFSET),
    .DEBUG_FLICKER(DEBUG_FLICKER)
    )u_scan(    // sprite logic
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),

    // CPU interface
    .cs         ( reg_cs    ),
    .cpu_we     ( mmr_we    ),
    .cpu_addr   ( mmr_addr  ),
    .cpu_dout   ( mmr_din   ),
    .cpu_dsn    ( mmr_dsn   ),
    .rmrd_addr  ( rmrd_addr ),

    // External RAM
    .dma_addr   ( scn_addr  ), // up to 16 kB
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
    .st_addr    ( ioctl_ram ? ioctl_addr[7:0] : debug_bus ),
    .st_dout    ( dump_reg  )
);

jtframe_objdraw #(
    .SHADOW(SHADOW),.SHADOW_PEN(SHADOW_PEN),.SW(2),
    .AW(10),.CW(16),.PW(4+10+2),.LATCH(1),.SWAPH(1),
    .ZW(12),.ZI(6),.ZENLARGE(1),
    .FLIP_OFFSET(9'h12),.KEEP_OLD(0)
) u_draw(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .hs         ( hs            ),
    .flip       ( 1'b0          ),
    .hdump      ( {1'b0,hdump}  ),

    .draw       ( dr_start      ),
    .busy       ( dr_busy       ),
    .code       ( code          ),
    .xpos       ( hpos          ),
    .ysub       ( ysub          ),
    .hz_keep    ( hz_keep       ),
    .hzoom      ( hzoom         ),

    .hflip      ( ~hflip        ),
    .vflip      ( vflip         ),
    .pal        ({1'b0,pre_shd, 3'b0, attr}),

    .rom_addr   ( pre_addr      ),
    .rom_cs     ( pre_cs        ),
    .rom_ok     ( rom_ok        ),
    .rom_data   ( rom_data      ),

    .pxl        ( pre_pxl       )
);

jtframe_dual_nvram16 #(
    .AW     ( RAMW    ),
    .SIMFILE("obj.bin")
) u_ram( // 8 or 16kB? check PCB. Game seems to work on 8kB ok
    // Port 0 - CPU access
    .clk0   ( clk       ),
    .data0  ( ram_din   ),
    .addr0  ( ram_addr  ),
    .we0    ( ram_we & {2{ram_cs}} ),
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
