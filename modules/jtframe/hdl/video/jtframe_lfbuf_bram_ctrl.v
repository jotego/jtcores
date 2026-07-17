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
    Date: 20-11-2022 
    
    Adapted by @somhi for BRAM memory (tested in cyclone IV GX150 target)
    Date: 23-12-2023     */

module jtframe_lfbuf_bram_ctrl #(parameter
    CLK96   =   0,   // assume 48-ish MHz operation by default
    VW      =   8,
    HW      =   9,
    BRAM_HW =  HW
)(
    input               rst,    // hold in reset for >150 us
    input               clk,
    input               pxl_cen,

    input               lhbl,
    input               ln_done,
    input               fb_keep,
    input      [VW-1:0] vrender,
    input      [VW-1:0] ln_v,
    input               vs,
    // data written to external memory
    input               frame,
    input               fb_blank,
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

    // Status
    input       [7:0]   st_addr,
    output reg  [7:0]   st_dout
);

localparam AW=BRAM_HW+VW+1;
localparam [1:0] IDLE=0, READ=1, WRITE=2;
localparam [HW-1:0] EDGE_ADDR = {HW{1'b1}};
localparam       WRAP_EDGE = BRAM_HW < HW;
localparam [BRAM_HW-1:0] BRAM_LAST      = {BRAM_HW{1'b1}};
localparam [BRAM_HW-1:0] BRAM_PRE_LAST  = BRAM_LAST - {{(BRAM_HW-1){1'b0}}, 1'b1};
localparam [BRAM_HW-1:0] BRAM_EDGE_LOAD = BRAM_PRE_LAST - {{(BRAM_HW-1){1'b0}}, 1'b1};

reg           vsl, lhbl_l, ln_done_l, do_wr, rd_wait;
reg  [   1:0] st;
reg  [AW-1:0] act_addr;
wire [HW-1:0] nx_rd_addr, nx_req_addr;
wire [BRAM_HW-1:0] nx_req_bram_addr;
reg  [HW-1:0] hblen, hlim, hcnt, wr_addr;
wire          fb_clr_over, rd_over, wr_over, rd_wrap, wr_edge_load;
wire          bram_wr;
wire          fb_rd_bank, fb_wr_bank;
reg 		  bram_rd;
reg  [VW-1:0] wr_v;

wire   [AW-1:0] bram_addr;
wire   [15:0] bram_q;
wire   [15:0] bram_zero;
wire   [ 1:0] bram_we_mask;
wire   [ 1:0] bram_no_we;
reg           bram_we;

localparam [15:0] LFBUF_CLR = `ifndef JTFRAME_LFBUF_CLR 0 `else `JTFRAME_LFBUF_CLR `endif ;

assign fb_clr_over = &fb_addr;
assign rd_over     = &rd_addr[BRAM_HW-1:0];
assign wr_over     = &wr_addr[BRAM_HW-1:0];
assign bram_addr   = act_addr;
assign nx_rd_addr  = rd_addr + 1'd1;
assign nx_req_addr = nx_rd_addr + 1'd1;
assign bram_wr     = ~bram_we && (!fb_keep || fb_din != LFBUF_CLR);
assign bram_we_mask= {2{bram_wr}};
assign bram_no_we  = 2'b0;
assign bram_zero   = 16'd0;
assign fb_dout     = ~bram_we ? 16'd0    : bram_q;
assign fb_rd_bank  = fb_keep ? 1'b0 : ~frame;
assign fb_wr_bank  = fb_keep ? 1'b0 :  frame;
assign rd_wrap     = WRAP_EDGE && rd_addr[BRAM_HW-1:0] == BRAM_PRE_LAST;
assign wr_edge_load= WRAP_EDGE && wr_addr[BRAM_HW-1:0] == BRAM_EDGE_LOAD;

generate
    if( BRAM_HW < HW ) begin : gen_reduced_width
        assign nx_req_bram_addr = |nx_req_addr[HW-1:BRAM_HW] ?
            {BRAM_HW{1'b1}} : nx_req_addr[BRAM_HW-1:0];
    end else begin : gen_full_width
        assign nx_req_bram_addr = nx_req_addr[BRAM_HW-1:0];
    end
endgenerate

always @(posedge clk) begin
    case( st_addr[3:0] )
        0: st_dout <= { 2'd0, bram_we, bram_rd, 2'd0, st };
        1: st_dout <= { 3'd0, frame, fb_done, 1'd0, 1'd0, line };
        2: st_dout <= fb_din[7:0];
        3: st_dout <= fb_din[15:8];
        4: st_dout <= fb_din[7:0];
        5: st_dout <= fb_din[15:8];
        6: st_dout <= 0;
        7: st_dout <= 0;
        8: st_dout <= ln_v[7:0];
        9: st_dout <= vrender[7:0];
        default: st_dout <= 0;
    endcase
end

jtframe_dual_ram16 #(.AW(AW)) u_ram(
    .clk0       ( clk          ),
    .data0      ( fb_din       ),
    .addr0      ( bram_addr    ),
    .we0        ( bram_we_mask ),
    .q0         ( bram_q       ),

    .clk1       ( clk          ),
    .data1      ( bram_zero    ),
    .addr1      ( bram_addr    ),
    .we1        ( bram_no_we   ),
    .q1         (              )
);

always @( posedge clk ) begin
    if( rst ) begin
        hblen  <= 0;
        hlim   <= 0;
        hcnt   <= 0;
        lhbl_l <= 0;
        vsl    <= 0;
    end else if(pxl_cen) begin
        lhbl_l  <= lhbl;
        vsl     <= vs;
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

wire skip_blank_lines = do_wr && fb_blank;

always @( posedge clk ) begin
    if( rst ) begin
        bram_we  <= 1;
        bram_rd  <= 0;
        fb_addr  <= 0;
        fb_clr   <= 0;
        fb_done  <= 0;
        act_addr <= 0;
        rd_addr  <= 0;
        wr_addr  <= 0;
        rd_wait  <= 0;
        line     <= 0;
        scr_we   <= 0;
        ln_done_l<= 0;
        wr_v     <= 0;
        do_wr    <= 0;
        st       <= IDLE;
    end else begin
        fb_done <= 0;
        ln_done_l <= ln_done;
        if (ln_done && !ln_done_l ) begin
            do_wr <= 1;
            wr_v  <= ln_v;
        end
        if( fb_clr ) begin
            // the line is cleared outside the state machine so a
            // read operation can happen independently
            fb_addr <= fb_addr + 1'd1;
            if( fb_clr_over ) begin
                fb_clr  <= 0;
            end
        end
        case( st )
            IDLE: begin
                bram_we <= 1;
                bram_rd <= 0;
                rd_wait <= 0;
                scr_we   <= 0;
                if( lhbl_l & ~lhbl ) begin
                    act_addr <= { fb_rd_bank, vrender, {BRAM_HW{1'd0}}  };
                    bram_rd <= 1;
                    rd_addr  <= 0;
                    rd_wait  <= 1;
                    st       <= READ;
                end else if( skip_blank_lines ) begin
                    fb_done  <= 1;
                    do_wr    <= 0;
                end else if( do_wr && hcnt<hlim && lhbl ) begin // do not start too late so it doesn't run over H blanking
                    fb_addr  <= 1;
                    wr_addr  <= 0;
                    act_addr <= { fb_wr_bank, wr_v, {BRAM_HW{1'd0}}  };
                    bram_we  <= 0;
                    fb_clr   <= 0;
                    do_wr    <= 0;
                    st       <= WRITE;
                end
            end
            READ: begin
                bram_rd <= 1;
                scr_we  <= 1;
                if( rd_wait ) begin
                    rd_wait <= 0;
                    act_addr[BRAM_HW-1:0] <= nx_rd_addr[BRAM_HW-1:0];
                end else begin
                    rd_addr <= rd_wrap ? EDGE_ADDR : nx_rd_addr;
                    if( rd_over ) begin
                        scr_we <= 0;
                        st     <= IDLE;
                    end else begin
                        act_addr[BRAM_HW-1:0] <= nx_req_bram_addr;
                    end
                end
            end
            WRITE: begin
                act_addr[BRAM_HW-1:0] <= act_addr[BRAM_HW-1:0]+1'd1;
                wr_addr <= wr_addr + 1'd1;
                fb_addr <= wr_edge_load ? EDGE_ADDR : fb_addr + 1'd1;
                if( wr_over ) begin
                    bram_we <= 1;
                    fb_addr  <= 0;
                    line     <= ~line;
                    fb_done  <= 1;
                    fb_clr   <= 1;
                    st       <= IDLE;
                end
            end
            default: st <= IDLE;
        endcase
    end
end

endmodule
