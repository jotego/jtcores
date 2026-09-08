/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 9-8-2026 */

// Space Harrier road generator: the 315-5025 custom (sheet 4/6), road control RAM
// 2016 x2 (IC50/IC63), road data ROM EPR-7181 (IC2), LS669 x3 counters
// (IC14/15/16). The 315-5025 has no decap, so its per-pixel behaviour comes from
// MAME's model -- the last-resort source for a custom the schematic and the
// siblings cannot describe. The state names are MAME's and map onto the sheet-4/6
// parts --
// 9M/9N/9P = LS669, 8J = LS164, 9J = LS174 -- so the transcription can be checked
// against segaic16_road.cpp line for line.
//
// license:BSD-3-Clause  copyright-holders:Aaron Giles
// Transcribed from MAME segaic16_road.cpp, segaic16_road_hangon_draw
// (ROAD_SHARRIER path). BSD-3-Clause requires this notice to be retained in
// redistributions: it is a licence condition, not a comment.
//
// Road control RAM word map (roadram, 0x400 words used of 0x800), MAME offsets /2:
//   0x000-0x0FF  per scanline: control
//                  [11:10] plycont  road priority vs tilemaps/sprites
//                  [9]     /CE of the road ROM (Space Harrier: 1 disables ROM data)
//                  [8]     counting-direction force (0 -> ff9j1 held set)
//                  [7:0]   index for the three tables below
//   0x100-0x1FF  per index:   hpos      horizontal position (12 bits used)
//   0x200-0x2FF  per index:   color0    background (solid-fill) colour, two sets
//   0x300-0x3FF  per index:   color1    road-pixel colour selects

module jtharier_road(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             hs,
    input      [ 8:0] vdump,      // line being displayed. NOT vrender: this module was
                                  // NOT vrender: jtframe_vtimer advances both on the
                                  // tick HS rises, so vrender indexes one line ahead
                                  // and draws the road a line high.

    // Road control RAM read port; the CPU owns the other one
    output reg [10:0] rdram_addr, // word address
    input      [15:0] rdram_data,

    // Road data ROM EPR-7181: two interleaved 0x4000 planes, {plane1, plane0}
    output     [13:0] rdrom_addr, // word address
    input      [15:0] rdrom_data,

    // Pixel output
    output reg [10:0] pxl,        // palette index, colour base already applied
    output reg        pxl_op,     // pixel is valid: low through the PREROLL warm-up
    output reg [ 1:0] plycont,    // road layering vs tilemaps/sprites

    input      [ 7:0] st_addr,
    output reg [ 7:0] st_dout
);

// Colour bases, segahang.cpp:190 segaic16_road_init(0, ROAD_SHARRIER). Its
// third base is the sky, used only by the Out Run draw.
localparam [10:0] COLORBASE1 = 11'h038,  // road ROM data
                  COLORBASE2 = 11'h7c0;  // background solid fill (the top band)

// The pipeline runs from x=-24 to warm ss8j and the counters but must not be
// drawn (segaic16_road.cpp:199). PREROLL counts those out; pxl_op keeps them
// off screen, since pxl holds the previous line's last value until then.
localparam [4:0] PREROLL = 5'd24;

// HROAD_HOFF delays the engine start after the hblank fetch, shifting the road
// right one pixel per count. PROVISIONAL: this value agrees with MAME, and MAME
// is not the authority here. If the board disagrees, the BOARD wins -- change
// this number.
localparam [6:0] HROAD_HOFF = 7'd31;

// Per-scanline table fetch: control first, since it holds the index the other
// three are addressed by.
reg  [ 2:0] st;
reg  [15:0] control, hpos, color0, color1;
reg  [ 7:0] idx_l;      // control[7:0], latched for the table addresses
wire [ 7:0] y   = vdump[7:0];

// The BRAM read is 0-latency from this pxl_cen-paced FSM, so each word is
// captured in the SAME state its address is driven. A testbench modelling it one
// pxl_cen late mis-aligns by a slot; do not "fix" the capture states to match.
always @(*) begin
    case( st )
        3'd2:    rdram_addr = { 3'b001, idx_l };  // 0x100 + idx : hpos
        3'd3:    rdram_addr = { 3'b010, idx_l };  // 0x200 + idx : color0
        3'd4:    rdram_addr = { 3'b011, idx_l };  // 0x300 + idx : color1
        default: rdram_addr = { 3'b000, y     };  // 0x000 + y  : control (and idle)
    endcase
end

// ---------------------------------------------------------------------------
// Per-pixel engine state, MAME node names retained
reg  [ 2:0] ctr9m;      // 4-bit counter at 9M, low 3 bits count bits in a byte
reg  [ 7:0] ctr9n9p;    // cascaded 4-bit counters 9P/9N, up/down byte counter
reg         ff9j1;      // 9J lower: counting direction
reg         ff9j2;      // 9J upper: background-colour enable
reg  [ 7:0] ss8j;       // serial shifter 8J, delays several signals

reg  [ 4:0] prewind;
reg         ff9j1_f;    // ff9j1 after the same-cycle forcing
reg         running;
reg         hs_l;
reg         waiting;
reg  [ 6:0] hoff_cnt;

// Road ROM address: idx selects the row, the top 6 bits of the byte counter the
// byte, stable for 8 pixels. control[9]=1 disables the ROM for the solid fill.
assign rdrom_addr = { idx_l, ctr9n9p[5:0] };

// ss8j bit 0 swaps the bit order: normal reads bit (7-ctr9m), swapped ctr9m.
wire [2:0] bitpos = ss8j[0] ? (3'd7 - ctr9m) : ctr9m;
wire       oe     = (ctr9n9p[7:6]==2'b11);              // /OE = AND of 9N bits 2,3
wire       ce     = ~control[9];                        // Space Harrier: ctrl[9] -> /CE
reg  [1:0] md;
reg  [1:0] mdc;         // md clamped for colour select
reg        cbit;
wire       select = ss8j[3];

// ff9j1 with the forcing applied (MAME 137-142), combinational so the forced
// value feeds this cycle's 6M updates rather than the next.
always @(*) begin
    ff9j1_f = ff9j1;
    if( ctr9n9p==8'hff ) ff9j1_f = 1'b0;   // carry out of 9P/9N clears it
    if( !control[8]    ) ff9j1_f = 1'b1;   // control bit 8 forces it set
end

always @(*) begin
    md = 2'd3;
    if( ce && oe )
        md = { rdrom_data[4'd8+bitpos +: 1], rdrom_data[{1'b0,bitpos} +: 1] };  // {plane1,plane0}
end

reg  [10:0] pxl_nx;
always @(*) begin
    mdc = 2'd0; cbit = 1'b0;
    if( ff9j2 && md==2'd3 ) begin
        // background solid fill: color0 holds two 6-bit selections
        pxl_nx = COLORBASE2 | { 5'd0, (select ? color0[5:0] : color0[13:8]) };
    end else begin
        // color1 bit 7 clamps a value-3 pixel to 0 (AND gates 7L/9K/7K)
        mdc    = (color1[7] && md==2'd3) ? 2'd0 : md;
        cbit   = color1[ {1'b0, mdc, select} +: 1 ];  // (md<<1)|select mux into color1[7:0]
        pxl_nx = COLORBASE1 | { 7'd0, select, mdc, cbit };
    end
end

// ---------------------------------------------------------------------------
// Each line: tables fetched on hs (st 0..5), counters load at st 5, then the
// engine free-runs past hblank into active video.
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st       <= 3'd0; hs_l <= 0; running <= 0; waiting <= 0; hoff_cnt <= 0;
        control  <= 0; hpos <= 0; color0 <= 0; color1 <= 0; idx_l <= 0;
        ctr9m    <= 0; ctr9n9p <= 0; ff9j1 <= 0; ff9j2 <= 1; ss8j <= 0;
        prewind  <= 0; pxl <= 0; pxl_op <= 0; plycont <= 0;
    end else if( pxl_cen ) begin
        hs_l <= hs;
        if( hs & ~hs_l ) begin
            st <= 3'd0; running <= 1'b0; waiting <= 1'b0; pxl_op <= 1'b0;
        end else if( hs & ~running & ~waiting ) begin
            if( st<3'd5 ) st <= st + 3'd1;
            case( st )
                3'd1: begin control <= rdram_data;      // control word (addr {000,y})
                            idx_l   <= rdram_data[7:0];
                            plycont <= rdram_data[11:10]; end
                3'd2: hpos   <= rdram_data;             // hpos   (addr {001,idx})
                3'd3: color0 <= rdram_data;             // color0 (addr {010,idx})
                3'd4: color1 <= rdram_data;             // color1 (addr {011,idx})
                3'd5: begin
                    // load the counters from hpos, then hold for HROAD_HOFF
                    // pxl_cen before running
                    ctr9m   <= hpos[2:0];
                    ctr9n9p <= hpos[10:3];
                    ff9j1   <= hpos[11];
                    ff9j2   <= 1'b1;
                    ss8j    <= 8'd0;
                    prewind <= PREROLL;
                    waiting <= 1'b1;
                    hoff_cnt<= HROAD_HOFF;
                end
                default:;
            endcase
        end else if( waiting ) begin
            // registration hold, then start the engine
            if( hoff_cnt==7'd0 ) begin running <= 1'b1; waiting <= 1'b0; end
            else hoff_cnt <= hoff_cnt - 7'd1;
        end else if( running ) begin
            ff9j1 <= ff9j1_f;

            if( prewind!=0 ) prewind <= prewind - 5'd1;
            else begin pxl <= pxl_nx; pxl_op <= 1'b1; end

            // 6M-clocked state update, all using the forced ff9j1
            ctr9m <= (ctr9m + 3'd1);           // 9M wraps mod 8 naturally (3-bit)
            if( ctr9m==3'd7 )                  // 9N/9P enabled on 9M carry
                ctr9n9p <= ff9j1_f ? (ctr9n9p + 8'd1) : (ctr9n9p - 8'd1);
            ff9j2 <= ~(~ff9j1_f & ss8j[7]);
            ss8j  <= { ss8j[6:0], ff9j1_f };
        end
    end
end

always @(posedge clk) begin
    case( st_addr[1:0] )
        2'd0: st_dout <= control[7:0];
        2'd1: st_dout <= hpos[7:0];
        2'd2: st_dout <= color0[7:0];
        default: st_dout <= color1[7:0];
    endcase
end

endmodule
