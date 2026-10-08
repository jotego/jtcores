// A simple OSD implementation. Can be hooked up between a cores
// VGA output and the physical VGA pins

module osd #(
	parameter [9:0] OSD_X_OFFSET = 10'd0,
	parameter [9:0] OSD_Y_OFFSET = 10'd0,
	parameter [5:0] OSD_COLOR    = `ifdef JTFRAME_OSDCOLOR `JTFRAME_OSDCOLOR `else 6'b101010 `endif ,
	parameter       OSD_DW       = 6
)(
	// OSDs pixel clock, should be synchronous to cores pixel clock to
	// avoid jitter.
	input        clk_sys,

	// SPI interface
	input        SPI_SCK,
	input        SPI_SS3,
	input        SPI_DI,

	input  [1:0] rotate, //[0] - rotate [1] - left or right

	// VGA signals coming from core
	input [OSD_DW-1:0] R_in,
	input [OSD_DW-1:0] G_in,
	input [OSD_DW-1:0] B_in,
	input        HSync,
	input        VSync,
	input        DE,

	// VGA signals going to video connector
	output reg [OSD_DW-1:0] R_out,
	output reg [OSD_DW-1:0] G_out,
	output reg [OSD_DW-1:0] B_out,

	output reg       HSync_out,
	output reg       VSync_out,
	output reg       DE_out,

	output reg	 osd_shown
);

`ifndef JTFRAME_OSDCOLOR
    `ifdef JTFRAME_RELEASE
        `define JTFRAME_OSDCOLOR (~6'b0)
    `else
        `define JTFRAME_OSDCOLOR (6'h3c)
    `endif
`endif

localparam [9:0] OSD_WIDTH   = 10'd256;
localparam [9:0] OSD_HEIGHT  = 10'd128;

// *********************************************************************************
// spi client
// *********************************************************************************

// this core supports only the display related OSD commands
// of the minimig
reg  osd_enable=1'b0;
wire osd_enable_sys;

(* ramstyle = "no_rw_check" *) reg  [7:0] osd_buffer[2047:0];  // the OSD buffer itself
always @(posedge clk_sys)
	osd_shown <= osd_enable_sys;

jtframe_sync u_sync_sys(
	.clk_in ( SPI_SCK        ),
	.clk_out( clk_sys 		 ),
	.raw	( osd_enable     ),
	.sync	( osd_enable_sys )
);


`ifdef SIMULATION
initial begin:clear_buffer
    integer cnt;
    for( cnt=0; cnt<2048; cnt=cnt+1 )
        osd_buffer[cnt] = 8'hAA;
end
`endif

// the OSD has its own SPI interface to the io controller
always@(posedge SPI_SCK, posedge SPI_SS3) begin: io_ctrl

	reg  [4:0] cnt;
	reg [10:0] bcnt;
	reg  [7:0] sbuf;
	reg  [7:0] cmd;
	if(SPI_SS3) begin
		cnt  <= 0;
		bcnt <= 0;
	end else begin
		sbuf <= {sbuf[6:0], SPI_DI};

		// 0:7 is command, rest payload
		if(cnt < 15) cnt <= cnt + 1'd1;
			else cnt <= 8;

		if(cnt == 7) begin
			cmd <= {sbuf[6:0], SPI_DI};

			// lower three command bits are line address
			bcnt <= {sbuf[1:0], SPI_DI, 8'h00};

			// command 0x40: OSDCMDENABLE, OSDCMDDISABLE
			if(sbuf[6:3] == 4'b0100) osd_enable <= SPI_DI;
		end

		// command 0x20: OSDCMDWRITE
		if((cmd[7:3] == 5'b00100) && (cnt == 15)) begin
			osd_buffer[bcnt] <= {sbuf[6:0], SPI_DI};
			bcnt <= bcnt + 1'd1;
		end
	end
end

// *********************************************************************************
// video timing and sync polarity anaylsis
// *********************************************************************************

// horizontal counter
reg  [9:0] h_cnt;
reg  [9:0] hs_low, hs_high;
reg        hs_pol;
reg  [9:0] dsp_width;

// vertical counter
reg  [9:0] v_cnt;
reg  [9:0] vs_low, vs_high;
reg        vs_pol;
reg  [9:0] dsp_height;

reg        doublescan;


reg ce_pix;
always @(negedge clk_sys) begin: horizontal_counter
	integer cnt;
	integer pixsz, pixcnt;
	reg hs;

	cnt <= cnt + 1;
	hs <= HSync;

	pixcnt <= pixcnt + 1;
	if(pixcnt == pixsz) pixcnt <= 0;
	ce_pix <= pixcnt==0;

	if(hs && ~HSync) begin
		cnt    <= 0;
		pixsz  <= (cnt >> 9) - 1;
		pixcnt <= 0;
		ce_pix <= 1;
	end
end

always @(posedge clk_sys) begin
	hs_pol     <= hs_high < hs_low;
	dsp_width  <= hs_pol ? hs_low : hs_high;
	vs_pol 	   <= vs_high < vs_low;
	dsp_height <= vs_pol ? vs_low : vs_high;
	doublescan <= dsp_height>350;
end

always @(posedge clk_sys) begin: sync
	reg hsD, hsD2;
	reg vsD, vsD2;

	if(ce_pix) begin
		// bring hsync into local clock domain
		hsD <= HSync;
		hsD2 <= hsD;

		// falling edge of HSync
		if(!hsD && hsD2) begin
			h_cnt <= 0;
			hs_high <= h_cnt;
		end

		// rising edge of HSync
		else if(hsD && !hsD2) begin
			h_cnt <= 0;
			hs_low <= h_cnt;
			v_cnt <= v_cnt + 1'd1;
		end else begin
			h_cnt <= h_cnt + 1'd1;
		end

		vsD <= VSync;
		vsD2 <= vsD;

		// falling edge of VSync
		if(!vsD && vsD2) begin
			v_cnt <= 0;
			vs_high <= v_cnt;
		end

		// rising edge of VSync
		else if(vsD && !vsD2) begin
			v_cnt <= 0;
			vs_low <= v_cnt;
		end
	end
end

// area in which OSD is being displayed
reg [9:0] h_osd_start;
reg [9:0] h_osd_end;
reg [9:0] v_osd_start;
reg [9:0] v_osd_end;

always @(posedge clk_sys) begin
	h_osd_start <= ((dsp_width - OSD_WIDTH)>> 1) + OSD_X_OFFSET;
	h_osd_end   <= h_osd_start + OSD_WIDTH;
	v_osd_start <= ((dsp_height- (OSD_HEIGHT<<doublescan))>> 1) + OSD_Y_OFFSET;
	v_osd_end   <= v_osd_start + (OSD_HEIGHT<<doublescan);
end

wire [9:0] osd_hcnt    = h_cnt - h_osd_start;
wire [9:0] osd_vcnt    = v_cnt - v_osd_start;
wire [9:0] osd_hcnt_next  = osd_hcnt + 10'd1;  // one pixel offset for osd pixel
wire [9:0] osd_hcnt_next2 = osd_hcnt + 10'd2;  // two pixel offset for osd byte address register
reg        osd_de;

reg [10:0] osd_buffer_addr;
wire [7:0] osd_byte = osd_buffer[osd_buffer_addr];
reg        osd_pixel;

`ifdef SIMULATION
`ifndef JTFRAME_OSD_NOLOGO
// Disable OSD background for simulation
`define JTFRAME_OSD_NOLOGO
`endif
`endif

`ifndef JTFRAME_OSD_NOLOGO
reg  [7:0] back_buffer[8*256];
wire [7:0] back_byte = back_buffer[osd_buffer_addr];
reg        back_pixel;
`else
wire	   back_pixel = 1'b1;
`endif

always @(posedge clk_sys) begin
	if (ce_pix) begin
		osd_buffer_addr <= rotate[0] ? {rotate[1] ? ~osd_hcnt_next2[7:5] : osd_hcnt_next2[7:5],
		                   rotate[1] ? (doublescan ?  osd_vcnt[7:0] :  {osd_vcnt[6:0], 1'b0}) :
		                               (doublescan ? ~osd_vcnt[7:0] : ~{osd_vcnt[6:0], 1'b0})} :
		                   // no rotation
		                               {doublescan ? osd_vcnt[7:5] : osd_vcnt[6:4], osd_hcnt_next2[7:0]};

		osd_pixel <= rotate[0]  ? osd_byte[rotate[1] ? ~osd_hcnt_next[4:2] : osd_hcnt_next[4:2]] :
		                          osd_byte[doublescan ? osd_vcnt[4:2] : osd_vcnt[3:1]];
		`ifndef JTFRAME_OSD_NOLOGO
		back_pixel <= rotate[0]  ?
                              back_byte[rotate[1] ? ~osd_hcnt_next[4:2] : osd_hcnt_next[4:2]] :
                              // no rotation:
                              back_byte[doublescan ? osd_vcnt[4:2] : osd_vcnt[3:1]];
		`endif

		`ifdef SIMULATE_OSD
		osd_de <=
		`else
		osd_de <= osd_enable_sys &&
		`endif
			(HSync != hs_pol) && ((h_cnt + 1'd1) >= h_osd_start) && ((h_cnt + 1'd1) < h_osd_end) &&
			(VSync != vs_pol) && (v_cnt >= v_osd_start) && (v_cnt < v_osd_end);

	end

	R_out <= !osd_de ? R_in : { {2{osd_pixel}}, OSD_COLOR[5:4]^{1'b0,back_pixel}, R_in[OSD_DW-1:4]};
	G_out <= !osd_de ? G_in : { {2{osd_pixel}}, OSD_COLOR[3:2]^{1'b0,back_pixel}, G_in[OSD_DW-1:4]};
	B_out <= !osd_de ? B_in : { {2{osd_pixel}}, OSD_COLOR[1:0]^{1'b0,back_pixel}, B_in[OSD_DW-1:4]};
	HSync_out <= HSync;
	VSync_out <= VSync;
	DE_out <= DE;
end

`ifndef JTFRAME_OSD_NOLOGO
initial begin
back_buffer = '{ 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'hC0, 8'hF0, 8'hF8, 8'hFC, 8'hFC, 8'hFC,
8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC,
8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hFC, 8'hF0, 8'hF0, 8'hF0, 8'hC0, 8'hC0, 8'hC0, 8'hC0,
8'hC0, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h80, 8'hC0, 8'hF0, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8,
8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hFC, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hF9,
8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8,
8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8,
8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8,
8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8,
8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hC8, 8'hC0,
8'hC0, 8'h80, 8'h80, 8'h80, 8'h80, 8'h80, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h80,
8'hE0, 8'hF8, 8'hFE, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'h3F, 8'h0F, 8'h07, 8'h01, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h01,
8'h01, 8'h01, 8'h01, 8'h05, 8'h07, 8'h07, 8'h37, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'hBF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F,
8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'h7F, 8'h3F,
8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F,
8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h3F, 8'h0F,
8'h03, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'hC0, 8'hF0, 8'hFC, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE,
8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE,
8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hFE, 8'hF0, 8'hF0, 8'hF0, 8'hC0, 8'hC0, 8'hC0, 8'hC0, 8'h40, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h80, 8'hC0, 8'hC0, 8'hF0, 8'hFC, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'h7F,
8'h1F, 8'h0F, 8'h03, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h80, 8'hE0, 8'hF8, 8'hFC, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'h7F, 8'h1F, 8'h07, 8'h01, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h3F, 8'h7F, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hF9, 8'hF8, 8'hF8, 8'hF8, 8'hF8,
8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hF8, 8'hFC, 8'hFC, 8'hFC,
8'hFC, 8'hFC, 8'hFE, 8'hFE, 8'hFE, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'h7F, 8'h3F, 8'h1F, 8'h07, 8'h01, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h80,
8'hE0, 8'hF8, 8'hFE, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'h3F, 8'h0F, 8'h03, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h01, 8'h03, 8'h03, 8'h07, 8'h0F, 8'h0F, 8'h1F, 8'h1F,
8'h3F, 8'h3F, 8'h7F, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'h7F, 8'h7F, 8'h3F,
8'h3F, 8'h1F, 8'h1F, 8'h0F, 8'h0F, 8'h07, 8'h03, 8'h03, 8'h01, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'hC0, 8'hF0, 8'hFC, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF, 8'hFF,
8'hFF, 8'h7F, 8'h1F, 8'h0F, 8'h03, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h01, 8'h01, 8'h03, 8'h03, 8'h03, 8'h07, 8'h07, 8'h07, 8'h0F, 8'h0F, 8'h0F, 8'h0F,
8'h0F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F,
8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F,
8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h0F, 8'h0F, 8'h0F, 8'h0F, 8'h0F, 8'h0F,
8'h07, 8'h07, 8'h07, 8'h07, 8'h03, 8'h03, 8'h03, 8'h01, 8'h01, 8'h01, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h01, 8'h01, 8'h01, 8'h01, 8'h01, 8'h07,
8'h07, 8'h07, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F,
8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h1F, 8'h07,
8'h01, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00 };
end
`endif
endmodule
