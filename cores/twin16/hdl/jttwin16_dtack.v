/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-12-2024 */

module jttwin16_dtack(
    input             clk,
    input             oram_cs,
    output            oeff_cs,
    input             vram_cs,
    input             ASn,
    input             RnW,
    input             UDSn,
    input             LDSn,
    input             tim,
    input             ab_sel,
    input             dma_bsy,
    input             pre_dtackn,
    input      [15:0] ma_dout, mb_dout, mo_dout,
    output reg [15:0] vdout,
    output            DTACKn
);

reg  vo_dtackn, waits, dout_okn;
wire vacc, avalid;

assign oeff_cs = ~dma_bsy & oram_cs;
assign vacc    = (vram_cs | oram_cs) & avalid;
assign DTACKn  = vacc ? vo_dtackn : pre_dtackn;
assign avalid  = !ASn && (RnW || {UDSn,LDSn}!=3);

always @(posedge clk) begin
    vo_dtackn <= dout_okn;
    if(tim) begin
        if( vacc ) waits <= ~(vram_cs | (oram_cs&~dma_bsy));
        if(!waits) begin
            vdout     <= oram_cs ? mo_dout : ab_sel ? ma_dout : mb_dout;
            dout_okn  <= 0;
        end
    end else begin
        waits <= 1;
    end
    if( ASn ) begin
        dout_okn  <= 1;
        vo_dtackn <= 1;
        waits     <= 1;
    end
end

endmodule