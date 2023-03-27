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
    Date: 10-10-2022 */

module jtoutrun_obj_scan(
    input              rst,
    input              clk,

    output reg         ln_done,
    // Obj table
    output     [10:1]  tbl_addr,
    input      [15:0]  tbl_dout,
    output     [15:0]  tbl_din,
    output reg         tbl_we,

    // Draw commands
    output reg         dr_start,
    input              dr_busy,
    output reg [ 8:0]  dr_xpos,
    output reg [15:0]  dr_offset,  // MSB is also used as the flip bit
    output reg [ 2:0]  dr_bank,
    output reg [ 1:0]  dr_prio,
    output reg         dr_shadow,
    output reg [ 6:0]  dr_pal,
    output reg [ 9:0]  dr_hzoom,
    output reg         dr_hflip,
    output reg         dr_backwd,

    // Video signal
    input              flip,
    input              hstart,
    input      [ 8:0]  vrender,

    input      [ 7:0]  debug_bus,
    // System info
    input      [ 7:0]  st_addr,
    output reg [ 7:0]  st_dout        // late or max number of sprites drawn in a line
);

parameter [8:0] PXL_DLY=8;

localparam STW = 4;

reg  [6:0] cur_obj, drawn_cnt, worst_cnt;  // current object
reg  [2:0] idx;
reg  [STW-1:0] st;
reg        first, stop, visible, backwd;

// Object data
reg        [ 8:0] bottom, top;
wire       [ 8:0] endline;
reg        [ 8:0] xpos;
reg signed [15:0] pitch;
reg        [15:0] offset;
reg        [ 2:0] bank;
reg        [ 1:0] prio;
reg        [ 6:0] pal;
reg               zoom_sel, hflip, vflip, shadow, hstartl, late;
reg        [15:0] nx_offset;
reg        [10:0] vacc;
wire       [10:0] nx_vacc;
reg        [ 9:0] vzoom, hzoom;
wire              is_first;

assign tbl_addr  = { cur_obj, idx };
assign tbl_din   = zoom_sel ? {7'd0, vacc[8:0]} : offset;
assign endline   = vflip ? top - {1'd0,tbl_dout[15:8]} : top + {1'd0,tbl_dout[15:8]};
assign is_first  = top == vrender[8:0];
assign nx_vacc   = {1'b0, vzoom} + {2'd0, is_first ? 9'd0 : tbl_dout[8:0]};

always @* begin
    nx_offset = offset;
    if( !first ) begin
        case( vacc[10:9] )
            0: nx_offset = tbl_dout;
            1: nx_offset = tbl_dout + pitch;
            2: nx_offset = tbl_dout + (pitch<<1);
            3: nx_offset = tbl_dout + (pitch<<1) + pitch;
        endcase
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cur_obj   <= 0;
        st        <= 0;
        tbl_we    <= 0;
        stop      <= 0;

        dr_start  <= 0;
        dr_xpos   <= 0;
        dr_offset <= 0;
        dr_bank   <= 0;
        dr_prio   <= 0;
        dr_pal    <= 0;
        hstartl   <= 0;
        late      <= 0;
    end else begin
        hstartl <= hstart;
        ln_done <= 0;
        if( idx < 7 ) idx <= idx + 3'd1;
        if( !stop ) begin
            st <= st+1'd1;
        end
        stop     <= 0;
        dr_start <= 0;
        tbl_we   <= 0;
        case( st )
            0: begin
                cur_obj  <= 0;
                stop     <= 0;
                dr_start <= 0;
                if( hstart ) begin
                    drawn_cnt <= 0;
                    if( drawn_cnt > worst_cnt ) worst_cnt <= drawn_cnt;
                    if( vrender==0 ) begin
                        st_dout   <= st_addr[0] ? { 1'b0, worst_cnt } : { 7'd0, late };
                        late <= 0;
                        worst_cnt <= 0;
                    end
                end
                if( !hstart || vrender>223 ) begin // holds the state
                    st  <= 0;
                    idx <= 0;
// `ifdef SIMULATION
//                 end else begin
//                     $display("--------- line %0d -----------", vrender);
// `endif
                end
            end
            1: if( !stop ) begin
                top     <= tbl_dout[ 8:0] ^ 9'h100;
                visible <= !tbl_dout[14] && !tbl_dout[12];
                bank    <= tbl_dout[11:9];
                first   <= 0;
                if( tbl_dout[15] ) begin
                    ln_done <= 1;
                    st      <= 0;
                end
            end
            2: begin
                offset <= tbl_dout;
            end
            3: begin
                { pitch[6:0], xpos } <= tbl_dout;
            end
            4: begin
                shadow <= tbl_dout[14];
                prio   <= tbl_dout[13:12];
                vzoom  <= tbl_dout[9:0];
            end
            5: begin
                vflip  <= ~tbl_dout[15]; // swap top & bottom when vflip is set
                hflip  <= ~tbl_dout[14]; // regular hflip
                backwd <= ~tbl_dout[13]; // the xpos sets the end position, instead of the start
                hzoom  <=  tbl_dout[9:0];
                pitch[15:7] <= {9{tbl_dout[12]}};
            end
            6: begin
                if( vflip ) begin
                    top    <= endline;
                    bottom <= top;
                end else begin
                    bottom <= endline;
                end
                pal <= tbl_dout[6:0];
                if( tbl_dout[15:8]==0 ) visible <= 0; // zero height
            end
            7: begin
                first <= is_first; // first line
                if( !visible || top > vrender || bottom < vrender ) begin // skip this sprite
                    cur_obj <= cur_obj + 1'd1;
                    idx     <= 0;
                    st      <= 1;
                    stop    <= 1;
                    if( &cur_obj ) begin
                        ln_done <= 1;
                        st      <= 0;
                    end
                end
                vacc <= nx_vacc;
            end
            8: begin
                offset   <= nx_offset;
                tbl_we   <= 1;
                zoom_sel <= 0;
                idx      <= 7; // idx would be 7 anyway, but I make it explicit for clarity
            end
            9: begin
                tbl_we   <= 1;
                zoom_sel <= 1;
                idx      <= 6;
            end
            10: begin
                if( !dr_busy ) begin
                    dr_xpos   <= xpos; //+PXL_DLY;
                    dr_offset <= offset;
                    dr_pal    <= pal;
                    dr_prio   <= prio;
                    dr_shadow <= shadow;
                    dr_start  <= pitch!=0;
                    dr_hflip  <= hflip;
                    dr_backwd <= backwd;
                    dr_hzoom  <= hzoom;
                    dr_bank   <= bank;
                    drawn_cnt <= drawn_cnt + 1'd1;
                    // next
                    if( &cur_obj ) begin
                        ln_done <= 0;
                        st      <= 0;
                    end
                    else begin
                        cur_obj <= cur_obj + 1'd1;
                        idx     <= 0;
                        st      <= 1;
                        stop    <= 1;
                    end
                end else begin
                    st <= st;
                end
            end
        endcase
        if( hstart && !hstartl && cur_obj!=0 ) begin
            cur_obj  <= 0;
            stop     <= 1;
            dr_start <= 0;
            idx      <= 0;
            st       <= 1;
            late     <= 1;
`ifdef SIMULATION
            $display("Assertion failed: objects not parsed within one scanline. vrender=0x%0x,cur_obj=0x%0x\n",vrender,cur_obj);
            // $finish;
`endif
        end
    end
end

endmodule