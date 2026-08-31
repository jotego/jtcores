/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_main(
    input             clk,
    input             rst,
    input             main_rom_cs,
    output     [19:1] rom_addr,
    output            rom_cs,
    input             rom_ok,
    input      [15:0] cpu_din,
    input             dev_cs,
    input             dev_bus_cs,
    input             dev_busy,
    input      [2:0]  ipl_n,
    input             vpa_n,
    output     [23:1] cpu_addr,
    output     [15:0] cpu_dout,
    output      [1:0] cpu_dsn,
    output            cpu_we,
    output            bus_active,
    output            cpu_as_n
);

wire [23:1] A;
wire [2:0] FC;
wire cpu_cen, cpu_cenb, ASn, LDSn, UDSn, RnW, DTACKn;
wire bus_cs = main_rom_cs || dev_bus_cs;
wire bus_busy = (main_rom_cs && !rom_ok) || (dev_bus_cs && dev_busy);
wire wait2_cs = main_rom_cs || dev_cs;
/* Optional timing/CPU status outputs are kept explicit for diagnostics. */
/* verilator lint_off UNUSEDSIGNAL */
wire [15:0] dtack_fave, dtack_fworst;
wire        cpu_reset_n, cpu_bg_n;
wire [2:0]  cpu_fc_diag = FC;
/* verilator lint_on UNUSEDSIGNAL */

assign rom_cs = main_rom_cs;
assign cpu_addr = A;
assign cpu_dsn = {UDSn,LDSn};
assign bus_active = !ASn && !rst;
assign cpu_as_n = ASn;
assign cpu_we = bus_active && !RnW;

jtmoomsa_main_rom_map u_rom_map(
    .bank(A[20]), .offset(A[18:1]), .rom_addr(rom_addr)
);

jtframe_68kdtack_cen #(.W(6),.RECOVERY(1)) u_dtack(
    .rst(rst), .clk(clk), .cpu_cen(cpu_cen), .cpu_cenb(cpu_cenb),
    .bus_cs(bus_cs), .bus_busy(bus_busy), .bus_legit(1'b0), .bus_ack(1'b0),
    .ASn(ASn), .DSn({UDSn,LDSn}), .num(5'd1), .den(6'd3),
    .DTACKn(DTACKn), .wait2(wait2_cs), .wait3(1'b0),
    .fave(dtack_fave), .fworst(dtack_fworst)
);

jtmoomsa_fx68k u_cpu(
    .clk(clk), .rst(rst), .cpu_cen(cpu_cen), .cpu_cenb(cpu_cenb),
    .BERRn(1'b1), .VPAn(vpa_n), .BGACKn(1'b1), .HALTn(1'b1), .RESETn(cpu_reset_n),
    .eab(A), .ASn(ASn), .LDSn(LDSn), .UDSn(UDSn), .eRWn(RnW),
    .DTACKn(DTACKn), .iEdb(cpu_din), .oEdb(cpu_dout),
    .BRn(1'b1), .BGn(cpu_bg_n), .IPLn(ipl_n), .FC(FC)
);

endmodule
