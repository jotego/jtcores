/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 07-04-2026 */

module jtcps3_sprdma(
    input               rst,
    input               clk,

    input               sprdma_enable,
    input               sprdma_go,

    input       [ 9:0]  gscr0x,
    input       [ 9:0]  gscr0y,
    input       [ 9:0]  gscr1x,
    input       [ 9:0]  gscr1y,
    input       [ 9:0]  gscr2x,
    input       [ 9:0]  gscr2y,
    input       [ 9:0]  gscr3x,
    input       [ 9:0]  gscr3y,
    input       [ 9:0]  gscr4x,
    input       [ 9:0]  gscr4y,
    input       [ 9:0]  gscr5x,
    input       [ 9:0]  gscr5y,
    input       [ 9:0]  gscr6x,
    input       [ 9:0]  gscr6y,
    input       [ 9:0]  gscr7x,
    input       [ 9:0]  gscr7y,

    output reg  [ 9:0]  gscr0x_buf,
    output reg  [ 9:0]  gscr0y_buf,
    output reg  [ 9:0]  gscr1x_buf,
    output reg  [ 9:0]  gscr1y_buf,
    output reg  [ 9:0]  gscr2x_buf,
    output reg  [ 9:0]  gscr2y_buf,
    output reg  [ 9:0]  gscr3x_buf,
    output reg  [ 9:0]  gscr3y_buf,
    output reg  [ 9:0]  gscr4x_buf,
    output reg  [ 9:0]  gscr4y_buf,
    output reg  [ 9:0]  gscr5x_buf,
    output reg  [ 9:0]  gscr5y_buf,
    output reg  [ 9:0]  gscr6x_buf,
    output reg  [ 9:0]  gscr6y_buf,
    output reg  [ 9:0]  gscr7x_buf,
    output reg  [ 9:0]  gscr7y_buf,

    output reg          scndma_rd,
    output reg  [18:2]  scndma_addr,
    input       [31:0]  scndma_data,
    input               scndma_ok,

    output reg  [12:2]  scene_addr,
    output reg  [31:0]  scene_din,
    output reg  [ 3:0]  scene_we,

    output reg          dma_busy,
    output reg  [ 9:0]  objlim
);

localparam [10:0] SPRITELIST_LAST    = 11'd2044;
localparam [11:0] SPRITELIST_SIZE    = 12'd2048;
localparam [31:0] SPRITELIST_STOPPER = 32'h8000_0000;
localparam [ 9:0] OBJLIM_MAX         = 10'd512;
localparam [18:2] MAINLIST_SIZE      = 17'd2048;

localparam [ 4:0] ST_IDLE         = 5'd0,
                  ST_MAIN_RD0     = 5'd1,
                  ST_MAIN_RD1     = 5'd2,
                  ST_MAIN_RD2     = 5'd3,
                  ST_MAIN_RD3     = 5'd4,
                  ST_MAIN_DEC     = 5'd5,
                  ST_SUB_RD0      = 5'd6,
                  ST_SUB_RD1      = 5'd7,
                  ST_SUB_RD2      = 5'd8,
                  ST_SUB_RD3      = 5'd9,
                  ST_EMIT0        = 5'd10,
                  ST_EMIT1        = 5'd11,
                  ST_EMIT2        = 5'd12,
                  ST_EMIT3        = 5'd13,
                  ST_MAIN_NEXT    = 5'd14,
                  ST_FINISH_STOP  = 5'd15,
                  ST_FINISH_ZERO1 = 5'd16,
                  ST_FINISH_ZERO2 = 5'd17,
                  ST_FINISH_ZERO3 = 5'd18;

reg [4:0]  st;

reg [18:2] main_addr, sub_base, sub_addr;
reg [10:0] dst_idx;
reg [ 8:0] sub_left, sub_index;

reg [31:0] main_w0, main_w1, main_w2,
           sub_w0,  sub_w1,  sub_w2;

reg [ 9:0] gscrollx, gscrolly, xpos, ypos;
reg [ 8:0] global_pal;
reg        whichbpp, whichpal, ok_l,
           global_xflip, global_yflip,
           global_alpha, global_bpp;

reg [31:0] emit_w0, emit_w1, emit_w2, emit_w3;

wire [10:0] mergedx, mergedy;
wire [ 9:0] subx, suby;
wire [ 8:0] subpal;
wire        subbpp, subalpha, subflipy, subflipx, trigger_dma ;
wire        data_rdy;

assign subpal   = sub_w0[8:0];
assign subbpp   = sub_w0[9];
assign subalpha = sub_w0[10];
assign subflipy = sub_w0[11];
assign subflipx = sub_w0[12];
assign subx     = sub_w1[25:16];
assign suby     = sub_w1[9:0];
assign mergedx  = xpos + subx + gscrollx;
assign mergedy  = ypos + suby + gscrolly;
assign data_rdy = scndma_ok  && !ok_l;
assign trigger_dma = sprdma_go & sprdma_enable & ~dma_busy;

reg [31:0] emit0_pre, emit1_pre;
reg [ 9:0] sel_gscrx, sel_gscry;

always @(*) begin
    case (main_w0[30:28])
        3'd0: {sel_gscrx, sel_gscry} = {gscr0x, gscr0y};
        3'd1: {sel_gscrx, sel_gscry} = {gscr1x, gscr1y};
        3'd2: {sel_gscrx, sel_gscry} = {gscr2x, gscr2y};
        3'd3: {sel_gscrx, sel_gscry} = {gscr3x, gscr3y};
        3'd4: {sel_gscrx, sel_gscry} = {gscr4x, gscr4y};
        3'd5: {sel_gscrx, sel_gscry} = {gscr5x, gscr5y};
        3'd6: {sel_gscrx, sel_gscry} = {gscr6x, gscr6y};
        default: {sel_gscrx, sel_gscry} = {gscr7x, gscr7y};
    endcase

    emit0_pre[31:10] = {sub_w0[31:13],
                        subflipx ^ global_xflip,
                        subflipy ^ global_yflip,
                        subalpha | global_alpha};
    if(whichbpp)
         emit0_pre[9] = global_bpp;
    else emit0_pre[9] = subbpp;
    if(whichpal)
         emit0_pre[8:0] = global_pal;
    else emit0_pre[8:0] = subpal;

    emit1_pre = {sub_w1[31:26], mergedx[9:0], sub_w1[15:10], mergedy[9:0]};
end

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        st  <= ST_IDLE;
        ok_l         <= 1'b0;
        scndma_rd    <= 1'b0;
        scndma_addr  <= 17'd0;
        scene_addr   <= 11'd0;
        scene_din    <= 32'd0;
        scene_we     <= 4'd0;
        dma_busy     <= 1'b0;
        objlim       <= 10'd0;
        main_addr    <= 17'd0;
        dst_idx      <= 11'd0;
        sub_base     <= 17'd0;  sub_addr     <= 17'd0;
        sub_left     <= 9'd0;   sub_index    <= 9'd0;
        main_w0      <= 32'd0;  main_w1      <= 32'd0;
        main_w2      <= 32'd0;
        sub_w0       <= 32'd0;  sub_w1       <= 32'd0;
        sub_w2       <= 32'd0;
        gscrollx     <= 10'd0;  gscrolly     <= 10'd0;
        xpos         <= 10'd0;  ypos         <= 10'd0;
        whichbpp     <= 1'b0;   whichpal     <= 1'b0;
        global_alpha <= 1'b0;
        global_xflip <= 1'b0;   global_yflip <= 1'b0;
        global_bpp   <= 1'b0;   global_pal   <= 9'd0;
        emit_w0      <= 32'd0;  emit_w1      <= 32'd0;
        emit_w2      <= 32'd0;  emit_w3      <= 32'd0;
        gscr0x_buf   <= 10'd0;  gscr0y_buf   <= 10'd0;
        gscr1x_buf   <= 10'd0;  gscr1y_buf   <= 10'd0;
        gscr2x_buf   <= 10'd0;  gscr2y_buf   <= 10'd0;
        gscr3x_buf   <= 10'd0;  gscr3y_buf   <= 10'd0;
        gscr4x_buf   <= 10'd0;  gscr4y_buf   <= 10'd0;
        gscr5x_buf   <= 10'd0;  gscr5y_buf   <= 10'd0;
        gscr6x_buf   <= 10'd0;  gscr6y_buf   <= 10'd0;
        gscr7x_buf   <= 10'd0;  gscr7y_buf   <= 10'd0;
    end else begin
        scndma_rd <= 1'b0;
        scene_we  <= 4'd0;
        ok_l <= scndma_ok;

        case( st )
            ST_IDLE: begin
                dma_busy <= 1'b0;
                if( trigger_dma ) begin
                    dma_busy  <= 1'b1;
                    main_addr <= 17'd0;
                    dst_idx   <= 11'd0;
                    objlim    <= 10'd0;
                    st <= ST_MAIN_RD0;
                end
            end

            ST_MAIN_RD0: begin
                if( dst_idx >= SPRITELIST_LAST || main_addr >= MAINLIST_SIZE ) begin
                    st <= ST_FINISH_STOP;
                end else begin
                    scndma_rd   <= 1'b1;
                    scndma_addr <= main_addr;
                    if( data_rdy ) begin
                        scndma_rd <= 1'b0;
                        main_w0   <= scndma_data;
                        st <= ST_MAIN_RD1;
                        if( scndma_data[31] ) st <= ST_FINISH_STOP;
                    end
                end
            end

            ST_MAIN_RD1: begin
                scndma_rd   <= 1'b1;
                scndma_addr <= main_addr + 17'd1;
                if( data_rdy ) begin
                    scndma_rd <= 1'b0;
                    main_w1   <= scndma_data;
                    st <= ST_MAIN_RD2;
                end
            end

            ST_MAIN_RD2: begin
                scndma_rd   <= 1'b1;
                scndma_addr <= main_addr + 17'd2;
                if( data_rdy ) begin
                    scndma_rd <= 1'b0;
                    main_w2   <= scndma_data;
                    st <= ST_MAIN_RD3;
                end
            end

            ST_MAIN_RD3: begin
                scndma_rd   <= 1'b1;
                scndma_addr <= main_addr + 17'd3;
                if( data_rdy ) begin
                    scndma_rd <= 1'b0;
                    st <= ST_MAIN_DEC;
                end
            end

            ST_MAIN_DEC: begin
                sub_base     <={main_w0[14:4], 6'b0};
                sub_left     <= main_w0[24:16];
                sub_index    <= 9'd0;
                xpos         <= main_w1[25:16];
                ypos         <= main_w1[9:0];
                whichbpp     <= main_w2[30];
                whichpal     <= main_w2[29];
                global_xflip <= main_w2[28];
                global_yflip <= main_w2[27];
                global_alpha <= main_w2[26];
                global_bpp   <= main_w2[25];
                global_pal   <= main_w2[24:16];
                gscrollx     <= sel_gscrx;
                gscrolly     <= sel_gscry;
                if( main_w0[24:16] == 9'd0 ) begin
                    st <= ST_MAIN_NEXT;
                end else begin
                    sub_addr <= { main_w0[14:4], 6'b0 };
                    st <= ST_SUB_RD0;
                end
            end

            ST_SUB_RD0: begin
                if( dst_idx >= SPRITELIST_LAST ) begin
                    st <= ST_FINISH_STOP;
                end else begin
                    scndma_rd   <= 1'b1;
                    scndma_addr <= sub_addr;
                    if( data_rdy ) begin
                        scndma_rd   <= 1'b0;
                        sub_w0 <= scndma_data;
                        st <= ST_SUB_RD1;
                    end
                end
            end

            ST_SUB_RD1: begin
                scndma_rd   <= 1'b1;
                scndma_addr <= sub_addr + 17'd1;
                if( data_rdy ) begin
                    scndma_rd   <= 1'b0;
                    sub_w1 <= scndma_data;
                    st <= ST_SUB_RD2;
                end
            end

            ST_SUB_RD2: begin
                scndma_rd   <= 1'b1;
                scndma_addr <= sub_addr + 17'd2;
                if( data_rdy ) begin
                    scndma_rd   <= 1'b0;
                    sub_w2 <= scndma_data;
                    st <= ST_SUB_RD3;
                end
            end

            ST_SUB_RD3: begin
                scndma_rd   <= 1'b1;
                scndma_addr <= sub_addr + 17'd3;
                if( data_rdy ) begin
                    scndma_rd   <= 1'b0;
                    emit_w0 <= emit0_pre;
                    emit_w1 <= emit1_pre;
                    emit_w2 <= sub_w2;
                    emit_w3 <= scndma_data;
                    st <= ST_EMIT0;
                end
            end

            ST_EMIT0: begin
                scene_addr <= dst_idx;
                scene_din  <= emit_w0;
                scene_we   <= 4'hf;
                st <= ST_EMIT1;
            end

            ST_EMIT1: begin
                scene_addr <= dst_idx + 11'd1;
                scene_din  <= emit_w1;
                scene_we   <= 4'hf;
                st <= ST_EMIT2;
            end

            ST_EMIT2: begin
                scene_addr <= dst_idx + 11'd2;
                scene_din  <= emit_w2;
                scene_we   <= 4'hf;
                st <= ST_EMIT3;
            end

            ST_EMIT3: begin
                scene_addr <= dst_idx + 11'd3;
                scene_din  <= emit_w3;
                scene_we   <= 4'hf;
                dst_idx <= dst_idx + 11'd4;
                if( objlim < OBJLIM_MAX ) begin
                    objlim <= objlim + 10'd1;
                end
                sub_left  <= sub_left - 9'd1;
                sub_index <= sub_index + 9'd1;
                if( dst_idx >= SPRITELIST_LAST ) begin
                    st <= ST_FINISH_STOP;
                end else if( sub_left == 9'd1 ) begin
                    st <= ST_MAIN_NEXT;
                end else begin
                    sub_addr <= sub_base + { 6'd0, sub_index + 9'd1, 2'b00 };
                    st <= ST_SUB_RD0;
                end
            end

            ST_MAIN_NEXT: begin
                main_addr <= main_addr + 17'd4;
                st <= ST_MAIN_RD0;
            end

            ST_FINISH_STOP: begin
                if( {1'b0, dst_idx} < SPRITELIST_SIZE ) begin
                    scene_addr <= dst_idx;
                    scene_din  <= SPRITELIST_STOPPER;
                    scene_we   <= 4'hf;
                end
                st <= ST_FINISH_ZERO1;
            end

            ST_FINISH_ZERO1: begin
                if( dst_idx <= 11'd2046 ) begin
                    scene_addr <= dst_idx + 11'd1;
                    scene_din  <= 32'd0;
                    scene_we   <= 4'hf;
                end
                st <= ST_FINISH_ZERO2;
            end

            ST_FINISH_ZERO2: begin
                if( dst_idx <= 11'd2045 ) begin
                    scene_addr <= dst_idx + 11'd2;
                    scene_din  <= 32'd0;
                    scene_we   <= 4'hf;
                end
                st <= ST_FINISH_ZERO3;
            end

            ST_FINISH_ZERO3: begin
                if( dst_idx <= 11'd2044 ) begin
                    scene_addr <= dst_idx + 11'd3;
                    scene_din  <= 32'd0;
                    scene_we   <= 4'hf;
                end
                {gscr0x_buf, gscr1x_buf, gscr2x_buf, gscr3x_buf,
                 gscr4x_buf, gscr5x_buf, gscr6x_buf, gscr7x_buf} <= {gscr0x, gscr1x, gscr2x, gscr3x,
                                                                     gscr4x, gscr5x, gscr6x, gscr7x};
                {gscr0y_buf, gscr1y_buf, gscr2y_buf, gscr3y_buf,
                 gscr4y_buf, gscr5y_buf, gscr6y_buf, gscr7y_buf} <= {gscr0y, gscr1y, gscr2y, gscr3y,
                                                                     gscr4y, gscr5y, gscr6y, gscr7y};

                dma_busy <= 1'b0;
                st <= ST_IDLE;
            end

            default: st <= ST_IDLE;
        endcase
    end
end

endmodule
