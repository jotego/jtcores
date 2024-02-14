//
// user_io.v
//
// user_io for the MiST board
// https://github.com/mist-devel
//
// Copyright (c) 2014 Till Harbaum <till@harbaum.org>
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

// parameter STRLEN and the actual length of conf_str have to match
 
module user_io (
	input [(8*STRLEN)-1:0] conf_str,
	output       [9:0]  conf_addr, // RAM address for config string, if STRLEN=0
	input        [7:0]  conf_chr,

	input               clk_sys, // clock for system-related messages (kbd, joy, etc...)
	input               clk_sd,  // clock for SD-card related messages

	input               SPI_CLK,
	input               SPI_SS_IO,
	output reg          SPI_MISO,
	input               SPI_MOSI,

	output reg   [31:0] joystick_0,
	output reg   [31:0] joystick_1,
	output reg   [31:0] joystick_2,
	output reg   [31:0] joystick_3,
	output reg   [31:0] joystick_4,
	output reg   [31:0] joystick_analog_0,
	output reg   [31:0] joystick_analog_1,
	output        [1:0] buttons,
	output        [1:0] switches,
	output              scandoubler_disable,
	output              ypbpr,
	output              no_csync,
	output reg   [63:0] status,
	output reg    [6:0] core_mod, // core variant, sent before the config string is requested
	// RTC data from IO controller
	// sec, min, hour, date, month, year, day (BCD)
	output reg   [63:0] rtc,

	// connection to sd card emulation
	input        [31:0] sd_lba,
	input [SD_IMAGES-1:0] sd_rd,
	input [SD_IMAGES-1:0] sd_wr,
	output reg          sd_ack = 0,  // ack any transfer
	output reg          sd_ack_conf = 0,
	output reg [SD_IMAGES-1:0] sd_ack_x = 0, // ack specific transfer
	input               sd_conf,
	input               sd_sdhc,
	output reg    [7:0] sd_dout, // valid on rising edge of sd_dout_strobe
	output reg          sd_dout_strobe = 0,
	input         [7:0] sd_din,
	output reg          sd_din_strobe = 0,
	output reg    [8:0] sd_buff_addr,

	output reg [SD_IMAGES-1:0] img_mounted, // rising edge if a new image is mounted
	output reg   [63:0] img_size,    // size of image in bytes

	// ps2 keyboard/mouse emulation
	output              ps2_kbd_clk,
	output              ps2_kbd_data,
	input               ps2_kbd_clk_i,
	input               ps2_kbd_data_i,
	output              ps2_mouse_clk,
	output              ps2_mouse_data,
	input               ps2_mouse_clk_i,
	input               ps2_mouse_data_i,

	// keyboard data
	output reg          key_pressed,  // 1-make (pressed), 0-break (released)
	output reg          key_extended, // extended code
	output reg    [7:0] key_code,     // key scan code
	output reg          key_strobe,   // key data valid

	input         [7:0] kbd_out_data,   // for Archie
	input               kbd_out_strobe,

	// mouse data
	output reg    [8:0] mouse_x,
	output reg    [8:0] mouse_y,
	output reg    [3:0] mouse_z,
	output reg    [7:0] mouse_flags,  // YOvfl, XOvfl, dy8, dx8, 1, mbtn, rbtn, lbtn
	output reg          mouse_strobe, // mouse data is valid on mouse_strobe
	output reg          mouse_idx,    // which mouse?

	// i2c bridge
	output reg          i2c_start,
	output reg          i2c_read,
	output reg    [6:0] i2c_addr,
	output reg    [7:0] i2c_subaddr,
	output reg    [7:0] i2c_dout,
	input         [7:0] i2c_din,
	input               i2c_ack,
	input               i2c_end,

	// serial com port
	input [7:0]         serial_data,
	input               serial_strobe
);

parameter STRLEN=0; // config string length
parameter PS2DIV=100; // master clock divider for psk2_kbd/mouse clk
parameter ROM_DIRECT_UPLOAD=0; // direct upload used for file uploads from the ARM
parameter SD_IMAGES=2; // number of block-access images (max. 4 supported in current firmware)
parameter PS2BIDIR=0; // bi-directional PS2 interface
parameter FEATURES=0; // requested features from the firmware
parameter ARCHIE=0;

`ifdef SIMULATION
       localparam W = 1;
`else
       localparam W = $clog2(SD_IMAGES); // this statement doesn't work on SynaptiCAD
`endif

reg [6:0]     sbuf;
reg [7:0]     cmd;
reg [2:0]     bit_cnt;    // counts bits 0-7 0-7 ...
reg [9:0]     byte_cnt;   // counts bytes
reg [7:0]     but_sw;
reg [2:0]     stick_idx;

assign buttons = but_sw[1:0];
assign switches = but_sw[3:2];
assign scandoubler_disable = but_sw[4];
assign ypbpr = but_sw[5];
assign no_csync = but_sw[6];

assign conf_addr = byte_cnt;

// bit 4 indicates ROM direct upload capability
wire [7:0] core_type = (ARCHIE == 1) ? 8'ha6 : (ROM_DIRECT_UPLOAD == 1) ? 8'hb4 : 8'ha4;

reg [W:0] drive_sel;
always begin
	integer i;
	drive_sel = 0;
	for(i = 0; i < SD_IMAGES; i = i + 1) if(sd_rd[i] | sd_wr[i]) drive_sel = i[W:0];
end

// command byte read by the io controller
wire [7:0] sd_cmd = { 4'h6, sd_conf, sd_sdhc, sd_wr[drive_sel], sd_rd[drive_sel] };

wire spi_sck = SPI_CLK;

// ---------------- PS2 ---------------------
reg ps2_clk;
always @(posedge clk_sys) begin
	integer cnt;
	cnt <= cnt + 1'd1;
	if(cnt == PS2DIV) begin
		ps2_clk <= ~ps2_clk;
		cnt <= 0;
	end
end

// keyboard
reg        ps2_kbd_tx_strobe;
wire [7:0] ps2_kbd_rx_byte ;
wire       ps2_kbd_rx_strobe;
wire       ps2_kbd_fifo_ok;

user_io_ps2 #(.PS2_BIDIR(PS2BIDIR), .PS2_FIFO_BITS(4)) ps2_kbd (
	.clk_sys       ( clk_sys ),
	.ps2_clk       ( ps2_clk ),
	.ps2_clk_i     ( ps2_kbd_clk_i ),
	.ps2_clk_o     ( ps2_kbd_clk ),
	.ps2_data_i    ( ps2_kbd_data_i ),
	.ps2_data_o    ( ps2_kbd_data ),
	.ps2_tx_strobe ( ps2_kbd_tx_strobe ), // from IO controller
	.ps2_tx_byte   ( spi_byte_in ),
	.ps2_rx_strobe ( ps2_kbd_rx_strobe ), // to IO controller
	.ps2_rx_byte   ( ps2_kbd_rx_byte ),
	.ps2_fifo_ready( ps2_kbd_fifo_ok )
);

// mouse
reg        ps2_mouse_tx_strobe;
wire [7:0] ps2_mouse_rx_byte ;
wire       ps2_mouse_rx_strobe;
wire       ps2_mouse_fifo_ok;

user_io_ps2 #(.PS2_BIDIR(PS2BIDIR), .PS2_FIFO_BITS(3)) ps2_mouse (
	.clk_sys       ( clk_sys ),
	.ps2_clk       ( ps2_clk ),
	.ps2_clk_i     ( ps2_mouse_clk_i ),
	.ps2_clk_o     ( ps2_mouse_clk ),
	.ps2_data_i    ( ps2_mouse_data_i ),
	.ps2_data_o    ( ps2_mouse_data ),
	.ps2_tx_strobe ( ps2_mouse_tx_strobe ), // from IO controller
	.ps2_tx_byte   ( spi_byte_in ),
	.ps2_rx_strobe ( ps2_mouse_rx_strobe ), // to IO controller
	.ps2_rx_byte   ( ps2_mouse_rx_byte ),
	.ps2_fifo_ready( ps2_mouse_fifo_ok )
);

// fifo to receive serial data from core to be forwarded to io controller

// 16 byte fifo to store serial bytes
localparam SERIAL_OUT_FIFO_BITS = 6;
reg [7:0] serial_out_fifo [(2**SERIAL_OUT_FIFO_BITS)-1:0];
reg [SERIAL_OUT_FIFO_BITS-1:0] serial_out_wptr;
reg [SERIAL_OUT_FIFO_BITS-1:0] serial_out_rptr;
 
wire serial_out_data_available = serial_out_wptr != serial_out_rptr;
wire [7:0] serial_out_byte = serial_out_fifo[serial_out_rptr] /* synthesis keep */;
wire [7:0] serial_out_status = { 7'b1000000, serial_out_data_available};

// status[0] is reset signal from io controller and is thus used to flush
// the fifo
always @(posedge serial_strobe or posedge status[0]) begin : serial_out
	if(status[0] == 1) begin
		serial_out_wptr <= 0;
	end else begin 
		serial_out_fifo[serial_out_wptr] <= serial_data;
		serial_out_wptr <= serial_out_wptr + 1'd1;
	end
end 

always@(negedge spi_sck or posedge status[0]) begin : serial_in
	if(status[0] == 1) begin
		serial_out_rptr <= 0;
	end else begin
		if((byte_cnt != 0) && (cmd == 8'h1b)) begin
			// read last bit -> advance read pointer
			if((bit_cnt == 7) && !byte_cnt[0] && serial_out_data_available)
				serial_out_rptr <= serial_out_rptr + 1'd1;
		end
	end
end


// SPI bit and byte counters
always@(posedge spi_sck or posedge SPI_SS_IO) begin : spi_counter
	if(SPI_SS_IO == 1) begin
		bit_cnt <= 0;
		byte_cnt <= 0;
	end else begin
		if((bit_cnt == 7)&&(~&byte_cnt)) 
			byte_cnt <= byte_cnt + 8'd1;

		bit_cnt <= bit_cnt + 1'd1;
	end
end

// SPI transmitter FPGA -> IO
reg [7:0] spi_byte_out;

always@(negedge spi_sck or posedge SPI_SS_IO) begin : spi_byteout
	if(SPI_SS_IO == 1) begin
	   SPI_MISO <= 1'bZ;
	end else begin
		SPI_MISO <= spi_byte_out[~bit_cnt];
	end
end

reg  [7:0] kbd_out_status = 0;
reg  [7:0] kbd_out_data_r = 0;

generate if (ARCHIE == 1) begin

reg        kbd_out_data_available = 0;

always@(negedge spi_sck or posedge SPI_SS_IO) begin : archie_kbd_out
	if(SPI_SS_IO == 1) begin
		kbd_out_data_r <= 0;
		kbd_out_status <= 0;
	end else begin
		kbd_out_status <= { 4'ha, 3'b000, kbd_out_data_available };
		kbd_out_data_r <= kbd_out_data;
	end
end
end
endgenerate

always@(posedge spi_sck or posedge SPI_SS_IO) begin : spi_transmitter
	reg [31:0] sd_lba_r;
	reg  [W:0] drive_sel_r;
	reg        ps2_kbd_rx_strobeD;
	reg        ps2_mouse_rx_strobeD;

	if(SPI_SS_IO == 1) begin
		spi_byte_out <= core_type;
	end else begin
		// read the command byte to choose the response
		if(bit_cnt == 7) begin
			if(!byte_cnt) cmd <= {sbuf, SPI_MOSI};

			spi_byte_out <= 0;
			case({(!byte_cnt) ? {sbuf, SPI_MOSI} : cmd})
			8'h04: if (ARCHIE == 1) begin
					if(byte_cnt == 0) spi_byte_out <= kbd_out_status;
					else              spi_byte_out <= kbd_out_data_r;
				end

			// PS2 keyboard command
			8'h0e: if (byte_cnt == 0) begin
					ps2_kbd_rx_strobeD <= ps2_kbd_rx_strobe;
					//echo the command code if there's a byte to send, indicating the core supports the command
					spi_byte_out <= (ps2_kbd_rx_strobe ^ ps2_kbd_rx_strobeD) ? 8'h0e : 8'h00;
				end else spi_byte_out <= ps2_kbd_rx_byte;

			// PS2 mouse command
			8'h0f: if (byte_cnt == 0) begin
					ps2_mouse_rx_strobeD <= ps2_mouse_rx_strobe;
					//echo the command code if there's a byte to send, indicating the core supports the command
					spi_byte_out <= (ps2_mouse_rx_strobe ^ ps2_mouse_rx_strobeD) ? 8'h0f : 8'h00;
				end else spi_byte_out <= ps2_mouse_rx_byte;

			// reading config string
			8'h14: if (STRLEN == 0) spi_byte_out <= conf_chr; else
			       if(byte_cnt < STRLEN) spi_byte_out <= conf_str[(STRLEN - byte_cnt - 1)<<3 +:8];

			// reading sd card status
			8'h16: if(byte_cnt == 0) begin
					spi_byte_out <= sd_cmd;
					sd_lba_r <= sd_lba;
					drive_sel_r <= drive_sel;
				end 
				else if(byte_cnt == 1) spi_byte_out <= drive_sel_r;
				else if(byte_cnt < 6) spi_byte_out <= sd_lba_r[(5-byte_cnt)<<3 +:8];

			// reading sd card write data
			8'h18: spi_byte_out <= sd_din;

			8'h1b:
				// send alternating flag byte and data
				if(byte_cnt[0]) spi_byte_out <= serial_out_status;
				else spi_byte_out <= serial_out_byte;

			// core features
			8'h80:
				if (byte_cnt == 0) spi_byte_out <= 8'h80;
				else spi_byte_out <= FEATURES[(4-byte_cnt)<<3 +:8];

			// i2c
			8'h31:
				if (byte_cnt == 0) spi_byte_out <= {6'd0, i2c_ack, i2c_end};
				else spi_byte_out <= i2c_din;

			endcase
		end
	end
end

// SPI receiver IO -> FPGA

reg       spi_receiver_strobe_r = 0;
reg       spi_transfer_end_r = 1;
reg [7:0] spi_byte_in;

// Read at spi_sck clock domain, assemble bytes for transferring to clk_sys
always@(posedge spi_sck or posedge SPI_SS_IO) begin : spi_receiver

	if(SPI_SS_IO == 1) begin
		spi_transfer_end_r <= 1;
	end else begin
		spi_transfer_end_r <= 0;

		if(bit_cnt != 7)
			sbuf[6:0] <= { sbuf[5:0], SPI_MOSI };

		// finished reading a byte, prepare to transfer to clk_sys
		if(bit_cnt == 7) begin
			spi_byte_in <= { sbuf, SPI_MOSI};
			spi_receiver_strobe_r <= ~spi_receiver_strobe_r;
		end
	end
end

// Process bytes from SPI at the clk_sys domain
always @(posedge clk_sys) begin : cmd_block

	reg       spi_receiver_strobe;
	reg       spi_transfer_end;
	reg       spi_receiver_strobeD;
	reg       spi_transfer_endD;
	reg [7:0] acmd;
	reg [3:0] abyte_cnt;   // counts bytes

	reg [7:0] mouse_flags_r;
	reg [7:0] mouse_x_r;
	reg [7:0] mouse_y_r;
	reg       mouse_fifo_ok;

	reg       kbd_fifo_ok;
	reg       key_pressed_r;
	reg       key_extended_r;

	//synchronize between SPI and sys clock domains
	spi_receiver_strobeD <= spi_receiver_strobe_r;
	spi_receiver_strobe <= spi_receiver_strobeD;
	spi_transfer_endD	<= spi_transfer_end_r;
	spi_transfer_end	<= spi_transfer_endD;

	key_strobe <= 0;
	mouse_strobe <= 0;
	ps2_kbd_tx_strobe <= 0;
	ps2_mouse_tx_strobe <= 0;
	i2c_start <= 0;

	if(ARCHIE == 1) begin
		if (kbd_out_strobe) kbd_out_data_available <= 1;
		key_pressed <= 0;
		key_extended <= 0;
		mouse_x <= 0;
		mouse_y <= 0;
		mouse_z <= 0;
		mouse_flags <= 0;
		mouse_idx <= 0;
	end

	if (spi_transfer_end) begin
		abyte_cnt <= 0;
		mouse_fifo_ok <= 0;
		kbd_fifo_ok <= 0;
	end else if (spi_receiver_strobeD ^ spi_receiver_strobe) begin

		if(~&abyte_cnt) 
			abyte_cnt <= abyte_cnt + 1'd1;

		if(abyte_cnt == 0) begin
			acmd <= spi_byte_in;
			if (spi_byte_in == 8'h70 || spi_byte_in == 8'h71)
				// accept the incoming mouse data only if there's place for the full packet
				mouse_fifo_ok <= ps2_mouse_fifo_ok;
			if (spi_byte_in == 8'h05)
				// accept the incoming keyboard data only if there's place for the full packet
				kbd_fifo_ok <= ps2_kbd_fifo_ok;
		end else begin
			if (ARCHIE == 1) begin
				if(acmd == 8'h04) kbd_out_data_available <= 0;
				if(acmd == 8'h05) begin
					key_strobe <= 1;
					key_code <= spi_byte_in;
				end
			end

			case(acmd)
				// buttons and switches
				8'h01: but_sw <= spi_byte_in;
				8'h60: if (abyte_cnt < 5) joystick_0[(abyte_cnt-1)<<3 +:8] <= spi_byte_in;
				8'h61: if (abyte_cnt < 5) joystick_1[(abyte_cnt-1)<<3 +:8] <= spi_byte_in;
				8'h62: if (abyte_cnt < 5) joystick_2[(abyte_cnt-1)<<3 +:8] <= spi_byte_in;
				8'h63: if (abyte_cnt < 5) joystick_3[(abyte_cnt-1)<<3 +:8] <= spi_byte_in;
				8'h64: if (abyte_cnt < 5) joystick_4[(abyte_cnt-1)<<3 +:8] <= spi_byte_in;
				8'h70,8'h71: if (ARCHIE == 0) begin
					// store incoming ps2 mouse bytes
					if (abyte_cnt < 4 && mouse_fifo_ok) begin
						ps2_mouse_tx_strobe <= 1;
					end

					if (abyte_cnt == 1) mouse_flags_r <= spi_byte_in;
					else if (abyte_cnt == 2) mouse_x_r <= spi_byte_in;
					else if (abyte_cnt == 3) mouse_y_r <= spi_byte_in;
					else if (abyte_cnt == 4) begin
						// flags: YOvfl, XOvfl, dy8, dx8, 1, mbtn, rbtn, lbtn
						mouse_flags <= mouse_flags_r;
						mouse_x <= { mouse_flags_r[4], mouse_x_r };
						mouse_y <= { mouse_flags_r[5], mouse_y_r };
						mouse_z <= spi_byte_in[3:0];
						mouse_idx <= acmd[0];
						mouse_strobe <= 1;
					end
				end
				8'h05: if (ARCHIE == 0) begin
					// store incoming ps2 keyboard bytes
					if (kbd_fifo_ok) ps2_kbd_tx_strobe <= 1;
					if (abyte_cnt == 1) begin
						key_extended_r <= 0;
						key_pressed_r <= 1;
					end
					if (spi_byte_in == 8'he0) key_extended_r <= 1'b1;
					else if (spi_byte_in == 8'hf0) key_pressed_r <= 1'b0;
					else begin
						key_extended <= key_extended_r && abyte_cnt != 1;
						key_pressed <= key_pressed_r || abyte_cnt == 1;
						key_code <= spi_byte_in;
						key_strobe <= 1'b1;
					end
				end

				// joystick analog
				8'h1a: begin
					// first byte is joystick index
					if(abyte_cnt == 1)
						stick_idx <= spi_byte_in[2:0];
					else if(abyte_cnt == 2) begin
						// second byte is x axis
						if(stick_idx == 0)
							joystick_analog_0[15:8] <= spi_byte_in;
						else if(stick_idx == 1)
							joystick_analog_1[15:8] <= spi_byte_in;
					end else if(abyte_cnt == 3) begin
						// third byte is y axis
						if(stick_idx == 0)
							joystick_analog_0[7:0] <= spi_byte_in;
						else if(stick_idx == 1)
							joystick_analog_1[7:0] <= spi_byte_in;
					end else if(abyte_cnt == 4) begin
						// fourth byte is 2nd x axis
						if(stick_idx == 0)
							joystick_analog_0[31:24] <= spi_byte_in;
						else if(stick_idx == 1)
							joystick_analog_1[31:24] <= spi_byte_in;
					end else if(abyte_cnt == 5) begin
						// fifth byte is 2nd y axis
						if(stick_idx == 0)
							joystick_analog_0[23:16] <= spi_byte_in;
						else if(stick_idx == 1)
							joystick_analog_1[23:16] <= spi_byte_in;
					end
				end

				8'h15: status <= spi_byte_in;

				// status, 64bit version
				8'h1e: if(abyte_cnt<9) status[(abyte_cnt-1)<<3 +:8] <= spi_byte_in;

				// core variant
				8'h21: core_mod <= spi_byte_in[6:0];

				// RTC
				8'h22: if(abyte_cnt<9) rtc[(abyte_cnt-1)<<3 +:8] <= spi_byte_in;

				// I2C bridge
				8'h30: if(abyte_cnt == 1) {i2c_addr, i2c_read} <= spi_byte_in;
				       else if (abyte_cnt == 2) i2c_subaddr <= spi_byte_in;
				       else if (abyte_cnt == 3) begin i2c_dout <= spi_byte_in; i2c_start <= 1; end

			endcase
		end
	end
end


// Process SD-card related bytes from SPI at the clk_sd domain
always @(posedge clk_sd) begin : sd_block

	reg       spi_receiver_strobe;
	reg       spi_transfer_end;
	reg       spi_receiver_strobeD;
	reg       spi_transfer_endD;
	reg [SD_IMAGES-1:0] sd_wrD;
	reg [7:0] acmd;
	reg [7:0] abyte_cnt;   // counts bytes

	//synchronize between SPI and sd clock domains
	spi_receiver_strobeD <= spi_receiver_strobe_r;
	spi_receiver_strobe <= spi_receiver_strobeD;
	spi_transfer_endD	<= spi_transfer_end_r;
	spi_transfer_end	<= spi_transfer_endD;

	if(sd_dout_strobe) begin
		sd_dout_strobe<= 0;
		if(~&sd_buff_addr) sd_buff_addr <= sd_buff_addr + 1'b1;
	end

	sd_din_strobe<= 0;
	sd_wrD <= sd_wr;
	// fetch the first byte immediately after the write command seen
	if (|(~sd_wrD & sd_wr)) begin
		sd_buff_addr <= 0;
		sd_din_strobe <= 1;
	end

	img_mounted <= 0;

	if (spi_transfer_end) begin
		abyte_cnt <= 8'd0;
		sd_ack <= 1'b0;
		sd_ack_conf <= 1'b0;
		sd_buff_addr <= 0;
		if (acmd == 8'h17 || acmd == 8'h18) sd_ack_x <= 0;
	end else if (spi_receiver_strobeD ^ spi_receiver_strobe) begin

		if(~&abyte_cnt) 
			abyte_cnt <= abyte_cnt + 8'd1;

		if(abyte_cnt == 0) begin
			acmd <= spi_byte_in;

			if(spi_byte_in == 8'h18) begin
				sd_din_strobe <= 1'b1;
				if(~&sd_buff_addr) sd_buff_addr <= sd_buff_addr + 1'b1;
			end

			if(spi_byte_in == 8'h19)
				sd_ack_conf <= 1'b1;
			if((spi_byte_in == 8'h17) || (spi_byte_in == 8'h18))
				sd_ack <= 1'b1;

		end else begin
			case(acmd)

				// send sector IO -> FPGA
				8'h17,
				// send SD config IO -> FPGA
				8'h19: begin
					// flag that download begins
					sd_dout_strobe <= 1'b1;
					sd_dout <= spi_byte_in;
				end

				// send sector FPGA -> IO
				8'h18: begin
					if(~&sd_buff_addr) begin
						sd_din_strobe <= 1'b1;
						sd_buff_addr <= sd_buff_addr + 1'b1;
					end
				end

				8'h1c: img_mounted[spi_byte_in[W:0]] <= 1;

				// send image info
				8'h1d: if(abyte_cnt<9) img_size[(abyte_cnt-1)<<3 +:8] <= spi_byte_in;
				// data transfer ack
				8'h23: sd_ack_x <= 1'b1 << spi_byte_in;

			endcase
		end
	end
end

endmodule

module user_io_ps2 (
	input       clk_sys,
	input       ps2_clk,
	input       ps2_clk_i,
	output      ps2_clk_o,
	input       ps2_data_i,
	output  reg ps2_data_o = 1,
	input       ps2_tx_strobe, // from IO controller
	input [7:0] ps2_tx_byte,
	output  reg ps2_rx_strobe = 0,  // to IO controller
	output  reg [7:0] ps2_rx_byte = 0,
	output      ps2_fifo_ready
);

parameter PS2_FIFO_BITS = 4;
parameter PS2_BIDIR = 0;

reg  [7:0] ps2_fifo [(2**PS2_FIFO_BITS)-1:0];
reg  [PS2_FIFO_BITS-1:0] ps2_wptr;
reg  [PS2_FIFO_BITS-1:0] ps2_rptr;
wire [PS2_FIFO_BITS:0] ps2_used = ps2_wptr >= ps2_rptr ?
                                        ps2_wptr - ps2_rptr :
                                        ps2_wptr - ps2_rptr + (2'd2**PS2_FIFO_BITS);
wire [PS2_FIFO_BITS:0] ps2_free = (2'd2**PS2_FIFO_BITS) - ps2_used;

assign ps2_fifo_ready = ps2_free[PS2_FIFO_BITS:2] != 0; // ps2_free > 3

// ps2 transmitter state machine
reg  [3:0] ps2_tx_state;
reg  [7:0] ps2_tx_shift_reg;
reg        ps2_parity;

// ps2 receiver state machine
reg  [3:0] ps2_rx_state = 0;
reg  [1:0] ps2_rx_start = 0;

assign     ps2_clk_o = ps2_clk || (ps2_tx_state == 0 && ps2_rx_state == 0);

always@(posedge clk_sys) begin : ps2_fifo_wr
	if (ps2_tx_strobe) begin
		ps2_fifo[ps2_wptr] <= ps2_tx_byte;
		ps2_wptr <= ps2_wptr + 1'd1;
	end
end

// ps2 transmitter/receiver
// Takes a byte from the FIFO and sends it in a ps2 compliant serial format.
// Sends a command to the IO controller if bidirectional mode is enabled.
always@(posedge clk_sys) begin : ps2_txrx
	reg ps2_clkD;
	reg ps2_clk_iD, ps2_dat_iD;
	reg ps2_r_inc;

	ps2_clkD <= ps2_clk;
	if (~ps2_clkD & ps2_clk) begin
		ps2_r_inc <= 1'b0;

		if(ps2_r_inc)
			ps2_rptr <= ps2_rptr + 1'd1;

		// transmitter is idle?
		if(ps2_tx_state == 0) begin
			ps2_data_o <= 1;
			// data in fifo present?
			if(ps2_wptr != ps2_rptr && (ps2_clk_i | PS2_BIDIR == 0)) begin
				// load tx register from fifo
				ps2_tx_shift_reg <= ps2_fifo[ps2_rptr];
				ps2_r_inc <= 1'b1;

				// reset parity
				ps2_parity <= 1'b1;

				// start transmitter
				ps2_tx_state <= 4'd1;

				// put start bit on data line
				ps2_data_o <= 1'b0; // start bit is 0
			end
		end else begin

			// transmission of 8 data bits
			if((ps2_tx_state >= 1)&&(ps2_tx_state < 9)) begin
				ps2_data_o <= ps2_tx_shift_reg[0]; // data bits
				ps2_tx_shift_reg[6:0] <= ps2_tx_shift_reg[7:1]; // shift down
				if(ps2_tx_shift_reg[0]) 
					ps2_parity <= !ps2_parity;
			end

			// transmission of parity
			if(ps2_tx_state == 9)
				ps2_data_o <= ps2_parity;

			// transmission of stop bit
			if(ps2_tx_state == 10)
				ps2_data_o <= 1'b1; // stop bit is 1

			// advance state machine
			if(ps2_tx_state == 11)
				ps2_tx_state <= 4'd0;
			else
				ps2_tx_state <= ps2_tx_state + 4'd1;
		end
	end

	if (PS2_BIDIR == 1) begin

		ps2_clk_iD <= ps2_clk_i;
		ps2_dat_iD <= ps2_data_i;

		// receive command
		case (ps2_rx_start)
		2'd0:
			// first: host pulls down the clock line
			if (ps2_clk_iD & ~ps2_clk_i) ps2_rx_start <= 1;
		2'd1:
			// second: host pulls down the data line, while releasing the clock
			if (ps2_dat_iD && !ps2_data_i) ps2_rx_start <= 2'd2;
			// if it releases the clock without pulling down the data line: goto 0
			else if (ps2_clk_i) ps2_rx_start <= 0;
		2'd2:
			if (ps2_clkD && ~ps2_clk) begin
				ps2_rx_state <= 4'd1;
				ps2_rx_start <= 0;
			end
		default: ;
		endcase

		// host data is valid after the rising edge of the clock
		if(ps2_rx_state != 0 && ~ps2_clkD && ps2_clk) begin
			ps2_rx_state <= ps2_rx_state + 1'd1;
			if (ps2_rx_state == 9) ;// parity
			else if (ps2_rx_state == 10) begin
				ps2_data_o <= 0; // ack the received byte
			end else if (ps2_rx_state == 11) begin
				ps2_rx_state <= 0;
				ps2_rx_strobe <= ~ps2_rx_strobe;
			end else begin
				ps2_rx_byte <= {ps2_data_i, ps2_rx_byte[7:1]};
			end
		end
	end else begin
		ps2_rx_byte <= 0;
		ps2_rx_strobe <= 0;
	end
end

endmodule
