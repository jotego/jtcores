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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 6-9-2021 */

/////////////////////////////////////////////
//  This module includes the SDRAM model
//  when used to simulate the core at the game level (instead of MiST(er) level)
//  this module also adds the SDRAM controller
//
//

`timescale 1ns/1ps

module test_harness(
    output  reg      rst = 1'b0,
    output  reg      clk27,
    input            pxl_cen,
    input            pxl_clk,
    input            pxl_vb,
    input            pxl_hb,
    input   [21:0]   sdram_addr,
    output  [15:0]   data_read,
    output           loop_rst,
    input            autorefresh,
    input            H0,
    output           downloading,
    input            dwnld_busy,
    output    [24:0] ioctl_addr,
    output    [ 7:0] ioctl_dout,
    output           ioctl_wr,
    // Video dumping
    input             HS,
    input             VS,
    input       [3:0] red,
    input       [3:0] green,
    input       [3:0] blue,
    output reg [31:0] frame_cnt,
    // SPI
    output       SPI_SCK,
    output       SPI_DI,  // SPI always from FPGA's view
    input        SPI_DO,
    output       SPI_SS2,
    output       SPI_SS3,
    output       CONF_DATA0,
    // SDRAM
    inout [15:0] SDRAM_DQ,
    inout [12:0] SDRAM_A,
    inout        SDRAM_DQML,
    inout        SDRAM_DQMH,
    inout        SDRAM_nWE,
    inout        SDRAM_nCAS,
    inout        SDRAM_nRAS,
    inout        SDRAM_nCS,
    inout [1:0]  SDRAM_BA,
    inout        SDRAM_CLK,
    inout        SDRAM_CKE
);

parameter sdram_instance = 1, GAME_ROMNAME="_PASS ROM NAME to test_harness_";
parameter TX_LEN = 207;

////////////////////////////////////////////////////////////////////
// video output dump
// Dumps a binary file with 32 bits per pixel. First 8 bits are the alpha, and set to 0xFF
// The rest are RGB in 8-bit format
// There is no dump while blanking. The inputs pxl_hb and pxl_vb are high during blanking
// The linux tool "convert" can process the raw stream and separate it into individual frames
// automatically

video_dump u_dump(
    .pxl_clk    ( pxl_clk       ),
    .pxl_cen    ( pxl_cen       ),
    .pxl_hb     ( pxl_hb        ),
    .pxl_vb     ( pxl_vb        ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .frame_cnt  ( frame_cnt     )
    //input        downloading
);

////////////////////////////////////////////////////////////////////
initial frame_cnt=0;
always @(posedge pxl_vb ) begin
    frame_cnt<=frame_cnt+1;
    $display("Frame %4d", frame_cnt);
end

`ifdef MAXFRAME
reg frames_done=1'b0;
always @(negedge pxl_vb)
    if( frame_cnt == `MAXFRAME ) frames_done <= 1'b1;
`else
reg frames_done=1'b1;
`endif

wire spi_done;
integer fincnt=0;

// The PLL is only added if the top level does not already include it
`ifndef MISTER
`ifndef MIST
wire clk_rom;
pll_game_mist u_pll(
    .inclk0 ( 1'b0    ),
    .c0     ( clk     ),     // 12
    .c1     (         ),     // 96
    // unused
    //.c3     (         ),     // 96 (shifted by -2.5ns)
    .locked (         )
);

assign clk_rom = clk;

generate
    if (sdram_instance==1) begin
        assign #5 SDRAM_CLK = clk_rom;

        jtframe_sdram u_sdram(
            .rst            ( rst           ),
            .clk            ( clk_rom       ), // 96MHz = 32 * 6 MHz -> CL=2
            .cen12          ( cen12         ),
            .H0             ( H0            ),
            .loop_rst       ( loop_rst      ),
            .autorefresh    ( autorefresh   ),
            .data_read      ( data_read     ),
            // ROM-load interface
            .downloading    ( downloading   ),
            .prog_addr      ( ioctl_addr    ),
            .prog_data      ( ioctl_dout    ),
            .prog_we        ( ioctl_wr      ),
            .sdram_addr     ( sdram_addr    ),
            // SDRAM interface
            .SDRAM_DQ       ( SDRAM_DQ      ),
            .SDRAM_A        ( SDRAM_A       ),
            .SDRAM_DQML     ( SDRAM_DQML    ),
            .SDRAM_DQMH     ( SDRAM_DQMH    ),
            .SDRAM_nWE      ( SDRAM_nWE     ),
            .SDRAM_nCAS     ( SDRAM_nCAS    ),
            .SDRAM_nRAS     ( SDRAM_nRAS    ),
            .SDRAM_nCS      ( SDRAM_nCS     ),
            .SDRAM_BA       ( SDRAM_BA      ),
            .SDRAM_CKE      ( SDRAM_CKE     )
        );
    end
endgenerate
`endif
`endif

////////////////////////////////////////////////////////////////////
always @(posedge clk27)
    if( ( spi_done && !dwnld_busy ) && frames_done ) begin
        for( fincnt=0; fincnt<`SIM_MS; fincnt=fincnt+1 ) begin
            #(1000*1000); // ms
            $display("%d ms",fincnt+1);
        end
        `ifdef STOPONLY
        $stop;
        `else
        $finish;
        `endif
    end

initial begin
    clk27 = 1'b0;
    forever clk27 = #(37.037/2) ~clk27; // 27 MHz
end

reg rst_base=1'b1;

initial begin
    rst_base = 1'b1;
    #100 rst_base = 1'b0;
    #150 rst_base = 1'b1;
    #2500 rst_base=1'b0;
end

integer rst_cnt;

always @(negedge clk27 or posedge rst_base)
    if( rst_base ) begin
        rst <= 1'b1;
        rst_cnt <= 2;
    end else begin
        if(rst_cnt) rst_cnt<=rst_cnt-1;
        else rst<=rst_base;
    end

`ifdef FASTSDRAM
quick_sdram u_sdram(
    .SDRAM_DQ   ( SDRAM_DQ      ),
    .SDRAM_A    ( SDRAM_A       ),
    .SDRAM_CLK  ( SDRAM_CLK     ),
    .SDRAM_nCS  ( SDRAM_nCS     ),
    .SDRAM_nRAS ( SDRAM_nRAS    ),
    .SDRAM_nCAS ( SDRAM_nCAS    ),
    .SDRAM_nWE  ( SDRAM_nWE     )
);
`else
mt48lc16m16a2 #(.filename(GAME_ROMNAME)) u_sdram (
    .Dq         ( SDRAM_DQ      ),
    .Addr       ( SDRAM_A       ),
    .Ba         ( SDRAM_BA      ),
    .Clk        ( SDRAM_CLK     ),
    .Cke        ( SDRAM_CKE     ),
    .Cs_n       ( SDRAM_nCS     ),
    .Ras_n      ( SDRAM_nRAS    ),
    .Cas_n      ( SDRAM_nCAS    ),
    .We_n       ( SDRAM_nWE     ),
    .Dqm        ( {SDRAM_DQMH,SDRAM_DQML}   ),
    .downloading( dwnld_busy    ),
    .VS         ( VS            ),
    .frame_cnt  ( frame_cnt     )
);
`endif

// Length of the downloading process
// if LOADROM is defined, the full length of the ROM file is done
// Otherwise, only 256 are transferred to let the core experience the pulse
// of the downloading signal
`ifdef LOADROM
    localparam DWNLEN = TX_LEN;
`else
    localparam DWNLEN = 256;
`endif

`ifndef ROM_OFFSET
    localparam ROM_OFFSET = 0;
`else
    localparam ROM_OFFSET = `ROM_OFFSET;
    initial $display("ROM will be dumped starting at %X",ROM_OFFSET);
`endif

spitx #(.filename(GAME_ROMNAME), .TX_LEN(DWNLEN),.TX_OFFSET(ROM_OFFSET) )
    u_spitx(
    .rst        ( rst        ),
    .SPI_DO     ( 1'b0       ),
    .SPI_SCK    ( SPI_SCK    ),
    .SPI_DI     ( SPI_DI     ),
    .SPI_SS2    ( SPI_SS2    ),
    .SPI_SS3    ( SPI_SS3    ),
    .SPI_SS4    (            ),
    .CONF_DATA0 ( CONF_DATA0 ),
    .spi_done   ( spi_done   )
);

data_io_harness #(.START_ADDR(ROM_OFFSET))
datain (
    .clkref_n       ( 1'b0        ),
    .SPI_SCK        (SPI_SCK      ),
    .SPI_SS2        (SPI_SS2      ),
    .SPI_SS4        (1'b1         ),
    .SPI_DI         (SPI_DI       ),
    .SPI_DO         (/* SPI_SS4 */),
    .ioctl_download (downloading  ),
    .ioctl_index    (             ),
    .clk_sys        (SDRAM_CLK    ),
    .ioctl_addr     ( ioctl_addr  ),
    .ioctl_dout     ( ioctl_dout  ),
    .ioctl_din      (             ),
    .ioctl_wr       ( ioctl_wr    ),
    // unused
    .ioctl_upload   (             ),
    .ioctl_fileext  (             ),
    .ioctl_filesize (             )
);

endmodule

// This is basically the same data_io used in MiST,
// but it's copied here with a different name to allow
// gate-level sims to work correctly
module data_io_harness
(
    input             clk_sys,
    input             SPI_SCK,
    input             SPI_SS2,
    input             SPI_SS4,
    input             SPI_DI,
    inout             SPI_DO,

    input             clkref_n, // assert ioctl_wr one cycle after clkref stobe (negative active)

    // ARM -> FPGA download
    output reg        ioctl_download = 0, // signal indicating an active download
    output reg        ioctl_upload = 0,   // signal indicating an active upload
    output reg  [7:0] ioctl_index,        // menu index used to upload the file ([7:6] - extension index, [5:0] - menu index)
                                          // Note: this is also set for user_io mounts.
                                          // Valid when ioctl_download = 1 or when img_mounted strobe is active in user_io.
    output reg        ioctl_wr,           // strobe indicating ioctl_dout valid
    output reg [24:0] ioctl_addr,
    output reg  [7:0] ioctl_dout,
    input       [7:0] ioctl_din,
    output reg [23:0] ioctl_fileext,      // file extension
    output reg [31:0] ioctl_filesize      // file size
);

`ifdef SIMULATION
initial begin
    ioctl_index = 8'h1;
end
`endif

parameter START_ADDR = 25'd0;
parameter ROM_DIRECT_UPLOAD = 0;

///////////////////////////////   DOWNLOADING   ///////////////////////////////

reg  [7:0] data_w;
reg  [7:0] data_w2  = 0;
reg  [3:0] cnt;
reg        rclk   = 0;
reg        rclk2  = 0;
reg        addr_reset = 0;
reg        downloading_reg = 0;
reg        uploading_reg = 0;
reg        reg_do;

localparam DIO_FILE_TX      = 8'h53;
localparam DIO_FILE_TX_DAT  = 8'h54;
localparam DIO_FILE_INDEX   = 8'h55;
localparam DIO_FILE_INFO    = 8'h56;
localparam DIO_FILE_RX      = 8'h57;
localparam DIO_FILE_RX_DAT  = 8'h58;

assign SPI_DO = reg_do;

// data_io has its own SPI interface to the io controller
always@(negedge SPI_SCK or posedge SPI_SS2) begin : SPI_TRANSMITTER
    reg [7:0] dout_r;

    if(SPI_SS2) begin
        reg_do <= 1'bZ;
    end else begin
        if (cnt == 15) dout_r <= ioctl_din;
        reg_do <= dout_r[~cnt[2:0]];
    end
end


always@(posedge SPI_SCK, posedge SPI_SS2) begin : SPI_RECEIVER
    reg  [6:0] sbuf;
    reg [24:0] addr;
    reg  [7:0] cmd;
    reg  [5:0] bytecnt;

    if(SPI_SS2) begin
        bytecnt <= 0;
        cnt     <= 0;
    end else begin
        // don't shift in last bit. It is evaluated directly
        // when writing to ram
        if(cnt != 15) sbuf <= { sbuf[5:0], SPI_DI};

        // count 0-7 8-15 8-15 ...
        if(cnt != 15) cnt <= cnt + 1'd1;
            else cnt <= 8;

        // finished command byte
        if(cnt == 7) cmd <= {sbuf, SPI_DI};

        if(cnt == 15) begin
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
                bytecnt <= bytecnt + 1'd1;
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
generate if (ROM_DIRECT_UPLOAD == 1) begin

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
            sbuf2 <= { sbuf2[5:0], SPI_DO };

        cnt2 <= cnt2 + 1'd1;

        // received a byte
        if(cnt2 == 7) begin
            bytecnt <= bytecnt + 1'd1;
            // read 514 byte/sector (512 + 2 CRC)
            if (bytecnt == 513) bytecnt <= 0;
            // don't send the CRC bytes
            if (~bytecnt[9]) begin
                data_w2 <= {sbuf2, SPI_DO};
                rclk2 <= ~rclk2;
            end
        end
    end
end

end
endgenerate

always@(posedge clk_sys) begin : DATA_OUT
    // synchronisers
    reg rclkD, rclkD2;
    reg rclk2D, rclk2D2;
    reg addr_resetD, addr_resetD2;

    reg wr_int, wr_int_direct, rd_int;
    reg [24:0] addr;
    reg [31:0] filepos;

    // bring flags from spi clock domain into core clock domain
    { rclkD, rclkD2 } <= { rclk, rclkD };
    { rclk2D ,rclk2D2 } <= { rclk2, rclk2D };
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
        if (wr_int || wr_int_direct) begin
            ioctl_dout <= wr_int ? data_w : data_w2;
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
    if (rclk2D ^ rclk2D2 && filepos != ioctl_filesize) begin
        filepos <= filepos + 1'd1;
        wr_int_direct <= 1;
    end
end

endmodule
