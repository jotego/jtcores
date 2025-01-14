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
    input                dma_bsy,

    input                sint,
    output        [17:1] ram_addr,
    input         [15:0] ram_dout,
    input                ram_ok,
    output reg           ram_cs,
    output               bus_we,
    output        [ 1:0] bus_dsn,

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
    output        [ 1:0] oram_we,

    // scroll tile RAMs
    output reg           stile_cs,
    output        [ 1:0] stile_we,
    input         [15:0] stile_dout,
    input                stile_ok,
    // video ROM checks
    output reg           obj_cs,
    output        [20:1] obj_addr,
    input         [15:0] obj_data,
    input                obj_ok,

    output        [18:1] rom_addr,
    output reg           rom_cs,
    input                rom_ok,
    input         [15:0] rom_data,

    input                dip_pause
);
`ifndef NOMAIN
reg  [15:0] cpu_din;
wire [15:0] vdout;
wire [23:1] A;
wire [ 1:0] dws;
wire        cpu_cen, cpu_cenb, pre_dtackn;
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
wire        bus_cs, bus_busy, BUSn, ab_sel, oeff_cs;
reg  [ 1:0] rom_part;
reg         sh_cs, vram_cs, oram_cs, sys_cs,
            sint_en, otram_cs, chapage;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign cpu_addr = A[17:1];
assign obj_addr = { A[20], A[20] ? chapage : A[19], A[18:1] };
assign dws      = ~({2{RnW}} | {UDSn, LDSn});
assign bus_dsn  = {UDSn, LDSn};
assign bus_we   = ~RnW;
assign ab_sel   = ~A[13];
assign va_we    = dws & {2{vram_cs & ~A[13]}};
assign vb_we    = dws & {2{vram_cs &  A[13]}};
assign oram_we  = dws & {2{oeff_cs}};
assign stile_we = dws & {2{stile_cs}};
assign sh_we    = dws & {2{sh_cs}};
assign rom_addr[16: 1] = A[16:1];
assign rom_addr[18:17] = rom_part;
assign bus_cs   =  rom_cs | ram_cs | obj_cs | stile_cs;
assign bus_busy = (rom_cs & ~rom_ok) | (ram_cs   & ~ram_ok) |
                  (obj_cs & ~obj_ok) | (stile_cs & ~stile_ok);
assign BUSn     = ASn | (LDSn & UDSn);
// Object Tile RAM is mapped at the bottom
// so the lyro SDRAM slot has access to it
// SPA0~SPA14 => SUB's A[2:16], A[1] selects upper/lower 16-bit word
assign ram_addr = { otram_cs ? {1'b0, A[16:14]} : 4'd8,  A[13:1] };

always @* begin
    vram_cs  = 0;
    oram_cs  = 0;
    stile_cs = 0;
    otram_cs = 0;
    obj_cs   = 0;
    rom_cs   = 0;
    ram_cs   = 0;
    sh_cs    = 0;
    sys_cs   = 0;
    rom_part = {1'b0,A[17]};
    // decoder 8M
    if(!ASn && !A[22]) case( A[19:17] )
        0,1: rom_cs = 1;
        2: sh_cs = 1;
        3: ram_cs = !BUSn;
        4: begin rom_cs=1; rom_part=2'b10; end
        5: sys_cs = 1;
        default:;
    endcase

    // decoder 7T
    if(!ASn && A[23:22]==2'b01) case( A[21:19] )
        0: oram_cs  = 1;
        1: vram_cs  = 1;
        2: stile_cs = !BUSn;    // shown as "zip" RAM in tests
        4,5,6: obj_cs = 1;
        7: {otram_cs,ram_cs} = {1'b1,!BUSn};
        default:;
    endcase
end

always @(posedge clk) begin
    cpu_din <= rom_cs   ? rom_data  :
               ram_cs   ? ram_dout  :
               otram_cs ? ram_dout  :
               oram_cs  ? vdout     :
               vram_cs  ? vdout     :
               sh_cs    ? sh_dout   :
               stile_cs ? stile_dout:
               obj_cs   ? obj_data  :
               16'h0;
end

always @(posedge clk) begin
    if(rst) begin
        sint_en <= 0;
        mint    <= 0;
        chapage <= 0;
    end else begin
        if(sys_cs) {chapage,sint_en,mint}<=cpu_dout[2:0];
    end
end

jttwin16_ints u_ints(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .LVBL   ( LVBL      ),
    .ASn    ( ASn       ),
    .A23    ( A[23]     ),

    // request from the other CPU
    .intn   ( sint      ),
    .int_en ( sint_en   ),

    .VPAn   ( VPAn      ),
    .IPLn   ( IPLn      )
);


jttwin16_dtack u_tim_dtack(
    .clk        ( clk       ),
    .ASn        ( ASn       ),
    .RnW        ( RnW       ),
    .LDSn       ( LDSn      ),
    .UDSn       ( UDSn      ),
    .dma_bsy    ( dma_bsy   ),
    .oram_cs    ( oram_cs   ),
    .vram_cs    ( vram_cs   ),
    .oeff_cs    ( oeff_cs   ),
    .tim        ( tim       ),
    .ab_sel     ( ab_sel    ),
    .ma_dout    ( ma_dout   ),
    .mb_dout    ( mb_dout   ),
    .mo_dout    ( mo_dout   ),
    .vdout      ( vdout     ),
    .pre_dtackn ( pre_dtackn),
    .DTACKn     ( DTACKn    )
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
assign
    ram_addr = 0, bus_we   = 0, bus_dsn = 3, cpu_addr = 0, cpu_dout = 0,
    sh_we    = 0, va_we    = 0, vb_we   = 0, oram_we  = 0, stile_we = 0,
    obj_addr = 0, rom_addr = 0;
initial begin
    mint   = 0; ram_cs = 0;
    obj_cs = 0; rom_cs = 0; stile_cs = 0;
end
`endif
endmodule