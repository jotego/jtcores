/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-10-2024 */

module jtwc_sub(
    input            rst_n,
    input            clk,
    input            cen,
    input            lvbl,       // video interrupt
    input            ws,
    // shared memory
    output reg       mmx_c8,
    output reg       mmx_d0,
    output reg       mmx_d8,
    output reg       mmx_e0,
    output reg       mmx_e8,
    output    [ 7:0] cpu_dout,
    output           wr_n,
    input     [ 7:0] sh_dout,
    // ROM access
    output reg       rom_cs,
    output    [14:0] rom_addr,
    input     [ 7:0] rom_data,
    input            rom_ok
);
`ifndef NOMAIN
wire [15:0] A;
wire [ 7:0] ram_dout;
reg  [ 7:0] cpu_din;
reg         ram_cs, latch_cs, sh_cs;
wire        rd_n, iorq_n, rfsh_n, mreq_n, int_n, cen_eff;

assign rom_addr = A[14:0];
assign cen_eff  = ~ws & cen;

always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    mmx_c8   = 0;
    mmx_d0   = 0;
    mmx_d8   = 0;
    mmx_e0   = 0;
    mmx_e8   = 0;
    sh_cs    = 0;
    if( !mreq_n && rfsh_n ) casez(A[15:14])
        0,1: rom_cs   = 1;
        3: case(A[13:11])
            0: ram_cs = 1;
            1: {sh_cs,mmx_c8} = 2'b11;
            2: {sh_cs,mmx_d0} = 2'b11;
            3: {sh_cs,mmx_d8} = 2'b11;
            4: {sh_cs,mmx_e0} = 2'b11;
            5: {sh_cs,mmx_e8} = 2'b11;
            default:;
        endcase
        default:;
    endcase
end

always @* begin
    cpu_din = rom_cs ? rom_data :
              ram_cs ? ram_dout :
              sh_cs  ? sh_dout  : 8'd0;
end

jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(1),.RECOVERY(1)) u_cpu(
    .rst_n      ( rst_n       ),
    .clk        ( clk         ),
    .cen        ( cen_eff     ),
    .cpu_cen    (             ),
    .int_n      ( ~lvbl       ), // int clear logic is internal
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( 1'b1        ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( cpu_din     ),
    .cpu_dout   ( cpu_dout    ),
    .ram_dout   ( ram_dout    ),
    // ROM access
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);
`else
initial begin
    mmx_c8  = 0;
    mmx_d0  = 0;
    mmx_d8  = 0;
    mmx_e0  = 0;
    mmx_e8  = 0;
    rom_cs  = 0;
end
assign {cpu_dout,wr_n,rom_addr} = 0;
`endif
endmodule