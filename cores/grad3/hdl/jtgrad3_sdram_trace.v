`ifdef JTGRAD3_TRACE_SDRAM
module jtgrad3_sdram_trace(
    input             clk,
    input             rst,
    input      [21:0] ba0_addr,
    input      [ 3:0] ba_rd,
    input      [ 3:0] ba_ack,
    input      [ 3:0] ba_dst,
    input      [ 3:0] ba_rdy,
    input      [15:0] data_read,
    input      [17:1] main_addr,
    input             main_cs,
    input             main_ok,
    input      [15:0] main_data,
    input      [ 1:0] bank0_req,
    input      [ 1:0] bank0_sel
);

always @(posedge clk) begin
    if( !rst && (main_cs || ba_ack[0] || ba_dst[0] || ba_rdy[0]) ) begin
        $display("G3SD b0addr=%06x rd=%b ack=%b dst=%b rdy=%b din=%04x main=%b:%05x ok=%b data=%04x req=%b sel=%b",
            ba0_addr, ba_rd[0], ba_ack[0], ba_dst[0], ba_rdy[0], data_read,
            main_cs, main_addr, main_ok, main_data, bank0_req, bank0_sel);
    end
end

endmodule

bind jtgrad3_game_sdram jtgrad3_sdram_trace u_jtgrad3_sdram_trace(
    .clk       ( clk             ),
    .rst       ( rst             ),
    .ba0_addr  ( ba0_addr        ),
    .ba_rd     ( ba_rd           ),
    .ba_ack    ( ba_ack          ),
    .ba_dst    ( ba_dst          ),
    .ba_rdy    ( ba_rdy          ),
    .data_read ( data_read       ),
    .main_addr ( main_addr       ),
    .main_cs   ( main_cs         ),
    .main_ok   ( main_ok         ),
    .main_data ( main_data       ),
    .bank0_req ( u_bank0.req     ),
    .bank0_sel ( u_bank0.slot_sel)
);

module jtgrad3_sdram_pin_trace(
    input             clk,
    input      [15:0] SDRAM_DQ,
    input      [12:0] SDRAM_A,
    input      [ 1:0] SDRAM_BA,
    input             SDRAM_DQML,
    input             SDRAM_DQMH,
    input             SDRAM_nWE,
    input             SDRAM_nCAS,
    input             SDRAM_nRAS,
    input             SDRAM_nCS,
    input      [15:0] data_read,
    input      [ 3:0] ba_rdy,
    input      [ 3:0] ba_dst,
    input      [31:0] frame_cnt
);

wire [3:0] cmd = { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE };

always @(posedge clk) begin
    if( frame_cnt >= 32'd95 &&
        (cmd != 4'b0111 || ba_dst[0] || ba_rdy[0] || SDRAM_DQ != 16'd0) ) begin
        $display("G3PIN cmd=%b ba=%0d a=%04x dqm=%b%b dq=%04x data=%04x dst=%b rdy=%b",
            cmd, SDRAM_BA, SDRAM_A, SDRAM_DQMH, SDRAM_DQML,
            SDRAM_DQ, data_read, ba_dst[0], ba_rdy[0]);
    end
end

endmodule

bind game_test jtgrad3_sdram_pin_trace u_jtgrad3_sdram_pin_trace(
    .clk       ( clk        ),
    .SDRAM_DQ  ( SDRAM_DQ   ),
    .SDRAM_A   ( SDRAM_A    ),
    .SDRAM_BA  ( SDRAM_BA   ),
    .SDRAM_DQML( SDRAM_DQML ),
    .SDRAM_DQMH( SDRAM_DQMH ),
    .SDRAM_nWE ( SDRAM_nWE  ),
    .SDRAM_nCAS( SDRAM_nCAS ),
    .SDRAM_nRAS( SDRAM_nRAS ),
    .SDRAM_nCS ( SDRAM_nCS  ),
    .data_read ( data_read  ),
    .ba_rdy    ( ba_rdy     ),
    .ba_dst    ( ba_dst     ),
    .frame_cnt ( frame_cnt  )
);
`endif
