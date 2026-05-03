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
    output     [11:1] pal_rd_addr,
    input      [15:0] palrd_dout,
    output     [11:1] pal_cpu_addr,
    output     [15:0] pal_cpu_din,
    output     [ 1:0] pal_cpu_we,
    input      [15:0] pal_cpu_dout,

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

    input      [ 7:0] debug_bus
);

wire [10:0] pal_addr;
wire [ 1:0] pal_we;
reg  [10:0] pxl;
reg  [10:0] tile_pxl;
reg  [ 2:0] tile_pri, obj_mask;
reg  [23:0] bgr;
reg         shl;

assign pal_we    = {2{cpu_we & pal_cs}} & ~cpu_dsn;
assign pal_addr  = pxl;
assign pal_rd_addr  = pal_addr;
assign pal_cpu_addr = cpu_addr[11:1];
assign pal_cpu_din  = cpu_dout;
assign pal_cpu_we   = pal_we;
assign cpu_din      = pal_cpu_dout;
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

// The 052535 devices are DACs; layer priority is the discrete CD8/CD9 logic
// on the color mixer sheet.
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
        bgr <= rgb555( palrd_dout[14:0], shl );
    end
end

endmodule
