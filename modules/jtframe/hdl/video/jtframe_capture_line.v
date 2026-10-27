/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-10-2026 */

// One immutable native scanline. The same BRAM holds pixels and their in-place
// wire encoding. Encoder writes never pass pixels already read from this RAM.

module jtframe_capture_line(
    input rst, clk, start, sample, finish, release_line,
    input [11:0] pixel,
    input [735:0] tag,
    input read_start,
    input [9:0] read_offset,
    input [7:0] read_length,
    output free, ready,
    output reg [767:0] header,
    output reg read_ready,
    output reg [1023:0] window
);

localparam IDLE=0, CAPTURE=1, META=2, FETCH=3, WAIT_RAM=4, CONSUME=5,
           EMIT=6, CLOSE=7, READY=8, READ_WAIT=9, READ_BYTE=10;
reg [3:0] state, after_emit;
reg [9:0] width, run, scan, output_bytes, rle_bytes;
reg [9:0] read_at;
reg [7:0] read_size, read_index;
reg [6:0] meta_index;
reg [11:0] last_pixel, run_pixel, pair_pixel;
reg [31:0] emit_data, crc;
reg [2:0] emit_count;
reg [7:0] low_byte;
reg [8:0] write_addr, fetch_addr;
reg [15:0] write_data;
reg write_enable, paired, encoding_rle, final_emit;
wire [15:0] ram_q;
wire [31:0] crc_next;
wire [7:0] crc_byte;
wire [10:0] packed_bytes, complete_rle;
wire [15:0] run_word, run_extension;
wire [31:0] run_bytes;
wire [8:0] capture_addr;
wire [15:0] capture_data;
wire ram_we;
wire [8:0] ram_addr;
wire [15:0] ram_data;
integer k;
reg [31:0] crc_work;

assign free = state==IDLE;
assign ready = state==READY || state==READ_WAIT || state==READ_BYTE;
assign packed_bytes = {1'b0,width}+{2'd0,width[9:1]}+{10'd0,width[0]};
assign complete_rle = {1'b0,rle_bytes}+(run>=16 ? 11'd4 : 11'd2);
assign run_word = {run>=16 ? 4'hf : run[3:0]-4'd1,run_pixel};
assign run_extension = {6'd0,run}-16'd16;
assign run_bytes = run>=16 ? {run_extension,run_word} : {16'd0,run_word};
assign crc_byte = state==META ? header[{meta_index,3'b000} +:8] : emit_data[7:0];
assign crc_next = crc_work;
assign capture_addr = width[8:0];
assign capture_data = {4'd0,pixel};
assign ram_we = state==CAPTURE ? sample && width<512 : state==IDLE && start ? sample : write_enable;
assign ram_addr = state==CAPTURE ? capture_addr : state==IDLE && start ? 9'd0 : write_addr;
assign ram_data = state==CAPTURE || (state==IDLE && start) ? capture_data : write_data;

always @* begin
    crc_work = crc^{24'd0,crc_byte};
    for(k=0;k<8;k=k+1) crc_work=crc_work[0] ? (crc_work>>1)^32'hedb88320 : crc_work>>1;
end

always @(posedge clk) begin
    write_enable<=0;
    if(rst || release_line) begin
        state<=IDLE; read_ready<=0; width<=0; run<=0;
        header<=0; window<=0; write_enable<=0;
    end else begin
        case(state)
            IDLE: if(start) begin
                state<=CAPTURE; width<=sample ? 10'd1 : 10'd0; rle_bytes<=0; run<=sample ? 10'd1 : 10'd0; last_pixel<=pixel;
                read_ready<=0;
            end
            CAPTURE: begin
                if(sample && width<512) begin
                    width<=width+1'd1; last_pixel<=pixel;
                    if(width==0 || pixel!=last_pixel) begin
                        if(width!=0) rle_bytes<=rle_bytes+(run>=16 ? 10'd4 : 10'd2);
                        run<=1;
                    end else run<=run+1'd1;
                end
                if(finish) begin
                    if(width==0) state<=IDLE;
                    else begin
                        header<={32'd0,tag};
                        header[511:496]<= {6'd0,width};
                        header[623:608]<=complete_rle<packed_bytes ? {5'd0,complete_rle} : {5'd0,packed_bytes};
                        header[631:624]<=complete_rle<packed_bytes ? 8'd2 : 8'd1;
                        encoding_rle<=complete_rle<packed_bytes;
                        meta_index<=0; crc<=32'hffffffff;
                        scan<=0; run<=0; paired<=0; output_bytes<=0;
                        state<=META;
                    end
                end
            end
            META: begin
                crc<=crc_next;
                if(meta_index==91) state<=FETCH;
                else meta_index<=meta_index+1'd1;
            end
            FETCH: begin fetch_addr<=scan[8:0]; state<=WAIT_RAM; end
            WAIT_RAM: state<=CONSUME;
            CONSUME: begin
                scan<=scan+1'd1;
                if(encoding_rle) begin
                    if(run==0 || ram_q[11:0]==run_pixel) begin
                        run_pixel<=ram_q[11:0]; run<=run+1'd1;
                        if(scan==width-1'd1) begin
                            // The final pixel extends the current run.
                            emit_data<=run+1'd1>=16 ?
                                {{6'd0,run}+16'd1-16'd16,4'hf,ram_q[11:0]} :
                                {16'd0,run[3:0],ram_q[11:0]};
                            emit_count<=run+1'd1>=16 ? 4 : 2;
                            final_emit<=1; state<=EMIT;
                        end else state<=FETCH;
                    end else begin
                        emit_data<=run_bytes; emit_count<=run>=16 ? 4 : 2;
                        run_pixel<=ram_q[11:0]; run<=1;
                        final_emit<=0; after_emit<=scan==width-1'd1 ? CLOSE : FETCH;
                        state<=EMIT;
                    end
                end else if(!paired) begin
                    pair_pixel<=ram_q[11:0]; paired<=1;
                    if(scan==width-1'd1) begin
                        emit_data<={16'd0,ram_q[3:0],4'd0,ram_q[11:4]};
                        emit_count<=2; final_emit<=1; state<=EMIT;
                    end else state<=FETCH;
                end else begin
                    emit_data<={8'd0,ram_q[7:0],pair_pixel[3:0],ram_q[11:8],pair_pixel[11:4]};
                    emit_count<=3; paired<=0; final_emit<=scan==width-1'd1;
                    after_emit<=FETCH; state<=EMIT;
                end
            end
            CLOSE: begin
                emit_data<=run_bytes; emit_count<=run>=16 ? 4 : 2;
                final_emit<=1; state<=EMIT;
            end
            EMIT: begin
                crc<=crc_next;
                if(!output_bytes[0]) low_byte<=emit_data[7:0];
                if(output_bytes[0] || (final_emit && emit_count==1)) begin
                    write_addr<=output_bytes[9:1];
                    write_data<=output_bytes[0] ? {emit_data[7:0],low_byte} : {8'd0,emit_data[7:0]};
                    write_enable<=1;
                end
                output_bytes<=output_bytes+1'd1;
                emit_data<=emit_data>>8; emit_count<=emit_count-1'd1;
                if(emit_count==1) begin
                    if(final_emit) begin header[767:736]<=~crc_next; state<=READY; end
                    else state<=after_emit;
                end
            end
            READY: if(read_start) begin
                read_ready<=0; read_at<=read_offset; read_size<=read_length;
                read_index<=0; window<=0;
                if(read_length!=0 && read_length<=128 && {6'd0,read_offset}+{8'd0,read_length}<=header[623:608]) begin
                    fetch_addr<=read_offset[9:1]; state<=READ_WAIT;
                end
            end
            READ_WAIT: state<=READ_BYTE;
            READ_BYTE: begin
                window[{read_index[6:0],3'b000} +:8]<= read_at[0] ? ram_q[15:8] : ram_q[7:0];
                if(read_index==read_size-1'd1) begin read_ready<=1; state<=READY; end
                else begin
                    read_at<=read_at+1'd1; read_index<=read_index+1'd1;
                    fetch_addr<=(read_at[9:1]+{8'd0,read_at[0]}); state<=READ_WAIT;
                end
            end
            default: state<=IDLE;
        endcase
    end
end

jtframe_dual_ram #(
    .DW ( 16 ),
    .AW ( 9  )
) u_ram(
    .clk0  ( clk        ),
    .addr0 ( ram_addr   ),
    .data0 ( ram_data   ),
    .we0   ( ram_we     ),
    .q0    (            ),
    .clk1  ( clk        ),
    .addr1 ( fetch_addr ),
    .data1 ( 16'd0      ),
    .we1   ( 1'b0       ),
    .q1    ( ram_q      )
);

endmodule
