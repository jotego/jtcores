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

    Author: Gyorgy Szombathelyi
    Version: 1.0
    Date: 27-03-2024 */

/*
    This module uses an SDRAM module for framebuffer.
    Each row contain one line, and the row content is bursted out to line buffers.
    As every used row is opened in every frame, there's no need to explicit refresh.
*/
/* verilator lint_off MODDUP */
module jtframe_lfbuf_sdr_ctrl #(parameter
    CLK96   =   0,   // assume 48-ish MHz operation by default
    VW      =   8,
    HW      =   9
)(
    input               rst,    // hold in reset for >150 us
    input               clk,
    input               pxl_cen,

    input               lhbl,
    input               ln_done,
    input      [VW-1:0] vrender,
    input      [VW-1:0] ln_v,
    input               vs,
    // data written to external memory
    input               frame,
    output reg [HW-1:0] fb_addr,
    input      [  15:0] fb_din,
    output reg          fb_clr,
    output reg          fb_done,

    // data read from external memory to screen buffer
    // during h blank
    output     [  15:0] fb_dout,
    output reg [HW-1:0] rd_addr,
    output reg          line,
    output reg          scr_we,

    input               init_n,
    output reg   [12:0] SDRAM_A,
    inout        [15:0] SDRAM_DQ,
    output reg          SDRAM_DQML,
    output reg          SDRAM_DQMH,
    output              SDRAM_nWE,
    output              SDRAM_nCAS,
    output              SDRAM_nRAS,
    output              SDRAM_nCS,
    output        [1:0] SDRAM_BA,
    output              SDRAM_CKE,

    // Status
    input       [7:0]   st_addr,
    output reg  [7:0]   st_dout
);

localparam AW=HW+VW+1;
localparam [2:0] IDLE=0, READ1=1, WRITE1=2, READ=3, WRITE=4;

localparam RASCAS_DELAY   = 3'd2;   // tRCD=20ns -> 2 cycles@<100MHz
localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH};

// all possible commands
localparam CMD_INHIBIT         = 4'b1111;
localparam CMD_NOP             = 4'b0111;
localparam CMD_ACTIVE          = 4'b0011;
localparam CMD_READ            = 4'b0101;
localparam CMD_WRITE           = 4'b0100;
localparam CMD_BURST_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE       = 4'b0010;
localparam CMD_AUTO_REFRESH    = 4'b0001;
localparam CMD_LOAD_MODE       = 4'b0000;

reg           lhbl_l, ln_done_l, do_wr;
reg  [   2:0] st;
reg  [HW-1:0] act_addr;
wire [HW-1:0] nx_rd_addr;
reg  [HW-1:0] hblen, hlim, hcnt;
wire          fb_over;
reg           sdram_init = 1;
reg     [6:0] sdram_init_st = 0;
reg    [15:0] sdram_din;
reg    [15:0] sdram_dout;
reg           sdram_oe;
reg     [3:0] sdram_cmd = CMD_NOP;
reg     [1:0] sdram_del;
reg           sdram_prechg;

assign SDRAM_CKE = 1;
assign SDRAM_BA = 0;
assign SDRAM_DQ = sdram_oe ? sdram_din : 16'hZZZZ;
assign SDRAM_nCS  = sdram_cmd[3];
assign SDRAM_nRAS = sdram_cmd[2];
assign SDRAM_nCAS = sdram_cmd[1];
assign SDRAM_nWE  = sdram_cmd[0];

assign fb_over    = &fb_addr;
assign fb_dout    = sdram_dout[15:0];

always @(posedge clk) begin
    case( st_addr[3:0] )
        0: st_dout <= { 2'd0, 1'b0, 2'd0, st };
        1: st_dout <= { 3'd0, frame, fb_done, 1'b0, 1'b0, line };
        2: st_dout <= fb_din[7:0];
        3: st_dout <= fb_din[15:8];
        4: st_dout <= sdram_din[7:0];
        5: st_dout <= sdram_din[15:8];
        6: st_dout <= sdram_dout[7:0];
        7: st_dout <= sdram_dout[15:8];
        8: st_dout <= ln_v[7:0];
        9: st_dout <= vrender[7:0];
        default: st_dout <= 0;
    endcase
end

always @( posedge clk, posedge rst ) begin
    if( rst ) begin
        hblen  <= 0;
        hlim   <= 0;
        hcnt   <= 0;
        lhbl_l <= 0;
    end else if(pxl_cen) begin
        lhbl_l  <= lhbl;
        hcnt    <= hcnt+1'd1;
        if( ~lhbl & lhbl_l ) begin // enters blanking
            hcnt   <= 0;
            hlim   <= hcnt - hblen; // H limit below which we allow do_wr events
        end
        if( lhbl & ~lhbl_l ) begin // leaves blanking
            hblen <= hcnt;
        end
    end
end

always @( posedge clk, posedge rst ) begin
    if( rst ) begin
        fb_addr  <= 0;
        fb_clr   <= 0;
        fb_done  <= 0;
        act_addr <= 0;
        rd_addr  <= 0;
        line     <= 0;
        scr_we   <= 0;
        ln_done_l<= 0;
        do_wr    <= 0;
        st       <= IDLE;
        sdram_cmd <= CMD_NOP;
        sdram_oe  <= 0;
        { SDRAM_DQML, SDRAM_DQMH } <= 2'b11;
        sdram_init_st <= 0;
    end else begin
        sdram_dout  <= SDRAM_DQ;
        sdram_cmd   <= CMD_NOP;
        sdram_oe    <= 0;
        { SDRAM_DQML, SDRAM_DQMH } <= 2'b11;

        fb_done <= 0;
        ln_done_l <= ln_done;
        if (ln_done && !ln_done_l ) do_wr <= 1;
        if( fb_clr ) begin
            // the line is cleared outside the state machine so a
            // read operation can happen independently
            fb_addr <= fb_addr + 1'd1;
            if( fb_over ) begin
                fb_clr  <= 0;
            end
        end
        case( st )
            IDLE: begin
                if (sdram_init) begin
                    sdram_init_st <= sdram_init_st + 1'd1;
                    if (sdram_init_st[2:0] == 0) begin
                        case (sdram_init_st[6:3])
                        0: begin
                            sdram_cmd <= CMD_PRECHARGE;
                            SDRAM_A[10] <= 1;
                        end
                        5,7: begin
                            sdram_cmd <= CMD_AUTO_REFRESH;
                        end
                        13: begin
                            sdram_cmd <= CMD_LOAD_MODE;
                            SDRAM_A <= MODE;
                        end
                        15: sdram_init <= 0;
                        default: ;
                        endcase
                    end
                end
                else begin
                    scr_we   <= 0;
                    sdram_prechg <= 0;
                    if( lhbl_l & ~lhbl ) begin
                        act_addr <= 0;
                        rd_addr  <= 0;
                        SDRAM_A  <= { ~frame, vrender };
                        sdram_cmd<= CMD_ACTIVE;
                        sdram_del<= 3;
                        st       <= READ1;
                    end else if( do_wr && !fb_clr &&
                        hcnt<hlim && lhbl ) begin // do not start too late so it doesn't run over H blanking
                        fb_addr  <= 0;
                        act_addr <= 0;
                        SDRAM_A  <= { frame, ln_v };
                        sdram_cmd<= CMD_ACTIVE;
                        do_wr    <= 0;
                        st       <= WRITE1;
                    end
                end
            end

            READ1: st <= READ;
            READ: begin
                SDRAM_A <= act_addr;

                if ( !sdram_prechg ) begin
                    sdram_cmd <= CMD_READ;
                    { SDRAM_DQML, SDRAM_DQMH } <= 2'b00;
                end

                if( sdram_del == 0 ) begin
                    scr_we <= 1;
                    rd_addr <= rd_addr + 1'd1;
                    if( &rd_addr ) begin
                        st <= IDLE;
                    end
                end
                else
                    sdram_del <= sdram_del - 1'd1;

                if ( &act_addr ) begin
                    SDRAM_A[10] <= 1;
                    sdram_prechg <= 1;
                end
                else
                    act_addr <= act_addr + 1'd1;
            end

            WRITE1: begin
                fb_addr <= fb_addr + 1'd1;
                st <= WRITE;
            end

            WRITE: begin
                SDRAM_A <= fb_addr - 1'd1;
                { SDRAM_DQML, SDRAM_DQMH } <= 2'b00;
                sdram_cmd <= CMD_WRITE;
                sdram_oe <= 1;
                sdram_din <= fb_din;
                if ( &fb_addr ) begin
                    SDRAM_A[10] <= 1;
                    fb_done <= 1;
                    fb_clr  <= 1;
                    line    <= ~line;
                    st      <= IDLE;
                end
                fb_addr <= fb_addr +1'd1;
            end

            default: st <= IDLE;
        endcase
    end
end

endmodule