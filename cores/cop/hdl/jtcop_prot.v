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
    Date: 4-1-2021 */

// This module contains the protection mechanism
// used on Robocop. It consists of a Hud6280 and some logic
// This is not used in Bad Dudes, where a i8051 replaces it.

// Hippodrome uses the same Hud6280 but it adds some protection mechanisms:
// - The ROM bits are twisted
// - There is a protection chip labelled "49" in page 26 of sch.
//   its details are unknown but the game seems to do a very rudimentary
//   use of it, so it is emulated with a very short LUT here
// - The MCU can access the BAC-06 chip on the same board

/* Equations in PAL16L8B in location 9A
/rom_a9 = A13 +
       rdn +
       wrn +
       cer_n +
       /A20
/HDPSEL = A14 +
       rdn +
       wrn +
       cer_n +
       /A20
/rom_cs = /ce7_n & /cer_n & /rdn & /wrn & A20 & /A13
/lit_cs =  ce7_n & /cer_n & /rdn & /wrn & A20 & /A14
/big_cs = /ce7_n & /cer_n & /rdn & /wrn & A20 & /A14
*/
module jtcop_prot(
    input           rst,
    input           clk,
    input           clk_cpu,
    input           LVBL,

    input    [11:1] main_addr,  // only 2kB are shared
    input    [ 7:0] main_dout,
    output   [ 7:0] main_din,
    input           main_cs,
    input           main_wrn,
    input    [ 1:0] game_id,

    // BA2 control - Hippodrome
    output     [ 7:0] ba2mcu_dout,
    output reg        ba2mcu_mode,
    input      [ 7:0] ba2mcu_mode_din,
    output reg        ba2mcu_cs,
    output            ba2mcu_rnw,
    input             ba2mcu_ok,
    input      [ 7:0] ba2mcu_data,
    output reg [13:1] ba2mcu_addr,
    output reg [ 1:0] ba2mcu_dsn,

    output   [15:0] mcu_addr,
    input     [7:0] mcu_data,
    output          mcu_cs,
    input           mcu_ok
);

localparam [ 1:0] HIPPODROME  = 2'd1;

wire [20:0] A;
wire [ 7:0] dout;
wire [12:0] shd_addr;
reg  [ 7:0] din, prot_st;
wire        waitn, wrn, rdn, SX;

wire        ce, cek_n, ce7_n, cer_n;
            //hdpsel_n;
wire        main_we;

wire        set_irq, irqn;
reg         rom_cs, ram_cs, shd_cs;
wire        ba2mcu_map, ba2mcu_sft;
wire [ 7:0] ram_dout, shd_dout;
wire        shd_we, ram_we, bac_cs;
reg         mcu_good, ba_good, prot_cs;
wire        irq2n;

assign ba2mcu_dout = dout;
assign ba2mcu_rnw  = wrn;
assign mcu_cs  = rom_cs;
assign mcu_addr = A[15:0];
assign main_we = main_cs & ~main_wrn;
// no bus access allowed while MAIN is accessing
assign waitn   = ~main_cs & mcu_good & ba_good;
// The "47" IC at location 10C in Hippodrome has an output
// to control the IRQ1 signal, but we don't know what triggers it
// For Robocop, the equivalent chip triggers it when accessing 7ff
assign set_irq = main_cs && main_addr==11'h7ff;// && game_id==0;
//assign irqn    = ~set_irq;
assign ram_we  = ram_cs & ~wrn;
assign shd_we  = shd_cs & ~wrn;
assign bac_cs  = A[20:19]==2'b11 && A[18:17]==2'd1 && game_id==HIPPODROME;
assign ba2mcu_sft = bac_cs && A[12:11]==2'd1;
assign ba2mcu_map = bac_cs && A[12:11]==2'd2;
assign irq2n = !(game_id==HIPPODROME && !LVBL);

// Unless SX is used, you can create a SDRAM
// request before knowing whether it is a read or write
// rdn and wrn are asserted with SX
// the address changes with CE
// One approach is to latch CS signals with SX
// and clear them with CE
// Another approach is a combinational assign including
// rdn and wrn to validate the _cs signals
// There are three clock cycles between SX and CE
always @(posedge clk) begin
    if(SX) begin
        rom_cs <= A[20:19]==0;
        case( game_id )
            HIPPODROME: begin
                ram_cs  <= A[20:16]==5'h1f;
                shd_cs  <= A[20:19]==2'b11 && A[18:17]==2'd0;   // 180000-18ffff
                prot_cs <= A[20:19]==2'b11 && A[18:17]==2'd2;
                ba2mcu_mode <= bac_cs && A[12:11]==2'd0;
                ba2mcu_dsn  <= { ~A[0], A[0] };
                ba2mcu_addr <= { ba2mcu_map, 2'd0, A[10:1] };
                ba2mcu_cs   <= ba2mcu_map | ba2mcu_sft;
            end
            default: begin
                ram_cs <= A[20] & ~A[13]; // 1f0000-1f1fff
                shd_cs <= A[20] & A[13];  // 1f2000-1f3fff
                prot_cs     <= 0;
                ba2mcu_mode <= 0;
                ba2mcu_dsn  <= 3;
                ba2mcu_addr <= 0;
                ba2mcu_cs   <= 0;
            end
        endcase
    end else if(ce) begin // CE will not happen is waitn is asserted
        rom_cs      <= 0;
        ram_cs      <= 0;
        shd_cs      <= 0;
        prot_cs     <= 0;
        ba2mcu_mode <= 0;
        ba2mcu_dsn  <= 3;
        ba2mcu_addr <= 0;
        ba2mcu_cs   <= 0;
    end
end

always @(posedge clk,posedge rst) begin
    if( rst ) begin
        prot_st <= 0;
    end else begin
        if( prot_cs && !wrn && A[12:0]==5 ) prot_st <= dout;
    end
end

always @(posedge clk) begin
    mcu_good <= !mcu_cs || mcu_ok;
    ba_good  <= !ba2mcu_cs || ba2mcu_ok;
    din <=
        ram_cs ? ram_dout :
        shd_cs ? shd_dout :
        prot_cs? (prot_st==8'h45 ? 8'h4e : prot_st==8'h92 ? 8'h15 : 8'h0) :
        ba2mcu_cs ? ba2mcu_data :
        ba2mcu_mode ? ba2mcu_mode_din :
        rom_cs ? mcu_data : 8'hff;
end

// Not sure how long I need to wait
// This is buried inside the DEM-01 chip
// Maybe the IRQ clear is set by HDPSEL simply
reg [7:0] cnt;
wire irq_clr = cnt==1;

always @(posedge clk_cpu ) begin
    if( set_irq )
        cnt <= 8'hff;
    else
        if(cnt!=0) cnt<=cnt-8'd1;
end

jtframe_ff u_ff (
    .clk    ( clk_cpu   ),
    .rst    ( rst       ),
    .cen    ( 1'b1      ),
    .din    ( 1'b1      ),
    .q      (           ),
    .qn     ( irqn      ),
    .set    (           ),    // active high
    .clr    ( irq_clr   ),    // active high
    .sigedge( set_irq   )
);

jtframe_ram #(.AW(13)) u_ram(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( dout      ),
    .addr   ( A[12:0]   ),
    .we     ( ram_we    ),
    .q      ( ram_dout  )
);

jtframe_dual_ram #(.AW(11)) u_shared(
    .clk0   ( clk_cpu   ),
    .clk1   ( clk       ),
    // Main CPU
    .data0  ( main_dout ),
    .addr0  ( main_addr ),
    .we0    ( main_we   ),
    .q0     ( main_din  ),
    // HuC6280
    .data1  ( dout      ),
    .addr1  ( A[10:0]   ),
    .we1    ( shd_we    ),
    .q1     ( shd_dout  )
);

HUC6280 u_huc(
    .CLK        ( clk       ),
    .RST_N      ( ~rst      ),
    .WAIT_N     ( waitn     ),
    .SX         ( SX        ),

    .A          ( A         ),
    .DI         ( din       ),
    .DO         ( dout      ),
    .WR_N       ( wrn       ),
    .RD_N       ( rdn       ),

    .RDY        ( 1'b1      ),
    .NMI_N      ( 1'b1      ),
    .IRQ1_N     ( irqn      ),
    .IRQ2_N     ( irq2n     ),

    .CE         ( ce        ),
    .CEK_N      ( cek_n     ),
    .CE7_N      ( ce7_n     ),
    .CER_N      ( cer_n     ),
    // Unused
    .PRE_RD     (           ),
    .PRE_WR     (           ),
    .HSM        (           ),
    .O          (           ),
    .K          ( 8'd0      ),
    .VDCNUM     ( 1'b0      ),
    .AUD_LDATA  (           ),
    .AUD_RDATA  (           )
);

endmodule