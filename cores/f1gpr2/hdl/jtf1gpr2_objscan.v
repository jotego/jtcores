/*  SPDX-FileCopyrightText: © 2026 Andrea Bogazzi
    SPDX-License-Identifier: GPL-3.0-or-later
    Date: 25-10-2026 */

module jtf1gpr2_objscan #(parameter ATTR_AW=11, LUT_AW=14)(
    input             rst,
    input             clk,
    input             hs,
    input      [ 8:0] vrender,
    input      [ 8:0] xoffs,
    input      [ 8:0] yoffs,
    input             flip,

    output     [ATTR_AW:1] objr_addr,
    input      [15:0] objr_dout,
    output     [LUT_AW:1] objl_addr,
    input      [15:0] objl_dout,

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

localparam RECW = 52, FW = 3;

reg  [ 2:0] st;
reg  [ 9:0] sort_addr, attr_addr;
reg         issuing, hs_l;
reg  [ 1:0] acnt1, acnt2;
reg         iss1, iss2;
reg  [15:0] w0, w1, w2;

wire        hs_pos  = hs & ~hs_l;
reg  [15:0] w3;
wire [ 8:0] oy      = w0[8:0];
wire [ 8:0] ox      = w1[8:0];
wire [ 2:0] xsize   = (w1[11:9]);
wire [ 2:0] ysize   = (w0[11:9]);
wire [ 3:0] zy_raw  = w0[15:12];
wire [ 3:0] zx_raw  = w1[15:12];
wire [ 5:0] zy      = 6'd32 - {2'd0,zy_raw};
wire        fx      = w2[14];
wire        fy      = w2[15];
wire [ 5:0] color   = w2[13:8];
wire [16:0] map_base= { w2[0], w3 };

wire [ 9:0] blk_h   = (({6'd0,ysize}+10'd1)*{4'd0,zy}) >> 1;
wire [ 8:0] dy      = vrender + 9'd16 - (oy + yoffs + 9'd16);
wire        on_line  = dy < blk_h[8:0];

reg  [ATTR_AW-1:0] rd_addr;
assign objr_addr = rd_addr;

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

// FIFO
reg  [RECW-1:0] fifo[0:(1<<FW)-1];
reg  [FW:0]     wptr, rptr;
wire            fifo_empty = wptr==rptr;
wire            fifo_full  = wptr[FW-1:0]==rptr[FW-1:0] && wptr[FW]!=rptr[FW];
wire [RECW-1:0] fifo_out   = fifo[rptr[FW-1:0]];
wire [RECW-1:0] rec_in     = { ox, map_base, xsize, ysize, src, zx_raw,
                               fx, fy, color };

// Sort list walk
localparam [2:0] S_IDLE=0, S_SORT=1, S_SORT_LAT=2, S_CHECK=3,
                 S_ATTR_LAT=5, S_EVAL=6, S_ATTR_DATA=7;
reg  [ 8:0] sort_idx;
reg  [ 9:0] sprite_idx;
reg  [ 1:0] attr_cnt;
wire        end_of_list = objr_dout[14];
wire        spr_disable = objr_dout[15];
wire [ 9:0] spr_index   = {objr_dout[9:0]};

always @(posedge clk) begin
    if( rst ) begin
        st <= S_IDLE; issuing <= 0; hs_l <= 0;
        wptr <= 0; sort_idx <= 0; rd_addr <= 0;
        w0 <= 0; w1 <= 0; w2 <= 0; w3 <= 0;
        attr_cnt <= 0; sprite_idx <= 0;
    end else begin
        hs_l <= hs;
        if( hs_pos ) begin
            st <= S_SORT;
            sort_idx <= 0;
            rd_addr <= 0;
            wptr <= 0;
        end else case( st )
            S_IDLE: ;
            S_SORT: begin
                rd_addr <= {{(ATTR_AW-9){1'b0}}, sort_idx};
                st <= S_SORT_LAT;
            end
            S_SORT_LAT: st <= S_CHECK;
            S_CHECK: begin
                if( end_of_list || sort_idx == 9'd511 ) begin
                    st <= S_IDLE;
                end else if( !spr_disable ) begin
                    sprite_idx <= spr_index;
                    attr_cnt <= 0;
                    rd_addr <= {spr_index[ATTR_AW-3:0], 2'd0};
                    st <= S_ATTR_LAT;
                end else begin
                    sort_idx <= sort_idx + 9'd1;
                    st <= S_SORT;
                end
            end
            S_ATTR_LAT: st <= S_ATTR_DATA;
            S_ATTR_DATA: begin
                case( attr_cnt )
                    2'd0: w0 <= objr_dout;
                    2'd1: w1 <= objr_dout;
                    2'd2: w2 <= objr_dout;
                    2'd3: w3 <= objr_dout;
                endcase
                rd_addr <= {sprite_idx[ATTR_AW-3:0], attr_cnt + 2'd1};
                attr_cnt <= attr_cnt + 2'd1;
                st <= attr_cnt==2'd3 ? S_EVAL : S_ATTR_LAT;
            end
            S_EVAL: begin
                if( !on_line || !fifo_full ) begin
                    if( on_line ) begin
                        fifo[wptr[FW-1:0]] <= rec_in;
                        wptr <= wptr + 1'd1;
                    end
                    sort_idx <= sort_idx + 9'd1;
                    st <= S_SORT;
                end
            end
            default: st <= S_IDLE;
        endcase
    end
end

// Draw: expand one slot into tile columns
localparam [1:0] D_IDLE=0, D_ISSUE=1, D_UP=2, D_DOWN=3;

reg  [ 1:0] dst;
reg  [ 2:0] dcol, lcol;
reg  [ 8:0] d_ox;
reg  [16:0] d_map;
reg  [ 2:0] d_xsize, d_ysize;
reg  [ 7:0] d_src;
reg  [ 3:0] d_zx;
reg  [ 5:0] d_col;
reg         d_fx, d_fy;
reg  [14:0] code_nx;
reg  [ 1:0] lutcnt;
reg         nx_ok;

wire [ 2:0] maprow = d_fy ? d_ysize - d_src[6:4] : d_src[6:4];
wire [ 2:0] mapcol = d_fx ? d_xsize - lcol       : lcol;
wire [ 3:0] stride = {1'b0,d_xsize} + 4'd1;
wire [16:0] mapidx = d_map + {13'd0,maprow}*{13'd0,stride} + {14'd0,mapcol};

assign objl_addr = mapidx[LUT_AW-1:0];
wire [14:0] lut_code = objl_dout[14:0];
assign pal = { 2'b01, d_col[4:0] };

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
        dst <= D_IDLE; dcol <= 0; lcol <= 0; rptr <= 0;
        draw <= 0; hz_keep <= 0; xpos <= 0; ysub <= 0; hzoom <= 0;
        hflip <= 0; vflip <= 0; code <= 0; code_nx <= 0;
        lutcnt <= 0; nx_ok <= 0;
        d_ox <= 0; d_map <= 0; d_xsize <= 0; d_ysize <= 0; d_src <= 0;
        d_zx <= 0; d_col <= 0; d_fx <= 0; d_fy <= 0;
    end else begin
        draw <= 0;
        if( !nx_ok ) begin
            lutcnt <= lutcnt + 2'd1;
            if( lutcnt==2'd1 ) begin code_nx <= lut_code; nx_ok <= 1; end
        end
        if( hs_pos ) begin
            dst <= D_IDLE; rptr <= 0;
        end else case( dst )
            D_IDLE: if( !fifo_empty ) begin
                { d_ox, d_map, d_xsize, d_ysize,
                  d_src, d_zx, d_fx, d_fy, d_col } <= fifo_out;
                rptr   <= rptr + 1'd1;
                dcol   <= 0;    lcol  <= 0;
                lutcnt <= 0;    nx_ok <= 0;
                dst    <= D_ISSUE;
            end
            D_ISSUE: if( nx_ok && !busy && !draw ) begin
                draw    <= 1;
                code    <= code_nx;
                hz_keep <= dcol!=0;
                xpos    <= d_ox + xoffs;
                ysub    <= d_src[3:0];
                hzoom   <= hz_lut;
                hflip   <= d_fx;
                vflip   <= d_fy;
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

`ifdef SIMULATION
integer sim_stalled, sim_peak, sim_unfinished, sim_tiles;
wire [FW:0] sim_queued = wptr-rptr;
always @(posedge clk) begin
    if( rst ) begin
        sim_stalled    <= 0;
        sim_peak       <= 0;
        sim_unfinished <= 0;
        sim_tiles      <= 0;
    end else if( hs_pos && vrender==0 ) begin
        $display("OBJ_SCAN stalled_cycles=%0d peak_queue=%0d unfinished=%0d tiles=%0d",sim_stalled,sim_peak,sim_unfinished,sim_tiles);
        sim_stalled    <= 0;
        sim_peak       <= 0;
        sim_unfinished <= 0;
        sim_tiles      <= 0;
    end else begin
        if( !hs_pos && st==S_EVAL && on_line && fifo_full ) sim_stalled <= sim_stalled+1;
        if( {28'd0,sim_queued}>sim_peak ) sim_peak <= {28'd0,sim_queued};
        if( hs_pos && (st!=S_IDLE || dst!=D_IDLE || !fifo_empty || busy) ) sim_unfinished <= sim_unfinished+1;
        if( draw ) sim_tiles <= sim_tiles+1;
    end
end
`endif

endmodule
