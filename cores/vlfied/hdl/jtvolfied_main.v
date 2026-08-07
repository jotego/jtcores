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

    Volfied main CPU (68000). Address decode from taito/volfied.cpp:
      000000-03ffff  program ROM
      080000-0fffff  data ROM
      100000-103fff  work RAM
      200000-203fff  PC090OJ sprite RAM    (word_r/word_w)
      400000-47ffff  bitmap VRAM           (video_ram_w, masked) -> jtvolfied_fb
      500000-503fff  palette RAM
      600000         video_mask_w
      700000         PC090OJ sprite_ctrl_w
      d00000         video_ctrl_r / video_ctrl_w
      e00001         PC060HA master_port_w
      e00003         PC060HA master_comm_r/w
      f00000-f007ff  C-chip mem68_r/w      (umask 0x00ff)
      f00800-f00fff  C-chip asic_r/asic68_w(umask 0x00ff)
*/

module jtvolfied_main(
    input                rst,
    input                clk,            // 48 MHz
    input                LVBL,

    output        [19:1] main_addr,
    output        [ 1:0] main_dsn,
    output        [15:0] main_dout,
    output               main_rnw,
    output reg           rom_cs,
    output reg           ram_cs,
    output reg           obj_cs,
    output reg           fb_cs,
    output reg           pal_cs,
    output reg           vmask_cs,       // 600000 video mask write
    output reg           sprctrl_cs,     // 700000 sprite control write
    output reg           vctrl_cs,       // d00000 video control r/w
    output reg    [ 3:0] obj_pal,        // sprite palette bank = sprite_ctrl[5:2]

    input         [15:0] oram_dout,
    input         [15:0] pal_dout,
    input         [15:0] fb_dout,
    input         [15:0] vctrl_dout,
    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,

    // C-chip (TC0030CMD) interface, 8-bit on lower byte
    output reg           cchip_cs,
    output        [11:1] cchip_addr,
    input         [ 7:0] cchip_dout,
    input                cchip_dtackn,

    // bitmap framebuffer in SDRAM (jtvolfied_fb) — fb_ok paces the 68k
    input                fb_ok,

    // Sound interface (PC060HA master side)
    input         [ 7:0] sn_dout,
    output reg           sn_we,
    output reg           sn_rd,

    input                dip_pause
);
`ifndef NOMAIN
wire [23:1] A;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, allFC, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
reg  [15:0] cpu_din;
wire [15:0] cpu_dout;
reg         intn, LVBLl;
wire        bus_cs, bus_busy, bus_legit;

// maincpu region (honouring MAME offsets, no no_offset): program 0x00000-
// 0x3ffff then a 0x40000-0x7ffff FF gap then data 0x80000-0xfffff. The data
// ROM lands at SDRAM 0x80000, matching the 68k map 1:1.
assign main_addr = A[19:1];
assign main_dsn  = {UDSn, LDSn};
assign main_rnw  = RnW;
assign main_dout = cpu_dout;
assign cchip_addr= A[11:1];
assign allFC     = ~&FC;
// VBL is a level-4 autovector interrupt (volfied.cpp: set_input_line(4,...)).
// IPLn[2:0]={IPL2n,IPL1n,IPL0n}; level 4 asserted => 3'b011.
assign IPLn      = { intn, 2'b11 };
assign VPAn      = !(!ASn && FC==7);
assign bus_cs    = rom_cs | ram_cs | fb_cs;
assign bus_busy  = (rom_cs & ~rom_ok) | (ram_cs & ~ram_ok) | (fb_cs & ~fb_ok);
assign bus_legit = 0;

always @* begin
    rom_cs     = allFC && A[23:20]==4'h0 && !ASn;             // 000000-0fffff
    ram_cs     = allFC && A[23:18]==6'h4 && !ASn;             // 100000-103fff
    obj_cs     = allFC && A[23:18]==6'h8 && !ASn;             // 200000-203fff
    fb_cs      = allFC && A[23:19]==5'h8 && !ASn;             // 400000-47ffff
    pal_cs     = allFC && A[23:18]==6'h14&& !ASn;             // 500000-503fff
    vmask_cs   = allFC && A[23:20]==4'h6 && !ASn && !RnW;     // 600000
    sprctrl_cs = allFC && A[23:20]==4'h7 && !ASn && !RnW;     // 700000
    vctrl_cs   = allFC && A[23:20]==4'hd && !ASn;             // d00000
    cchip_cs   = allFC && A[23:20]==4'hf && !ASn;             // f00000-f00fff

    // PC060HA master interface at e00001 (port) / e00003 (comm), odd byte -> LDS.
    // A[1] selects port(0) vs comm(1); jtvolfied_snd takes A[1] as its "main_addr".
    sn_we = allFC && A[23:20]==4'he && !ASn && !LDSn && !RnW;
    sn_rd = allFC && A[23:20]==4'he && !ASn && !LDSn &&  RnW;
end

always @(posedge clk) begin
    cpu_din <= rom_cs   ? rom_data :
               ram_cs   ? ram_dout :
               obj_cs   ? oram_dout :
               pal_cs   ? pal_dout  :
               fb_cs    ? fb_dout   :
               vctrl_cs ? vctrl_dout :
               cchip_cs ? { 8'hff, cchip_dout } :
               sn_rd    ? { 8'hff, sn_dout }    :
               16'hffff;
end

// sprite control (0x700000). volfied.cpp colpri_cb:
//   sprite_colbank = 0x100 | ((sprite_ctrl & 0x3c) << 2)
// PC090OJ pen = (colbank+color)*16+pixel => palette idx = {1, sprite_ctrl[5:2], obj_pxl}
always @(posedge clk, posedge rst) begin
    if( rst ) obj_pal <= 0;
    else if( sprctrl_cs && !main_rnw ) obj_pal <= cpu_dout[5:2];
end

// VBL interrupt
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        LVBLl <= 0;
        intn  <= 1;
    end else begin
        LVBLl <= LVBL;
        if( !VPAn )
            intn <= 1;
        else if( !LVBL && LVBLl )
            intn <= 0;
    end
end

jtframe_68kdtack_cen #(.W(8)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( bus_legit ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 7'd1      ),
    .den        ( 8'd6      ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
);

`ifdef SIMULATION
// Boot-progress instrumentation (mirrors the MAME boot order:
// VCTRL-W -> VMASK-W -> PC060 -> C-chip RAM init -> palette/obj/bitmap).
integer vctrl_w=0, vmask_w=0, sn_w=0, cchip_a=0, ram_w=0, pal_w=0, obj_w=0, fb_w=0;
reg vctrl_l=0, vmask_l=0, sn_l=0, cchip_l=0, ram_l=0, pal_l=0, obj_l=0, fb_l=0;
reg [27:0] heart=0; integer cen_cnt=0;
always @(posedge clk) if(!rst) begin
    vctrl_l<=vctrl_cs; vmask_l<=vmask_cs; sn_l<=(sn_we|sn_rd);
    cchip_l<=cchip_cs; ram_l<=ram_cs; pal_l<=pal_cs; obj_l<=obj_cs; fb_l<=fb_cs;
    if(vctrl_cs&~vctrl_l&~RnW) vctrl_w<=vctrl_w+1;
    if(vmask_cs&~vmask_l)      vmask_w<=vmask_w+1;
    if((sn_we|sn_rd)&~sn_l)    sn_w  <=sn_w+1;
    if(cchip_cs&~cchip_l)      cchip_a<=cchip_a+1;
    if(ram_cs&~ram_l&~RnW)     ram_w <=ram_w+1;
    if(pal_cs&~pal_l&~RnW)     pal_w <=pal_w+1;
    if(obj_cs&~obj_l&~RnW)     obj_w <=obj_w+1;
    if(fb_cs&~fb_l&~RnW)       fb_w  <=fb_w+1;
    if(cpu_cen) cen_cnt<=cen_cnt+1;
    heart<=heart+1;
    if(heart[23:0]==0) begin
      $display("[%0t] VOLDBG cen=%0d pause=%b A=%06x ASn=%b LVBL=%b intn=%b | vctrl=%0d vmask=%0d snd=%0d cchip=%0d ram=%0d pal=%0d obj=%0d fb=%0d",
        $time,cen_cnt,dip_pause,{A,1'b0},ASn,LVBL,intn,vctrl_w,vmask_w,sn_w,cchip_a,ram_w,pal_w,obj_w,fb_w);
      cen_cnt<=0;
    end
end
// Interrupt-ack + PC-in-RAM detector. Log each IACK (FC==7) and the first
// time the CPU fetches an instruction from RAM (PC gone wild).
reg asn_l2=1; reg pcwild=0, booted=0;
reg [23:0] rp0=0, rp1=0, rp2=0, rp3=0;   // last 4 distinct program PCs
always @(posedge clk) if(!rst) begin
    asn_l2<=ASn;
    if(asn_l2 && !ASn && FC==3'd6) begin   // supervisor program fetch
        if({A,1'b0}>=24'h1400) booted<=1;  // boot main code reached
        // Real derail = program fetch from the work-RAM region (0x100000+).
        // (The game legitimately runs code below 0x1400, e.g. 0xf9a, so that
        // is NOT a derail.)
        if(!pcwild && {A,1'b0}>=24'h100000 && {A,1'b0}<24'h400000) begin
            pcwild<=1;
            $display("[%0t] *** PC DERAIL *** prev PCs %06x,%06x,%06x,%06x -> %06x  intn=%b",
                     $time,rp3,rp2,rp1,rp0,{A,1'b0},intn);
        end
        if(!pcwild && {A,1'b0}!=rp0) begin
            rp3<=rp2; rp2<=rp1; rp1<=rp0; rp0<={A,1'b0};   // shift history
        end
    end
end
`endif

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),

    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),

    .BERRn      ( 1'b1        ),
    .HALTn      ( dip_pause   ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    // Non-SDRAM regions (obj/pal/fb/vctrl/sound/C-chip) are auto-acked by
    // u_dtack when bus_cs=0. The C-chip stub is BRAM-fast so it needs no extra
    // wait state; cchip_dtackn is reserved for the real-MCU path (REAL_MCU=1).
    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        )
);
wire _unused_dtack = &{1'b0, cchip_dtackn};
`else
assign main_addr=0, main_dsn=0, main_dout=0, main_rnw=1, cchip_addr=0;
initial begin
    rom_cs=0; ram_cs=0; obj_cs=0; fb_cs=0; pal_cs=0;
    vmask_cs=0; sprctrl_cs=0; vctrl_cs=0; cchip_cs=0; sn_we=0; sn_rd=0; obj_pal=0;
end
`endif
endmodule
