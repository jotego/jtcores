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

    Author: niknak
    Version: 1.0
    Date: 2-8-2026 */

/*  JTSHARRIER — road / floor layer

    ATTRIBUTION
    -----------
    The per-scanline generator below is DERIVED FROM MAME source: it is a
    gate-for-gate transcription into Verilog of `segaic16_road_hangon_draw`
    (ROAD_SHARRIER) in segaic16_road.cpp.

        MAME segaic16_road.cpp
        license: BSD-3-Clause
        copyright-holders: Aaron Giles

    BSD-3-Clause is compatible with this core's GPL-3 and requires the copyright
    notice to be retained in redistributions. The same applies to
    jtsharrier_obj_scan.v and _obj_draw.v, whose sprite draw algorithm comes
    from sega16sp.cpp by the same author.

    Space Harrier's "road" draws the checkerboard ground and the solid background
    fill. Sim-verified bit-exact against a Python transcription of the MAME loop.

    colorbase1=0x038, colorbase2=0x7c0  (segahang.cpp segaic16_road_init).

    ARCHITECTURE
    ------------
    * Private roadram copy (jtframe_dual_ram16): the shared roadram in game.v has
      both ports taken (main=A, sub=B), so -- like jtoutrun_road -- this module
      keeps its own copy, written by snooping the CPU write streams, read by the
      engine. Main wins if both write on the same cycle; they do not race in
      practice.
    * Road GFX plane pre-fetch: to keep the per-pixel engine single-cycle, both
      planes for the byte we're about to need are pre-read into a small
      2-entry cache one road-byte ahead. The road ROM byte only changes every 8
      engine pixels (ctr9m wraps 0..7), so plane0 and plane1 are read across two
      of the eight slow cycles and held.

    TIMING
    ------
    The engine runs one scanline at road-pixel rate. It starts HROAD_WARM=24
    pixels before the visible line (MAME's `for x=-24`) so the 8-bit serial
    shifter 8J is warmed up. The pipeline is clocked on pxl_cen; the road ROM
    is read on pxl2_cen (2x) so both planes land before the pixel that needs them.
    Output: road_pal (11-bit palette index) + road_op (opaque) + road_fg (this is
    a foreground-road line, plycont!=0, for the mixer's layer order).
*/

module jtsharrier_road(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,

    input      [ 8:0] vrender,
    input      [ 8:0] hdump,
    input             hstart,
    input             LHBL,

    // CPU write snoop into the private roadram copy (word addr 0..0x3ff)
    input      [10:0] rr_main_addr,
    input      [15:0] rr_main_din,
    input      [ 1:0] rr_main_we,
    input      [10:0] rr_sub_addr,
    input      [15:0] rr_sub_din,
    input      [ 1:0] rr_sub_we,

    // road GFX ROM: two 16KB plane BRAMs, read together (one cycle, no 2-phase)
    output reg [13:0] road0_addr,
    input      [15:0] road0_data,   // interleaved word {plane1[P], plane0[P]}
                                    // (download packs both road planes as 16-bit)

    // to the mixer
    output reg [10:0] road_pal,
    output reg        road_op,
    output reg        road_fg,

    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout      // road ROM readback probe (debug_bus[7:5]==3'b110)
);

// ROAD ROM READBACK PROBE. debug_bus[7:5]==3'b110 overrides the road address and
// cycles 4 test addresses, read back via debug_view at debug_bus[2:0]:
//   0..3 -> road0_data[7:0]  (plane0)   expect 36 07 80 7f
//   4..7 -> road0_data[15:8] (plane1)   expect 00 00 00 00
// A byte-swapped download reads road0 = db f0 ff ff instead.
wire        probe_en = debug_bus[7:5]==3'b110;
reg  [13:0] probe_addr;
reg  [1:0]  probe_sel;
reg  [12:0] probe_cnt;
reg  [ 7:0] r0d0,r0d1,r0d2,r0d3, r1d0,r1d1,r1d2,r1d3;

always @(*) case(probe_sel)
    2'd0: probe_addr = 14'h0100;
    2'd1: probe_addr = 14'h0cfe;
    2'd2: probe_addr = 14'h1d87;
    default: probe_addr = 14'h3fe0;
endcase

always @(posedge clk) begin
    if( !probe_en ) begin
        probe_cnt <= 13'd0;
        probe_sel <= 2'd0;
    end else begin
        probe_cnt <= probe_cnt + 1'b1;
        if( &probe_cnt ) probe_sel <= probe_sel + 1'b1;   // next addr every 8192 clks
        if( probe_cnt==13'h1F00 ) begin                   // latch after data has settled
            case(probe_sel)
                2'd0: begin r0d0<=road0_data[7:0]; r1d0<=road0_data[15:8]; end
                2'd1: begin r0d1<=road0_data[7:0]; r1d1<=road0_data[15:8]; end
                2'd2: begin r0d2<=road0_data[7:0]; r1d2<=road0_data[15:8]; end
                default: begin r0d3<=road0_data[7:0]; r1d3<=road0_data[15:8]; end
            endcase
        end
    end
end

always @(*) case(debug_bus[2:0])
    3'd0: st_dout=r0d0; 3'd1: st_dout=r0d1; 3'd2: st_dout=r0d2; 3'd3: st_dout=r0d3;
    3'd4: st_dout=r1d0; 3'd5: st_dout=r1d1; 3'd6: st_dout=r1d2; default: st_dout=r1d3;
endcase

localparam [10:0] CB1 = 11'h038;
localparam [10:0] CB2 = 11'h7c0;
localparam [5:0]  WARM = 6'd24;

// ---------------- private roadram copy ----------------
wire [10:0] rr_waddr = |rr_main_we ? rr_main_addr : rr_sub_addr;
wire [15:0] rr_wdin  = |rr_main_we ? rr_main_din  : rr_sub_din;
wire [ 1:0] rr_we    = rr_main_we | rr_sub_we;
reg  [10:0] rr_raddr;
wire [15:0] rr_rdout;

jtframe_dual_ram16 #(.AW(11)) u_roadram_copy(
    .clk0 (clk), .clk1(clk),
    .addr0(rr_waddr), .data0(rr_wdin), .we0(rr_we), .q0(),
    .addr1(rr_raddr), .data1(16'd0),   .we1(2'b0),  .q1(rr_rdout)
);

// ---------------- engine ----------------
reg  [15:0] control, hpos, color0, color1, control_a;
reg  [ 7:0] line_sel;
reg  [ 2:0] ctr9m;
reg  [ 8:0] ctr9n9p;
reg         ff9j1, ff9j2;
reg  [ 7:0] ss8j;
reg  [ 2:0] ctr9m_d;
reg         ss8j0_d;
reg  signed [9:0] xpos;
reg  [ 3:0] st;
reg         warm;

localparam ST_IDLE=0, ST_A_HPOS=1, ST_L_CTRL=2, ST_W_HPOS=3, ST_L_HPOS=4,
           ST_L_COL0=5, ST_L_COL1=6, ST_PIX=7;

wire [7:0] idx    = control[7:0];
wire       is_fg  = (control[11:10] != 2'd0);
wire [5:0] byteidx= ctr9n9p[5:0];

// both planes at the same {line_sel, byteidx} address
always @(*) begin
    road0_addr = probe_en ? probe_addr : { line_sel, byteidx };
end

// --- constant-section signals (combinational, match C++ top-of-loop) ---
wire        ctr9n9p_ena = (ctr9m == 3'd7);
wire        carry_ff    = (ctr9n9p[7:0] == 8'hff);
wire        oe_active   = (ctr9n9p[7:6] == 2'b11);
wire        rom_ce      = ~control[9];
// road{0,1}_data have 1-cycle BRAM latency against the address formed from
// ctr9n9p/ctr9m this cycle. bitsel picks the bit within the 16-bit interleaved
// road byte, using the CURRENT ctr9m/ss8j. Verified 0-mismatch against MAME's
// segaic16_road_hangon_draw over two roadmaps; indexing with the delayed
// ctr9m_d/ss8j0_d instead shears the picture.
wire [2:0]  bitsel      = ss8j[0] ? (ctr9m ^ 3'd7) : ctr9m;
wire        sel         = ss8j[3];

// ff9j1 with the forced set/clear applied (as C++ does at top of loop, before use)
wire ff9j1_eff = !control[8] ? 1'b1 : (carry_ff ? 1'b0 : ff9j1);

// road{0,1}_data track byteidx with 1-cycle BRAM latency, but byteidx only
// changes every 8 pixels, so the data is stable well before it is used.
wire [1:0] md_raw = { road0_data[{1'b1,bitsel}], road0_data[{1'b0,bitsel}] };
wire [1:0] md     = (rom_ce && oe_active) ? md_raw : 2'd3;

// colour
reg [10:0] col;
reg        cop;
always @(*) begin
    if( ff9j2 && md==2'd3 ) begin
        col = CB2 | ((color0 >> (sel ? 0 : 8)) & 16'h3f);
        cop = 1'b1;
    end else begin
        col = CB1;
        cop = 1'b1;
        begin : mux
            reg [1:0] mdc; reg cbit;
            mdc = (color1[7] && md==2'd3) ? 2'd0 : md;
            cbit = (color1 >> ((mdc<<1) | sel)) & 1'b1;
            col  = CB1 | { 7'd0, sel, mdc, cbit };
        end
    end
    if( warm ) cop = 1'b0;
end

// ---- Road horizontal registration ---------------------------------------
// MAME draws road pixel x at screen column x (x from -24). HROAD_HOFF delays the
// road start so xpos 0..319 map onto screen columns 0..319; without it the
// left-hand pixels fall off-screen and the right-hand columns are never
// generated, leaving a seam. Tunable, in pixels, 1:1.
//
localparam [6:0] HROAD_HOFF = 7'd38;
reg  [6:0] hoff_cnt;
reg        hoff_arm, hstart_d;
always @(posedge clk, posedge rst) begin
    if( rst ) begin hoff_arm<=0; hoff_cnt<=0; hstart_d<=0; end
    else begin
        hstart_d <= 1'b0;
        if( hstart ) begin hoff_arm<=1'b1; hoff_cnt<=7'd0; end
        else if( hoff_arm && pxl_cen ) begin
            if( hoff_cnt==HROAD_HOFF-1 ) begin hstart_d<=1'b1; hoff_arm<=1'b0; end
            else hoff_cnt <= hoff_cnt + 1'b1;
        end
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st<=ST_IDLE; road_pal<=0; road_op<=0; road_fg<=0;
        ctr9m<=0; ctr9n9p<=0; ff9j1<=0; ff9j2<=1; ss8j<=0;
        xpos<=0; control<=0; hpos<=0; color0<=0; color1<=0; line_sel<=0;
        warm<=1; rr_raddr<=0; ctr9m_d<=0; ss8j0_d<=0;
    end else begin
        if( hstart_d ) begin
            rr_raddr <= { 3'd0, vrender[7:0] };   // issue control addr (idx 0x000)
            st       <= ST_A_HPOS;
            road_op  <= 0;
        end else case( st )
        // rr_raddr is registered AND the RAM read is registered => a value issued
        // in state N is valid on rr_rdout in state N+2. We pipeline: each state
        // issues the next address; latches happen 2 states after their issue.
        ST_A_HPOS: begin                          // control addr propagating
            control_a <= rr_rdout;                // (garbage; discarded)
            rr_raddr  <= {3'b001, 8'd0};          // placeholder; fixed in next
            st        <= ST_L_CTRL;
        end
        ST_L_CTRL: begin                          // rr_rdout = CONTROL now
            control  <= rr_rdout;
            line_sel <= rr_rdout[7:0];
            rr_raddr <= {3'b001, rr_rdout[7:0]};  // issue hpos
            st       <= ST_W_HPOS;
        end
        ST_W_HPOS: begin                          // hpos addr propagating
            rr_raddr <= {3'b010, control[7:0]};   // issue color0
            st       <= ST_L_HPOS;
        end
        ST_L_HPOS: begin                          // rr_rdout = HPOS now
            hpos     <= rr_rdout;
            rr_raddr <= {3'b011, control[7:0]};   // issue color1
            st       <= ST_L_COL0;
        end
        ST_L_COL0: begin                          // rr_rdout = COLOR0 now
            color0   <= rr_rdout;
            st       <= ST_L_COL1;
        end
        ST_L_COL1: begin                          // rr_rdout = COLOR1 now
            color1   <= rr_rdout;
            ctr9m   <= hpos[2:0];
            ctr9n9p <= {1'b0, hpos[10:3]};
            ff9j1   <= hpos[11];
            ff9j2   <= 1'b1;
            ss8j    <= 8'd0;
            xpos    <= -$signed({4'd0,WARM});
            warm    <= 1'b1;
            road_fg <= is_fg;
            st      <= ST_PIX;
        end
        // emit one pixel and clock the gate-level state, one cycle per pixel
        ST_PIX: if( pxl_cen ) begin
            road_pal <= col;
            road_op  <= cop;
            warm     <= (xpos + 1) < 0;
            xpos     <= xpos + 1'd1;

            // clock 9M; on wrap clock 9N/9P using the EFFECTIVE direction
            ctr9m_d <= ctr9m;        // align plane-data index to BRAM latency
            ss8j0_d <= ss8j[0];
            ctr9m <= ctr9m + 3'd1;
            if( ctr9n9p_ena )
                ctr9n9p <= ctr9n9p + (ff9j1_eff ? 9'd1 : -9'd1);
            // 9J upper + shifter (use ff9j1_eff, matching C++ which uses the
            // forced value for the rest of the iteration)
            ff9j2 <= (!ff9j1_eff && ss8j[7]) ? 1'b0 : 1'b1;
            ss8j  <= { ss8j[6:0], ff9j1_eff };
            ff9j1 <= ff9j1_eff;

            if( xpos >= $signed(10'sd319) ) st <= ST_IDLE;
        end
        default: st <= ST_IDLE;
        endcase
        // Blank the road outside the active line, on a WIDENED window.
        // LHBL here is preLHBL (high over hdump 0x0C0..0x1FF). The mixer's own
        // window is jtframe_blank's, 2 pixels later (0x0C2..0x071), and rgb lags
        // road_op by one pixel, so the road must be allowed to drive from the
        // early edge of preLHBL to the late edge of its delayed copy.
        // Clearing on raw preLHBL alone drops xpos 318/319 at the wrap; clearing
        // on the delayed copy alone moves both edges later and costs pixels at
        // the left. ORing the two widens the window at both ends.
        if( !(LHBL | lhbl_dly) ) road_op <= 1'b0;
    end
end

// preLHBL delayed by 2 pixel clocks, to match jtframe_blank's DLY=2 window.
reg [1:0] lhbl_sh;
wire      lhbl_dly = lhbl_sh[1];
always @(posedge clk, posedge rst) begin
    if( rst ) lhbl_sh <= 0;
    else if( pxl_cen ) lhbl_sh <= { lhbl_sh[0], LHBL };
end

endmodule
