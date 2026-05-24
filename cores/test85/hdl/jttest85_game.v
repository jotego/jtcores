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
wire [7:0] sdram_status;

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
        cen6,             // 57
        sdram_status,     // 56:49
        rst,              // 48
        LVBL,             // 47
        text_we,          // 46
        1'b0,             // 45
        1'b0,             // 44
        cpu_cs,           // 43
        cpu_ok,           // 42
        cpu_we,           // 41
        ~cpu_we & cpu_cs, // 40
        cpu_data,         // 39:32
        cpu_din,          // 31:24
        1'b0,             // 23
        cpu_addr          // 22:0
    };
end
/* verilator lint_on UNUSED */
assign debug_view  = st85_tap[{debug_bus[2:0],3'b000} +: 8];
`else
assign debug_view  = sdram_status;
`endif

jttest85_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen6          ),
    .lvbl       ( LVBL          ),

    .sdram_data ( cpu_data      ),
    .sdram_ok   ( cpu_ok        ),
    .sdram_addr ( cpu_addr      ),
    .sdram_din  ( cpu_din       ),
    .sdram_cs   ( cpu_cs        ),
    .sdram_we   ( cpu_we        ),
    .sdram_dsn  ( cpu_dsn       ),
    .sdram_status( sdram_status ),

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
reg        sim_rst_l, sim_lvbl_l, sim_title_seen, sim_pass_seen;
reg [ 5:0] sim_title;
reg [ 3:0] sim_pass;
integer    sim_frame, sim_sdram_wr, sim_sdram_rd;

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
        sim_pass             <= 4'd0;
        sim_title_seen       <= 1'b0;
        sim_pass_seen        <= 1'b0;
        sim_frame            <= 0;
        sim_sdram_wr         <= 0;
        sim_sdram_rd         <= 0;
    end else begin
        if( sim_rst_l ) begin
            $display("TEST85 simulation monitor: reset released");
        end

        if( cpu_cs &&  cpu_we ) sim_sdram_wr <= sim_sdram_wr + 1;
        if( cpu_cs && !cpu_we ) sim_sdram_rd <= sim_sdram_rd + 1;

        if( text_we ) begin
            case( text_addr )
                10'h000: if( text_din == 8'h54 ) sim_title[0] <= 1'b1; // T
                10'h001: if( text_din == 8'h45 ) sim_title[1] <= 1'b1; // E
                10'h002: if( text_din == 8'h53 ) sim_title[2] <= 1'b1; // S
                10'h003: if( text_din == 8'h54 ) sim_title[3] <= 1'b1; // T
                10'h004: if( text_din == 8'h38 ) sim_title[4] <= 1'b1; // 8
                10'h005: if( text_din == 8'h35 ) sim_title[5] <= 1'b1; // 5
                10'h080: begin
                    if( text_din == 8'h50 ) sim_pass[0] <= 1'b1; // P
                    if( text_din == 8'h46 ) sim_fail( "CPU wrote FAIL status to text RAM" );
                end
                10'h081: if( text_din == 8'h41 ) sim_pass[1] <= 1'b1; // A
                10'h082: if( text_din == 8'h53 ) sim_pass[2] <= 1'b1; // S
                10'h083: if( text_din == 8'h53 ) sim_pass[3] <= 1'b1; // S
                default: begin
                end
            endcase
        end

        if( sim_title == 6'h3f && !sim_title_seen ) begin
            sim_title_seen <= 1'b1;
            $display("TEST85 simulation monitor: title text written");
        end

        if( sim_pass == 4'hf && !sim_pass_seen ) begin
            sim_pass_seen <= 1'b1;
            $display("TEST85 simulation monitor: PASS text written");
        end

        if( sim_lvbl_l && !LVBL ) begin
            sim_frame <= sim_frame + 1;
            if( sim_frame == 10 ) begin
                if( !sim_title_seen           ) sim_fail( "TEST85 title was not written after the tenth IRQ frame" );
                if( !sim_pass_seen            ) sim_fail( "PASS status was not written after the tenth IRQ frame" );
                if( sim_sdram_wr < 1          ) sim_fail( "no SDRAM write command seen after the tenth IRQ frame" );
                if( sim_sdram_rd < 2          ) sim_fail( "not enough SDRAM read commands seen after the tenth IRQ frame" );
                $display("PASS: TEST85 simulation monitor: IRQ frame activity wr=%0d rd=%0d",
                    sim_sdram_wr, sim_sdram_rd);
            end
        end
    end
end
`endif

/* verilator lint_on UNUSED */

endmodule
