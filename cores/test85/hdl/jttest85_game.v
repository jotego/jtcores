/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jttest85_game(
    `include "jtframe_game_ports.inc"
);

assign snd         = 16'd0;
assign sample      = 1'b0;
assign dip_flip    = 1'b0;
wire [7:0] cache_status;

`ifdef JTFRAME_SIGNALTAP
/* verilator lint_off UNUSED */
reg [63:0] st85_tap;

always @(posedge clk) begin
    st85_tap <= {
        text_din[7],      // 63: FAIL/red text write marker
        VS,               // 62
        HS,               // 61
        LHBL,             // 60
        pxl2_cen,         // 59
        pxl_cen,          // 58
        cen_cpu,          // 57
        cache_status,     // 56:49
        rst,              // 48
        LVBL,             // 47
        text_we,          // 46
        cpu_flush_done,   // 45
        cpu_flushing,     // 44
        cpu_flush,        // 43
        cpu_ok,           // 42
        cpu_we,           // 41
        cpu_rd,           // 40
        cpu_data,         // 39:32
        cpu_din,          // 31:24
        cpu_addr[23:0]    // 23:0
    };
end
/* verilator lint_on UNUSED */
assign debug_view  = st85_tap[{debug_bus[2:0],3'b000} +: 8];
`else
assign debug_view  = cache_status;
`endif

jttest85_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_cpu       ),
    .lvbl       ( LVBL          ),

    .cache_data ( cpu_data      ),
    .cache_ok   ( cpu_ok        ),
    .cache_flushing   ( cpu_flushing   ),
    .cache_flush_done ( cpu_flush_done ),
    .cache_addr ( cpu_addr      ),
    .cache_din  ( cpu_din       ),
    .cache_rd   ( cpu_rd        ),
    .cache_we   ( cpu_we        ),
    .cache_flush( cpu_flush     ),
    .cache_dsn  ( cpu_dsn       ),
    .cache_status( cache_status ),

    .text_addr  ( text_addr     ),
    .text_din   ( text_din      ),
    .text_dout  ( text_dout     ),
    .text_we    ( text_we       )
);

jttest85_video u_video(
    .rst        ( rst             ),
    .clk        ( clk             ),
    .pxl_cen    ( pxl_cen         ),
    .pxl2_cen   ( pxl2_cen        ),

    .text_vaddr ( text_vaddr ),
    .text_vdata ( text_vdata ),

    .LHBL       ( LHBL            ),
    .LVBL       ( LVBL            ),
    .HS         ( HS              ),
    .VS         ( VS              ),
    .red        ( red             ),
    .green      ( green           ),
    .blue       ( blue            )
);

`ifdef SIMULATION
reg        sim_rst_l, sim_lvbl_l, sim_title_seen, sim_rom_pass_seen, sim_fill_seen, sim_check_seen;
reg [ 5:0] sim_title;
reg [ 3:0] sim_rom_pass, sim_fill, sim_check;
integer    sim_frame, sim_cache_wr, sim_cache_rd, sim_cache_flush;
integer    sim_cache_flush_done;

task sim_fail;
    input [8*96-1:0] msg;
begin
    $display("FAIL: TEST85 simulation monitor: %0s", msg);
    `ifdef VERILATOR
    $fatal(1, "%0s", msg);
    `else
    $finish;
    `endif
end
endtask

always @(posedge clk) begin
    sim_rst_l  <= rst;
    sim_lvbl_l <= LVBL;

    if( rst ) begin
        sim_title            <= 6'd0;
        sim_rom_pass         <= 4'd0;
        sim_fill             <= 4'd0;
        sim_check            <= 4'd0;
        sim_title_seen       <= 1'b0;
        sim_rom_pass_seen    <= 1'b0;
        sim_fill_seen        <= 1'b0;
        sim_check_seen       <= 1'b0;
        sim_frame            <= 0;
        sim_cache_wr         <= 0;
        sim_cache_rd         <= 0;
        sim_cache_flush      <= 0;
        sim_cache_flush_done <= 0;
    end else begin
        if( sim_rst_l ) begin
            $display("TEST85 simulation monitor: reset released");
        end

        if( cpu_we         ) sim_cache_wr         <= sim_cache_wr + 1;
        if( cpu_rd         ) sim_cache_rd         <= sim_cache_rd + 1;
        if( cpu_flush      ) sim_cache_flush      <= sim_cache_flush + 1;
        if( cpu_flush_done ) sim_cache_flush_done <= sim_cache_flush_done + 1;

        if( text_we ) begin
            case( text_addr )
                10'h000: if( text_din == 8'h54 ) sim_title[0] <= 1'b1; // T
                10'h001: if( text_din == 8'h45 ) sim_title[1] <= 1'b1; // E
                10'h002: if( text_din == 8'h53 ) sim_title[2] <= 1'b1; // S
                10'h003: if( text_din == 8'h54 ) sim_title[3] <= 1'b1; // T
                10'h004: if( text_din == 8'h38 ) sim_title[4] <= 1'b1; // 8
                10'h005: if( text_din == 8'h35 ) sim_title[5] <= 1'b1; // 5
                10'h040: begin
                    if( text_din == 8'h50 ) sim_rom_pass[0] <= 1'b1; // P
                    if( text_din == 8'h46 ) sim_fail( "CPU wrote FAIL ROM status to text RAM" );
                end
                10'h041: if( text_din == 8'h41 ) sim_rom_pass[1] <= 1'b1; // A
                10'h042: if( text_din == 8'h53 ) sim_rom_pass[2] <= 1'b1; // S
                10'h043: if( text_din == 8'h53 ) sim_rom_pass[3] <= 1'b1; // S
                10'h080: begin
                    if( text_din == 8'h46 ) sim_fill[0] <= 1'b1; // F
                end
                10'h081: if( text_din == 8'h49 ) sim_fill[1] <= 1'b1; // I
                10'h082: if( text_din == 8'h4c ) sim_fill[2] <= 1'b1; // L
                10'h083: if( text_din == 8'h4c ) sim_fill[3] <= 1'b1; // L
                10'h0c0: begin
                    if( text_din == 8'h43 ) sim_check[0] <= 1'b1; // C
                end
                10'h0c1: if( text_din == 8'h48 ) sim_check[1] <= 1'b1; // H
                10'h0c2: if( text_din == 8'h45 ) sim_check[2] <= 1'b1; // E
                10'h0c3: if( text_din == 8'h43 ) sim_check[3] <= 1'b1; // C
                10'h100: if( text_din == 8'h46 ) sim_fail( "CPU wrote FAIL status to text RAM" );
                default: begin
                end
            endcase
        end

        if( sim_title == 6'h3f && !sim_title_seen ) begin
            sim_title_seen <= 1'b1;
            $display("TEST85 simulation monitor: title text written");
        end

        if( sim_rom_pass == 4'hf && !sim_rom_pass_seen ) begin
            sim_rom_pass_seen <= 1'b1;
            $display("TEST85 simulation monitor: PASS ROM text written");
        end

        if( sim_fill == 4'hf && !sim_fill_seen ) begin
            sim_fill_seen <= 1'b1;
            $display("TEST85 simulation monitor: FILL status text written");
        end

        if( sim_check == 4'hf && !sim_check_seen ) begin
            sim_check_seen <= 1'b1;
            $display("TEST85 simulation monitor: CHECK status text written");
        end

        if( sim_lvbl_l && !LVBL ) begin
            sim_frame <= sim_frame + 1;
            if( sim_frame == 3 ) begin
                if( !sim_title_seen       ) sim_fail( "TEST85 title was not written after the early IRQ window" );
                if( !sim_rom_pass_seen    ) sim_fail( "PASS ROM status was not written after the early IRQ window" );
                if( !sim_fill_seen        ) sim_fail( "FILL status was not written after the early IRQ window" );
                if( sim_cache_rd < 64     ) sim_fail( "not enough cache reads seen for ROM validation" );
                if( sim_cache_wr < 1      ) sim_fail( "no SDRAM tag write command seen after ROM validation" );
                $display("PASS: TEST85 simulation monitor: ROM validation and fill started wr=%0d rd=%0d flush=%0d flush_done=%0d",
                    sim_cache_wr, sim_cache_rd, sim_cache_flush, sim_cache_flush_done);
            end
            if( sim_frame == 15 ) begin
                if( sim_cache_flush < 1       ) sim_fail( "no cache flush command seen during SDRAM fill window" );
                if( sim_cache_flush_done < 1  ) sim_fail( "no cache flush completion seen during SDRAM fill window" );
                $display("PASS: TEST85 simulation monitor: SDRAM fill is progressing");
            end
        end
    end
end
`endif

/* verilator lint_on UNUSED */

endmodule
