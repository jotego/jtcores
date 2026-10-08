/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-4-2026 */

// Fujitsu 29F016A TSOP48 FlashROM
module jtcps3_simm_flash #(
    parameter WRITE_ENABLE = 1,
    parameter PAIR_LANES   = 0
)(
    input               rst,
    input               clk,
    // CPU interface
    input               cs,
    input               rd,
    input               wr,
    input       [20:0]  addr,
    input       [31:0]  din,
    // CPU/JTFRAME byte-mask order: dsn[3] masks din[31:24].
    input       [ 3:0]  dsn,
    output      [31:0]  dout,
    output              ok,
    // interface to SDRAM (via cache mux)
    output      [21:0]  mem_addr,
    output              mem_rd,
    output              mem_we,
    input       [31:0]  mem_data,
    input               mem_ok,
    output      [31:0]  mem_din,
    output      [ 3:0]  mem_dsn
);

localparam [3:0] ST_READ    = 4'd0,
                 ST_UNLOCK1 = 4'd1,
                 ST_UNLOCK2 = 4'd2,
                 ST_AUTO    = 4'd3,
                 ST_PROGRAM = 4'd4,
                 ST_ERASE1  = 4'd5,
                 ST_ERASE2  = 4'd6,
                 ST_ERASE3  = 4'd7;

localparam [1:0] OP_IDLE      = 2'd0,
                 OP_PROG_READ = 2'd1,
                 OP_PROG_WR   = 2'd2,
                 OP_ERASE_WR  = 2'd3;

`ifdef CPS3_CPU_TEST
localparam ERASE_WORD_BITS = 10;
localparam CHIP_WORD_BITS  = 12;
`else
localparam ERASE_WORD_BITS = 16;
localparam CHIP_WORD_BITS  = 21;
`endif

reg  [ 3:0] lane_state[0:3];
reg         wr_seen;
reg  [ 1:0] op;
reg         prog_req;
reg         erase_req;
reg         erase_chip;
reg         erase_toggle;
reg  [20:0] op_addr;
reg  [20:0] erase_addr;
reg  [20:0] erase_count;
reg  [31:0] op_data;
reg  [ 3:0] op_mask;
reg  [31:0] prog_old;
reg         done_ack;

reg [31:0] dout_l;
reg        ok_l;

wire        write_start = cs & wr & ~wr_seen & (op == OP_IDLE);
wire [ 3:0] state_lane0 = lane_state[0];
wire [ 3:0] state_lane1 = lane_state[1];
wire [ 3:0] state_lane2 = PAIR_LANES ? lane_state[0] : lane_state[2];
wire [ 3:0] state_lane3 = PAIR_LANES ? lane_state[1] : lane_state[3];
wire [ 3:0] auto_mask = {
    state_lane3 == ST_AUTO,
    state_lane2 == ST_AUTO,
    state_lane1 == ST_AUTO,
    state_lane0 == ST_AUTO
};
wire        cmd_555_addr = addr[10:0] == 11'h555;
wire        read_id_addr = addr[7:0] == 8'd0 ||
                           addr[7:0] == 8'd1 ||
                           addr[7:0] == 8'd2;
wire [ 7:0] flash_id_byte = addr[7:0] == 8'd0 ? 8'h04 :
                            addr[7:0] == 8'd1 ? 8'had :
                            addr[7:0] == 8'd2 ? 8'h00 : 8'hff;

function [3:0] next_state;
    input [3:0] state;
    input [20:0] a;
    input [7:0] data;
begin
    if (data == 8'hf0 || data == 8'hff) begin
        next_state = ST_READ;
    end else begin
        case (state)
            ST_READ:    next_state = a[10:0] == 11'h555 && data == 8'haa ? ST_UNLOCK1 : ST_READ;
            ST_UNLOCK1: next_state = a[10:0] == 11'h2aa && data == 8'h55 ? ST_UNLOCK2 : ST_READ;
            ST_UNLOCK2: next_state = a[10:0] == 11'h555 && data == 8'h90 ? ST_AUTO    :
                                      a[10:0] == 11'h555 && data == 8'ha0 ? ST_PROGRAM :
                                      a[10:0] == 11'h555 && data == 8'h80 ? ST_ERASE1  : ST_READ;
            ST_AUTO:    next_state = ST_AUTO;
            ST_PROGRAM: next_state = ST_READ;
            ST_ERASE1:  next_state = a[10:0] == 11'h555 && data == 8'haa ? ST_ERASE2 : ST_READ;
            ST_ERASE2:  next_state = a[10:0] == 11'h2aa && data == 8'h55 ? ST_ERASE3 : ST_READ;
            ST_ERASE3:  next_state = ST_READ;
            default:    next_state = ST_READ;
        endcase
    end
end
endfunction

wire [3:0] write_lane = { ~dsn[0], ~dsn[1], ~dsn[2], ~dsn[3] };
wire       read_id = cs & rd & read_id_addr;
wire       read_id_auto_all = read_id & (&auto_mask);
wire [3:0] program_lane = {
    write_lane[3] & (state_lane3 == ST_PROGRAM),
    write_lane[2] & (state_lane2 == ST_PROGRAM),
    write_lane[1] & (state_lane1 == ST_PROGRAM),
    write_lane[0] & (state_lane0 == ST_PROGRAM)
};
wire [3:0] sector_erase_lane = {
    write_lane[3] & (state_lane3 == ST_ERASE3) & (din[ 7: 0] == 8'h30),
    write_lane[2] & (state_lane2 == ST_ERASE3) & (din[15: 8] == 8'h30),
    write_lane[1] & (state_lane1 == ST_ERASE3) & (din[23:16] == 8'h30),
    write_lane[0] & (state_lane0 == ST_ERASE3) & (din[31:24] == 8'h30)
};
wire [3:0] chip_erase_lane = {
    write_lane[3] & (state_lane3 == ST_ERASE3) & cmd_555_addr & (din[ 7: 0] == 8'h10),
    write_lane[2] & (state_lane2 == ST_ERASE3) & cmd_555_addr & (din[15: 8] == 8'h10),
    write_lane[1] & (state_lane1 == ST_ERASE3) & cmd_555_addr & (din[23:16] == 8'h10),
    write_lane[0] & (state_lane0 == ST_ERASE3) & cmd_555_addr & (din[31:24] == 8'h10)
};
wire [3:0] erase_lane = |chip_erase_lane ? chip_erase_lane : sector_erase_lane;
wire [3:0] program_op_lane = WRITE_ENABLE ? program_lane : 4'd0;
wire [3:0] erase_op_lane   = WRITE_ENABLE ? erase_lane   : 4'd0;
wire       erase_sector_last = erase_count[ERASE_WORD_BITS-1:0] == {ERASE_WORD_BITS{1'b1}};
wire       erase_chip_last = erase_count[CHIP_WORD_BITS-1:0] == {CHIP_WORD_BITS{1'b1}};
wire       erase_last = erase_chip ? erase_chip_last : erase_sector_last;
wire [7:0] erase_status = { 1'b0, erase_toggle, 2'b00, 1'b1, erase_toggle, 2'b00 };
wire [3:0] erase_status_mask = op == OP_ERASE_WR ? op_mask : 4'd0;
wire [7:0] lane0_dout = read_id && auto_mask[0] ? flash_id_byte : mem_data[31:24];
wire [7:0] lane1_dout = read_id && auto_mask[1] ? flash_id_byte : mem_data[23:16];
wire [7:0] lane2_dout = read_id && auto_mask[2] ? flash_id_byte : mem_data[15: 8];
wire [7:0] lane3_dout = read_id && auto_mask[3] ? flash_id_byte : mem_data[ 7: 0];

assign mem_addr = (op == OP_ERASE_WR) ?
                  (erase_chip ? { 1'b0, erase_count } :
                                { 1'b0, erase_addr[20:ERASE_WORD_BITS], erase_count[ERASE_WORD_BITS-1:0] }) :
                  (op == OP_IDLE ? { 1'b0, addr } : { 1'b0, op_addr });
assign mem_rd   = (op == OP_PROG_READ) || (cs & rd & !read_id_auto_all);
assign mem_we   = ((op == OP_PROG_WR) && prog_req) ||
                  ((op == OP_ERASE_WR) && erase_req);
assign mem_din  = (op == OP_PROG_WR) ? {
    op_mask[0] ? (prog_old[31:24] & op_data[31:24]) : 8'hff,
    op_mask[1] ? (prog_old[23:16] & op_data[23:16]) : 8'hff,
    op_mask[2] ? (prog_old[15: 8] & op_data[15: 8]) : 8'hff,
    op_mask[3] ? (prog_old[ 7: 0] & op_data[ 7: 0]) : 8'hff
} : 32'hffff_ffff;
assign mem_dsn  = (op == OP_IDLE) ? 4'hf :
                  { ~op_mask[0], ~op_mask[1], ~op_mask[2], ~op_mask[3] };

wire [31:0] dout_nx = {
    erase_status_mask[0] ? erase_status : lane0_dout,
    erase_status_mask[1] ? erase_status : lane1_dout,
    erase_status_mask[2] ? erase_status : lane2_dout,
    erase_status_mask[3] ? erase_status : lane3_dout
};

wire ok_nx = done_ack || (cs & rd & (read_id_auto_all || mem_ok)) ||
             (write_start && (program_op_lane == 4'd0) && (erase_op_lane == 4'd0));

assign dout = dout_l;
assign ok   = ok_l;

always @(posedge clk) begin
    integer i;

    if (rst) begin
        for (i = 0; i < 4; i = i + 1)
            lane_state[i] <= ST_READ;
        wr_seen    <= 1'b0;
        op         <= OP_IDLE;
        prog_req   <= 1'b0;
        erase_req  <= 1'b0;
        erase_chip <= 1'b0;
        erase_toggle <= 1'b1;
        op_addr    <= 21'd0;
        erase_addr <= 21'd0;
        erase_count <= 21'd0;
        op_data    <= 32'd0;
        op_mask    <= 4'd0;
        prog_old   <= 32'd0;
        done_ack   <= 1'b0;
        dout_l     <= 32'hffff_ffff;
        ok_l       <= 1'b0;
    end else begin
        dout_l <= dout_nx;
        ok_l   <= ok_nx;

        if (!cs || !wr) begin
            wr_seen <= 1'b0;
            done_ack <= 1'b0;
        end

        if (write_start) begin
            wr_seen <= 1'b1;

            if (PAIR_LANES) begin
                if (write_lane[0]) lane_state[0] <= next_state(lane_state[0], addr, din[31:24]);
                if (write_lane[2]) lane_state[0] <= next_state(lane_state[0], addr, din[15: 8]);
                if (write_lane[1]) lane_state[1] <= next_state(lane_state[1], addr, din[23:16]);
                if (write_lane[3]) lane_state[1] <= next_state(lane_state[1], addr, din[ 7: 0]);
            end else begin
                if (write_lane[0]) lane_state[0] <= next_state(lane_state[0], addr, din[31:24]);
                if (write_lane[1]) lane_state[1] <= next_state(lane_state[1], addr, din[23:16]);
                if (write_lane[2]) lane_state[2] <= next_state(lane_state[2], addr, din[15: 8]);
                if (write_lane[3]) lane_state[3] <= next_state(lane_state[3], addr, din[ 7: 0]);
            end

            if (|erase_op_lane) begin
                op          <= OP_ERASE_WR;
                erase_req   <= 1'b1;
                erase_chip  <= |chip_erase_lane;
                erase_toggle <= 1'b1;
                op_addr     <= addr;
                erase_addr  <= { addr[20:ERASE_WORD_BITS], {ERASE_WORD_BITS{1'b0}} };
                erase_count <= 21'd0;
                op_data     <= 32'hffff_ffff;
                op_mask     <= erase_op_lane;
            end else if (|program_op_lane) begin
                op       <= OP_PROG_READ;
                prog_req <= 1'b0;
                op_addr  <= addr;
                op_data  <= din;
                op_mask  <= program_op_lane;
            end else begin
                done_ack <= 1'b1;
            end
        end else begin
            case (op)
                OP_PROG_READ: begin
                    if (mem_ok) begin
                        prog_old <= mem_data;
                        op       <= OP_PROG_WR;
                    end
                end
                OP_PROG_WR: begin
                    if (!prog_req) begin
                        prog_req <= 1'b1;
                    end else if (mem_ok) begin
                        op       <= OP_IDLE;
                        prog_req <= 1'b0;
                        done_ack <= 1'b1;
                    end
                end
                OP_ERASE_WR: begin
                    if (erase_req && cs & rd & mem_ok)
                        erase_toggle <= ~erase_toggle;
                    if (erase_req && mem_ok) begin
                        if (erase_last) begin
                            op         <= OP_IDLE;
                            erase_req  <= 1'b0;
                            erase_chip <= 1'b0;
                            done_ack   <= 1'b1;
                        end else begin
                            erase_count <= erase_count + 21'd1;
                            erase_req   <= 1'b0;
                        end
                    end else if (!erase_req) begin
                        erase_req <= 1'b1;
                    end
                end
                default: ;
            endcase
        end
    end
end

endmodule
