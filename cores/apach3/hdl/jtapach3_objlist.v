/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
module jtapach3_objlist(
    input              rst,
    input              clk,
    input              flush,
    input              start,
    input              bank,
    input        [8:0] length,
    input        [8:0] target_y,
    output reg   [9:0] ram_addr,
    input      [207:0] ram_data,
    output             busy,
    output             valid,
    output     [207:0] data,
    output       [8:0] index,
    input              pop
);
reg active, issued, selected_bank;
reg [8:0] next_index, index0, index1, line_y;
reg [1:0] pending, wp, rp;
reg [2:0] count;
reg [216:0] fifo [0:3];
wire take = pop && valid;
wire push = pending[1] && line_y >= {1'b0,ram_data[135:128]} && line_y < {1'b0,ram_data[143:136]};
wire [3:0] reserved = {1'b0,count}+{3'd0,pending[0]}+{3'd0,pending[1]};
wire issue = active && !issued && (reserved < 4 || take);
assign valid = count != 0;
assign {index,data} = fifo[rp];
assign busy = active;
always @(posedge clk) begin
    if (rst || flush) begin
        active <= 0;
        issued <= 1;
        pending <= 0;
        wp <= 0;
        rp <= 0;
        count <= 0;
        ram_addr <= 0;
    end else if (start) begin
        active <= length != 0;
        issued <= length == 0;
        selected_bank <= bank;
        line_y <= target_y;
        next_index <= length-1'b1;
        pending <= 0;
        wp <= 0;
        rp <= 0;
        count <= 0;
    end else begin
        pending <= {pending[0],issue};
        index1 <= index0;
        if (issue) begin
            ram_addr <= {selected_bank,next_index};
            index0 <= next_index;
            if (next_index == 0) issued <= 1;
            else next_index <= next_index-1'b1;
        end
        case ({push,take})
            2'b10: count <= count+1'b1;
            2'b01: count <= count-1'b1;
            default: ;
        endcase
        if (push) begin
            fifo[wp] <= {index1,ram_data};
            wp <= wp+1'b1;
        end
        if (take) rp <= rp+1'b1;
        if (active && issued && pending == 0 && count == 0) active <= 0;
    end
end
endmodule
