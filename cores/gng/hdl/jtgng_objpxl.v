/*  This file is part of JTGNG.
    JTGNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTGNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTGNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-1-2019 */

// Object Line Buffer

module jtgng_objpxl #(
    parameter          dw=4,
                       palw=0,
                       AW=8,
    parameter [AW-1:0] PXL_DLY=7,
    parameter [AW-1:0] H0=0
    )(
    input              rst,
    input              clk,
    input              cen /*direct_enable*/,
    input              pxl_cen /*direct_enable*/,
    // screen
    input              LHBL,
    input              flip,
    input       [8:0]  posx,
    input              line,
    // pixel data
    input       [dw-1:0]  new_pxl,
    output      [dw-1:0]  obj_pxl
);

localparam lineA=1'b0, lineB=1'b1;

// Line colour buffer

reg [AW-1:0] addrA, addrB;
reg [AW-1:0] Hcnt;

wire [dw-1:0] lineA_q, lineB_q;
reg  [dw-1:0] dataA, dataB;
reg           weA, weB;
reg           pxlbuf_line;

always @(posedge clk, posedge rst)
    if( rst )
        pxlbuf_line <= lineA;
    else if(cen) begin
        pxlbuf_line <= line;
    end

always @(posedge clk) if(pxl_cen) begin
    if( !LHBL ) Hcnt <= AW==8 ? 8'd0 : (H0-PXL_DLY);
    else Hcnt <= Hcnt+1'd1;
end

wire [dw-1:0] blank = {dw{1'b1}};

reg [AW-1:0] addr_wr;
reg [dw-1:0] data_wr;
reg          pxl_wr;

always @(posedge clk) if(cen) begin
    data_wr <= new_pxl;
    addr_wr <= {AW{flip}} ^ posx[AW-1:0];
    // pxl_wr enable if !posx[8] for AW=8, always if AW=9
    pxl_wr  <= (AW!=8 || !posx[8]) && (new_pxl[dw-palw-1:0]!=blank[dw-palw-1:0]); // && !DISPTM_b && LHBL;
end

reg [   3:0] st;
reg [dw-1:0] obj_pxl0;

always @(posedge clk,posedge rst) begin
    if(rst) begin
        st <= 4'b0;
    end else begin
        st <= { pxl_cen, st[3:1] };
        if( st[2] ) obj_pxl0 <= pxlbuf_line==lineA ? lineA_q : lineB_q;
    end
end

always @(*) begin
    if( pxlbuf_line == lineA ) begin
        // lineA readout
        addrA = Hcnt;
        weA   = LHBL && st[0];
        dataA = blank;
        // lineB writein
        addrB = addr_wr;
        weB   = pxl_wr;
        dataB = data_wr;
    end else begin
        // lineA writein
        addrA = addr_wr;
        weA   = pxl_wr;
        dataA = data_wr;
        // lineB readout
        addrB = Hcnt;
        weB   = LHBL && st[0];
        dataB = blank;
    end
end

jtframe_ram #(.aw(AW),.dw(dw),.cen_rd(0)) lineA_buf(
    .clk     ( clk             ),
    .cen     ( 1'b1            ),
    .addr    ( addrA           ),
    .data    ( dataA           ),
    .we      ( weA             ),
    .q       ( lineA_q         )
);

jtframe_ram #(.aw(AW),.dw(dw),.cen_rd(0)) lineB_buf(
    .clk     ( clk             ),
    .cen     ( 1'b1            ),
    .addr    ( addrB           ),
    .data    ( dataB           ),
    .we      ( weB             ),
    .q       ( lineB_q         )
);

generate
    if( AW==8 )begin : shifter
    // Delay pixel output in order to be aligned with the other layers
    jtframe_sh #(.width(dw), .stages(PXL_DLY)) u_sh(
        .clk            ( clk           ),
        .clk_en         ( pxl_cen       ), // important: pixel cen!
        .din            ( obj_pxl0      ),
        .drop           ( obj_pxl       )
    );
    end else begin : noshifter
        assign obj_pxl = obj_pxl0;
    end
endgenerate

endmodule // jtgng_objpxl