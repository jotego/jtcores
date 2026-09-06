/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-8-2026 */

/*  Sprite table scanner for the Space Harrier custom (315-5011/5012).

    ATTRIBUTION -- derived from MAME `sega_sharrier_sprite_device::draw` in
    sega16sp.cpp (Aaron Giles, BSD-3-Clause). BSD-3 requires the notice to be
    retained in redistributions, so this is a licence condition, not a note.

    Descriptor (8 words, sega16sp.cpp:291); words +0..+8 only:
      +0  bbbbbbbb tttttttt   bottom=[15:8], top=[7:0]  (DEVICE scanlines)
      +2  -bbb---- --------   bank
      +2  -------x xxxxxxxx   xpos (xpos $BD = screen X 0, applied in _obj.v)
      +4  s------- --------   shadow DISABLE (0 = enabled)
      +4  -p------ --------   priority
      +4  --cccccc --------   colour
      +4  -------- -ppppppp   pitch (signed 7-bit)
      +6  f------- --------   flip = address bit 15 (the address can carry in)
      +6  -ooooooo oooooooo   base offset within the bank
      +8  --zzzzzz --------   hzoom
      +8  -------- --zzzzzz   vzoom
    bottom > 0xF0 ends the list; skip if top >= bottom. Device origin is
    (189,-1), so device y = vrender-1.

    Vertical zoom is stateful down the sprite, sega16sp.cpp:367:
        for y = top..bottom-1: addr += pitch; if(zoom[zaddr++] & zmask) addr += pitch
        zaddr = (vzoom & 0x38) << 5   ==  { vzoom[5:3], 8'd0 }
        zmask = 1 << (vzoom & 7)      ==  zoom_data[ vzoom[2:0] ]
    MAME runs a whole sprite in one call and keeps the running address in the +E
    scratch word. That word is CPU-visible and scene-restorable here, so this
    scanner carries the address line-to-line in a private 256x16 RAM instead:
    reset to the +6 base on the sprite's first on-screen line, stepped after.
*/

module jtharier_obj_scan(
    input              rst,
    input              clk,

    input      [ 8:0]  vrender,
    input              hstart,

    // Object RAM read port, 256 sprites x 8 words
    output     [11:1]  tbl_addr,
    input      [15:0]  tbl_dout,

    // Zoom table ROM epr-6844
    output     [12:0]  zoom_addr,
    input      [ 7:0]  zoom_data,

    output reg         dr_start,
    input              dr_busy,
    output reg [ 8:0]  dr_xpos,
    output reg [15:0]  dr_offset,   // [15] = hflip
    output reg [ 2:0]  dr_bank,
    output reg         dr_prio,
    output reg [ 5:0]  dr_pal,
    output reg         dr_shadow,   // shadow ENABLED for this sprite
    output reg [ 6:0]  dr_hzoom
);

localparam [2:0] LAST_IDX = 3'd4;   // words +0,+2,+4,+6,+8

reg  [ 7:0] cur_obj;
reg  [ 3:0] st;
reg  [ 2:0] idx;
reg         stop, visible, first, hstart_l;

reg  [ 7:0] top;
reg  [ 2:0] bank;
reg  [ 8:0] xpos;
reg signed [15:0] pitch;
reg  [15:0] addr;
reg  [ 5:0] vzoom, hzoom6, pal;
reg         prio, shadow_dis;
reg  [15:0] scr;            // running address latched from the private scratch RAM

// Private scratch RAM: the +E running address, one word per sprite
wire [15:0] scr_dout;
reg  [15:0] scr_din;
reg         scr_we;

assign tbl_addr = { cur_obj, idx };

wire [ 8:0] vdev = vrender - 9'd1;

wire [12:0] zbase = { 2'd0, vzoom[5:3], 8'd0 };
wire [ 7:0] yoff  = vdev[7:0] - top;
assign      zoom_addr = zbase + { 5'd0, yoff };
wire        zbit  = zoom_data[ vzoom[2:0] ];

// The +6 base on the sprite's first line, else the scratch, stepped by pitch --
// twice when the zoom bit is set.
wire [15:0] base_addr = first ? addr : scr;
wire [15:0] nx_addr   = base_addr + pitch + (zbit ? pitch : 16'd0);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cur_obj   <= 0;
        st        <= 0;
        idx       <= 0;
        stop      <= 0;
        hstart_l  <= 0;
        first     <= 0;
        visible   <= 0;
        addr      <= 0;
        scr       <= 0;
        top       <= 0;
        pitch     <= 0;
        scr_we    <= 0;
        scr_din   <= 0;
        dr_start  <= 0;
        dr_xpos   <= 0;
        dr_offset <= 0;
        dr_bank   <= 0;
        dr_prio   <= 0;
        dr_pal    <= 0;
        dr_shadow <= 0;
        dr_hzoom  <= 0;
    end else begin
        // idx free-runs; the branches forcing idx<=0 win by coming later.
        idx      <= idx>=LAST_IDX ? LAST_IDX : (idx + 3'd1);
        if( !stop ) st <= st + 1'd1;
        hstart_l <= hstart;
        stop     <= 0;
        dr_start <= 0;
        scr_we   <= 0;

        case( st )
            0: begin
                cur_obj <= 0;
                stop    <= 0;
                if( !(hstart && !hstart_l) || vrender>223 ) begin
                    st  <= 0;
                    idx <= 0;
                end
            end
            1: if( !stop ) begin       // tbl_dout = +0 : bottom / top
                top     <= tbl_dout[ 7:0];
                visible <= (vdev[8]==0) && (vdev[7:0] >= tbl_dout[7:0])
                                        && (tbl_dout[15:8] > vdev[7:0])
                                        && (tbl_dout[7:0] < tbl_dout[15:8]);
                first   <= tbl_dout[7:0] == vdev[7:0];
                if( tbl_dout[15:8] > 8'hf0 ) begin      // end of list
                    st  <= 0;
                    idx <= 0;
                end
            end
            2: begin                   // tbl_dout = +2 : bank / xpos
                bank <= tbl_dout[14:12];
                xpos <= tbl_dout[ 8:0];
            end
            3: begin                   // tbl_dout = +4 : shadow / prio / colour / pitch
                shadow_dis  <= tbl_dout[15];
                prio        <= tbl_dout[14];
                pal         <= tbl_dout[13:8];
                pitch[6:0]  <= tbl_dout[6:0];
                pitch[15:7] <= {9{tbl_dout[6]}};        // sext 7-bit
            end
            4: begin                   // tbl_dout = +6 : flip + base offset
                addr <= tbl_dout;
                if( !visible ) begin   // skip before touching the scratch
                    cur_obj <= cur_obj + 1'd1;
                    idx     <= 0;
                    st      <= 1;
                    stop    <= 1;
                    if( &cur_obj ) st <= 0;
                end
            end
            5: begin                   // tbl_dout = +8 : hzoom / vzoom
                hzoom6 <= tbl_dout[13:8];
                vzoom  <= tbl_dout[ 5:0];
            end
            6: begin                   // zoom_data valid next cycle
                scr <= scr_dout;
            end
            7: begin                   // step the running address, write it back
                addr    <= nx_addr;
                scr_din <= nx_addr;
                scr_we  <= 1;
            end
            8: begin                   // issue the draw
                if( !dr_busy ) begin
                    dr_xpos   <= xpos;
                    dr_offset <= addr;                 // [15] = hflip
                    dr_bank   <= bank;
                    dr_prio   <= prio;
                    dr_pal    <= pal;
                    dr_shadow <= ~shadow_dis;
                    dr_hzoom  <= { hzoom6, 1'b0 };      // MAME: (field & 0x3f) << 1
                    dr_start  <= 1;
                    cur_obj   <= cur_obj + 1'd1;
                    idx       <= 0;
                    st        <= 1;
                    stop      <= 1;
                    if( &cur_obj ) st <= 0;
                end else begin
                    st <= st;                          // wait for the drawer
                end
            end
            default: st <= 0;
        endcase

        if( hstart && !hstart_l && st!=0 ) begin
            cur_obj  <= 0;
            idx      <= 0;
            st       <= 1;
            stop     <= 1;
            dr_start <= 0;
            scr_we   <= 0;
        end
    end
end

jtframe_dual_ram16 #(.AW(8)) u_scratch(
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    .addr0  ( cur_obj   ),
    .data0  ( scr_din   ),
    .we0    ( {2{scr_we}} ),
    .q0     (           ),
    .addr1  ( cur_obj   ),
    .data1  ( 16'd0     ),
    .we1    ( 2'd0      ),
    .q1     ( scr_dout  )
);

endmodule
