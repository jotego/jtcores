/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 10-8-2026 */

// VS8904/VS8905 sprite list walker.
//
// 128 slots of 4 words. Word 0x1fe - word 2 of the last slot - is the list
// start pointer.
//
// MAME walks 0x1f8 down to that pointer, pri==1 pass first, and the priority
// buffer keeps the FIRST pixel written. Reproducing that with a keep-first
// line buffer costs a pixel at every border, because jtframe_obj_buffer reads
// the old pixel through a registered port and jtframe_draw keeps its write
// enable asserted on both clocks of the half rate cadence KEEP_OLD imposes.
// The exact same picture comes out of a plain keep-last buffer walked in
// reverse: slots ascending from the pointer up to 0x1f8, pri==0 pass first.
//
//   w0: [8:0] oy      [15:12] zoomy
//   w1: [8:0] ox      [15:12] zoomx
//   w2: [3:0] colour  [4] pri  [7] enable
//       [10:8] xsize  [11] flipx  [14:12] ysize  [15] flipy
//   w3: map, indexed into the lookup RAM to get the real tile code
//
// Zoom is shrink only: the effective factor is 32-nibble, so 32 is 1:1 and 17
// is about half size. One tile is 16*zoom/32 = zoom/2 pixels on screen.
//
// Timing. A line is 456 px x 8 clk = 3648 clocks. The walk issues one sprite
// RAM word per clock - a flat 4 clocks per slot, on line or not - so both
// priority passes over the whole list take ~1020 clocks, and it runs
// CONCURRENTLY with the gfx fetch: slots that are on this line queue in a
// FIFO. The drawer pops a slot and expands it into tile columns, reading the
// lookup RAM for column N+1 while column N is still drawing. Walk time and
// draw time overlap instead of adding up, so the list is not truncated by the
// end of the line - which used to drop the pri==0 pass, i.e. the sprites that
// belong in FRONT.

// PASSES=2 walks the list twice, pri==1 then pri==0 (vsystem_spr2 pritype 0
// and 1). PASSES=1 is the pritype 2 case - f1gp - where the chip makes a
// single pass and the priority value comes from the mixer instead
module jtpspike_objscan #(parameter PASSES=2)(
    input             rst,
    input             clk,
    input             hs,
    input             scan_en,     // held low when the second chip is unused
    input      [ 8:0] vrender,
    input      [ 8:0] xoffs,       // vsystem_spr2 set_offsets x, signed
    input      [ 8:0] yoffs,       // vsystem_spr2 set_offsets y, signed
    input             flip,
    input      [ 1:0] objbank,

    // sprite RAM
    output     [ 9:1] objr_addr,
    input      [15:0] objr_dout,
    // tile code lookup RAM
    input             wide_lut,   // karatblz LUTs are 64kB, others 16kB
    input      [14:0] cmask,      // tile-code mask, gfx region size / 128 - 1
    output     [14:0] objl_addr,
    input      [15:0] objl_dout,

    // jtframe_objdraw
    output reg        draw,
    input             busy,
    output reg [14:0] code,
    output reg [ 8:0] xpos,
    output reg [ 3:0] ysub,
    output reg [ 7:0] hzoom,
    output reg        hz_keep,
    output reg        hflip, vflip,
    output     [ 6:0] pal
);

localparam [8:0] LAST = 9'h1f8, PTR = 9'h1fe;
// candidate record: ox9 map16 xsize3 ysize3 src8 zxnib4 fx1 fy1 pri1 colour4
localparam       RECW = 50, FW = 3;     // FIFO depth = 8 slots

reg  [ 2:0] st;
reg  [ 8:0] first, scan_addr, rd_addr;
reg         pass, pass1, pass2, issuing, hs_l;
reg  [ 1:0] wsel1, wsel2;
reg         iss1, iss2;
reg  [15:0] w0, w1, w2;

wire        hs_pos  = hs & ~hs_l;
wire [15:0] w3      = objr_dout;        // live on the bus when wsel2==3
wire [ 8:0] oy      = w0[8:0];
wire [ 8:0] ox      = w1[8:0];
wire [ 2:0] xsize   = w2[10:8];
wire [ 2:0] ysize   = w2[14:12];
wire        en      = w2[7];
wire        pri     = w2[4];
wire        fx      = w2[11];
wire        fy      = w2[15];
wire [ 5:0] zy      = 6'd32 - {2'd0,w0[15:12]};

// how many lines the whole block covers, and where this line falls in it
wire [ 9:0] blk_h   = (({6'd0,ysize}+10'd1)*{4'd0,zy}) >> 1;
wire [ 8:0] dy      = vrender + 9'd16 - (oy + yoffs + 9'd16);
wire        on_line = dy < blk_h[8:0];

assign objr_addr = rd_addr;

// dy * 32 / zy, as dy * (8192/zy) >> 8
reg [8:0] recip;
always @* begin
    case( zy )
        6'd17: recip = 9'd482; 6'd18: recip = 9'd455;
        6'd19: recip = 9'd431; 6'd20: recip = 9'd410;
        6'd21: recip = 9'd390; 6'd22: recip = 9'd372;
        6'd23: recip = 9'd356; 6'd24: recip = 9'd341;
        6'd25: recip = 9'd328; 6'd26: recip = 9'd315;
        6'd27: recip = 9'd303; 6'd28: recip = 9'd293;
        6'd29: recip = 9'd282; 6'd30: recip = 9'd273;
        6'd31: recip = 9'd264; default: recip = 9'd256;
    endcase
end

wire [16:0] prod = {8'd0,dy} * {8'd0,recip};
wire [ 7:0] src  = prod[15:8];

// ---------------- candidate FIFO ----------------
reg  [RECW-1:0] fifo[0:(1<<FW)-1];
reg  [FW:0]     wptr, rptr;
wire            fifo_empty = wptr==rptr;
wire            fifo_full  = wptr[FW-1:0]==rptr[FW-1:0] && wptr[FW]!=rptr[FW];
wire [RECW-1:0] fifo_out   = fifo[rptr[FW-1:0]];
wire [RECW-1:0] rec_in     = { ox, w3, xsize, ysize, src, w1[15:12],
                               fx, fy, pri, w2[3:0] };
wire            push = iss2 && wsel2==2'd3 && en && on_line &&
                       (PASSES==1 || pri==pass2);
// a full FIFO holds the address and puts a bubble in the delay pipe, so the
// words already in flight still land in step
wire            stall = fifo_full;

// ---------------- scan: one word per clock ----------------
always @(posedge clk) begin
    if( rst ) begin
        st      <= 0;      issuing <= 0;    pass  <= 0;
        scan_addr <= 0;    rd_addr <= 0;    first <= 0;
        wsel1   <= 0;      wsel2   <= 0;
        iss1    <= 0;      iss2    <= 0;
        pass1   <= 0;      pass2   <= 0;
        w0      <= 0;      w1      <= 0;    w2    <= 0;
        wptr    <= 0;      hs_l    <= 0;
    end else begin
        hs_l <= hs;
        // Restart on every HS from whatever state we were in
        if( hs_pos ) begin
            rd_addr <= PTR;
            st      <= scan_en ? 3'd1 : 3'd0;
            issuing <= 0;
            pass    <= 0;
            wptr    <= 0;
            iss1    <= 0;
            iss2    <= 0;
        end else begin
            case( st )
                0: ;                        // idle until the next HS
                1: st <= 2;                 // BRAM latency
                2: st <= 3;
                // MAME clamps the list pointer to 0x1FC and then loops while
                // start != first-4, so a pointer above LAST means an EMPTY
                // list. Clamping to LAST instead would draw slot 0x1F8 once -
                // one stale sprite left over from the previous scene.
                3: begin
                    first     <= {objr_dout[6:0],2'd0};
                    scan_addr <= {objr_dout[6:0],2'd0};
                    if( {objr_dout[6:0],2'd0} > LAST ) st <= 0;
                    else begin issuing <= 1; st <= 4; end
                end
                default:;                   // 4 = walking
            endcase

            if( issuing && !stall ) begin
                rd_addr <= scan_addr;
                if( scan_addr=={LAST[8:2],2'd3} ) begin   // last word, last slot
                    if( pass || PASSES==1 ) issuing <= 0;
                    else begin pass <= 1; scan_addr <= first; end
                end else scan_addr <= scan_addr + 9'd1;
            end
            wsel1 <= scan_addr[1:0]; iss1 <= issuing & ~stall; pass1 <= pass;
            wsel2 <= wsel1;          iss2 <= iss1;             pass2 <= pass1;

            // the word issued two edges ago is on objr_dout now
            if( iss2 ) case( wsel2 )
                2'd0: w0 <= objr_dout;
                2'd1: w1 <= objr_dout;
                2'd2: w2 <= objr_dout;
                default:;                   // w3 is used straight off the bus
            endcase

            if( push ) begin
                fifo[wptr[FW-1:0]] <= rec_in;
                wptr <= wptr + 1'd1;
            end
        end
    end
end

// ---------------- draw: expand one slot into tile columns ----------------
localparam [2:0] D_IDLE=0, D_ISSUE=1, D_UP=2, D_DOWN=3;

reg  [ 2:0] dst, dcol, lcol;
reg  [ 8:0] d_ox;
reg  [15:0] d_map;
reg  [ 2:0] d_xsize, d_ysize;
reg  [ 7:0] d_src;
reg  [ 3:0] d_zx, d_col;
reg         d_fx, d_fy, d_pri;
reg  [14:0] code_nx;
reg  [ 1:0] lutcnt;
reg         nx_ok;

// the map advances with the unflipped index, the position uses the flipped one
wire [ 2:0] maprow = d_fy ? d_ysize - d_src[6:4] : d_src[6:4];
wire [ 2:0] mapcol = d_fx ? d_xsize - lcol       : lcol;
// the map row stride is the next power of two of xsize+1
wire [ 3:0] stride = d_xsize<3'd1 ? 4'd1 : d_xsize<3'd2 ? 4'd2 :
                     d_xsize<3'd4 ? 4'd4 : 4'd8;
wire [15:0] mapidx = d_map + {12'd0,maprow}*{12'd0,stride} + {13'd0,mapcol};

assign objl_addr = wide_lut ? mapidx[14:0] : { 2'd0, mapidx[12:0] };
// the pri bit rides along with the pixel so the mixer can use it
assign pal       = { d_pri, objbank, d_col };

// MAME reduces the lookup value with code % gfx->elements(), where elements is
// the DECLARED ROM_REGION size / 128, not the bytes actually loaded. Every
// region here is a power of two, so the remainder is a plain mask - but the
// width is per chip and per game, and 13 bits truncates turbofrc and karatblz:
//   chip 0  pspikes gfx2 0x100000 /128 = 8192   -> 13
//           turbofrc spritegfx 0x200000  = 16384 -> 14  (only 0x180000 loaded)
//           aerofgt  spritegfx 0x100000  = 8192  -> 13
//           karatblz spritegfx 0x400000  = 32768 -> 15  (only 0x240000 loaded)
//   chip 1  turbofrc/aerofgt gfx4 0x80000 = 4096 -> 12
//           karatblz gfx4 0x100000        = 8192 -> 13
wire [14:0] lut_code = objl_dout[14:0] & cmask;

// 2048/zx, the source step jtframe_draw subtracts per output pixel
reg [7:0] hz_lut;
always @* begin
    case( 6'd32 - {2'd0,d_zx} )
        6'd17: hz_lut = 8'd120; 6'd18: hz_lut = 8'd114;
        6'd19: hz_lut = 8'd108; 6'd20: hz_lut = 8'd102;
        6'd21: hz_lut = 8'd98;  6'd22: hz_lut = 8'd93;
        6'd23: hz_lut = 8'd89;  6'd24: hz_lut = 8'd85;
        6'd25: hz_lut = 8'd82;  6'd26: hz_lut = 8'd79;
        6'd27: hz_lut = 8'd76;  6'd28: hz_lut = 8'd73;
        6'd29: hz_lut = 8'd71;  6'd30: hz_lut = 8'd68;
        6'd31: hz_lut = 8'd66;  default: hz_lut = 8'd64;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        dst  <= D_IDLE; dcol <= 0; lcol <= 0; rptr <= 0;
        draw <= 0; hz_keep <= 0; xpos <= 0; ysub <= 0; hzoom <= 0;
        hflip<= 0; vflip <= 0; code <= 0; code_nx <= 0;
        lutcnt <= 0; nx_ok <= 0;
        d_ox <= 0; d_map <= 0; d_xsize <= 0; d_ysize <= 0; d_src <= 0;
        d_zx <= 0; d_col <= 0; d_fx <= 0; d_fy <= 0; d_pri <= 0;
    end else begin
        draw <= 0;
        // lookup RAM is registered: the code for the address set two edges ago
        if( !nx_ok ) begin
            lutcnt <= lutcnt + 2'd1;
            if( lutcnt==2'd1 ) begin code_nx <= lut_code; nx_ok <= 1; end
        end
        if( hs_pos ) begin
            dst <= D_IDLE; rptr <= 0;
        end else case( dst )
            D_IDLE: if( !fifo_empty ) begin
                { d_ox, d_map, d_xsize, d_ysize,
                  d_src, d_zx, d_fx, d_fy, d_pri, d_col } <= fifo_out;
                rptr   <= rptr + 1'd1;
                dcol   <= 0;    lcol  <= 0;
                lutcnt <= 0;    nx_ok <= 0;     // fetch column 0
                dst    <= D_ISSUE;
            end
            D_ISSUE: if( nx_ok && !busy && !draw ) begin
                draw    <= 1;
                code    <= code_nx;
                hz_keep <= dcol!=0;
                xpos    <= d_ox + xoffs;
                ysub    <= d_src[3:0];  // jtframe_draw applies vflip itself
                hzoom   <= hz_lut;
                hflip   <= d_fx;
                vflip   <= d_fy;
                // start the lookup for the next column while this one draws
                if( dcol!=d_xsize ) begin
                    lcol   <= dcol + 3'd1;
                    lutcnt <= 0;
                    nx_ok  <= 0;
                end
                dst <= D_UP;
            end
            D_UP:   if( busy  ) dst <= D_DOWN;
            D_DOWN: if( !busy ) begin
                if( dcol==d_xsize ) dst <= D_IDLE;
                else begin
                    dcol <= dcol + 3'd1;
                    dst  <= D_ISSUE;
                end
            end
            default: dst <= D_IDLE;
        endcase
    end
end

endmodule
