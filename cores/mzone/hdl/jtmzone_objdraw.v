// SPDX-License-Identifier: GPL-3.0-or-later

// PCB object ROM organization and core packing: doc/timing.md, "PCB object hardware".
module jtmzone_objdraw(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               cen2,

    input               HS,
    input        [ 8:0] hdump,
    input               flip,

    input               draw,
    output reg          busy,

    input        [ 7:0] code,
    input        [ 8:0] xpos,
    input        [ 3:0] pal,
    input               hflip,
    input        [ 3:0] ysub,

    input        [ 3:0] prog_data,
    input        [ 7:0] prog_addr,
    input               prog_en,

    output reg   [12:0] rom_addr,
    output reg          rom_cs,
    input        [31:0] rom_data,
    input               rom_ok,

    output       [ 3:0] pxl
);

// Raw hdump positions used as hread=0 in each orientation.
localparam [8:0] HOFFSET      = 9'd54;
localparam [8:0] HOFFSET_FLIP = 9'd6;
// Circular line-buffer starting addresses, before read-latency compensation.
localparam [7:0] PCB_RD_ORIGIN      = 8'd9;
localparam [7:0] PCB_RD_ORIGIN_FLIP = 8'd16;
// Request one address ahead to compensate for the synchronous read path.
localparam [7:0] RAM_RD_PHASE  = 8'd1;

reg [ 1:0] dr_st;
reg [31:0] pxl_data;
reg [ 2:0] cnt;
reg [ 3:0] cur_pal;
reg        cur_hflip;
reg [ 7:0] buf_a;
reg        buf_we;
reg  [7:0] buf_al;
reg        buf_wel;
wire [ 3:0] draw_pal_pxl;
wire [ 3:0] pal_pxl;
wire [31:0] decoded_rom_data = {
    {rom_data[24],rom_data[28],rom_data[16],rom_data[20]}, // pixel 7
    {rom_data[25],rom_data[29],rom_data[17],rom_data[21]}, // pixel 6
    {rom_data[26],rom_data[30],rom_data[18],rom_data[22]}, // pixel 5
    {rom_data[27],rom_data[31],rom_data[19],rom_data[23]}, // pixel 4
    {rom_data[ 8],rom_data[12],rom_data[ 0],rom_data[ 4]}, // pixel 3
    {rom_data[ 9],rom_data[13],rom_data[ 1],rom_data[ 5]}, // pixel 2
    {rom_data[10],rom_data[14],rom_data[ 2],rom_data[ 6]}, // pixel 1
    {rom_data[11],rom_data[15],rom_data[ 3],rom_data[ 7]}  // pixel 0
};
wire [3:0] draw_pen = pxl_data[3:0];
// Switch banks on the leading edge of HS, during horizontal blank.  The
// object buffer switches on a falling LHBL input, hence the inversion.
wire       obj_buf_lhbl = ~HS;
// Position the object read sequence relative to raw horizontal timing.
wire [8:0] hoffset = flip ? HOFFSET_FLIP : HOFFSET;
wire [8:0] hread = hdump - hoffset;
// Enable reads at hread=-2,-1 and 0..239. The two early reads prime
// the synchronous read pipeline; output drains after the last request.
wire       buf_rd = pxl_cen && (hread>=9'd510 || hread<9'd240);
// Select the circular buffer origin for each orientation, then advance
// the request address by RAM_RD_PHASE to compensate for read latency.
// Eight-bit arithmetic wraps the address modulo 256.
wire [7:0] buf_rd_origin = flip ? PCB_RD_ORIGIN_FLIP : PCB_RD_ORIGIN;
wire [7:0] buf_rd_addr = hread[7:0] + buf_rd_origin + RAM_RD_PHASE;

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
        busy     <= 1'b0;
        rom_cs   <= 1'b0;
        rom_addr <= 13'd0;
        dr_st    <= 2'd0;
        cnt      <= 3'd0;
        pxl_data <= 32'd0;
        buf_a    <= 8'd0;
        buf_we   <= 1'b0;
    end else begin
        if( cen2 ) case( dr_st )
            2'd0: if( draw && !busy ) begin
                cur_pal       <= pal;
                cur_hflip     <= hflip;
                buf_a         <= xpos[7:0] + (hflip ? 8'd15 : 8'd0);
                rom_addr      <= { code, ysub[3], 1'b0, ysub[2:0] };
                rom_cs        <= 1'b1;
                busy          <= 1'b1;
                dr_st         <= 2'd1;
            end
            2'd1: if( rom_cs && rom_ok ) begin
                pxl_data   <= decoded_rom_data;
                rom_cs     <= 1'b0;
                cnt         <= 3'd7;
                buf_we      <= 1'b1;
                dr_st      <= 2'd2;
            end
            2'd2: begin
                pxl_data <= pxl_data >> 4;
                buf_a    <= cur_hflip ? buf_a-8'd1 : buf_a+8'd1;
                cnt      <= cnt-3'd1;
                if( cnt==0 ) begin
                    if( rom_addr[3] ) begin
                        busy  <= 1'b0;
                        buf_we <= 1'b0;
                        dr_st <= 2'd0;
                    end else begin
                        rom_addr[3] <= 1'b1;
                        rom_cs <= 1'b1;
                        dr_st <= 2'd1;
                    end
                end
            end
            default: begin
                dr_st <= 2'd0;
            end
        endcase
    end
end

jtframe_obj_buffer #(
    .AW         ( 8  ),
    .DW         ( 4  ),
    .ALPHA      ( 0  ),
    .BLANK      ( 0  )
) u_line(
    .clk    ( clk          ),
    .LHBL   ( obj_buf_lhbl ),
    .flip   ( 1'b0         ),
    .wr_data( draw_pal_pxl ),
    .wr_addr( buf_al        ),
    .we     ( buf_wel       ),
    .rd_addr( buf_rd_addr   ),
    .rd     ( buf_rd       ),
    .rd_data( pal_pxl )
);

assign pxl = pal_pxl;

jtframe_prom #(
    .DW     ( 4 ),
    .AW     ( 8 )
) u_palette(
    .clk    ( clk                    ),
    .cen    ( 1'b1                   ),
    .data   ( prog_data              ),
    .wr_addr( prog_addr              ),
    .we     ( prog_en                ),
    .rd_addr( { cur_pal, draw_pen } ),
    .q      ( draw_pal_pxl          )
);

endmodule
