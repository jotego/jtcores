/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtslap_sound(
    input             rst,
    input             clk,
    input             snd_cen, free_cen, psg_cen,
    input             sound_en,
    input             tigerh,
    input             sha_cs,
    output            sha_ok,
    output     [10:0] ram_addr,
    output      [7:0] ram_dout,
    input       [7:0] ram_data,
    output            ram_we,
    output     [12:0] snd_addr,
    output reg        snd_cs,
    input       [7:0] snd_data,
    input             snd_ok,
    input      [15:0] dipsw,
    input       [5:0] joystick1, joystick2,
    input       [1:0] cab_1p, coin,
    output      [9:0] psg1, psg2
);
`ifndef NOMAIN
wire [15:0] cpu_addr;
wire [ 7:0] cpu_dout, psg1_dout, psg2_dout, directions, buttons;
reg  [ 7:0] cpu_din;
reg  [ 3:0] psg1_addr, psg2_addr;
reg  [13:0] nmi_count;
reg         nmi_en, snd_rst;
wire        rst_n, mreq_n, wr_n, rd_n, rfsh_n, busak_n, busrq_n, nmi_n;
wire        psg1_wr_n, psg2_wr_n;
reg         ram_cs, psg1_cs, psg2_cs, nmi_cs;

assign rst_n = ~snd_rst;
assign busrq_n = ~sha_cs;
assign sha_ok = !sound_en || !busak_n;
assign ram_addr = cpu_addr[10:0];
assign ram_dout = cpu_dout;
assign ram_we = ram_cs && !wr_n && busak_n;
assign snd_addr = cpu_addr[12:0];
// U7A divider tap: 3 MHz / 8192 on Tiger-Heli, / 16384 on Slap Fight.
assign nmi_n = !nmi_en || !(tigerh ? nmi_count[12] : nmi_count[13]);
assign psg1_wr_n = !(psg1_cs && !wr_n && cpu_addr[1]);
assign psg2_wr_n = !(psg2_cs && !wr_n && cpu_addr[1]);
assign directions = {joystick2[3:0],joystick1[3:0]};
assign buttons = tigerh ? {coin,cab_1p,joystick2[5:4],joystick1[5:4]} :
                         {coin,cab_1p,joystick2[4],joystick2[5],joystick1[4],joystick1[5]};

always @(posedge clk) snd_rst <= rst || !sound_en;

always @* begin
    snd_cs = !mreq_n && rfsh_n && cpu_addr[15:13]==0 && !rd_n;
    // U11D Y6 selects C000-DFFF; the 2016 uses only A0-A10.
    ram_cs = !mreq_n && rfsh_n && cpu_addr[15:13]==3'b110;
    psg1_cs = !mreq_n && rfsh_n && cpu_addr[15:4]==12'ha08;
    psg2_cs = !mreq_n && rfsh_n && cpu_addr[15:4]==12'ha09;
    nmi_cs = !mreq_n && rfsh_n && cpu_addr[15:5]==11'h507;
    cpu_din = snd_cs ? snd_data :
              ram_cs ? ram_data :
              psg1_cs ? psg1_dout :
              psg2_cs ? psg2_dout : 8'hff;
end

always @(posedge clk) begin
    if(snd_rst) begin
        psg1_addr <= 0;
        psg2_addr <= 0;
        nmi_en <= 0;
        nmi_count <= 0;
    end else begin
        // U9D /Q holds U7A in reset until the sound timer is started.
        if(!nmi_en) nmi_count <= 0;
        else if(free_cen) nmi_count <= nmi_count+14'd1;
        if(snd_cen && !wr_n) begin
            if(psg1_cs && !cpu_addr[1]) psg1_addr <= cpu_dout[3:0];
            if(psg2_cs && !cpu_addr[1]) psg2_addr <= cpu_dout[3:0];
            // U11E Y6 presets U9D at A0E0; Y7 clocks it at A0F0.
            // Its D wire is undrawn; high is inferred from timer operation.
            // Both accesses keep the divider running until AU_ENABLE resets it.
            if(nmi_cs) nmi_en <= 1;
        end
    end
end

jt49 u_psg1(
    .rst_n  ( rst_n       ),
    .clk    ( clk         ),
    .clk_en ( psg_cen     ),
    .addr   ( psg1_addr   ),
    .cs_n   ( 1'b0        ),
    .wr_n   ( psg1_wr_n   ),
    .din    ( cpu_dout    ),
    .sel    ( 1'b1        ),
    .dout   ( psg1_dout   ),
    .sound  ( psg1        ),
    .A      (             ),
    .B      (             ),
    .C      (             ),
    .sample (             ),
    .IOA_in ( directions  ),
    .IOA_out(             ),
    .IOA_oe (             ),
    .IOB_in ( buttons     ),
    .IOB_out(             ),
    .IOB_oe (             )
);

jt49 u_psg2(
    .rst_n  ( rst_n       ),
    .clk    ( clk         ),
    .clk_en ( psg_cen     ),
    .addr   ( psg2_addr   ),
    .cs_n   ( 1'b0        ),
    .wr_n   ( psg2_wr_n   ),
    .din    ( cpu_dout    ),
    .sel    ( 1'b1        ),
    .dout   ( psg2_dout   ),
    .sound  ( psg2        ),
    .A      (             ),
    .B      (             ),
    .C      (             ),
    .sample (             ),
    .IOA_in ( dipsw[7:0]  ),
    .IOA_out(             ),
    .IOA_oe (             ),
    .IOB_in ( dipsw[15:8] ),
    .IOB_out(             ),
    .IOB_oe (             )
);

jtframe_z80 u_z80(
    .rst_n  ( rst_n    ),
    .clk    ( clk      ),
    .cen    ( snd_cen  ),
    .wait_n ( 1'b1     ),
    .int_n  ( 1'b1     ),
    .nmi_n  ( nmi_n    ),
    .busrq_n( busrq_n  ),
    .m1_n   (          ),
    .mreq_n ( mreq_n   ),
    .iorq_n (          ),
    .rd_n   ( rd_n     ),
    .wr_n   ( wr_n     ),
    .rfsh_n ( rfsh_n   ),
    .halt_n (          ),
    .busak_n( busak_n  ),
    .A      ( cpu_addr ),
    .din    ( cpu_din  ),
    .dout   ( cpu_dout )
);
`else
assign sha_ok=1, ram_addr=0, ram_dout=0, ram_we=0, snd_addr=0;
assign psg1=0, psg2=0;
initial snd_cs=0;
`endif
endmodule
