/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

module jt6802 #(parameter EXT_DECODE=0)(
    input             rst,
    input             cpu_rst,
    input             clk,
    input             cen,
    input             enable,
    input             ready,
    input             mr_n,
    input      [ 7:0] din,
    input      [ 7:0] opcode,
    output     [ 7:0] opcode_raw,
    output     [15:0] addr,
    output     [ 7:0] dout,
    output            e,
    output            vma,
    output            wr,
    output            done,
    output            instruction_end,
    output            opcode_fetch,
    input             ext_halt,
    output            ba,
    input             irq,
    input             nmi
);

wire        cpu_vma, cpu_wr, ni, halt, irq_ack;
wire [15:0] cpu_addr;
wire [ 7:0] cpu_dout;
reg  [ 1:0] phase;
reg         stretch, syncing, started, was_halt;
reg         irq_pending, nmi_pending, nmi_l;
reg  [15:0] held_addr;
reg  [ 7:0] held_dout;
reg         held_vma, held_wr;
wire        engine_rst = rst | cpu_rst | syncing;
wire        stalled = phase[1] && (!ready || !mr_n || stretch);
wire        bus_cen = cen && enable && (engine_rst || !stalled);
wire        cpu_cen = !engine_rst && bus_cen && (!(halt || ba) || phase==3);
wire        cpu_irq = irq | irq_pending;
wire        cpu_nmi = nmi | nmi_pending;

assign e = phase[1];
assign addr = e ? held_addr : cpu_addr;
assign dout = phase==3 ? held_dout : cpu_dout;
assign vma = !engine_rst && !ba && (e ? held_vma : cpu_vma);
assign wr = !engine_rst && !ba && (e ? held_wr : cpu_wr);
assign done = !engine_rst && cpu_cen && phase==3 && !ba && vma;
assign opcode_fetch = done && ni;
assign instruction_end = !engine_rst && cpu_cen && started && (ni || (halt && !was_halt));

always @(posedge clk) begin
    if(rst || cpu_rst) begin
        syncing     <= 1;
        started     <= 0;
        was_halt    <= 0;
        irq_pending <= 0;
        nmi_pending <= 0;
        nmi_l       <= 0;
        held_addr   <= 0;
        held_dout   <= 0;
        held_vma    <= 0;
        held_wr     <= 0;
    end else begin
        if(bus_cen && phase==3) syncing <= 0;
        if(cen && enable) begin
            if(nmi && !nmi_l) nmi_pending <= 1;
            if(irq && (ba || ext_halt)) irq_pending <= 1;
            nmi_l <= nmi;
            if(cpu_cen && ni && !halt && !ext_halt) begin
                nmi_pending <= 0;
            end
            if(irq_ack) irq_pending <= 0;
        end
        if(cpu_cen) begin
            was_halt <= halt;
            if(ni) started <= 1;
            if(phase==2) held_dout <= cpu_dout;
            if(phase==1) begin
                held_addr <= cpu_addr;
                held_vma  <= cpu_vma;
                held_wr   <= cpu_wr;
            end
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        phase   <= 0;
        stretch <= 0;
    end else begin
        if(bus_cen) phase <= phase+1'd1;
        if(engine_rst) stretch <= 0;
        else if(cen && enable && phase[1]) stretch <= !mr_n && !stretch;
    end
end

jt680x #(.EXT_DECODE(EXT_DECODE)) u_cpu(
    .rst       ( engine_rst ),
    .clk       ( clk        ),
    .cen       ( cpu_cen    ),
    .wr        ( cpu_wr     ),
    .addr      ( cpu_addr   ),
    .din       ( din        ),
    .opcode    ( opcode     ),
    .opcode_raw( opcode_raw ),
    .dout      ( cpu_dout   ),
    .ni        ( ni         ),
    .halt      ( halt       ),
    .vma       ( cpu_vma    ),
    .irq_ack   ( irq_ack    ),
    .ext_halt  ( ext_halt   ),
    .ba        ( ba         ),
    .irq       ( cpu_irq    ),
    .nmi       ( cpu_nmi    ),
    .irq_icf   ( 1'b0       ),
    .irq_ocf   ( 1'b0       ),
    .irq_tof   ( 1'b0       ),
    .irq_sci   ( 1'b0       ),
    .irq_cmf   ( 1'b0       ),
    .irq2      ( 1'b0       )
);

endmodule
