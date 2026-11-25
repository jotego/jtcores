/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 13-1-2020 */

module jtcps1_dma(
    input              rst,
    input              clk,
    input              pxl_cen,
    input              pxl2_cen,

    input              HB,
    input      [ 8:0]  vrender1,
    input              flip,

    input      [ 3:1]  scrdma_en,

    input      [15:0]  vram1_base,
    input      [15:0]  hpos1,
    input      [15:0]  vpos1,

    input      [15:0]  vram2_base,
    input      [15:0]  hpos2,
    input      [15:0]  vpos2,

    input      [15:0]  vram3_base,
    input      [15:0]  hpos3,
    input      [15:0]  vpos3,

    input      [15:0]  vram_row_base,
    input      [15:0]  row_offset,
    input              row_en,
    output reg [15:0]  row_scr,

    input      [ 7:0]  tile_addr,
    output     [15:0]  tile_data,

    input              objdma_en,
    input      [15:0]  vram_obj_base,
    input      [ 9:0]  obj_table_addr,
    input              obj_dma_ok,
    output     [15:0]  obj_table_data,

    input      [15:0]  vram_pal_base,
    input              pal_dma_ok,
    input      [11:0]  colmix_addr,
    output     [15:0]  pal_data,
    input      [ 5:0]  pal_page_en,

    output reg [17:1]  vram_addr,
    input      [15:0]  vram_data,
    input              vram_ok,
    output             vram_clr,
    output             vram_cs,
    output reg         rfsh_en,
    output reg         br,
    input              bg,

    output             watch_scr1,
    output             watch_scr2,
    output             watch_scr3,
    output             watch_pal,
    output             watch_row,
    output             watch_obj
);

localparam TASKW=1+1+3+6;
localparam [7:0] LAST_SCR1 = 8'd99, LAST_SCR2 = 8'd225, LAST_SCR3 = 8'd255;
localparam ROW=0, OBJ=1, SCR1=2, SCR2=3, SCR3=4,
           PAL0=5, PAL1=6,PAL2=7,PAL3=8,PAL4=9,PAL5=10;
localparam MW = 3;

reg  [15:0] vrenderf, vscr1, vscr2, vscr3, row_scr_next;
reg  [11:0] scan;
wire [11:0] wr_pal_addr;
wire [15:0] pal_ram_q;
wire [ 2:0] pal_target_page;
reg  [10:0] vn, hn, hstep;
reg  [ 9:0] obj_cnt, obj_wr_cnt;
reg  [ 8:0] pal_cnt, pal_wr_cnt, vram_scr_base;
reg  [ 7:0] scr_cnt, scr_over, scr_wr_cnt;
reg  [MW-1:0] misses;
reg  [ 3:0] step;
reg  [ 3:0] hdr_cnt;

localparam [3:0] HEADER = 4'd9;
localparam       SCR3_ROW_MSB = 4;
reg  [ 2:0] active, swap, pal_rd_page, pal_wr_page;

wire [ TASKW-1:0] next_step_task, next_task;
reg  [ TASKW-1:0] tasks, step_task, cur_task;

reg         last_HB, line_req, last_pal_dma_ok, pal_busy;
reg  [ 5:0] pal_enable_mask;
reg         pal_seen_enabled;
reg         rd_bank, wr_bank, adv, check_adv;
reg         rd_obj_bank, wr_obj_bank;
reg         scr_wr, obj_wr, pal_wr;
reg         obj_fill, obj_end, fill_found, fill_en;
reg  [ 9:3] obj_base_l;

wire        HB_edge  = !last_HB && HB;
wire        row_ok   = vrender1<9'd240 || vrender1>9'd257;
wire        tile_first = vrender1 == 9'd15;
wire        tile_ok    = vrender1 >  9'd15 && vrender1 < 9'd239;

wire [17:1] vrow_addr = { vram_row_base[9:3], row_offset[9:0] + vrenderf[9:0] },
            vscr_addr = { vram_scr_base[8:5], scan, scr_cnt[0] },
            vobj_addr = { obj_base_l, obj_cnt },
            vpal_addr = { vram_pal_base[9:0], 7'd0 } + { 5'd0, pal_rd_page , pal_cnt };

assign watch_obj  = tasks[OBJ];
assign watch_scr1 = tasks[SCR1];
assign watch_scr2 = tasks[SCR2];
assign watch_scr3 = tasks[SCR3];
assign watch_row  = tasks[ROW];
assign watch_pal  = |tasks[PAL5:PAL0];

always @(*) begin
    wr_bank = cur_task[SCR1] ? ~active[0] :
              cur_task[SCR3] ? ~active[2] : ~active[1];
    rd_bank = !tile_addr[7]          ? active[0] : (
              tile_addr <= LAST_SCR2 ? active[1] :
                                       active[2]);
end

always @(*) begin
    fill_found = cur_task[OBJ] && obj_cnt[1:0]==2'b11 && vram_data[15:8]==8'hff;
    fill_en    = fill_found | obj_fill;
end

reg [15:0] tile_din, obj_din, pal_din;

assign vram_clr = 0;

jtframe_dual_ram #(.DW(16), .AW(9)) u_tile_cache(
    .clk0   ( clk           ),
    .clk1   ( clk           ),
    .data0  ( tile_din      ),
    .addr0  ( { wr_bank, scr_wr_cnt   } ),
    .we0    ( scr_wr        ),
    .q0     (               ),
    .data1  ( ~16'd0        ),
    .addr1  ( { rd_bank, tile_addr  } ),
    .we1    ( 1'b0          ),
    .q1     ( tile_data     )
);

jtframe_dual_ram #(.DW(16), .AW(11)) u_obj_cache(
    .clk0   ( clk           ),
    .clk1   ( clk           ),
    .data0  ( obj_din       ),
    .addr0  ( { wr_obj_bank, obj_wr_cnt } ),
    .we0    ( obj_wr        ),
    .q0     (               ),
    .data1  ( ~16'd0        ),
    .addr1  ( { rd_obj_bank, obj_table_addr  } ),
    .we1    ( 1'b0          ),
    .q1     ( obj_table_data)
);

assign wr_pal_addr = { pal_wr_page, pal_wr_cnt };
assign pal_target_page = pal_wr_page + { 2'd0, (&pal_wr_cnt) };

jtframe_dual_ram #(.DW(16), .AW(12)) u_pal_ram(
    .clk0   ( clk           ),
    .clk1   ( clk           ),
    .data0  ( pal_din       ),
    .addr0  ( wr_pal_addr   ),
    .we0    ( pal_wr        ),
    .q0     (               ),
    .data1  ( ~16'd0        ),
    .addr1  ( colmix_addr   ),
    .we1    ( 1'b0          )
    `ifndef FORCE_GRAY
    ,.q1    ( pal_ram_q     )
    `endif
);

assign pal_data = colmix_addr == 12'hFFF ? 16'h0 : pal_ram_q;

`ifdef FORCE_GRAY
assign pal_data = {4'hf, {3{colmix_addr[3:0]}} };
`endif

always @(*) begin
    if( cur_task[SCR1] ) begin
        scan   = { vn[8],   hn[8:3], vn[7:3] };
        hstep  = 11'd8;
    end else if( cur_task[SCR2] ) begin
        scan   = { vn[9:8], hn[9:4], vn[7:4] };
        hstep  = 11'd16;
    end else begin
        scan   = { vn[10:8], hn[10:5], vn[7:5] };
        hstep  = 11'd32;
    end
end

assign vram_cs        = br;
assign next_step_task = step_task<<1;
assign next_task      = step_task & tasks;

always @(posedge clk) begin
    vscr1 <= vpos1 + vrenderf;
    vscr2 <= vpos2 + vrenderf;
    vscr3 <= vpos3 + vrenderf;
end

`ifdef SIMULATION
wire on_scr1 = cur_task[SCR1];
wire on_scr2 = cur_task[SCR2];
wire on_scr3 = cur_task[SCR3];
wire on_row  = cur_task[ROW];
wire on_obj  = cur_task[OBJ];
wire on_pal  = |cur_task[PAL5:PAL0];
`endif

always @(posedge clk) begin
    if( rst ) begin
        tasks       <= {TASKW{1'b0}};
        cur_task    <= {TASKW{1'b0}};
        step_task   <= {TASKW{1'b0}};
        last_HB     <= 1;
        br          <= 0;
        adv         <= 0;
        check_adv   <= 0;
        step        <= 4'b1;
        line_req    <= 0;
        hdr_cnt     <= 4'd0;
        active      <= 3'b0;
        swap        <= 3'b0;
        pal_cnt     <= 9'd0;
        pal_wr_cnt  <= 9'd0;
        vram_addr   <= 0;
        misses      <= {MW{1'b0}};
        rfsh_en     <= 1;
        pal_rd_page <= 3'd0;
        pal_wr_page <= 3'd0;
        pal_enable_mask <= 6'd0;
        pal_seen_enabled <= 1'b0;
        rd_obj_bank <= 0;
        wr_obj_bank <= 1;
        scr_wr      <= 0;
        obj_wr      <= 0;
        pal_wr      <= 0;
        obj_fill    <= 0;
        obj_end     <= 1;
        obj_base_l  <= 0;
        obj_cnt     <= 10'd0;
        vrenderf    <= 16'd0;
    end else if(pxl2_cen) begin
        last_HB <= HB;
        last_pal_dma_ok <= pal_dma_ok;
        scr_wr <= 0;
        obj_wr <= 0;
        pal_wr <= 0;

        if( pal_dma_ok && !last_pal_dma_ok ) begin
            pal_busy <= 1;
        end

        if( HB_edge ) begin
            line_req <= 1;
            active   <= active ^ swap;
            swap     <= 3'd0;
            vrenderf <= {7'd0, (vrender1 ^ { 1'b0, {8{flip}}}) + (flip ? -9'd8 : 9'd1) };
        end

        if( line_req && step[0] ) begin
            line_req    <= 0;
            hdr_cnt     <= HEADER;
            pal_busy    <= 0;
            tasks[OBJ] <= !obj_end;
            if( pal_busy ) begin
                pal_rd_page      <= 3'd0;
                pal_wr_page      <= 3'd0;
                pal_enable_mask  <= pal_page_en;
                pal_seen_enabled <= 1'b0;
                tasks[PAL5:PAL0] <= 6'h3f;
                pal_cnt          <= 9'd0;
            end
            tasks[ROW ] <= row_en & row_ok;
            tasks[SCR1] <= scrdma_en[1] && ((vscr1[2:0]==3'd0 && tile_ok) || tile_first);
            tasks[SCR2] <= scrdma_en[2] && ((vscr2[3:0]=={ flip, 3'd0 } && tile_ok) || tile_first);
            tasks[SCR3] <= scrdma_en[3] && ((vscr3[SCR3_ROW_MSB:0]=={ {SCR3_ROW_MSB-2{flip}}, 3'd0 } && tile_ok) || tile_first);
            scr_cnt     <= 8'd0;
            check_adv   <= 1;
            row_scr     <= row_en ? row_scr_next : {12'b0, hpos2[3:0] };
        end else
        if( check_adv ) begin
            cur_task  <= {TASKW{1'b0}};
            step_task <= { {TASKW-1{1'b0}}, 1'b1 };
            adv       <= HEADER!=0 || |tasks;
            check_adv <= 0;
            br        <= HEADER!=0 || |tasks;
            rfsh_en   <= ~&tasks[SCR3:SCR1];
        end else
        if( bg && br && hdr_cnt!=0 ) begin
            hdr_cnt <= hdr_cnt-4'd1;
        end else
        if( bg && br ) begin
            if( adv ) begin
                step_task <= next_step_task;
                cur_task  <= next_task;
                if( ~|tasks ) begin
                    br      <= 0;
                    misses  <= {MW{1'd0}};
                    rfsh_en <= 1;
                end else
                    step      <= 4'b1;
                adv <= ~|next_task;
                if( next_task[SCR1] ) begin
                    vn        <= vscr1[10:0] + { 8'd0, {3{flip}} };
                    hn        <= 11'h38 + { hpos1[10:3], 3'b0 };
                    scr_cnt   <= 8'd0;
                    scr_over  <= LAST_SCR1;
                    swap[0]   <= 1'b1;
                    vram_scr_base <= vram1_base[9:1];
                end
                if( next_task[SCR2] ) begin
                    vn        <= vscr2[10:0] + { 8'd0, {3{flip}} };
                    hn        <= 11'h30 + { hpos2[10:4], 4'b0 };
                    scr_cnt   <= 8'd128;
                    scr_over  <= LAST_SCR2;
                    swap[1]   <= 1'b1;
                    vram_scr_base <= vram2_base[9:1];
                end
                if( next_task[SCR3]) begin
                    vn        <= vscr3[10:0] + { 8'd0, {3{flip}} };
                    hn        <= 11'h20 + { hpos3[10:5], 5'b0 };
                    scr_cnt   <= LAST_SCR2+8'd1;
                    scr_over  <= LAST_SCR3;
                    swap[2]   <= 1'b1;
                    vram_scr_base <= vram3_base[9:1];
                end
            end
            else begin
                if( step[3] && !vram_ok ) begin
                    if( ~&misses ) misses <= misses + 1'd1;
                end else begin
                    if( step[1] && vram_ok && misses!=0 ) begin
                        misses <= misses - 1'd1;
                        step <= 4'b1000;
                    end else begin
                        step <= { step[2:0], step[3] };
                    end
                end
                case( step )
                    4'd1: begin
                        vram_addr <=  cur_task[ROW]       ? vrow_addr : (
                                     |cur_task[SCR3:SCR1] ? vscr_addr : (
                                      cur_task[OBJ]       ? vobj_addr :
                                      vpal_addr ));
                    end
                    default:;
                    4'd8: if( vram_ok ) begin
                        tile_din <= vram_data;
                        obj_din  <= vram_data & {16{~fill_en}};
                        scr_wr   <= |cur_task[SCR3:SCR1];
                        obj_wr   <= cur_task[OBJ];
                        pal_wr   <= |cur_task[PAL5:PAL0] && pal_target_page<3'd6 &&
                                    pal_enable_mask[pal_target_page];
                        scr_wr_cnt <= scr_cnt;
                        obj_wr_cnt <= obj_cnt;
                        if( |cur_task[PAL5:PAL0] ) begin
                            pal_din    <= vram_data;
                            pal_wr_cnt <= pal_cnt;
                        end

                        if( |cur_task[SCR3:SCR1] ) begin
                            if( scr_cnt==scr_over ) begin
                                adv     <= 1;
                                if( cur_task[SCR1] ) tasks[SCR1] <= 0;
                                if( cur_task[SCR2] ) tasks[SCR2] <= 0;
                                if( cur_task[SCR3] ) tasks[SCR3] <= 0;
                            end
                            else begin
                                scr_cnt <= scr_cnt+8'd1;
                                if( scr_cnt[0] )
                                    hn <= hn + hstep;
                            end
                        end else
                        if( cur_task[ROW] ) begin
                            adv        <= 1;
                            tasks[ROW] <= 0;
                            row_scr_next <= {12'b0, hpos2[3:0] } + vram_data;
                        end
                        if( cur_task[OBJ] ) begin
                            obj_cnt  <= obj_cnt + 10'd1;
                            obj_fill <= fill_en;
                            if( cur_task[OBJ] ) begin
                                adv <= (&obj_cnt[1:0]);
                                if( &obj_cnt[1:0] ) tasks[OBJ]<=0;
                            end
                            if( &obj_cnt ) begin
                                obj_end  <= 1;
                                obj_fill <= 0;
                            end
                        end
                        if( |cur_task[PAL5:PAL0] ) begin
                            pal_cnt <= pal_cnt + 9'd1;
                            if( &pal_wr_cnt ) begin
                                tasks[PAL5:PAL0] <= tasks[PAL5:PAL0] & ~cur_task[PAL5:PAL0];
                                adv <= 1;
                                pal_wr_page <= pal_wr_page+3'd1;
                                pal_seen_enabled <= pal_seen_enabled |
                                    |(cur_task[PAL5:PAL0] & pal_enable_mask);
                            end
                            if( &pal_cnt ) begin
                                if( pal_seen_enabled |
                                    |(cur_task[PAL5:PAL0] & pal_enable_mask) )
                                    pal_rd_page<=pal_rd_page+3'd1;
                            end
                        end
                    end
                endcase
            end
        end
        if( HB_edge && vrender1==9'd0 && objdma_en && obj_end ) begin
            obj_base_l  <= vram_obj_base[9:3];
            wr_obj_bank <= ~wr_obj_bank;
            rd_obj_bank <= wr_obj_bank;
            obj_fill    <= 0;
            obj_end     <= 0;
            obj_cnt     <= 0;
        end
    end
end

endmodule
