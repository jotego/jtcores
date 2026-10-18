/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

module jtpopeye_obj(
    input             rst,
    input             clk,
    input             cen20,
    input             cen10,
    input             cen5,

    input      [ 1:0] h,
    input             hb,
    input             vb,
    input             rv,
    input             initeo,
    input      [17:0] dj,

    output     [12:1] obj0_addr,
    input      [15:0] obj0_data,
    output     [12:1] obj1_addr,
    input      [15:0] obj1_data,
    output     [12:1] obj2_addr,
    input      [15:0] obj2_data,
    output     [12:1] obj3_addr,
    input      [15:0] obj3_data,

    output reg [ 1:0] obj_v,
    output reg [ 2:0] obj_c
);

wire [12:0] addr;
wire [ 3:0] ld;
wire        eo, dotck, qa_up, ldl, tc, sel;
wire [ 7:0] d3e, d3f, d3j, d3k;
reg  [ 7:0] l3e, l3f, l3j, l3k;
reg  [ 3:0] c3, c4, cnt;
reg  [15:0] sv0, sv1;
reg         qb;

assign eo        = ~initeo;
assign addr      = { dj[16], dj[17], dj[10:1], dj[0] ^ eo };
assign obj0_addr = addr[12:1];
assign obj1_addr = addr[12:1];
assign obj2_addr = addr[12:1];
assign obj3_addr = addr[12:1];
assign d3e       = addr[0] ? obj0_data[15:8] : obj0_data[7:0];
assign d3f       = addr[0] ? obj1_data[15:8] : obj1_data[7:0];
assign d3j       = addr[0] ? obj2_data[15:8] : obj2_data[7:0];
assign d3k       = addr[0] ? obj3_data[15:8] : obj3_data[7:0];

assign dotck     = cen10 & ~cen5;
assign qa_up     = cen20 & ~cen10;
assign ldl       = dotck & h[1] & h[0];
assign ld        = { ~&dj[16:14], 1'b1, dj[13:12] ^ {2{rv}} };
assign tc        = &cnt;
assign sel       = ~c4[3];

always @(posedge clk) begin
    if( rst ) begin
        cnt <= 0;
    end else if( hb ) begin
        cnt <= 0;
    end else if( dotck ) begin
        cnt <= ldl ? ld : cnt + 4'd1;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        l3e <= 0;
        l3f <= 0;
        l3j <= 0;
        l3k <= 0;
        c3  <= 0;
    end else if( ldl ) begin
        l3e <= d3e;
        l3f <= d3f;
        l3j <= d3j;
        l3k <= d3k;
        c3  <= { dj[11], dj[16:14] };
    end
end

always @(posedge clk) begin
    if( rst ) begin
        qb <= 0;
    end else if( cen5 ) begin
        qb <= 1;
    end else if( dotck ) begin
        qb <= 0;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        c4 <= 0;
    end else if( cen5 && tc ) begin
        c4 <= { c3[3] ^ rv, c3[2:0] };
    end
end

always @(posedge clk) begin
    if( rst ) begin
        sv0 <= 0;
        sv1 <= 0;
    end else if( qa_up ) begin
        if( qb && tc ) begin
            sv0 <= { l3j, l3k };
            sv1 <= { l3e, l3f };
        end else if( c4[3] ) begin
            sv0 <= { 1'b0, sv0[15:1] };
            sv1 <= { 1'b0, sv1[15:1] };
        end else begin
            sv0 <= { sv0[14:0], 1'b0 };
            sv1 <= { sv1[14:0], 1'b0 };
        end
    end
end

always @(posedge clk) begin
    if( rst ) begin
        obj_v <= 0;
        obj_c <= 0;
    end else begin
        obj_v <= vb ? 2'b00 : sel ? { sv1[15], sv0[15] } : { sv1[0], sv0[0] };
        obj_c <= ~c4[2:0];
    end
end

endmodule
