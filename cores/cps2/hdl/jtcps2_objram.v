/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 5-12-2020 */

// Original order
// 0  X
// 1  Y
// 2  code
// 3  attr

// it should be possible to use half the memory by
// copying the data from the SDRAM when obank toggles
// but if a game change it outside V blank
// it may create a visible glitch

module jtcps2_objram(
    input           rst,
    input           clk_cpu,
    input           clk_gfx,

    input           obank,

    // Configuration
    input           objcfg_cs,
    input    [ 1:0] cfg_dsn,
    input    [15:0] cpu_dout,
    input    [ 3:1] cfg_addr,

    output reg [9:0] off_x,
    output reg [9:0] off_y,

    // Interface with CPU
    input           cs,
    output reg      ok,
    input    [ 1:0] dsn,
    input    [15:0] oram_din,
    input    [13:1] main_addr,
    // output   [15:0] dout2cpu,

    // Interface with OBJ engine
    input    [ 9:0] obj_addr, // 11 bits because bank is automatic
                              // and 32-bits are read together
    output   [15:0] obj_x,
    output   [15:0] obj_y,
    output   [15:0] obj_attr,
    output   [15:0] obj_code
);

parameter AW=13; // 13 for full table shadowing
localparam [3:1] XOFF=4, YOFF=5;

reg  [15:0] din_x, din_y;

wire [   1:0] wex, wey, wecode, weattr;
wire [AW-3:0] wr_addr, gfx_addr;

wire [9:0] next_offy = { cfg_dsn[1] ? off_y[9:8] : cpu_dout[9:8],
                         cfg_dsn[0] ? off_y[7:0] : cpu_dout[7:0] };

wire [9:0] next_offx = { cfg_dsn[1] ? off_x[9:8] : cpu_dout[9:8],
                         cfg_dsn[0] ? off_x[7:0] : cpu_dout[7:0] };

assign wex      = ~dsn & {2{cs & main_addr[2:1]==2'd0}};
assign wey      = ~dsn & {2{cs & main_addr[2:1]==2'd1}};
assign wecode   = ~dsn & {2{cs & main_addr[2:1]==2'd2}};
assign weattr   = ~dsn & {2{cs & main_addr[2:1]==2'd3}};

assign wr_addr  = {  obank^main_addr[13], main_addr[AW-1:3] };
assign gfx_addr = { ~obank, obj_addr[AW-4:0] };

always @(posedge clk_cpu) begin
    ok    <= cs;
end

`ifdef XOFF_RST
    // Scene simulation only
    localparam [9:0] XOFF_RST=`XOFF_RST;
    localparam [9:0] YOFF_RST=`YOFF_RST;

    initial $display("SIMULATION: Object offset fixed to %X/%X", XOFF_RST, YOFF_RST );
`else
    // Regular operation
    localparam [9:0] XOFF_RST=10'd0;
    localparam [9:0] YOFF_RST=10'd0;
`endif

always @(posedge clk_cpu, posedge rst) begin
    if( rst ) begin
        off_x <= XOFF_RST;
        off_y <= YOFF_RST;
    end else if( objcfg_cs ) begin
        if( cfg_addr == XOFF ) begin
            if( cfg_dsn!=2'b11 ) off_x <= next_offx;
        end
        if( cfg_addr == YOFF ) begin
            if( cfg_dsn!=2'b11 ) off_y <= next_offy;
        end
    end
end

jtframe_dual_ram16 #(
    .AW(AW-2)
    // ,.SIMFILE_LO("objx_lo.bin"), .SIMFILE_HI("objx_hi.bin")
) u_x(
    .clk0       ( clk_cpu      ),
    .clk1       ( clk_gfx      ),
    // Port 0: CPU
    .data0      ( oram_din     ),
    .addr0      ( wr_addr      ),
    .we0        ( wex          ),
    .q0         (              ),
    // Port 1: GFX
    .data1      ( 16'd0        ),
    .addr1      ( gfx_addr     ),
    .we1        ( 2'b0         ),
    .q1         ( obj_x        )
);

jtframe_dual_ram16 #(
    .AW(AW-2)
    // ,.SIMFILE_LO("objy_lo.bin"), .SIMFILE_HI("objy_hi.bin")
) u_y(
    .clk0       ( clk_cpu      ),
    .clk1       ( clk_gfx      ),
    // Port 0: CPU
    .data0      ( oram_din     ),
    .addr0      ( wr_addr      ),
    .we0        ( wey          ),
    .q0         (              ),
    // Port 1: GFX
    .data1      ( 16'd0        ),
    .addr1      ( gfx_addr     ),
    .we1        ( 2'b0         ),
    .q1         ( obj_y        )
);

jtframe_dual_ram16 #(
    .AW(AW-2)
    // ,.SIMFILE_LO("objattr_lo.bin"), .SIMFILE_HI("objattr_hi.bin")
) u_attr(
    .clk0       ( clk_cpu      ),
    .clk1       ( clk_gfx      ),
    // Port 0: CPU
    .data0      ( oram_din     ),
    .addr0      ( wr_addr      ),
    .we0        ( weattr       ),
    .q0         (              ),
    // Port 1: GFX
    .data1      ( 16'd0        ),
    .addr1      ( gfx_addr     ),
    .we1        ( 2'b0         ),
    .q1         ( obj_attr     )
);

jtframe_dual_ram16 #(
    .AW(AW-2)
    // ,.SIMFILE_LO("objcode_lo.bin"), .SIMFILE_HI("objcode_hi.bin")
) u_code(
    .clk0       ( clk_cpu      ),
    .clk1       ( clk_gfx      ),
    // Port 0: CPU
    .data0      ( oram_din     ),
    .addr0      ( wr_addr      ),
    .we0        ( wecode       ),
    .q0         (              ),
    // Port 1: GFX
    .data1      ( 16'd0        ),
    .addr1      ( gfx_addr     ),
    .we1        ( 2'b0         ),
    .q1         ( obj_code     )
);

endmodule
