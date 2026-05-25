/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jtcps3crc_game(
    `include "jtframe_game_ports.inc"
);

assign snd         = 16'd0;
assign sample      = 1'b0;
assign dip_flip    = 1'b0;
wire [7:0] cache_status;

`ifdef JTFRAME_SIGNALTAP
/* verilator lint_off UNUSED */
reg [63:0] crc_tap;

always @(posedge clk) begin
    crc_tap <= {
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
assign debug_view  = crc_tap[{debug_bus[2:0],3'b000} +: 8];
`else
assign debug_view  = cache_status;
`endif

jtcps3crc_main u_main(
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
reg        sim_rst_l, sim_lvbl_l, sim_title_seen, sim_bank_seen;
reg [ 3:0] sim_title, sim_bank;
integer    sim_frame, sim_cache_rd;

task sim_fail;
    input [8*96-1:0] msg;
begin
    $display("FAIL: CPS3CRC simulation monitor: %0s", msg);
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
        sim_title      <= 4'd0;
        sim_bank       <= 4'd0;
        sim_title_seen <= 1'b0;
        sim_bank_seen  <= 1'b0;
        sim_frame      <= 0;
        sim_cache_rd   <= 0;
    end else begin
        if( sim_rst_l ) begin
            $display("CPS3CRC simulation monitor: reset released");
        end

        if( cpu_we ) sim_fail( "CPU attempted an SDRAM write" );
        if( cpu_rd ) sim_cache_rd <= sim_cache_rd + 1;

        if( text_we ) begin
            case( text_addr )
                10'h000: if( text_din == 8'h43 ) sim_title[0] <= 1'b1; // C
                10'h001: if( text_din == 8'h48 ) sim_title[1] <= 1'b1; // H
                10'h002: if( text_din == 8'h45 ) sim_title[2] <= 1'b1; // E
                10'h003: if( text_din == 8'h43 ) sim_title[3] <= 1'b1; // C
                10'h040: if( text_din == 8'h42 ) sim_bank[0] <= 1'b1; // B
                10'h041: if( text_din == 8'h41 ) sim_bank[1] <= 1'b1; // A
                10'h042: if( text_din == 8'h4e ) sim_bank[2] <= 1'b1; // N
                10'h043: if( text_din == 8'h4b ) sim_bank[3] <= 1'b1; // K
                default: begin
                end
            endcase
        end

        if( sim_title == 4'hf && !sim_title_seen ) begin
            sim_title_seen <= 1'b1;
            $display("CPS3CRC simulation monitor: title text written");
        end

        if( sim_bank == 4'hf && !sim_bank_seen ) begin
            sim_bank_seen <= 1'b1;
            $display("CPS3CRC simulation monitor: bank row text written");
        end

        if( sim_lvbl_l && !LVBL ) begin
            sim_frame <= sim_frame + 1;
            if( sim_frame == 3 ) begin
                if( !sim_title_seen ) sim_fail( "CHECKING title was not written after the early IRQ window" );
                if( !sim_bank_seen  ) sim_fail( "BANK row was not written after the early IRQ window" );
                if( sim_cache_rd < 1 ) sim_fail( "no SDRAM reads seen" );
                $display("PASS: CPS3CRC simulation monitor: display and read-only SDRAM access started rd=%0d", sim_cache_rd);
            end
        end
    end
end
`endif

endmodule
