/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 12-01-2026 */
module jtframe_mister_cartsave (
    input             clk,
    input             OSD_STATUS,
    input      [63:0] img_size,
    input             img_mounted,
    input             img_readonly,
    input      [ 1:0] ram_save,
    input             ram_load,
    input             downloading, // ioctl_cart
    input 	   [ 7:0] sd_buff_addr,
    input 	   [ 7:0] sd_buff_dout,
    output reg [ 7:0] sd_buff_din,
    input 			  sd_buff_wr,
    input             sd_ack,
    output reg [31:0] sd_lba,
    output reg        sd_rd,
    output reg        sd_wr,
    output reg        bk_ena,
    output reg        sd_wait,
    // Core
    input             sav_change,
    input             sav_wait,
    input      [15:0] sav_din,
    output reg [15:0] sav_dout,
    output reg [15:0] sav_addr,
    output reg [ 1:0] sav_wr,
    output reg        sav_ack

);

reg  save_rd, save_wr;
reg  save_wait, bsy_l;
// reg [18:0] sav_addr;
wire bk_load, bk_save;
reg  bk_loading, bk_state;
reg  sav_pending;
reg  old_downloading, old_load, old_save, old_ack, sd_active;
wire save_busy = sav_wait;
wire bk_busy   = bk_state == 1;

always @(posedge clk) begin
	bsy_l <= save_busy;
	if(~save_busy & ~save_rd & ~save_wr) begin
		save_wait <= 0;
		if(save_wait)
	    	sd_buff_din <= sd_buff_addr[0]? sav_din[15:8] : sav_din[7:0];
	end

	if(~bk_busy) begin
		sav_addr  <= 16'hFF;
		save_wait <= 0;
	end
	else if(sd_ack & ~save_busy & (~save_wait)) begin
		if(~bk_loading && (sav_addr != {sd_lba[7:0], sd_buff_addr})) begin
			save_rd   <= 1;
			sav_addr  <= {sd_lba[7:0], sd_buff_addr};
			save_wait <= 1;
		end
		if(bk_loading && sd_buff_wr) begin
			save_wr   <= 1;
			sav_addr  <= {sd_lba[7:0], sd_buff_addr};
			save_wait <= 1;
			sav_wr    <= {~sd_buff_addr[0],sd_buff_addr[0]};
		end
	end
	if(~bk_busy | save_busy) {save_rd, save_wr} <= 0;
end

/////////////////////////  BRAM SAVE/LOAD  /////////////////////////////

initial sav_dout = 0;
always @* begin
    // sav_addr    = {sd_lba[7:0], sd_buff_addr[7:1],1'b0};
    // sav_wr      = wr_word ? 2'b11 : 2'b00;
    // sd_buff_din = sd_buff_addr[0]? sav_din[15:8] : sav_din[7:0];
	sd_wait     = save_wait;
    sav_ack     = save_wait; // save_rd | sav_wr;
    // if(sd_active && sd_buff_wr)
    	if(sd_buff_addr[0])
    	    sav_dout[15:8] = sd_buff_dout;
    	else
    	    sav_dout[ 7:0] = sd_buff_dout;
end

always @(posedge clk) begin
    if(~old_ack & sd_ack)
    	sd_active <= 1;
    else if(~sd_ack & old_ack)
    	sd_active <= 0;
end


initial begin
	old_downloading = 0;
	sav_pending     = 0;
	sav_dout        = 0;
	sav_ack         = 0;
	sd_active       = 0;
	sav_wr          = 0;
	old_load        = 0;
	old_save        = 0;
	old_ack         = 0;
 	bk_ena          = 0;
	bk_state        = 0;
	bk_loading      = 0;
	sd_wait         = 0;
	sd_buff_din     = 0;
	sd_rd           = 0;
	sd_wr           = 0;
	sd_lba          = 0;
	sd_buff_din =0;
end

assign bk_save = ram_save[1] | (sav_pending & OSD_STATUS & ram_save[0]);
assign bk_load = ram_load;

always @(posedge clk) begin
	old_downloading <= downloading;
	if(~old_downloading & downloading)
		bk_ena <= 0;

	//Save file always mounted in the end of downloading state.
	if(downloading && img_mounted && !img_readonly)
		bk_ena <= 1;

	if (bk_ena & sav_change & ~OSD_STATUS)
		sav_pending <= 1;
	else if (bk_state)
		sav_pending <= 0;
end

always @(posedge clk) begin
	old_load <= bk_load;
	old_save <= bk_save;
	old_ack  <= sd_ack;

	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;

	if(!bk_state) begin
		if(bk_ena & ((~old_load & bk_load) | (~old_save & bk_save))) begin
			bk_state <= 1;
			bk_loading <= bk_load;
			sd_lba <= 0;
			sd_rd <=  bk_load;
			sd_wr <= ~bk_load;
		end
		// if(old_downloading & ~downloading & |img_size & bk_ena) begin
			// bk_state <= 1;
			// bk_loading <= 1;
			// sd_lba <= 0;
			// sd_rd <= 1;
			// sd_wr <= 0;
		// end
	end else begin
		if(old_ack & ~sd_ack) begin
			if(&sd_lba[6:0]) begin
				bk_loading <= 0;
				bk_state <= 0;
			end else begin
				sd_lba <= sd_lba + 1'd1;
				sd_rd  <=  bk_loading;
				sd_wr  <= ~bk_loading;
			end
		end
	end
end

endmodule
