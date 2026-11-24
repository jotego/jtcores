`timescale 1ns/1ps

module test;

reg clk = 0;
reg rst = 1;
reg cen6 = 1;
reg shift_a1 = 0, shift_a2 = 0, shift_b = 0, edge_2hd = 0, edge_4hd = 0;
reg line_n = 0;
reg hflip = 0;
reg [3:0] tile_priority = 0;
reg [6:0] vram2_data = 7'h35;
reg [3:0] a_pixel = 4'ha, b_pixel = 4'hb;
reg a_opaque = 0, b_opaque = 0;
reg [3:0] object_pixel = 0;
reg [3:0] gfx_en = 4'b1111;
wire [10:0] ref_index, dut_index;
wire [1:0] ref_source, dut_source;
wire ref_a_hflip, ref_b_hflip, dut_a_hflip, dut_b_hflip;
wire [7:0] red, green, blue;
reg [7:0] mode_seen [0:25];
integer pr, opa, obj, mask, mode;
integer total;
reg [3:0] a_pr, b_pr;
reg [10:0] safe_index;
reg [1:0] source;
reg visible;
reg [4:0] r5, g5, b5;

wire [3:0] gated_obj = gfx_en[3] ? object_pixel : 4'd0;
wire gated_a_opaque = a_opaque & gfx_en[1];
wire gated_b_opaque = b_opaque & gfx_en[2];

jtnemsis_k5293 uut(
    .rst            ( rst            ),
    .clk            ( clk            ),
    .pxl_cen           ( cen6           ),
    .shift_a1_clkd  ( shift_a1       ),
    .shift_a2_clkd  ( shift_a2       ),
    .shift_b_clkd   ( shift_b        ),
    .h2_clkd       ( edge_2hd       ),
    .h4_clkd       ( edge_4hd       ),
    .tm_a_hflip     ( dut_a_hflip    ),
    .tm_b_hflip     ( dut_b_hflip    ),
    .tm_a_px_data   ( a_pixel        ),
    .tm_a_px_trans  ( gated_a_opaque ),
    .tm_b_px_data   ( b_pixel        ),
    .tm_b_px_trans  ( gated_b_opaque ),
    .hflip          ( hflip          ),
    .tile_priority  ( tile_priority  ),
    .vhff           ( 1'b0           ),
    .vram2_data     ( vram2_data     ),
    .obj_px_data    ( { 8'd0, 4'd0, gated_obj } ),
    .color_ram_addr ( dut_index      ),
    .color_source   ( dut_source     ),
    .h1_n           ( line_n         )
);

jtnemsis_k5293 uut_reference(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .pxl_cen           ( cen6          ),
    .shift_a1_clkd  ( shift_a1      ),
    .shift_a2_clkd  ( shift_a2      ),
    .shift_b_clkd   ( shift_b       ),
    .h2_clkd       ( edge_2hd      ),
    .h4_clkd       ( edge_4hd      ),
    .tm_a_hflip     ( ref_a_hflip   ),
    .tm_b_hflip     ( ref_b_hflip   ),
    .tm_a_px_data   ( a_pixel       ),
    .tm_a_px_trans  ( a_opaque      ),
    .tm_b_px_data   ( b_pixel       ),
    .tm_b_px_trans  ( b_opaque      ),
    .hflip          ( hflip         ),
    .tile_priority  ( tile_priority ),
    .vhff           ( 1'b0          ),
    .vram2_data     ( vram2_data    ),
    .obj_px_data    ( { 8'd0, 4'd0, object_pixel } ),
    .color_ram_addr ( ref_index     ),
    .color_source   ( ref_source    ),
    .h1_n           ( line_n        )
);

// Distinct nonzero palette output makes an enabled-source leak observable.
jtnemsis_colmix u_colmix(
	.rst   ( rst       ),
    .clk   ( clk       ),
    .pxl_cen ( cen6    ),
    .gfx_en( gfx_en    ),
    .source( source    ),
    .red5  ( r5        ),
    .green5( g5        ),
    .blue5 ( b5        ),
    .preLHBL( 1'b1     ),
    .preLVBL( 1'b1     ),
    .LHBL  (           ),
    .LVBL  (           ),
    .red   ( red       ),
    .green ( green     ),
    .blue  ( blue      )
);

task tick;
begin
    #2 clk = 1;
    #1;
    #1 clk = 0;
    #1;
end
endtask

task pulse_2hd;
begin edge_2hd=1; tick; edge_2hd=0; tick; end
endtask

task pulse_4hd;
begin edge_4hd=1; tick; edge_4hd=0; tick; end
endtask

task pulse_shift_a1;
begin shift_a1=1; tick; shift_a1=0; tick; end
endtask

task pulse_shift_a2;
begin shift_a2=1; tick; shift_a2=0; tick; end
endtask

task pulse_shift_b;
begin shift_b=1; tick; shift_b=0; tick; end
endtask

task pulse_line;
begin line_n=1; tick; line_n=0; tick; end
endtask

task check;
    input condition;
    input [8*96-1:0] message;
begin
    if (condition !== 1'b1) begin
        $display("FAIL: %0s pr=%02x opa=%x obj=%x mask=%x source=%x idx=%x", message, pr, opa, obj, mask, dut_source, dut_index);
        $fatal(1);
    end
end
endtask

task load_priority;
    input [3:0] ap;
    input [1:0] bp;
begin
    // Capture B through its 2HD, 4HD, and shift stages.
    tile_priority = {2'b00, bp};
    pulse_2hd();
    pulse_4hd();
    pulse_shift_b();

    // Capture A through its 4HD, 2HD, and two shift stages. B's 4HD and
    // shift stages also advance using the already captured B priority.
    tile_priority = ap;
    pulse_4hd();
    pulse_2hd();
    pulse_shift_a1();
    pulse_shift_a2();
end
endtask

initial begin
    total = 0;
    r5 = 5'h1f;
    g5 = 5'h1f;
    b5 = 5'h1f;
    for (mode=0; mode<26; mode=mode+1) mode_seen[mode]=0;
    tick();
    rst=0;

    for (pr=0; pr<64; pr=pr+1) begin
        a_pr = pr[3:0];
        b_pr = pr[5:4];
        load_priority(a_pr, b_pr);
        check(uut.tm_a_shift_a2_latched[10:7] == a_pr, "A priority captured through real K5293 delay line");
        check(uut.tm_b_shift_b_latched[9:8] == b_pr, "B priority captured through real K5293 delay line");
        mode_seen[uut.priority_handler.tm_mode] = 1;

        for (opa=0; opa<4; opa=opa+1) begin
            for (obj=0; obj<16; obj=obj+1) begin
                for (mask=0; mask<8; mask=mask+1) begin
                    gfx_en = {1'b0, mask[2], mask[1], mask[0]};
                    a_opaque = opa[1] ^ mask[0];
                    b_opaque = opa[0] ^ mask[1];
                    a_pixel = (pr + opa + mask) & 4'hf;
                    b_pixel = (pr ^ opa ^ mask) & 4'hf;
                    object_pixel = (obj + mask + opa) & 4'hf;
                    pulse_line();
                    #1;
                    tick();
                    source = dut_source;
                    safe_index = ( (dut_source == 2'd1 && !gfx_en[1]) ||
                                   (dut_source == 2'd2 && !gfx_en[2]) ||
                                   (dut_source == 2'd0 && !gfx_en[3]) ) ? 11'd0 : dut_index;
                    r5 = 5'h1f;
                    g5 = 5'h1f;
                    b5 = 5'h1f;
                    tick();
                    #1;

                    if (mask == 7) begin
                        check(dut_index == ref_index && dut_source == ref_source,
                              "all-enabled path matches unmasked K5293 reference");
                    end
                    if (dut_source == 2'd1)
                        check(dut_index[3:0] == a_pixel &&
                              dut_index[10:4] == uut.tm_a_shift_a2_latched[6:0],
                              "A source tag remains aligned with the current A pixel and bank");
                    else if (dut_source == 2'd2)
                        check(dut_index[3:0] == b_pixel &&
                              dut_index[10:4] == uut.tm_b_shift_b_latched[6:0],
                              "B source tag remains aligned with the current B pixel and bank");
                    else
                        check(dut_index == { 7'd0, 4'd0, gated_obj },
                              "object source tag remains aligned with current object pixel");
                    visible = (dut_source == 2'd1) ? gfx_en[1] :
                              (dut_source == 2'd2) ? gfx_en[2] : gfx_en[3];
                    if (!visible)
                        check({red,green,blue} == 24'd0 && safe_index == 0,
                              "disabled forced winner is black and palette-safe");
                    else
                        check(({red,green,blue} != 24'd0), "enabled selected source remains visible");
                    total = total + 1;
                end
            end
        end
    end

    for (mode=0; mode<26; mode=mode+1)
        check(mode_seen[mode], "all measured K5293 priority modes exercised");

    $display("PASS: integrated K5293 layer masks, %0d states", total);
    $finish;
end

endmodule
