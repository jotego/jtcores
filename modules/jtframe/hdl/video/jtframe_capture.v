/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2026 */

// Small ordered two-slot native-color capture stream.
module jtframe_capture #(
    parameter WIDTH=256,
    parameter HEIGHT=224,
    parameter COLORW=4
)(
    input rst,
    input clk,
    input spi_clk,
    input game_reset,
    input pxl_cen,
    input lhbl,
    input lvbl,
    input [COLORW-1:0] red,
    input [COLORW-1:0] green,
    input [COLORW-1:0] blue,
    input cab_active,
    input [31:0] cab_frame,
    input dump_pause,
    input rx_strobe,
    input [7:0] rx_cmd,
    input [7:0] rx_byte,
    input [4:0] rx_index,
    input spi_read_consume,
    input [9:0] spi_pixel_addr,
    output [15:0] spi_pixel_data,
    output [15:0] info_width,
    output [15:0] info_height,
    output reg [31:0] info_frame,
    output spi_read_ready,
    output [7:0] spi_read_prefix,
    output spi_read_bank,
    output reg cancel_toggle,
    output pause_gate,
    output reg capture_hold
);

localparam IDLE=0, WAIT_TARGET=1, SETTLE=2, ACQUIRE=3, DRAIN=4, DONE=5;
localparam [9:0] WIDTH10=WIDTH;
localparam [9:0] HEIGHT10=HEIGHT;

reg [2:0] state;
reg [31:0] local_frame, requested;
reg [39:0] begin_payload;
reg [9:0] step, next_y, residue, native_y, rows_remaining;
reg [1:0] settle_rasters;
reg begin_pending, info_capture_pending;
reg [1:0] publish_toggle;
reg [1:0] consume_meta, consume_sync;
reg [1:0] consume_toggle;
reg [1:0] publish_meta, publish_sync;
reg cancel_meta, cancel_sync, cancel_seen;
reg consumer_bank, producer_bank, cab_mode, pause_request;
reg [7:0] bank_prefix0, bank_prefix1;
reg active_l, lvbl_l, line_collecting;
reg game_reset_l;
reg engine_abort;
wire [14:0] rgb;
wire [4*COLORW-1:0] red_repeated, green_repeated, blue_repeated;
wire native_active, active_start, active_end, raster_tick;
wire [10:0] next_row_sum;
wire bank_free, engine_busy, engine_committed, engine_bank;
wire cancel_event, begin_accept, strict_cancel;
wire drain_release;
wire line_sample;
wire line_start;
wire line_finish;
wire [7:0] engine_prefix;
wire [1:0] free_slots;
wire [31:0] selected_frame;
wire [31:0] frame_after_boundary;
wire [15:0] begin_step;
wire [9:0] active_y;

assign info_width = { (COLORW>=5), 5'd0, WIDTH10 };
assign info_height = HEIGHT;
assign pause_gate = pause_request;
assign native_active = lhbl && lvbl;
assign active_start = pxl_cen && native_active && !active_l;
assign active_end = pxl_cen && !native_active && active_l;
assign raster_tick = pxl_cen && lvbl && !lvbl_l;
assign red_repeated = {4{red}};
assign green_repeated = {4{green}};
assign blue_repeated = {4{blue}};
generate
    if(COLORW>=5) begin : gen_rgb555
        assign rgb = {red_repeated[4*COLORW-1 -: 5],
                      green_repeated[4*COLORW-1 -: 5],
                      blue_repeated[4*COLORW-1 -: 5]};
    end else begin : gen_rgb444
        assign rgb = {3'd0, red_repeated[4*COLORW-1 -: 4],
                      green_repeated[4*COLORW-1 -: 4],
                      blue_repeated[4*COLORW-1 -: 4]};
    end
endgenerate
assign line_start = state==ACQUIRE && active_start && active_y==next_y &&
                    rows_remaining!=0 && !line_collecting && !engine_busy && bank_free;
assign line_finish = active_end && line_collecting;
assign line_sample = line_start || (pxl_cen && native_active && line_collecting);
assign next_row_sum = {1'b0,next_y}+{1'b0,step};
assign selected_frame = cab_mode ? cab_frame : local_frame;
assign frame_after_boundary = selected_frame+1'd1;
assign begin_step = {rx_byte,begin_payload[39:32]};
assign active_y = raster_tick ? 10'd0 : native_y;
assign strict_cancel = game_reset && !game_reset_l &&
                       (state!=IDLE || pause_request || rows_remaining!=0 ||
                        publish_toggle!=0 || line_collecting);
assign cancel_event = strict_cancel || (rx_strobe && rx_cmd==8'h99 && rx_index==0);
assign begin_accept = rx_strobe && rx_cmd==8'h91 && rx_index==6;
assign drain_release = state==DRAIN && publish_toggle==consume_sync && !engine_busy && raster_tick;
assign free_slots = {publish_toggle[1]==consume_sync[1],publish_toggle[0]==consume_sync[0]};
assign bank_free = producer_bank ? free_slots[1] : free_slots[0];
assign spi_read_bank = consumer_bank;
assign spi_read_ready = publish_sync[consumer_bank]!=consume_toggle[consumer_bank];
assign spi_read_prefix = !spi_read_ready ? 8'd0 : consumer_bank ? bank_prefix1 : bank_prefix0;

always @(posedge clk) begin
    if(rst) begin
        game_reset_l<=0;
        consume_meta<=0;
        consume_sync<=0;
    end else begin
        game_reset_l<=game_reset;
        consume_meta<=consume_toggle;
        consume_sync<=consume_meta;
    end
end

always @(posedge spi_clk or posedge rst) begin
    if(rst) begin
        publish_meta<=0;
        publish_sync<=0;
        cancel_meta<=0;
        cancel_sync<=0;
        cancel_seen<=0;
        consume_toggle<=0;
        consumer_bank<=0;
    end else begin
        publish_meta<=publish_toggle;
        publish_sync<=publish_meta;
        cancel_meta<=cancel_toggle;
        cancel_sync<=cancel_meta;
        if(cancel_sync!=cancel_seen) begin
            cancel_seen<=cancel_sync;
            consume_toggle<=publish_sync;
            consumer_bank<=0;
        end else if(spi_read_consume && spi_read_ready) begin
            consume_toggle[consumer_bank]<=publish_sync[consumer_bank];
            consumer_bank<=~consumer_bank;
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        state<=IDLE;
        local_frame<=0;
        requested<=0;
        begin_payload<=0;
        step<=16;
        next_y<=0;
        residue<=0;
        native_y<=0;
        rows_remaining<=0;
        settle_rasters<=0;
        begin_pending<=0;
        info_capture_pending<=0;
        publish_toggle<=0;
        producer_bank<=0;
        cab_mode<=0;
        pause_request<=0;
        capture_hold<=0;
        bank_prefix0<=0;
        bank_prefix1<=0;
        line_collecting<=0;
        engine_abort<=0;
        cancel_toggle<=0;
        info_frame<=0;
        active_l<=0;
        lvbl_l<=0;
    end else begin
        engine_abort<=0;
        if(pxl_cen) active_l<=native_active;
        if(pxl_cen) lvbl_l<=lvbl;
        if(game_reset) local_frame<=0;
        if(raster_tick) begin
            native_y<=0;
            capture_hold<=pause_request;
            if(!pause_request && !game_reset) local_frame<=local_frame+1'd1;
        end else if(active_end) native_y<=native_y+1'd1;

        if(rx_strobe && rx_cmd==8'h90 && rx_index==0) begin
            if(info_capture_pending) begin
                info_frame<=requested;
                info_capture_pending<=0;
            end else info_frame <= (state!=IDLE && state!=DONE) ? requested : cab_active ? cab_frame : local_frame;
        end

        if(rx_strobe && rx_cmd==8'h91) begin
            if(rx_index==0) begin_payload<=0;
            else if(rx_index<=5) begin_payload[(rx_index-1'b1)*8 +: 8]<=rx_byte;
        end

        if(state==WAIT_TARGET && raster_tick && frame_after_boundary>=requested) begin
            state<=SETTLE;
            requested<=frame_after_boundary;
            pause_request<=1;
            settle_rasters<=0;
        end else if(state==SETTLE && raster_tick) begin
            if(settle_rasters==1) begin
                settle_rasters<=2;
                state<=ACQUIRE;
            end else settle_rasters<=settle_rasters+1'd1;
        end

        if(line_start) line_collecting<=1;
        if(line_finish) line_collecting<=0;

        if(engine_committed && !cancel_event && state==ACQUIRE && rows_remaining!=0) begin
            if(rows_remaining==HEIGHT10) info_capture_pending<=1;
            if(engine_bank) bank_prefix1<=engine_prefix;
            else bank_prefix0<=engine_prefix;
            publish_toggle[engine_bank]<=~publish_toggle[engine_bank];
            producer_bank<=~engine_bank;
            rows_remaining<=rows_remaining-1'd1;
            if(rows_remaining>1) begin
                if(next_row_sum<HEIGHT) next_y<=next_row_sum[9:0];
                else begin
                    residue<=residue+1'd1;
                    next_y<=residue+1'd1;
                end
            end else state<=DRAIN;
        end

        if(drain_release) begin
            pause_request<=0;
            if(begin_pending) begin
                state<=WAIT_TARGET;
                rows_remaining<=HEIGHT10;
                next_y<=0;
                residue<=0;
                settle_rasters<=0;
                begin_pending<=0;
            end else state<=DONE;
        end

        if(cancel_event) begin
            state<=IDLE;
            pause_request<=0;
            line_collecting<=0;
            engine_abort<=1;
            rows_remaining<=0;
            begin_pending<=0;
            info_capture_pending<=0;
            publish_toggle<=0;
            producer_bank<=0;
            bank_prefix0<=0;
            bank_prefix1<=0;
            next_y<=0;
            residue<=0;
            settle_rasters<=0;
            cancel_toggle<=~cancel_toggle;
        end else if(begin_accept) begin
            if(state==DRAIN && rows_remaining==0 && publish_toggle==consume_sync && !engine_busy && !begin_pending) begin
                requested<=begin_payload[31:0];
                info_capture_pending<=0;
                step<=begin_step==0 ? 10'd1 : begin_step>HEIGHT ? HEIGHT10 : begin_step[9:0];
                cab_mode<=cab_active;
                if(drain_release) begin
                    state<=WAIT_TARGET;
                    rows_remaining<=HEIGHT10;
                    next_y<=0;
                    residue<=0;
                    settle_rasters<=0;
                    begin_pending<=0;
                end else begin_pending<=1;
            end else if((state==IDLE || state==DONE) && !dump_pause && WIDTH>0 && WIDTH<=512 && HEIGHT>0 && HEIGHT<=512) begin
                state<=WAIT_TARGET;
                requested<=begin_payload[31:0];
                info_capture_pending<=0;
                if(begin_step==0) step<=10'd1;
                else if(begin_step>HEIGHT) step<=HEIGHT10;
                else step<=begin_step[9:0];
                cab_mode<=cab_active;
                pause_request<=0;
                capture_hold<=0;
                rows_remaining<=HEIGHT10;
                next_y<=0;
                residue<=0;
                settle_rasters<=0;
                line_collecting<=0;
            end
        end
    end
end

jtframe_capture_line #(
    .WIDTH  ( WIDTH  ),
    .COLORW ( COLORW )
) u_line(
    .rst             ( rst             ),
    .clk             ( clk             ),
    .spi_clk         ( spi_clk         ),
    .start           ( line_start      ),
    .sample          ( line_sample     ),
    .finish          ( line_finish     ),
    .abort_all       ( engine_abort    ),
    .pixel           ( rgb              ),
    .bank            ( producer_bank   ),
    .spi_pixel_addr  ( spi_pixel_addr  ),
    .spi_pixel_data  ( spi_pixel_data  ),
    .busy            ( engine_busy     ),
    .committed       ( engine_committed),
    .committed_bank  ( engine_bank     ),
    .prefix          ( engine_prefix   )
);

endmodule
