/* Test-only stubs for unrelated jts16_main dependencies. */
module jtframe_68kdma #(parameter BW=1)(
    input clk, rst, cen,
    output reg cpu_BRn, cpu_BGACKn,
    input cpu_BGn, cpu_ASn, cpu_DTACKn,
    input [BW-1:0] dev_br
);
always @(posedge clk) begin
    cpu_BRn <= 1'b1;
    cpu_BGACKn <= 1'b1;
end
endmodule

module jtframe_8751mcu #(parameter SYNC_XDATA=0, SYNC_P1=0, SYNC_INT=0, ROMBIN="") (
    input rst, clk, cen, int0n, int1n,
    input [7:0] p0_i, p1_i, p2_i, p3_i,
    output [7:0] p0_o, p1_o, p2_o, p3_o,
    input [7:0] x_din,
    output [7:0] x_dout,
    output [15:0] x_addr,
    output x_wr, x_acc,
    input clk_rom,
    input [11:0] prog_addr,
    input [7:0] prom_din,
    input prom_we
);
assign p0_o = 8'hff;
assign p1_o = 8'hff;
assign p2_o = 8'hff;
assign p3_o = 8'hff;
assign x_dout = 8'h00;
assign x_addr = 16'h0000;
assign x_wr = 1'b0;
assign x_acc = 1'b0;
endmodule

module jt8255(
    input rst, clk,
    input [1:0] addr,
    input [7:0] din,
    output [7:0] dout,
    input rdn, wrn, csn,
    input [7:0] porta_din, portb_din, portc_din,
    output [7:0] porta_dout, portb_dout, portc_dout
);
assign dout = 8'hff;
assign porta_dout = 8'hff;
assign portb_dout = 8'hff;
assign portc_dout = 8'hff;
endmodule

module jtframe_okdly #(parameter W=1)(
    input rst, clk,
    input [W-1:0] cs, ok,
    output ok_dly
);
assign ok_dly = 1'b0;
endmodule

module jtframe_68kdtack_cen #(parameter W=8, MFREQ=50000)(
    input rst, clk,
    output cpu_cen, cpu_cenb,
    input bus_cs, bus_busy, bus_legit, bus_ack, ASn,
    input [1:0] DSn,
    input [6:0] num,
    input [7:0] den,
    input wait2, wait3,
    output DTACKn,
    output [15:0] fave, fworst
);
assign cpu_cen = 1'b0;
assign cpu_cenb = 1'b0;
assign DTACKn = 1'b1;
assign fave = 16'd0;
assign fworst = 16'd0;
endmodule

module jts16_fd1094(
    input rst, clk,
    output [12:0] key_addr,
    input [7:0] key_data,
    input [12:0] prog_addr,
    input fd1094_we,
    input [7:0] prog_data,
    input dec_en,
    input [2:0] FC,
    input ASn,
    input [23:1] addr,
    input [15:0] enc,
    output [15:0] dec,
    input rom_ok,
    input dtackn,
    output ok_dly
);
assign key_addr = 13'd0;
assign dec = enc;
assign ok_dly = rom_ok;
endmodule

module jts16_fd1089(
    input rst, clk,
    output [12:0] key_addr,
    input [7:0] key_data,
    input [12:0] prog_addr,
    input fd1089_we,
    input [7:0] prog_data,
    input dec_type, dec_en, op_n,
    input [23:1] addr,
    input [15:0] enc,
    output [15:0] dec,
    input rom_ok,
    output ok_dly
);
assign key_addr = 13'd0;
assign dec = enc;
assign ok_dly = rom_ok;
endmodule

module jtframe_m68k(
    input clk, rst, cpu_cen, cpu_cenb, BERRn, VPAn, BGACKn, HALTn,
    output RESETn,
    output [23:1] eab,
    output ASn, LDSn, UDSn, eRWn,
    input DTACKn,
    input [15:0] iEdb,
    output [15:0] oEdb,
    input BRn,
    output BGn,
    input [2:0] IPLn,
    output [2:0] FC
);
assign RESETn = 1'b1;
assign eab = 23'd0;
assign ASn = 1'b1;
assign LDSn = 1'b1;
assign UDSn = 1'b1;
assign eRWn = 1'b1;
assign oEdb = 16'd0;
assign BGn = 1'b1;
assign FC = 3'd0;
endmodule
