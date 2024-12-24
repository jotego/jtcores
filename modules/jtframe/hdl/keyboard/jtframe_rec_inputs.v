/*  This file is part of JT_FRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 10-2-2024 */

// record input data in a compressed format
// decompress with `jtutil inputs`
module jtframe_rec_inputs(
    input              rst,
    input              clk,

    input              vs,
    input              dip_pause,

    input       [ 3:0] game_start,
    input       [ 3:0] game_coin,
    input       [ 5:0] joystick,

    input       [12:0] ioctl_addr,
    output      [ 7:0] ioctl_merged
);
    parameter RECAW=13, ACTIVE_LOW=1;

    reg  [ 7:0] recin, rec_l, fdiff;
    reg         rec_clrd, vsl;
    reg  [RECAW-1:0] reca;
    wire [ 7:0] rec_data = { joystick[5:0], {2{ACTIVE_LOW[0]}}^{game_start[0], game_coin[0]} };
    reg  [ 1:0] recwsh;
    wire [ 7:0] recmux = !rec_clrd ? (!reca[0] ? 8'hff: 8'h0 ) :
                         recwsh[0] ?            recin : fdiff;
    wire        rec_we = recwsh!= 0 || !rec_clrd;

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            reca     <= 0;
            recin    <= 0;
            rec_l    <= 0;
            recwsh   <= 0;
            fdiff    <= 0;
            rec_clrd <= 0;
        end else begin
            vsl <= vs;
            if( !rec_clrd ) begin
                reca <= reca+1'd1;
                if( &reca ) rec_clrd <= 1;
            end else begin
                recwsh <= recwsh>>1;
                if( vsl && !vs && dip_pause) begin
                    if( &fdiff || rec_data != rec_l ) begin
                        rec_l <= rec_data;
                        recin <= rec_data ^ rec_l;
                        recwsh <= 2;
                    end else begin
                        fdiff <= fdiff +1'd1;
                    end
                end
                case( recwsh )
                    2: begin
                        reca  <= reca+1'd1;
                    end
                    1: begin
                        reca <= reca+1'd1;
                        fdiff <= 0;
                    end
                    default:;
                endcase
            end
        end
    end

    // 1st byte = number of frames before applying the value change
    // 2nd byte = input bits that changed are set high
    // see "jtutil inputs" in "src/jtutil/inputs.go" for conveting to sim_inputs.hex
    jtframe_dual_ram #(.AW(RECAW) ) u_record( // 2kB, set in jtdef.go
        // Port 0: record
        .clk0   ( clk            ),
        .data0  ( recmux         ),
        .addr0  ( reca           ),
        .we0    ( rec_we         ),
        .q0     (                ),
        // Port 1: readout
        .clk1   ( clk            ),
        .data1  ( 8'd0           ),
        .addr1  (ioctl_addr[RECAW-1:0]),
        .we1    ( 1'b0           ),
        .q1     ( ioctl_merged   )
    );

endmodule