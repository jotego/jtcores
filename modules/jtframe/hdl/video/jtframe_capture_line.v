/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2026 */

// Capture one native line, then encode it in place in its selected BRAM bank.
module jtframe_capture_line #(
    parameter WIDTH=256,
    parameter COLORW=4
)(
    input rst,
    input clk,
    input spi_clk,
    input start,
    input sample,
    input finish,
    input abort_all,
    input [14:0] pixel,
    input bank,
    input [9:0] spi_pixel_addr,
    output [15:0] spi_pixel_data,
    output busy,
    output committed,
    output reg committed_bank,
    output reg [7:0] prefix
);

localparam IDLE=0, CAPTURE=1, FETCH=2, WAIT_RAM=3, CONSUME=4,
           CLOSE=5, EMIT=6, COMMIT=7;

reg [2:0] state, after_emit;
reg [9:0] width, run, scan, fetch_addr;
reg [8:0] rle_bytes;
reg [9:0] output_count;
reg [14:0] last_pixel, run_pixel, pair_pixel;
reg [31:0] emit_data;
reg [2:0] emit_count;
reg [7:0] low_byte;
reg [15:0] ram0_data;
reg [9:0] ram0_addr;
reg ram0_we;
reg paired, final_emit, rle_selected;
reg line_bank;
wire [15:0] ram_q;
wire [10:0] raw_bytes;
wire [9:0] complete_rle;
wire [15:0] run_word;
wire [10:0] run_cost;
wire [9:0] rle_accum;

assign busy = state!=IDLE;
assign committed = state==COMMIT;
assign raw_bytes = COLORW>=5 ? ({1'b0,width}<<1) :
                   ({1'b0,width}+{width,1'b0}+11'd1)>>1;
assign run_cost = COLORW>=5 ? (run>=2 ? 11'd4 : 11'd2) :
                  (run>=16 ? 11'd4 : 11'd2);
assign complete_rle = {1'b0,rle_bytes}+run_cost[9:0];
generate
    if(COLORW>=5) begin : gen_rgb555_runword
        assign run_word = {1'b1,run_pixel};
    end else begin : gen_rgb444_runword
        assign run_word = {run>=16 ? 4'hf : run[3:0]-4'd1,run_pixel[11:0]};
    end
endgenerate
assign rle_accum = {1'b0,rle_bytes}+run_cost[9:0];

always @* begin
    ram0_addr = {line_bank,9'd0};
    ram0_data = 16'd0;
    ram0_we = 1'b0;
    case(state)
        IDLE: begin
            if(start) begin
                ram0_addr = {bank,9'd0};
                ram0_data = COLORW>=5 ? {1'b0,pixel} : {4'd0,pixel[11:0]};
                ram0_we = sample;
            end
        end
        CAPTURE: begin
            ram0_addr = {line_bank,width[8:0]};
            ram0_data = COLORW>=5 ? {1'b0,pixel} : {4'd0,pixel[11:0]};
            ram0_we = sample && width<WIDTH;
        end
        FETCH: ram0_addr = {line_bank,scan[8:0]};
        WAIT_RAM: ram0_addr = {line_bank,fetch_addr[8:0]};
        EMIT: begin
            ram0_addr = {line_bank,output_count[9:1]};
            ram0_data = output_count[0] ? {emit_data[7:0],low_byte} : {8'd0,emit_data[7:0]};
            ram0_we = output_count[0] || (final_emit && emit_count==1);
        end
        default: ;
    endcase
end

always @(posedge clk) begin
    if(rst) begin
        state<=IDLE;
        width<=0;
        run<=0;
        scan<=0;
        fetch_addr<=0;
        rle_bytes<=0;
        output_count<=0;
        emit_data<=0;
        emit_count<=0;
        low_byte<=0;
        paired<=0;
        final_emit<=0;
        rle_selected<=0;
        line_bank<=0;
        committed_bank<=0;
        prefix<=0;
        last_pixel<=0;
        run_pixel<=0;
        pair_pixel<=0;
        after_emit<=FETCH;
    end else if(abort_all) begin
        state<=IDLE;
        width<=0;
        run<=0;
        paired<=0;
        final_emit<=0;
    end else begin
        case(state)
            IDLE: if(start) begin
                state<=CAPTURE;
                line_bank<=bank;
                width<=0;
                run<=0;
                rle_bytes<=0;
                output_count<=0;
                paired<=0;
                if(sample) begin
                    width<=1;
                    run<=1;
                    last_pixel<=pixel;
                end
            end
            CAPTURE: begin
                if(sample && width<WIDTH) begin
                    width<=width+1'd1;
                    if(pixel!=last_pixel) begin
                        if(rle_accum>10'd508) rle_bytes<=9'd509;
                        else rle_bytes<=rle_accum[8:0];
                        run<=1;
                        last_pixel<=pixel;
                    end else if(run!=10'h3ff) run<=run+1'd1;
                end
                if(finish) begin
                    if(width==0) state<=IDLE;
                    else begin
                        rle_selected <= {1'b0,complete_rle}<raw_bytes && complete_rle<=10'd508;
                        prefix <= {1'b0,complete_rle}<raw_bytes && complete_rle<=10'd508 ? complete_rle[8:1] : 8'hff;
                        scan<=0;
                        run<=0;
                        output_count<=0;
                        paired<=0;
                        if(COLORW>=5 && !({1'b0,complete_rle}<raw_bytes && complete_rle<=10'd508)) begin
                            committed_bank<=line_bank;
                            state<=COMMIT;
                        end else state<=FETCH;
                    end
                end
            end
            FETCH: begin
                fetch_addr<=scan;
                state<=WAIT_RAM;
            end
            WAIT_RAM: state<=CONSUME;
            CONSUME: begin
                scan<=scan+1'd1;
                if(rle_selected) begin
                    if(run==0 || ram_q[14:0]==run_pixel) begin
                        run_pixel<=ram_q[14:0];
                        run<=run+1'd1;
                        if(scan==width-1'd1) begin
                            if(COLORW>=5) begin
                                if(run+1'd1>=2) begin
                                    emit_data<={6'd0,run+1'd1-10'd2,1'b1,ram_q[14:0]};
                                    emit_count<=4;
                                end else begin
                                    emit_data<={16'd0,1'b0,ram_q[14:0]};
                                    emit_count<=2;
                                end
                            end else begin
                                if(run+1'd1>=16) begin
                                    emit_data<={6'd0,run-10'd15,4'hf,ram_q[11:0]};
                                    emit_count<=4;
                                end else begin
                                    emit_data<={16'd0,run[3:0],ram_q[11:0]};
                                    emit_count<=2;
                                end
                            end
                            final_emit<=1;
                            state<=EMIT;
                        end else state<=FETCH;
                    end else begin
                        if(COLORW>=5) begin
                            if(run>=2) begin
                                emit_data<={6'd0,run-10'd2,1'b1,run_pixel};
                                emit_count<=4;
                            end else begin
                                emit_data<={16'd0,1'b0,run_pixel};
                                emit_count<=2;
                            end
                        end else begin
                            if(run>=16) begin
                                emit_data<={6'd0,run-10'd16,run_word};
                                emit_count<=4;
                            end else begin
                                emit_data<={16'd0,run_word};
                                emit_count<=2;
                            end
                        end
                        run_pixel<=ram_q[14:0];
                        run<=1;
                        final_emit<=0;
                        after_emit<=scan==width-1'd1 ? CLOSE : FETCH;
                        state<=EMIT;
                    end
                end else if(!paired) begin
                    pair_pixel<=ram_q[14:0];
                    paired<=1;
                    if(scan==width-1'd1) begin
                        emit_data<={16'd0,ram_q[3:0],4'd0,ram_q[11:4]};
                        emit_count<=2;
                        final_emit<=1;
                        state<=EMIT;
                    end else state<=FETCH;
                end else begin
                    emit_data<={8'd0,ram_q[7:0],pair_pixel[3:0],ram_q[11:8],pair_pixel[11:4]};
                    emit_count<=3;
                    paired<=0;
                    final_emit<=scan==width-1'd1;
                    after_emit<=FETCH;
                    state<=EMIT;
                end
            end
            CLOSE: begin
                if(COLORW>=5) begin
                    if(run>=2) begin
                        emit_data<={6'd0,run-10'd2,1'b1,run_pixel};
                        emit_count<=4;
                    end else begin
                        emit_data<={16'd0,1'b0,run_pixel};
                        emit_count<=2;
                    end
                end else begin
                    if(run>=16) begin
                        emit_data<={6'd0,run-10'd16,run_word};
                        emit_count<=4;
                    end else begin
                        emit_data<={16'd0,run_word};
                        emit_count<=2;
                    end
                end
                final_emit<=1;
                state<=EMIT;
            end
            EMIT: begin
                if(!output_count[0]) low_byte<=emit_data[7:0];
                output_count<=output_count+1'd1;
                emit_data<=emit_data>>8;
                emit_count<=emit_count-1'd1;
                if(emit_count==1) begin
                    if(final_emit) begin
                        committed_bank<=line_bank;
                        state<=COMMIT;
                    end else state<=after_emit;
                end
            end
            COMMIT: state<=IDLE;
            default: state<=IDLE;
        endcase
    end
end

jtframe_dual_ram #(
    .DW ( 16 ),
    .AW ( 10 )
) u_pixel_ram(
    .clk0  ( clk            ),
    .addr0 ( ram0_addr      ),
    .data0 ( ram0_data      ),
    .we0   ( ram0_we        ),
    .q0    ( ram_q          ),
    .clk1  ( spi_clk        ),
    .addr1 ( spi_pixel_addr ),
    .data1 ( 16'd0          ),
    .we1   ( 1'b0           ),
    .q1    ( spi_pixel_data )
);

endmodule
