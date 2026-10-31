/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

module jtapach3_ground(
    input             rst,
    input             clk,
    input             pxl_cen,
    input       [8:0] h,
    input       [8:0] v,
    input      [15:0] rotate_data,
    input             rotate_we,
    input       [7:0] road_z,
    input             invalidate,
    input             road_invalidate,
    output reg  [8:1] road_x_addr,
    input      [15:0] road_x_data,
    output reg  [8:0] prom_addr,
    input       [7:0] prom_data,
    output reg [15:1] ram_addr,
    output reg        ram_cs,
    input      [15:0] ram_data,
    input             ram_ok,
    output     [10:0] pxl,
    output reg        overflow
);

localparam IDLE=0, SCAN=1, ROW_WAIT=2, CALC=3, FETCH=4;
reg [2:0] state;
reg [3:0] rotate_idx;
reg [15:0] rotate [0:11];
reg signed [31:0] hacc, gacc;
reg [8:0] x, target_y;
reg [7:0] row;
reg side;
reg [1:0] pixel_shift, stripe;
reg [14:0] cached_addr;
reg [7:0] cached_data;
reg cache_valid;
reg [7:0] cached_row, cached_prom;
reg [15:0] cached_road_x;
reg row_valid;
reg [10:0] write_data;
reg write_enable;
wire [8:0] next_y = v == 279 ? 0 : v + 1'b1;
wire signed [23:0] h_start = {rotate[0][7:0],rotate[4]};
wire signed [23:0] g_start = {rotate[9],rotate[10][7:0]};
wire signed [15:0] h_dx = rotate[2], h_dy = rotate[6];
wire signed [15:0] g_dx = rotate[8], g_dy = rotate[11];
wire signed [31:0] grow = gacc >>> 8;
wire [7:0] ground_row = grow > 255 ? 8'hff : grow[7:0];
wire row_hit = row_valid && cached_row == ground_row && !road_invalidate;
wire [15:0] selected_road_x = row_hit ? cached_road_x : road_x_data;
wire [7:0] selected_prom = row_hit ? cached_prom : prom_data;
wire [11:0] hsum = hacc[19:8] + selected_road_x[11:0];
wire [11:0] magnitude = hsum[11] ? ~hsum : hsum;
wire [14:0] pixel_addr = {ground_row,magnitude[8:2]};
wire [7:0] stripe_sum = selected_prom + road_z;
wire [7:0] pixel_byte = cached_addr == pixel_addr ? cached_data : ram_data[7:0];
wire [1:0] pixel = pixel_byte[{magnitude[1:0],1'b0}+:2];
wire [1:0] fetched_pixel = ram_data[{1'b0,pixel_shift,1'b0}+:2];
wire draw_ready = magnitude >= 512 || (cache_valid && cached_addr == pixel_addr && !invalidate);
wire [10:0] ground_pixel = {2'b01,4'd0,hsum[11],
    (magnitude >= 512 ? 2'd0 : pixel),stripe_sum[6:5]};
wire [8:0] read_x = h == 399 ? 9'd0 : h+9'd1;
integer i;
`ifdef SIMULATION
reg [7:0] rotate_init [0:31];
integer rotate_file, rotate_count;
initial begin
    for (integer k=0;k<32;k=k+1) rotate_init[k]=0;
    rotate_file=$fopen("rest.bin","rb");
    if (rotate_file != 0) begin
        rotate_count=$fread(rotate_init,rotate_file);
        $fclose(rotate_file);
        if (rotate_count != 32) $fatal(1,"Incomplete rotation restore data");
    end
end
`endif

jtframe_linebuf #(
    .DW ( 11 ),
    .AW ( 9  )
) u_buffer (
    .clk      ( clk          ),
    .LHBL     ( h != 398     ),
    .wr_addr  ( x            ),
    .wr_data  ( write_data   ),
    .we       ( write_enable ),
    .rd_addr  ( read_x       ),
    .rd_data  ( pxl          ),
    .rd_gated (              )
);

always @* begin
    write_enable = 0;
    write_data = ground_pixel;
    if (!rst && h < 398 && target_y == next_y) case (state)
        SCAN: begin
            if (grow < 0) begin
                write_enable = 1;
                write_data = 11'h100 + {4'd0,(grow < -128 ? 7'd0 : grow[6:0])};
            end else write_enable = row_hit && draw_ready;
        end
        CALC: write_enable = draw_ready;
        FETCH: begin
            write_enable = ram_ok;
            write_data = {2'b01,4'd0,side,fetched_pixel,stripe};
        end
        default: ;
    endcase
end

task draw_ground;
    begin
        if (draw_ready) begin
            hacc <= hacc + {{16{h_dx[15]}},h_dx};
            gacc <= gacc + {{16{g_dx[15]}},g_dx};
            x <= x + 1'b1;
            state <= x == 319 ? IDLE : SCAN;
        end else begin
            ram_addr <= pixel_addr;
            ram_cs <= 1;
            side <= hsum[11];
            pixel_shift <= magnitude[1:0];
            stripe <= stripe_sum[6:5];
            state <= FETCH;
        end
    end
endtask

always @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
`ifdef SIMULATION
        rotate_idx <= rotate_init[24][3:0];
`else
        rotate_idx <= 0;
`endif
        for (i=0;i<12;i=i+1)
`ifdef SIMULATION
            rotate[i] <= {rotate_init[2*i+1],rotate_init[2*i]};
`else
            rotate[i] <= 0;
`endif
        hacc <= 0;
        gacc <= 0;
        x <= 0;
        target_y <= 0;
        row <= 0;
        side <= 0;
        pixel_shift <= 0;
        stripe <= 0;
        cached_addr <= 0;
        cached_data <= 0;
        cache_valid <= 0;
        cached_row <= 0;
        cached_prom <= 0;
        cached_road_x <= 0;
        row_valid <= 0;
        road_x_addr <= 0;
        prom_addr <= 0;
        ram_addr <= 0;
        ram_cs <= 0;
        overflow <= 0;
    end else begin
        if (rotate_we) begin
            rotate[rotate_idx] <= rotate_data;
            rotate_idx <= rotate_idx == 11 ? 0 : rotate_idx + 1'b1;
        end
        if (invalidate) cache_valid <= 0;
        if (road_invalidate) row_valid <= 0;
        if (pxl_cen && h == 0 && state != IDLE) overflow <= 1;
        if (pxl_cen && h == 0 && state == IDLE) begin
            target_y <= next_y;
            x <= 0;
            hacc <= $signed({{8{h_start[23]}},h_start}) + $signed({1'b0,next_y}) * h_dy;
            gacc <= $signed({{8{g_start[23]}},g_start}) + $signed({1'b0,next_y}) * g_dy;
            state <= next_y < 240 ? SCAN : IDLE;
        end else case (state)
            IDLE: begin end
            SCAN: begin
                if (grow < 0) begin
                    hacc <= hacc + {{16{h_dx[15]}},h_dx};
                    gacc <= gacc + {{16{g_dx[15]}},g_dx};
                    x <= x + 1'b1;
                    if (x == 319) state <= IDLE;
                end else if (row_hit) begin
                    draw_ground();
                end else begin
                    row <= ground_row;
                    road_x_addr <= ground_row;
                    prom_addr <= {1'b0,ground_row};
                    state <= ROW_WAIT;
                end
            end
            ROW_WAIT: state <= CALC;
            CALC: begin
                cached_row <= row;
                cached_road_x <= road_x_data;
                cached_prom <= prom_data;
                row_valid <= !road_invalidate;
                draw_ground();
            end
            FETCH: if (ram_ok) begin
                ram_cs <= 0;
                cached_addr <= ram_addr;
                cached_data <= ram_data[7:0];
                cache_valid <= !invalidate;
                hacc <= hacc + {{16{h_dx[15]}},h_dx};
                gacc <= gacc + {{16{g_dx[15]}},g_dx};
                x <= x + 1'b1;
                state <= x == 319 ? IDLE : SCAN;
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule
