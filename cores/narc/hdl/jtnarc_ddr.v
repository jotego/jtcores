/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtnarc_ddr(
    input              rst,
    input              clk,

    input       [19:4] vcpu_addr,
    input              vcpu_rd,
    input              vcpu_we,
    input      [127:0] vcpu_din,
    input       [15:0] vcpu_dsn,
    output     [127:0] vcpu_data,
    output             vcpu_ok,
    input              vcpu_flush,
    output             vcpu_flush_done,

    input       [19:4] scan_addr,
    input              scan_rd,
    input              scan_fetch,
    input       [19:4] scan_lstart,
    output     [127:0] scan_data,
    output             scan_ok,

    input       [19:4] vrow_addr,
    input              vrow_rd,
    output     [127:0] vrow_data,
    output             vrow_ok,

    output reg  [ 7:0] ddr_burstcnt,
    output reg  [28:0] ddr_addr,
    output reg         ddr_rd,
    output reg         ddr_we,
    output reg  [ 7:0] ddr_be,
    output reg  [63:0] ddr_din,
    input              ddr_busy,
    input       [63:0] ddr_dout,
    input              ddr_dout_ready
);

localparam OWS=4, OWR=4, OWC=2;
localparam [1:0] IDLE=0, WR=1, RD=2, FILLED=3;
localparam [1:0] PS=0, PR=1, PC=2;

reg  [ 1:0] st=IDLE;

(* ramstyle = "MLAB, no_rw_check" *) reg [159:0] fq[0:7];
reg  [ 3:0] fw=0, fr=0;
reg         wok=0;
wire        fq_empty = fw==fr;
wire        fq_full  = fw[2:0]==fr[2:0] && fw[3]!=fr[3];
wire        s_miss, r_miss, c_miss, c_ok;
wire        any_miss = s_miss | r_miss | c_miss;
wire [15:0] lofs     = vcpu_addr - scan_lstart;
wire        inline   = scan_fetch && lofs<16'd65;
wire        push     = vcpu_we && !wok && !fq_full && !any_miss && !inline;
wire [159:0] fq_q    = fq[fr[2:0]];
wire [ 19:4] fq_addr = fq_q[159:144];
wire [127:0] fq_din  = fq_q[143:16];
wire [ 15:0] fq_dsn  = fq_q[15:0];
wire        lo_en    = ~&fq_dsn[ 7:0];
wire        hi_en    = ~&fq_dsn[15:8];

assign vcpu_ok         = wok | c_ok;
assign vcpu_flush_done = vcpu_flush && fq_empty && st==IDLE;

always @(posedge clk) begin
    wok <= push;
    if( push ) begin
        fq[fw[2:0]] <= { vcpu_addr, vcpu_din, vcpu_dsn };
        fw <= fw+4'd1;
    end
end

reg  [ 1:0] sel=PS;
reg  [ 6:0] bcnt;
reg  [ 6:0] last;
reg         hi2;
reg  [63:0] lo_beat;
reg         fill_we=0;
reg  [ 5:0] fill_a;
reg [127:0] fill_d;
reg  [ 2:0] fstart=0, fdone=0;
reg  [ 1:0] nxt;

always @* begin
    case( sel )
        PS:      nxt = r_miss ? PR : c_miss ? PC : PS;
        PR:      nxt = c_miss ? PC : s_miss ? PS : PR;
        default: nxt = s_miss ? PS : r_miss ? PR : PC;
    endcase
end

always @(posedge clk) begin
    fill_we <= 0;
    fstart  <= 0;
    fdone   <= 0;
    case( st )
        IDLE: begin
            if( !fq_empty ) begin
                if( !lo_en && !hi_en ) begin
                    fr <= fr+4'd1;
                end else begin
                    ddr_we       <= 1;
                    ddr_addr     <= { 4'd3, 8'd0, fq_addr, !lo_en };
                    ddr_burstcnt <= lo_en && hi_en ? 8'd2 : 8'd1;
                    ddr_din      <= lo_en ? fq_din[63:0] : fq_din[127:64];
                    ddr_be       <= lo_en ? ~fq_dsn[7:0] : ~fq_dsn[15:8];
                    hi2          <= lo_en && hi_en;
                    st           <= WR;
                end
            end else if( any_miss ) begin
                ddr_rd  <= 1;
                ddr_be  <= 8'hff;
                bcnt    <= 0;
                st      <= RD;
                case( nxt )
                    PS: begin
                        ddr_addr     <= { 4'd3, 8'd0, scan_addr[19:4+OWS], {OWS+1{1'b0}} };
                        ddr_burstcnt <= 8'd1 << (OWS+1);
                        last         <= (7'd1 << (OWS+1)) - 7'd1;
                    end
                    PR: begin
                        ddr_addr     <= { 4'd3, 8'd0, vrow_addr[19:4+OWR], {OWR+1{1'b0}} };
                        ddr_burstcnt <= 8'd1 << (OWR+1);
                        last         <= (7'd1 << (OWR+1)) - 7'd1;
                    end
                    default: begin
                        ddr_addr     <= { 4'd3, 8'd0, vcpu_addr[19:4+OWC], {OWC+1{1'b0}} };
                        ddr_burstcnt <= 8'd1 << (OWC+1);
                        last         <= (7'd1 << (OWC+1)) - 7'd1;
                    end
                endcase
                sel    <= nxt;
                fstart <= 3'b001 << nxt;
            end
        end
        WR: if( !ddr_busy ) begin
            if( hi2 ) begin
                hi2     <= 0;
                ddr_din <= fq_din[127:64];
                ddr_be  <= ~fq_dsn[15:8];
            end else begin
                ddr_we <= 0;
                fr     <= fr+4'd1;
                st     <= IDLE;
            end
        end
        RD: begin
            if( ddr_rd && !ddr_busy ) ddr_rd <= 0;
            if( ddr_dout_ready ) begin
                bcnt <= bcnt+7'd1;
                if( !bcnt[0] ) lo_beat <= ddr_dout;
                else begin
                    fill_we <= 1;
                    fill_a  <= bcnt[6:1];
                    fill_d  <= { ddr_dout, lo_beat };
                end
                if( bcnt==last ) st <= FILLED;
            end
        end
        FILLED: begin
            fdone <= 3'b001 << sel;
            st    <= IDLE;
        end
    endcase
end

wire        fwe_s = fill_we && sel==PS;
wire        fwe_r = fill_we && sel==PR;
wire        fwe_c = fill_we && sel==PC;

jtnarc_ddr_rbuf #(.OW(OWS)) u_scan(
    .rst        ( rst             ),
    .clk        ( clk             ),
    .addr       ( scan_addr       ),
    .rd         ( scan_rd         ),
    .dout       ( scan_data       ),
    .ok         ( scan_ok         ),
    .miss       ( s_miss          ),
    .wr         ( push            ),
    .wr_addr    ( vcpu_addr       ),
    .fill_start ( fstart[0]       ),
    .fill_we    ( fwe_s           ),
    .fill_a     ( fill_a[OWS-1:0] ),
    .fill_d     ( fill_d          ),
    .fill_done  ( fdone[0]        )
);

jtnarc_ddr_rbuf #(.OW(OWR)) u_vrow(
    .rst        ( rst             ),
    .clk        ( clk             ),
    .addr       ( vrow_addr       ),
    .rd         ( vrow_rd         ),
    .dout       ( vrow_data       ),
    .ok         ( vrow_ok         ),
    .miss       ( r_miss          ),
    .wr         ( push            ),
    .wr_addr    ( vcpu_addr       ),
    .fill_start ( fstart[1]       ),
    .fill_we    ( fwe_r           ),
    .fill_a     ( fill_a[OWR-1:0] ),
    .fill_d     ( fill_d          ),
    .fill_done  ( fdone[1]        )
);

jtnarc_ddr_rbuf #(.OW(OWC)) u_vcpu(
    .rst        ( rst             ),
    .clk        ( clk             ),
    .addr       ( vcpu_addr       ),
    .rd         ( vcpu_rd         ),
    .dout       ( vcpu_data       ),
    .ok         ( c_ok            ),
    .miss       ( c_miss          ),
    .wr         ( push            ),
    .wr_addr    ( vcpu_addr       ),
    .fill_start ( fstart[2]       ),
    .fill_we    ( fwe_c           ),
    .fill_a     ( fill_a[OWC-1:0] ),
    .fill_d     ( fill_d          ),
    .fill_done  ( fdone[2]        )
);

endmodule
