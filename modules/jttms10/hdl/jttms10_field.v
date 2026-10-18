/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Bit-addressed 1..32-bit fields on an aligned 16-bit word bus.
 *
 * A shared DSP product by a one-hot factor aligns writes and final reads.
 * Address preparation and read-result alignment have constant latency. One architectural
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
    output            busy,
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
    READ      = 3'd2,
    SELECT    = 3'd3,
    RMW_READ  = 3'd4,
    WRITE     = 3'd5,
    RESPONSE  = 3'd7;

reg [2:0] state;
assign busy=state!=IDLE;
reg [31:0] base_addr;
reg [47:0] data_window, read_window;
reg [5:0] span_remaining;
reg [15:0] old_word;
reg [1:0] index, last_index;
reg [3:0] offset;
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

// Merge the incoming last word before alignment, so its data and the
// architectural response are captured together. The same 48x17 product
// aligns a write left by 0..15 or a read right by 0..15 (product bits47:16).
reg [47:0] assembled_read;
always @* begin
    assembled_read=read_window;
    case(index)
        2'd0: assembled_read[15:0]=word_rdata & word_mask;
        2'd1: assembled_read[31:16]=word_rdata & word_mask;
        default: assembled_read[47:32]=word_rdata & word_mask;
    endcase
end
wire [47:0] align_input=state==IDLE ? {16'd0,wdata} : assembled_read;
wire [4:0] align_shift=state==IDLE ? {1'b0,addr[3:0]} : 5'd16-{1'b0,offset};
wire [16:0] align_factor=17'd1 << align_shift;
(* multstyle="dsp" *) wire [47:0] aligned_product=align_input * align_factor;

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
        offset      <= 4'd0;
    end else begin
        case (state)
            IDLE: if (req) begin
                base_addr   <= {addr[31:4],4'b0000};
                span_remaining <= field_span;
                data_window <= aligned_product;
                read_window <= 48'd0;
                index       <= 2'd0;
                last_index  <= field_span > 6'd32 ? 2'd2 :
                               field_span > 6'd16 ? 2'd1 : 2'd0;
                offset      <= addr[3:0];
                if (size == 6'd0 || size > 6'd32)
                    state <= RESPONSE;
                else
                    // The first word's coverage is known at acceptance; it needs
                    // no selector clock before its first physical request.
                    state <= !we ? READ : addr[3:0]==0 && size>=6'd16 ? WRITE : RMW_READ;
            end
            READ: if (word_ack) begin
                case (index)
                    2'd0: read_window[15:0]  <= word_rdata & word_mask;
                    2'd1: read_window[31:16] <= word_rdata & word_mask;
                    default: read_window[47:32] <= word_rdata & word_mask;
                endcase
                if (index == last_index) begin
                    read_window <= {16'd0,aligned_product[47:16]};
                    state <= RESPONSE;
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
            RESPONSE: if (!req) state <= IDLE;
            default: state <= IDLE;
        endcase
    end
end

endmodule
