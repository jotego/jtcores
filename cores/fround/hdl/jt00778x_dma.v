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
    Date: 30-12-2024 */

module jt00778x_dma#(parameter PW=10)(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             objbufinit,
    input             lvbl,

    input             dma_on,
    output reg        dma_bsy=0,
    input    [PW-1:0] obj_dx, obj_dy,

    output     [13:1] oram_addr,
    input      [15:0] oram_dout,
    output reg [15:0] oram_din,
    output reg        oram_we
);

localparam [   2:0] PARSED_AREA={3'b110};

reg         beflag=0, obi_l=0,obj_en=0,dma_clr=0, dma_cen=0;
reg  [13:1] cpr_addr=0; // copy read  address
reg  [10:1] cpw_addr=0; // copy write address
reg  [ 7:0] hibuf;
wire [ 4:1] nx_cpra;
wire [11:1] nx_cpwa;
`ifdef SIMULATION
wire [13:0] cpr_afull = {cpr_addr,1'b0};
wire [13:0] cpw_afull = {PARSED_AREA,cpw_addr,1'b0};
`endif

assign oram_addr = oram_we  ? { PARSED_AREA, cpw_addr } : cpr_addr;
assign nx_cpwa    = { 1'b1, cpw_addr } + 1'h1;
assign nx_cpra  = {1'd0, cpr_addr[3:1]} + 4'd1;

always @(posedge clk) begin
    if( rst ) begin
        oram_we  <= 0;
        dma_bsy  <= 0;
        obj_en   <= 0;
        oram_din <= 0;
        beflag   <= 0;
        obi_l    <= 0;
    end else if( pxl_cen ) begin
        obi_l <= objbufinit;
        if( objbufinit && !obi_l ) begin
            dma_bsy <= 1;
            obj_en  <= ~dma_on;
        end
        dma_cen <= ~dma_cen; // not really a cen, must be combined with pxl_cen
        if( lvbl ) begin
            dma_clr  <= 1;
            cpr_addr <= 0;
            cpw_addr <= 0;
            oram_we  <= 0;
            oram_din <= 0;
            beflag   <= 0;
        end else if( dma_bsy ) begin
            if( dma_clr && dma_cen ) begin
                { dma_clr, cpw_addr } <= nx_cpwa;
                oram_we <= obj_en & nx_cpwa[11];
            end else if( !dma_clr ) begin // direct copy
                if( !dma_cen ) begin
                    case( cpr_addr[3:1] )
                        0: begin
                            cpw_addr[10:3] <= oram_dout[7:0];
                            oram_din <= 0;
                            beflag   <= oram_dout[15] && obj_en;
                        end
                        2: begin // flags
                            cpw_addr[2:1] <= 3;
                            oram_din <= { 1'b1,5'd0, oram_dout[9:0] };
                            oram_we  <= beflag;
                            // if(beflag) $display("OBJ %X flags %X (hsize=%d, vsize=%d)",
                            //     cpw_addr[10:3], { 1'b1,5'd0, oram_dout[9:0] },
                            //     8'h10<<oram_dout[5:4], 8'h10<<oram_dout[7:6] );
                        end
                        3: begin // code
                            cpw_addr[2:1] <= 0;
                            oram_din <= oram_dout;
                            oram_we  <= beflag;
                            // if(beflag) $display("        code %X", oram_dout );
                        end
                        4: hibuf <= oram_dout[7:0];
                        5: begin // x
                            cpw_addr[2:1] <= 1;
                            oram_din      <= {hibuf,oram_dout[15:8]}-{{16-PW{1'b0}},obj_dx};
                            oram_we  <= beflag;
                            // if(beflag) $display("        x =  %X", {oram_din[15:8],oram_dout[15:8]} );
                        end
                        6: hibuf <= oram_dout[7:0];
                        7: begin // y
                            cpw_addr[2:1] <= 2;
                            oram_din      <= {hibuf,oram_dout[15:8]}-{{16-PW{1'b0}},obj_dy};
                            oram_we  <= beflag;
                            // if(beflag) $display("        y =  %X", {oram_din[15:8],oram_dout[15:8]} );
                        end
                    endcase
                end else begin
                    cpr_addr[3:1] <= nx_cpra[3:1];
                    if( nx_cpra[4] ) begin
                        cpr_addr[13:4] <= cpr_addr[13:4]+10'h5;
                        dma_bsy <= cpr_addr<'h17d7;
                    end
                    oram_we <= 0;
                end
            end
        end
    end
end

endmodule