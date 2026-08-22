/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-04-2026 */

module jtcps3_chardma #(
    parameter [1:0] DMA_XOR_K = 2'd0
)(
    input               rst,
    input               clk,

    // Trigger / registers (from PPU MMR)
    input       [15:0]  chardma_src_lo,
    input       [ 5:0]  chardma_src_hi,
    input               chardma_go,

    // Source lane (zipchar) - 32-bit reads over logical m_user5 space
    input               zipchar_ok,
    input       [31:0]  zipchar_data,
    output reg  [25:2]  zipchar_addr,
    output reg          zipchar_rd,

    // Character RAM / tile-store lane (tiles_wr) - 32-bit RW inside 8 MiB region
    input               tiles_ok,
    input       [31:0]  tiles_data,
    output reg          tiles_rd,
    output reg  [22:2]  tiles_addr,
    output reg          tiles_we,
    output reg  [31:0]  tiles_din,
    output reg  [ 3:0]  tiles_dsn, // active low byte mask

    output reg          busy,
    output reg          done
);

localparam [2:0] CMD_COPY  = 3'd0,
                 CMD_6BPP  = 3'd2,
                 CMD_8BPP  = 3'd3,
                 CMD_TABLE = 3'd4;

localparam [7:0]
    ST_IDLE          = 8'd0,
    ST_LIST_REQ0     = 8'd1,
    ST_LIST_WAIT0    = 8'd2,
    ST_LIST_REQ1     = 8'd3,
    ST_LIST_WAIT1    = 8'd4,
    ST_LIST_REQ2     = 8'd5,
    ST_LIST_WAIT2    = 8'd6,
    ST_DECODE        = 8'd7,

    ST_COPY_SRC      = 8'd10,
    ST_COPY_EMIT     = 8'd11,

    ST_6_SRC         = 8'd20,
    ST_6_TBL0_REQ    = 8'd21,
    ST_6_TBL0_WAIT   = 8'd22,
    ST_6_TBL1_REQ    = 8'd23,
    ST_6_TBL1_WAIT   = 8'd24,
    ST_6_PROC        = 8'd25,

    ST_8_CTRL        = 8'd30,
    ST_8_DATA_WAIT   = 8'd31,
    ST_8_PROC        = 8'd32,
    ST_8_P_WAIT      = 8'd33,
    ST_8_TBL0_REQ    = 8'd34,
    ST_8_TBL0_WAIT   = 8'd35,
    ST_8_TBL1_REQ    = 8'd36,
    ST_8_TBL1_WAIT   = 8'd37,

    ST_TABLE_LOAD0_REQ  = 8'd40,
    ST_TABLE_LOAD0_WAIT = 8'd41,
    ST_TABLE_LOAD1_REQ  = 8'd42,
    ST_TABLE_LOAD1_WAIT = 8'd43,

    ST_FINISH        = 8'd250;

reg [7:0] st;

// Command list pointer: word index inside 8 MiB char RAM (MAME-style)
reg  [21:0] list_wptr;
reg  [31:0] w0,    w1,    w2;
wire [31:0] len32, dst32, src32;

reg  [22:0] out_left;    // remaining output bytes (decompressed) for current command
reg  [22:0] dst_byte;    // destination logical byte address in char RAM
reg  [25:0] src_user5;   // linear user5 byte address
reg  [25:0] table_user5; // linear user5 byte address for table base

// Zipchar fetch (1 outstanding)
reg        z_pending;
reg [25:0] z_ba;
reg        zip_ok_l, tiles_ok_l;
wire [ 1:0] z_sel_now  = (z_ba[1:0] ^ DMA_XOR_K);
wire [ 7:0] z_byte_now =
    z_sel_now==2'd0 ? zipchar_data[31:24] :
    z_sel_now==2'd1 ? zipchar_data[23:16] :
    z_sel_now==2'd2 ? zipchar_data[15: 8] :
                      zipchar_data[ 7: 0];
wire       zipchar_idle = !z_pending && !zipchar_rd && !zipchar_ok;
wire       zipchar_rdy  = z_pending & zipchar_ok & ~zip_ok_l;
wire       tiles_rdy   = tiles_ok   & ~tiles_ok_l;

// Queue of bytes to be processed (max 2 for table indirection)
reg [7:0] q0, q1;
reg [1:0] qn;

// Current table index (for 2-byte table reads)
reg [6:0] tbl_idx;
reg [6:0] table_load_idx;
reg [7:0] table_load_lo;
reg [15:0] table_cache [0:127];

// Common output emitter
reg [7:0] emit_byte;
reg [8:0] emit_rep;
reg       emit_accepted;

// Packed destination write buffer. Sequential logical bytes map through ^3
// into one physical word, so this reduces char-RAM write transactions.
reg        wrbuf_valid;
reg [22:2] wrbuf_addr;
reg [31:0] wrbuf_din;
reg [ 3:0] wrbuf_dsn;

// Cmd2 state (6bpp)
reg [7:0] last_norm;

// Cmd3 state (8bpp)
reg [15:0] lastb, lastb2;
reg [7:0]  ctrl;
reg [3:0]  ctrl_i;

// Command 4 loads the 128 two-byte table entries used by the RLE streams.

assign len32 = (((w0 & 32'h001f_ffff) + 32'd1) << 3);
assign dst32 = (w1 << 3);
assign src32 = ((w2 << 1) - 32'h0040_0000);

function [22:0] xor3_addr(input [22:0] a);
    xor3_addr = { a[22:2], a[1:0] ^ 2'b11 };
endfunction

task tiles_req_read(input [22:2] a);
begin
    tiles_rd   <= 1'b1;
    tiles_we   <= 1'b0;
    tiles_addr <= a;
    tiles_din  <= 32'd0;
    tiles_dsn  <= 4'hf;
end
endtask

task tiles_req_write_buf;
begin
    tiles_rd   <= 1'b1;
    tiles_we   <= 1'b1;
    tiles_addr <= wrbuf_addr;
    tiles_din  <= wrbuf_din;
    tiles_dsn  <= wrbuf_dsn;
end
endtask

task wrbuf_flush_step;
begin
    if (!tiles_rd) begin
        tiles_req_write_buf();
    end else if (tiles_rdy) begin
        wrbuf_valid <= 1'b0;
    end
end
endtask

task wrbuf_add_byte(input [22:0] phys_byte_addr, input [7:0] b);
    reg [22:2] wa;
    reg [1:0]  bl;
    reg [31:0] din_next;
    reg [ 3:0] dsn_next;
begin
    wa = phys_byte_addr[22:2];
    bl = phys_byte_addr[1:0];

    din_next = wrbuf_valid ? wrbuf_din : 32'd0;
    dsn_next = wrbuf_valid ? wrbuf_dsn : 4'hf;

    case (bl)
    2'd3: din_next[31:24] = b;
    2'd2: din_next[23:16] = b;
    2'd1: din_next[15: 8] = b;
    default: din_next[ 7: 0] = b;
    endcase
    dsn_next[bl] = 1'b0;

    wrbuf_valid <= 1'b1;
    wrbuf_addr  <= wa;
    wrbuf_din   <= din_next;
    wrbuf_dsn   <= dsn_next;
end
endtask

task emit_buffered_byte(input [22:0] phys_byte_addr, input [7:0] b);
begin
    emit_accepted = 1'b0;
    if (wrbuf_valid &&
        (wrbuf_dsn == 4'h0 || wrbuf_addr != phys_byte_addr[22:2] ||
         !wrbuf_dsn[phys_byte_addr[1:0]])) begin
        wrbuf_flush_step();
    end else begin
        wrbuf_add_byte(phys_byte_addr, b);
        emit_accepted = 1'b1;
    end
end
endtask

task zip_req_byte(input [25:0] user5_byte_addr);
begin
    z_ba        <= user5_byte_addr;
    zipchar_addr<= user5_byte_addr[25:2];
    zipchar_rd  <= 1'b1;
    z_pending   <= 1'b1;
end
endtask

always @(posedge clk) begin
    done <= 1'b0;

    if (rst) begin
        st         <= ST_IDLE;
        busy       <= 1'b0;
        zipchar_rd <= 1'b0;
        zipchar_addr <= 0;
        tiles_rd   <= 1'b0;
        tiles_addr <= 0;
        tiles_we   <= 1'b0;
        tiles_din  <= 0;
        tiles_dsn  <= 4'hf;
        z_pending  <= 1'b0;
        z_ba       <= 0;
        qn         <= 0;
        emit_rep   <= 0;
        table_user5<= 0;
        zip_ok_l   <= 1'b0;
        tiles_ok_l <= 1'b0;
        last_norm  <= 0;
        lastb      <= 16'hfffe;
        lastb2     <= 16'hffff;
        ctrl        <= 0;
        ctrl_i      <= 0;
        table_load_idx <= 0;
        table_load_lo  <= 0;
        emit_accepted <= 1'b0;
        wrbuf_valid <= 1'b0;
        wrbuf_addr  <= 0;
        wrbuf_din   <= 0;
        wrbuf_dsn   <= 4'hf;
    end else begin
        emit_accepted = 1'b0;
        zip_ok_l   <= zipchar_ok;
        tiles_ok_l <= tiles_ok;
        // zipchar_rd is a request strobe; z_pending tracks the outstanding read.
        if (zipchar_rd) zipchar_rd <= 1'b0;
        if (z_pending && zipchar_ok) z_pending <= 1'b0;
        if (tiles_ok) begin
            tiles_rd <= 1'b0;
        end

        case (st)
        ST_IDLE: begin
            busy     <= 1'b0;
            emit_rep <= 0;
            qn       <= 0;
            if (chardma_go) begin
                busy        <= 1'b1;
                list_wptr   <= {chardma_src_hi, chardma_src_lo};
                zip_ok_l    <= 1'b0;
                tiles_ok_l  <= 1'b0;
                st          <= ST_LIST_REQ0;
            end
        end

        // List entry: 3 words
        ST_LIST_REQ0: begin
            if (wrbuf_valid) begin
                wrbuf_flush_step();
            end else if (!tiles_rd) begin
                tiles_req_read(list_wptr[20:0]);
                st <= ST_LIST_WAIT0;
            end
        end
        ST_LIST_WAIT0: if (tiles_rdy) begin
            w0 <= tiles_data;
            list_wptr <= list_wptr + 22'd1;
            st <= ST_LIST_REQ1;
        end
        ST_LIST_REQ1: if (!tiles_rd) begin
            tiles_req_read(list_wptr[20:0]);
            st <= ST_LIST_WAIT1;
        end
        ST_LIST_WAIT1: if (tiles_rdy) begin
            w1 <= tiles_data;
            list_wptr <= list_wptr + 22'd1;
            st <= ST_LIST_REQ2;
        end
        ST_LIST_REQ2: if (!tiles_rd) begin
            tiles_req_read(list_wptr[20:0]);
            st <= ST_LIST_WAIT2;
        end
        ST_LIST_WAIT2: if (tiles_rdy) begin
            w2 <= tiles_data;
            list_wptr <= list_wptr + 22'd1;
            st <= ST_DECODE;
        end

        ST_DECODE: begin
            if (w0[24]) begin
                st <= ST_FINISH;
            end else begin
                out_left <= len32[22:0];
                dst_byte <= dst32[22:0];
                src_user5<= src32[25:0];
                emit_rep <= 0;
                qn       <= 0;
                last_norm<= 0;
                lastb    <= 16'hfffe;
                lastb2   <= 16'hffff;
                ctrl_i   <= 0;

                if (w0[23:21]==CMD_TABLE) begin
                    table_user5    <= src32[25:0];
                    table_load_idx <= 7'd0;
                    st <= ST_TABLE_LOAD0_REQ;
                end else if (w0[23:21]==CMD_COPY) begin
                    st <= ST_COPY_SRC;
                end else if (w0[23:21]==CMD_6BPP) begin
                    st <= ST_6_SRC;
                end else if (w0[23:21]==CMD_8BPP) begin
                    st <= ST_8_CTRL;
                end else begin
                    st <= ST_LIST_REQ0;
                end
            end
        end

        // Cmd 0: uncompressed copy
        ST_COPY_SRC: begin
            if (out_left==0) st <= ST_LIST_REQ0;
            else if (emit_rep!=0) st <= ST_COPY_EMIT;
            else if (zipchar_idle) begin
                zip_req_byte(src_user5);
                st <= ST_COPY_EMIT;
            end
        end
        ST_COPY_EMIT: begin
            if (out_left==0) begin
                emit_rep <= 0;
                st <= ST_LIST_REQ0;
            end else if (emit_rep!=0) begin
                emit_buffered_byte(xor3_addr(dst_byte), emit_byte);
                if (emit_accepted) begin
                    dst_byte <= dst_byte + 23'd1;
                    out_left <= out_left - 23'd1;
                    emit_rep <= emit_rep - 9'd1;
                    if (emit_rep==9'd1) st <= ST_COPY_SRC;
                end
            end else if (zipchar_rdy) begin
                emit_byte <= z_byte_now;
                emit_rep  <= 9'd1;
                src_user5 <= src_user5 + 26'd1;
            end
        end

        // Cmd 2: 6bpp RLE decompression
        ST_6_SRC: begin
            if (out_left==0) st <= ST_LIST_REQ0;
            else if (emit_rep!=0 || qn!=0) st <= ST_6_PROC;
            else if (zipchar_idle) begin
                zip_req_byte(src_user5);
                st <= ST_6_PROC;
            end
        end

        ST_6_TBL0_REQ: begin
            q0 <= table_cache[tbl_idx][15:8];
            q1 <= table_cache[tbl_idx][ 7:0];
            qn <= 2'd2;
            st <= ST_6_PROC;
        end
        ST_6_TBL0_WAIT,
        ST_6_TBL1_REQ,
        ST_6_TBL1_WAIT: st <= ST_6_PROC;

        ST_6_PROC: begin
            if (out_left==0) begin
                emit_rep <= 0;
                qn <= 0;
                st <= ST_LIST_REQ0;
            end else if (emit_rep!=0) begin
                emit_buffered_byte(xor3_addr(dst_byte), emit_byte);
                if (emit_accepted) begin
                    dst_byte <= dst_byte + 23'd1;
                    out_left <= out_left - 23'd1;
                    emit_rep <= emit_rep - 9'd1;
                    if (emit_rep==9'd1) st <= ST_6_SRC;
                end
            end else if (qn!=0) begin
                // process_byte() semantics
                if (q0[6]) begin
                    emit_byte <= (last_norm & 8'h3f);
                    emit_rep  <= {3'd0, q0[5:0]} + 9'd1;
                end else begin
                    emit_byte <= q0;
                    emit_rep  <= 9'd1;
                    last_norm <= q0;
                end
                // pop queue
                q0 <= q1;
                q1 <= 8'd0;
                qn <= qn - 2'd1;
            end else if (zipchar_rdy) begin
                // got next stream byte
                src_user5 <= src_user5 + 26'd1;
                if (z_byte_now[7]) begin
                    tbl_idx <= z_byte_now[6:0];
                    st <= ST_6_TBL0_REQ;
                end else begin
                    q0 <= z_byte_now;
                    qn <= 2'd1;
                    st <= ST_6_PROC;
                end
            end else if (zipchar_idle) begin
                // Queue drained without a new request in flight; fetch the next stream byte.
                zip_req_byte(src_user5);
            end
        end

        // Cmd 3: 8bpp RLE decompression
        ST_8_CTRL: begin
            if (out_left==0) st <= ST_LIST_REQ0;
            else if (zipchar_idle) begin
                zip_req_byte(src_user5);
                st <= ST_8_DATA_WAIT;
            end
        end
        ST_8_DATA_WAIT: if (zipchar_rdy) begin
            ctrl   <= z_byte_now;
            ctrl_i <= 4'd0;
            src_user5 <= src_user5 + 26'd1;
            st <= ST_8_PROC;
        end

        ST_8_TBL0_REQ: begin
            q0 <= table_cache[tbl_idx][15:8];
            q1 <= table_cache[tbl_idx][ 7:0];
            qn <= 2'd2;
            st <= ST_8_PROC;
        end
        ST_8_TBL0_WAIT,
        ST_8_TBL1_REQ,
        ST_8_TBL1_WAIT: st <= ST_8_PROC;

        ST_8_PROC: begin
            if (out_left==0) begin
                emit_rep <= 0;
                qn <= 0;
                st <= ST_LIST_REQ0;
            end else if (emit_rep!=0) begin
                emit_buffered_byte(xor3_addr(dst_byte), emit_byte);
                if (emit_accepted) begin
                    dst_byte <= dst_byte + 23'd1;
                    out_left <= out_left - 23'd1;
                    emit_rep <= emit_rep - 9'd1;
                    if (emit_rep==9'd1) st <= ST_8_PROC;
                end
            end else if (qn!=0) begin
                // ProcessByte8 semantics
                if (lastb==lastb2) begin
                    emit_byte <= lastb[7:0];
                    emit_rep  <= q0 == 8'hff ? 9'd0 : {1'b0, q0} + 9'd1;
                    lastb2    <= 16'hffff;
                end else begin
                    lastb2    <= lastb;
                    lastb     <= {8'd0,q0};
                    emit_byte <= q0;
                    emit_rep  <= 9'd1;
                end
                q0 <= q1;
                q1 <= 8'd0;
                qn <= qn - 2'd1;
            end else if (ctrl_i==4'd8) begin
                st <= ST_8_CTRL;
            end else if (zipchar_idle) begin
                zip_req_byte(src_user5);
                st <= ST_8_P_WAIT;
            end
        end

        // Got p byte
        ST_8_P_WAIT: if (zipchar_rdy) begin
            src_user5 <= src_user5 + 26'd1;
            if (ctrl[7]) begin
                tbl_idx <= z_byte_now[6:0];
                st <= ST_8_TBL0_REQ;
            end else begin
                q0 <= z_byte_now;
                qn <= 2'd1;
                st <= ST_8_PROC;
            end
            ctrl <= {ctrl[6:0],1'b0};
            ctrl_i <= ctrl_i + 4'd1;
        end


        ST_TABLE_LOAD0_REQ: begin
            if (zipchar_idle) begin
                zip_req_byte(table_user5 + {18'd0, table_load_idx, 1'b0});
                st <= ST_TABLE_LOAD0_WAIT;
            end
        end
        ST_TABLE_LOAD0_WAIT: if (zipchar_rdy) begin
            table_load_lo <= z_byte_now;
            st <= ST_TABLE_LOAD1_REQ;
        end
        ST_TABLE_LOAD1_REQ: begin
            if (zipchar_idle) begin
                zip_req_byte(table_user5 + {18'd0, table_load_idx, 1'b0} + 26'd1);
                st <= ST_TABLE_LOAD1_WAIT;
            end
        end
        ST_TABLE_LOAD1_WAIT: if (zipchar_rdy) begin
            table_cache[table_load_idx] <= {table_load_lo, z_byte_now};
            if (table_load_idx == 7'd127) begin
                st <= ST_LIST_REQ0;
            end else begin
                table_load_idx <= table_load_idx + 7'd1;
                st <= ST_TABLE_LOAD0_REQ;
            end
        end

        ST_FINISH: begin
            if (wrbuf_valid) begin
                wrbuf_flush_step();
            end else begin
                busy <= 1'b0;
                done <= 1'b1;
                st <= ST_IDLE;
            end
        end

        default: st <= ST_IDLE;
        endcase
    end
end

endmodule
