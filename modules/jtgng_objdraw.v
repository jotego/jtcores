/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 11-1-2019 */

module jtgng_objdraw #(parameter 
    ROM_AW   = 16, 
    LAYOUT   = 0,   // 0: GnG, Commando
                    // 1: 1943
    PALW     = 2,
    PALETTE  = 0, // 1 if the palette PROM is used
    PALETTE1_SIMFILE = "", // only for simulation
    PALETTE0_SIMFILE = "" // only for simulation
) (
    input              rst,
    input              clk,     // 24 MHz
    input              cen6,    //  6 MHz
    // screen
    input       [7:0]  VF,
    input       [3:0]  pxlcnt,
    output reg  [8:0]  posx,
    input              flip,
    input              pause,
    // per-line sprite data
    input       [4:0]  objcnt,
    input       [7:0]  objbuf_data,
    // SDRAM interface
    output  reg [ROM_AW-1:0] obj_addr,
    input       [15:0] objrom_data,
    // Palette PROM
    input              OBJON,
    input       [7:0]  prog_addr,
    input              prom_hi_we,
    input              prom_lo_we,
    input       [3:0]  prog_din,
    // pixel data
    output reg  [PALW-1:0]       pospal,
    output reg  [(PALETTE?7:3):0]  new_pxl  // 8 bits if PROMs used, 4 bits otherwise
);

reg [7:0] ADlow;
reg [PALW-1:0] objpal, objpal1;
reg [ROM_AW-15:0] ADhigh;
reg [8:0] objx;
reg obj_vflip, obj_hflip, hover;
wire posvflip;
reg  poshflip;
reg vinzone;

reg poshflip2;

reg [7:0] Vsum;

always @(*) begin
    Vsum = (~VF + { {7{~flip}}, 1'b1})+objbuf_data; // this is equivalent to
    // 2's complement of VF plus object's Y, i.e. a subtraction
    // but flip is used to make it work with flipped screens
    // This is the same formula used on the schematics
end

reg [3:0] Vobj;

always @(posedge clk) if(cen6) begin
    case( pxlcnt[3:0] )
        4'd0: ADlow   <= objbuf_data;
        4'd1: case( LAYOUT )
            default: begin // GnG, Commando
                ADhigh    <= objbuf_data[7:6];
                objpal    <= objbuf_data[5:4];
                obj_vflip <= objbuf_data[3];
                obj_hflip <= objbuf_data[2];
                hover     <= objbuf_data[0];
            end
            1: begin // 1943
                ADhigh    <= objbuf_data[7:5];
                objpal    <= objbuf_data[3:0];
                obj_vflip <= 1'b0;
                obj_hflip <= 1'b0;
                hover     <= objbuf_data[4];
            end
        endcase
        4'd2: begin // Object Y is on objbuf_data at this step
            Vobj    <=  Vsum[3:0];
            vinzone <= &Vsum[7:4];
        end
        4'd3: begin
            objx <= { hover, objbuf_data };
        end
        default:;
    endcase
    if( pxlcnt[1:0]==2'd3 ) begin
        obj_addr <= (!vinzone || objcnt==5'd0) ? {ROM_AW{1'b0}} :
            { ADhigh, ADlow, Vobj^{4{~obj_vflip}}, pxlcnt[3:2]^{2{obj_hflip}} };
    end
end


// ROM data depacking

reg [3:0] z,y,x,w;
reg [8:0] posx1;

always @(posedge clk) if(cen6) begin
    if( pxlcnt[3:0]==4'h7 ) begin
        objpal1   <= objpal;
        poshflip2 <= obj_hflip;
        posx1     <= objx;
    end else begin
        posx1     <= posx1 + 9'b1;
    end
    case( pxlcnt[1:0] )
        2'd3:  begin // new data
                {z,y,x,w} <= objrom_data;
            end
        default:
            if( poshflip2 ) begin
                z <= z >> 1;
                y <= y >> 1;
                x <= x >> 1;
                w <= w >> 1;
            end else begin
                z <= z << 1;
                y <= y << 1;
                x <= x << 1;
                w <= w << 1;
            end
    endcase
end

generate
    if( PALETTE == 1 ) begin
        wire [7:0] prom_dout;
        wire [3:0] new_col = { w[3],x[3],y[3],z[3] }; // 1943 has bits reversed for palette PROMs
        wire [7:0] pal_addr = { objpal1, new_col };

        jtgng_prom #(.aw(8),.dw(4), .simfile(PALETTE1_SIMFILE) ) u_prom_msb(
            .clk    ( clk            ),
            .cen    ( cen6           ),
            .data   ( prog_din       ),
            .rd_addr( pal_addr       ),
            .wr_addr( prog_addr      ),
            .we     ( prom_hi_we     ),
            .q      ( prom_dout[7:4] )
        );

        jtgng_prom #(.aw(8),.dw(4), .simfile(PALETTE0_SIMFILE) ) u_prom_lsb(
            .clk    ( clk            ),
            .cen    ( cen6           ),
            .data   ( prog_din       ),
            .rd_addr( pal_addr       ),
            .wr_addr( prog_addr      ),
            .we     ( prom_lo_we     ),
            .q      ( prom_dout[3:0] )
        );

        reg  [8:0] posx2;

        `ifdef AVATARS
            reg  [7:0] avatar_pxl;
            always @(posedge clk) if(cen6)
                avatar_pxl <= { objpal1, z[3], y[3], x[3], w[3] };
        `else
            wire [7:0] avatar_pxl = prom_dout;
        `endif

        always @(posedge clk ) if(cen6) begin
            pospal <= {PALW{1'b0}}; // it is actually unused on the upper level
            posx2 <= posx1; // 1-clk delay to match the PROM data
            if( OBJON ) begin
                new_pxl <= pause ? avatar_pxl : prom_dout;
                posx    <= posx2;
            end else begin
                new_pxl <= 8'hf;
                posx    <= 9'h100;
            end
        end

    end else begin
        // No palette PROMs
        always @(posedge clk) if(cen6) begin
            new_pxl <= poshflip2 ? {w[0],x[0],y[0],z[0]} : {w[3],x[3],y[3],z[3]};
            posx    <= posx1;
            pospal  <= objpal1;
        end
    end
endgenerate

endmodule // jtgng_objdraw