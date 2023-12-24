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

    // Status
    input       [7:0]   st_addr,
    output reg  [7:0]   st_dout
);

localparam AW=HW+VW+1;
localparam [1:0] IDLE=0, READ=1, WRITE=2;

reg           vsl, lhbl_l, ln_done_l, do_wr;
reg  [   1:0] st;
reg  [AW-1:0] act_addr;
wire [HW-1:0] nx_rd_addr;
reg  [HW-1:0] hblen, hlim, hcnt;
wire          fb_over;
reg 		  bram_rd;

reg    [15:0] ram[(2**AW)-1:0];
wire   [20:0] bram_addr;
wire   [15:0] bram_data;   
reg    [15:0] douta;
reg           bram_we;	

always @(posedge clk)
    if (~bram_we)
        ram[bram_addr] <= bram_data;
    else
        douta <= ram[bram_addr];

assign fb_over    = &fb_addr;
assign bram_addr  = act_addr;
assign nx_rd_addr = rd_addr + 1'd1;
assign bram_data  = bram_we  ? 16'hzzzz : fb_din;
assign fb_dout    = ~bram_we ? 16'd0    : douta;

always @(posedge clk) begin
    case( st_addr[3:0] )
        0: st_dout <= { 2'd0, bram_we, bram_rd, 2'd0, st };
        1: st_dout <= { 3'd0, frame, fb_done, 1'd0, 1'd0, line };
        2: st_dout <= fb_din[7:0];
        3: st_dout <= fb_din[15:8];
        4: st_dout <= bram_data[7:0];
        5: st_dout <= bram_data[15:8];
        6: st_dout <= 0;
        7: st_dout <= 0;
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

always @( posedge clk, posedge rst ) begin
    if( rst ) begin
        bram_we  <= 1;
        bram_rd  <= 0;
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
    end else begin
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
                bram_we <= 1;
                bram_rd <= 0;
                scr_we   <= 0;
                if( lhbl_l & ~lhbl ) begin
                    act_addr <= { ~frame, vrender, {HW{1'd0}}  };
                    bram_rd <= 1;
                    rd_addr  <= 0;
                    scr_we   <= 1;
                    st       <= READ;
                end else if( do_wr && !fb_clr &&
                    hcnt<hlim && lhbl ) begin // do not start too late so it doesn't run over H blanking
                    fb_addr  <= 0;
                    act_addr <= {  frame, ln_v, {HW{1'd0}}  };
                    bram_we  <= 0;
                    do_wr    <= 0;
                    st       <= WRITE;
                end
            end
            READ: begin
                bram_rd <= 0;
                rd_addr <= nx_rd_addr;
                if( &rd_addr ) st <= IDLE;
                else act_addr[HW-1:0] <= nx_rd_addr;
                bram_rd <= 1;
            end
            WRITE: begin
                act_addr[HW-1:0] <= act_addr[HW-1:0]+1'd1;
                fb_addr <= fb_addr +1'd1;
                if( fb_over ) begin
                    bram_we <= 1;
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
