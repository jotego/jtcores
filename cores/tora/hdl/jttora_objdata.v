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
    Date: 1-1-2023 */

module jttora_objdata(
    input               rst,
    input               clk,
    // screen
    input        [8:0]  vdump,
    input               flip,
    input               hs,
    // per-line sprite data
    output      [ 9:0]  lut_addr,
    input       [11:0]  lut_data,
    // Draw data
    output reg  [11:0]  dr_code,
    output reg  [ 8:0]  dr_xpos,
    output reg          dr_hflip,
    output reg          dr_vflip,
    output reg  [ 3:0]  dr_pal,
    output reg  [ 3:0]  dr_ysub,
    output reg          dr_start,
    input               dr_busy,

    input         [7:0] debug_bus
);

parameter VINV=1; // Assumes that the y position is inverted (needed for Tora, but not Biocom)

localparam [7:0] OBJMAX=159;

reg  [ 8:0] Vsum, vf;
reg  [ 3:0] Vobj;
reg  [ 1:0] st;
reg  [ 7:0] obj_cnt;
reg  [ 4:0] drawn;  // max 31 objects per line
reg         vinzone, done, hsl, cen=0;

assign lut_addr = { obj_cnt, st };

always @(*) begin
    vf   = vdump^{flip,{8{flip^~VINV[0]}}};
    Vsum = vf + lut_data[8:0] + 8'd1;
end

always @(posedge clk) begin
    cen <= ~cen;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st       <= 0;
        done     <= 0;
        obj_cnt  <= 0;
        drawn    <= 0;
        hsl      <= 0;
        dr_start <= 0;
        dr_xpos  <= 0;
        dr_ysub  <= 0;
        dr_vflip <= 0;
        dr_hflip <= 0;
        dr_pal   <= 0;
    end else begin
        hsl      <= hs;
        dr_start <= 0;
        if( ~hs & hsl ) begin
            drawn   <= 0;
            obj_cnt <= OBJMAX;
            st      <= 0;
            done    <= 0;
        end
        if( !done && cen ) begin
            st <= st + 1'd1;
            case( st )
                0: dr_code <= lut_data;
                1: begin
                    dr_vflip <= lut_data[0]^~VINV[0];
                    dr_hflip <= ~lut_data[1];
                    dr_pal   <= lut_data[5:2];
                end
                2: begin // Object Y is on objbuf_data at this step
                    dr_ysub <=  Vsum[3:0];
                    vinzone <= &Vsum[8:4];
                end
                3: begin
                    dr_xpos <= lut_data[8:0] + 9'd13;
                    if( !vinzone || !dr_busy ) begin
                        obj_cnt <= obj_cnt - 1'd1;
                        if( vinzone ) drawn <= drawn + 1'd1;
                        done <= (vinzone && &drawn) || obj_cnt==0;
                    end
                    if( vinzone ) begin
                        dr_start <= !dr_busy;
                        if( dr_busy ) st <= 3;
                    end
                end
            endcase
        end
    end
end

endmodule