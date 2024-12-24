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
    Date: 15-4-2023 */

// Programmable custom chip used in Thunder Force, S.P.Y. and Helix
// The main CPU writes the program to its internal RAM
// How it works, nobody knows
// But what the program is expected to is emulated on MAME
// This implementation so far does what is needed for Thunder Force

module jt052591(
    input             rst,
    input             clk,
    input             cen,

    // CPU interface
    input             cs,
    input             cpu_we,
    // input      [12:0] cpu_addr,
    // input      [ 7:0] cpu_dout,
    // output reg [ 7:0] cpu_din,
    output            cpu2ram_we,

    // RAM. Called E(xternal) or ER (External RAM) in the pinout
    output reg        ram_we,
    output     [10:0] ram_addr, // real chip has 12:0, but 12,11 are NC in sch.
    input      [ 7:0] ram_dout,
    output reg [ 7:0] ram_din,

    // original pin names
    input             bk,       // 0=internal RAM, 1=external RAM
    output reg        out0,     // connected to PCMFIRQ in Thunder Cross
    input             start,    // triggers the programmed process
    // Debug
    output    [ 7:0]  st_dout
);

reg  [ 5:0] out_cnt;
reg  [ 4:0] st;
reg  [10:0] pos0, end0, addr;
reg  [ 7:0] flag0, flag1, cm, hm, start1, end1, pos1,
            t0, b0, l0, r0, x0, y0,
            t1, b1, l1, r1, x1, y1;
reg         bsy, start_l, thunderxa;

wire   int_we = cs & cpu_we & ~bk; // internal writes are ignored

assign cpu2ram_we = cs & cpu_we & bk; // BK writes mapped to the upper half of the RAM
assign ram_addr = addr;
assign st_dout  = { 6'd0, thunderxa,bsy };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        start_l <= 0;
        bsy     <= 0;
    end else begin
        start_l <= start;
        if( start & ~start_l ) bsy <= 1;
        if( !out0 ) bsy <= 0;
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st         <= 0;
        out0       <= 0;
        out_cnt    <= 0;
        ram_we     <= 0;
        thunderxa <= 0;
        pos0       <= 0;
        pos1       <= 0;
        {x0,y0,x1,y1}<=0;
        {b0,t0,l0,r0}<=0;
        {b1,t1,l1,r1}<=0;
    end else if(cen) begin
        if( out_cnt!=0 ) begin
            out_cnt <=out_cnt-1'd1;
            out0    <= 0;
        end else begin
            out0    <= 1;
        end
        st <= bsy && out_cnt==0 ? st+5'd1 : 5'd0;
        case(st)
            1: begin addr<=0; end
            2: begin addr<=1; end0[10:8] <= ram_dout[2:0]; end
            3: begin addr<=2; end0[ 7:0] <= ram_dout; end
            4: begin addr<=3; end1       <= ram_dout; end
            5: begin addr<=4; cm         <= ram_dout; end
            6: begin addr<=5; hm         <= ram_dout; end
            7: begin
                addr<=6;
                if(ram_dout<16) begin
                    thunderxa <= 1;
                    pos0[10:8] <= ram_dout[2:0];
                end else begin
                    thunderxa <= 0;
                    pos0 <= { 3'd0, ram_dout };
                end
            end
            8: begin
                if(thunderxa) begin
                    addr<=7;
                    pos0[7:0] <= ram_dout;
                end else begin
                    addr<=6;
                end
            end
            9: begin
                start1 <= ram_dout; addr <= pos0;
                $display("052591: set 0 %X -> %X    set 1 %X -> %X",pos0, end0, ram_dout, end1);
            end
            // loop
            10: begin
                addr <= pos0 + 11'd3;
                flag0    <= ram_dout;
                if( (ram_dout & cm) == 0) begin
                    pos0<=pos0+11'd5;
                    st <= 24;   // NEXT
                end
            end
            11: begin addr <= pos0 + 11'd4; x0 <= ram_dout; end
            12: begin addr <= pos0 + 11'd1; y0 <= ram_dout; end
            13: begin addr <= pos0 + 11'd2; l0 <= x0-ram_dout; r0 <= x0+ram_dout; end
            14: begin pos1     <= start1;   t0 <= y0-ram_dout; b0 <= y0+ram_dout;
                      addr <= {3'd0, start1}; end
            // inner loop
            15: begin // INNER_LOOP
                addr <= {3'd0,pos1} + 11'd3;
                flag1 <= ram_dout;
                if( (ram_dout & hm) == 0) begin
                    pos1<=pos1+8'd5;
                    st <= 23;   // INNER_NEXT
                end
            end
            16: begin addr <= {3'd0,pos1} + 11'd4; x1 <= ram_dout; end
            17: begin addr <= {3'd0,pos1} + 11'd1; y1 <= ram_dout; end
            18: begin addr <= {3'd0,pos1} + 11'd2; l1 <= x1-ram_dout; r1 <= x1+ram_dout; end
            19: begin                              t1 <= y1-ram_dout; b1 <= y1+ram_dout; end
            20: begin
                addr <= pos0;
                if( l1<r0 && l0<r1 && t1<b0 && t0<b1 ) begin
                    ram_we     <= 1;
                    ram_din    <= flag0;
                    ram_din[2] <= flag0[2] | flag1[2];
                    ram_din[4] <= 1;
                end
            end
            21: begin
                addr <= {3'd0,pos1};
                if( ram_we ) begin
                    ram_din    <= flag1;
                    ram_din[4] <= 1;
                end
            end
            22: begin
                ram_we <= 0;
                pos1 <= pos1+8'd5;
            end
            23: begin // INNER_NEXT
                addr <= {3'd0,pos1};
                if( pos1<end1 )
                    st <= 15; // inner loop
                else
                    pos0 <= pos0 + 11'd5;
            end
            24: begin // NEXT
                addr <= pos0;
                if( pos0<end0 ) begin
                    st <= 10;
                end else begin
                    st <= 0;
                    out_cnt <= 6'h3f;
                end
            end
        endcase
    end
end

endmodule