/*  SPDX-FileCopyrightText: © 2026 Andrea Bogazzi
    SPDX-License-Identifier: GPL-3.0-or-later
    Date: 25-10-2026 */

module jtf1gpr2_roz(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             hs, vs,
    input             flip,

    input             cs,
    input      [ 4:1] addr,
    input      [15:0] din,
    input      [ 1:0] dsn,

    input      [ 7:0] roz_bank,

    output     [12:1] rozv_addr,
    input      [15:0] rozv_dout,

    output reg [20:1] rom_addr,
    output reg        rom_cs,
    input      [15:0] rom_data,
    input             rom_ok,

    output     [ 7:0] pxl,
    output            on
);

wire [12:0] x, y;
reg  vs_dly, hs_l;
wire vs_eff = flip ? vs : vs_dly;

always @(posedge clk) begin
    hs_l <= hs;
    if( hs & ~hs_l ) vs_dly <= vs;
end

wire xh, yh, ob;

jt053936 #(.XOFFSET(-4),.YOFFSET(-22)) u_xy(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( pxl_cen   ),

    .din        ( din       ),
    .addr       ( addr      ),

    .hs         ( hs        ),
    .vs         ( vs_eff    ),
    .cs         ( cs        ),
    .dtackn     ( 1'b0      ),
    .dsn        ( dsn       ),
    .dma_n      (           ),

    .ldout      ( 16'd0     ),
    .lh         (           ),
    .la         (           ),

    .x          ( x         ),
    .xh         ( xh        ),
    .y          ( y         ),
    .yh         ( yh        ),
    .nx         (           ),
    .ny         (           ),
    .ob         ( ob        ),

    .ioctl_addr ( 5'd0      ),
    .ioctl_din  (           )
);

assign rozv_addr = { y[9:4], x[9:4] };

reg  [18:0] code;
reg  [ 3:0] col;
reg  [ 3:0] xl, yl, xl2;
reg         ob_l, ob_l2, ob_l3;
reg         got_map, got_gfx;
reg  [15:0] gfx_word;

always @(posedge clk) begin
    if( rst ) begin
        code    <= 0; col <= 0;
        xl      <= 0; yl  <= 0; xl2 <= 0;
        ob_l    <= 1; ob_l2 <= 1; ob_l3 <= 1;
        got_map <= 0; got_gfx <= 0;
        rom_cs  <= 0; rom_addr <= 0;
        gfx_word<= 0;
    end else begin
        if( pxl_cen ) begin
            code    <= (rozv_dout[10:0] | ({roz_bank, 3'd0} << 8));
            col     <= rozv_dout[15:12];
            xl      <= x[3:0];
            yl      <= y[3:0];
            ob_l    <= ob;
            got_map <= 1;
            got_gfx <= 0;
        end
        if( got_map && !got_gfx ) begin
            rom_addr <= { code, yl, xl[3:2] };
            rom_cs   <= ~ob_l;
            if( ob_l ) begin
                got_gfx <= 1;
                got_map <= 0;
            end
        end
        if( rom_cs && rom_ok ) begin
            gfx_word <= rom_data;
            rom_cs   <= 0;
            got_gfx  <= 1;
            got_map  <= 0;
            xl2      <= xl;
            ob_l2    <= ob_l;
        end
        if( ob_l && got_map && !got_gfx ) begin
            ob_l2   <= 1;
            got_gfx <= 1;
            got_map <= 0;
        end
    end
end

reg [3:0] pix;
always @* begin
    case( xl2[1:0] )
        2'd0: pix = gfx_word[15:12];
        2'd1: pix = gfx_word[11: 8];
        2'd2: pix = gfx_word[ 7: 4];
        2'd3: pix = gfx_word[ 3: 0];
    endcase
end

assign on  = ~ob_l2;
assign pxl = ob_l2 ? 8'd0 : { col, pix };

endmodule
