/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Sprites. Object RAM (512 entries of four words) is copied into a frame
 * buffer when vertical blanking starts. During each line the copy is scanned
 * from entry 511 down to 0 and the sprites covering the next line are drawn
 * into a line buffer, later entries overwriting earlier ones so entry 0 wins.
 * The display side reads the other line buffer and clears it behind the read.
 *
 * Entry words: 0 code[10:0]; 1 attr = colour[5:0], flipx bit 8, flipy bit 9,
 * prio[11:10]; 2 x<<7; 3 y<<7. Screen x = x-32 (a further -14 when flipped in
 * x), y = y-16; y == 0x100 hides the sprite and prio 0 skips it.
 *
 * Time per line is 446 pixels x 6 clocks = 2676: the scan reads only the y
 * word, one entry a clock (512), and each sprite on the line costs about 30
 * more, so some 70 sprites per line fit; beyond that `ovf` latches and the
 * rest are dropped.
 */

module jtwardner_obj(
    input             rst, clk, pxl_cen,
    input             LVBL,
    input      [ 8:0] hdump, vrender,
    output reg [10:0] ram_addr,
    input      [15:0] ram_q,
    output reg [15:0] rom_addr,
    input      [31:0] rom_data,
    output reg        rom_cs,
    input             rom_ok,
    output reg [12:0] pxl,
    output reg        ovf
);

// ---- frame copy of the object RAM, 2048 clocks from the fall of LVBL
reg  [15:0] frame[0:2047];
reg  [15:0] frame_q;
reg  [10:0] cp, cp_addr;
reg         copying, LVBL_l, we1, we2;
reg  [10:0] frd_addr;

always @(posedge clk) begin
    ram_addr <= cp;
    cp_addr  <= ram_addr;
    we1      <= copying;
    we2      <= we1;
    if( we2 ) frame[cp_addr] <= ram_q;      // ram_q is one clock behind ram_addr
    frame_q  <= frame[frd_addr];
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        copying <= 0; cp <= 0; LVBL_l <= 1;
    end else begin
        LVBL_l <= LVBL;
        if( LVBL_l && !LVBL ) begin
            copying <= 1;
            cp      <= 0;
        end else if( copying ) begin
            cp <= cp + 11'd1;
            if( cp == 11'd2047 ) copying <= 0;
        end
    end
end

// ---- line buffer. jtframe_obj_buffer is the same two-line arrangement, but
//      built on jtframe_dual_ram: one port writes the line being drawn and
//      reads back what is already there, the other reads the line being shown
//      and blanks it behind the read. Written by hand it needed two write
//      ports on one array, which Quartus could only build out of logic.
//
//      The module swaps the two lines on the falling edge of its LHBL input.
//      This core swaps at the last count of the line, where the renderer also
//      starts, so it is handed a signal that falls there rather than the real
//      LHBL, which falls at 319.
reg  [ 8:0] wr_x;
reg  [12:0] wr_d;
reg         wr_en;
wire        start = pxl_cen && hdump == 9'd445;   // next count is pixel 0
wire [12:0] lbuf_q;

jtframe_obj_buffer #(.DW(13),.AW(9),.ALPHAW(4),.ALPHA(13'd0)) u_lbuf(
    .clk     ( clk               ),
    .LHBL    ( hdump != 9'd445   ),
    .flip    ( 1'b0              ),
    .wr_data ( wr_d              ),
    .wr_addr ( wr_x              ),
    .we      ( wr_en             ),
    .rd_addr ( hdump             ),
    .rd      ( pxl_cen           ),
    .rd_data ( lbuf_q            )
);

always @(posedge clk, posedge rst) begin
    if( rst ) pxl <= 0; else pxl <= lbuf_q;
end

// ---- renderer. Scans entry 511 down to 0 reading the y word, one entry a
//      clock through a small pipeline; on a hit it fetches attr, code and x,
//      two ROM words, and writes the 16 pixels one a clock.
reg  [ 3:0] st;
reg  [ 9:0] entry;            // bit 9 set once entry 0 has been issued
reg  [ 8:0] hit_e, e1, e2;
reg         v1, v2;           // a y word is in flight
reg  [15:0] w_code, w_attr, w_x, w_y;
reg  [ 8:0] ly;               // line being rendered
reg  [31:0] half0, half1;
reg  [ 4:0] pcnt;
reg         busy;
reg [511:0] touched;          // pixels of the write line any sprite has hit

wire [ 8:0] sy    = w_y[15:7];
wire [ 8:0] sx    = w_x[15:7];
wire        flipx = w_attr[8], flipy = w_attr[9];
wire [ 1:0] prio  = w_attr[11:10];
wire [ 8:0] ydiff = ly - (sy - 9'd16);
// hit test on the y word as it arrives
wire [ 8:0] q_sy   = frame_q[15:7];
wire [ 8:0] q_diff = ly - (q_sy - 9'd16);
wire        yhit   = q_sy != 9'h100 && q_diff < 9'd16;
wire [ 8:0] x0    = sx - 9'd32 - (flipx ? 9'd14 : 9'd0);
wire [ 3:0] srow  = flipy ? ~ydiff[3:0] : ydiff[3:0];
wire [ 3:0] pix_i = flipx ? ~pcnt[3:0] : pcnt[3:0];
wire [31:0] half  = pix_i[3] ? half1 : half0;
wire [ 2:0] psh   = ~pix_i[2:0];
wire [ 7:0] hf3 = half[31:24], hf2 = half[23:16], hf1 = half[15:8], hf0 = half[7:0];
// MAME lists planeoffset from the most significant pen bit down, so the pen is
// assembled from the low byte of the ROM word upwards, not the other way round
wire [ 3:0] pen   = { hf0[psh], hf1[psh], hf2[psh], hf3[psh] };
wire [ 8:0] px    = x0 + {5'd0, pcnt[3:0]};

localparam SCAN=0, DRAIN=1, FETCH0=2, FETCH1=3, FETCH2=4, FETCH3=5,
           FETCH4=6, ROM0=7, ROM1=8, DRAW=9, NEXT=10;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st <= SCAN; entry <= 0; busy <= 0; rom_cs <= 0; wr_en <= 0; ovf <= 0;
        frd_addr <= 0; rom_addr <= 0; wr_x <= 0; wr_d <= 0; pcnt <= 0;
        w_code <= 0; w_attr <= 0; w_x <= 0; w_y <= 0; ly <= 0;
        half0 <= 0; half1 <= 0; touched <= 0; hit_e <= 0; e1 <= 0; e2 <= 0;
        v1 <= 0; v2 <= 0;
    end else begin
        wr_en <= 0;
        if( start ) begin
            ly      <= vrender;
            entry   <= 10'd511;
            v1      <= 0; v2 <= 0;
            touched <= 0;
            // only visible lines need sprites; the frame copy takes the
            // beginning of line 240 and nothing reads the copy then
            busy    <= vrender < 9'd240;
            st      <= SCAN;
            rom_cs  <= 0;
            if( busy ) ovf <= 1;                // previous line not finished
        end else if( busy ) begin
            // data pipeline, two clocks behind the address
            v2 <= v1; e2 <= e1;
            case( st )
                SCAN: begin
                    frd_addr <= { entry[8:0], 2'd3 };
                    v1 <= 1;
                    e1 <= entry[8:0];
                    entry <= entry - 10'd1;
                    if( entry == 10'd0 ) st <= DRAIN;
                    if( v2 && yhit ) begin
                        w_y   <= frame_q;
                        hit_e <= e2;
                        v1    <= 0; v2 <= 0;
                        st    <= FETCH0;
                    end
                end
                DRAIN: begin                    // last two words still in flight
                    v1 <= 0;
                    if( v2 ) begin
                        if( yhit ) begin
                            w_y   <= frame_q;
                            hit_e <= e2;
                            v2    <= 0;
                            st    <= FETCH0;
                        end else if( !v1 ) busy <= 0;
                    end else if( !v1 ) busy <= 0;
                end
                // attr, code and x of the hit entry
                FETCH0: begin frd_addr <= {hit_e, 2'd1}; st <= FETCH1; end
                FETCH1: begin frd_addr <= {hit_e, 2'd0}; st <= FETCH2; end
                FETCH2: begin frd_addr <= {hit_e, 2'd2}; w_attr <= frame_q; st <= FETCH3; end
                FETCH3: begin
                    w_code <= frame_q;
                    // priority 0 entries are skipped
                    st     <= prio == 2'd0 ? NEXT : FETCH4;
                end
                FETCH4: begin
                    w_x      <= frame_q;
                    rom_addr <= { w_code[10:0], srow, 1'b0 };
                    rom_cs   <= 1;
                    st       <= ROM0;
                end
                ROM0: if( rom_ok ) begin
                    half0    <= rom_data;
                    rom_addr <= { w_code[10:0], srow, 1'b1 };
                    st       <= ROM1;
                end
                ROM1: if( rom_ok ) begin
                    half1  <= rom_data;
                    rom_cs <= 0;
                    pcnt   <= 0;
                    st     <= DRAW;
                end
                DRAW: begin
                    // pen 0 leaves the buffer alone. MAME marks every
                    // touched pixel priority 31 whether it drew or not, so a
                    // pixel hit twice is never hidden: that is the multi bit
                    if( pen != 4'd0 && px < 9'd320 ) begin
                        wr_x        <= px;
                        wr_d        <= { touched[px], prio, w_attr[5:0], pen };
                        wr_en       <= 1;
                        touched[px] <= 1;
                    end
                    pcnt <= pcnt + 5'd1;
                    if( pcnt == 5'd15 ) st <= NEXT;
                end
                NEXT: begin
                    // resume the scan below the sprite just drawn
                    if( hit_e == 9'd0 ) busy <= 0;
                    entry <= {1'b0, hit_e} - 10'd1;
                    st    <= SCAN;
                end
                default: st <= SCAN;
            endcase
        end
    end
end

endmodule
