/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-11-2026 */

module jtshdfrc_scroll(
    input                rst,
    input                clk,
    input                draw_start,
    input         [ 8:0] rline,
    input         [ 9:0] lb_ra,
    input         [ 8:0] scrx0, scry0, scrx1, scry1,

    output reg    [13:1] bg_addr,
    input         [15:0] bg_data,

    output        [20:2] scr_addr,
    output reg           scr_cs,
    input                scr_ok,
    input         [31:0] scr_data,
    output        [19:2] scr2_addr,
    output reg           scr2_cs,
    input                scr2_ok,
    input         [31:0] scr2_data,

    output        [10:0] lbg0,
    output        [ 9:0] lbg1
);

wire        rbank = rline[0];
reg  [ 9:0] bg_wa;
reg  [10:0] bg_wd;
reg         bg0_we, bg1_we;

jtframe_rpwp_ram #(
    .DW ( 11 ),
    .AW ( 10 )
) u_lbbg0(
    .clk     ( clk    ),
    .rd_addr ( lb_ra  ),
    .dout    ( lbg0   ),
    .wr_addr ( bg_wa  ),
    .din     ( bg_wd  ),
    .we      ( bg0_we )
);

jtframe_rpwp_ram #(
    .DW ( 10 ),
    .AW ( 10 )
) u_lbbg1(
    .clk     ( clk        ),
    .rd_addr ( lb_ra      ),
    .dout    ( lbg1       ),
    .wr_addr ( bg_wa      ),
    .din     ( bg_wd[9:0] ),
    .we      ( bg1_we     )
);

localparam B_IDLE=0, B_V0=1, B_V1=2, B_V2=3, B_RA=4, B_RW=5, B_HAND=7;
reg  [2:0]  bst;
reg         blayer;
reg  [4:0]  bk;
reg  [8:0]  bsx0, bsy0, bsx1, bsy1;
reg  [15:0] bw0;
reg  [13:0] bcode;
reg  [4:0]  bcolr;
reg         bfx;
reg  [3:0]  brow;
reg         brd;
reg  [31:0] bd0, bd1, bd2;
reg  [1:0]  bwait;
wire [8:0]  bsx = blayer ? bsx1 : bsx0;
wire [8:0]  bsy = blayer ? bsy1 : bsy0;
wire [8:0]  by  = rline + bsy;
wire [4:0]  btc = bsx[8:4] + bk;

assign scr_addr  = { bcode, brd, brow };
assign scr2_addr = { bcode, brow };

reg         dbusy, dlayer, dfx;
reg  [3:0]  di;
reg  [8:0]  dx0;
reg  [4:0]  dcol;
reg  [31:0] dd0, dd1, dd2;

always @* begin
    bg_addr = blayer ? { 3'b100, by[8:4], btc } : { 2'b00, by[8:4], btc, bst==B_V1 };
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bst <= B_IDLE; scr_cs <= 0; scr2_cs <= 0; dbusy <= 0; bg0_we <= 0; bg1_we <= 0;
    end else begin

        case( bst )
            B_IDLE: if( draw_start ) begin
                bsx0 <= scrx0; bsy0 <= scry0; bsx1 <= scrx1; bsy1 <= scry1;
                blayer <= 1; bk <= 0; bst <= B_V0;
            end
            B_V0: bst <= B_V1;
            B_V1: begin
                bw0 <= bg_data;
                bst <= blayer ? B_RA : B_V2;
                if( blayer ) begin
                    bcode <= { 2'd0, bg_data[11:0] };
                    bcolr <= { 1'b0, bg_data[15:12] };
                    bfx   <= 0;
                    brow  <= by[3:0];
                end
            end
            B_V2: begin
                bcode <= bg_data[13:0];
                bcolr <= bw0[4:0];
                bfx   <= bw0[6];
                brow  <= bw0[7] ? ~by[3:0] : by[3:0];
                bst   <= B_RA;
            end
            B_RA: begin
                scr_cs    <= 1;
                scr2_cs   <= 1;
                brd       <= 0;
                bwait     <= 2'd2;
                bst       <= B_RW;
            end
            B_RW: begin
                if( bwait!=0 ) bwait <= bwait - 2'd1;
                else begin
                    if( scr2_cs && scr2_ok ) begin bd2 <= scr2_data; scr2_cs <= 0; end
                    if( scr_cs && scr_ok ) begin
                        if( !brd ) begin
                            bd0      <= scr_data;
                            brd      <= 1;
                            bwait    <= 2'd2;
                        end else begin
                            bd1    <= scr_data;
                            scr_cs <= 0;
                        end
                    end
                    if( !scr_cs && !scr2_cs ) bst <= B_HAND;
                end
            end
            B_HAND: if( !dbusy ) begin

                dbusy  <= 1;
                dlayer <= blayer;
                dfx    <= bfx;
                di     <= 0;
                dx0    <= { bk, 4'd0 } - { 5'd0, bsx[3:0] };
                dcol   <= bcolr;
                dd0    <= bd0;
                dd1    <= bd1;
                dd2    <= bd2;
                if( bk==5'd20 ) begin
                    bk <= 0;
                    if( blayer ) begin blayer <= 0; bst <= B_V0; end
                    else bst <= B_IDLE;
                end else begin
                    bk  <= bk + 5'd1;
                    bst <= B_V0;
                end
            end
            default: bst <= B_IDLE;
        endcase

        bg0_we <= 0; bg1_we <= 0;
        if( dbusy ) begin : draw
            reg [3:0] sx;
            reg [2:0] j;
            reg       hh;
            reg [31:0] r01;
            reg [15:0] r2;
            reg [5:0] pen;
            sx  = dfx ? ~di : di;
            hh  = sx[3];
            j   = ~sx[2:0];
            r01 = hh ? dd1 : dd0;
            r2  = hh ? dd2[31:16] : dd2[15:0];
            pen = { r01[{2'd1,j}], r01[{2'd0,j}], r01[{2'd3,j}], r01[{2'd2,j}],
                    r2[{1'b1,j}], r2[{1'b0,j}] };
            bg_wa <= { rbank, dx0 + {5'd0, di} };
            bg_wd <= { dcol, pen };
            if( dlayer ) bg1_we <= 1; else bg0_we <= 1;
            di <= di + 4'd1;
            if( di==4'd15 ) dbusy <= 0;
        end
    end
end

endmodule
