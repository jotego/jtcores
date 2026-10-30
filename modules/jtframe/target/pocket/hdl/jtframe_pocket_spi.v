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
    along with JTFRAME. If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-8-2022 */

// The addr and dout outputs belong to the clk_74a but will be stable by the
// time rd and wr are produced.
// The constraint file pocket.sdc contains false path directives to cover this

module jtframe_pocket_spi(
    input             clk_74a,
    // SPI clock domain
    inout      [ 1:0] spi_dio,
    inout             spi_clk,
    input             spi_ss,

    // clk_rom domain
    input             rst_rom,
    input             clk_rom,

    output reg [31:2] addr,
    output            rd,
    input      [31:0] din,
    input             waitn,

    output            wr,
    output reg [31:0] dout
);

localparam [1:0] IDLE  = 0,
                 WRITE = 1,
                 READ  = 2;

// SPI
reg  [31:0] spi_addr, spi_dout;
reg         spi_aok, spi_dok, clk_sel;
reg  [ 4:0] spi_cnt;

reg  [33:0] tx_buf;
reg  [ 4:0] tx_cnt;
reg  [ 9:0] tx_go;
reg         tx_clk, tx_busy;

wire [31:0] addr_s, dout_s;
wire        dinok_s, ainok_s;
reg         ainokl;
reg  [ 1:0] st;
wire        tx_go_sh;
reg         rd_a, wr_a;

assign spi_clk = tx_busy ? tx_clk : 1'bz;
assign spi_dio = tx_busy ? tx_buf[33:32] : 2'bzz;

// SPI Rx
always @(posedge spi_clk, posedge spi_ss) begin
    if(spi_ss) begin
        spi_aok <= 0;
        spi_dok <= 0;
        spi_cnt <= 0;
    end else begin
        if( !spi_cnt[4]  ) spi_addr <= { spi_addr[29:0], spi_dio };
        if(  spi_cnt[4]  ) spi_dout <= { spi_dout[29:0], spi_dio };
        if( ~&spi_cnt    ) spi_cnt <= spi_cnt+1'd1;
        if(  spi_cnt==15 ) begin
            spi_aok <= 1;   // Address part
        end
        if( &spi_cnt ) spi_dok <= 1;   // Data part
    end
end

// SPI Tx

always @(posedge clk_74a, posedge spi_ss ) begin
    if( spi_ss ) begin
        tx_cnt  <= 0;
        tx_busy <= 0;
        tx_buf  <= 0;
        tx_clk  <= 0;
    end else begin
        tx_clk <= !tx_busy ? 1'b1 : ~tx_clk;
        if( tx_go[0] ) begin
            tx_buf <= { 2'b11, din };
            tx_cnt  <= 5'h1f;
            tx_busy <= 1;
        end else if( tx_clk ) begin
            if( tx_busy ) tx_cnt <= tx_cnt + 1'd1;
            if( tx_cnt==5'hf ) begin
                tx_busy <= 0;
                tx_clk  <= 1;
            end
            tx_buf <= tx_buf << 2;
        end
    end
end

// Interface with the JTPOCKET core
jtframe_sync #(.W(32+32+2)) u_spi2rom(
    .clk_in     ( spi_clk              ),
    .clk_out    ( clk_74a              ),
    .raw        ( { spi_dout, spi_addr, spi_dok, spi_aok } ),
    .sync       ( { dout_s, addr_s, dinok_s, ainok_s     } )
);

initial begin
    ainokl <= 0;
    wr_a   <= 0;
    rd_a   <= 0;
    addr   <= 0;
    dout   <= 0;
    tx_go  <= 0;
end

jtframe_crossclk_strobe u_rd(
    .clk_in     ( clk_74a   ),
    .clk_out    ( clk_rom   ),
    .stin       ( rd_a      ),
    .stout      ( rd        )
);

jtframe_crossclk_strobe u_wr(
    .clk_in     ( clk_74a   ),
    .clk_out    ( clk_rom   ),
    .stin       ( wr_a      ),
    .stout      ( wr        )
);

always @(posedge clk_74a ) begin
    ainokl   <= ainok_s;
    wr_a     <= 0;
    rd_a     <= 0;
    tx_go    <= tx_go>>1;
    case( st )
        default: if( ainok_s && !ainokl ) begin
            addr <= addr_s[31:2];
            st   <= addr_s[0] ? WRITE : READ;
            rd_a <= ~addr_s[0]; // request data to core
        end
        WRITE: if( dinok_s ) begin
            dout <= dout_s;
            wr_a <= 1;
            st   <= IDLE;
        end
        READ: begin
            tx_go <= 10'd1<<9;
            st <= IDLE;
        end
    endcase
end

endmodule
