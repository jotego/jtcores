
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
    Date: 20-1-2019 */

// 1942 Object Generation


module jt1942_objtiming(
    input              rst,
    input              clk,
    input              cen6,    //  6 MHz
    input        [1:0] game_id,
    // screen
    input   [7:0]      V,
    input   [8:0]      H,
    input              LHBL,
    input              HINIT,
    input              flip,
    input              obj_ok,
    output reg [3:0]   pxlcnt,
    output reg [4:0]   objcnt,
    output reg [3:0]   bufcnt,
    output reg         line,
    output reg         pxlcnt_lsb,
    output reg         over
);

reg last_LHBL, okdly;
wire rom_good = obj_ok & okdly;
wire posedge_LHBL = LHBL && !last_LHBL;
reg [4:0] auxcnt;

// The 1942 logo effect still doesn't look perfect
// the second round if flip is set
// there appear to be a 2-pixel wide gap in between
// the two halves of the CAPCOM logo
// If flip is off, the second round logo is rendered
// correctly
always @(*) begin
    objcnt = auxcnt;
    if( (V[7]^flip) && auxcnt> 'hf && game_id==0)
        objcnt[3] = objcnt[3]^1;
end

always @(posedge clk) begin
    last_LHBL <= LHBL;
    okdly     <= obj_ok;
    if( posedge_LHBL ) begin
        pxlcnt    <= 0;
        over      <= 0;
        bufcnt    <= 0;
        pxlcnt_lsb<= 0;
        auxcnt    <= 0;
    end else begin // image scan
        if(bufcnt!=4'b1010)
            bufcnt <= bufcnt+4'd1;
        else if(rom_good && !over ) begin
            {pxlcnt, pxlcnt_lsb} <= {pxlcnt,pxlcnt_lsb}+5'd1;
            if( &{pxlcnt,pxlcnt_lsb} ) begin
                bufcnt <= 4'd0;
                over   <= auxcnt == 5'h17;
                auxcnt <= auxcnt + 5'h1;
            end
        end
        else if(!rom_good) pxlcnt_lsb <= 1'b0;
    end
end

always @(posedge clk) begin
    if( rst )
        line <= 1'b0;
    else if(cen6) begin
        if( HINIT ) line <= ~line;
    end
end

// 1942: left part of the vertical screen (V[7]==1)
// reads objects 0h to 17h, right half read 0h to Fh and then 18h to 1fh
// so the 1942 logo effect occurs. But this should take the flip bit into
// account to work correctly and that isn't in the schematics. Again,
// the schematics look like coming from a prototype version
// Vulgus: objects 0 to 17 only

/* Original sequence
`ifdef VULGUS
reg vulgus_sr;
always @(posedge clk, posedge rst)
    if( rst ) begin
        vulgus_sr  <= 1'b1;
        objcnt[4:3] <= 2'b0;
    end else if(cen6) begin
        if( &H[6:4]==1'b1 && pxlcnt==4'd7 ) begin
            { vulgus_sr, objcnt[4:3] } <= { objcnt[4:3], vulgus_sr };
        end
    end
`endif
always @(*) begin
    // This is the original scan sequence of each game, that counts objects
    `ifdef VULGUS
        // scan sequence measured on real PCB. Region objcnt[4:3]==2'b11 is not scanned.
        objcnt[2:0] = H[6:4];
    `else
        // 1942 scan sequence from schematics
        objcnt[4] = H[8]^~H[7];
        objcnt[3] = (V[7] & objcnt[4]) ^ ~H[7];
        objcnt[2:0] = H[6:4];
    `endif
end
*/

endmodule // jt1942_obj