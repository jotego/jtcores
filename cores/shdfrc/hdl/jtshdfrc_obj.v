/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-11-2026 */

module jtshdfrc_obj(
    input                rst,
    input                clk,
    input                line_start,
    input                line_wrap,
    input                pxl_cen,
    input         [ 8:0] vcnt,
    input         [ 8:0] rline,
    input         [ 8:0] hcnt,

    output reg    [12:1] spr_rd_addr,
    input         [15:0] spr_rd_data,
    output reg           spr_copy_busy,
    input                spr_copy_ok,

    output        [22:2] obj_addr,
    output               obj_cs,
    input                obj_ok,
    input         [31:0] obj_data,
    output        [20:1] obj4_addr,
    output               obj4_cs,
    input                obj4_ok,
    input         [15:0] obj4_data,

    output        [10:0] lobj
);

wire [ 8:0] ob_x;
wire [10:0] ob_wd;
wire        ob_we;

jtframe_obj_buffer #(
    .DW        ( 11 ),
    .AW        ( 9  ),
    .ALPHAW    ( 5  ),
    .ALPHA     ( 0  ),
    .BLANK_DLY ( 3  ),
    .LATCH_RD  ( 0  )
) u_lbobj(
    .clk     ( clk        ),
    .LHBL    ( ~line_wrap ),
    .flip    ( 1'b0       ),
    .wr_data ( ob_wd      ),
    .wr_addr ( ob_x       ),
    .we      ( ob_we      ),
    .rd_addr ( hcnt       ),
    .rd      ( pxl_cen    ),
    .rd_data ( lobj       )
);

reg  [47:0] sbuf_wd;
reg  [8:0]  sbuf_wa;
reg         sbuf_we;
reg  [8:0]  sbuf_ra;
wire [47:0] sbuf_q;
reg  [39:0] cacc;

jtframe_rpwp_ram #(
    .DW ( 48 ),
    .AW ( 9  )
) u_sprbuf(
    .clk     ( clk     ),
    .rd_addr ( sbuf_ra ),
    .dout    ( sbuf_q  ),
    .wr_addr ( sbuf_wa ),
    .din     ( sbuf_wd ),
    .we      ( sbuf_we )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        spr_copy_busy <= 0; spr_rd_addr <= 0; sbuf_we <= 0;
    end else begin
        sbuf_we <= 0;
        if( !spr_copy_busy ) begin
            if( line_start && vcnt==9'd248 ) begin
                spr_copy_busy <= 1;
                spr_rd_addr <= 0;
            end
        end else if( spr_copy_ok ) begin
            if( spr_rd_addr[3:1]==3'd5 ) begin
                sbuf_wa <= spr_rd_addr[12:4];
                sbuf_wd <= { spr_rd_data[7:0], cacc };
                sbuf_we <= 1;
                spr_rd_addr <= { spr_rd_addr[12:4]+9'd1, 3'd0 };
                if( &spr_rd_addr[12:4] ) spr_copy_busy <= 0;
            end else begin
                cacc <= { spr_rd_data[7:0], cacc[39:8] };
                spr_rd_addr[3:1] <= spr_rd_addr[3:1] + 3'd1;
            end
        end
    end
end

localparam OF_D = 8;
reg  [10:0] line_origin;
reg         sev;
reg         scan_on;
reg  [35:0] ofifo [0:OF_D-1];
reg  [2:0]  ofr, ofw;
reg  [3:0]  ofn;

wire [7:0]  s0 = sbuf_q[ 7: 0], s1 = sbuf_q[15: 8], s2 = sbuf_q[23:16],
            s3 = sbuf_q[31:24], s4 = sbuf_q[39:32], s5 = sbuf_q[47:40];
wire [10:0] distance = line_origin - { 1'b0, s0[1:0], s1 };
wire        y_wrap   = distance[10] == distance[9];
wire        shit     = s0[2] && y_wrap && distance[8:7]==0 && distance[6:4]<=s0[7:5];
wire [15:0] scode    = { s2, s3 } + { 13'd0, distance[6:4] };
wire [3:0]  srow     = s0[3] ? distance[3:0] : ~distance[3:0];
wire [8:0]  sx9    = { s4[0], s5 } + 9'd1;

wire [35:0] shitw  = { scode, srow, s0[4], s4[6], s4[5:1], sx9 };
wire        opush  = sev && shit;
reg         opop;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scan_on <= 0; sev <= 0; sbuf_ra <= 0; ofr <= 0; ofw <= 0; ofn <= 0;
    end else begin

        sev <= 0;
        if( line_start && !spr_copy_busy && vcnt!=9'd248 ) begin
            scan_on <= 1;
            sbuf_ra <= 0;
        end else if( scan_on && ofn < OF_D-2 ) begin
            if( sbuf_ra==0 ) line_origin <= 11'd255 - { 2'd0, rline };
            sev     <= 1;
            sbuf_ra <= sbuf_ra + 9'd1;
            if( &sbuf_ra ) scan_on <= 0;
        end

        if( opush ) begin ofifo[ofw] <= shitw; ofw <= ofw + 3'd1; end
        if( opop  ) ofr <= ofr + 3'd1;
        if( opush != opop ) ofn <= ofn + (opush ? 4'd1 : 4'hf);
    end
end

reg  [35:0] draw_entry;
wire [35:0] fifo_head = ofifo[ofr];
wire        draw_busy, draw_rom_cs, draw_rom_ok;
wire [22:2] draw_rom_addr;
wire [39:0] draw_rom_data;
wire [ 7:0] plane0 = obj_addr[2] ? obj4_data[15:8] : obj4_data[7:0];
reg         prefetch;
wire        prefetch_cs = prefetch && !draw_rom_cs;
// Keep the ROM address stable when the prefetched entry leaves the FIFO.
wire [35:0] next_entry = opop ? draw_entry : fifo_head;
reg         rom_cs_l, rom_half_l, rom_settling;
wire        rom_new = obj_cs && (!rom_cs_l || obj_addr[6]!=rom_half_l);

assign obj_addr    = prefetch_cs ? { next_entry[35:20], next_entry[15], next_entry[19:16] } : draw_rom_addr;
assign obj_cs      = draw_rom_cs || prefetch_cs;
assign obj4_addr   = obj_addr[22:3];
assign obj4_cs     = obj_cs;
assign draw_rom_ok = !rom_new && !rom_settling && obj_ok && obj4_ok;

genvar pixel;
generate
    for( pixel=0; pixel<8; pixel=pixel+1 ) begin : gen_planes
        assign draw_rom_data[pixel   ] = plane0  [ 7-pixel];
        assign draw_rom_data[pixel+ 8] = obj_data[31-pixel];
        assign draw_rom_data[pixel+16] = obj_data[23-pixel];
        assign draw_rom_data[pixel+24] = obj_data[15-pixel];
        assign draw_rom_data[pixel+32] = obj_data[ 7-pixel];
    end
endgenerate

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        opop <= 0;
        prefetch <= 0;
        rom_cs_l <= 0;
        rom_half_l <= 0;
        rom_settling <= 0;
    end else begin
        opop <= 0;
        if( !draw_busy && !opop && ofn!=0 ) begin
            draw_entry <= fifo_head;
            opop <= 1;
        end
        if( draw_rom_cs ) prefetch <= 0;
        else if( draw_busy && ofn!=0 ) prefetch <= 1;
        rom_cs_l     <= obj_cs;
        rom_half_l   <= obj_addr[6];
        rom_settling <= rom_new;
    end
end

jtframe_draw #(
    .AW  ( 9  ),
    .CW  ( 16 ),
    .PW  ( 11 ),
    .BPP ( 5  )
) u_draw(
    .rst      ( rst               ),
    .clk      ( clk               ),
    .draw     ( opop              ),
    .busy     ( draw_busy         ),
    .code     ( draw_entry[35:20] ),
    .xpos     ( draw_entry[ 8: 0] ),
    .ysub     ( draw_entry[19:16] ),
    .trunc    ( 2'd0              ),
    .hzoom    ( 6'd0              ),
    .hz_keep  ( 1'b0              ),
    .hflip    ( draw_entry[15]    ),
    .vflip    ( 1'b0              ),
    .pal      ( draw_entry[14: 9] ),
    .rom_addr ( draw_rom_addr     ),
    .rom_cs   ( draw_rom_cs       ),
    .rom_ok   ( draw_rom_ok       ),
    .rom_data ( draw_rom_data     ),
    .buf_addr ( ob_x              ),
    .buf_we   ( ob_we             ),
    .buf_din  ( ob_wd             )
);

endmodule
