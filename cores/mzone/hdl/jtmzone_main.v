/* SPDX-FileCopyrightText: 2026 Ulf Skutnabba
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-10-2026 */

module jtmzone_main(
    input              rst,
    input              clk,
    input              cpu_clk_cen,

    output     [15:0]  main_addr,
    output reg         main_cs,
    input      [ 7:0]  main_data,
    input              main_ok,

    output             cpu_rnw,

    output reg         vram0_cs,
    output reg         vram1_cs,
    output reg         cram0_cs,
    output reg         cram1_cs,

    output     [10:0]  shared_addr,
    output     [ 7:0]  shared_dout,
    output             shared_we,
    input      [ 7:0]  shared_din,

    output     [ 9:0]  vram_addr,
    output     [ 7:0]  vram_din,
    input      [ 7:0]  vram0_dout,
    input      [ 7:0]  vram1_dout,
    input      [ 7:0]  cram0_dout,
    input      [ 7:0]  cram1_dout,

    output     [ 9:0]  objram_addr,
    output     [ 7:0]  objram_din,
    output reg         objram_cs,
    input      [ 7:0]  objram_dout,

    output             video_reg_cs,
    output     [ 1:0]  video_reg_addr,
    output reg         intsnd,

    input              LVBL,
    input              dip_pause,
    input              intmain_n
);

`ifndef NOMAIN

reg  [ 7:0]  cpu_din;
reg          intst;
reg          main_latch_cs, scrolly_cs, scrollx_cs;
wire [15:0]  A;
wire         RnW, VMA;
wire         cpu_cen;
wire [ 7:0]  cpu_dout;
reg          shared_cs;
wire         irq_n;
wire         firq_n;
wire         BS;
wire         irq_trigger = ~LVBL & dip_pause;
wire         scroll_cs     = scrolly_cs | scrollx_cs;

assign main_addr = A;
assign cpu_rnw  = RnW;
assign shared_addr = A[10:0];
assign shared_dout = cpu_dout;
assign shared_we   = shared_cs && !RnW;
assign vram_addr = A[9:0];
assign vram_din  = cpu_dout;
assign objram_addr = A[9:0];
assign objram_din  = cpu_dout;

// Compact register addresses match cfg/mmr.yaml and the scene dump tail.
assign video_reg_cs = cpu_cen && !RnW &&
                        (scroll_cs || (main_latch_cs && A[2:0]==3'd5));
assign video_reg_addr = scrolly_cs ? 2'd0 : scrollx_cs ? 2'd1 : 2'd2;

always @(*) begin
    main_cs        = VMA && RnW && A[15:14] != 0; // ROM = 4000-FFFF
    main_latch_cs = 0;
    scrolly_cs    = 0;
    scrollx_cs    = 0;
    vram0_cs      = 0;
    vram1_cs      = 0;
    cram0_cs      = 0;
    cram1_cs      = 0;
    objram_cs     = 0;
    shared_cs     = 0;

    // B_B7 decodes A15..A11 into 2 KB blocks. B_A13 is the
    // addressable latch at 0000-0007 inside the first block.
    if( VMA ) begin
        case( A[15:11] )
            5'h00: if( A[10:3] == 0 ) main_latch_cs = 1;
            5'h02: scrolly_cs = 1;
            5'h03: scrollx_cs = 1;
            5'h04: if( !A[10] ) vram0_cs = 1;
                    else         vram1_cs = 1;
            5'h05: if( !A[10] ) cram0_cs = 1;
                    else         cram1_cs = 1;
            5'h06: objram_cs = 1;
            5'h07: shared_cs = 1;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    cpu_din <= main_cs    ? main_data   :
                vram0_cs  ? vram0_dout :
                vram1_cs  ? vram1_dout :
                cram0_cs  ? cram0_dout :
                cram1_cs  ? cram1_dout :
                objram_cs ? objram_dout :
                shared_cs ? shared_din : 8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        intsnd        <= 1'b0;
        intst         <= 1'b0;
    end else if( cpu_cen ) begin
        if( main_latch_cs && !RnW ) begin
            // B_A13 is a 74LS259 addressable latch. Only the schematic nets
            // currently used by the core are modeled here.
            case( A[2:0] )
                // 0: coin 2 counter
                // 1: coin 1 counter
                3'd3: intsnd <= cpu_dout[0];
                3'd7: intst  <= cpu_dout[0];
                default: ;
            endcase
        end
    end
end

// B_C12A on the schematic: ~IRQ is clocked by BLANK and released by INTST.
jtframe_ff u_nirq(
    .rst             ( rst                                  ),
    .clk             ( clk                                  ),
    .cen             ( 1'b1                                 ),
    .din             ( 1'b0                                 ),
    .q               ( irq_n                                ),
    .qn              (                                      ),
    .set             ( ~intst                               ),
    .clr             ( 1'b0                                 ),
    .sigedge         ( irq_trigger                          )
);

// B_C1B on the schematic: D is grounded, Q drives ~FIRQ and the active-low
// preset is driven by ~MBS. BS is the corresponding active-high event.
jtframe_ff u_nfirq(
    .rst             ( rst                                  ),
    .clk             ( clk                                  ),
    .cen             ( 1'b1                                 ),
    .din             ( 1'b0                                 ),
    .q               ( firq_n                               ),
    .qn              (                                      ),
    .set             ( BS                                   ),
    .clr             ( 1'b0                                 ),
    .sigedge         ( intmain_n                            )
);

jtframe_sys6809 #(
    .RAM_AW          ( 0                                    ),
    .KONAMI          ( 1                                    ),
    .RECOVERY        ( 1                                    ),
    .CENDIV          ( 1                                    )
) u_cpu(
    .rstn            ( ~rst                                 ),
    .clk             ( clk                                  ),
    .cen             ( cpu_clk_cen                          ),
    .cpu_cen         ( cpu_cen                              ),

    .nIRQ            ( irq_n                                ),
    .nFIRQ           ( firq_n                               ),
    .nNMI            ( 1'b1                                 ),
    .irq_ack         (                                      ),
    .BA              (                                      ),
    .BS              ( BS                                   ),
    .bus_busy        ( 1'b0                                 ),

    .A               ( A                                    ),
    .RnW             ( RnW                                  ),
    .VMA             ( VMA                                  ),
    .ram_cs          ( 1'b0                                 ),
    .rom_cs          ( main_cs                              ),
    .rom_ok          ( main_ok                              ),
    .ram_dout        (                                      ),
    .cpu_dout        ( cpu_dout                             ),
    .cpu_din         ( cpu_din                              )
);

`else
assign main_addr       = 16'd0;
assign main_cs         = 1'b0;
assign cpu_rnw         = 1'b1;
assign vram0_cs        = 1'b0;
assign vram1_cs        = 1'b0;
assign cram0_cs        = 1'b0;
assign cram1_cs        = 1'b0;
assign shared_addr     = 11'd0;
assign shared_dout     = 8'd0;
assign shared_we       = 1'b0;
assign vram_addr       = 10'd0;
assign vram_din        = 8'd0;
assign objram_addr     = 10'd0;
assign objram_din      = 8'd0;
assign objram_cs       = 1'b0;
assign video_reg_cs    = 1'b0;
assign video_reg_addr  = 2'd0;
assign intsnd          = 1'b0;
`endif

endmodule
