/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-8-2023 */

module jttwin16_sub(
    input                rst,
    input                clk, // 48 MHz
    input                LVBL,

    input                tim,
    output reg           mint,

    input                sub_intn,
    output        [17:1] ram_addr,
    input         [15:0] ram_dout,
    input                ram_ok,
    output reg           ram_cs,
    output               ram_we,
    output        [ 1:0] ram_dsn,

    output        [17:1] cpu_addr,
    output        [15:0] cpu_dout,
    // shared RAM
    output        [ 1:0] sh_we,
    input         [15:0] sh_dout,
    // video RAM outputs,
    input         [15:0] ma_dout,   // scroll A
    input         [15:0] mb_dout,   // scroll B
    input         [15:0] mo_dout,   // objects
    output        [ 1:0] va_we,
    output        [ 1:0] vb_we,
    output        [ 1:0] obj_we,

    // scroll tile RAMs
    output        [ 1:0] stile_we,
    input         [15:0] stile_dout,
    // video ROM checks
    output reg           chapage,
    input         [31:0] obj_data,
    input                obj_ok,

    output        [18:1] rom_addr,
    output reg           rom_cs,
    input                rom_ok,
    input         [15:0] rom_data,

    input                dip_pause
);
`ifndef NOMAIN
reg  [15:0] cpu_din;
wire [23:1] A;
wire [ 1:0] dws;
wire        cpu_cen, cpu_cenb, pre_dtackn, vb_intn, sintn;
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
wire        bus_cs, bus_busy, BUSn;
reg  [ 1:0] rom_part;
reg         sh_cs, vram_cs, oram_cs, sys_cs, stram_cs,
            sint_enb, otram_cs, otrom_cs;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign cpu_addr = A[17:1];
assign VPAn     = ~( A[23] & ~ASn );
assign ram_dsn  = {UDSn, LDSn};
assign IPLn     = {vb_intn & sintn, vb_intn, ~(vb_intn & ~sintn)};
assign dws      = ~({2{RnW}} | {UDSn, LDSn});
assign ram_we   = !RnW && ram_cs && {UDSn, LDSn}!=3;
assign va_we    = dws & {2{vram_cs & ~A[13]}};
assign vb_we    = dws & {2{vram_cs &  A[13]}};
assign obj_we   = dws & {2{oram_cs}};
assign stile_we = dws & {2{stram_cs}};
assign sh_we    = dws & {2{sh_cs}};
assign DTACKn   = (~(vram_cs | oram_cs ) | tim) & pre_dtackn;
assign rom_addr[16: 1] = A[16:1];
assign rom_addr[18:17] = rom_part;
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs  & ~rom_ok) | (ram_cs  & ~ram_ok) | (otrom_cs & ~obj_ok);
// Object Tile RAM is mapped at the bottom
// so the lyro SDRAM slot has access to it
// SPA0~SPA14 => SUB's A[2:16], A[1] selects upper/lower 16-bit word
assign ram_addr = { otram_cs ? {1'b0, A[16:14]} : 4'd8,  A[13:1] };

always @* begin
    vram_cs  = 0;
    oram_cs  = 0;
    stram_cs = 0;
    otram_cs = 0;
    otrom_cs = 0;
    rom_cs   = 0;
    ram_cs   = 0;
    sh_cs    = 0;
    sys_cs   = 0;
    rom_part = {1'b0,A[17]};
    // decoder 8M
    if(!ASn && !A[22]) case( A[19:17] )
        0,1: rom_cs = 1;
        2: sh_cs = 1;
        3: ram_cs = 1;
        4: begin rom_cs=1; rom_part=2'b10; end
        5: sys_cs = 1;
        default:;
    endcase

    // decoder 7T
    if(!ASn && A[23:22]==2'b01) case( A[21:19] )
        0: oram_cs  = 1;
        1: vram_cs  = 1;
        2: stram_cs = 1;
        4,5,6: otrom_cs = 1;
        7: otram_cs = 1;
        default:;
    endcase
end

always @(posedge clk) begin
    cpu_din <= rom_cs   ? rom_data  :
               ram_cs   ? ram_dout  :
               otram_cs ? ram_dout  :
               oram_cs  ? mo_dout   :
               sh_cs    ? sh_dout   :
               stram_cs ? stile_dout:
               vram_cs  ? (A[13] ? mb_dout : ma_dout ) :
               otrom_cs ? ( A[1] ? obj_data[31:16] : obj_data[15:0] ) :
               16'h0;
end

always @(posedge clk) begin
    if(rst) begin
        sint_enb <= 0;
        mint     <= 0;
        chapage  <= 0;
    end else begin
        if(sys_cs) {chapage,sint_enb,mint}<=cpu_dout[2:0];
    end
end

jtframe_edge #(.QSET(0))u_vbl(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .edgeof     ( ~LVBL     ),
    .clr        ( ~VPAn     ),
    .q          ( vb_intn   )
);

jtframe_edge #(.QSET(0))u_subint(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .edgeof     ( sub_intn  ),
    .clr        ( sint_enb  ),
    .q          ( sintn     )
);

jtframe_68kdtack_cen #(.W(5)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 4'd3      ),  // numerator
    .den        ( 5'd16     ),  // denominator, => 9216
    .DTACKn     ( pre_dtackn),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    // Frequency report
    .fave       (           ),
    .fworst     (           )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

    // Buses
    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),


    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),

    .BERRn      ( 1'b1        ),
    // Bus arbitrion
    .HALTn      ( dip_pause   ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        ) // VBLANK
);
`else
`endif
endmodule