/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2023.

Support the authors:

       Raki: https://www.patreon.com/ikamusume
    LMN-san: https://ko-fi.com/lmnsan
  OScherler: https://ko-fi.com/oscherler

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

*/

//================================================================================
//  Nemesis Main Module (68000 CPU board minus audio)
//================================================================================

`default_nettype none

module nemesis_main
(
	input         i_clk,          // 48 MHz
	input         i_rst,          // reset signal

	// [LS244] @ 18E (schematic bottom left)
	input         i_cen9,         // A45: clock enable 9 MHz
	input         i_vblank,       // A37
	input         i_256v,         // A33
	input         i_blk,          // A35
	input         i_cen6,         // A41 clock enable
	input         i_clk6,         // A41 clock
	input         i_1h_n,         // A43
	input         i_2h,           // A49

	// [LS244] @ 18G (schematic top centre)
	input         i_vsinc,        // B16
	input         i_sync,         // B33 -> (B14)
	// output     o_res_n,        // A47 (already an input on all boards)
	output        o_chacs_n,      // B49
	output        o_rw_n,         // B47
	output        o_uds_n,        // B45
	output        o_lds_n,        // B43

	// [LS244] @ 18J (schematic top right)
	output        o_inter_non,    // B32
	output        o_288_256,      // B31
	output        o_vflip,        // B29
	output        o_hflip,        // B30
	output        o_objram_n,     // B35
	output        o_vcs2,         // B39
	output        o_vcs1,         // B41
	output        o_vzcs,         // B37

	// ROM access
	output [16:0] o_rom_addr,
	output        o_rom_cs,
	input  [15:0] i_rom_data,
	input         i_rom_ok,

	// Sound CMD
	// [LS244] @ 12F (schematic top right)
	output        o_sound_on_n,   // 
	// [LS138] @ 13G (schematic top right)
	output        o_data_n,       // 
	// data bus
	output [ 7:0] o_sound_db,     // 

	// Video
	// LS244 @ 17L, 18L (schematic top middle)
	output [15:1] o_addr,         // B1-15
	// [LS157] @ 16K, 17K, 18K
	input  [10:0] i_cd,           // B17-27
	// [LS245] @ 18A, 18C (schematic centre middle)
	input  [15:0] i_data_bus_in,  // A1-31 (odd, 16 bits)
	output [15:0] o_data_bus_out, // A1-31 (odd, 16 bits)
	// RGB [LS09] @ 4K, 4L, 5K, 5L (schematic bottom right)
	output reg [ 4:0] o_red,      // A14
	output reg [ 4:0] o_green,    // A13
	output reg [ 4:0] o_blue,     // B13

	// DIP switches @ 5E, 5F, 5G
	input  [ 7:0] i_dip1,         // (8 bits)
	input  [ 7:0] i_dip2,         // (8 bits)
	input  [ 7:0] i_dip3,         // (8 bits)

	input         i_pause,        // Pause, active low

	// [PS2401-4] @ 2E, 2F, 2G, 2H, 2J
	// A: solder side, B: parts side, cf. manual, page 4
	input         i_coin1,        // A10
	input         i_1p_left,      // B8
	input         i_2p_left,      // A4

	input         i_coin2,        // B10
	input         i_1p_right,     // A8
	input         i_2p_right,     // B4

	input         i_service,      // B7
	input         i_1p_up,        // A9
	input         i_2p_up,        // B6

	input         i_1p_start,     // A5
	input         i_1p_down,      // A11
	input         i_2p_down,      // B9

	input         i_2p_start,     // B5
	input         i_1p_sp_pow,    // A7
	input         i_2p_sp_pow,    // A3

	input         i_1p_missile,   // A6
	input         i_2p_missile,   // B3

	input         i_1p_shoot,     // A12
	input         i_2p_shoot      // B15
);

///////////////////
// Signals
///////////////////

// clock enables
reg         cen9, cen9b;

// address and data buses
wire        as_n, lds_n, uds_n, RnW, vpa_n, int16_n, int32_n, u16f_d1, u16f_d2;
reg         DTACKn;
reg  [ 2:0] ipl_n;
wire [23:1] cpu_addr;
wire [15:0] cpu_dout, rom_dout, color;
reg  [15:0] cpu_din;
wire [ 7:0] ram_hi_dout, ram_lo_dout, color_ram_lo_dout, color_ram_hi_dout;
reg  [ 7:0] u11k_out, u13j_out, input_mux_out;

// chip selects
wire        prom_cs_n, ram_cs_n, chara, excs_n, pre_ram_cs_n,
            vzure, vramcs1, vramcs2, objram, color_ram, u11k_g_n, u13j_g_n, data_n,
            afe_n, input_mux_g_n, dip1_g_n, dip2_g_n;
reg         reg_ram_cs;

`ifndef NOMAIN

///////////////////
// Inputs / Outputs
///////////////////

// chip select outputs to video
assign o_chacs_n  = chara;
assign o_vzcs     = vzure;
assign o_vcs1     = vramcs1;
assign o_vcs2     = vramcs2;
assign o_objram_n = objram;

// settings outputs to video
assign o_hflip      = u11k_out[2];
assign o_vflip      = u11k_out[3];
assign o_288_256    = u11k_out[4];
assign o_inter_non  = u11k_out[5];

// address and data to video
assign o_rw_n         = RnW;
assign o_uds_n        = uds_n;
assign o_lds_n        = lds_n;
assign o_addr         = cpu_addr[15:1];
assign o_data_bus_out = cpu_dout;

// data output to sound
assign o_sound_db   = cpu_dout[7:0];
assign o_data_n     = data_n;
assign o_sound_on_n = u13j_out[2];

///////////////////
// Input MUX
///////////////////

wire [1:0]  input_mux_sel;
wire [7:0]  input_mux_a, input_mux_b, input_mux_c, input_mux_d;

// MiSTer joystick input is active low, like the Nemesis buttons that are grounded with a pull-up.
// But there are optocouplers on the PCB that invert the signal, so we have to invert here too.
//
// ** 5 x Quad Optocoupler            **
// ** [PS2401-4] @ 2E, 2F, 2G, 2H, 2J **
// ** 8-Bit DIP Switch                **
// ** [DIP] @ 5G                      **
assign input_mux_a = { 3'b0, ~i_2p_start, ~i_1p_start, ~i_service, ~i_coin2, ~i_coin1 };
assign input_mux_b = { 1'b0, ~i_1p_shoot, ~i_1p_missile, ~i_1p_sp_pow, ~i_1p_down, ~i_1p_up, ~i_1p_right, ~i_1p_left };
assign input_mux_c = { 1'b0, ~i_2p_shoot, ~i_2p_missile, ~i_2p_sp_pow, ~i_2p_down, ~i_2p_up, ~i_2p_right, ~i_2p_left };
assign input_mux_d = i_dip3;

assign input_mux_sel = cpu_addr[2:1];

// ** 4 x Dual 4-to-1 Line Multiplexer **
// ** [LS253] @ 3E, 3F, 3G, 3J         **
always @(*) begin
	case( input_mux_sel )
		2'b00: input_mux_out <= input_mux_a;
		2'b01: input_mux_out <= input_mux_b;
		2'b10: input_mux_out <= input_mux_c;
		2'b11: input_mux_out <= input_mux_d;
	endcase
end

///////////////////
// Address Decoding
///////////////////

// ** 3 x 3-to-8 Line Decoder **
// ** [LS138] @ 14J, 6J, 13G  **
// ** Tri 3-Input NOR Gate    **
// ** [LS27]  @ 16G           **
// ** Quad 2-Input NAND Gate  **
// ** [LS00]  @ 17J           **
// ** Hex Inverter            **
// ** [LS04]  @ 12G           **
// ** Quad 2-Input OR Gate    **
// ** [LS32]  @ 11E, 4J       **
nemesis_68k_addr_dec u_addr_dec(
	.i_as_n           ( as_n           ),
	.i_lds_n          ( lds_n          ),
	.i_uds_n          ( uds_n          ),
	.i_cpu_addr       ( cpu_addr       ),

	.o_prom_cs_n      ( prom_cs_n      ),
	.o_chara          ( chara          ),
	.o_excs_n         ( excs_n         ),
	.o_ram_cs_n       ( pre_ram_cs_n   ),
	.o_vzure          ( vzure          ),
	.o_vramcs1        ( vramcs1        ),
	.o_vramcs2        ( vramcs2        ),
	.o_objram         ( objram         ),
	.o_color_ram      ( color_ram      ),
	.o_u11k_g_n       ( u11k_g_n       ),
	.o_u13j_g_n       ( u13j_g_n       ),
	.o_data_n         ( data_n         ),
	.o_afe_n          ( afe_n          ),
	.o_input_mux_g_n  ( input_mux_g_n  ),
	.o_dip1_g_n       ( dip1_g_n       ),
	.o_dip2_g_n       ( dip2_g_n       )
);

///////////////////
// SDRAM Fix
///////////////////

// TODO: see if needed

`ifdef SDRAM_FIX

// ram_cs and vram_cs signals go down before DSWn signals
// that causes a false read request to the SDRAM. In order
// to avoid that a little bit of logic is needed:
wire   UDSWn, LDSWn;
reg    dsn_dly;

// high during DMA transfer
assign UDSWn = RnW | uds_n;
assign LDSWn = RnW | lds_n;

assign ram_cs_n = dsn_dly ? reg_ram_cs  : pre_ram_cs_n;

always @(posedge i_clk) if( cen9 ) begin
	reg_ram_cs <= pre_ram_cs_n;
	dsn_dly    <= &{ UDSWn, LDSWn }; // low if any DSWn was low
end

`else

assign ram_cs_n = pre_ram_cs_n;

`endif

///////////////////
// CPU Clock Enables
///////////////////

// generate enPhi1 and enPhi2 for fx68k by advancing and delaying 9 MHz clock by 1 48 MHz clock
always @(posedge i_clk ) begin
	reg cen9x;

	cen9  <= i_cen9;
	cen9x <= cen9;
	cen9b <= cen9x;
end

///////////////////
// CPU Data Bus Input
///////////////////

// Use = in always @(*) (like in jt_gng/sf).

// ** Triple 3-Input NAND Gate **
// ** [LS10] @ 16J             **
// ** Hex Inverter             **
// ** [LS04] @ 17G             **
// ** Dual 4-Input AND Gate    **
// ** [LS21] @ 12E             **
wire video_cs_n = &{ objram, vzure, vramcs1, vramcs2, chara };

always @(*) begin
	case( 1'b0 )
		prom_cs_n:      cpu_din = rom_dout;
		ram_cs_n:       cpu_din = { ram_hi_dout, ram_lo_dout };
		color_ram:      cpu_din = { color_ram_hi_dout, color_ram_lo_dout };
		dip1_g_n:       cpu_din = { 8'h00, i_dip1 };
		dip2_g_n:       cpu_din = { 8'h00, i_dip2 };
		input_mux_g_n:  cpu_din = { 8'h00, input_mux_out };
		u11k_g_n:       cpu_din = { 8'h00, u11k_out };
		u13j_g_n:       cpu_din = { 8'h00, u13j_out };
		video_cs_n:     cpu_din = i_data_bus_in;
		default:        cpu_din = 16'hffff;
	endcase
end

///////////////////
// Addressable Latches
///////////////////

// ** 8-Bit Addressable Latch **
// ** [LS259] @ 11K           **
always @( posedge i_clk ) begin
	if( i_rst )
		u11k_out <= 8'd0;
	else if( ! u11k_g_n )
		u11k_out[ cpu_addr[3:1] ] <= cpu_dout[0];
end

// ** 8-Bit Addressable Latch **
// ** [LS259] @ 13J           **
always @( posedge i_clk ) begin
	if( i_rst )
		u13j_out <= 8'd0;
	else if( ! u13j_g_n )
		u13j_out[ cpu_addr[3:1] ] <= cpu_dout[8];
end

///////////////////
// DTACKn Generation
///////////////////

wire DTACKn_other, DTACKn_vzure_objram, DTACKn_vram_chara;
wire idt, vzure_objram_cs_n, vram_chara_cs_n, LUDSn, clk6_1h_2h;

// from debug connector?
//
// ** Octal Buffer **
// ** [LS244] @ 7K **
assign idt = 1'b1;

// ** Triple 3-Input NAND Gate **
// ** [LS10] @ 16J             **
// ** Hex Inverter             **
// ** [LS04] @ 17G             **
// ** Quad 2-Input AND Gate    **
// ** [LS08] @ 11F             **
assign vzure_objram_cs_n = &{ vzure, objram };
assign vram_chara_cs_n = &{ idt, vramcs1, vramcs2, chara };
assign LUDSn = &{ lds_n, uds_n };

// ** Dual D Flip-Flop  **
// ** [LS74] @ 17E, top **
jtframe_ff u_17e_top(
	.rst     ( i_rst        ),
	.clk     ( i_clk        ),
	.cen     ( 1'b1         ),
	.sigedge ( i_clk6       ),
	.set     ( LUDSn        ),
	.clr     ( 1'b0         ),
	.din     ( LUDSn        ),
	.q       ( DTACKn_other ),
	.qn      (              )
);

// ** Dual D Flip-Flop     **
// ** [LS74] @ 17E, bottom **
jtframe_ff u_17e_bottom(
	.rst     ( i_rst               ),
	.clk     ( i_clk               ),
	.cen     ( 1'b1                ),
	.sigedge ( i_1h_n              ),
	.set     ( LUDSn               ),
	.clr     ( 1'b0                ),
	.din     ( LUDSn               ),
	.q       ( DTACKn_vzure_objram ),
	.qn      (                     )
);

// ** Hex Inverter         **
// ** [LS04] @ 17G         **
// ** Tri 3-Input NOR Gate **
// ** [LS27]  @ 16G        **
assign clk6_1h_2h = ~|{ i_clk6, ~i_1h_n, i_2h };

// ** Dual D Flip-Flop **
// ** [LS74] @ 18F     **
jtframe_ff u_18f(
	.rst     ( i_rst             ),
	.clk     ( i_clk             ),
	.cen     ( 1'b1              ),
	.sigedge ( clk6_1h_2h        ),
	.set     ( LUDSn             ),
	.clr     ( 1'b0              ),
	.din     ( DTACKn_other      ),
	.q       ( DTACKn_vram_chara ),
	.qn      (                   )
);

// Schematic feeds prom_cs_n to both A and B selector inputs of mux
// so that it selects input D. In Verilog we can do it more explicitely
// by testing 3 signals and having a default case.
// 
// ** Dual 4-Line to 1-Line Data Selector/Multiplexer **
// ** [LS153] @ 16E                                   **
always @(*) begin
	case( { prom_cs_n, vzure_objram_cs_n, vram_chara_cs_n } )
		3'b011:  DTACKn <= ( LUDSn | ~i_rom_ok ); // PROM (add ROM OK signal to wait for SDRAM ready)
		3'b101:  DTACKn <= DTACKn_vzure_objram;   // VZURE or OBJRAM
		3'b110:  DTACKn <= DTACKn_vram_chara;     // VRAMCS1-2, CHARA
		default: DTACKn <= DTACKn_other;
	endcase
end

///////////////////
// Interrupt handling
///////////////////

assign int16_n = u11k_out[0];
assign int32_n = u11k_out[1];

// ** Hex D Flip-Flop    **
// ** [LS174] @ 17F, top **
jtframe_ff u_17f_top(
	.rst     ( i_rst    ),
	.clk     ( i_clk    ),
	.cen     ( 1'b1     ),
	.sigedge ( i_vblank ),
	.set     ( ~int16_n ),
	.clr     ( 1'b0     ),
	.din     ( 1'b0     ),
	.q       ( u16f_d2  ),
	.qn      (          )
);

// ** Hex D Flip-Flop       **
// ** [LS174] @ 17F, bottom **
jtframe_ff u_17f_bottom(
	.rst     ( i_rst    ),
	.clk     ( i_clk    ),
	.cen     ( 1'b1     ),
	.sigedge ( i_256v   ),
	.set     ( ~int32_n ),
	.clr     ( 1'b0     ),
	.din     ( 1'b0     ),
	.q       ( u16f_d1  ),
	.qn      (          )
);

// ** 10–Line to 4-Line Priority Encoder **
// ** [LS147] @ 16F                      **
always @(*) begin
	if( ~u16f_d2 & i_pause )
		ipl_n <= 3'b101;
	else if( ~u16f_d1 & i_pause )
		ipl_n <= 3'b110;
	else
		ipl_n <= 3'b111;
end

///////////////////
// CPU
///////////////////

// ** Hex Inverter         **
// ** [LS04] @ 17G         **
// ** Quad 2-Input OR Gate **
// ** [LS32]  @ 15J        **
assign vpa_n = |{ ~cpu_addr[23], as_n };

// ** 16-Bit Microprocessor **
// ** [68000] @ 14E         **
fx68k u_cpu(
	.clk        ( i_clk       ), // input - 48 MHz
	.extReset   ( i_rst       ), // input - active high (real 68k reset is active low)
	.pwrUp      ( i_rst       ), // input
	.enPhi1     ( cen9        ), // input
	.enPhi2     ( cen9b       ), // input
	.HALTn      ( ~i_rst      ), // input

	// Buses
	.eab        ( cpu_addr    ), // output
	.iEdb       ( cpu_din     ), // input
	.oEdb       ( cpu_dout    ), // output

	.eRWn       ( RnW         ), // output
	.LDSn       ( lds_n       ), // output
	.UDSn       ( uds_n       ), // output
	.ASn        ( as_n        ), // output
	.VPAn       ( vpa_n       ), // input

	.BERRn      ( 1'b1        ), // input

	// Bus arbitration
	.BRn        ( 1'b1        ), // input
	.BGACKn     ( 1'b1        ), // input

	.DTACKn     ( DTACKn      ), // input
	.IPL0n      ( ipl_n[0]    ), // input
	.IPL1n      ( ipl_n[1]    ), // input
	.IPL2n      ( ipl_n[2]    ), // input

	// Unused
	.BGn        (             ), // output
	.FC0        (             ), // output
	.FC1        (             ), // output
	.FC2        (             ), // output
	.oRESETn    (             ), // output
	.oHALTEDn   (             ), // output
	.VMAn       (             ), // output
	.E          (             )  // output
);


///////////////////
// ROM
///////////////////

assign o_rom_addr = cpu_addr[17:1];
assign o_rom_cs = ~prom_cs_n;
assign rom_dout = i_rom_data;

///////////////////
// RAM
///////////////////

// ** 2 x CMOS 64 kbit SRAM **
// ** [8464] @ 16C, 17C     **
// ** Hex Inverter **
// ** [LS04] @ 17G **
jtframe_ram #( .AW(14), .DW(8) ) u_ram_lo(
	.clk    ( i_clk                        ),
	.cen    ( 1'b1                         ),
	.addr   ( cpu_addr[14:1]               ),
	.data   ( cpu_dout[ 7:0]               ),
	.we     ( &{ ~ram_cs_n, ~RnW, ~lds_n } ),
	.q      ( ram_lo_dout                  )
);

// ** 2 x CMOS 64 kbit SRAM **
// ** [8464] @ 16A, 17A     **
// ** Hex Inverter **
// ** [LS04] @ 17G **
jtframe_ram #( .AW(14), .DW(8) ) u_ram_hi(
	.clk    ( i_clk                        ),
	.cen    ( 1'b1                         ),
	.addr   ( cpu_addr[14:1]               ),
	.data   ( cpu_dout[15:8]               ),
	.we     ( &{ ~ram_cs_n, ~RnW, ~uds_n } ),
	.q      ( ram_hi_dout                  )
);

`else

assign o_inter_non = 1'b0;
assign o_288_256   = 1'b0;
assign o_vflip     = 1'b0;
assign o_hflip     = 1'b0;
assign o_addr      = 15'h0000;

`endif

///////////////////
// COLOR RAM
///////////////////

// ** Quad 2-Input AND Gate   **
// ** [LS09] @ 4K, 4L, 5K, 5L **
always @( posedge i_clk ) if( i_cen6 ) begin
	o_red   <= color[4:0];
	o_green <= color[9:5];
	o_blue  <= color[14:10];
end

// ** 16 kbit SRAM    **
// ** [2128-15] @ 14K **
// ** Quad 2-Input OR Gate **
// ** [LS32] @ 15J         **
jtframe_dual_ram #( .AW(11), .DW(8), .SIMHEXFILE("colorram_lo.hex") ) u_color_ram_lo(
	.clk0    ( i_clk                         ),
	.addr0   ( cpu_addr[11:1]                ),
	.data0   ( cpu_dout[ 7:0]                ),
	.we0     ( &{ ~color_ram, ~RnW, ~lds_n } ),
	.q0      ( color_ram_lo_dout             ),

	.clk1    ( i_clk                         ),
	.addr1   ( i_cd                          ),
	.data1   (                               ),
	.we1     ( 1'b0                          ),
	.q1      ( color[7:0]                    )
);

// ** 16 kbit SRAM    **
// ** [2128-15] @ 15K **
// ** Quad 2-Input OR Gate **
// ** [LS32] @ 15J         **
jtframe_dual_ram #( .AW(11), .DW(8), .SIMHEXFILE("colorram_hi.hex") ) u_color_ram_hi(
	.clk0    ( i_clk                         ),
	.addr0   ( cpu_addr[11:1]                ),
	.data0   ( cpu_dout[15:8]                ),
	.we0     ( &{ ~color_ram, ~RnW, ~uds_n } ),
	.q0      ( color_ram_hi_dout             ),

	.clk1    ( i_clk                         ),
	.addr1   ( i_cd                          ),
	.data1   (                               ),
	.we1     ( 1'b0                          ),
	.q1      ( color[15:8]                   )
);

endmodule
