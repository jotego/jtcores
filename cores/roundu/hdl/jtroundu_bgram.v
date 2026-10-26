/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-10-2026 */

module jtroundu_bgram(
    input             rst,
    input             clk,
    input      [16:0] cpu_addr,
    input       [7:0] cpu_din,
    output      [7:0] cpu_dout,
    input             cpu_cs,
    input             cpu_we,
    output            cpu_ok,
    input      [16:0] gfx_addr,
    output      [7:0] gfx_data,
    input             line_start,
    input       [8:0] v,
    input      [15:0] back_x,
    input      [15:0] scroll_x,
    input      [15:0] scroll_y,
    output     [16:1] ram_addr,
    output     [15:0] ram_din,
    input      [15:0] ram_data,
    output            ram_cs,
    output            ram_we,
    output      [1:0] ram_dsn,
    input             ram_ok
);

wire [8:0] next_v = v == 271 ? 9'd0 : v+9'd1;
wire signed [10:0] far_y = $signed({2'd0,next_v}) + $signed({2'd0,scroll_y[8:0]}) - 11'sd384;
wire signed [10:0] near_y = far_y - 11'sd64;
wire need_far = far_y >= 0 && far_y < 128;
wire need_near = near_y >= 0 && near_y < 64;
reg [2:0] state;
reg layer, buffer_sel, near_needed;
reg [6:0] column;
reg [16:0] base [0:1];
reg [6:0] first_word [0:1];
wire [6:0] fetch_word = first_word[layer]+column;
wire [16:0] fetch_addr = {base[layer][16:8],fetch_word,1'b0};
reg fetch_cs;
wire fetch_ok;
wire [15:0] fetch_data;
reg [1:0] ready_far, ready_near;
reg [6:0] row_far [0:1];
reg [5:0] row_near [0:1];
reg fill_we;
reg [1:0] fill_bank;
reg [6:0] fill_addr;
reg [15:0] fill_data;
wire patch_we = ram_cs && ram_ok && ram_we;
wire [15:0] line_data [0:3];
reg [1:0] read_bank;
reg read_odd, read_valid;
wire [15:0] read_data = line_data[read_bank];
assign gfx_data = !read_valid ? 8'd0 : read_odd ? read_data[15:8] : read_data[7:0];

jtroundu_txram #(
    .GFX_DW ( 16 )
) u_access (
    .rst         ( rst        ),
    .clk         ( clk        ),
    .cpu_addr    ( cpu_addr   ),
    .cpu_din     ( cpu_din    ),
    .cpu_dout    ( cpu_dout   ),
    .cpu_cs      ( cpu_cs     ),
    .cpu_we      ( cpu_we     ),
    .cpu_ok      ( cpu_ok     ),
    .gfx_addr    ( fetch_addr ),
    .gfx_cs      ( fetch_cs   ),
    .gfx_data    ( fetch_data ),
    .gfx_ok      ( fetch_ok   ),
    .ram_addr    ( ram_addr   ),
    .ram_din     ( ram_din    ),
    .ram_data    ( ram_data   ),
    .ram_cs      ( ram_cs     ),
    .ram_we      ( ram_we     ),
    .ram_dsn     ( ram_dsn    ),
    .ram_ok      ( ram_ok     ),
    .initialized (            )
);

genvar b;
generate for (b=0;b<4;b=b+1) begin : g_line
    wire patch_hit = patch_we && (b < 2 ?
        ram_addr[16:15] == 2'b10 && ram_addr[14:8] == row_far[b%2] :
        ram_addr[16:14] == 3'b110 && ram_addr[13:8] == row_near[b%2]);
    wire [1:0] wen = patch_hit ? ~ram_dsn : {2{fill_we && fill_bank == b}};
    jtframe_dual_ram16 #(
        .AW ( 7 )
    ) u_line (
        .clk0  ( clk                                   ),
        .addr0 ( patch_hit ? ram_addr[7:1] : fill_addr ),
        .data0 ( patch_hit ? ram_din : fill_data       ),
        .we0   ( wen                                   ),
        .q0    (                                       ),
        .clk1  ( clk                                   ),
        .addr1 ( gfx_addr[7:1]                         ),
        .data1 ( 16'd0                                 ),
        .we1   ( 2'b00                                 ),
        .q1    ( line_data[b]                          )
    );
end endgenerate

always @(posedge clk) begin
    read_bank <= {gfx_addr[15],v[0]};
    read_odd <= gfx_addr[0];
    read_valid <= gfx_addr[15] ? ready_near[v[0]] && row_near[v[0]] == gfx_addr[13:8] :
                                               ready_far[v[0]] && row_far[v[0]] == gfx_addr[14:8];
    fill_we <= 0;
    if (rst) begin
        state <= 0;
        fetch_cs <= 0;
        ready_far <= 0;
        ready_near <= 0;
        layer <= 0;
        buffer_sel <= 0;
        near_needed <= 0;
        column <= 0;
        fill_bank <= 0;
        fill_addr <= 0;
        fill_data <= 0;
        base[0] <= 0; base[1] <= 0;
        first_word[0] <= 0; first_word[1] <= 0;
        row_far[0] <= 0; row_far[1] <= 0;
        row_near[0] <= 0; row_near[1] <= 0;
        read_valid <= 0;
    end else case (state)
        0: if (line_start) begin
            buffer_sel <= next_v[0];
            ready_far[next_v[0]] <= 0;
            ready_near[next_v[0]] <= 0;
            row_far[next_v[0]] <= far_y[6:0];
            row_near[next_v[0]] <= near_y[5:0];
            base[0] <= {2'b10,far_y[6:0],8'd0};
            base[1] <= {3'b110,near_y[5:0],8'd0};
            first_word[0] <= back_x[8:2];
            first_word[1] <= scroll_x[8:2];
            near_needed <= need_near;
            column <= 0;
            layer <= !need_far;
            if (need_far || need_near) state <= 1;
        end
        1: begin
            fetch_cs <= 1;
            state <= 2;
        end
        2: if (fetch_ok) begin
            fill_we <= 1;
            fill_bank <= {layer,buffer_sel};
            fill_addr <= fetch_word;
            fill_data <= fetch_data;
            fetch_cs <= 0;
            state <= 3;
        end
        3: begin
            if (column == 80) begin
                if (layer) ready_near[buffer_sel] <= 1;
                else ready_far[buffer_sel] <= 1;
                column <= 0;
                layer <= 1;
                state <= !layer && near_needed ? 1 : 0;
            end else begin
                column <= column+1'b1;
                state <= 1;
            end
        end
        default: state <= 0;
    endcase
end

endmodule
