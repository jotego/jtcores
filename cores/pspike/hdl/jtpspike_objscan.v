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

module jtpspike_objscan(
    input             rst,
    input             clk,
    input             hs,
    input             scan_en,     // held low when the second chip is unused
    input      [ 8:0] vrender,
    input      [ 8:0] yoffs,       // vsystem_spr2 set_offsets y, signed
    input             flip,
    input      [ 1:0] objbank,

    // sprite RAM
    output     [ 9:1] objr_addr,
    input      [15:0] objr_dout,
    // tile code lookup RAM
    input             wide_lut,   // karatblz LUTs are 64kB, others 16kB
    output     [14:0] objl_addr,
    input      [15:0] objl_dout,

    // jtframe_objdraw
    output reg        draw,
    input             busy,
    output     [12:0] code,
    output reg [ 8:0] xpos,
    output reg [ 3:0] ysub,
    output reg [ 7:0] hzoom,
    output reg        hz_keep,
    output reg        hflip, vflip,
    output     [ 6:0] pal
);

localparam [8:0] LAST = 9'h1f8, PTR = 9'h1fe;

reg  [ 4:0] st;
reg  [ 8:0] first, slot;
reg         pass, hs_l;
reg  [15:0] w0, w1, w2, w3;
reg  [ 2:0] col;
reg  [ 7:0] src;
reg  [ 8:0] rd_addr;

wire [ 8:0] oy      = w0[8:0];
wire [ 8:0] ox      = w1[8:0];
wire [ 2:0] xsize   = w2[10:8];
wire [ 2:0] ysize   = w2[14:12];
wire        en      = w2[7];
wire        pri     = w2[4];
wire        fx      = w2[11];
wire        fy      = w2[15];
wire [ 5:0] zy      = 6'd32 - {2'd0,w0[15:12]};
wire [ 5:0] zx      = 6'd32 - {2'd0,w1[15:12]};

// how many lines the whole block covers, and where this line falls in it
wire [ 9:0] blk_h   = (({6'd0,ysize}+10'd1)*{4'd0,zy}) >> 1;
wire [ 8:0] dy      = vrender + 9'd16 - (oy + yoffs + 9'd16);
wire        on_line = dy < blk_h[8:0];
wire [ 3:0] row     = src[7:4];
// the map advances with the unflipped index, the position uses the flipped one
wire [ 2:0] maprow  = fy ? ysize - row[2:0] : row[2:0];
wire [ 2:0] mapcol  = fx ? xsize - col      : col;
// the map row stride is the next power of two of xsize+1
wire [ 3:0] stride  = xsize<3'd1 ? 4'd1 : xsize<3'd2 ? 4'd2 :
                      xsize<3'd4 ? 4'd4 : 4'd8;
wire [15:0] mapidx  = w3 + {12'd0,maprow}*{12'd0,stride} + {13'd0,mapcol};

assign objr_addr = rd_addr;
assign objl_addr = wide_lut ? mapidx[14:0] : { 2'd0, mapidx[12:0] };

`ifdef SIMULATION
reg [3:0] zxmin=4'hf, zxmax=0, zymin=4'hf, zymax=0;
always @(posedge clk) if( draw ) begin
    if( w1[15:12] < zxmin ) zxmin <= w1[15:12];
    if( w1[15:12] > zxmax ) zxmax <= w1[15:12];
    if( w0[15:12] < zymin ) zymin <= w0[15:12];
    if( w0[15:12] > zymax ) zymax <= w0[15:12];
end
always @(negedge hs) if( $time > 200000000 )
    $display("%m zoom nibble x=%0h..%0h y=%0h..%0h -> zx=%0d..%0d hzoom=%0d",
        zxmin, zxmax, zymin, zymax, 6'd32-{2'd0,zxmax}, 6'd32-{2'd0,zxmin}, hzoom);
`endif
assign code      = objl_dout[12:0];
// the pri bit rides along with the pixel so the mixer can use it
assign pal       = { pri, objbank, w2[3:0] };

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

// 2048/zx, the source step jtframe_draw subtracts per output pixel
reg [7:0] hz_lut;
always @* begin
    case( zx )
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

wire [16:0] prod = {8'd0,dy} * {8'd0,recip};

always @(posedge clk) begin
    if( rst ) begin
        st      <= 0;
        draw    <= 0;
        slot    <= LAST;
        first   <= 0;
        pass    <= 0;
        col     <= 0;
        rd_addr <= 0;
        hz_keep <= 0;
        xpos    <= 0;
        ysub    <= 0;
        hzoom   <= 0;
        hflip   <= 0;
        vflip   <= 0;
        src     <= 0;
    end else begin
        hs_l <= hs;
        draw <= 0;
        // Restart on every HS from whatever state we were in. A line that runs
        // out of time simply drops the sprites it did not reach, like the real
        // chip, instead of losing sync for every following line
        if( hs & ~hs_l ) begin
            rd_addr <= PTR;
            st      <= scan_en ? 5'd1 : 5'd0;
        end else case( st )
            0: ;                            // idle until the next HS
            1: st <= 2;                     // BRAM latency
            2: st <= 3;
            3: begin
                first <= {objr_dout[6:0],2'd0} > LAST ? LAST : {objr_dout[6:0],2'd0};
                pass  <= 0;
                slot  <= {objr_dout[6:0],2'd0} > LAST ? LAST : {objr_dout[6:0],2'd0};
                st    <= 4;
            end
            // Read the four attribute words. The RAM registers its output, so
            // the word for the address issued in state N lands in state N+2
            4: begin rd_addr <= slot;      st <= 5; end
            5: begin rd_addr <= slot|9'd1; st <= 6; end
            6: begin rd_addr <= slot|9'd2; st <= 7; w0 <= objr_dout; end
            7: begin rd_addr <= slot|9'd3; st <= 8; w1 <= objr_dout; end
            8: begin st <= 9;  w2 <= objr_dout; end
            9: begin st <= 10; w3 <= objr_dout; end
            10: begin
                src <= prod[15:8];
                col <= 0;
                st  <= (en && pri==pass && on_line) ? 11 : 15;
            end
            // One draw per tile column, left to right so the zoom accumulator
            // runs across the whole block. States 11-12 wait for the lookup
            // RAM to answer with the tile code for this column
            11: st <= 12;
            12: st <= 13;
            13: if( !busy && !draw ) begin
                draw    <= 1;
                hz_keep <= col!=0;
                xpos    <= ox;
                ysub    <= src[3:0];    // jtframe_draw applies vflip itself
                hzoom   <= hz_lut;
                hflip   <= fx;
                vflip   <= fy;
                st      <= 14;
            end
            14: if( busy ) st <= 16;
            16: if( !busy ) begin
                if( col==xsize ) st <= 15;
                else begin
                    col <= col + 3'd1;
                    st  <= 11;
                end
            end
            15: begin
                if( slot==LAST ) begin
                    if( pass==1 ) st <= 0;  // both passes done
                    else begin
                        pass <= 1;
                        slot <= first;
                        st   <= 4;
                    end
                end else begin
                    slot <= slot + 9'd4;
                    st   <= 4;
                end
            end
            default: st <= 0;
        endcase
    end
end

`ifdef SIMULATION
// Is the scan finishing inside the line? If HS arrives while st!=0 the list
// was truncated, and the sprites lost are the ones drawn last - the pri==0
// pass, i.e. exactly those that should be on top.
integer trunc_lines, total_lines, draws, max_draws;
always @(posedge clk) begin
    if( rst ) begin
        trunc_lines <= 0; total_lines <= 0; draws <= 0; max_draws <= 0;
    end else begin
        if( draw ) draws <= draws+1;
        if( hs & ~hs_l ) begin
            total_lines <= total_lines+1;
            if( st != 0 ) trunc_lines <= trunc_lines+1;
            if( draws > max_draws ) max_draws <= draws;
            draws <= 0;
        end
        if( total_lines==262 ) begin
            $display("%m objscan: %0d of %0d lines truncated, peak %0d draws/line",
                     trunc_lines, total_lines, max_draws);
            trunc_lines <= 0; total_lines <= 0; max_draws <= 0;
        end
    end
end
`endif

endmodule
