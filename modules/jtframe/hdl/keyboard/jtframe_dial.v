/*  This file is part of JTFRAME.
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
    Date: 15-1-2023 */

// Dial emulation using joystick, mouse or spinner

module jtframe_dial(
    input           rst,
    input           clk,
    input           lhbl,
    // emulation based on mouse
    input           mouse_st,
    input     [8:0] mouse_dx,
    input     [8:0] mouse_dy,
    // emulation based on joysticks
    input     [9:0] joystick1, joystick2,
    input     [8:0] spinner_1, spinner_2,
    input     [1:0] sensty,
    input           raw,    // emulation via mouse may not work with raw enabled
    input           reverse,
    output    [1:0] dial_x,    dial_y
);

localparam B0 = `JTFRAME_DIALEMU_LEFT,
           B1 = B0+1;

reg   [3:0] line_cnt;
reg   [7:0] cnt1, cnt2;
reg         lhbl_l, sel;
reg         i_1p, d_1p, inc_1p, inc_2p,
            i_2p, d_2p, dec_1p, dec_2p,
            up_1p, up_2p,
            last1,  last2, cen=0, act_line, up_joy;
wire        mouse_sel_x, mouse_sel_y;

wire        toggle1, toggle2, line;
reg   [1:0] mouse_sens;
wire        mouse_up_x, mouse_up_y;
wire        mouse_inc_x, mouse_dec_x;
wire        mouse_inc_y, mouse_dec_y;

assign toggle1  = last1 != spinner_1[8],
       toggle2  = last2 != spinner_2[8];
assign line     = lhbl & ~lhbl_l;

always @* begin
    case( sensty ) // how often is the joystick check?
        1: { mouse_sens, act_line } = { 2'd3, line_cnt < 15 }; // 15 out of 16 lines
        0: { mouse_sens, act_line } = { 2'd2, line_cnt <  8 };
        3: { mouse_sens, act_line } = { 2'd1, line_cnt <  4 };
        2: { mouse_sens, act_line } = { 2'd0, line_cnt <  1 }; // once every 16 lines
    endcase
    up_joy = act_line & line;
    i_1p = sel ? !joystick1[B0] : mouse_sel_x ? mouse_inc_x :  cnt1[7];
    d_1p = sel ? !joystick1[B1] : mouse_sel_x ? mouse_dec_x : !cnt1[7];
    i_2p = sel ? !joystick2[B0] : mouse_sel_y ? mouse_inc_y :  cnt2[7];
    d_2p = sel ? !joystick2[B1] : mouse_sel_y ? mouse_dec_y : !cnt2[7];
	 inc_1p = reverse ? d_1p : i_1p;
	 dec_1p = reverse ? i_1p : d_1p;
	 inc_2p = reverse ? d_2p : i_2p;
	 dec_2p = reverse ? i_2p : d_2p;
end

jtframe_dial_mouse u_dial_mouse_x (
    .clk            ( clk          ),
    .spinner_strobe ( spinner_1[7] ),
    .line           ( line         ),
    .mouse_sens     ( mouse_sens   ),
    .mouse_st       ( mouse_st     ),
    .mouse_dx       ( mouse_dx     ),
    .mouse_inc      ( mouse_inc_x  ),
    .mouse_dec      ( mouse_dec_x  ),
    .mouse_up       ( mouse_up_x   ),
    .mouse_sel      ( mouse_sel_x  )
);

jtframe_dial_mouse u_dial_mouse_y (
    .clk            ( clk          ),
    .spinner_strobe ( spinner_2[7] ),
    .line           ( line         ),
    .mouse_sens     ( mouse_sens   ),
    .mouse_st       ( mouse_st     ),
    .mouse_dx       ( mouse_dy     ),
    .mouse_inc      ( mouse_inc_y  ),
    .mouse_dec      ( mouse_dec_y  ),
    .mouse_up       ( mouse_up_y   ),
    .mouse_sel      ( mouse_sel_y  )
);

// The dial update rythm is set to once every four lines
always @(posedge clk) begin
    lhbl_l    <= lhbl;
    cen       <= ~cen;

    if( line ) line_cnt <= line_cnt+4'd1;
    up_1p <= up_joy;
    up_2p <= up_joy;
    sel   <= up_joy;
    if( !up_joy && cen ) begin
        up_1p <= cnt1 != 0;
        up_2p <= cnt2 != 0;
        if( cnt1 != 0 ) cnt1 <= cnt1 + (cnt1[7] ? 8'd1 : 8'hff );
        if( cnt2 != 0 ) cnt2 <= cnt2 + (cnt2[7] ? 8'd1 : 8'hff );
    end
    if( toggle1 ) cnt1 <= { spinner_1[7],  {7{spinner_1[7]}} ^ {2'd0, 2'b10^sensty,3'd2} };
    if( toggle2 ) cnt2 <= { spinner_2[7],  {7{spinner_2[7]}} ^ {2'd0, 2'b10^sensty,3'd2} };
end

always @(posedge clk) begin
    last1 <= spinner_1[8];
    last2 <= spinner_2[8];
end

jt4701_dialemu u_dial1p(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pulse      ( raw ?  toggle1 : mouse_up_x | up_1p    ),
    .inc        ( raw ?  spinner_1[7] ^ reverse : inc_1p ),
    .dec        ( raw ? ~spinner_1[7] ^ reverse : dec_1p ),
    .dial       ( dial_x        )
);

jt4701_dialemu u_dial2p(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pulse      ( raw ?  toggle2 : mouse_up_y | up_2p    ),
    .inc        ( raw ?  spinner_2[7] ^ reverse : inc_2p ),
    .dec        ( raw ? ~spinner_2[7] ^ reverse : dec_2p ),
    .dial       ( dial_y        )
);

endmodule

module jtframe_dial_mouse(
    input             clk,
    input             spinner_strobe,
    input             line,
    input       [1:0] mouse_sens,
    input             mouse_st,
    input       [8:0] mouse_dx,
    output reg        mouse_inc,
    output reg        mouse_dec,
    output            mouse_up,
    output reg        mouse_sel
);

reg        spinner_l;
reg [10:0] mouse_cnt;

always @(posedge clk) begin
    spinner_l <= spinner_strobe;

    // Automatically select spinner or mouse control
    if( mouse_st && mouse_cnt==0 ) begin
        mouse_sel <= 1;
        mouse_inc <=  mouse_dx[8];
        mouse_dec <= ~mouse_dx[8];
        mouse_cnt <=  { 2'd0, (mouse_dx[8] ? -mouse_dx : mouse_dx) } << mouse_sens;
    end else if( line ) begin
        if( mouse_cnt==0 ) begin
            mouse_inc <= 0;
            mouse_dec <= 0;
        end else begin
            mouse_cnt <= mouse_cnt - 1'd1;
        end
    end
    if( spinner_l != spinner_strobe ) mouse_sel <= 0;
end

assign mouse_up = mouse_sel & mouse_cnt!=0 && line;

endmodule
