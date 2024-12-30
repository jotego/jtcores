/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 23-12-2024 */

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