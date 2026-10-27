/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-10-2026 */

// Native two-line acquisition and coherent, identity-checked SPI mailbox.

module jtframe_capture #(
    parameter WIDTH=256, HEIGHT=224, COLORW=4, CLOCK_HZ=48000000,
    parameter FEEDBACK=0
)(
    input rst, clk, game_reset, pxl_cen, lhbl, lvbl,
    input [COLORW-1:0] red, green, blue,
    input irq_level, irq_taken_toggle, dump_pause,
    input [31:0] cab_frame, cab_epoch,
    input rx_strobe,
    input [7:0] rx_cmd, rx_byte,
    input [4:0] rx_index,
    output pause_gate, capture_hold,
    output reg [1535:0] snapshot,
    output reg [767:0] line_snapshot,
    output reg [127:0] window_snapshot,
    output [1023:0] read_window
);

localparam [7:0] NATIVE_BITS=COLORW;
localparam [15:0] WIDTH16=WIDTH, HEIGHT16=HEIGHT;
localparam [31:0] CLOCK32=CLOCK_HZ;
localparam IDLE=0, WAIT_TARGET=1, CONFIRM=2, ACQUIRE=3, DONE=4, ERROR=5, RESUME=6;
reg [2:0] state;
reg [7:0] error;
reg [191:0] payload;
reg [63:0] cookie, expected_epoch, capture_seq, requested, achieved,
           first_raster,last_raster,first_game,last_game, deadline, settled_at;
reg contract_valid, pause_request, strict_capture, settled, have_source;
reg [HEIGHT-1:0] missing;
reg [9:0] remaining, y;
reg active_l, selected, selected_valid;
reg [1:0] start_line, finish_line, release_line, read_start, collecting;
reg [11:0] first_pixel[0:1];
reg [63:0] end_irq[0:1],end_raster[0:1],end_game[0:1];
reg [31:0] end_cab[0:1];
localparam YW=$clog2(HEIGHT);
reg [9:0] offset;
reg [7:0] length;
reg [31:0] next_line_seq;
reg [735:0] tags[0:1];
reg [63:0] line_irq[0:1];
reg [9:0] line_y[0:1];
reg hold_for_raster;
wire [1:0] free, ready, read_ready;
wire [767:0] headers[0:1];
wire [1023:0] windows[0:1];
wire [735:0] end_tags[0:1];
reg [191:0] packet;
wire [11:0] rgb;
wire [4*COLORW-1:0] red_repeat,green_repeat,blue_repeat;
wire [31:0] delivered;
wire [31:0] flags;
wire raster_tick, effective, lost, irq_observed, service_observed;
wire [63:0] epoch,raster,game,irqs,irq_generation,raster_now,game_now,irq_now;
wire [31:0] raster_period;
wire native_active, active_start, active_end, context_ok, identity_ok;
wire [1:0] sample_line;
wire [9:0] capture_y;
wire feedback_valid;
wire no_step;
wire [11:0] input_rgb[0:1];
genvar g;

assign capture_y=raster_tick ? 10'd0 : y;
assign feedback_valid=FEEDBACK!=0;
assign no_step=1'b0;
assign native_active=lhbl && lvbl;
assign active_start=pxl_cen && native_active && !active_l;
assign active_end=pxl_cen && !native_active && active_l;
always @* begin
    packet=payload;
    if(rx_index!=0) packet[{rx_index-5'd1,3'b000} +:8]=rx_byte;
end
assign context_ok=cookie!=0 && expected_epoch==epoch;
assign identity_ok=context_ok && payload[63:0]==cookie && payload[127:64]==capture_seq;
assign flags={26'd0,strict_capture,effective,service_observed,irq_observed,contract_valid,feedback_valid};
assign sample_line=start_line | (collecting & {2{pxl_cen && native_active}});
assign capture_hold=hold_for_raster;
assign read_window=windows[selected];
// Narrow components repeat MSBs to fill four bits. >4-bit cores do not advertise
// this RGB444-only implementation and are rejected by the MCU.
assign red_repeat={4{red}};
assign green_repeat={4{green}};
assign blue_repeat={4{blue}};
assign rgb={red_repeat[4*COLORW-1-:4],green_repeat[4*COLORW-1-:4],blue_repeat[4*COLORW-1-:4]};
assign delivered=HEIGHT-{22'd0,remaining};

always @(posedge clk) begin
    // CAB consumes the same physical edge two clocks later. Remember whether
    // *that edge* advanced logical time, rather than an asynchronous change in
    // effective pause between the native edge and the synchronized CAB tick.
    if(rst) hold_for_raster<=0;
    else if(raster_tick) hold_for_raster<=effective;
end

always @(posedge clk) begin
    if(rst) begin
        payload<=0; snapshot<=0; line_snapshot<=0; window_snapshot<=0;
        state<=IDLE; error<=0; cookie<=0; expected_epoch<=0; capture_seq<=0;
        contract_valid<=0; pause_request<=0; strict_capture<=0; settled<=0; have_source<=0;
        missing<=0; remaining<=0; y<=0; active_l<=0;
        start_line<=0; finish_line<=0; release_line<=0; read_start<=0; collecting<=0;
        selected<=0; selected_valid<=0; offset<=0; length<=0; next_line_seq<=0;
        requested<=0; achieved<=0; first_raster<=0; last_raster<=0; first_game<=0; last_game<=0;
        deadline<=0; settled_at<=0;
    end else begin
        start_line<=0; finish_line<=0; release_line<=0; read_start<=0;
        if(pxl_cen) active_l<=native_active;
        if(raster_tick) y<=0;
        else if(active_end) y<=y+1'd1;
        if(state==WAIT_TARGET && raster_tick && game_now>=requested) begin
            state<=CONFIRM; achieved<=game_now; pause_request<=1;
            deadline<=raster_now+64'd2; settled<=0;
        end
        if(state==CONFIRM) begin
            if(!effective) settled<=0;
            if(effective && !settled) begin settled<=1; settled_at<=raster; end
            if(raster_tick) begin
                if(effective && settled && raster_now>=settled_at+64'd2) begin
                    state<=ACQUIRE; strict_capture<=1;
                end else if(!effective && raster_now>=deadline) begin
                    state<=ACQUIRE; strict_capture<=0; pause_request<=0;
                end
            end
        end
        if(state==ACQUIRE) begin
            if(active_start && capture_y<HEIGHT && missing[capture_y[YW-1:0]] &&
                !(collecting[0] && line_y[0]==capture_y) && !(collecting[1] && line_y[1]==capture_y) &&
                !(ready[0] && line_y[0]==capture_y) && !(ready[1] && line_y[1]==capture_y) &&
                !( !free[0] && line_y[0]==capture_y) && !( !free[1] && line_y[1]==capture_y)) begin
                if(free[0] || free[1]) begin
                    if(free[0]) begin start_line[0]<=1; collecting[0]<=1; end
                    else begin start_line[1]<=1; collecting[1]<=1; end
                    next_line_seq<=next_line_seq+1'd1;
                    line_y[free[0] ? 0 : 1]<=capture_y;
                    first_pixel[free[0] ? 0 : 1]<=rgb;
                    line_irq[free[0] ? 0 : 1]<=irq_now;
                    tags[free[0] ? 0 : 1]<={96'd0,NATIVE_BITS,8'd0,16'd0,flags,32'd0,32'd0,16'd0,6'd0,capture_y,
                        cab_frame,irq_now,game_now,raster_now,capture_seq,epoch,cookie,next_line_seq,{7'd0,!free[0]},8'd1,16'h4c56};
                    if(!have_source) begin first_raster<=raster_now; first_game<=game_now; have_source<=1; end
                end
            end
            if(pxl_cen && native_active) begin
                if(collecting[0]) begin end_irq[0]<=irq_now; end_cab[0]<=cab_frame; end_raster[0]<=raster_now; end_game[0]<=game_now; end
                if(collecting[1]) begin end_irq[1]<=irq_now; end_cab[1]<=cab_frame; end_raster[1]<=raster_now; end_game[1]<=game_now; end
            end
            if(active_end) begin
                finish_line<=collecting; collecting<=0;
                if(collecting[0] && (end_raster[0]!=tags[0][319:256] || end_game[0]!=tags[0][383:320])) begin finish_line[0]<=0; release_line[0]<=1; end
                if(collecting[1] && (end_raster[1]!=tags[1][319:256] || end_game[1]!=tags[1][383:320])) begin finish_line[1]<=0; release_line[1]<=1; end
                last_raster<=raster_now; last_game<=game_now;
            end
            if(strict_capture && (lost || !effective)) begin
                state<=ERROR; error<=5; pause_request<=0; release_line<=3; collecting<=0;
            end
        end
        if(state==RESUME && raster_tick) begin state<=DONE; pause_request<=0; end
        if(game_reset && state!=IDLE && state!=DONE && state!=ERROR) begin
            state<=ERROR; error<=6; pause_request<=0; release_line<=3; collecting<=0;
        end
        if(rx_strobe) begin
            if(rx_index==0) payload<=0;
            else if(rx_index<=24) payload[{rx_index-5'd1,3'b000} +:8]<=rx_byte;
            if(rx_index==0) case(rx_cmd)
                8'h90: snapshot<={384'd0,delivered,8'd0,6'd0,ready,6'd0,remaining,
                    CLOCK32,raster_period,cab_epoch,cab_frame,irq_generation,last_game,first_game,last_raster,first_raster,
                    achieved,requested,irqs,game,raster,capture_seq,epoch,cookie,flags,{24'd0,NATIVE_BITS},HEIGHT16,WIDTH16,error,5'd0,state,8'd1,8'h76};
                8'h97: if(selected_valid) line_snapshot<=headers[selected];
                8'h96: window_snapshot<={32'd0,headers[selected][63:32],16'd0,6'd0,offset,8'd0,length,6'd0,selected,read_ready[selected] && selected_valid,8'h77};
                default: ;
            endcase
            if(rx_cmd==8'h98 && rx_index==17) begin
                if(state==IDLE || state==DONE || state==ERROR) begin
                    cookie<=packet[63:0]; expected_epoch<=packet[127:64]; contract_valid<=rx_byte[0]; error<=0;
                end else error<=1;
            end
            if(rx_cmd==8'h91 && rx_index==12) begin
                if(context_ok && (state==IDLE || state==DONE || state==ERROR) && WIDTH<=512 && HEIGHT<=512 && COLORW<=4 && !dump_pause) begin
                    capture_seq<=capture_seq+1'd1; requested<=packet[63:0]; state<=WAIT_TARGET;
                    remaining<=HEIGHT; missing<={HEIGHT{1'b1}}; release_line<=3; collecting<=0;
                    strict_capture<=0; selected_valid<=0; error<=0; have_source<=0;
                end else error<=2;
            end
            if(rx_cmd==8'h92 && rx_index==17) begin
                selected_valid<=0;
                if(identity_ok && rx_byte<2 && ready[rx_byte[0]]) begin
                    selected<=rx_byte[0]; selected_valid<=1;
                end else error<=3;
            end
            if(rx_cmd==8'h93 && rx_index==24) begin
                if(identity_ok && payload[135:128]<2 && ready[payload[128]] &&
                    headers[payload[128]][63:32]==payload[167:136] && rx_byte!=0 && rx_byte<=128 &&
                    {1'b0,payload[183:168]}+{9'd0,rx_byte}<= {1'b0,headers[payload[128]][623:608]}) begin
                    selected<=payload[128]; selected_valid<=1;
                    offset<=payload[177:168]; length<=rx_byte;
                    read_start[payload[128]]<=1;
                end else begin error<=4; selected_valid<=0; end
            end
            if(rx_cmd==8'h95 && rx_index==21) begin
                if(identity_ok && payload[135:128]<2 && ready[payload[128]] &&
                    headers[payload[128]][63:32]==packet[167:136] && state==ACQUIRE) begin
                    release_line[payload[128]]<=1;
                    missing[line_y[payload[128]][YW-1:0]]<=0; remaining<=remaining-1'd1;
                    selected_valid<=0;
                    if(remaining==1) state<=RESUME;
                end else error<=3;
            end
            if(rx_cmd==8'h99 && rx_index==16) begin
                if(packet[63:0]==cookie && packet[127:64]==capture_seq) begin
                    state<=IDLE; pause_request<=0; collecting<=0; release_line<=3; selected_valid<=0;
                end else error<=3;
            end
        end
    end
end

generate for(g=0;g<2;g=g+1) begin: lines
    wire [63:0] irq_delta;
    assign irq_delta=end_irq[g]-line_irq[g];
    assign input_rgb[g]=start_line[g] ? first_pixel[g] : rgb;
    assign end_tags[g]={tags[g][735:576],end_cab[g],irq_delta[31:0],tags[g][511:0]};
    jtframe_capture_line u_line(
        .rst          ( rst             ),
        .clk          ( clk             ),
        .start        ( start_line[g]   ),
        .sample       ( sample_line[g]  ),
        .finish       ( finish_line[g]  ),
        .release_line ( release_line[g] ),
        .pixel        ( input_rgb[g]    ),
        .tag          ( end_tags[g]     ),
        .read_start   ( read_start[g]   ),
        .read_offset  ( offset          ),
        .read_length  ( length          ),
        .free         ( free[g]         ),
        .ready        ( ready[g]        ),
        .header       ( headers[g]      ),
        .read_ready   ( read_ready[g]   ),
        .window       ( windows[g]      )
    );
end endgenerate

jtframe_capture_progress u_progress(
    .rst              ( rst              ),
    .clk              ( clk              ),
    .game_reset       ( game_reset       ),
    .pxl_cen          ( pxl_cen          ),
    .lvbl             ( lvbl             ),
    .irq_level        ( irq_level        ),
    .irq_taken_toggle ( irq_taken_toggle ),
    .feedback_valid   ( feedback_valid   ),
    .contract_valid   ( contract_valid   ),
    .pause_request    ( pause_request    ),
    .step             ( no_step          ),
    .raster_tick      ( raster_tick      ),
    .pause_gate       ( pause_gate       ),
    .pause_effective  ( effective        ),
    .contract_lost    ( lost             ),
    .step_done        (                  ),
    .step_failed      (                  ),
    .epoch            ( epoch            ),
    .raster_frame     ( raster           ),
    .game_frame       ( game             ),
    .irq_count        ( irqs             ),
    .irq_generation   ( irq_generation   ),
    .raster_period    ( raster_period    ),
    .irq_observed     ( irq_observed     ),
    .service_observed ( service_observed ),
    .raster_now       ( raster_now       ),
    .game_now         ( game_now         ),
    .irq_now          ( irq_now          )
);

endmodule
