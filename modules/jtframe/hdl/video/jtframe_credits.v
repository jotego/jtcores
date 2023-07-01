/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 14-3-2020 */

// 8x8 tiles

module jtframe_credits #(
    parameter        PAGES  = 1,
                     COLW   = 4,       // bits per pixel colour component
    parameter [11:0] PAL0   = { 4'hf, 4'h0, 4'h0 },  // Red
    parameter [11:0] PAL1   = { 4'h0, 4'hf, 4'h0 },  // Green
    parameter [11:0] PAL2   = { 4'h3, 4'h3, 4'hf },  // Blue
    parameter [11:0] PAL3   = { 4'hf, 4'hf, 4'hf },  // White
    parameter        BLKPOL = 1'b1, // Blanking polarity
    parameter        SPEED  = 2     // scroll speed
) (
    input               rst,
    input               clk,

    // input image
    input               pxl_cen,
    input               HB,
    input               VB,
    input [COLW*3-1:0]  rgb_in,

    // Optional VRAM control
    input         [7:0] vram_din,
    input         [9:0] vram_addr,
    input               vram_we,
    output        [7:0] vram_dout,

    // control
    input               enable, // shows the screen and resets the scroll counter
    input               toggle, // disables the screen. Only has an effect if enable is high
    input [2:0]         vram_ctrl,
    input               fast_scroll,
    input [1:0]         rotate,

    // output image
    output reg              HB_out,
    output reg              VB_out,
    output reg [COLW*3-1:0] rgb_out
);

localparam MSGW  = PAGES == 1 ? 10 :
                   (PAGES == 2 ? 11 :
                   (PAGES > 2 && PAGES <=4 ? 12 :
                   (PAGES > 5 && PAGES <=8 ? 13 : 14 ))); // Support for upto 16 pages
localparam VPOSW = MSGW-2;
localparam HPOSW = 9;
localparam             _MAXVISIBLE = PAGES*32*8-1; // workaround to avoid a warning
localparam [VPOSW-1:0] MAXVISIBLE  = _MAXVISIBLE[VPOSW-1:0];

`ifndef JTFRAME_CREDITS_HSTART
    localparam [HPOSW-1:0] HOFFSET=0;
`else
    localparam [HPOSW-1:0] HOFFSET=`JTFRAME_CREDITS_HSTART;
`endif

localparam [HPOSW-1:0] HSTART= 0,
                       HEND  = 'h102;

reg  [HPOSW-1:0]  hn;
wire [HPOSW-1:0]  hscan;
reg  [VPOSW-1:0]  scrpos, vdump, vdump1;
reg  [8:0]        vrender;
wire [8:0]        scan_data;
wire [7:0]        font_data;
reg  [MSGW-1:0]   scan_addr;
wire [9:0]        font_addr = {scan_data[6:0],
                        rotate==2'b11 ? (~vdump[2:0]+3'd1) : vdump[2:0] };
wire              visible = vrender < MAXVISIBLE;
reg               last_toggle, last_enable;
reg               show, hide;
wire              vram_mode = vram_ctrl[0];
wire              vram_nc;

assign hscan = hn - HOFFSET;

jtframe_dual_ram #(.DW(9), .AW(MSGW),.SYNFILE("msg.bin"),.ASCII_BIN(1)) u_msg(
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    // Port 0: optional write access
    .data0  ( {1'b1, vram_din }             ),
    .addr0  ( { {MSGW-10{1'b0}}, vram_addr } ),
    .we0    ( vram_we   ),
    .q0     ( { vram_nc, vram_dout } ),
    // Port 1: video dump
    .data1  ( 9'd0      ),
    .addr1  ( scan_addr ),
    .we1    ( 1'b0      ),
    .q1     ( scan_data )
);

jtframe_ram #(.AW(10),.SYNFILE("font0.hex")) u_font(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( 8'd0      ),
    .addr   ( font_addr ),
    .we     ( 1'b0      ),
    .q      ( font_data )
);

reg  [1:0]      pal;
reg  [2:0]      pxl;

localparam MULTIPAGE = MSGW > 10;

// hb and vb are always active high
wire hb = BLKPOL ? HB : ~HB;
wire vb = BLKPOL ? VB : ~VB;
reg [7:0] pxl_data;
wire tate      = rotate[0],
     tate_flip = rotate==2'b11;

reg last_hb, last_vb;
reg [3:0] scr_base;

wire hb_edge = hb && !last_hb;

always @(posedge clk) if(pxl_cen) begin
    if( tate || hb_edge ) begin
        vdump1  <= scrpos + (tate ? hscan : vrender);
        vdump   <= vdump1;
    end
end

wire [VPOSW-1:3] vidx_flip = (~vdump[VPOSW-1:3])+1'd1;

always @(posedge clk) begin
    if( rst ) begin
        hn       <= HSTART;
        scrpos   <= {VPOSW{1'b0}};
        vrender  <= 8'd0;
        scr_base <= 4'd0;
    end else if(pxl_cen) begin
        last_hb <= hb;
        last_vb <= vb;
        if( hb_edge ) begin
            vrender <= vrender + 8'd1;
        end
        hn <= hb ? HSTART : hn+9'd1;
        // scrpos: scroll counter
        // gets reset each time the pause button is pressed
        if( enable && !last_enable ) begin
            scrpos <=  tate_flip ? MAXVISIBLE : {VPOSW{1'b0}};
        end else begin
            if ( vb ) begin
                vrender  <= 0;
                if( !last_vb && MULTIPAGE ) begin
                    // Scroll runs at max speed when the visible pages are over
                    // otherwise it runs at SPEED
                    if( scr_base == SPEED || scrpos>MAXVISIBLE || fast_scroll ) begin
                        scrpos <= tate_flip ? (scrpos-1'b1) : (scrpos + 1'b1);
                        scr_base <= 4'd0;
                    end else scr_base <= scr_base + 4'd1;
                end
            end
        end
        if( vram_mode ) scrpos <= 0;
        //if( /*tate || hn[2:0]==3'd0 || hb || vb ) begin
            scan_addr <= tate ?
                { rotate[1] ? vidx_flip : vdump[VPOSW-1:3], vrender[7:3]^{5{~rotate[1]}} } :
                { vdump[VPOSW-1:3], hscan[7:3] };
        //end
        // Draw
        if( tate ) begin
            pxl <= { scan_data[8:7], font_data[ vrender[2:0] ^{3{rotate[1]}} ] };
        end else begin
            pxl <= { pal, pxl_data[7] };
            if( hscan[2:0]==3'd1 ) begin
                pal      <= scan_data[8:7];
                pxl_data <= font_data;
            end else begin
                pxl_data <= pxl_data << 1;
            end
        end
    end
end

//////////////////////////////////////////////////////////////////////////////
// Object Generator


`ifdef JTFRAME_AVATARS
reg  [ 7:0] buf_din;
reg         buf_we0, buf_we1;
reg  [ 7:0] buf_addr0;

reg  [11:0] lut_addr;
wire [ 7:0] lut_data;

reg  [12:0] obj_addr;
wire [15:0] obj_data;

wire [ 7:0] pal_addr;
wire [11:0] pal_data;
reg  [11:0] obj_pxl;
reg  [ 7:0] obj_id, obj_x, obj_y;

reg         line = 1'b0;

jtframe_dual_ram #(.DW(8), .AW(9)) u_linebuffer(
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    // Port 0: new data writes
    .data0  ( buf_din   ),
    .addr0  ( { line, buf_addr0 } ),
    .we0    ( buf_we0   ),
    .q0     (           ),
    // Port 1
    .data1  ( ~8'd0     ),
    .addr1  ( { ~line, hscan[7:0] } ),
    .we1    ( buf_we1   ),
    .q1     ( pal_addr  )
);

jtframe_ram #(.DW(8), .AW(12),.SYNFILE("lut.hex")) u_lut(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( 8'd0      ),
    .addr   ( lut_addr  ),
    .we     ( 1'b0      ),
    .q      ( lut_data  )
);

jtframe_ram #(.DW(16), .AW(13),.SYNFILE("avatar.hex")) u_obj(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( 16'd0     ),
    .addr   ( obj_addr  ),
    .we     ( 1'b0      ),
    .q      ( obj_data  )
);

jtframe_ram #(.DW(12), .AW(4+4),.SYNFILE("avatar_pal.hex")) u_pal(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( 12'd0     ),
    .addr   ( pal_addr  ),
    .we     ( 1'b0      ),
    .q      ( pal_data  )
);

wire [VPOSW-1:0] vsub = vdump1 - { lut_data, 3'b0 };
reg  [3:0] obj_pal;
reg  [3:0] x,y,z,w;

reg [4:0] st;
reg       first;

reg last_hb2; // this is one is not gated by pxl_cen

always @(posedge clk) begin
    last_hb2 <= hb;
    if( hb && !last_hb2 ) begin
        lut_addr <= 12'd0;
        first    <= 1'b1;
        st       <= 0;
        line     <= ~line;
        buf_we0  <= 1'b0;
        buf_addr0<= 8'd0;
    end else begin
        st <= st+1;
        case( st )
            0: begin
                if( lut_addr==12'd0 && !first ) st <= 0;
            end
            1: begin
                lut_addr <= lut_addr + 12'd1;
                first <= 1'b0;
            end
            2: begin
                lut_addr <= lut_addr + 12'd1;
                obj_id   <= lut_data;
            end
            3: begin
                lut_addr <= lut_addr + 12'd1;
                obj_x    <= lut_data;
            end
            4: begin
                lut_addr <= lut_addr + 12'd1;
                obj_y    <= lut_data;
                obj_addr <= { obj_id[6:0], vsub[3:0], 2'b0 }; // 7+4+2 = 13
                if( !({lut_data,3'b0} <= vdump1 && {lut_data,3'b0}+16 > vdump1) ) st <= 0;
                if( obj_id==8'hff ) begin // end of LUT
                    lut_addr <= 12'd0;
                    st <= 0;
                end
            end
            5: obj_pal <= lut_data;
            6: begin
                buf_addr0     <= { obj_x-8'd1, 3'b111 };
                {z,y,x,w}     <= obj_data;
                obj_addr[1:0] <= 2'b01;
            end
            7,8,9,10,    12,13,14,15,
            17,18,19,20, 22,23,24,25: begin
                buf_addr0    <= buf_addr0 + 1;
                // xywz
                // wxyz
                // zyxw
                // zywx
                // zwyx
                // zwxy
                buf_din      <= { obj_pal, z[3],y[3],x[3],w[3] };
                buf_we0      <= 1'b1;
                obj_x        <= obj_x + 1;
                x            <= x << 1;
                y            <= y << 1;
                z            <= z << 1;
                w            <= w << 1;
            end
            11: begin
                {z,y,x,w}     <= obj_data;
                obj_addr[1:0] <= 2'b10;
            end
            16: begin
                {z,y,x,w}     <= obj_data;
                obj_addr[1:0] <= 2'b11;
            end
            21: {z,y,x,w}     <= obj_data;
            26: begin
                buf_we0<= 1'b0;
                st     <= 0;
            end
        endcase
    end
end

reg rd=1'b0;
reg [ 2:0] st2=3'd0;
reg        obj_ok;

always @(posedge clk ) begin
    st2 <= st2+1;
    case( st2 )
        3: begin
            obj_pxl <= pal_data;
            obj_ok  <= pal_addr[3:0] != 4'hf; // visible pixel
            buf_we1 <= !hscan[8]; // do not empty the line buffer when
                               // scanning the left side of the screen
                               // This applies when JTFRAME_CREDITS_HSTART!=0
        end
        4: begin
            buf_we1 <= 1'b0;
            if( pxl_cen ) st2 <= 0; else st2 <= 4;
        end
    endcase
end

`else
wire [11:0] obj_pxl = ~12'h0;
wire        obj_ok  = 1'b0;
`endif

/////////////////////////////////////////////////////////////////////////////
// Colour Mixer
// Merge the new image with the old
localparam R1 = COLW*3-1;
localparam R0 = COLW*2;
localparam G1 = COLW*2-1;
localparam G0 = COLW;
localparam B1 = COLW-1;
localparam B0 = 0;

wire [COLW*3-1:0] dim = { 1'b0, rgb_in[R1:R0+1], 1'b0, rgb_in[G1:G0+1], 1'b0, rgb_in[B1:B0+1] };

// COLW must be >= 4
reg [7:0] b;

function [COLW*3-1:0] extend;
    input [11:0] rgb4;
    begin
        b = {2{rgb4[3:0]}};
        extend[COLW*3-1-:8] = {2{rgb4[11:8]}};
        extend[COLW*2-1-:8] = {2{rgb4[ 7:4]}};
        extend[COLW*1-1: 0] = b[7-:COLW];
    end
endfunction

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        show        <= 0;
        hide        <= 0;
        last_toggle <= 0;
        last_enable <= 0;
    end else begin
        last_enable <= enable;
        last_toggle <= toggle;
        if( enable ) begin
            if( vram_mode ) begin
                show <= 1;
                hide <= 0;
            end else begin
                show <= ~hide;
                if( toggle && !last_toggle ) begin
                    hide <= ~hide;
                end
            end
        end else show <= 0;
    end
end

always @(posedge clk) if(pxl_cen) begin
    { HB_out, VB_out } <= { HB, VB };
    // if HOFFSET != 0 and the game is vertical, the full horizontal length
    // of the screen is used. Otherwise, the credits will start at HOFFSET
    // and last for 256 pixels
    if( !show || ( HOFFSET!=0 && !tate && (hn<HOFFSET || hn>=(HEND+HOFFSET))) )
        rgb_out <= rgb_in;
    else begin
        if( (!pxl[0] && (!obj_ok || vram_mode)) || !visible ) begin
            if( vram_ctrl[0] ) begin
                rgb_out <= (vdump[7] ? vram_ctrl[2] : vram_ctrl[1]) ? dim : rgb_in;
            end else begin
                rgb_out <= dim;
            end
        end else begin
            if( pxl[0] || tate ) begin // CHAR, OBJ disabled for TATE
                case( pxl[2:1] )
                    2'd0: rgb_out <= extend(PAL0);
                    2'd1: rgb_out <= extend(PAL1);
                    2'd2: rgb_out <= extend(PAL2);
                    2'd3: rgb_out <= extend(PAL3);
                endcase
            end else rgb_out <= extend(obj_pxl); // OBJ
        end
        if( vb || hb ) rgb_out <= 0;
    end
end

endmodule