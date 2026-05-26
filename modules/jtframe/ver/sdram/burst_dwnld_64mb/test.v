`timescale 1ns / 1ps

module test(
    input              clk,
    input              rst,

    input              ioctl_rom,
    input      [25:0]  ioctl_addr,
    input      [ 7:0]  ioctl_dout,
    input              ioctl_wr,
    output             prog_rdy,

    input      [22:0]  addr,
    input      [ 1:0]  ba,
    input              rd,
    output     [15:0]  dout,
    output             ack,
    output             dst,
    output             dok,
    output             rdy,
    output             init,

    input      [15:0]  SDRAM_DQ,
    output     [15:0]  SDRAM_DIN,
    output     [12:0]  SDRAM_A,
    output     [ 1:0]  SDRAM_DQM,
    output     [ 1:0]  SDRAM_BA,
    output             SDRAM_nWE,
    output             SDRAM_nCAS,
    output             SDRAM_nRAS,
    output             SDRAM_nCS,
    output             SDRAM_CKE
);

localparam integer PERIOD = 10;
localparam integer AW     = 23;
localparam integer HF     = 1;

wire [AW-1:0] prog_addr;
wire [15:0]   prog_data;
wire [ 1:0]   prog_mask;
wire          prog_we;
wire          prog_rd;
wire [ 1:0]   prog_ba;
wire          prom_we;
wire          header;

wire [15:0]   sdram_dq = SDRAM_DQ;

reg  [31:0]   hcnt;
wire          rfsh = hcnt == 0;

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        hcnt <= 0;
    end else begin
        hcnt <= hcnt == (64_000/PERIOD)-1 ? 0 : hcnt + 1'd1;
    end
end

jtframe_burst_sdram #(
    .AW       ( AW ),
    .HF       ( HF ),
    .MISTER   ( 0  ),
    .PROG_LEN ( 64 )
) uut (
    .rst        ( rst          ),
    .clk        ( clk          ),
    .init       ( init         ),
    .addr       ( addr         ),
    .ba         ( ba           ),
    .rd         ( rd           ),
    .wr         ( 1'b0         ),
    .din        ( 16'h0000     ),
    .dout       ( dout         ),
    .ack        ( ack          ),
    .dst        ( dst          ),
    .dok        ( dok          ),
    .rdy        ( rdy          ),
    .prog_en    ( ioctl_rom    ),
    .prog_addr  ( prog_addr    ),
    .prog_rd    ( prog_rd      ),
    .prog_wr    ( prog_we      ),
    .prog_din   ( prog_data    ),
    .prog_dsn   ( prog_mask    ),
    .prog_ba    ( prog_ba      ),
    .prog_dst   (              ),
    .prog_dok   (              ),
    .prog_rdy   ( prog_rdy     ),
    .prog_ack   (              ),
    .rfsh       ( rfsh         ),
    .sdram_dq   ( sdram_dq     ),
    .sdram_din  ( SDRAM_DIN    ),
    .sdram_a    ( SDRAM_A      ),
    .sdram_dqml ( SDRAM_DQM[0] ),
    .sdram_dqmh ( SDRAM_DQM[1] ),
    .sdram_ba   ( SDRAM_BA     ),
    .sdram_nwe  ( SDRAM_nWE    ),
    .sdram_ncas ( SDRAM_nCAS   ),
    .sdram_nras ( SDRAM_nRAS   ),
    .sdram_ncs  ( SDRAM_nCS    ),
    .sdram_cke  ( SDRAM_CKE    )
);

jtframe_dwnld #(
    .SDRAMW    ( 24          ),
    .BA1_START ( 26'h1000000 ),
    .BA2_START ( 26'h2000000 ),
    .BA3_START ( 26'h3000000 ),
    .SWAB      ( 1'b1        )
) u_dwnld (
    .clk        ( clk         ),
    .ioctl_rom  ( ioctl_rom   ),
    .ioctl_addr ( ioctl_addr  ),
    .ioctl_dout ( ioctl_dout  ),
    .ioctl_wr   ( ioctl_wr    ),
    .prog_addr  ( prog_addr   ),
    .prog_data  ( prog_data   ),
    .prog_mask  ( prog_mask   ),
    .prog_we    ( prog_we     ),
    .prog_rd    ( prog_rd     ),
    .prog_ba    ( prog_ba     ),
    .gfx4_en    ( 1'b0        ),
    .gfx8_en    ( 1'b0        ),
    .gfx16_en   ( 1'b0        ),
    .gfx16b_en  ( 1'b0        ),
    .gfx16c_en  ( 1'b0        ),
    .prom_we    ( prom_we     ),
    .header     ( header      ),
    .sdram_ack  ( prog_rdy    )
);

endmodule
