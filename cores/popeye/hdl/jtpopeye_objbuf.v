/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

module jtpopeye_objbuf(
    input             rst,
    input             clk,
    input             cen5,
    input             cen10,

    input      [ 7:0] h,
    input             h20,
    input             hb,
    input      [ 7:0] v,
    input             rv,

    input      [ 7:0] dm,
    input      [ 3:0] dmcs_n,
    input      [ 7:0] dd,
    input             rohvs,
    input             rohvck,

    output     [28:0] obj_do,
    output reg [ 8:1] rovi,
    output reg [17:0] dj,
    output reg [ 5:3] obj_c,
    output reg        bakc4
);

wire [ 3:0] dmcs;
wire [ 8:0] sum;
wire [ 2:0] row, colw;
wire [ 5:0] scan_addr, adr0, adr1;
wire [17:0] desc, din0, din1, q0, q1, dji, dout0, dout1;
wire        v0, cin, oor, dotck, n0, n1, c2, netx, djck;
wire        ce0_n, ce1_n, we0_n, we1_n, wr0, wr1;
reg  [17:0] din0_l, din1_l;
reg         q4b, djck_l, rohvck_l, ce0_l, ce1_l, we0_l, we1_l;

assign dmcs      = ~dmcs_n;
assign v0        = v[0];
assign cin       = rohvck ^ rv;
assign sum       = { 1'b0, obj_do[15:8] } + { 1'b0, v } + { 8'd0, cin };
assign oor       = |sum[7:3];
assign row       = sum[2:0] ^ {3{obj_do[27]}};
assign colw      = obj_do[26:24];
assign desc      = { obj_do[28], colw, obj_do[1:0], obj_do[23:16], row, obj_do[27] };
assign din0      = { desc[17], desc[16:14] & {3{ v0}}, desc[13:0] };
assign din1      = { desc[17], desc[16:14] & {3{~v0}}, desc[13:0] };
assign scan_addr = { h[7:3], h20 };

assign dotck     = cen10 & ~cen5;
assign n0        = ~( h[0] & q4b );
assign n1        = ~( n0 & h[1] & ~hb );
assign c2        = ~h[0] & ~q4b;
assign netx      = rohvs | c2 | oor;
assign djck      = h[0] & ~q4b & ~h[1];

assign adr0      = v0 ? obj_do[7:2] : scan_addr;
assign adr1      = v0 ? scan_addr   : obj_do[7:2];
assign ce0_n     = v0 & netx;
assign ce1_n     = ~v0 & netx;
assign we0_n     = v0 ? n0 : n1;
assign we1_n     = v0 ? n1 : n0;
assign wr0       = ~ce0_n & ~we0_n;
assign wr1       = ~ce1_n & ~we1_n;

assign dout0     = ce0_l ? 18'h3ffff : ( we0_l ? ~q0 : ~din0_l );
assign dout1     = ce1_l ? 18'h3ffff : ( we1_l ? ~q1 : ~din1_l );
assign dji       = dout0 & dout1;

always @(posedge clk) begin
    if( rst ) begin
        q4b <= 0;
    end else if( dotck ) begin
        q4b <= h[0];
    end
end

always @(posedge clk) begin
    if( rst ) begin
        ce0_l  <= 1;
        ce1_l  <= 1;
        we0_l  <= 1;
        we1_l  <= 1;
        din0_l <= 0;
        din1_l <= 0;
        djck_l <= 0;
        dj     <= 18'h3ffff;
    end else begin
        ce0_l  <= ce0_n;
        ce1_l  <= ce1_n;
        we0_l  <= we0_n;
        we1_l  <= we1_n;
        din0_l <= din0;
        din1_l <= din1;
        djck_l <= djck;
        if( djck && !djck_l ) dj <= dji;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        rovi     <= 0;
        rohvck_l <= 1;
        obj_c    <= 0;
        bakc4    <= 0;
    end else begin
        rovi     <= sum[8:1];
        rohvck_l <= rohvck;
        if( rohvck && !rohvck_l ) { bakc4, obj_c } <= obj_do[27:24];
    end
end

jtframe_ram #(.AW(8)) u_lane0(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( dd            ),
    .addr   ( dm            ),
    .we     ( dmcs[0]       ),
    .q      ( obj_do[7:0]   )
);

jtframe_ram #(.AW(8)) u_lane1(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( dd            ),
    .addr   ( dm            ),
    .we     ( dmcs[1]       ),
    .q      ( obj_do[15:8]  )
);

jtframe_ram #(.AW(8)) u_lane2(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( dd            ),
    .addr   ( dm            ),
    .we     ( dmcs[2]       ),
    .q      ( obj_do[23:16] )
);

jtframe_ram #(.AW(8),.DW(5)) u_lane3(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( dd[4:0]       ),
    .addr   ( dm            ),
    .we     ( dmcs[3]       ),
    .q      ( obj_do[28:24] )
);

jtframe_ram #(.AW(6),.DW(18)) u_buf0(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( din0          ),
    .addr   ( adr0          ),
    .we     ( wr0           ),
    .q      ( q0            )
);

jtframe_ram #(.AW(6),.DW(18)) u_buf1(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( din1          ),
    .addr   ( adr1          ),
    .we     ( wr1           ),
    .q      ( q1            )
);

endmodule
