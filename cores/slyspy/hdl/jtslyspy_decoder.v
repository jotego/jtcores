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
    Date: 28-2-2022 */

module jtcop_decoder(
    input              rst,
    input              clk,
    input       [23:1] A,
    input              ASn,
    input              RnW,
    input              LVBL,
    input              LVBL_l,
    input              sec2,
    input              service,
    input       [ 1:0] coin,
    output reg         rom_cs,
    output reg         eep_cs,
    output reg         prisel_cs,
    output reg         mixpsel_cs,
    output reg         nexin_cs,       // used as the counter control signals
    output reg         nexout_cs,      // used as the counter control signals
    output reg         nexrm1,         // used on Heavy Barrel PCB for the track balls
    output             disp_cs,
    output reg         sysram_cs,
    output reg         vint_clr,
    output reg         cblk,
    output reg  [ 2:0] read_cs,
    // BAC06 chips
    output reg         fmode_cs,
    output reg         fsft_cs,
    output reg         fmap_cs,
    output reg         bmode_cs,
    output reg         bsft_cs,
    output reg         bmap_cs,
    output reg         nexrm0_cs,
    output reg         cmode_cs,
    output reg         csft_cs,
    output reg         cmap_cs,
    // Object
    output reg         obj_cs,       // called MIX in the schematics
    output             obj_copy,     // called *DM in the schematics
    // Palette
    output reg [ 1:0]  pal_cs,
    // HuC6820 protection
    output reg         huc_cs,      // shared memory with HuC6820
    // sound
    output reg         snreq,
    // MCU/SUB CPU
    output reg [5:0]   sec          // bit 2 is unused
);

reg  [1:0] mapsel, premap;
reg  nexinl, nexoutl;
reg  [6:0] timeout;

assign disp_cs = |{fmap_cs, bmap_cs, cmap_cs, fsft_cs, bsft_cs, csft_cs };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        premap <= 0;
        mapsel <= 0;
        nexinl <= 0;
        nexoutl<= 0;
    end else begin
        nexinl <= nexin_cs;
        nexoutl<= nexout_cs;
        if( nexin_cs & ~nexinl ) premap <= premap+2'd1;
        if( nexout_cs & ~nexoutl ) premap <= 0;
        if( ASn ) mapsel <= premap;
    end
end

// clear the IRQ automatically for now
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        timeout <= 0;
    end else begin
        timeout <= (!LVBL && LVBL_l) ? 7'h7f : timeout>0 ? timeout-7'd1 : 7'd0;
        vint_clr <= timeout==1;
    end
end

// Triggering it once per frame, not sure if the
// CPU has it mapped to an address, like Robocop
assign obj_copy = !LVBL && LVBL_l;

always @(*) begin
    eep_cs     = 0;
    // third BAC06 chip
    nexrm0_cs  = 0;
    nexrm1     = 0;
    prisel_cs  = 0;
    //obj_copy   = 0;
    snreq      = 0;
    mixpsel_cs = 0;
    cblk       = 0;
    read_cs    = 0;
    pal_cs     = 0;
    sysram_cs  = 0;
    sec[5:3]   = { service, coin };
    sec[2]     = sec2;
    sec[1:0]   = 0;
    huc_cs     = 0;

    if( !ASn && A[21:20]==3 )
        case( A[19:14] )
            6'h01: sysram_cs = 1;  // 0x30'4000
            6'h4: pal_cs[0] = 1;   // 0x31'0000
            6'h5: case( A[3:1] )   // 0x31'4000
                3'h0: snreq = 1;
                3'h1: prisel_cs = 1; // 0x31'4002
                3'h4: read_cs[2] = 1; // DIP sw
                3'h5: read_cs[0] = 1; // cabinet IO
                3'h6: read_cs[1] = 1; // system I/O
                default:;
            endcase
            6'h7: nexrm0_cs = 1; // protection
            default:;
        endcase
end

always @* begin
    rom_cs    = !ASn && A[21:20]==2'b00 && A[19:16]<8 && RnW; // although not all sockets are populated
    cmode_cs  = !ASn && A[21:20]==2'b11 && A[16:14]==0 && A[12:11]==0; // 30'0000
    csft_cs   = !ASn && A[21:20]==2'b11 && A[16:14]==0 && A[12:11]==1; // 30'0800
    cmap_cs   = !ASn && A[21:20]==2'b11 && A[16:14]==0 && A[12:11]==2; // 30'1000
    obj_cs    = !ASn && A[21:20]==2'b11 && A[16:14]==2;                // 30'8000
    // 24'0000
    nexin_cs  = !ASn && A[21:16]==6'h24 && A[15:13]==2 &&  RnW; // cnt up
    nexout_cs = !ASn && A[21:16]==6'h24 && A[15:13]==5 && !RnW; // cnt clr
    bmode_cs  = !ASn && A[21:16]==6'h24 && A[15:13]==0 && mapsel==0;
    bsft_cs   = !ASn && A[21:16]==6'h24 && A[15:13]==1 && mapsel==0;
    bmap_cs   = !ASn && A[21:16]==6'h24 &&
        (   (A[15:13]==0 && mapsel==2) ||
            (A[15:13]==3 && mapsel==0) ||
            (A[15:13]==4 && mapsel==3) ||
            (A[15:13]==6 && mapsel==1) );
    fmode_cs  = !ASn && A[21:16]==6'h24 && A[15:13]==4 && mapsel==0;
    fsft_cs   = !ASn && A[21:16]==6'h24 && A[15:13]==6 && mapsel==0;
    fmap_cs   = !ASn && A[21:16]==6'h24 &&
        (   (A[15:13]==0 && mapsel==3) ||
            (A[15:13]==1 && mapsel==2) ||
            (A[15:13]==4 && mapsel==1) ||
            (A[15:13]==7 && !mapsel[0]) );
end

endmodule