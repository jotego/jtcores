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
    Date: 21-1-2019 */

module jt1942_objdraw(
    input              rst,
    input              clk,     //
    input              cen6,    //  6 MHz
    input       [1:0]  game_id,
    // screen
    input              flip,
    input       [7:0]  V,
    input       [8:0]  H,
    input       [3:0]  pxlcnt,
    input              pxlcnt_lsb,
    input       [3:0]  bufcnt,
    // per-line sprite data
    input       [7:0]  objbuf_data0,
    input       [7:0]  objbuf_data1,
    input       [7:0]  objbuf_data2,
    input       [7:0]  objbuf_data3,
    // SDRAM interface
    output reg  [14:0] obj_addr,
    input       [15:0] obj_data,
    input              obj_ok,
    // Palette PROM
    input   [7:0]      prog_addr,
    input              prom_pal_we,
    input   [3:0]      prog_din,
    // pixel data
    output reg  [8:0]  posx,
    output reg  [3:0]  new_pxl
);

localparam [1:0] VULGUS   = 2'd1,
                 HIGEMARU = 2'd2;

reg [3:0] CD; // colour data
reg [7:0] V2C;
wire [7:0] VF = {8{flip}} ^V;
reg VINZONE;

reg [1:0] vlen;
reg VINcmp, VINlen, Veq, Vlt; // Vgt;

reg  hige, vulgus;

// signal aliases
wire [7:0] next_AD    = objbuf_data0;
wire [1:0] next_vlen  = objbuf_data1[7:6];
wire       next_ADext = objbuf_data1[5];
wire       next_hover = hige ? 1'b0: objbuf_data1[4];
wire       next_hflip = hige && objbuf_data1[4];
wire       next_vflip = hige && objbuf_data1[5];
wire [3:0] next_CD    = objbuf_data1[3:0];
wire [7:0] objy       = objbuf_data2;
wire [8:0] objx       = { next_hover, objbuf_data3 };

wire [7:0] LVBETA = objy + V2C;
wire [7:0] VBETA = ~LVBETA;

reg        hflip;

always @(posedge clk) begin
    hige   <= game_id==HIGEMARU;
    vulgus <= game_id==VULGUS;
end

always @(*) begin
    // comparison side of VINZONE
    // Vgt = VBETA  > ~objy;
    Veq = VBETA == ~objy;
    Vlt = VBETA  < ~objy;
    VINcmp = /*ADext ? Vgt :*/ (Veq|Vlt);
    if( !hige ) begin
        case( next_vlen )
            2'b00: VINlen = &LVBETA[7:4]; // 16 lines
            2'b01: VINlen = &LVBETA[7:5]; // 32 lines
            2'b10: VINlen = &LVBETA[7:6]; // 64 lines
            2'b11: VINlen = 1'b1;
        endcase // vlen
    end else begin // Higemaru
        VINlen = &LVBETA[7:4]; // 16 lines
    end
    //VINZONE = ~(VINcmp & VINlen);
    VINZONE = ~(VINcmp & VINlen);
end

reg [14:0] pre_addr;
reg VINZONE2, VINZONE3;
reg [8:0] posx1, posx2;

localparam [3:0] DATAREAD = 4'd7; //6,8,9,10,11,12,16

always @(posedge clk) begin
    V2C <= ~VF + { {7{~flip}}, 1'b1 }; // V 2's complement
    if( bufcnt==4'h9 ) begin // set new address
        case( game_id )
            VULGUS:   pre_addr[14:10] <= {1'b0, next_AD[7:4]};
            HIGEMARU: pre_addr[14:10] <= {2'b0, next_AD[6:4]};
            default:  pre_addr[14:10] <= {next_AD[7], next_ADext, next_AD[6:4]};
        endcase
        if( !hige ) begin
            case( next_vlen )
                2'd0: pre_addr[9:6] <= next_AD[3:0]; // 16
                2'd1: pre_addr[9:6] <= { next_AD[3:1], ~LVBETA[4] }; // 32
                2'd2: pre_addr[9:6] <= { next_AD[3:2], ~LVBETA[5], ~LVBETA[4] }; // 64
                2'd3: pre_addr[9:6] <= ~LVBETA[7:4];
            endcase
        end else begin
            pre_addr[9:6] <= next_AD[3:0]; // 16
        end
        pre_addr[4:1] <= (~LVBETA[3:0]) ^ {4{next_vflip}};
        hflip         <= next_hflip;
        VINZONE2 <= VINZONE; // active low
        CD   <= next_CD;
    end
end

reg [1:0] hcnt; // read order 2,3,0,1

always @* begin
    obj_addr[14:2] = { pre_addr[14:6], pre_addr[4:1] };
    obj_addr[1:0] = hcnt;
    if(hige) obj_addr = { pre_addr[14:6], hcnt[1]^hflip, pre_addr[4:1], hcnt[0]^hflip };
end

// ROM data depacking

reg  [3:0] z,y,x,w;
reg  [3:0] obj_wxyz;
wire [7:0] pal_addr = { CD, obj_wxyz};
reg  [2:0] draw;
wire       pre_draw = bufcnt[3] && pxlcnt_lsb && !VINZONE2 && obj_ok;

always @(posedge clk) begin
    if( !bufcnt[3] ) hcnt <= 2'd0;
    draw <= { draw[1:0], pre_draw };
    if( pre_draw ) begin
        posx1 <= objx+{5'd0, pxlcnt};
        if( pxlcnt[1:0] == 2'b0 ) begin
            {z,y,x,w} <= obj_data;
            case( hcnt )
                2'd2: hcnt <= 2'd3;
                2'd3: hcnt <= 2'd0;
                2'd0: hcnt <= 2'd1;
                2'd1: hcnt <= 2'd2;
            endcase
        end else begin
            if( hflip ) begin
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
    	end
    end
end

always @(*) begin
    case( game_id )
        VULGUS:   obj_wxyz = {y[3],z[3],w[3],x[3]};
        HIGEMARU: obj_wxyz = hflip ? {y[0],z[0],w[0],x[0]} : {y[3],z[3],w[3],x[3]};
        default : obj_wxyz = {w[3],x[3],y[3],z[3]};
    endcase
end

wire [3:0] prom_dout;

always @(posedge clk ) begin
    if(draw[0]) posx2 <= posx1;
    if(draw[1]) begin
        new_pxl <= prom_dout;
        posx    <= hige ? { 1'b0, posx2[7:0]} : posx2; // Higemaru's OBJ wrap around
    end else begin
        new_pxl <= 4'hf;
        posx    <= 9'h100;
    end
end

jtframe_prom #(.AW(8),.DW(4),
    .SIMFILE("../../../rom/1942/sb-8.k3")
) u_prom_k3(
    .clk    ( clk            ),
    .cen    ( 1'b1           ),
    .data   ( prog_din       ),
    .rd_addr( pal_addr       ),
    .wr_addr( prog_addr      ),
    .we     ( prom_pal_we    ),
    .q      ( prom_dout      )
);

endmodule // jtgng_objdraw