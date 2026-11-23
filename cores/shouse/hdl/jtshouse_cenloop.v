/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-9-2023 */

module jtshouse_cenloop(
    input             rst,
    input             clk,
    input      [ 2:0] busy,

    output            cen_main, cen_sub, cen_mcu, cen_sndq,
    output            snd_sel,
    output            cen_snd,

    output     [15:0] fave, fworst // average cpu_cen frequency in kHz
);

parameter FCLK = 49152,
          FCPU =  1536*4, // 49152/1536/4 = 8
          NUM  = 1,
          DEN  = FCLK/FCPU,
          CW   = $clog2(FCLK/FCPU)+4;

reg     [3:0] cpu_cen=0;
reg     [1:0] clk4=0;
reg           rst_l=0;
wire          restart = rst_l & ~rst;
wire          over;
wire [  CW:0] cencnt_nx;
reg  [CW-1:0] cencnt=0;
reg     [1:0] blank=0;
reg           aux_snd=0, cen_snd_r=0, snd_sel_r=0;
wire          bsyg = busy==0 || rst;

assign over      = &blank && cencnt > DEN[CW-1:0]-{NUM[CW-2:0],1'b0};
assign cencnt_nx = {1'b0,cencnt}+NUM[CW:0] -
                   (over && bsyg ? DEN[CW:0] : {CW+1{1'b0}});

assign cen_main = cpu_cen[0] & ~restart;
assign cen_sub  = cpu_cen[1] & ~restart;
assign cen_mcu  =|cpu_cen[3:0] & ~restart;
assign cen_sndq = cpu_cen[1] & ~restart;
assign cen_snd  = cen_snd_r & ~restart;
assign snd_sel  = snd_sel_r & ~restart;

always @(posedge clk) begin
    rst_l <= rst;
   {cen_snd_r,aux_snd} <= restart ? 2'd0 : {aux_snd,cpu_cen[3]};
    snd_sel_r <= cen_mcu & cen_sub;
end

`ifdef SIMULATION
reg aux2;
always @(posedge clk) aux2 <= cen_snd;
always @* begin
    if( aux2 && cen_mcu ) begin
        $display("Tri RAM clash possible");
        $stop;
    end
end
`endif

always @(posedge clk) begin
    if( ~&blank ) blank <= blank + 1'd1 ;
    cencnt  <= cencnt_nx[CW] ? {CW{1'b1}} : cencnt_nx[CW-1:0];
    if( over && bsyg ) begin
        blank <= 0;
        clk4 <= clk4+2'd1;
        cpu_cen[0] <= clk4==0;
        cpu_cen[1] <= clk4==2;
        cpu_cen[2] <= clk4==1;
        cpu_cen[3] <= clk4==3;
    end else begin
        cpu_cen <= 0;
    end
    if( restart ) begin
        clk4    <= 0;
        cencnt  <= 0;
        blank   <= 0;
        cpu_cen <= 0;
    end
end

jtframe_freqinfo #(.MFREQ( FCLK )) u_info(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pulse      ( cpu_cen[0]),
    .fave       ( fave      ), // average cpu_cen frequency in kHz
    .fworst     ( fworst    )
);

endmodule