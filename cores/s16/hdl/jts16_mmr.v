/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 10-3-2021 */

module jts16_mmr(
    input              rst,
    input              clk,

    input              flip,
    // CPU interface
    input              char_cs,
    input      [11:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dswn,

    // Video registers
    output reg [15:0]  scr1_pages,
    output reg [15:0]  scr2_pages,

    output reg [15:0]  scr1_hpos,
    output reg [15:0]  scr1_vpos,

    output reg [15:0]  scr2_hpos,
    output reg [15:0]  scr2_vpos,

    // Row/col scroll are set here for S16B
    inout              rowscr1_en,
    inout              rowscr2_en,
    inout              colscr1_en,
    inout              colscr2_en,

    input              altscr1_en,
    input              altscr2_en,
    // status dump
    input      [ 7:0]  st_addr,
    output reg [ 7:0]  st_dout
);

parameter MODEL=0;  // 0 = S16A, 1 = S16B

reg [15:0]  scr1_pages_flip, scr2_pages_flip,
            scr1_pages_nofl, scr2_pages_nofl,
            // S16B only:
            scr1_pages_alt, scr2_pages_alt,
            scr1_vpos_alt,  scr2_vpos_alt,
            scr1_hpos_alt,  scr2_hpos_alt,
            scr1_pages_std, scr2_pages_std,
            scr1_vpos_std,  scr2_vpos_std,
            scr1_hpos_std,  scr2_hpos_std;

generate
    if( MODEL==1 ) begin
        assign rowscr1_en = scr1_hpos[15];
        assign rowscr2_en = scr2_hpos[15];
        assign colscr1_en = scr1_vpos[15];
        assign colscr2_en = scr2_vpos[15];
    end
endgenerate

function [15:0] bytemux( input [15:0] old );
    bytemux = { dswn[1] ? old[15:8] : cpu_dout[15:8], dswn[0] ? old[7:0] : cpu_dout[7:0] };
endfunction

`ifdef SIMULATION
    reg [15:0] sim_cfg[0:511];

    initial begin
        $readmemh( "mmr.hex", sim_cfg );

        if( MODEL==0 ) begin
            scr1_pages_flip = sim_cfg[9'h08e>>1];
            scr1_pages_nofl = sim_cfg[9'h09e>>1];
            scr2_pages_flip = sim_cfg[9'h08c>>1];
            scr2_pages_nofl = sim_cfg[9'h09c>>1];
            scr1_vpos       = sim_cfg[9'h124>>1];
            scr2_vpos       = sim_cfg[9'h126>>1];
            scr1_hpos       = sim_cfg[9'h1f8>>1];
            scr2_hpos       = sim_cfg[9'h1fa>>1];
        end else begin
            scr1_pages_std  = sim_cfg[9'h080>>1];
            scr2_pages_std  = sim_cfg[9'h082>>1];
            scr1_pages_alt  = sim_cfg[9'h084>>1];
            scr2_pages_alt  = sim_cfg[9'h086>>1];
            scr1_vpos_std   = sim_cfg[9'h090>>1];
            scr2_vpos_std   = sim_cfg[9'h092>>1];
            scr1_vpos_alt   = sim_cfg[9'h094>>1];
            scr2_vpos_alt   = sim_cfg[9'h096>>1];
            scr1_hpos_std   = sim_cfg[9'h098>>1];
            scr2_hpos_std   = sim_cfg[9'h09a>>1];
            scr1_hpos_alt   = sim_cfg[9'h09c>>1];
            scr2_hpos_alt   = sim_cfg[9'h09e>>1];
        end
    end
`endif

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scr1_pages      <= 0;
        scr2_pages      <= 0;
        scr1_pages_alt  <= 0;
        scr1_pages_std  <= 0;
        scr2_pages_alt  <= 0;
        scr2_pages_std  <= 0;
        scr1_vpos_alt   <= 0;
        scr2_vpos_alt   <= 0;
        scr1_hpos_alt   <= 0;
        scr2_hpos_alt   <= 0;
        scr1_vpos_std   <= 0;
        scr2_vpos_std   <= 0;
        scr1_hpos_std   <= 0;
        scr2_hpos_std   <= 0;
        scr1_vpos       <= 0;
        scr2_vpos       <= 0;
        scr1_hpos       <= 0;
        scr2_hpos       <= 0;
        if( MODEL==0 ) begin
            scr1_pages_flip <= 0;
            scr2_pages_flip <= 0;
            scr1_pages_nofl <= 0;
            scr2_pages_nofl <= 0;
        end
    end else begin
        if( MODEL==0 ) begin
            scr1_pages <= flip ? scr1_pages_flip : scr1_pages_nofl;
            scr2_pages <= flip ? scr2_pages_flip : scr2_pages_nofl;
        end else begin
            scr1_pages <= altscr1_en ? scr1_pages_alt : scr1_pages_std;
            scr2_pages <= altscr2_en ? scr2_pages_alt : scr2_pages_std;
            scr1_vpos  <= altscr1_en ? scr1_vpos_alt : scr1_vpos_std;
            scr2_vpos  <= altscr2_en ? scr2_vpos_alt : scr2_vpos_std;
            scr1_hpos  <= altscr1_en ? scr1_hpos_alt : scr1_hpos_std;
            scr2_hpos  <= altscr2_en ? scr2_hpos_alt : scr2_hpos_std;
        end
        if( char_cs && cpu_addr[11:9]==3'b111 && dswn!=2'b11) begin
            if( MODEL==0 ) begin
                case( {cpu_addr[8:1], 1'b0} )
                    9'h08e: scr1_pages_flip <= bytemux( scr1_pages_flip );
                    9'h09e: scr1_pages_nofl <= bytemux( scr1_pages_nofl );
                    9'h08c: scr2_pages_flip <= bytemux( scr2_pages_flip );
                    9'h09c: scr2_pages_nofl <= bytemux( scr2_pages_nofl );
                    9'h124: scr1_vpos       <= bytemux( scr1_vpos       );
                    9'h126: scr2_vpos       <= bytemux( scr2_vpos       );
                    9'h1f8: scr1_hpos       <= bytemux( scr1_hpos       );
                    9'h1fa: scr2_hpos       <= bytemux( scr2_hpos       );
                    default:;
                endcase
            end else begin // System 16B
                case( {cpu_addr[8:1], 1'b0} )
                    9'h080: scr1_pages_std  <= bytemux( scr1_pages      );
                    9'h082: scr2_pages_std  <= bytemux( scr2_pages      );
                    9'h084: scr1_pages_alt  <= bytemux( scr1_pages_alt  );
                    9'h086: scr2_pages_alt  <= bytemux( scr2_pages_alt  );
                    9'h090: scr1_vpos_std   <= bytemux( scr1_vpos       );
                    9'h092: scr2_vpos_std   <= bytemux( scr2_vpos       );
                    9'h094: scr1_vpos_alt   <= bytemux( scr1_vpos_alt   );
                    9'h096: scr2_vpos_alt   <= bytemux( scr2_vpos_alt   );
                    9'h098: scr1_hpos_std   <= bytemux( scr1_hpos       );
                    9'h09a: scr2_hpos_std   <= bytemux( scr2_hpos       );
                    9'h09c: scr1_hpos_alt   <= bytemux( scr1_hpos_alt   );
                    9'h09e: scr2_hpos_alt   <= bytemux( scr2_hpos_alt   );
                    default:;
                endcase
            end
        end
    end
end

always @(posedge clk) begin
    case( st_addr )
        0:  st_dout <= MODEL ? scr1_pages[7:0]  : scr1_pages_nofl[ 7:0];
        1:  st_dout <= MODEL ? scr1_pages[15:8] : scr1_pages_nofl[15:8];
        2:  st_dout <= MODEL ? scr2_pages[7:0]  : scr2_pages_nofl[ 7:0];
        3:  st_dout <= MODEL ? scr2_pages[15:8] : scr2_pages_nofl[15:8];
        4:  st_dout <= scr1_vpos[ 7:0];
        5:  st_dout <= scr1_vpos[15:8];
        6:  st_dout <= scr2_vpos[ 7:0];
        7:  st_dout <= scr2_vpos[15:8];
        8:  st_dout <= scr1_hpos[ 7:0];
        9:  st_dout <= scr1_hpos[15:8];
        8'ha: st_dout <= scr2_hpos[ 7:0];
        8'hb: st_dout <= scr2_hpos[15:8];
        8'hc: st_dout <= { 2'd0, colscr2_en, rowscr2_en, 2'd0, colscr1_en, rowscr1_en };
        default: st_dout <= 0;
    endcase
end

endmodule