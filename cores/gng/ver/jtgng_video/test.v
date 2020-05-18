module test(
    input           rst,
    input           SDRAM_CLK,
    input           clk,        // 24   MHz
    input           cen6,       //  6   MHz
    input           flip,
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL,
    output          LVBL,
    output          rom_ready
);

wire [8:0] V;
wire [8:0] H;
wire HINIT;

jtgng_timer timers(
    .clk       ( clk      ),
    .clk_en    ( cen6     ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( LHBL     ),
    .LVBL      ( LVBL     )
);

wire char_mrdy;
wire [12:0] char_addr;
wire [ 7:0] chram_dout,scram_dout;
wire [15:0] chrom_data;
wire [ 8:0] obj_AB;
wire bus_req, blen;
wire [14:0] obj_addr;
wire [15:0] obj_data;
wire [23:0] scr_dout;
wire [14:0] scr_addr;

jtgng_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cpu_AB     ( 11'd0         ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( 1'b0          ),
    .flip       ( flip          ),
    .cpu_dout   ( 8'd0          ),
    // CHAR
    .char_cs    ( 1'b0          ),
    .chram_dout ( chram_dout    ),
    .char_mrdy  ( char_mrdy     ),
    .char_addr  ( char_addr     ),
    .chrom_data ( chrom_data    ),
    // SCROLL - ROM
    .scr_cs     ( 1'b0          ),
    .scrpos_cs  ( 1'b0          ),
    .scram_dout ( scram_dout    ),
    .scr_addr   ( scr_addr      ),
    .scrom_data ( scr_dout      ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .main_ram   ( 8'd0          ),
    .OKOUT      ( 1'b0          ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( 1'b0          ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .blue_cs    ( 1'b0          ),
    .redgreen_cs( 1'b0          ),
    .enable_char( 1'b1          ),
    .enable_obj ( 1'b0          ),
    .enable_scr ( 1'b0          ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

// SDRAM interface
wire [15:0] SDRAM_DQ;       // SDRAM Data bus 16 Bits
wire [12:0] SDRAM_A;        // SDRAM Address bus 13 Bits
wire        SDRAM_DQML;     // SDRAM Low-byte Data Mask
wire        SDRAM_DQMH;     // SDRAM High-byte Data Mask
wire        SDRAM_nWE;      // SDRAM Write Enable
wire        SDRAM_nCAS;     // SDRAM Column Address Strobe
wire        SDRAM_nRAS;     // SDRAM Row Address Strobe
wire        SDRAM_nCS;      // SDRAM Chip Select
wire  [1:0] SDRAM_BA;       // SDRAM Bank Address
wire        SDRAM_CKE;      // SDRAM Clock Enable


wire [1:0] Dqm = { SDRAM_DQMH, SDRAM_DQML };
/*
mt48lc16m16a2 SDRAM(
    .Dq     ( SDRAM_DQ   ),
    .Addr   ( SDRAM_A    ),
    .Ba     ( SDRAM_BA   ),
    .Clk    ( clk        ),
    .Cke    ( SDRAM_CKE  ),
    .Cs_n   ( SDRAM_nCS  ),
    .Ras_n  ( SDRAM_nRAS ),
    .Cas_n  ( SDRAM_nCAS ),
    .We_n   ( SDRAM_nWE  ),
    .Dqm    ( Dqm        )
);
*/

// Quick model for SDRAM
reg  [15:0] sdram_mem[0:2**18-1];
reg  [12:0] sdram_row;
//reg  [10:0] sdram_col;
reg  [15:0] sdram_data;
reg  [17:0] sdram_compound;
assign SDRAM_DQ = sdram_data;
initial $readmemh("../../../rom/gng.hex",  sdram_mem, 0, 180223);
always @(posedge SDRAM_CLK) begin
    if( !SDRAM_nCS && !SDRAM_nRAS &&  SDRAM_nCAS && SDRAM_nWE && SDRAM_CKE ) sdram_row <= SDRAM_A;
    if( !SDRAM_nCS &&  SDRAM_nRAS && !SDRAM_nCAS && SDRAM_nWE && SDRAM_CKE ) sdram_compound <= {sdram_row[8:0], SDRAM_A[8:0]};
    sdram_data <= sdram_mem[ sdram_compound ];
end


jtgng_rom rom (
    .clk        ( SDRAM_CLK     ), // 96MHz = 32 * 6 MHz -> CL=2
    .rst        ( rst           ),
    .char_addr  ( char_addr     ),
    .main_addr  ( 17'd0         ),
    .snd_addr   ( 15'd0         ),
    .obj_addr   ( obj_addr      ),
    .scr_addr   ( scr_addr      ),

    .char_dout  ( chrom_data    ),
    .main_dout  (               ),
    .snd_dout   (               ),
    .obj_dout   ( obj_data      ),
    .scr_dout   ( scr_dout      ),
    .ready      ( rom_ready     ),
    // SDRAM interface
    .SDRAM_DQ   ( SDRAM_DQ      ),
    .SDRAM_A    ( SDRAM_A       ),
    .SDRAM_DQML ( SDRAM_DQML    ),
    .SDRAM_DQMH ( SDRAM_DQMH    ),
    .SDRAM_nWE  ( SDRAM_nWE     ),
    .SDRAM_nCAS ( SDRAM_nCAS    ),
    .SDRAM_nRAS ( SDRAM_nRAS    ),
    .SDRAM_nCS  ( SDRAM_nCS     ),
    .SDRAM_BA   ( SDRAM_BA      ),
    .SDRAM_CKE  ( SDRAM_CKE     ),
    // ROM load
    .downloading ( 1'b0         ),
    .romload_addr( 25'd0        ),
    .romload_data( 16'd0        ),
    .romload_wr  ( 1'b0         )
);

endmodule // test
