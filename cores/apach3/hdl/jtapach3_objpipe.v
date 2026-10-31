/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
module jtapach3_objpipe(
    input                    rst,
    input                    clk,
    input                    flush,
    input                    start,
    input            [319:0] occupied,
    input       signed [59:0] source_x,
    input       signed [59:0] source_y,
    input       signed [59:0] step_x,
    input       signed [59:0] step_y,
    input              [8:0] first_x,
    input              [8:0] last_x,
    input              [8:0] target_y,
    input              [7:0] palette,
    input              [8:0] scale,
    input             [32:0] reciprocal,
    input                    flip_x,
    input                    flip_y,
    input                    repeat_line,
    input              [8:0] top_line,
    input              [9:0] bottom_line,
    input             [31:0] x_min,
    input             [31:0] x_max,
    input             [31:0] y_min,
    input             [31:0] y_max,
    input                    desc_we,
    input             [10:0] desc_addr,
    input              [4:0] desc_page,
    input             [11:0] desc_left,
    input             [12:0] desc_right,
    input             [17:0] desc_base,
    output                   busy,
    output                   valid,
    input                    pop,
    output            [47:0] pixel,
    output                   ahead_valid,
    output            [17:0] ahead_addr
);
(* romstyle = "M10K" *) reg [32:0] inverse [0:511];
reg active, issued;
reg signed [59:0] sx, sy, dx, dy;
reg signed [59:0] dx8, dy8, dx32, dy32, dx7, dy7, dx31, dy31;
reg signed [59:0] end_sx, end_sy;
reg signed [31:0] ex, ey;
reg skip8, skip32;
reg [5:0] stride;
reg [8:0] x, end_x, line_tag, scl, top;
reg [4:0] page;
reg [9:0] bottom;
reg [7:0] color_tag;
reg [32:0] inv;
reg fx, fy, repeat_rows;
reg [31:0] xmin, xmax, ymin, ymax;
reg [7:0] stages;
reg [8:0] xpos [0:7];
reg [26:0] cols [0:7], lines [0:7];
reg [19:0] distx, disty;
reg [59:0] productx, producty;
reg [26:0] numerx1, numery1;
wire [11:0] left3;
wire [12:0] right3;
wire [17:0] base3;
reg [17:0] base4, base5, base6;
reg [26:0] delta4, delta5, delta6, quotient6;
reg [8:0] count4, count5, count6;
reg [32:0] inverse4;
reg [59:0] wrap_product5;
reg [17:0] addr7;
reg bank7;
reg [47:0] fifo [0:15];
reg [3:0] wp, rp;
reg [4:0] count;
wire advance = count < 8;
wire push = advance && stages[7];
wire take = pop && valid;
wire [3:0] ahead = rp + 4'd1;
wire [26:0] row = (lines[2] - {18'd0,top}) >> 3;
wire desc_read = !rst && !flush && !start && advance;
integer i;
reg signed [31:0] px, py;
reg [26:0] qx, qy, qw;
reg [17:0] tile;
wire [12:0] span_pixels = right3-{1'b0,left3};
wire [8:0] span = span_pixels[11:3];
reg [26:0] full_tile;

assign busy = active;
assign valid = count != 0;
assign pixel = fifo[rp];
assign ahead_valid = count > 1;
assign ahead_addr = fifo[ahead][21:4];

jtframe_dual_ram_cen #(
    .DW ( 43 ),
    .AW ( 11 )
) u_desc (
    .clk0  ( clk                              ),
    .cen0  ( desc_read                        ),
    .data0 ( 43'd0                            ),
    .addr0 ( {page,row[5:0]}                  ),
    .we0   ( 1'b0                             ),
    .q0    ( {left3,right3,base3}             ),
    .clk1  ( clk                              ),
    .cen1  ( 1'b1                             ),
    .data1 ( {desc_left,desc_right,desc_base} ),
    .addr1 ( desc_addr                        ),
    .we1   ( desc_we                          ),
    .q1    (                                  )
);

initial begin
    inverse[0]=0;
    for (i=1;i<512;i=i+1) inverse[i]=(33'h100000000+{1'b0,i[31:0]}-1'b1)/{1'b0,i[31:0]};
end
always @(posedge clk) begin
    if (desc_read) inverse4 <= inverse[span];
end

always @(posedge clk) begin
    if (rst || flush) begin
        active <= 0;
        issued <= 1;
        stages <= 0;
        count <= 0;
        wp <= 0;
        rp <= 0;
    end else if (start) begin
        active <= 1;
        issued <= 0;
        stages <= 0;
        count <= 0;
        wp <= 0;
        rp <= 0;
        sx <= source_x;
        sy <= source_y;
        dx <= step_x;
        dy <= step_y;
        dx8 <= step_x <<< 3;
        dy8 <= step_y <<< 3;
        dx32 <= step_x <<< 5;
        dy32 <= step_y <<< 5;
        dx7 <= (step_x <<< 3)-step_x;
        dy7 <= (step_y <<< 3)-step_y;
        dx31 <= (step_x <<< 5)-step_x;
        dy31 <= (step_y <<< 5)-step_y;
        x <= first_x;
        end_x <= last_x;
        line_tag <= target_y;
        color_tag <= palette;
        scl <= scale;
        inv <= reciprocal;
        fx <= flip_x;
        fy <= flip_y;
        repeat_rows <= repeat_line;
        page <= desc_page;
        top <= top_line;
        bottom <= bottom_line;
        xmin <= x_min;
        xmax <= x_max;
        ymin <= y_min;
        ymax <= y_max;
    end else begin
        case ({push,take})
            2'b10: count <= count+1'b1;
            2'b01: count <= count-1'b1;
            default: ;
        endcase
        if (take) rp <= rp+1'b1;
        if (push) begin
            fifo[wp] <= {line_tag,color_tag,xpos[7],addr7,bank7,cols[7][2:0]^3'd3};
            wp <= wp+1'b1;
        end
        if (active && issued && stages == 0 && count == 0) active <= 0;
        if (advance) begin
            stages <= {stages[6:0],1'b0};
            for (i=1;i<8;i=i+1) xpos[i] <= xpos[i-1];
            for (i=3;i<8;i=i+1) begin
                cols[i] <= cols[i-1];
                lines[i] <= lines[i-1];
            end
            if (active && !issued) begin
                px={{12{sx[59]}},sx[59:40]};
                py={{12{sy[59]}},sy[59:40]};
                if (fx) px=-px-1;
                if (fy) py=-py-1;
                end_sx=sx+dx31;
                end_sy=sy+dy31;
                ex={{12{end_sx[59]}},end_sx[59:40]};
                ey={{12{end_sy[59]}},end_sy[59:40]};
                if (fx) ex=-ex-1;
                if (fy) ey=-ey-1;
                skip32={1'b0,x}+10'd31<={1'b0,end_x} &&
                    ((px<$signed(xmin) && ex<$signed(xmin)) ||
                     (!repeat_rows && px>=$signed(xmax) && ex>=$signed(xmax)) ||
                     (py<$signed(ymin) && ey<$signed(ymin)) ||
                     (py>=$signed(ymax) && ey>=$signed(ymax)) ||
                     (x[4:0]==0 && (&occupied[{x[8:5],5'd0}+:32])));
                end_sx=sx+dx7;
                end_sy=sy+dy7;
                ex={{12{end_sx[59]}},end_sx[59:40]};
                ey={{12{end_sy[59]}},end_sy[59:40]};
                if (fx) ex=-ex-1;
                if (fy) ey=-ey-1;
                skip8={1'b0,x}+10'd7<={1'b0,end_x} &&
                    ((px<$signed(xmin) && ex<$signed(xmin)) ||
                     (!repeat_rows && px>=$signed(xmax) && ex>=$signed(xmax)) ||
                     (py<$signed(ymin) && ey<$signed(ymin)) ||
                     (py>=$signed(ymax) && ey>=$signed(ymax)) ||
                     (x[2:0]==0 && (&occupied[{x[8:3],3'd0}+:8])));
                stride=skip32 ? 6'd32 : skip8 ? 6'd8 : 6'd1;
                stages[0] <= !skip32 && !skip8 && !occupied[x] && px>=$signed(xmin) &&
                             (repeat_rows || px<$signed(xmax)) && py>=0 &&
                             py>=$signed(ymin) && py<$signed(ymax);
                distx <= px[19:0];
                disty <= py[19:0];
                xpos[0] <= x;
                sx <= sx+(skip32 ? dx32 : skip8 ? dx8 : dx);
                sy <= sy+(skip32 ? dy32 : skip8 ? dy8 : dy);
                if ({1'b0,x}+{4'd0,stride}>{1'b0,end_x}) issued <= 1;
                else x <= x+{3'd0,stride};
            end
            productx <= {distx,7'd0}*inv;
            producty <= {disty,7'd0}*inv;
            numerx1 <= {distx,7'd0};
            numery1 <= {disty,7'd0};
            qx=productx[58:32];
            qy=producty[58:32];
            if (qx*scl > {9'd0,numerx1}) qx=qx-1'b1;
            if (qy*scl > {9'd0,numery1}) qy=qy-1'b1;
            cols[2] <= qx;
            lines[2] <= qy;
            stages[3] <= stages[2] && lines[2]>={18'd0,top} && lines[2]<{17'd0,bottom};
            stages[4] <= stages[3] && cols[3]>={15'd0,left3} && (repeat_rows || cols[3]<{14'd0,right3});
            delta4 <= (cols[3]-{15'd0,left3})>>3;
            count4 <= span;
            base4 <= base3;
            wrap_product5 <= delta4*inverse4;
            delta5 <= delta4;
            count5 <= count4;
            base5 <= base4;
            qw=wrap_product5[58:32];
            if (qw*count5 > {9'd0,delta5}) qw=qw-1'b1;
            quotient6 <= repeat_rows && delta5>={18'd0,count5} ? qw : 27'd0;
            delta6 <= delta5;
            count6 <= count5;
            base6 <= base5;
            full_tile={9'd0,base6}+delta6-quotient6*count6;
            tile=full_tile[17:0];
            addr7 <= {tile[15:1],lines[6][2:0]};
            bank7 <= tile[0];
        end
    end
end
endmodule
