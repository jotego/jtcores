/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2026.
SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
SPDX-License-Identifier: GPL-3.0-only
Project edit date: 2026-11-08.

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

module jtnemsis_main
(
    input         rst,
    input         clk,
    input         pxl_cen,
    input         cen_9,
    input         vblank,       // Existing preLVBL_n polarity: high while blank.
    input         v256,
    input         clk6,         // Physical 6 MHz clock level, not an enable.
    input         h1_n,
    input         h2,

    output        chacs_n,
    output        rw_n,
    output        uds_n,
    output        lds_n,
    output        inter_non,
    output        resolution_288_256,
    output        vflip,
    output        hflip,
    output        objram_n,
    output        vcs2,
    output        vcs1,
    output        vzcs,

    output [17:1] main_addr,
    output        main_cs,      // Active high SDRAM request.
    input  [15:0] main_data,
    input         main_ok,

    output        sound_on_n,
    output        data_n,
    output [ 7:0] sound_db,

    output [15:1] video_addr,
    input  [15:0] video_din,    // Data entering main from the video bus.
    output [15:0] video_dout,   // Data driven from main onto the video bus.
    output [11:1] pal_cpu_addr,
    output [15:0] pal_cpu_din,
    output [ 1:0] pal_cpu_we,
    input  [15:0] pal_cpu_dout,
    input  [15:0] pal_video_dout,

    output reg [ 4:0] red,
    output reg [ 4:0] green,
    output reg [ 4:0] blue,

    input  [ 6:0] joystick1,
    input  [ 6:0] joystick2,
    input  [ 1:0] coin,
    input  [ 1:0] cab_1p,
    input  [23:0] dipsw,
    input         service,
    input         dip_pause,

    input  [ 7:0] debug_bus,
    output [ 7:0] st_dout,
    input  [ 3:0] ioctl_addr
    `ifdef JTFRAME_IOCTL_RD
    , output [ 7:0] ioctl_din
    `endif
);

// ---------------------------------------------------------------------------
// Signals
// ---------------------------------------------------------------------------

// clock enables
reg         cpu_cen, cpu_cenb;

// address and data buses
wire        as_n, rnw, vpa_n, int16_n, int32_n, u16f_d1, u16f_d2;
wire        cpu_halt_n, irq16_set, irq32_set;
wire        ram_lo_we, ram_hi_we, video_cs_n;
wire [ 7:0] u11k_latch_din, u13j_latch_din;
reg         dtack_n;
reg  [ 2:0] ipl_n;
wire [ 1:0] input_mux_sel;
wire [ 7:0] input_mux_a, input_mux_b, input_mux_c, input_mux_d;
wire        dtack_other_n, dtack_vzure_objram_n, dtack_vram_chara_n;
wire        idt, vzure_objram_cs_n, vram_chara_cs_n, lanes_idle, clk6_1h_2h;
wire        u11k_q0, u11k_q1, u11k_q2, u11k_q3;
wire        u11k_q4, u11k_q5, u11k_q6, u11k_q7;
wire        u13j_q0, u13j_q1, u13j_q2, u13j_q3;
wire        u13j_q4, u13j_q5, u13j_q6, u13j_q7;
wire [ 7:0] u11k_ioctl_din, u13j_ioctl_din;
wire [23:1] cpu_addr;
wire [15:0] cpu_dout;
reg  [15:0] cpu_din;
wire [ 7:0] ram_hi_dout, ram_lo_dout;
wire [ 7:0] u11k_out, u13j_out;
reg  [ 7:0] input_mux_out;

// chip selects
wire        prom_cs_n, ram_cs_n, chara, excs_n, pre_ram_cs_n,
            vzure, vramcs1, vramcs2, objram, color_ram, u11k_g_n, u13j_g_n,
            afe_n, input_mux_g_n, dip1_g_n, dip2_g_n;
reg         reg_ram_cs;
wire        u11k_mmr_cs, u13j_mmr_cs;
`ifdef SDRAM_FIX
wire        udsw_n, ldsw_n;
reg         dsn_dly;
`endif

assign u11k_latch_din = { 7'd0, cpu_dout[0] };
assign u13j_latch_din = { 7'd0, cpu_dout[8] };

`ifndef NOMAIN

// Combinational wiring
assign video_cs_n = &{ objram, vzure, vramcs1, vramcs2, chara };
assign irq16_set = ~int16_n;
assign irq32_set = ~int32_n;
assign ram_lo_we = &{ ~ram_cs_n, ~rnw, ~lds_n };
assign ram_hi_we = &{ ~ram_cs_n, ~rnw, ~uds_n };
assign cpu_halt_n = ~rst;
assign idt = 1'b1;
assign vzure_objram_cs_n = &{ vzure, objram };
assign vram_chara_cs_n = &{ idt, vramcs1, vramcs2, chara };
assign lanes_idle = &{ lds_n, uds_n };
assign clk6_1h_2h = ~|{ clk6, ~h1_n, h2 };
assign int16_n = u11k_out[0];
assign int32_n = u11k_out[1];
assign vpa_n = |{ ~cpu_addr[23], as_n };
assign main_addr = cpu_addr[17:1];
assign main_cs = ~prom_cs_n;
`ifdef SDRAM_FIX
assign udsw_n = rnw | uds_n;
assign ldsw_n = rnw | lds_n;
assign ram_cs_n = dsn_dly ? reg_ram_cs : pre_ram_cs_n;
`else
assign ram_cs_n = pre_ram_cs_n;
`endif

// ---------------------------------------------------------------------------
// Inputs / Outputs
// ---------------------------------------------------------------------------

// chip select outputs to video
assign chacs_n      = chara;
assign vzcs         = vzure;
assign vcs1         = vramcs1;
assign vcs2         = vramcs2;
assign objram_n     = objram;

// address and data to video
assign rw_n         = rnw;
assign video_addr = cpu_addr[15:1];
assign video_dout = cpu_dout;

// data output to sound
assign sound_db     = cpu_dout[7:0];
assign sound_on_n   = u13j_out[2];

assign u11k_mmr_cs = ~u11k_g_n;
assign u13j_mmr_cs = ~u13j_g_n;

// ---------------------------------------------------------------------------
// Input MUX
// ---------------------------------------------------------------------------

// MiSTer joystick input is active low, like the Nemesis buttons that are grounded with a pull-up.
// But there are optocouplers on the PCB that invert the signal, so we have to invert here too.
//
// ** 5 x Quad Optocoupler            **
// ** [PS2401-4] @ 2E, 2F, 2G, 2H, 2J **
// ** 8-Bit DIP Switch                **
// ** [DIP] @ 5G                      **
assign input_mux_a = { 3'b0, ~cab_1p[1], ~cab_1p[0], ~service, ~coin[1], ~coin[0] };
assign input_mux_b = { 1'b0, ~joystick1[6], ~joystick1[5], ~joystick1[4], ~joystick1[2], ~joystick1[3], ~joystick1[0], ~joystick1[1] };
assign input_mux_c = { 1'b0, ~joystick2[6], ~joystick2[5], ~joystick2[4], ~joystick2[2], ~joystick2[3], ~joystick2[0], ~joystick2[1] };
assign input_mux_d = dipsw[23:16];

assign input_mux_sel = cpu_addr[2:1];

// ** 4 x Dual 4-to-1 Line Multiplexer **
// ** [LS253] @ 3E, 3F, 3G, 3J         **
always @(*) begin
	case( input_mux_sel )
		2'b00: input_mux_out = input_mux_a;
		2'b01: input_mux_out = input_mux_b;
		2'b10: input_mux_out = input_mux_c;
		2'b11: input_mux_out = input_mux_d;
	endcase
end

// ---------------------------------------------------------------------------
// Address Decoding
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// SDRAM Fix
// ---------------------------------------------------------------------------

// TODO: see if needed

`ifdef SDRAM_FIX

// ram_cs and vram_cs signals go down before DSWn signals
// that causes a false read request to the SDRAM. In order
// to avoid that a little bit of logic is needed:

always @(posedge clk) if( cpu_cen ) begin
	reg_ram_cs <= pre_ram_cs_n;
	dsn_dly    <= &{ udsw_n, ldsw_n }; // low if any DSWn was low
end
`endif

// ---------------------------------------------------------------------------
// CPU Clock Enables
// ---------------------------------------------------------------------------

// generate enPhi1 and enPhi2 for fx68k by advancing and delaying 9 MHz clock by 1 48 MHz clock
always @(posedge clk ) begin
	reg cpu_cen_dly;

	cpu_cen  <= cen_9;
	cpu_cen_dly <= cpu_cen;
	cpu_cenb <= cpu_cen_dly;
end

// ---------------------------------------------------------------------------
// CPU Data Bus Input
// ---------------------------------------------------------------------------

// Use = in always @(*) (like in jt_gng/sf).

// ** Triple 3-Input NAND Gate **
// ** [LS10] @ 16J             **
// ** Hex Inverter             **
// ** [LS04] @ 17G             **
// ** Dual 4-Input AND Gate    **
// ** [LS21] @ 12E             **

always @(*) begin
	case( 1'b0 )
		prom_cs_n:      cpu_din = main_data;
		ram_cs_n:       cpu_din = { ram_hi_dout, ram_lo_dout };
		color_ram:      cpu_din = pal_cpu_dout;
		dip1_g_n:       cpu_din = { 8'h00, dipsw[7:0] };
		dip2_g_n:       cpu_din = { 8'h00, dipsw[15:8] };
		input_mux_g_n:  cpu_din = { 8'h00, input_mux_out };
		u11k_g_n:       cpu_din = { 8'h00, u11k_out };
		u13j_g_n:       cpu_din = { 8'h00, u13j_out };
		video_cs_n:     cpu_din = video_din;
		default:        cpu_din = 16'hffff;
	endcase
end

// ---------------------------------------------------------------------------
// Addressable Latches
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// dtack_n Generation
// ---------------------------------------------------------------------------

// from debug connector?
//
// ** Octal Buffer **
// ** [LS244] @ 7K **

// ** Triple 3-Input NAND Gate **
// ** [LS10] @ 16J             **
// ** Hex Inverter             **
// ** [LS04] @ 17G             **
// ** Quad 2-Input AND Gate    **
// ** [LS08] @ 11F             **

// ** Dual D Flip-Flop  **
// ** [LS74] @ 17E, top **

// ** Dual D Flip-Flop     **
// ** [LS74] @ 17E, bottom **

// ** Hex Inverter         **
// ** [LS04] @ 17G         **
// ** Tri 3-Input NOR Gate **
// ** [LS27]  @ 16G        **

// ** Dual D Flip-Flop **
// ** [LS74] @ 18F     **

// Schematic feeds prom_cs_n to both A and B selector inputs of mux
// so that it selects input D. In Verilog we can do it more explicitely
// by testing 3 signals and having a default case.
// 
// ** Dual 4-Line to 1-Line Data Selector/Multiplexer **
// ** [LS153] @ 16E                                   **
always @(*) begin
	case( { prom_cs_n, vzure_objram_cs_n, vram_chara_cs_n } )
		3'b011:  dtack_n = ( lanes_idle | ~main_ok ); // PROM (add ROM OK signal to wait for SDRAM ready)
		3'b101:  dtack_n = dtack_vzure_objram_n;   // VZURE or OBJRAM
		3'b110:  dtack_n = dtack_vram_chara_n;     // VRAMCS1-2, CHARA
		default: dtack_n = dtack_other_n;
	endcase
end

// ---------------------------------------------------------------------------
// Interrupt handling
// ---------------------------------------------------------------------------

// ** Hex D Flip-Flop    **
// ** [LS174] @ 17F, top **

// ** Hex D Flip-Flop       **
// ** [LS174] @ 17F, bottom **

// ** 10–Line to 4-Line Priority Encoder **
// ** [LS147] @ 16F                      **
always @(*) begin
	if( ~u16f_d2 & dip_pause )
		ipl_n = 3'b101;
	else if( ~u16f_d1 & dip_pause )
		ipl_n = 3'b110;
	else
		ipl_n = 3'b111;
end

// ---------------------------------------------------------------------------
// CPU
// ---------------------------------------------------------------------------

// ** Hex Inverter         **
// ** [LS04] @ 17G         **
// ** Quad 2-Input OR Gate **
// ** [LS32]  @ 15J        **

// ** 16-Bit Microprocessor **
// ** [68000] @ 14E         **

// ---------------------------------------------------------------------------
// ROM
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// RAM
// ---------------------------------------------------------------------------

// ** 2 x CMOS 64 kbit SRAM **
// ** [8464] @ 16C, 17C     **
// ** Hex Inverter **
// ** [LS04] @ 17G **

// ** 2 x CMOS 64 kbit SRAM **
// ** [8464] @ 16A, 17A     **
// ** Hex Inverter **
// ** [LS04] @ 17G **

// Instances
jtnemsis_palram_if u_palram_if(
	.cpu_addr ( cpu_addr[11:1] ),
	.cpu_din  ( cpu_dout       ),
	.cs_n     ( color_ram      ),
	.rnw      ( rnw            ),
	.uds_n    ( uds_n          ),
	.lds_n    ( lds_n          ),
	.pal_addr ( pal_cpu_addr ),
	.pal_din  ( pal_cpu_din  ),
	.pal_we   ( pal_cpu_we   )
);

jtnemsis_68k_addr_dec u_addr_dec(
	.as_n           ( as_n           ),
	.lds_n          ( lds_n          ),
	.uds_n          ( uds_n          ),
	.cpu_addr       ( cpu_addr       ),

	.prom_cs_n      ( prom_cs_n      ),
	.chara          ( chara          ),
	.excs_n         ( excs_n         ),
	.ram_cs_n       ( pre_ram_cs_n   ),
	.vzure          ( vzure          ),
	.vramcs1        ( vramcs1        ),
	.vramcs2        ( vramcs2        ),
	.objram         ( objram         ),
	.color_ram      ( color_ram      ),
	.u11k_g_n       ( u11k_g_n       ),
	.u13j_g_n       ( u13j_g_n       ),
	.data_n         ( data_n         ),
	.afe_n          ( afe_n          ),
	.input_mux_g_n  ( input_mux_g_n  ),
	.dip1_g_n       ( dip1_g_n       ),
	.dip2_g_n       ( dip2_g_n       )
);

jtframe_ff u_17e_top(
	.rst     ( rst        ),
	.clk     ( clk        ),
	.cen     ( 1'b1         ),
	.sigedge ( clk6       ),
	.set     ( lanes_idle        ),
	.clr     ( 1'b0         ),
	.din     ( lanes_idle        ),
	.q       ( dtack_other_n ),
	.qn      (              )
);

jtframe_ff u_17e_bottom(
	.rst     ( rst               ),
	.clk     ( clk               ),
	.cen     ( 1'b1                ),
	.sigedge ( h1_n              ),
	.set     ( lanes_idle               ),
	.clr     ( 1'b0                ),
	.din     ( lanes_idle               ),
	.q       ( dtack_vzure_objram_n ),
	.qn      (                     )
);

jtframe_ff u_18f(
	.rst     ( rst             ),
	.clk     ( clk             ),
	.cen     ( 1'b1              ),
	.sigedge ( clk6_1h_2h        ),
	.set     ( lanes_idle             ),
	.clr     ( 1'b0              ),
	.din     ( dtack_other_n      ),
	.q       ( dtack_vram_chara_n ),
	.qn      (                   )
);

jtframe_ff u_17f_top(
	.rst     ( rst    ),
	.clk     ( clk    ),
	.cen     ( 1'b1     ),
	.sigedge ( vblank ),
	.set     ( irq16_set ),
	.clr     ( 1'b0     ),
	.din     ( 1'b0     ),
	.q       ( u16f_d2  ),
	.qn      (          )
);

jtframe_ff u_17f_bottom(
	.rst     ( rst    ),
	.clk     ( clk    ),
	.cen     ( 1'b1     ),
	.sigedge ( v256   ),
	.set     ( irq32_set ),
	.clr     ( 1'b0     ),
	.din     ( 1'b0     ),
	.q       ( u16f_d1  ),
	.qn      (          )
);

jtframe_ram #( .AW(14) ) u_ram_lo(
	.clk    ( clk                        ),
	.cen    ( 1'b1                         ),
	.addr   ( cpu_addr[14:1]               ),
	.data   ( cpu_dout[ 7:0]               ),
	.we     ( ram_lo_we ),
	.q      ( ram_lo_dout                  )
);

jtframe_ram #( .AW(14) ) u_ram_hi(
	.clk    ( clk                        ),
	.cen    ( 1'b1                         ),
	.addr   ( cpu_addr[14:1]               ),
	.data   ( cpu_dout[15:8]               ),
	.we     ( ram_hi_we ),
	.q      ( ram_hi_dout                  )
);

`else

// Keep live generated MMR blocks at known addresses/data during scene playback.
assign cpu_addr = 23'd0;
assign cpu_dout = 16'd0;
assign chacs_n      = 1'b1;
assign objram_n     = 1'b1;
assign vcs1         = 1'b1;
assign vcs2         = 1'b1;
assign vzcs         = 1'b1;
assign rw_n         = 1'b1;
assign uds_n        = 1'b1;
assign lds_n        = 1'b1;
assign video_addr = 15'd0;
assign video_dout = 16'd0;
assign main_cs       = 1'b0;
assign main_addr     = 17'd0;
assign sound_on_n   = 1'b1;
assign data_n       = 1'b1;
assign sound_db     = 8'd0;
assign pal_cpu_addr = 11'd0;
assign pal_cpu_din  = 16'd0;
assign pal_cpu_we   = 2'b00;
assign u11k_mmr_cs = 1'b0;
assign u13j_mmr_cs = 1'b0;

`endif

// These outputs remain connected during NOMAIN scene runs so the generated
// MMR restore values continue to control the measured video hardware.
assign hflip     = u11k_out[2];
assign vflip     = u11k_out[3];
assign resolution_288_256   = u11k_out[4];
assign inter_non = u11k_out[5];

assign st_dout = debug_bus[1:0] == 2'd0 ? u11k_out :
                 debug_bus[1:0] == 2'd1 ? u13j_out :
                 debug_bus[1:0] == 2'd2 ? {2'b0, u11k_out[5:0]} : 8'd0;

// The LS259 enables are qualified by LDS/UDS in the address decoder. The
// measured RTL writes while selected even during read cycles, so rnw is held
// low here to preserve that addressable-latch behavior.

// ---------------------------------------------------------------------------
// COLOR RAM
// ---------------------------------------------------------------------------

// ** Quad 2-Input AND Gate   **
// ** [LS09] @ 4K, 4L, 5K, 5L **
assign u13j_out = {u13j_q7, u13j_q6, u13j_q5, u13j_q4,
                   u13j_q3, u13j_q2, u13j_q1, u13j_q0};

assign u11k_out = {u11k_q7, u11k_q6, u11k_q5, u11k_q4,
                   u11k_q3, u11k_q2, u11k_q1, u11k_q0};

`ifdef JTFRAME_IOCTL_RD
assign ioctl_din = ioctl_addr[3] ? u13j_ioctl_din : u11k_ioctl_din;
`endif

always @( posedge clk ) if( pxl_cen ) begin
	red   <= pal_video_dout[4:0];
	green <= pal_video_dout[9:5];
	blue  <= pal_video_dout[14:10];
end

jtnemsis_u11k_mmr u11k_mmr(
	.rst        ( rst             ),
	.clk        ( clk             ),
	.cs         ( u11k_mmr_cs       ),
	.addr       ( cpu_addr[3:1]     ),
	.rnw        ( 1'b0              ),
	.din        ( u11k_latch_din ),
	.dout       (                   ),
	.u11k_q0    ( u11k_q0           ),
	.u11k_q1    ( u11k_q1           ),
	.u11k_q2    ( u11k_q2           ),
	.u11k_q3    ( u11k_q3           ),
	.u11k_q4    ( u11k_q4           ),
	.u11k_q5    ( u11k_q5           ),
	.u11k_q6    ( u11k_q6           ),
	.u11k_q7    ( u11k_q7           ),
	.ioctl_addr ( ioctl_addr[2:0]   ),
	.ioctl_din  ( u11k_ioctl_din    ),
	.debug_bus  ( 8'd0              ),
	.st_dout    (                   )
);

jtnemsis_u13j_mmr #(.SEEK(8)) u13j_mmr(
	.rst        ( rst             ),
	.clk        ( clk             ),
	.cs         ( u13j_mmr_cs       ),
	.addr       ( cpu_addr[3:1]     ),
	.rnw        ( 1'b0              ),
	.din        ( u13j_latch_din ),
	.dout       (                   ),
	.u13j_q0    ( u13j_q0           ),
	.u13j_q1    ( u13j_q1           ),
	.u13j_q2    ( u13j_q2           ),
	.u13j_q3    ( u13j_q3           ),
	.u13j_q4    ( u13j_q4           ),
	.u13j_q5    ( u13j_q5           ),
	.u13j_q6    ( u13j_q6           ),
	.u13j_q7    ( u13j_q7           ),
	.ioctl_addr ( ioctl_addr[2:0]   ),
	.ioctl_din  ( u13j_ioctl_din    ),
	.debug_bus  ( 8'd0              ),
	.st_dout    (                   )
);

`ifndef NOMAIN
fx68k u_cpu(
	.clk        ( clk       ), // input - 48 MHz
	.extReset   ( rst       ), // input - active high (real 68k reset is active low)
	.pwrUp      ( rst       ), // input
	.enPhi1     ( cpu_cen        ), // input
	.enPhi2     ( cpu_cenb       ), // input
	.HALTn      ( cpu_halt_n ), // input

	// Buses
	.eab        ( cpu_addr    ), // output
	.iEdb       ( cpu_din     ), // input
	.oEdb       ( cpu_dout    ), // output

	.eRWn       ( rnw         ), // output
	.LDSn       ( lds_n       ), // output
	.UDSn       ( uds_n       ), // output
	.ASn        ( as_n        ), // output
	.VPAn       ( vpa_n       ), // input

	.BERRn      ( 1'b1        ), // input

	// Bus arbitration
	.BRn        ( 1'b1        ), // input
	.BGACKn     ( 1'b1        ), // input

	.DTACKn     ( dtack_n      ), // input
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
`endif

endmodule
