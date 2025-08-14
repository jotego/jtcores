module test;

wire rst, clk, pxl_cen, lhbl, vs;
wire [8:0] ln_v;

// always @(posedge clk) begin
//     if(uut.st==4'b10) $finish;
// end

jtframe_lfbuf_ctrl uut(
    .rst        ( rst           ),    // hold in reset for >150 us
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .lhbl       ( lhbl          ),
    .vs         ( ln_v[3]       ),
    .ln_done    ( 1'b0          ),
    .vrender    ( ln_v[7:0]     ),
    .ln_v       ( ln_v[7:0]     ),
    // data written to external memory
    .frame      ( 1'b0          ),
    .fb_addr    (               ),
    .fb_din     ( 16'd0         ),
    .fb_clr     (               ),
    .fb_done    (               ),

    // data read from external memory to screen buffer
    // during h blank
    .fb_dout    (               ),
    .rd_addr    (               ),
    .line       (               ),
    .scr_we     (               ),

    // cell RAM (PSRAM) signals
    .cr_addr    (               ),
    .cr_adq     (               ),
    .cr_wait    ( 1'b0          ),
    .cr_clk     (               ),
    .cr_advn    (               ),
    .cr_cre     (               ),
    .cr_cen     (               ), // chip enable
    .cr_oen     (               ),
    .cr_wen     (               ),
    .cr_dsn     (               )
);

jtframe_test_clocks #(.MAXFRAMES(4)) clocks(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .lhbl       ( lhbl      ),
    .vs         ( vs        ),
    .v          ( ln_v      ),
    .lvbl       (           )
);

endmodule