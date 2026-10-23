/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-10-2026 */

module jtseicro_mcu(
    input             rst, cpu_rst, clk, cen, run, reset_req, dip_pause, nsc8105,
    input             release_clk,
    input      [23:0] dipsw,
    input             nvram_en,
    output      [7:0] nvram_addr, nvram_din,
    output            nvram_we,
    input       [7:0] nvram_dout,
    output     [14:0] rom_addr,
    output            rom_cs,
    input       [7:0] rom_data,
    input             rom_ok,
    output     [10:0] shared_addr,
    output      [7:0] shared_din,
    output            shared_we,
    input       [7:0] shared_dout,
    output reg  [3:0] dac,
    output      [7:0] debug_view
);

// PAL arbitration and bus assumptions: ../doc/hardware_verification.md.
wire [15:0] addr;
wire [7:0] dout, internal_data;
wire wr, mcu_e, mcu_vma, step, instruction_end, opcode_fetch, mr_n;
wire core_rst=rst || cpu_rst || reset_req || !run;
wire internal_cs=addr<16'h0080;
wire shared_cs=addr>=16'hf800;
wire nvram_cs=nvram_en && addr[15:8]==8'h10;
wire write_cycle=wr && mcu_vma;
reg [7:0] din;
assign rom_addr=addr[14:0];
assign rom_cs=!core_rst && mcu_vma && !wr && addr>=16'h8000 && addr<16'hf800;
assign shared_addr=addr[10:0];
assign shared_din=dout;
assign shared_we=shared_cs && write_cycle && step && !core_rst;
assign nvram_addr=addr[7:0];
assign nvram_din=dout;
assign nvram_we=nvram_cs && write_cycle && step && !core_rst;
assign debug_view=addr[15:8];
always @* begin
    din=8'hff;
    if(internal_cs) din=internal_data;
    else if(shared_cs) din=shared_dout;
    else if(rom_cs) din=rom_data;
    else if(nvram_cs) din=nvram_dout;
    else case(addr)
        16'h1003: din={4'd0,dipsw[3:0]};
        16'h1005: din={4'd0,dipsw[11:8]};
        16'h1006: din={4'd0,dipsw[19:16]};
        default:;
    endcase
end
jtframe_ram #(
    .AW   ( 7                                               )
) u_internal(
    .clk  ( clk                                             ),
    .cen  ( 1'b1                                            ),
    .addr ( addr[6:0]                                       ),
    .data ( dout                                            ),
    .we   ( internal_cs && write_cycle && step && !core_rst ),
    .q    ( internal_data                                   )
);

always @(posedge clk) begin
    if(core_rst) dac<=0;
    else if(step && write_cycle && addr==16'h2000) dac<=dout[7:4];
end
jt6802 #(
    .FC_COMPAT       ( 1                 )
) u_cpu(
    .irq             ( 1'b0              ),
    .nmi             ( 1'b0              ),
    .ext_halt        ( 1'b0              ),
    .ba              (                   ),
    .rst             ( rst               ),
    .cpu_rst         ( core_rst          ),
    .clk             ( clk               ),
    .cen             ( cen               ),
    .enable          ( dip_pause         ),
    .ready           ( !rom_cs || rom_ok ),
    .mr_n            ( mr_n              ),
    .nsc8105         ( nsc8105           ),
    .din             ( din               ),
    .addr            ( addr              ),
    .dout            ( dout              ),
    .e               ( mcu_e             ),
    .vma             ( mcu_vma           ),
    .wr              ( wr                ),
    .done            ( step              ),
    .instruction_end ( instruction_end   ),
    .opcode_fetch    ( opcode_fetch      )
);
jtseicro_mr u_mr(
    .rst         ( rst         ),
    .clk         ( clk         ),
    .e           ( mcu_e       ),
    .vma         ( mcu_vma     ),
    .a15         ( addr[15]    ),
    .release_clk ( release_clk ),
    .mr_n        ( mr_n        )
);
endmodule
