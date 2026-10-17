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
 * throughout both physical cycles for arbiter reservation.
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
    input             word_ack
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
reg [47:0] mask_window, data_window, read_window;
reg [31:0] rdata_q;
reg [15:0] old_word;
reg [1:0] index, last_index;
reg [3:0] align_count, offset;
reg write_q;
reg [15:0] word_mask, word_data;
wire [31:0] size_mask = 32'hffff_ffff >> (6'd32 - size);
wire [5:0] field_span = {2'b00,addr[3:0]} + size;

assign rdata = rdata_q;
assign word_lock = (state == RMW_READ) ||
                   ((state == WRITE) && (word_mask != 16'hffff));

always @* begin
    case (index)
        2'd0: begin
            word_mask = mask_window[15:0];
            word_data = data_window[15:0];
            word_addr = base_addr;
        end
        2'd1: begin
            word_mask = mask_window[31:16];
            word_data = data_window[31:16];
            word_addr = base_addr + 32'd16;
        end
        default: begin
            word_mask = mask_window[47:32];
            word_data = data_window[47:32];
            word_addr = base_addr + 32'd32;
        end
    endcase
    word_req = (state == READ) || (state == RMW_READ) || (state == WRITE);
    word_we = (state == WRITE);
    word_wdata = (state == WRITE && word_mask != 16'hffff) ?
        ((old_word & ~word_mask) | (word_data & word_mask)) : word_data;
    ack = (state == RESPONSE);
end

always @(posedge clk) begin
    if (rst) begin
        state       <= IDLE;
        base_addr   <= 32'd0;
        mask_window <= 48'd0;
        data_window <= 48'd0;
        read_window <= 48'd0;
        rdata_q     <= 32'd0;
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
                mask_window <= {16'd0,size_mask};
                data_window <= {16'd0,wdata};
                read_window <= 48'd0;
                rdata_q     <= 32'd0;
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
                mask_window <= {mask_window[46:0],1'b0};
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
                end else
                    index <= index + 2'd1;
            end
            SELECT: state <= (word_mask == 16'hffff) ? WRITE : RMW_READ;
            RMW_READ: if (word_ack) begin
                old_word <= word_rdata;
                state <= WRITE;
            end
            WRITE: if (word_ack) begin
                if (index == last_index)
                    state <= RESPONSE;
                else begin
                    index <= index + 2'd1;
                    state <= SELECT;
                end
            end
            ALIGN: if (align_count != 4'd0) begin
                read_window <= {1'b0,read_window[47:1]};
                align_count <= align_count - 4'd1;
            end else begin
                rdata_q <= read_window[31:0];
                state <= RESPONSE;
            end
            RESPONSE: if (!req) state <= IDLE;
            default: state <= IDLE;
        endcase
    end
end

endmodule
