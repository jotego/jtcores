//
// data_io.v
//
// data_io for the MiST board
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
///////////////////////////////////////////////////////////////////////

module data_io
(
	input             clk_sys,
	input             SPI_SCK,
	input             SPI_SS2,
	input             SPI_SS4,
	input             SPI_DI,
	output            SPI_DO,
`ifdef DEMISTIFY	
	input             SPI_DO_IN,
`endif
	input             QCSn,
	input             QSCK,
	input       [3:0] QDAT,

	input             clkref_n, // assert ioctl_wr one cycle after clkref stobe (negative active)

	// ARM -> FPGA download
	output reg        ioctl_download = 0, // signal indicating an active download
	output reg        ioctl_upload = 0,   // signal indicating an active upload
	output reg  [7:0] ioctl_index,        // menu index used to upload the file ([7:6] - extension index, [5:0] - menu index)
	                                      // Note: this is also set for user_io mounts.
	                                      // Valid when ioctl_download = 1 or when img_mounted strobe is active in user_io.
	output reg        ioctl_wr,           // strobe indicating ioctl_dout valid
	output reg [26:0] ioctl_addr,
	output reg  [7:0] ioctl_dout,
	input       [7:0] ioctl_din,
	output reg [23:0] ioctl_fileext,      // file extension
	output reg [31:0] ioctl_filesize,     // file size

	// IDE interface
	input             hdd_clk,
	input             hdd_cmd_req,
	input             hdd_cdda_req,
	input             hdd_dat_req,
	output            hdd_cdda_wr,
	output            hdd_status_wr,
	output      [2:0] hdd_addr,
	output            hdd_wr,

	output     [15:0] hdd_data_out,
	input      [15:0] hdd_data_in,
	output            hdd_data_rd,
	output            hdd_data_wr,

	// IDE config
	output      [1:0] hdd0_ena,
	output      [1:0] hdd1_ena
);

parameter START_ADDR = 27'd0;
parameter ROM_DIRECT_UPLOAD = 0;
parameter USE_QSPI = 0;
parameter ENABLE_IDE = 0;

///////////////////////////////   DOWNLOADING   ///////////////////////////////

reg  [6:0] sbuf;
reg  [7:0] data_w;
reg  [7:0] data_w2  = 0;
reg  [7:0] data_w3  = 0;
reg  [3:0] cnt;
reg  [7:0] cmd;
reg  [6:0] bytecnt;

reg        rclk   = 0;
reg        rclk2  = 0;
reg        rclk3  = 0;
reg        addr_reset = 0;
reg        downloading_reg = 0;
reg        uploading_reg = 0;
reg        reg_do;

localparam DIO_FILE_TX       = 8'h53;
localparam DIO_FILE_TX_DAT   = 8'h54;
localparam DIO_FILE_INDEX    = 8'h55;
localparam DIO_FILE_INFO     = 8'h56;
localparam DIO_FILE_RX       = 8'h57;
localparam DIO_FILE_RX_DAT   = 8'h58;

localparam QSPI_READ         = 8'h40;
localparam QSPI_WRITE        = 8'h41;

localparam CMD_IDE_REGS_RD   = 8'h80;
localparam CMD_IDE_REGS_WR   = 8'h90;
localparam CMD_IDE_DATA_WR   = 8'hA0;
localparam CMD_IDE_DATA_RD   = 8'hB0;
localparam CMD_IDE_CDDA_RD   = 8'hC0;
localparam CMD_IDE_CDDA_WR   = 8'hD0;
localparam CMD_IDE_STATUS_WR = 8'hF0;
localparam CMD_IDE_CFG_WR    = 8'hFA;

assign SPI_DO = reg_do;

// data_io has its own SPI interface to the io controller
wire [7:0] cmdcode = { 4'h0, hdd_dat_req, hdd_cmd_req, 2'b00 };

always@(negedge SPI_SCK or posedge SPI_SS2) begin : SPI_TRANSMITTER
	reg [7:0] dout_r;

	if(SPI_SS2) begin
		reg_do <= 1'bZ;
	end else begin
		if (cnt == 0) dout_r <= cmdcode;
		if (cnt == 15) begin
			case(cmd)
				CMD_IDE_REGS_RD,
				CMD_IDE_DATA_RD:
					dout_r <= bytecnt[0] ? hdd_data_in[7:0] : hdd_data_in[15:8];

				CMD_IDE_CDDA_RD:
					dout_r <= {7'd0, hdd_cdda_req};

				DIO_FILE_RX_DAT:
					dout_r <= ioctl_din;

				default:
					dout_r <= 0;

			endcase
		end
		reg_do <= dout_r[~cnt[2:0]];
	end
end


always@(posedge SPI_SCK, posedge SPI_SS2) begin : SPI_RECEIVER
	if(SPI_SS2) begin
		bytecnt <= 0;
		cnt <= 0;
	end	else begin
		// don't shift in last bit. It is evaluated directly
		// when writing to ram
		if(cnt != 15) sbuf <= { sbuf[5:0], SPI_DI};

		// count 0-7 8-15 8-15 ...
		if(cnt != 15) cnt <= cnt + 1'd1;
			else cnt <= 8;

		// finished command byte
		if(cnt == 7) cmd <= {sbuf, SPI_DI};

		if(cnt == 15) begin
			if (~&bytecnt) bytecnt <= bytecnt + 1'd1;
			else bytecnt[0] <= ~bytecnt[0];

			case (cmd)
			// prepare/end transmission
			DIO_FILE_TX: begin
				// prepare
				if(SPI_DI) begin
					addr_reset <= ~addr_reset;
					downloading_reg <= 1;
				end else begin
					downloading_reg <= 0;
				end
			end

			DIO_FILE_RX: begin
				// prepare
				if(SPI_DI) begin
					addr_reset <= ~addr_reset;
					uploading_reg <= 1;
				end else begin
					uploading_reg <= 0;
				end
			end

			// command 0x57: DIO_FILE_RX_DAT
			// command 0x54: DIO_FILE_TX_DAT
			DIO_FILE_RX_DAT,
			DIO_FILE_TX_DAT: begin
				data_w <= {sbuf, SPI_DI};
				rclk <= ~rclk;
			end

			// expose file (menu) index
			DIO_FILE_INDEX: ioctl_index <= {sbuf, SPI_DI};

			// receiving FAT directory entry (mist-firmware/fat.h - DIRENTRY)
			DIO_FILE_INFO: begin
				case (bytecnt)
					8'h08: ioctl_fileext[23:16]  <= {sbuf, SPI_DI};
					8'h09: ioctl_fileext[15: 8]  <= {sbuf, SPI_DI};
					8'h0A: ioctl_fileext[ 7: 0]  <= {sbuf, SPI_DI};
					8'h1C: ioctl_filesize[ 7: 0] <= {sbuf, SPI_DI};
					8'h1D: ioctl_filesize[15: 8] <= {sbuf, SPI_DI};
					8'h1E: ioctl_filesize[23:16] <= {sbuf, SPI_DI};
					8'h1F: ioctl_filesize[31:24] <= {sbuf, SPI_DI};
				endcase
			end
			endcase
		end
	end
end

// direct SD Card->FPGA transfer
generate if (ROM_DIRECT_UPLOAD || ENABLE_IDE) begin

always@(posedge SPI_SCK, posedge SPI_SS4) begin : SPI_DIRECT_RECEIVER
	reg  [6:0] sbuf2;
	reg  [2:0] cnt2;
	reg  [9:0] bytecnt;

	if(SPI_SS4) begin
		cnt2 <= 0;
		bytecnt <= 0;
	end else begin
		// don't shift in last bit. It is evaluated directly
		// when writing to ram
		if(cnt2 != 7)
`ifdef DEMISTIFY		
			sbuf2 <= { sbuf2[5:0], SPI_DO_IN };
`else
			// sbuf2 <= { sbuf2[5:0], SPI_DO };
`endif
		cnt2 <= cnt2 + 1'd1;

		// received a byte
		if(cnt2 == 7) begin
			bytecnt <= bytecnt + 1'd1;
			// read 514 byte/sector (512 + 2 CRC)
			if (bytecnt == 513) bytecnt <= 0;
			// don't send the CRC bytes
			if (~bytecnt[9]) begin
				data_w2 <= {sbuf2, SPI_DO_IN};
				rclk2 <= ~rclk2;
			end
		end
	end
end

end
endgenerate

// QSPI receiver
generate if (USE_QSPI) begin

always@(negedge QSCK, posedge QCSn) begin : QSPI_RECEIVER
	reg nibble_lo;
	reg cmd_got;
	reg cmd_write;

	if (QCSn) begin
		cmd_got <= 0;
		cmd_write <= 0;
		nibble_lo <= 0;
	end else begin
		nibble_lo <= ~nibble_lo;
		if (nibble_lo) begin
			data_w3[3:0] <= QDAT;
			if (!cmd_got) begin
				cmd_got <= 1;
				if ({data_w3[7:4], QDAT} == QSPI_WRITE) cmd_write <= 1;
			end else begin
				if (cmd_write) rclk3 <= ~rclk3;
			end
		end else
			data_w3[7:4] <= QDAT;
	end
end
end
endgenerate

always@(posedge clk_sys) begin : DATA_OUT
	// synchronisers
	reg rclkD, rclkD2;
	reg rclk2D, rclk2D2;
	reg rclk3D, rclk3D2;
	reg addr_resetD, addr_resetD2;

	reg wr_int, wr_int_direct, wr_int_qspi, rd_int;
	reg [26:0] addr;
	reg [31:0] filepos;

	// bring flags from spi clock domain into core clock domain
	{ rclkD, rclkD2 } <= { rclk, rclkD };
	{ rclk2D ,rclk2D2 } <= { rclk2, rclk2D };
	{ rclk3D ,rclk3D2 } <= { rclk3, rclk3D };
	{ addr_resetD, addr_resetD2 } <= { addr_reset, addr_resetD };

	ioctl_wr <= 0;

	if (!downloading_reg) begin
		ioctl_download <= 0;
		wr_int <= 0;
		wr_int_direct <= 0;
	end

	if (!uploading_reg) begin
		ioctl_upload <= 0;
		rd_int <= 0;
	end

	if (~clkref_n) begin
		rd_int <= 0;
		wr_int <= 0;
		wr_int_direct <= 0;
		wr_int_qspi <= 0;
		if (wr_int || wr_int_direct || wr_int_qspi) begin
			ioctl_dout <= wr_int ? data_w : wr_int_direct ? data_w2 : data_w3;
			ioctl_wr <= 1;
			addr <= addr + 1'd1;
			ioctl_addr <= addr;
		end
		if (rd_int) begin
			ioctl_addr <= ioctl_addr + 1'd1;
		end
	end

	// detect transfer start from the SPI receiver
	if(addr_resetD ^ addr_resetD2) begin
		addr <= START_ADDR;
		ioctl_addr <= START_ADDR;
		filepos <= 0;
		ioctl_download <= downloading_reg;
		ioctl_upload <= uploading_reg;
	end

	// detect new byte from the SPI receiver
	if (rclkD ^ rclkD2) begin
		wr_int <= downloading_reg;
		rd_int <= uploading_reg;
	end
	// direct transfer receiver
	if (rclk2D ^ rclk2D2 && filepos != ioctl_filesize && downloading_reg) begin
		filepos <= filepos + 1'd1;
		wr_int_direct <= 1;
	end
	// QSPI transfer receiver
	if (rclk3D ^ rclk3D2) begin
		wr_int_qspi <= downloading_reg;
	end

end

// IDE handling
generate if (ENABLE_IDE) begin

reg  [1:0] int_hdd0_ena;
reg  [1:0] int_hdd1_ena;
reg        int_hdd_cdda_wr;
reg        int_hdd_status_wr;
reg  [2:0] int_hdd_addr = 0;
reg        int_hdd_wr;
reg [15:0] int_hdd_data_out;
reg        int_hdd_data_rd;
reg        int_hdd_data_wr;

assign hdd0_ena = int_hdd0_ena;
assign hdd1_ena = int_hdd1_ena;
assign hdd_cdda_wr = int_hdd_cdda_wr;
assign hdd_status_wr = int_hdd_status_wr;
assign hdd_addr = int_hdd_addr;
assign hdd_wr = int_hdd_wr;
assign hdd_data_out = int_hdd_data_out;
assign hdd_data_rd = int_hdd_data_rd;
assign hdd_data_wr = int_hdd_data_wr;

reg        rst0  = 1;
reg        rst2  = 1;
reg        rclk_ide_stat = 0;
reg        rclk_ide_regs_rd = 0;
reg        rclk_ide_regs_wr = 0;
reg        rclk_ide_wr = 0;
reg        rclk_ide_rd = 0;
reg        rclk_cdda_wr = 0;
reg  [7:0] data_ide;

always@(posedge SPI_SCK, posedge SPI_SS2) begin : SPI_RECEIVER_IDE
	if(SPI_SS2) begin
		rst0 <= 1;
	end	else begin
		rst0 <= 0;

		if(cnt == 15) begin

			case (cmd)
			//IDE commands
			CMD_IDE_CFG_WR:
				if (bytecnt == 0) begin
					int_hdd0_ena <= {sbuf[0], SPI_DI};
					int_hdd1_ena <= sbuf[2:1];
				end

			CMD_IDE_STATUS_WR:
				if (bytecnt == 0) begin
					data_ide <= {sbuf, SPI_DI};
					rclk_ide_stat <= ~rclk_ide_stat;
				end

			CMD_IDE_REGS_WR:
				if (bytecnt >= 8 && bytecnt <= 18 && !bytecnt[0]) begin
					data_ide <= {sbuf, SPI_DI};
					rclk_ide_regs_wr <= ~rclk_ide_regs_wr;
				end

			CMD_IDE_REGS_RD:
				if (bytecnt > 5 && !bytecnt[0]) begin
					rclk_ide_regs_rd <= ~rclk_ide_regs_rd;
				end

			CMD_IDE_DATA_WR:
				if (bytecnt > 4) begin
					data_ide <= {sbuf, SPI_DI};
					rclk_ide_wr <= ~rclk_ide_wr;
				end

			CMD_IDE_CDDA_WR:
				if (bytecnt > 4) begin
					data_ide <= {sbuf, SPI_DI};
					rclk_cdda_wr <= ~rclk_cdda_wr;
				end

			CMD_IDE_DATA_RD:
				if (bytecnt > 3) rclk_ide_rd <= ~rclk_ide_rd;

			endcase
		end
	end
end

always@(posedge SPI_SCK, posedge SPI_SS4) begin : SPI_DIRECT_RECEIVER_IDE
	if(SPI_SS4) begin
		rst2 <= 1;
	end else begin
		rst2 <= 0;
	end
end

always@(posedge hdd_clk) begin : IDE_OUT
	reg loword;

	// synchronisers
	reg rclk2D, rclk2D2;
	reg rclk_ide_statD, rclk_ide_statD2;
	reg rclk_cdda_wrD, rclk_cdda_wrD2;
	reg rclk_ide_wrD, rclk_ide_wrD2;
	reg rclk_ide_rdD, rclk_ide_rdD2;
	reg rclk_ide_regs_wrD, rclk_ide_regs_wrD2;
	reg rclk_ide_regs_rdD, rclk_ide_regs_rdD2;
	reg rst0D, rst0D2;
	reg rst2D, rst2D2;

	// bring flags from spi clock domain into core clock domain
	{ rclk2D ,rclk2D2 } <= { rclk2, rclk2D };
	{ rclk_ide_statD, rclk_ide_statD2 } <= { rclk_ide_stat, rclk_ide_statD };
	{ rclk_ide_rdD, rclk_ide_rdD2 } <= { rclk_ide_rd, rclk_ide_rdD };
	{ rclk_ide_wrD, rclk_ide_wrD2 } <= { rclk_ide_wr, rclk_ide_wrD };
	{ rclk_cdda_wrD, rclk_cdda_wrD2 } <= { rclk_cdda_wr, rclk_cdda_wrD };
	{ rclk_ide_regs_rdD, rclk_ide_regs_rdD2 } <= { rclk_ide_regs_rd, rclk_ide_regs_rdD };
	{ rclk_ide_regs_wrD, rclk_ide_regs_wrD2 } <= { rclk_ide_regs_wr, rclk_ide_regs_wrD };
	{ rst0D, rst0D2 } <= { rst0, rst0D };
	{ rst2D, rst2D2 } <= { rst2, rst2D };

	// IDE receiver
	int_hdd_wr <= 0;
	int_hdd_status_wr <= 0;
	int_hdd_data_wr <= 0;
	int_hdd_data_rd <= 0;
	int_hdd_cdda_wr <= 0;

	if (rst0D2) int_hdd_addr <= 0;
	if (rst0D2 && rst2D2) loword <= 0;

	if (rclk_ide_statD ^ rclk_ide_statD2) begin
		int_hdd_status_wr <= 1;
		int_hdd_data_out <= {8'h00, data_ide};
	end
	if (rclk_ide_rdD ^ rclk_ide_rdD2) begin
		loword <= ~loword;
		if (loword)
			int_hdd_data_rd <= 1;
	end
	if (rclk_ide_wrD ^ rclk_ide_wrD2) begin
		loword <= ~loword;
		if (!loword)
			int_hdd_data_out[15:8] <= data_ide;
		else begin
			int_hdd_data_wr <= 1;
			int_hdd_data_out[7:0] <= data_ide;
		end
	end
	if (rclk_cdda_wrD ^ rclk_cdda_wrD2) begin
		loword <= ~loword;
		if (!loword)
			int_hdd_data_out[15:8] <= data_ide;
		else begin
			int_hdd_cdda_wr <= 1;
			int_hdd_data_out[7:0] <= data_ide;
		end
	end
	if (rclk2D ^ rclk2D2 && !downloading_reg) begin
		loword <= ~loword;
		if (!loword)
			int_hdd_data_out[15:8] <= data_w2;
		else begin
			int_hdd_data_wr <= 1;
			int_hdd_data_out[7:0] <= data_w2;
		end
	end
	if (rclk_ide_regs_wrD ^ rclk_ide_regs_wrD2) begin
		int_hdd_wr <= 1;
		int_hdd_data_out <= {8'h00, data_ide};
		int_hdd_addr <= int_hdd_addr + 1'd1;
	end
	if (rclk_ide_regs_rdD ^ rclk_ide_regs_rdD2) begin
		int_hdd_addr <= int_hdd_addr + 1'd1;
	end
end
end else begin
	assign hdd0_ena = 0;
	assign hdd1_ena = 0;
	assign hdd_cdda_wr = 0;
	assign hdd_status_wr = 0;
	assign hdd_addr = 0;
	assign hdd_wr = 0;
	assign hdd_data_out = 0;
	assign hdd_data_rd = 0;
	assign hdd_data_wr = 0;
end

endgenerate

endmodule
