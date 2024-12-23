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
    Date: 12-3-2021 */

module jts16_obj_scan(
    input              rst,
    input              clk,

    input              alt_bank,

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
    output reg [ 3:0]  dr_bank,
    output reg [ 1:0]  dr_prio,
    output reg [ 5:0]  dr_pal,
    output reg [ 4:0]  dr_hzoom,
    output reg         dr_hflipb,

    // Video signal
    input              flip,
    input              hstart,
    input      [ 8:0]  vrender
);

parameter [8:0] PXL_DLY=8;
parameter       MODEL=0;  // 0 = S16A, 1 = S16B

localparam LAST_IDX = MODEL ? 5 : 4;
localparam STW = MODEL ? 4 : 3;
localparam ST_SCRATCH = MODEL ? 7 : 6,
           ST_PREZOOM = MODEL ? 6 /*Ok for S16B*/: 9 /* Unreachable for S16A*/,
           ST_ZOOM    = 8, // Unreachable for S16A
           ST_DRAW    = MODEL ? 9 : 7;

reg  [6:0] cur_obj;  // current object
reg  [2:0] idx;
reg  [STW-1:0] st;
reg [15:0] zoom;
reg        first, stop, visible, hstart_l;

// Object data
//reg        [7:0] bottom, top;
reg        [ 8:0] xpos;
reg signed [15:0] pitch;
reg        [15:0] offset; // MSB is also used as the flip bit
reg        [ 3:0] bank;
reg        [ 1:0] prio;
reg        [ 5:0] pal;
reg               zoom_sel, hflipb; // H flip bit for S16B
wire       [15:0] next_offset;
wire       [15:0] next_zoom;
wire       [ 5:0] vzoom;

assign tbl_addr    = { cur_obj, idx };
assign next_offset = (first ? offset : tbl_dout) + ( pitch << (MODEL[0] & zoom[15]) );
assign vzoom       = { 1'b0, first ? 5'd0 : tbl_dout[14:10] } + { 1'b0, tbl_dout[9:5] };
assign next_zoom   = { vzoom, tbl_dout[9:0] };
assign tbl_din     = zoom_sel ? {1'b0, zoom[14:0] } : offset;

reg  [7:0] top, bottom;
wire       inzone = vrender[7:0]>=top && bottom>vrender[7:0];
wire       badobj = top >= bottom;

generate
     if( MODEL==0 )
        initial zoom = 0;
endgenerate

`ifdef SIMULATION
    wire hide = MODEL && st==3 && tbl_dout[14];
`endif

always @* begin
    if (!flip) begin
        top    = tbl_dout[ 7:0];
        bottom = tbl_dout[15:8];
    end else begin
        bottom = 8'd223-tbl_dout[ 7:0];
        top    = 8'd223-tbl_dout[15:8];
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
        hstart_l  <= 0;
    end else begin
        idx <= idx>=LAST_IDX ? 3'd7 : (idx + 3'd1); // 7 is the scratch location
        if( !stop ) begin
            st <= st+1'd1;
        end
        hstart_l <= hstart;
        stop     <= 0;
        dr_start <= 0;
        tbl_we   <= 0;
/* verilator lint_off WIDTH */
        case( st )
/* verilator lint_on WIDTH */
            0: begin
                cur_obj  <= 0;
                stop     <= 0;
                dr_start <= 0;
                if( !(hstart && !hstart_l) || vrender>223 ) begin // holds it still
                    st  <= 0;
                    idx <= 0;
                end
            end
            1: begin
                if( !stop ) begin
                    visible <= inzone;
                    if( MODEL==0 && bottom>=8'hf0 ) begin
                        st <= 0; // Done
                    end else if( MODEL==0 && (!inzone || badobj) ) begin
                        // For S16A there is no end-of-table (EOT) bit, so we
                        // can loop around here. For S16B, we need to check
                        // tbl_dout at state 3 for the EOT bit
                        // Next object
                        cur_obj <= cur_obj + 1'd1;
                        idx     <= 0;
                        st      <= 1;
                        stop    <= 1;
                        if( &cur_obj )
                            st <= 0; // we're done
                    end else begin // draw this one
                        first <= top == vrender[7:0]; // first line
                    end
                end
            end
            2: xpos <= tbl_dout[8:0];
            3: begin
                pitch <= MODEL ? { {8{tbl_dout[7]}}, tbl_dout[7:0]} : tbl_dout;
                hflipb<= tbl_dout[8];
                if( (MODEL && tbl_dout[14]) || !visible ) begin // skip this sprite
                    cur_obj <= cur_obj + 1'd1;
                    idx     <= 0;
                    st      <= 1;
                    stop    <= 1;
                    if( &cur_obj )
                        st <= 0; // we're done
                end
                if( MODEL && tbl_dout[15] ) begin
                    st <= 0; // end of sprite list
                end
            end
            4: begin
                offset  <= tbl_dout; // flip/offset
            end
            5: begin
                if (MODEL) begin
                    pal  <= tbl_dout[5:0];
                    bank <= tbl_dout[11:8];
                    prio <= tbl_dout[7:6];
                end else begin
                    pal  <= tbl_dout[13:8];
                    bank <= {1'b0, tbl_dout[6:4] };
                    prio <= tbl_dout[1:0];
                end
            end
            ST_PREZOOM: begin
                zoom <= next_zoom;
            end
            ST_SCRATCH: begin
                offset   <= next_offset;
                tbl_we   <= 1;
                zoom_sel <= 0;
            end
            ST_ZOOM: begin
                tbl_we  <= 1;
                zoom_sel<= 1;
                idx     <= 5;
            end
            ST_DRAW: begin
                if( !dr_busy ) begin
                    dr_xpos   <= xpos; //+PXL_DLY;
                    dr_offset <= offset;
                    dr_pal    <= pal;
                    dr_prio   <= prio;
                    dr_start  <= 1;
                    dr_hflipb <= hflipb;
                    dr_hzoom  <= zoom[4:0];
                    if( alt_bank ) begin
                        case( bank )
                            0:  dr_bank <= 0;
                            7:  dr_bank <= 3;
                            11: dr_bank <= 2;
                            13: dr_bank <= 1;
                            14: dr_bank <= 0;
                            default: dr_bank <= 15;
                        endcase
                    end else
                        dr_bank <= bank;
                    // next
                    if( &cur_obj )
                        st <= 0; // Done
                    else begin
                        cur_obj <= cur_obj + 1'd1;
                        idx     <= 0;
                        st      <= 1;
                        stop    <= 1;
                    end
                end else begin
                    if(!hstart) st <= ST_DRAW[STW-1:0];
                end
            end
        endcase
    end
end

endmodule