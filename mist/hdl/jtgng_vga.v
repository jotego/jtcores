`timescale 1ns/1ps

module jtgng_vga(
	input				clk_gng,	// 6MHz
	input				clk_vga,	// 25MHz
	input				rst,
	input	[3:0]		red,
	input	[3:0]		green,
	input	[3:0]		blue,
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

//`ifndef SIM_SYNCONLY
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

wire [3:0] nc;

jtgng_vgabuf buf_b (
	.address_a ( { sel, 1'b1, wr_addr} ),
	.address_b ( {~sel, 1'b1, rd_addr} ),
	.clock_a ( clk_gng ),
	.clock_b ( clk_vga ),
	.data_a ( {4'b0, blue} ),
	.data_b ( {4'b0, blue} ), // unused
	.wren_a ( 1'b1 ),
	.wren_b ( 1'b0 ),
	.q_b ( {nc,vga_blue} )
	);
//`endif

reg last_LHBL;

always @(posedge clk_gng)
	if( rst ) begin
		wr_addr <= 8'd0;
		sel <= 1'b0;		
	end else  begin
		last_LHBL <= LHBL;	
		if( !LHBL ) begin
			wr_addr <= 8'd0;
			if( last_LHBL!=LHBL ) sel <= ~sel;
		end else
			wr_addr <= wr_addr + 1'b1;
	end

reg lhbl, last_lhbl;
reg lvbl, last_lvbl;
reg vsync_req;
reg wait_hsync;

always @(posedge clk_vga) begin
	lhbl <= LHBL;
	last_lhbl <= lhbl;

	lvbl <= LVBL;
	last_lvbl <= lvbl;

	vsync_req <= !vga_vsync ? 1'b0 : vsync_req || (!lvbl && last_lvbl);
end

reg [6:0] cnt;
reg [1:0] state;
reg centre_done, finish,double;
reg vsync_cnt;

localparam SYNC=2'd0, FRONT=2'd1, LINE=2'd2, BACK=2'd3;

always @(posedge clk_vga) begin
	if( rst ) begin
		rd_addr <= 8'd0;
		state <= SYNC;
		cnt <= 7'd96;
		centre_done <= 1'b0;
		wait_hsync <= 1'b0;
		vsync_cnt  <= 1'b0;
		vga_vsync  <= 1'b1;
		vga_hsync  <= 1'b1;
	end
	else 
	case( state )
		SYNC: begin
			rd_addr <= 8'd0;
			vga_hsync <= 1'b0;
			if( vsync_req ) begin
				vga_vsync <= 1'b0;
				vsync_cnt <= 1'b0;		
			end			
			cnt <= cnt - 1'b1;
			if( wait_hsync && (lhbl && !last_lhbl) ||
			   !wait_hsync && !cnt ) begin
				state<=FRONT;
				cnt  <=7'd16;
				wait_hsync <= ~wait_hsync;
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
				cnt   <=7'd63;
				centre_done <= 1'b0;
			end
		end
		LINE: begin
			case( {finish, centre_done})
				2'b00:
					if(cnt) 
						cnt<=cnt-1'b1; // blank space on left
					else 
						{centre_done,rd_addr,double}<={rd_addr,double}+1'b1;
				2'b01: begin
					finish <= cnt==7'd60;
					cnt <= cnt+1'b1;
				end
				2'b11: begin
					state <= BACK;
					cnt   <= 7'd48;
				end
			endcase
		end				
		BACK: begin			
			if( !cnt ) begin
				state<=SYNC;
				cnt <= 7'd96;
				{vga_vsync, vsync_cnt} <= {vsync_cnt, 1'b1};
			end
			else cnt <= cnt - 1'b1;
		end
	endcase
end

endmodule // jtgng_vga