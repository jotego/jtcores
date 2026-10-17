/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Bit-addressed 1..32-bit fields on an aligned 16-bit word bus.
 *
 * Alignment is performed one bit per clock in a 48-bit shift register.
 * This trades up to 15 setup clocks (and 15 read-result clocks) for small
 * fixed shifts instead of wide variable barrel shifters. One architectural
 * request is accepted while idle; ack stays asserted until req falls.
 * Physical request/address/data stay stable until word_ack. word_ack is one
 * pulse per accepted word; word_req may remain high with new payload after
 * the acknowledgement edge. A partial-word read/write pair holds word_lock
 * throughout both physical cycles for arbiter reservation. If HOLD breaks
 * the pair after the read and before the write starts, word_restart cancels
 * the stale write and repeats the read after HOLD releases.
 */
module jttms10_field(
    input             clk,
    input             rst,
    input             req,
    input             we,
    input      [31:0] addr,
    input      [31:0] wdata,
    input      [5:0]  size,
    output reg        ack,
    output     [31:0] rdata,
    output reg        word_req,
    output reg        word_we,
    output            word_lock,
    output reg [31:0] word_addr,
    output reg [15:0] word_wdata,
    input      [15:0] word_rdata,
    input             word_ack,
    input             word_restart
);

localparam [2:0]
    IDLE      = 3'd0,
    PREP      = 3'd1,
    READ      = 3'd2,
    SELECT    = 3'd3,
    RMW_READ  = 3'd4,
    WRITE     = 3'd5,
    ALIGN     = 3'd6,
    RESPONSE  = 3'd7;

reg [2:0] state;
reg [31:0] base_addr;
reg [47:0] data_window, read_window;
reg [5:0] span_remaining;
reg [15:0] old_word;
reg [1:0] index, last_index;
reg [3:0] align_count, offset;
reg write_q;
wire [15:0] word_mask;
reg [15:0] word_data;
wire [5:0] field_span = {2'b00,addr[3:0]} + size;
// HOLD may break a partial-word pair only after its read completed and
// before its write was accepted. Cancel that pending write and reread the
// external word after HOLD releases, so unrelated bits cannot go stale.
wire restart_rmw = word_restart && state == WRITE && word_mask != 16'hffff;

// The lower bound applies only to the first word; the remaining span
// supplies the upper bound. This replaces a shifted 48-bit mask window.
genvar mask_bit;
generate for(mask_bit=0;mask_bit<16;mask_bit=mask_bit+1) begin: g_word_mask
    localparam [5:0] UPPER_BIT=mask_bit;
    if(mask_bit==15) begin: g_last
        assign word_mask[mask_bit] = span_remaining>UPPER_BIT;
    end else begin: g_lower
        localparam [3:0] LOWER_BIT=mask_bit;
        assign word_mask[mask_bit] =
            (index!=0 || offset<=LOWER_BIT) && span_remaining>UPPER_BIT;
    end
end endgenerate

// Read data is valid with ack and remains stable until the next request.
assign rdata = read_window[31:0];
assign word_lock = (state == RMW_READ) ||
                   ((state == WRITE) && (word_mask != 16'hffff) && !restart_rmw);

always @* begin
    word_data = data_window[15:0];
    word_addr = base_addr;
    word_req = (state == READ) || (state == RMW_READ) ||
               ((state == WRITE) && !restart_rmw);
    word_we = (state == WRITE) && !restart_rmw;
    word_wdata = (state == WRITE && word_mask != 16'hffff) ?
        ((old_word & ~word_mask) | (word_data & word_mask)) : word_data;
    ack = (state == RESPONSE);
end

always @(posedge clk) begin
    if (rst) begin
        state       <= IDLE;
        base_addr   <= 32'd0;
        span_remaining <= 6'd0;
        data_window <= 48'd0;
        read_window <= 48'd0;
        old_word    <= 16'd0;
        index       <= 2'd0;
        last_index  <= 2'd0;
        align_count <= 4'd0;
        offset      <= 4'd0;
        write_q     <= 1'b0;
    end else begin
        case (state)
            IDLE: if (req) begin
                base_addr   <= {addr[31:4],4'b0000};
                span_remaining <= field_span;
                data_window <= {16'd0,wdata};
                read_window <= 48'd0;
                index       <= 2'd0;
                last_index  <= field_span > 6'd32 ? 2'd2 :
                               field_span > 6'd16 ? 2'd1 : 2'd0;
                align_count <= addr[3:0];
                offset      <= addr[3:0];
                write_q     <= we;
                if (size == 6'd0 || size > 6'd32)
                    state <= RESPONSE;
                else if (addr[3:0] != 4'd0)
                    state <= PREP;
                else
                    state <= we ? SELECT : READ;
            end
            PREP: begin
                data_window <= {data_window[46:0],1'b0};
                align_count <= align_count - 4'd1;
                if (align_count == 4'd1)
                    state <= write_q ? SELECT : READ;
            end
            READ: if (word_ack) begin
                case (index)
                    2'd0: read_window[15:0]  <= word_rdata & word_mask;
                    2'd1: read_window[31:16] <= word_rdata & word_mask;
                    default: read_window[47:32] <= word_rdata & word_mask;
                endcase
                if (index == last_index) begin
                    align_count <= offset;
                    state <= ALIGN;
                end else begin
                    index <= index + 2'd1;
                    base_addr <= base_addr + 32'd16;
                    span_remaining <= span_remaining - 6'd16;
                end
            end
            SELECT: state <= (word_mask == 16'hffff) ? WRITE : RMW_READ;
            RMW_READ: if (word_ack) begin
                old_word <= word_rdata;
                state <= WRITE;
            end
            WRITE: if (restart_rmw) begin
                state <= RMW_READ;
            end else if (word_ack) begin
                if (index == last_index)
                    state <= RESPONSE;
                else begin
                    index <= index + 2'd1;
                    base_addr <= base_addr + 32'd16;
                    span_remaining <= span_remaining - 6'd16;
                    data_window <= {16'd0,data_window[47:16]};
                    state <= SELECT;
                end
            end
            ALIGN: if (align_count != 4'd0) begin
                read_window <= {1'b0,read_window[47:1]};
                align_count <= align_count - 4'd1;
            end else begin
                state <= RESPONSE;
            end
            RESPONSE: if (!req) state <= IDLE;
            default: state <= IDLE;
        endcase
    end
end

endmodule
