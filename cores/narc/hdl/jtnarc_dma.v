/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-10-2026 */

module jtnarc_dma(
    input             rst,
    input             clk,
    input             wr,
    input      [ 3:0] sel,
    input      [15:0] din,
    output reg [15:0] dout,
    output reg        busy,
    output reg        irq,
    input             pause,
    output            paused,
    output reg [21:2] src_addr,
    output reg        src_rd,
    input      [31:0] src_data,
    input             src_ok,
    output reg [18:3] dst_addr,
    output reg        dst_we,
    output reg [63:0] dst_din,
    output reg [ 7:0] dst_dsn,
    input             dst_ok
);

localparam [2:0] IDLE=3'd0, FETCH=3'd1, PIXEL=3'd2, DRAIN=3'd3, NEXT=3'd4;

reg  [15:0] ctrl, offset, sagl, sagh, xpos, ypos, hsize, vsize, cmap, cconst;
reg  [ 2:0] st;
reg  [31:0] saddr, lstart;
reg  [15:0] hcnt, vcnt;
reg  [11:0] credit;
reg  [ 8:0] dx, dy;
reg  [31:0] sword, nword;
reg  [19:0] sw_addr, nw_addr;
reg         sw_ok, nw_ok, pf;
reg  [ 7:0] pix;
reg  [15:0] wb_a;
reg  [63:0] wb_d;
reg  [ 3:0] wb_m;
reg         wb_v;
reg  [87:0] fq[0:7];
reg  [ 2:0] fw, fr;
reg  [ 3:0] fc;
wire        fq_full  = fc[3];
wire        fq_empty = fc==0;
wire [ 7:0] wb_dsn   = ~{ {2{wb_m[3]}}, {2{wb_m[2]}}, {2{wb_m[1]}}, {2{wb_m[0]}} };

wire [ 7:0] sbyte  = saddr[4:3]==0 ? sword[ 7: 0] :
                     saddr[4:3]==1 ? sword[15: 8] :
                     saddr[4:3]==2 ? sword[23:16] : sword[31:24];
wire        hflip  = ctrl[4];
wire        zero   = pix==0;
wire        draw   = zero ? ctrl[0] | ctrl[2] : ctrl[1] | ctrl[3];
wire        subst  = zero ? ~ctrl[0] & ctrl[2] : ~ctrl[1] & ctrl[3];
wire [ 7:0] wpix   = subst ? cconst[7:0] : pix;
wire        last   = hcnt==16'd1;
wire [15:0] wa_now = { dy, dx[8:2] };
wire        endln  = hcnt==0 || vcnt==0 || last;
wire        start  = wr && !busy && sel==4'd0 && din[15];
wire        paced  = credit>=12'd4;
wire        adv    = st==NEXT && !(wb_v && endln) && hcnt!=0 && vcnt!=0 && paced;
wire [16:0] psum   = hflip ? { offset[15], offset } - { 1'b0, hsize } : { offset[15], offset } + { 1'b0, hsize };
wire [16:0] pitch  = ( psum + 17'd3 ) & ~17'd3;
wire [31:0] lstep  = { {12{pitch[16]}}, pitch, 3'd0 };
wire [ 1:0] wrem   = hflip ? saddr[4:3] : ~saddr[4:3];
wire [31:0] nline  = lstart + lstep;
wire        lnend  = hcnt <= { 14'd0, wrem } + 16'd1;
wire [19:0] pf_a   = lnend ? nline[24:5] : hflip ? saddr[24:5]-20'd1 : saddr[24:5]+20'd1;
wire        pf_go  = (st==PIXEL || st==NEXT) && !src_rd && !pause && sw_ok
                     && !(lnend && vcnt<=16'd1) && !(nw_ok && nw_addr==pf_a);

wire        push   = !fq_full && wb_v && (
                        ( pause && (st==FETCH || st==PIXEL) ) ||
                        ( st==PIXEL && draw && !pause && wb_a!=wa_now ) ||
                        ( st==NEXT && endln ) );
assign paused = st==IDLE || ( pause && !src_rd && !dst_we && fq_empty && !wb_v );

always @(posedge clk) begin
    case( sel )
        4'd0:    dout <= { busy, ctrl[14:0] };
        4'd1:    dout <= offset;
        4'd2:    dout <= sagl;
        4'd3:    dout <= sagh;
        4'd4:    dout <= xpos;
        4'd5:    dout <= ypos;
        4'd6:    dout <= hsize;
        4'd7:    dout <= vsize;
        4'd8:    dout <= cmap;
        4'd9:    dout <= cconst;
        default: dout <= 16'hffff;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        { ctrl, offset, sagl, sagh, xpos, ypos, hsize, vsize, cmap, cconst } <= 0;
        st       <= IDLE;
        busy     <= 0;
        irq      <= 0;
        saddr    <= 0;
        lstart   <= 0;
        hcnt     <= 0;
        vcnt     <= 0;
        dx       <= 0;
        dy       <= 0;
        sword    <= 0;
        sw_addr  <= 0;
        sw_ok    <= 0;
        nword    <= 0;
        nw_addr  <= 0;
        nw_ok    <= 0;
        pf       <= 0;
        pix      <= 0;
        src_addr <= 0;
        src_rd   <= 0;
        dst_addr <= 0;
        dst_we   <= 0;
        dst_din  <= 0;
        dst_dsn  <= 8'hff;
        wb_a     <= 0;
        wb_d     <= 0;
        wb_m     <= 0;
        wb_v     <= 0;
        fw       <= 0;
        fr       <= 0;
        fc       <= 0;
    end else begin
        if( dst_we && dst_ok ) dst_we <= 0;
        if( !dst_we && !fq_empty ) begin
            { dst_addr, dst_din, dst_dsn } <= fq[fr];
            dst_we <= 1;
            fr     <= fr+3'd1;
        end
        if( wr && !busy ) case( sel )
            4'd0: begin
                ctrl <= din;
                irq  <= 0;
                if( din[15] ) begin
                    busy  <= 1;
                    saddr <= { sagh, sagl };
                    lstart<= { sagh, sagl };
                    hcnt  <= hsize;
                    vcnt  <= vsize;
                    dx    <= xpos[8:0];
                    dy    <= ypos[8:0];
                    sw_ok <= 0;
                    st    <= hsize==0 || vsize==0 ? NEXT : FETCH;
                end
            end
            4'd1: offset <= din;
            4'd2: sagl   <= din;
            4'd3: sagh   <= din;
            4'd4: xpos   <= din;
            4'd5: ypos   <= din;
            4'd6: hsize  <= din;
            4'd7: vsize  <= din;
            4'd8: cmap   <= din;
            4'd9: cconst <= din;
            default:;
        endcase
        if( pause && wb_v && !fq_full && (st==FETCH || st==PIXEL) ) begin
            fq[fw] <= { wb_a, wb_d, wb_dsn };
            wb_v   <= 0;
        end
        case( st )
            FETCH: if( sw_ok && sw_addr==saddr[24:5] ) begin
                pix <= sbyte;
                st  <= PIXEL;
            end else if( nw_ok && nw_addr==saddr[24:5] ) begin
                sword   <= nword;
                sw_addr <= nw_addr;
                sw_ok   <= 1;
            end else if( !src_rd && !pause ) begin
                src_addr <= saddr[24:5];
                src_rd   <= 1;
                pf       <= 0;
            end
            PIXEL: if( !draw ) begin
                st <= NEXT;
            end else if( !pause ) begin
                if( wb_v && wb_a!=wa_now ) begin
                    if( !fq_full ) begin
                        fq[fw] <= { wb_a, wb_d, wb_dsn };
                        wb_v <= 0;
                    end
                end else begin
                    wb_a <= wa_now;
                    wb_d[ {dx[1:0],4'd0} +: 16 ] <= { cmap[7:0], wpix };
                    wb_m <= ( wb_v ? wb_m : 4'd0 ) | (4'd1<<dx[1:0]);
                    wb_v <= 1;
                    st   <= NEXT;
                end
            end
            DRAIN: if( fq_empty && !dst_we && !src_rd ) begin
                busy <= 0;
                irq  <= 1;
                st   <= IDLE;
            end
            NEXT: begin
                if( wb_v && endln ) begin
                    if( !fq_full ) begin
                        fq[fw] <= { wb_a, wb_d, wb_dsn };
                        wb_v <= 0;
                    end
                end else if( hcnt==0 || vcnt==0 ) begin
                    st <= DRAIN;
                end else if( !paced ) begin
                    st    <= NEXT;
                end else if( !last ) begin
                    hcnt  <= hcnt-16'd1;
                    dx    <= dx+9'd1;
                    saddr <= hflip ? saddr-32'd8 : saddr+32'd8;
                    st    <= FETCH;
                end else begin
                    hcnt  <= hsize;
                    vcnt  <= vcnt-16'd1;
                    dx    <= xpos[8:0];
                    dy    <= dy+9'd1;
                    saddr <= lstart + lstep;
                    lstart<= lstart + lstep;
                    st    <= vcnt==16'd1 ? DRAIN : FETCH;
                end
            end
            default:;
        endcase
        if( src_rd && src_ok ) begin
            src_rd <= 0;
            if( pf ) begin
                nword   <= src_data;
                nw_addr <= src_addr;
                nw_ok   <= 1;
            end else begin
                sword   <= src_data;
                sw_addr <= src_addr;
                sw_ok   <= 1;
            end
        end else if( pf_go ) begin
            src_addr <= pf_a;
            src_rd   <= 1;
            pf       <= 1;
        end
        if( push ) fw <= fw+3'd1;
        case( { push, !dst_we && !fq_empty } )
            2'b10: fc <= fc+4'd1;
            2'b01: fc <= fc-4'd1;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    if( rst || start )
        credit <= 0;
    else
        credit <= credit + { 11'd0, ~&credit } - ( adv ? 12'd4 : 12'd0 );
end

endmodule
