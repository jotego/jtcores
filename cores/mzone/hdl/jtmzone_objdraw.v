/* SPDX-FileCopyrightText: 2026 Ulf Skutnabba
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-10-2026 */

// JTFRAME helper comparison and retained PCB timing: doc/renderers.md.

// PCB object ROM organization and core packing: doc/timing.md, "PCB object hardware".
module jtmzone_objdraw(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              HS,
    input      [ 8:0]  hdump,
    input              flip,

    input              draw,
    output             busy,

    input      [ 7:0]  code,
    input      [ 8:0]  xpos,
    input      [ 3:0]  pal,
    input              hflip,
    input      [ 3:0]  ysub,

    input      [ 3:0]  prog_data,
    input      [ 7:0]  prog_addr,
    input              prog_en,

    output     [12:0]  rom_addr,
    output             rom_cs,
    input      [31:0]  rom_data,
    input              rom_ok,

    output     [ 3:0]  pxl
);

// Raw hdump positions used as hread=0 in each orientation.
localparam [ 8:0]  HOFFSET      = 9'd54;
localparam [ 8:0]  HOFFSET_FLIP = 9'd6;
// Circular line-buffer starting addresses, before read-latency compensation.
localparam [ 7:0]  PCB_RD_ORIGIN      = 8'd9;
localparam [ 7:0]  PCB_RD_ORIGIN_FLIP = 8'd16;
// Request one address ahead to compensate for the synchronous read path.
localparam [ 7:0]  RAM_RD_PHASE  = 8'd1;

reg  [ 3:0]  cur_pal;
reg          cur_hflip;
reg  [ 7:0]  start_x,buf_al;
reg          buf_wel;
wire [ 7:0]  buf_addr,buf_pred;
wire         buf_we;
wire [14:2]  draw_addr;
wire [ 3:0]  draw_pal_pxl,pal_pxl;
wire [31:0]  rom_sorted;
wire [ 7:0]  buf_a=cur_hflip?(start_x<<1)+8'd15-buf_addr:buf_addr;
// Switch banks on the leading edge of HS, during horizontal blank.  The
// object buffer switches on a falling LHBL input, hence the inversion.
wire         obj_buf_lhbl = ~HS;
// Position the object read sequence relative to raw horizontal timing.
wire [ 8:0]  hoffset = flip ? HOFFSET_FLIP : HOFFSET;
wire [ 8:0]  hread = hdump - hoffset;
// Enable reads at hread=-2,-1 and 0..239. The two early reads prime
// the synchronous read pipeline; output drains after the last request.
wire         buf_rd = pxl_cen && (hread>=9'd510 || hread<9'd240);
// Select the circular buffer origin for each orientation, then advance
// the request address by RAM_RD_PHASE to compensate for read latency.
// Eight-bit arithmetic wraps the address modulo 256.
wire [ 7:0]  buf_rd_origin = flip ? PCB_RD_ORIGIN_FLIP : PCB_RD_ORIGIN;
wire [ 7:0]  buf_rd_addr = hread[7:0] + buf_rd_origin + RAM_RD_PHASE;

// The PCB orders the row MSB before the horizontal half, followed by
// the three row LSBs. The helper exposes {code, half, row}.
assign rom_addr = {draw_addr[14:7],draw_addr[5],draw_addr[6],draw_addr[4:2]};
assign pxl = pal_pxl;

// Convert paired-plane groups into the helper's plane-per-byte format.
assign rom_sorted[ 7: 0] = {rom_data[20],rom_data[21],rom_data[22],rom_data[23],
                        rom_data[ 4],rom_data[ 5],rom_data[ 6],rom_data[ 7]};
assign rom_sorted[15: 8] = {rom_data[16],rom_data[17],rom_data[18],rom_data[19],
                        rom_data[ 0],rom_data[ 1],rom_data[ 2],rom_data[ 3]};
assign rom_sorted[23:16] = {rom_data[28],rom_data[29],rom_data[30],rom_data[31],
                        rom_data[12],rom_data[13],rom_data[14],rom_data[15]};
assign rom_sorted[31:24] = {rom_data[24],rom_data[25],rom_data[26],rom_data[27],
                        rom_data[ 8],rom_data[ 9],rom_data[10],rom_data[11]};

// The synchronous object PROM produces its result one master clock after
// {palette,pen}; delay the line-buffer write address and enable by the same clock.
always @(posedge clk) begin
    if( rst ) begin
        buf_al  <= 8'd0;
        buf_wel <= 1'b0;
    end else begin
        buf_al  <= buf_a;
        buf_wel <= buf_we;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        cur_pal   <= 4'd0;
        cur_hflip <= 1'b0;
        start_x   <= 8'd0;
    end else if( draw && !busy ) begin
        cur_pal   <= pal;
        cur_hflip <= hflip;
        start_x   <= xpos[7:0];
    end
end
jtframe_draw #(.AW(8),.CW(8),.PW(8)) u_draw(
    .rst             ( rst                                  ),
    .clk             ( clk                                  ),
    .draw            ( draw                                 ),
    .busy            ( busy                                 ),
    .code            ( code                                 ),
    .xpos            ( xpos[7:0]                            ),
    .ysub            ( ysub                                 ),
    .trunc           ( 2'd0                                 ),
    .hzoom           ( 6'd0                                 ),
    .hz_keep         ( 1'b0                                 ),
    .hflip           ( 1'b0                                 ),
    .vflip           ( 1'b0                                 ),
    .pal             ( pal                                  ),
    .rom_addr        ( draw_addr                            ),
    .rom_cs          ( rom_cs                               ),
    .rom_ok          ( rom_ok                               ),
    .rom_data        ( rom_sorted                           ),
    .buf_addr        ( buf_addr                             ),
    .buf_we          ( buf_we                               ),
    .buf_din         ( buf_pred                             )
);

jtframe_obj_buffer #(
    .AW              ( 8                                    ),
    .DW              ( 4                                    ),
    .ALPHA           ( 0                                    ),
    .BLANK           ( 0                                    )
) u_line(
    .clk             ( clk                                  ),
    .LHBL            ( obj_buf_lhbl                         ),
    .flip            ( 1'b0                                 ),
    .wr_data         ( draw_pal_pxl                         ),
    .wr_addr         ( buf_al                               ),
    .we              ( buf_wel                              ),
    .rd_addr         ( buf_rd_addr                          ),
    .rd              ( buf_rd                               ),
    .rd_data         ( pal_pxl                              )
);

jtframe_prom #(
    .DW              ( 4                                    ),
    .AW              ( 8                                    )
) u_palette(
    .clk             ( clk                                  ),
    .cen             ( 1'b1                                 ),
    .data            ( prog_data                            ),
    .wr_addr         ( prog_addr                            ),
    .we              ( prog_en                              ),
    .rd_addr         ( { cur_pal, buf_pred[3:0] }           ),
    .q               ( draw_pal_pxl                         )
);

endmodule
