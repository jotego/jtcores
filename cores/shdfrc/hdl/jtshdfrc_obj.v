/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-11-2026 */

module jtshdfrc_obj(
    input                rst,
    input                clk,
    input                line_start,
    input         [ 8:0] vcnt,
    input         [ 8:0] rline,
    input         [ 9:0] lb_ra,
    input                ob_clr,

    output reg    [12:1] spr_rd_addr,
    input         [15:0] spr_rd_data,
    output reg           spr_copy_busy,
    input                spr_copy_ok,

    output        [22:2] obj_addr,
    output reg           obj_cs,
    input                obj_ok,
    input         [31:0] obj_data,
    output        [20:1] obj4_addr,
    output reg           obj4_cs,
    input                obj4_ok,
    input         [15:0] obj4_data,

    output        [10:0] lobj
);

wire        rbank = rline[0];
reg  [ 9:0] ob_wa;
reg  [10:0] ob_wd;
reg         ob_we;

jtframe_dual_ram #(
    .DW ( 11 ),
    .AW ( 10 )
) u_lbobj(
    .clk0  ( clk    ),
    .data0 ( ob_wd  ),
    .addr0 ( ob_wa  ),
    .we0   ( ob_we  ),
    .q0    (        ),
    .clk1  ( clk    ),
    .data1 ( 11'd0  ),
    .addr1 ( lb_ra  ),
    .we1   ( ob_clr ),
    .q1    ( lobj   )
);

reg  [47:0] sbuf_wd;
reg  [8:0]  sbuf_wa;
reg         sbuf_we;
reg  [8:0]  sbuf_ra;
wire [47:0] sbuf_q;
reg  [39:0] cacc;

jtframe_rpwp_ram #(
    .DW ( 48 ),
    .AW ( 9  )
) u_sprbuf(
    .clk     ( clk     ),
    .rd_addr ( sbuf_ra ),
    .dout    ( sbuf_q  ),
    .wr_addr ( sbuf_wa ),
    .din     ( sbuf_wd ),
    .we      ( sbuf_we )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        spr_copy_busy <= 0; spr_rd_addr <= 0; sbuf_we <= 0;
    end else begin
        sbuf_we <= 0;
        if( !spr_copy_busy ) begin
            if( line_start && vcnt==9'd248 ) begin
                spr_copy_busy <= 1;
                spr_rd_addr <= 0;
            end
        end else if( spr_copy_ok ) begin
            if( spr_rd_addr[3:1]==3'd5 ) begin
                sbuf_wa <= spr_rd_addr[12:4];
                sbuf_wd <= { spr_rd_data[7:0], cacc };
                sbuf_we <= 1;
                spr_rd_addr <= { spr_rd_addr[12:4]+9'd1, 3'd0 };
                if( &spr_rd_addr[12:4] ) spr_copy_busy <= 0;
            end else begin
                cacc <= { spr_rd_data[7:0], cacc[39:8] };
                spr_rd_addr[3:1] <= spr_rd_addr[3:1] + 3'd1;
            end
        end
    end
end

localparam OF_D = 8;
reg  [10:0] line_origin;
reg         sev;
reg         scan_on;
reg  [35:0] ofifo [0:OF_D-1];
reg  [2:0]  ofr, ofw;
reg  [3:0]  ofn;

wire [7:0]  s0 = sbuf_q[ 7: 0], s1 = sbuf_q[15: 8], s2 = sbuf_q[23:16],
            s3 = sbuf_q[31:24], s4 = sbuf_q[39:32], s5 = sbuf_q[47:40];
wire [10:0] distance = line_origin - { 1'b0, s0[1:0], s1 };
wire        y_wrap   = distance[10] == distance[9];
wire        shit     = s0[2] && y_wrap && distance[8:7]==0 && distance[6:4]<=s0[7:5];
wire [15:0] scode    = { s2, s3 } + { 13'd0, distance[6:4] };
wire [3:0]  srow     = s0[3] ? distance[3:0] : ~distance[3:0];
wire [8:0]  sx9    = { s4[0], s5 } + 9'd1;

wire [35:0] shitw  = { scode, srow, s0[4], s4[6], s4[5:1], sx9 };
wire        opush  = sev && shit;
reg         opop;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scan_on <= 0; sev <= 0; sbuf_ra <= 0; ofr <= 0; ofw <= 0; ofn <= 0;
    end else begin

        sev <= 0;
        if( line_start && !spr_copy_busy && vcnt!=9'd248 ) begin
            scan_on <= 1;
            sbuf_ra <= 0;
        end else if( scan_on && ofn < OF_D-2 ) begin
            if( sbuf_ra==0 ) line_origin <= 11'd255 - { 2'd0, rline };
            sev     <= 1;
            sbuf_ra <= sbuf_ra + 9'd1;
            if( &sbuf_ra ) scan_on <= 0;
        end

        if( opush ) begin ofifo[ofw] <= shitw; ofw <= ofw + 3'd1; end
        if( opop  ) ofr <= ofr + 3'd1;
        if( opush != opop ) ofn <= ofn + (opush ? 4'd1 : 4'hf);
    end
end

localparam OC_IDLE=0, OC_RD=1, OC_RW=2, OC_HAND=3;
reg  [1:0]  ocst;
reg  [35:0] oent;
reg         ohalf;
reg  [1:0]  owait;
reg  [31:0] ocd;
reg  [7:0]  ocd4;

reg         odbusy, odfx, odpri, odhalf;
reg  [4:0]  odpal;
reg  [8:0]  odx;
reg  [31:0] odd;
reg  [7:0]  odd4;
reg  [2:0]  oi;

wire [15:0] e_code = oent[35:20];
wire [3:0]  e_row  = oent[19:16];

assign obj_addr  = { e_code, ohalf, e_row };
assign obj4_addr = { e_code, ohalf, e_row[3:1] };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ocst <= OC_IDLE; obj_cs <= 0; obj4_cs <= 0; opop <= 0; odbusy <= 0; ob_we <= 0;
    end else begin
        opop  <= 0;
        ob_we <= 0;
        case( ocst )
            OC_IDLE: if( ofn!=0 && !opop ) begin
                oent  <= ofifo[ofr];
                opop  <= 1;
                ohalf <= 0;
                ocst  <= OC_RD;
            end
            OC_RD: begin
                obj_cs  <= 1;
                obj4_cs <= 1;
                owait   <= 2'd2;
                ocst    <= OC_RW;
            end
            OC_RW: begin
                if( owait!=0 ) owait <= owait - 2'd1;
                else if( obj_ok && obj4_ok ) begin
                    ocd  <= obj_data;
                    ocd4 <= e_row[0] ? obj4_data[15:8] : obj4_data[7:0];
                    obj_cs  <= 0;
                    obj4_cs <= 0;
                    ocst <= OC_HAND;
                end
            end
            OC_HAND: if( !odbusy ) begin
                odbusy <= 1;
                odd    <= ocd;
                odd4   <= ocd4;
                odfx   <= oent[15];
                odpri  <= oent[14];
                odpal  <= oent[13:9];
                odx    <= oent[8:0];
                odhalf <= ohalf;
                oi     <= 0;
                if( !ohalf ) begin ohalf <= 1; ocst <= OC_RD; end
                else ocst <= OC_IDLE;
            end
            default: ocst <= OC_IDLE;
        endcase

        if( odbusy ) begin : odraw
            reg [2:0] j;
            reg [4:0] pen;
            reg [3:0] px;
            j   = ~oi;
            pen = { odd[{2'd0,j}], odd[{2'd1,j}], odd[{2'd2,j}], odd[{2'd3,j}], odd4[j] };
            px  = { odhalf, oi };
            ob_wa <= { rbank, odx + { 5'd0, odfx ? ~px : px } };
            ob_wd <= { odpri, odpal, pen };
            ob_we <= pen != 5'd0;
            oi    <= oi + 3'd1;
            if( oi==3'd7 ) odbusy <= 0;
        end
    end
end

endmodule
