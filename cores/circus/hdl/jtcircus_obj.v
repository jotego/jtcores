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
    Date: 23-8-2024 */

// The 64kB frame buffer in the original is
// replaced by an equivalent circuit:
// - 256B LUT buffer
// - 256B dual line buffer

module jtcircus_obj(
    input               rst,
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,

    // CPU interface
    input         [9:0] cpu_addr,
    input         [7:0] cpu_dout,
    input               objram_cs,
    input               cpu_rnw,
    output        [7:0] obj_dout,

    // video inputs
    input               obj_frame,
    input               hs,
    input               LHBL,
    input               LVBL,
    input         [7:0] vrender,
    input         [8:0] hdump,
    input               flip,

    // PROMs
    input         [3:0] prog_data,
    input         [7:0] prog_addr,
    input               prog_en,

    // SDRAM
    output       [15:2] rom_addr,
    input        [31:0] rom_data,
    output              rom_cs,
    input               rom_ok,

    output        [3:0] pxl,
    input         [7:0] debug_bus
);

parameter [7:0] HOFFSET = 0;
parameter REV_SCAN = 0;

localparam FIX = 9'h2d, FIXF = 9'hde;

wire [ 7:0] dma_din, scan_dout;
wire        obj_we, obj_bl;
reg  [ 7:0] scan_addr=0;
reg         dma_we, dma_done;
wire [ 9:0] eff_dma;
reg  [ 7:0] dma_addr;
wire [ 3:0] pal_data, pre_pxl, pxl_dly;

assign obj_we  = objram_cs & ~cpu_rnw;
assign eff_dma = {1'b0,obj_frame,dma_addr};
assign pxl     = obj_bl ? 4'd0 : flip ? pre_pxl : pxl_dly;
assign obj_bl  = flip ? hdump>=FIXF : hdump <= FIX;
jtframe_sh #(.W(4),.L(5)) u_sh(
    .clk    ( clk       ),
    .clk_en ( pxl_cen   ),
    .din    ( pre_pxl   ),
    .drop   ( pxl_dly   )
);

jtframe_dual_ram u_hi(
    // Port 0, CPU
    .clk0   ( clk24      ),
    .data0  ( cpu_dout   ),
    .addr0  ( cpu_addr   ),
    .we0    ( obj_we     ),
    .q0     ( obj_dout   ),
    // Port 1
    .clk1   ( clk        ),
    .data1  (            ),
    .addr1  ( eff_dma    ),
    .we1    ( 1'b0       ),
    .q1     ( dma_din    )
);

// LUT frame buffer and DMA
jtframe_dual_ram #(.AW(8)) u_fb(
    // Port 0, DMA
    .clk0   ( clk           ),
    .data0  ( dma_din       ),
    .addr0  ( dma_addr      ),
    .we0    ( dma_we        ),
    .q0     (               ),
    // Port 1, drawing
    .clk1   ( clk           ),
    .data1  (               ),
    .addr1  ( scan_addr     ),
    .we1    ( 1'b0          ),
    .q1     ( scan_dout     )
);

always @(posedge clk) begin
    if(!LVBL) begin
        dma_done <= 0;
        dma_addr <= 0;
        dma_we   <= 0;
    end
    if( LVBL && !dma_done && pxl_cen ) begin
        dma_we <= 1;
        if( dma_we ) dma_addr <= dma_addr+8'd1;
        if( &dma_addr ) begin
            dma_done <= 1;
            dma_we   <= 0;
        end
    end
end

// Table scan
reg        cen2, hs_l;
reg  [1:0] scan_st;
reg  [8:0] dr_code;
reg  [7:0] dr_xpos;
reg  [3:0] dr_pal, dr_v;
reg        dr_hflip, dr_vflip, dr_start, done;
wire [7:0] vrf, ydiff, nx_addr, dr_y;
wire [8:0] hdumpf;
wire       inzone, hinit, dr_busy;

assign vrf     = vrender^{8{flip}};
assign inzone  = dr_y>=vrf && dr_y<(vrf+8'h10);
assign dr_y    = scan_dout+8'hf;
assign ydiff   = vrf-dr_y-8'd1;
assign nx_addr = scan_addr+8'd1;
assign hinit   = !hs && hs_l;
assign hdumpf  = { hdump[8], (hdump[7:0]^{8{flip}})+(flip?8'h7:8'h0) };

always @(posedge clk) begin
    cen2 <= ~cen2;
    if(cen2) hs_l <= hs;
end

always @(posedge clk) if(cen2) begin
    case( scan_st )
        0: begin
            dr_start <= 0;
            if(!dr_busy && !dr_start) begin
                dr_code[7:0] <= scan_dout;
                scan_addr    <= nx_addr;
                if(!done) scan_st <= 1;
            end
        end
        1: begin
            scan_st    <= 2;
            dr_vflip   <= scan_dout[7];
            dr_hflip   <= scan_dout[6];
            dr_code[8] <= scan_dout[5];
            dr_pal     <= scan_dout[3:0];
            scan_addr  <= nx_addr;
        end
        2: begin
            scan_st   <= 3;
            dr_xpos   <= scan_dout;
            scan_addr <= nx_addr;
        end
        3: begin
            dr_v      <= ydiff[3:0];
            scan_addr <= nx_addr;
            dr_start  <= inzone;
            scan_st   <= 0;
            done      <= &scan_addr[7:2];
        end
    endcase
    if( hinit ) begin
        scan_st   <= 0;
        scan_addr <= 0;
        dr_start  <= 0;
        done      <= 0;
    end
end

jtkicker_objdraw #(
    .HOFFSET    ( HOFFSET   ),
    .PACKED     ( 2         )
) u_draw (
    .rst        ( rst       ),
    .clk        ( clk       ),        // 48 MHz

    .pxl_cen    ( pxl_cen   ),
    .cen2       ( cen2      ),
    // video inputs
    .LHBL       ( LHBL      ),
    .hinit_x    ( hinit     ),
    .hdump      ( hdumpf    ),

    // control
    .draw       ( dr_start  ),
    .busy       ( dr_busy   ),

    // Object table data
    .code       ( dr_code   ),
    .xpos       ( dr_xpos   ),
    .pal        ( dr_pal    ),
    .hflip      ( dr_hflip  ),
    .vflip      ( dr_vflip  ),
    .ysub       ( dr_v      ),

    // PROMs
    .prog_data  ( prog_data ),
    .prog_addr  ( prog_addr ),
    .prog_en    ( prog_en   ),

    // SDRAM
    .rom_cs     ( rom_cs    ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( rom_data  ),
    .rom_ok     ( rom_ok    ),

    .pxl        ( pre_pxl   ),
    .debug_bus  ( debug_bus )
);

endmodule