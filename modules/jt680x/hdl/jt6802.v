/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-10-2026 */

module jt6802 #(parameter FC_COMPAT=0)(
    input             rst, cpu_rst, clk, cen, enable,
    input             ready, mr_n, nsc8105,
    input      [ 7:0] din,
    output     [15:0] addr,
    output     [ 7:0] dout,
    output            e, vma, wr, done, instruction_end, opcode_fetch,
    input             ext_halt,
    output            ba,
    input             irq, nmi
);

wire reset_cpu = rst || cpu_rst;
reg [1:0] phase;
reg stretch, started, was_halt, syncing;
wire engine_rst = reset_cpu || syncing;
reg [15:0] held_addr;
reg [7:0] held_dout;
reg held_vma, held_wr;
wire [15:0] cycle_addr;
wire [7:0] cycle_dout, raw_opcode, opcode;
wire cycle_wr, cycle_vma, ni, halt, legal;
wire stalled = phase[1] && (!ready || !mr_n || stretch);
wire bus_cen = cen && enable && (engine_rst || (!stalled && !illegal));
wire cpu_cen = !engine_rst && bus_cen && (!(halt || ba) || phase==3);
reg illegal;

assign e = phase[1];
assign addr = e ? held_addr : cycle_addr;
assign dout = phase==3 ? held_dout : cycle_dout;
assign vma = !engine_rst && !ba && (e ? held_vma : cycle_vma);
assign wr = !engine_rst && !ba && (e ? held_wr : cycle_wr);
assign done = !engine_rst && cpu_cen && phase==3 && !ba;
assign opcode_fetch = done && ni;
assign instruction_end = !engine_rst && cpu_cen && started && (ni || (halt && !was_halt));

always @(posedge clk) begin
    if(reset_cpu) begin
        syncing <= 1;
        started <= 0;
        was_halt <= 0;
        illegal <= 0;
        held_addr <= 0;
        held_dout <= 0;
        held_vma <= 0;
        held_wr <= 0;
    end else begin
        if(bus_cen && phase==3) syncing <= 0;
        if(cpu_cen) begin
            was_halt <= halt;
            if(ni) begin
                started <= 1;
                if(!legal) illegal <= 1;
            end
            if(phase==2) held_dout <= cycle_dout;
            if(phase==1) begin
                held_addr <= cycle_addr;
                held_vma <= cycle_vma;
                held_wr <= cycle_wr;
            end
        end
    end
end

`ifdef SIMULATION
always @(posedge clk) if(!engine_rst && illegal && enable)
    $fatal(1,"MC6802 unsupported opcode %h",raw_opcode);
`endif

always @(posedge clk) begin
    if(rst) begin
        phase <= 0;
        stretch <= 0;
    end else begin
        if(bus_cen) phase <= phase+1'd1;
        if(engine_rst) stretch <= 0;
        else if(cen && enable && phase[1]) stretch <= !ready ? stretch : !mr_n && !stretch;
    end
end

jt6802_decode #(
    .FC_COMPAT  ( FC_COMPAT  )
) u_decode(
    .nsc8105    ( nsc8105    ),
    .raw        ( raw_opcode ),
    .opcode     ( opcode     ),
    .legal      ( legal      )
);

jt680x #(
    .MC6800     ( 1          ),
    .EXT_DECODE ( 1          )
) u_cpu(
    .rst        ( engine_rst ),
    .clk        ( clk        ),
    .cen        ( cpu_cen    ),
    .din        ( din        ),
    .addr       ( cycle_addr ),
    .dout       ( cycle_dout ),
    .wr         ( cycle_wr   ),
    .vma        ( cycle_vma  ),
    .opcode     ( opcode     ),
    .opcode_raw ( raw_opcode ),
    .ni         ( ni         ),
    .halt       ( halt       ),
    .ext_halt   ( ext_halt   ),
    .ba         ( ba         ),
    .irq        ( irq        ),
    .nmi        ( nmi        ),
    .irq_icf    ( 1'b0       ),
    .irq_ocf    ( 1'b0       ),
    .irq_tof    ( 1'b0       ),
    .irq_sci    ( 1'b0       ),
    .irq_cmf    ( 1'b0       ),
    .irq2       ( 1'b0       )
);
endmodule
