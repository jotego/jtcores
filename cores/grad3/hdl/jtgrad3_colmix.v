/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jtgrad3_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             prio,
    input      [ 1:0] obj_pri,

    input             lhbl,
    input             lvbl,

    input      [12:1] cpu_addr,
    input      [15:0] cpu_dout,
    input      [ 1:0] cpu_dsn,
    input             cpu_we,
    input             pal_cs,
    output     [15:0] cpu_din,

    input             lyrf_blnk_n,
    input             lyra_blnk_n,
    input             lyrb_blnk_n,
    input             lyro_blnk_n,
    input      [ 7:0] lyrf_pxl,
    input      [11:0] lyra_pxl,
    input      [11:0] lyrb_pxl,
    input      [11:0] lyro_pxl,
    input             shadow,

    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,

    input      [11:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din,
    input      [ 7:0] debug_bus
);

wire [15:0] pal_dout;
wire [10:0] pal_addr;
wire [ 1:0] pal_we;
reg  [10:0] pxl;
reg  [10:0] tile_pxl;
reg  [ 2:0] tile_pri, obj_mask;
reg  [23:0] bgr;
reg         shl;

assign pal_we    = {2{cpu_we & pal_cs}} & ~cpu_dsn;
assign pal_addr  = pxl;
assign ioctl_din = ioctl_addr[0] ? pal_dout[15:8] : pal_dout[7:0];
assign { blue, green, red } = (lvbl & lhbl) ? bgr : 24'd0;

function [10:0] fix_addr( input [7:0] p );
    fix_addr = { 4'd0, p[7:5], p[3:0] };
endfunction

function [10:0] a_addr( input [11:0] p );
    a_addr = 11'd512 + { 4'd0, p[7:5], p[3:0] };
endfunction

function [10:0] b_addr( input [11:0] p );
    b_addr = 11'd768 + { 4'd0, p[7:5], p[3:0] };
endfunction

function [10:0] obj_addr( input [11:0] p );
    obj_addr = { 2'b00, p[8:4], p[3:0] };
endfunction

function [2:0] obj_prio_mask( input prio_mode, input [1:0] pri );
    if( prio_mode ) begin
        case( pri )
            2'd0: obj_prio_mask = 3'b110;
            2'd1: obj_prio_mask = 3'b100;
            2'd2: obj_prio_mask = 3'b000;
            2'd3: obj_prio_mask = 3'b111;
        endcase
    end else begin
        case( pri )
            2'd0: obj_prio_mask = 3'b101;
            2'd1: obj_prio_mask = 3'b001;
            2'd2: obj_prio_mask = 3'b101;
            2'd3: obj_prio_mask = 3'b111;
        endcase
    end
endfunction

function [7:0] dim50( input [7:0] d );
    dim50 = {1'b0, d[7:1]};
endfunction

function [23:0] rgb555( input [14:0] cin, input shade );
    rgb555 = !shade ? {
        cin[ 4: 0], cin[ 4: 2],
        cin[ 9: 5], cin[ 9: 7],
        cin[14:10], cin[14:12] } :
        { dim50({cin[ 4: 0], cin[ 4: 2]}),
          dim50({cin[ 9: 5], cin[ 9: 7]}),
          dim50({cin[14:10], cin[14:12]}) };
endfunction

always @* begin
    tile_pxl = 0;
    tile_pri = 0;
    obj_mask = obj_prio_mask( prio, obj_pri );
    if( prio ) begin
        tile_pxl = fix_addr( lyrf_pxl );
        tile_pri = 3'b001;
        if( lyra_blnk_n ) begin
            tile_pxl = a_addr( lyra_pxl );
            tile_pri = 3'b010;
        end
        if( lyrb_blnk_n ) begin
            tile_pxl = b_addr( lyrb_pxl );
            tile_pri = 3'b100;
        end
    end else begin
        tile_pxl = a_addr( lyra_pxl );
        tile_pri = 3'b010;
        if( lyrb_blnk_n ) begin
            tile_pxl = b_addr( lyrb_pxl );
            tile_pri = 3'b100;
        end
        if( lyrf_blnk_n ) begin
            tile_pxl = fix_addr( lyrf_pxl );
            tile_pri = 3'b001;
        end
    end
    pxl = lyro_blnk_n && ((obj_mask & tile_pri) == 3'd0) ? obj_addr( lyro_pxl ) : tile_pxl;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bgr <= 0;
        shl <= 0;
    end else if( pxl_cen ) begin
        shl <= shadow;
        bgr <= rgb555( pal_dout[14:0], shl );
    end
end

`ifdef JTGRAD3_TRACE_VIDEO
reg        trace_lvbl_l;
reg [15:0] trace_frame;
reg [31:0] trace_active, trace_pxl, trace_pal, trace_rgb;
reg [31:0] trace_f, trace_a, trace_b, trace_o;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        trace_lvbl_l <= 0;
        trace_frame  <= 0;
        trace_active <= 0;
        trace_pxl    <= 0;
        trace_pal    <= 0;
        trace_rgb    <= 0;
        trace_f      <= 0;
        trace_a      <= 0;
        trace_b      <= 0;
        trace_o      <= 0;
    end else if( pxl_cen ) begin
        trace_lvbl_l <= lvbl;
        if( trace_lvbl_l & ~lvbl ) begin
            if( trace_frame[3:0] == 4'd0 || trace_pxl != 0 || trace_pal != 0 || trace_rgb != 0 )
                $display("G3MIX frame=%0d active=%0d pxl=%0d pal=%0d rgb=%0d f=%0d a=%0d b=%0d o=%0d",
                    trace_frame, trace_active, trace_pxl, trace_pal, trace_rgb,
                    trace_f, trace_a, trace_b, trace_o);
            trace_frame  <= trace_frame + 1'd1;
            trace_active <= 0;
            trace_pxl    <= 0;
            trace_pal    <= 0;
            trace_rgb    <= 0;
            trace_f      <= 0;
            trace_a      <= 0;
            trace_b      <= 0;
            trace_o      <= 0;
        end else if( lvbl & lhbl ) begin
            trace_active <= trace_active + 1'd1;
            if( pxl != 0 ) trace_pxl <= trace_pxl + 1'd1;
            if( pal_dout != 0 ) trace_pal <= trace_pal + 1'd1;
            if( bgr != 0 ) trace_rgb <= trace_rgb + 1'd1;
            if( lyrf_blnk_n ) trace_f <= trace_f + 1'd1;
            if( lyra_blnk_n ) trace_a <= trace_a + 1'd1;
            if( lyrb_blnk_n ) trace_b <= trace_b + 1'd1;
            if( lyro_blnk_n ) trace_o <= trace_o + 1'd1;
        end
    end
end
`endif

jtframe_dual_nvram16 #(.AW(11), .SIMFILE("pal.bin")) u_pal(
    .clk0   ( clk             ),
    .data0  ( cpu_dout        ),
    .addr0  ( cpu_addr[11:1]  ),
    .we0    ( pal_we          ),
    .q0     ( cpu_din         ),

    .clk1   ( clk             ),
    .addr1a ( pal_addr        ),
    .q1a    ( pal_dout        ),
    .data1  ( 8'd0            ),
    .addr1b ( ioctl_addr[11:0]),
    .we1b   ( 1'b0            ),
    .sel_b  ( ioctl_ram       ),
    .q1b    (                 )
);

endmodule
