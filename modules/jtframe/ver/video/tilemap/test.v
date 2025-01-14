`timescale 1ns/1ps

module test;

parameter SIZE         =  8,    // 8x8, 16x16 or 32x32
		  VA           = 10,    // VRAM bit width
		  CW           = 12,
		  PW           =  8,    // pixel width
		  BPP          =  2,    // bits per pixel. Palette width = PW-BPP
		  VR           = SIZE==8 ? CW+3 : SIZE==16 ? CW+5 : CW+7,
		  MAP_HW       = 8,    // 2^MAP_HW = size of the map in pixels
		  MAP_VW       = 8,
		  FLIP_MSB     = 1, // set to 0 for scroll tile maps
		  FLIP_HDUMP   = 1,
		  FLIP_VDUMP   = 1,
		  XOR_HFLIP    = 0,  // set to 1 so hflip gets ^ with flip
		  XOR_VFLIP    = 0,  // set to 1 so vflip gets ^ with flip
		  HDUMP_OFFSET = 0,  // adds an offset to hdump
		  HJUMP        = 1,  // see jtframe_scroll
		  // override VH and HW only for non rectangular tiles
		  VW           = SIZE==8 ? 3 : SIZE==16 ? 4: 5,
		  HW           = VW;

localparam PALW = PW-BPP,
		   DW   = 8*BPP;

reg  [ 4:0] cen_cnt=0;
reg         rst, clk,
			change, vswap, lvbl_l;
wire        pxl_cen, pxl_zero;

wire [   8:0] V,H;
wire          LVBL, LHBL;
reg  [  31:0] data;
// wire [VR-1:0] rom_addr;
wire [VA-1:0] vram_addr;
reg  [CW-1:0] code;
wire [PW-1:0] pxl;
reg  [   2:0] sel;
reg           flip;

localparam [2:0] M942 = 0, DD=1, FROUND=2, KARNOV=3,
				 WWF  = 4, WC=5;

initial begin
	$dumpfile("test.lxt");
	$dumpvars;
	$dumpon;
	#500000000 $finish;
end

assign pxl_cen     =  cen_cnt[1:0]==3;
assign pxl_zero    = &cen_cnt;

function vram_check( input [10:0] addr,   input [4:0] vdump, input [4:0] hdump, // H[7:3], V[7:3]
					 input        fl,     input [SIZE-1:0] sz);
	reg [4:0] veff, heff;
	veff = FLIP_VDUMP ?  vdump^{5{fl}}                    : vdump;
	heff = FLIP_HDUMP ? (hdump-HDUMP_OFFSET[4:0])^{5{fl}} : hdump-HDUMP_OFFSET[4:0];
	vram_check  = addr=={veff>>sz,heff}>>sz;
endfunction

function pxl_check( input flip, input [PW-1:0] pxl, input [31:0] data );
	pxl_check   = flip ? pxl[3:0] =={data[24],data[16],data[ 8],data[ 0]} :
						 pxl[3:0] =={data[31],data[23],data[15],data[ 7]} ;
endfunction

initial begin
	clk  = 0;
	data = 0;
 	code = 0;
	forever clk = #10 ~clk;
end

always @(posedge clk) begin
    cen_cnt <= cen_cnt + 1'd1;
    lvbl_l  <= LVBL; vswap <= LVBL != lvbl_l;
    if( pxl_zero ) data[15:0] <= {data[7:0],H[7:0]};
end

initial begin
	rst = 1;
	sel = 0;
	change =0;
	flip = 0;
	repeat (5) @(posedge clk);
	rst = 0;
	// Check if it works with different timing values and changing the flip
	// sel 0 flip 0
	repeat (3) begin wait (vswap==1);
					 @(posedge clk); end
	// sel 0 flip 1
	@(posedge clk) flip=1;
	repeat (4) @(posedge clk) change =~change;
	repeat (3) begin wait (vswap==1);
					@(posedge clk); @(posedge clk); end
    // sel 1 flip 0
	@(posedge clk) begin sel=1; flip=0; end
	repeat (4) @(posedge clk) change =~change;
	repeat (3) begin wait (vswap==1);
					@(posedge clk); @(posedge clk); end
    // sel 1 flip 1
	@(posedge clk) flip=1;
	repeat (4) @(posedge clk) change =~change;
	repeat (3) begin wait (vswap==1);
					@(posedge clk); @(posedge clk); end
	// sel 2 flip 0
	@(posedge clk) begin sel=2; flip=0; end
	repeat (4) @(posedge clk) change =~change;
	repeat (3) begin wait (vswap==1);
					@(posedge clk); @(posedge clk); end
    // sel 2 flip 1
	@(posedge clk) flip=1;
	repeat (4) @(posedge clk) change =~change;
	repeat (3) begin wait (vswap==1);
					@(posedge clk); @(posedge clk); end
	// sel 3 flip 0
	@(posedge clk) begin sel=3; flip=0; end
	repeat (4) @(posedge clk) change =~change;
	repeat (3) begin wait (vswap==1);
					@(posedge clk); @(posedge clk); end
    // sel 3 flip 1
	@(posedge clk) flip=1;
	repeat (4) @(posedge clk) change =~change;
	repeat (3) begin wait (vswap==1);
					@(posedge clk); @(posedge clk); end
	// sel 4 flip 0
	@(posedge clk) begin sel=4; flip=0; end
	repeat (4) @(posedge clk) change =~change;
	repeat (3) begin wait (vswap==1);
					@(posedge clk); @(posedge clk); end
    // sel 4 flip 1
	@(posedge clk) flip=1;
	repeat (4) @(posedge clk) change =~change;
	repeat (3) begin wait (vswap==1);
					@(posedge clk); @(posedge clk); end
	// sel 5 flip 0
	@(posedge clk) begin sel=5; flip=0; end
	repeat (4) @(posedge clk) change =~change;
	repeat (3) begin wait (vswap==1);
					@(posedge clk); @(posedge clk); end
    // sel 5 flip 1
	@(posedge clk) flip=1;
	repeat (4) @(posedge clk) change =~change;
	repeat (3) begin wait (vswap==1);
					@(posedge clk); @(posedge clk); end
	$display("PASS");
	$finish;
end

jtframe_tilemap #(
	.SIZE(SIZE), .VA(VA),
	.CW(CW),.PW(PW),.BPP(BPP),
	.VR(VR),.MAP_HW(MAP_HW),.MAP_VW(MAP_VW),
	.FLIP_MSB(FLIP_MSB),.FLIP_HDUMP(FLIP_HDUMP),.FLIP_VDUMP(FLIP_VDUMP),
	.XOR_HFLIP(XOR_HFLIP),.XOR_VFLIP(XOR_VFLIP),
	.HDUMP_OFFSET(HDUMP_OFFSET),
	.HJUMP(HJUMP),
	.VW(VW),.HW(HW)
	)u_char(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .vdump      ( V             ),
    .hdump      ( H             ),
    .blankn     ( LVBL          ),
    .flip       ( flip          ),

    .vram_addr  ( vram_addr     ),

    .code       ( code          ),
    .pal        ( {PALW{1'd0}}  ),
    .hflip      ( hflip         ),
    .vflip      ( vflip         ),

    .rom_addr   ( /*rom_addr*/  ),
    .rom_data   ( data[0+:DW]   ),
    .rom_cs     (               ),
    .rom_ok     ( 1'b1          ),      // ignored. It assumes that data is always right

    .pxl        ( pxl           )
);

	wire v_check, p_check;
	assign v_check = vram_check( {{4'd11-VA{1'b0}},vram_addr}, V[7:3], H[7:3], flip, SIZE>>4);
	assign p_check = pxl_check(flip, pxl, data);

	always @(posedge clk) if(pxl_cen) begin
	    assert(v_check) else $fatal;
	    if( cen_cnt==5'd6 ) assert(p_check) else $fatal;
	end

localparam SIZE_TEST=3;
genvar sz;

generate
	for( sz=0; sz < SIZE_TEST; sz = sz +1) begin
		localparam 	SZ = 6'd8<<sz,
					VA_T = 10 - sz*2;
		// wire [VR_T-1:0] rom_ad;
		wire [VA_T-1:0] vram_ad;
		wire [  PW-1:0] pxl_sz;
		wire [     5:0] szz= SZ;
		wire [     3:0] va=VA_T;
		wire        px_check, vr_check;

		jtframe_tilemap #(
			.SIZE(SZ),.VA(VA_T),
			.CW(CW),.PW(PW),.BPP(4),
			.MAP_HW(MAP_HW),.MAP_VW(MAP_VW),
			.FLIP_MSB(FLIP_MSB),.FLIP_HDUMP(FLIP_HDUMP),.FLIP_VDUMP(FLIP_VDUMP),
			.XOR_HFLIP(XOR_HFLIP),.XOR_VFLIP(XOR_VFLIP),
			.HDUMP_OFFSET(HDUMP_OFFSET),
			.HJUMP(HJUMP)
			)u_size(
		    .rst        ( rst           ),
		    .clk        ( clk           ),
		    .pxl_cen    ( pxl_cen       ),

		    .vdump      ( V             ),
		    .hdump      ( H             ),
		    .blankn     ( LVBL          ),
		    .flip       ( flip          ),

		    .vram_addr  ( vram_ad       ),

		    .code       (  code         ),
		    .pal        (  4'd0         ),
		    .hflip      ( hflip         ),
		    .vflip      ( vflip         ),

		    .rom_addr   ( /*rom_ad*/    ),
		    .rom_data   ( data          ),
		    .rom_cs     (               ),
		    .rom_ok     ( 1'b1          ),
		    .pxl        ( pxl_sz        )
		);

		assign vr_check = vram_check( {{4'd11-VA_T{1'b0}},vram_ad}, V[7:3], H[7:3], flip, sz);
		assign px_check = pxl_check(flip, pxl_sz, data);

		always @(posedge clk) if(pxl_cen) begin
		    assert(vr_check) else $fatal;
		    if( cen_cnt==5'd6 ) assert(px_check) else $fatal;
		end
	end
endgenerate

test_timer_gate u_timer(
	.clk     ( clk     ),
	.pxl_cen ( pxl_cen ),
	.sel     ( sel     ),
	.V       ( V       ),
	.H       ( H       ),
	.LHBL    ( LHBL    ),
	.LVBL    ( LVBL    ),
	.HS      (         ),
	.VS      (         )

);


endmodule





module test_timer_gate (
	input            clk,
	input            pxl_cen,
	input      [2:0] sel,
	output reg [8:0] V,
	output reg [8:0] H,
	output reg       LHBL,
	output reg       LVBL,
	output reg       HS,
	output reg       VS

);

localparam [2:0] M942 = 0, DD=1, FROUND=2, KARNOV=3,
				 WWF  = 4, WC=5;

wire [8:0]	M9_v, M9_h, DD_v, DD_h,
			FR_v, FR_h, KV_v, KV_h,
			WF_v, WF_h, WC_v, WC_h;
wire 		M9_lhbl, M9_lvbl, M9_hs, M9_vs,
			DD_lhbl, DD_lvbl, DD_hs, DD_vs,
			FR_lhbl, FR_lvbl, FR_hs, FR_vs,
			KV_lhbl, KV_lvbl, KV_hs, KV_vs,
			WF_lhbl, WF_lvbl, WF_hs, WF_vs,
			WC_lhbl, WC_lvbl, WC_hs, WC_vs;

always @(*) begin
	case (sel)
		M942:   {V, H, LVBL, LHBL, HS, VS} = {M9_v, M9_h, M9_lvbl, M9_lhbl, M9_hs, M9_vs};
		DD:     {V, H, LVBL, LHBL, HS, VS} = {DD_v, DD_h, DD_lvbl, DD_lhbl, DD_hs, DD_vs};
		FROUND: {V, H, LVBL, LHBL, HS, VS} = {FR_v, FR_h, FR_lvbl, FR_lhbl, FR_hs, FR_vs};
		KARNOV: {V, H, LVBL, LHBL, HS, VS} = {KV_v, KV_h, KV_lvbl, KV_lhbl, KV_hs, KV_vs};
		WWF:    {V, H, LVBL, LHBL, HS, VS} = {WF_v, WF_h, WF_lvbl, WF_lhbl, WF_hs, WF_vs};
		WC:     {V, H, LVBL, LHBL, HS, VS} = {WC_v, WC_h, WC_lvbl, WC_lhbl, WC_hs, WC_vs};
		default:;
	endcase
end

jtgng_timer u_1942_timer(
    .clk       ( clk      ),
    .cen6      ( pxl_cen  ),
    .V         ( M9_v     ),
    .H         ( M9_h     ),
    .Hinit     (          ),
    .LHBL      ( M9_lhbl  ),
    .LVBL      ( M9_lvbl  ),
    .LHBL_obj  (          ),
    .HS        ( M9_hs    ),
    .VS        ( M9_vs    ),
    .Vinit     (          ),
    .LVBL_obj  (          )
);

jtframe_vtimer #(
    .VB_START   ( 9'hf7     ),
    .VB_END     ( 9'h7      ),
    .VCNT_END   ( 9'd271    ),
    .VS_START   ( 9'h106    ),
    .HS_START   ( 9'h1ae    ),
    .HB_START   ( 9'h184    ),
    .HJUMP      ( 1         ),
    .HB_END     ( 9'd4      ),
    .HINIT      ( 9'd255    )
)   u_dd_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( DD_v      ),
    .vrender    (           ),
    .vrender1   (           ),
    .H          ( DD_h      ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( DD_lhbl   ),
    .LVBL       ( DD_lvbl   ),
    .HS         ( DD_hs     ),
    .VS         ( DD_vs     )
);

jtframe_vtimer #(
    .HCNT_START ( 9'h020    ),
    .HCNT_END   ( 9'h19F    ),
    .HB_START   ( 9'h029    ), // 320 visible, 384 total (64 pxl=HB)
    .HB_END     ( 9'h069    ),
    .HS_START   ( 9'h031    ), // HS starts 8 pixels after HB
    .HS_END     ( 9'h051    ), // 32 pixel wide

    .V_START    ( 9'h0F8    ), // 224 visible, 40 blank, 264 total
    .VB_START   ( 9'h1EF    ),
    .VB_END     ( 9'h10F    ),
    .VS_START   ( 9'h1FF    ), // 8 lines wide, 16 lines after VB start
    .VS_END     ( 9'h0FF    ), // 60.6 Hz according to MAME
    .VCNT_END   ( 9'h1FF    )
) u_fround_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( FR_v      ),
    .vrender    (           ),
    .vrender1   (           ),
    .H          ( FR_h      ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( FR_lhbl   ),
    .LVBL       ( FR_lvbl   ),
    .HS         ( FR_hs     ), // 16kHz
    .VS         ( FR_vs     )
);

jtframe_vtimer #(
    .VB_START   ( 9'hf7     ),
    .VB_END     ( 9'd7      ),
    .VCNT_END   ( 9'd271    ),
    .VS_START   ( 9'h106    ),
    .HS_START   ( 9'h1b0    ),
    .HB_START   ( 9'h189    ),
    .HJUMP      ( 1         ),
    .HB_END     ( 9'd9      ),
    .HINIT      ( 9'd255    )
)   u_karnov_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( KV_v      ),
    .vrender    (           ),
    .vrender1   (           ),
    .H          ( KV_h      ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( KV_lhbl   ),
    .LVBL       ( KV_lvbl   ),
    .HS         ( KV_hs     ),
    .VS         ( KV_vs     )
);

jtframe_vtimer #(
    .VB_START   ( 9'hf7     ),
    .VB_END     ( 9'h7      ),
    .VCNT_END   ( 9'd271    ),
    .VS_START   ( 9'h106    ),
    .HS_START   ( 9'h1b5    ),
    .HB_START   ( 9'h181    ),
    .HJUMP      ( 1         ),
    .HB_END     ( 9'd9      ),
    .HINIT      ( 9'd255    )
)   u_wwf_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( WF_v      ),
    .vrender    (           ),
    .vrender1   (           ),
    .H          ( WF_h      ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( WF_lhbl   ),
    .LVBL       ( WF_lvbl   ),
    .HS         ( WF_hs     ),
    .VS         ( WF_vs     )
);

jtframe_vtimer #(
    .V_START    ( 9'h0f8    ),
    .VCNT_END   ( 9'h1ff    ),
    .VB_START   ( 9'h1ef    ),
    .VB_END     ( 9'h10f    ),
    .VS_START   ( 9'h0f8    ),

    .HCNT_START ( 9'h080    ),
    .HCNT_END   ( 9'h1ff    ),
    .HS_START   ( 9'h0ad    ),
    .HB_START   ( 9'h089    ),
    .HB_END     ( 9'h109    )
)   u_wc_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( WC_v      ),
    .vrender    (           ),
    .vrender1   (           ),
    .H          ( WC_h      ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( WC_lhbl   ),
    .LVBL       ( WC_lvbl   ),
    .HS         ( WC_hs     ),
    .VS         ( WC_vs     )
);

endmodule