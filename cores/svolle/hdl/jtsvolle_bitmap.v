/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-10-2026 */

module jtsvolle_bitmap(
    input             rst, clk, en, next_line,
    input      [8:0]  h,
    input      [7:0]  v,
    output     [15:2] ram_addr,
    output            ram_cs,
    input      [31:0] ram_data,
    input             ram_ok,
    output     [3:0]  pxl,
    output reg        overrun
);

localparam IDLE=2'd0, GAP=2'd1, REQUEST=2'd2, RELEASE=2'd3;
reg [1:0] state;
reg [5:0] word_index;
reg [7:0] fetch_y;
reg read_bank, write_bank, ready, valid;
wire [7:0] display_y = v+8'd1;
wire line_ready = ready && fetch_y==display_y && state==IDLE;
wire [8:0] x = h+9'd13;
wire [31:0] pixels;
wire [2:0] nibble = {x[2],~x[1:0]};
wire write_en = state==REQUEST && ram_ok;

assign ram_addr = {fetch_y,word_index};
assign ram_cs = state==REQUEST;
assign pxl = en && valid ? pixels[{nibble,2'b00}+:4] : 4'hf;

always @(posedge clk) begin
    if(rst) begin
        state <= IDLE;
        word_index <= 0;
        fetch_y <= 0;
        read_bank <= 0;
        write_bank <= 1;
        ready <= 0;
        valid <= 0;
        overrun <= 0;
    end else begin
        case(state)
            GAP: state <= REQUEST;
            REQUEST: if(ram_ok) state <= RELEASE;
            RELEASE: if(!ram_ok) begin
                if(&word_index) begin
                    ready <= 1;
                    state <= IDLE;
                end else begin
                    word_index <= word_index+6'd1;
                    state <= GAP;
                end
            end
            default: state <= IDLE;
        endcase
        if(next_line) begin
            valid <= en && line_ready;
            if(en && state==IDLE) begin
                if(line_ready) read_bank <= write_bank;
                write_bank <= line_ready ? read_bank : ~read_bank;
                ready <= 0;
                fetch_y <= v+8'd2;
                word_index <= 0;
                state <= GAP;
            end else if(en) overrun <= 1;
        end
    end
end

jtframe_dual_ram #(
    .DW         ( 32            ),
    .AW         ( 7             )
) u_lines(
    .clk0       ( clk           ),
    .data0      ( ram_data      ),
    .addr0      ( {write_bank,word_index} ),
    .we0        ( write_en      ),
    .q0         (               ),
    .clk1       ( clk           ),
    .data1      ( 32'd0         ),
    .addr1      ( {read_bank,x[8:3]} ),
    .we1        ( 1'b0          ),
    .q1         ( pixels        )
);

endmodule
