/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-9-2026 */

module jtnnjema_snd(
    input             rst,
    input             clk,
    input             cen4,

    input      [ 7:0] snd_latch,
    output            latch_clr,

    // ROM
    output reg        rom_cs,
    output     [15:0] rom_addr,
    input      [ 7:0] rom_data,
    input             rom_ok,

    output signed [15:0] fm,
    output reg [ 7:0] dac1,
    output reg [ 7:0] dac2
);

`ifndef NOSOUND
wire [15:0] A;
wire [ 7:0] cpu_dout, ram_dout, fm_dout;
wire        mreq_n, iorq_n, rd_n, wr_n, m1_n, rfsh_n;
wire        cen_eff;
reg         ram_cs, fm_cs;
reg         int_n;
reg  [ 8:0] intcnt;
wire [ 7:0] cpu_din;

wire iorq = !iorq_n && m1_n;
wire iowr = iorq && !wr_n;
wire iord = iorq && !rd_n;

assign rom_addr  = A;
assign latch_clr = iord && A[7:0]==8'h04;

always @* begin
    rom_cs = !mreq_n && rfsh_n && !rd_n && A<16'hc000;
    ram_cs = !mreq_n && rfsh_n && A[15:11]==5'b11000;   // C000-C7FF
    fm_cs  = iowr && A[7:1]==0;
end

always @(posedge clk) begin
    if( rst ) begin
        dac1 <= 8'h80;
        dac2 <= 8'h80;
    end else if( iowr ) begin
        if( A[7:0]==8'h02 ) dac1 <= cpu_dout;
        if( A[7:0]==8'h03 ) dac2 <= cpu_dout;
    end
end

// periodic interrupt, 4MHz/512 = 7.8kHz, held until acknowledged
always @(posedge clk) begin
    if( rst ) begin
        intcnt <= 0;
        int_n  <= 1;
    end else begin
        if( cen4 ) begin
            intcnt <= intcnt+9'd1;
            if( &intcnt ) int_n <= 0;
        end
        if( !iorq_n && !m1_n ) int_n <= 1;
    end
end

assign cpu_din = rom_cs ? rom_data :
                 ram_cs ? ram_dout :
                 (iord && A[7:0]==8'h06) ? snd_latch :
                 (iord && A[7:0]==8'h04) ? 8'h00     : 8'hff;

jtframe_z80 u_cpu(
    .rst_n   ( ~rst      ),
    .clk     ( clk       ),
    .cen     ( cen_eff   ),
    .wait_n  ( 1'b1      ),
    .int_n   ( int_n     ),
    .nmi_n   ( 1'b1      ),
    .busrq_n ( 1'b1      ),
    .m1_n    ( m1_n      ),
    .mreq_n  ( mreq_n    ),
    .iorq_n  ( iorq_n    ),
    .rd_n    ( rd_n      ),
    .wr_n    ( wr_n      ),
    .rfsh_n  ( rfsh_n    ),
    .halt_n  (           ),
    .busak_n (           ),
    .A       ( A         ),
    .din     ( cpu_din   ),
    .dout    ( cpu_dout  )
);

jtframe_z80wait #(.DEVCNT(1),.RECOVERY(0)) u_wait(
    .rst_n   ( ~rst      ),
    .clk     ( clk       ),
    .cen_in  ( cen4      ),
    .cen_out ( cen_eff   ),
    .gate    (           ),
    .mreq_n  ( mreq_n    ),
    .iorq_n  ( iorq_n    ),
    .busak_n ( 1'b1      ),
    .dev_busy( 1'b0      ),
    .rom_cs  ( rom_cs    ),
    .rom_ok  ( rom_ok    )
);

jtframe_ram #(.AW(11)) u_ram(
    .clk  ( clk       ),
    .cen  ( 1'b1      ),
    .addr ( A[10:0]   ),
    .data ( cpu_dout  ),
    .we   ( ram_cs & ~mreq_n & ~wr_n ),
    .q    ( ram_dout  )
);

jtopl u_opl(
    .rst     ( rst       ),
    .clk     ( clk       ),
    .cen     ( cen4      ),
    .din     ( cpu_dout  ),
    .dout    ( fm_dout   ),
    .addr    ( A[0]      ),
    .cs_n    ( ~fm_cs    ),
    .wr_n    ( wr_n      ),
    .irq_n   (           ),
    .snd     ( fm        ),
    .sample  (           )
);

`else
initial begin
    rom_cs=0; dac1=0; dac2=0;
end
assign rom_addr  = 0;
assign latch_clr = 0;
assign fm        = 0;
`endif
endmodule
