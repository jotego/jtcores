`timescale 1ns/1ps

module jtgng_vga(
	input				clk_gng,	// 6MHz
	input				clk_vga,	// 25MHz
	input				rst,
	input	[3:0]		red,
	input	[3:0]		green,
	input	[3:0]		blue,
	input				Hinit,
	input				LHBL,
	input				LVBL,
	output	[3:0]		vga_red,
	output	[3:0]		vga_green,
	output	[3:0]		vga_blue,
	output	reg			vga_hsync,
	output	reg			vga_vsync
);

reg [7:0] wr_addr, rd_addr;
reg sel;

`ifndef SIM_SYNCONLY
jtgng_vgabuf buf_rg (
	.address_a ( { sel, 1'b0, wr_addr} ),
	.address_b ( {~sel, 1'b0, rd_addr} ),
	.clock_a ( clk_gng ),
	.clock_b ( clk_vga ),
	.data_a ( {red,green} ),
	.data_b ( {red,green} ), // unused
	.wren_a ( 1'b1 ),
	.wren_b ( 1'b0 ),
	.q_b ( {vga_red, vga_green} )
	);

jtgng_vgabuf buf_b (
	.address_a ( { sel, 1'b1, wr_addr} ),
	.address_b ( {~sel, 1'b1, rd_addr} ),
	.clock_a ( clk_gng ),
	.clock_b ( clk_vga ),
	.data_a ( {4'b0, blue} ),
	.data_b ( {4'b0, blue} ), // unused
	.wren_a ( 1'b1 ),
	.wren_b ( 1'b0 ),
	.q_b ( vga_blue )
	);
`endif

always @(posedge clk_gng)
	if( rst ) begin
		wr_addr <= 8'd0;
		sel <= 1'b0;		
	end else 
	if( !LHBL ) begin
		wr_addr <= 8'd0;
		sel <= ~sel;
	end else
		wr_addr <= wr_addr + 1'b1;

reg lhbl, last_lhbl;

always @(posedge clk_vga) begin
	lhbl <= LHBL;
	last_lhbl <= lhbl;
end

reg [6:0] cnt;
reg [1:0] state;
reg finish,double;

localparam SYNC=2'd0, FRONT=2'd1, LINE=2'd2, BACK=2'd3;

always @(posedge clk_vga) begin
	if( rst ) begin
		rd_addr <= 8'd0;
		state <= SYNC;
		cnt <= 7'd96;
	end
	else 
	case( state )
		SYNC: begin
			rd_addr <= 8'd0;
			vga_hsync <= 1'b0;
			cnt <= cnt - 1'b1;
			if( !cnt ) begin
				state<=FRONT;
				cnt  <=7'd16;
			end
		end
		FRONT: begin
			rd_addr <= 8'd0;
			vga_hsync <= 1'b1;
			cnt <= cnt - 1'b1;
			if( !cnt ) begin
				state<=LINE;
				double<=1'b0;
				finish<=1'b0;
			end
		end
		LINE: begin
			if(finish) begin
				state <= BACK;
				cnt   <= 7'd48;
			end
			{finish,rd_addr,double}<={rd_addr,double}+1'b1;
		end
		BACK: begin			
			if( !cnt ) begin
				state<=SYNC;
				cnt <= 7'd96;
			end
			else cnt <= cnt - 1'b1;
		end
	endcase
end

endmodule // jtgng_vga