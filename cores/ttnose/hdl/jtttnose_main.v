/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 01-11-2026 */

module jtttnose_main(
    input rst,
    input clk,
    input dip_pause,
    input lvbl,
    input acia_cen,
    output [23:1] addr,
    output [15:0] dout,
    output [19:1] rom_addr,
    output rom_cs,
    input [15:0] rom_data,
    input rom_ok,
    output [13:1] work_addr,
    output work_cs,
    output work_we,
    output [1:0] work_dsn,
    output [15:0] work_din,
    input [15:0] work_data,
    input work_ok,
    output [1:0] rozgfx_we,
    input [15:0] rozgfx_dout,
    output [1:0] oram_we,
    input [15:0] oram_dout,
    output [1:0] txram_we,
    input [15:0] txram_dout,
    output [1:0] pal_we,
    input [15:0] pal_dout,
    output roz_map_cs,
    output roz_map_we,
    input [7:0] roz_map_dout,
    input roz_map_ok,
    output roz_we,
    output gga_cs,
    output gga_we,
    output gfxbank_we,
    output reg [7:0] snd_latch,
    output snd_wr,
    input snd_pending,
    input [5:0] joystick,
    input [7:0] steering,
    input [7:0] accelerator,
    input [7:0] brake,
    input [3:0] coin,
    input [3:0] cab_1p,
    input service,
    input dip_test,
    input [15:0] dipsw,
    output [7:0] debug_view
);
wire [23:1] a;
wire [2:0] fc;
wire asn,ldsn,udsn,rnw,dtackn,cen,cenb,ready;
wire [1:0] dsn={udsn,ldsn};
wire access_bus=!asn && fc!=3'b111 && dsn!=2'b11;
wire write_bus=access_bus && !rnw;
reg write_seen,lvbl_l,irq6;
wire once=write_bus && !write_seen;
wire code_cs=access_bus && a[23:18]==0;
wire user1_cs=access_bus && a[23:19]==5'b00100;
wire user2_cs=access_bus && a[23:17]==7'b0010110;
wire rozgfx_cs=access_bus && a[23:17]==7'b0100000;
wire oram_cs=access_bus && a[23:12]==12'hffc;
wire tx_cs=access_bus && a[23:12]==12'hffd;
wire pal_cs=access_bus && a[23:12]==12'hffe;
wire in0_cs=access_bus && a==23'h7ff800;
wire in1_cs=access_bus && a==23'h7ff801;
wire dip_cs=access_bus && a==23'h7ff802;
wire latch_cs=access_bus && a==23'h7ff804 && !ldsn;
wire acia_cs=access_bus && a[23:2]==22'h3ffC0c && !ldsn;
wire [7:0] acia_data;
wire acia_irq;
wire [2:0] ipln=irq6 ? 3'b001 : acia_irq ? 3'b100 : 3'b111;
wire inta_n=!(fc==3'b111 && !asn);
wire [1:0] directions={steering>=8'h60,steering<=8'ha0} & joystick[1:0];
wire [15:0] in0={1'b1,~service,1'b1,dip_test,cab_1p[1:0],coin[1:0],
    1'b1,dipsw[14] ? 3'b111 : brake[7:5],directions[0],directions[1],2'b11};
wire [15:0] in0_buttons=(in0 & 16'hffcf)|
    (dipsw[14] ? {10'd0,joystick[4],joystick[5],4'd0} : (in0 & 16'h0030));
wire [15:0] in1=dipsw[14] ? 16'hffff : {9'h1ff,accelerator[7:5],4'hf};
wire [15:0] cpu_din=rom_cs ? rom_data : work_cs ? work_data :
    rozgfx_cs ? rozgfx_dout : roz_map_cs ? {8'hff,roz_map_dout} :
    oram_cs ? oram_dout : tx_cs ? txram_dout : pal_cs ? pal_dout :
    in0_cs ? in0_buttons : in1_cs ? in1 : dip_cs ? dipsw :
    latch_cs ? {15'd0,snd_pending} : acia_cs ? {8'hff,acia_data} : 16'hffff;
assign addr=a;
assign rom_cs=(code_cs || user1_cs || user2_cs) && rnw;
assign rom_addr=user1_cs ? 19'h20000+{1'b0,a[18:1]} :
                user2_cs ? 19'h60000+{3'd0,a[16:1]} : {2'd0,a[17:1]};
assign work_cs=access_bus && a[23:14]==10'h3fe;
assign work_addr=a[13:1];
assign work_we=work_cs && !rnw;
assign work_dsn=dsn;
assign work_din=dout;
assign rozgfx_we={2{rozgfx_cs && write_bus}} & ~dsn;
assign oram_we={2{oram_cs && write_bus}} & ~dsn;
assign txram_we={2{tx_cs && write_bus}} & ~dsn;
assign pal_we={2{pal_cs && write_bus}} & ~dsn;
assign roz_map_cs=access_bus && a[23:12]==12'h500 && !ldsn;
assign roz_map_we=roz_map_cs && write_bus;
assign roz_we=once && a[23:5]==19'h28800 && !ldsn;
assign gga_cs=access_bus && a[23:2]==22'h3ffc08 && !ldsn;
assign gga_we=once && gga_cs;
assign gfxbank_we=once && in0_cs && !ldsn;
assign snd_wr=once && latch_cs;
assign debug_view=a[15:8];
always @(posedge clk) begin
    if(rst) begin
        write_seen<=0;lvbl_l<=0;irq6<=0;snd_latch<=0;
    end else begin
        if(!write_bus) write_seen<=0;
        else if(once) write_seen<=1;
        lvbl_l<=lvbl;
        if(!inta_n && irq6) irq6<=0;
        if(lvbl_l && !lvbl) irq6<=1;
        if(snd_wr) snd_latch<=dout[7:0];
    end
end
`ifdef SIMULATION
reg trace_seen;
integer trace_count;
always @(posedge clk) begin
    if(rst) begin trace_seen<=0;trace_count<=0;end
    else begin
        if(asn || dsn==3) trace_seen<=0;
        if(cenb && !dtackn && access_bus && !trace_seen && trace_count<64) begin
            trace_seen<=1;
            trace_count<=trace_count+1;
            $display("TTNOSE ACK a=%06x rd=%b data=%04x write=%04x fc=%x",{a,1'b0},rnw,cpu_din,dout,fc);
        end
    end
end
always @(posedge clk) begin
    if(!rst && lvbl_l && !lvbl)
        $display("TTNOSE vblank bus=%06x fc=%x irq=%b pending=%b",{a,1'b0},fc,irq6,snd_pending);
    if(!rst && gfxbank_we)
        $display("TTNOSE video control=%02x bus=%06x",dout[7:0],{a,1'b0});
end
`endif

jtframe_okdly #(
    .W ( 3 )
) u_ready(
    .rst    ( rst                         ),
    .clk    ( clk                         ),
    .cs     ( {rom_cs,work_cs,roz_map_cs} ),
    .ok     ( {rom_ok,work_ok,roz_map_ok} ),
    .ok_dly ( ready                       )
);

jtframe_m68k u_cpu(
    .clk      ( clk       ),
    .rst      ( rst       ),
    .cpu_cen  ( cen       ),
    .cpu_cenb ( cenb      ),
    .BERRn    ( 1'b1      ),
    .VPAn     ( inta_n    ),
    .BGACKn   ( 1'b1      ),
    .HALTn    ( dip_pause ),
    .RESETn   (           ),
    .eab      ( a         ),
    .ASn      ( asn       ),
    .LDSn     ( ldsn      ),
    .UDSn     ( udsn      ),
    .eRWn     ( rnw       ),
    .DTACKn   ( dtackn    ),
    .iEdb     ( cpu_din   ),
    .oEdb     ( dout      ),
    .BRn      ( 1'b1      ),
    .BGn      (           ),
    .IPLn     ( ipln      ),
    .FC       ( fc        )
);
jtframe_68kdtack_cen #(
    .W ( 7 )
) u_dtack(
    .rst       ( rst                           ),
    .clk       ( clk                           ),
    .cpu_cen   ( cen                           ),
    .cpu_cenb  ( cenb                          ),
    .bus_cs    ( rom_cs | work_cs | roz_map_cs ),
    .bus_busy  ( ~ready                        ),
    .bus_legit ( 1'b0                          ),
    .bus_ack   ( 1'b0                          ),
    .ASn       ( asn                           ),
    .DSn       ( dsn                           ),
    .num       ( 6'd11                         ),
    .den       ( 7'd63                         ),
    .wait2     ( 1'b0                          ),
    .wait3     ( 1'b0                          ),
    .DTACKn    ( dtackn                        ),
    .fave      (                               ),
    .fworst    (                               )
);
jtttnose_acia u_acia(
    .rst  ( rst             ),
    .clk  ( clk             ),
    .cen  ( acia_cen        ),
    .cs   ( acia_cs         ),
    .we   ( once && acia_cs ),
    .rs   ( a[1]            ),
    .din  ( dout[7:0]       ),
    .dout ( acia_data       ),
    .irq  ( acia_irq        )
);

endmodule
