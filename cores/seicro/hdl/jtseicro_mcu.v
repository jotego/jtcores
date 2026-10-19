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

wire [15:0] addr;
wire [7:0] dout, internal_data;
wire wr, fetch, step, instruction_end;
wire [7:0] next_op;
wire [15:0] legacy_addr, base_addr;
wire [7:0] legacy_dout, base_dout;
wire legacy_wr, legacy_fetch, legacy_step;
wire base_wr, base_e, base_vma, base_done, mr_n;
wire write_cycle=wr && (nsc8105 || base_vma);
reg [7:0] opcode;
wire internal_cs=addr<16'h0080;
wire shared_cs=addr>=16'hf800;
wire nvram_cs=nvram_en && addr[15:8]==8'h10;
reg [7:0] din;
reg [4:0] stall_count;
wire core_rst=rst | cpu_rst | reset_req | ~run;

assign rom_addr=addr[14:0];
assign addr=nsc8105 ? legacy_addr : base_addr;
assign dout=nsc8105 ? legacy_dout : base_dout;
assign wr=nsc8105 ? legacy_wr : base_wr;
assign fetch=nsc8105 ? legacy_fetch : base_vma && !base_wr;
assign rom_cs=!core_rst && !wr && addr>=16'h8000 && addr<16'hf800 &&
              (nsc8105 || base_vma);
assign legacy_step=nsc8105 && cen && dip_pause && stall_count==0 && (!rom_cs || rom_ok);
assign step=nsc8105 ? legacy_step : base_done;
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

always @(posedge clk) begin
    if(core_rst) begin
        stall_count<=0;
        opcode<=0;
        dac<=0;
    end else begin
        if(cen && dip_pause && stall_count!=0) stall_count<=stall_count-5'd1;
        if(legacy_step) begin
            stall_count <= (addr[15] && (fetch || wr) ? 5'd4 : 5'd0) +
                           (instruction_end ? {1'b0,padding(next_op,nsc8105)} : 5'd0);
            if(instruction_end) opcode<=next_op;
        end
        if(step && write_cycle && addr==16'h2000) dac<=dout[7:4];
    end
end

function [3:0] padding;
    input [7:0] op;
    input nsc;
    begin
        case(op)
            8'h60,8'h63,8'h64,8'h66,8'h67,8'h68,8'h69,8'h6a,
            8'h6c,8'h6f,8'ha7,8'he7,8'hbf,8'hff: padding=3;
            8'h8d,8'had: padding=5;
            8'hbd: padding=9;
            8'h9f,8'hdf: padding=1;
            8'haf,8'hef: padding=7;
            default: padding=0;
        endcase
        if(nsc) case(op)
            8'h30,8'h35,8'h6d: padding=padding+4'd4;
            8'h71,8'h7b: padding=8;
            8'hec: padding=3;
            default:;
        endcase
    end
endfunction

jtframe_ram #(
    .AW ( 7 )
) u_internal(
    .clk  ( clk                                             ),
    .cen  ( 1'b1                                            ),
    .addr ( addr[6:0]                                       ),
    .data ( dout                                            ),
    .we   ( internal_cs && write_cycle && step && !core_rst ),
    .q    ( internal_data                                   )
);

jtseicro_m6802_cpu u_cpu(
    .rst             ( core_rst || !nsc8105 ),
    .clk             ( clk                  ),
    .cen             ( legacy_step          ),
    .nsc8105         ( nsc8105              ),
    .wr              ( legacy_wr            ),
    .fetch           ( legacy_fetch         ),
    .instruction_end ( instruction_end      ),
    .next_op         ( next_op              ),
    .addr            ( legacy_addr          ),
    .din             ( din                  ),
    .dout            ( legacy_dout          ),
    .ext_halt        ( 1'b0                 ),
    .ba              (                      ),
    .irq             ( 1'b0                 ),
    .nmi             ( 1'b0                 ),
    .irq_icf         ( 1'b0                 ),
    .irq_ocf         ( 1'b0                 ),
    .irq_tof         ( 1'b0                 ),
    .irq_sci         ( 1'b0                 ),
    .irq_cmf         ( 1'b0                 ),
    .irq2            ( 1'b0                 )
);

jtseicro_m6802 u_base(
    .rst             ( rst                 ),
    .cpu_rst         ( core_rst || nsc8105 ),
    .clk             ( clk                 ),
    .cen             ( cen                 ),
    .enable          ( dip_pause           ),
    .ready           ( !rom_cs || rom_ok   ),
    .mr_n            ( mr_n                ),
    .din             ( din                 ),
    .addr            ( base_addr           ),
    .dout            ( base_dout           ),
    .e               ( base_e              ),
    .vma             ( base_vma            ),
    .wr              ( base_wr             ),
    .done            ( base_done           ),
    .instruction_end (                     )
);

jtseicro_mr u_mr(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .e           ( base_e        ),
    .vma         ( base_vma      ),
    .a15         ( base_addr[15] ),
    .release_clk ( release_clk   ),
    .mr_n        ( mr_n          )
);

endmodule
