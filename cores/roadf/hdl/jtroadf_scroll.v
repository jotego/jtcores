/*  This file is part of JTKICKER.
    JTKICKER program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKICKER program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKICKER.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 14-11-2021 */

module jtroadf_scroll(
    input               rst,
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,

    // CPU interface
    input        [11:0] cpu_addr,
    input         [7:0] cpu_dout,
    input               cpu_rnw,
    input               vram_cs,
    output        [7:0] vram_dout,

    // Row scroll
    input         [7:0] scr_din,
    input               scr_we,

    // video inputs
    input               LHBL,
    input         [7:0] vdump,
    input         [8:0] hdump,
    input               flip,
    input               is_hyper,

    // PROMs
    input         [3:0] prog_data,
    input         [7:0] prog_addr,
    input               prog_en,

    // SDRAM
    output reg   [13:0] rom_addr,
    input        [31:0] rom_data,
    input               rom_ok,

    output        [3:0] pxl,
    input         [7:0] debug_bus,
    input               ioctl_ram,
    output       [ 7:0] ioctl_din,
    input        [15:0] ioctl_addr
);

wire [ 7:0] code, attr, vram_high, vram_low, pal_addr;
reg  [ 3:0] pal_msb;
reg  [ 3:0] cur_pal;
reg  [ 2:0] code_msb;
reg  [31:0] pxl_data;
reg  [10:0] rd_addr;
reg  [ 7:0] hpos, vf;
reg  [ 8:0] hsum, heff;
reg         cur_hf;
wire        vram_we_low, vram_we_high;
reg         vflip, hflip;
wire        vram_we;
wire [10:0] eff_addr;

assign vram_we      = vram_cs & ~cpu_rnw;
assign vram_we_low  = vram_we & ~cpu_addr[11];
assign vram_we_high = vram_we &  cpu_addr[11];
assign vram_dout    = cpu_addr[11] ? vram_high : vram_low;
assign eff_addr     = cpu_addr[10:0];
assign ioctl_din    = ioctl_addr[11] ? attr : code;

always @* begin
    // These are chips D6, D7, C5 and B7 in the video board sch.
    hsum = {hpos[7:1],2'd0} + ( LHBL ? hdump : { ~6'h0, hdump[2:0]} ) + 9'd8 - {8'd0,flip};
    heff = hsum ^ {1'b0,{8{flip}}};
    code_msb = is_hyper ?
        { attr[6], 1'b0, attr[7] } : // jumper JP1 video board
        { attr[6:5],     attr[7] };
    vflip    = 0; // is_hyper & attr[5]; // MAME uses this, but I don't see it in the schematics
end


assign pal_addr =
    { cur_pal, cur_hf ? pxl_data[3:0] : pxl_data[31:28] };

// scroll register in custom chip 085
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hpos <= 0;
        vf   <= 0;
    end else begin
        if( pxl_cen && heff[2:0]==7 ) begin
            rd_addr <= { vf[7:3], heff[8:3] }; // 5+6 = 11
        end
        if( scr_we  ) hpos <= scr_din;
        vf <= {8{flip}} ^ vdump;
    end
end

always @(posedge clk) if(pxl_cen) begin
    if( heff[2:0]==0 ) begin
        rom_addr <= { code_msb, code, vf[2:0]^{3{vflip}} }; // 3+8+3=14 bits
        pal_msb  <= attr[3:0];
        hflip    <= attr[4]^flip;
    end
    if( heff[2:0]==4 ) begin // 2 pixel delay to grab data
        pxl_data <= {
            rom_data[27], rom_data[31], rom_data[19], rom_data[23],
            rom_data[26], rom_data[30], rom_data[18], rom_data[22],
            rom_data[25], rom_data[29], rom_data[17], rom_data[21],
            rom_data[24], rom_data[28], rom_data[16], rom_data[20],
            rom_data[11], rom_data[15], rom_data[ 3], rom_data[ 7],
            rom_data[10], rom_data[14], rom_data[ 2], rom_data[ 6],
            rom_data[ 9], rom_data[13], rom_data[ 1], rom_data[ 5],
            rom_data[ 8], rom_data[12], rom_data[ 0], rom_data[ 4]
        };
        cur_hf   <= hflip;
        cur_pal  <= pal_msb;
    end else begin
        pxl_data <= cur_hf ? pxl_data>>4 : pxl_data<<4;
    end
end

wire [10:0] dmp_addr = ioctl_ram ? ioctl_addr[10:0] : rd_addr;

jtframe_dual_ram #(.simfile("vram_lo.bin"),.aw(11)) u_low(
    // Port 0, CPU
    .clk0   ( clk24         ),
    .data0  ( cpu_dout      ),
    .addr0  ( eff_addr      ),
    .we0    ( vram_we_low   ),
    .q0     ( vram_low      ),
    // Port 1
    .clk1   ( clk           ),
    .data1  (               ),
    .addr1  ( dmp_addr      ),
    .we1    ( 1'b0          ),
    .q1     ( code          )
);

jtframe_dual_ram #(.simfile("vram_hi.bin"),.aw(11)) u_high(
    // Port 0, CPU
    .clk0   ( clk24         ),
    .data0  ( cpu_dout      ),
    .addr0  ( eff_addr      ),
    .we0    ( vram_we_high  ),
    .q0     ( vram_high     ),
    // Port 1
    .clk1   ( clk           ),
    .data1  (               ),
    .addr1  ( dmp_addr      ),
    .we1    ( 1'b0          ),
    .q1     ( attr          )
);

jtframe_prom #(
    .dw ( 4     ),
    .aw ( 8     )
//    simfile = "477j09.b8",
) u_palette(
    .clk    ( clk       ),
    .cen    ( pxl_cen   ),
    .data   ( prog_data ),
    .wr_addr( prog_addr ),
    .we     ( prog_en   ),

    .rd_addr( pal_addr  ),
    .q      ( pxl       )
);

endmodule