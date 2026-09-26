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

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 19-9-2026
*/

// System FL main board: i960KA + address decoder per MAME namcofl.cpp
// The 32-bit CPU bus is split into 16-bit halves for RAM/registers, and
// byte cycles for the C116/spritebank. ROM regions read the SDRAM directly,
// so do code fetches and data loads from work RAM (wram32, 32-bit read-only)
// Writes are posted (except sysreg), the next access waits for the funnel
// sysreg map (32-bit word offsets): 2 = RAM/ROM swap, 10-13 = IRQ0-3 ack
// IRQs: 0 network timer (vbl+3 lines), 1 raster (C116), 2 vblank (vbl+1)

module jtsysfl_main(
    input             rst,
    input             clk,
    input             cpu_cen,      // 20 MHz
    // video timing
    input             lvbl, hs,
    input             raster_irqn,
    // program+data ROM, SDRAM bank 0
    output reg [21:2] main_addr,
    output            main_cs,
    input             main_ok,
    input      [31:0] main_data,
    // work RAM, SDRAM bank 2
    output reg [20:1] wram_addr,
    output reg        wram_cs,
    output reg        wram_we,
    output reg [15:0] wram_din,
    output reg [ 1:0] wram_dsn,
    input             wram_ok,
    input      [15:0] wram_data,
    // work RAM code fetches, 32-bit read-only view of the same bank
    output     [20:2] wram32_addr,
    output            wram32_cs,
    input             wram32_ok,
    input      [31:0] wram32_data,
    // BRAMs, CPU ports
    output     [15:1] cvram_addr,
    output     [15:0] cvram_din,
    output     [ 1:0] cvram_we,
    input      [15:0] cvram_dout,
    output     [16:1] crozram_addr,
    output     [15:0] crozram_din,
    output     [ 1:0] crozram_we,
    input      [15:0] crozram_dout,
    output     [16:1] coram_addr,
    output     [15:0] coram_din,
    output     [ 1:0] coram_we,
    input      [15:0] coram_dout,
    output     [14:1] share_addr,
    output     [15:0] share_din,
    output     [ 1:0] share_we,
    input      [15:0] share_dout,
    output     [12:1] backup_addr,
    output     [15:0] backup_din,
    output     [ 1:0] backup_we,
    input      [15:0] backup_dout,
    // video registers
    output            scfg_cs, rozcfg_cs,
    output     [ 5:1] cfg_addr,
    output            cpu_rnw,
    output     [ 1:0] vdsn,
    output     [15:0] vcpu_dout,
    input      [15:0] scfg_dout, rozcfg_dout,
    output            pal_cs,
    output     [14:0] pal_amux,
    output     [ 7:0] pal_din,
    input      [ 7:0] pal_dout,
    // sprite bank MMR
    output            misc_cs,
    output     [ 1:0] misc_addr,
    output     [ 7:0] misc_din,
    // debug
    output            halted
);

localparam [3:0] T_NONE=4'd0, T_WRAM=4'd1, T_NVRAM=4'd2, T_SHARE=4'd3,
                 T_COM =4'd4, T_VRAM=4'd5, T_ROZR =4'd6, T_ORAM =4'd7,
                 T_SCFG=4'd8, T_ROZC=4'd9, T_PAL  =4'd10,T_MISC =4'd11,
                 T_INT =4'd12,T_SYS =4'd13,T_NET  =4'd14,T_UNK  =4'd15;
localparam [1:0] IDLE=2'd0, SETUP=2'd1, WAIT=2'd2;

// CPU bus
wire [31:2] ca;
wire [31:0] cdout;
reg  [31:0] cdin;
wire [ 3:0] cdsn;
wire        ccs, cwr, cfetch;
reg         fok;
wire        cok;
wire [31:0] a = {ca, 2'd0};

// decode, live side: ROM goes straight to the 32-bit SDRAM bus
reg         bank_sel;   // 1 = ROM at 0, RAM at 0x10000000 (reset value)
wire        lowmem  = a[31:29]==3'd0;               // 0x0/0x1 x0000000
wire        is_prog = lowmem && (a[28] != bank_sel);
wire        is_wram = lowmem && (a[28] == bank_sel);
wire        is_data = a[31:28]==4'h2;
wire        is_rom32= (is_prog || is_data) && !cwr;
wire        is_code, is_wdat, is_w32;
wire        is_sys  = a[31:28]==4'h4;
// nvram is a BRAM (SD-card save/restore); comram lives in the wram window
wire        is_cm   = ccs && a[31:28]==4'h3 && a[23:20]==4'h3 && !a[19];
wire        post    = cwr && !is_sys;               // posted write

assign main_cs = ccs && is_rom32;
always @* begin
    main_addr = is_data ? 20'h40000 + {1'b0, a[20:2]} : {2'd0, a[19:2]};
end
assign wram32_cs   = ccs && is_w32;
assign wram32_addr = a[20:2];
assign cok = is_rom32 ? main_ok : is_w32 ? wram32_ok : fok;

// the wram32 slot serves its last fetched words without reading the SDRAM
// (jtframe_romrq_bcache keeps two): shadow its recent misses, flag the ones
// written since and read those, or anything while a write is posted, through
// the 16-bit path. Depth must be >= the slot's, extra depth is harmless
localparam SHW=4;
reg  [20:2]    sh_a[0:SHW-1];
reg  [SHW-1:0] sh_v, sh_d;
reg            sh_hit, sh_dirty;
integer        si;

always @* begin
    sh_hit   = 0;
    sh_dirty = 0;
    for( si=0; si<SHW; si=si+1 ) if( sh_v[si] && sh_a[si]==a[20:2] ) begin
        sh_hit = 1;
        if( sh_d[si] ) sh_dirty = 1;
    end
end

// 16-bit half funnel, works on the latched request so writes can be posted
reg  [ 1:0] st;
reg  [31:2] fa;
reg  [31:0] fd;
reg  [ 3:0] fdsn;
reg         fwr, half, bytesel;
reg  [ 1:0] cnt;
reg  [15:0] f_lo, f_hi, rd16;
reg  [31:0] intram[0:3];
reg  [ 3:0] tgt;
wire [31:0] la     = {fa, 2'd0};
assign is_wdat = is_wram && !cwr && !cfetch && st==IDLE && !sh_dirty;
// code fetches obey the same dirty/posted-write rules as data loads
assign is_code = is_wram && !cwr &&  cfetch && st==IDLE && !sh_dirty;
assign is_w32  = is_code || is_wdat;
wire        l_wram = la[31:29]==3'd0 && la[28]==bank_sel;
wire [15:0] h_wdat = half ? fd[31:16] : fd[15:0];
wire [ 1:0] h_dsn  = half ? fdsn[3:2] : fdsn[1:0];
wire        skip_hi= fwr && &fdsn[3:2];                 // nothing to write
wire [16:1] ha     = {la[16:2], half};
wire [15:0] sbyte  = {la[15:2], half, 1'b0} - 16'h4000; // shareram at 0x...4000
wire        bwr    = st==WAIT && cnt==0 && fwr;         // BRAM write pulse
wire [ 1:0] blanes = ~h_dsn;
wire [ 7:0] net_b0, net_b1;
reg         irq2_ff, irq1_ff, irq0_ff;
integer     j;

always @* begin
    tgt = T_NONE;
    if( l_wram ) tgt = T_WRAM;
    else if( la[31:28]==4'h3 ) case( la[23:20] )
        4'h0: tgt = T_NVRAM;
        4'h1: tgt = T_MISC;                         // sprite bank
        4'h2: tgt = T_SHARE;
        4'h3: tgt = la[19] ? T_NET : T_COM;
        4'h4: tgt = T_PAL;
        4'h8: tgt = T_VRAM;
        4'ha: tgt = T_SCFG;
        4'hc: tgt = T_ROZR;
        4'hd: tgt = T_ROZC;
        4'he: tgt = T_ORAM;
        4'hf: tgt = T_INT;
        default: tgt = T_NONE;
    endcase
    else if( la[31:28]==4'h4 ) tgt = T_SYS;
    else if( la[31:28]==4'hf ) tgt = T_UNK;
end

assign cvram_addr   = ha[15:1];
assign crozram_addr = ha[16:1];
// C355 page 1 attr/list writes also land on page 0, which is the one drawn
// (MAME namco_c355spr spriteram_w). Second write one clock after bwr
wire        oattr1  = ha[16:13]==4'b1000;               // 10000-11fff
wire        olist1  = ha[16:10]==7'b1010_000;           // 14000-143ff
wire        omir_we = tgt==T_ORAM && st==WAIT && cnt==1 && fwr && (oattr1 || olist1);
assign coram_addr   = !omir_we ? ha[16:1] :
                      oattr1   ? ha[16:1] - 16'h8000 : ha[16:1] - 16'h9000;
assign share_addr   = sbyte[14:1];
assign cvram_din    = h_wdat;
assign crozram_din  = h_wdat;
assign coram_din    = h_wdat;
assign share_din    = h_wdat;
assign backup_addr   = ha[12:1];
assign backup_din    = h_wdat;
assign cvram_we     = tgt==T_VRAM  && bwr ? blanes : 2'd0;
assign crozram_we   = tgt==T_ROZR  && bwr ? blanes : 2'd0;
assign coram_we     = (tgt==T_ORAM && bwr) || omir_we ? blanes : 2'd0;
assign share_we     = tgt==T_SHARE && bwr ? blanes : 2'd0;
assign backup_we     = tgt==T_NVRAM && bwr ? blanes : 2'd0;
// video registers, held through WAIT
assign scfg_cs   = tgt==T_SCFG && st==WAIT;
assign rozcfg_cs = tgt==T_ROZC && st==WAIT;
assign cfg_addr  = {la[5:2], half};
assign cpu_rnw   = ~fwr;
assign vdsn      = h_dsn;
assign vcpu_dout = h_wdat;
// byte devices
wire [7:0] bdat  = tgt==T_PAL ? pal_dout : 8'd0; // sprite bank is write-only
assign pal_cs    = tgt==T_PAL  && st==WAIT && !(fwr && h_dsn[bytesel]);
assign misc_cs   = tgt==T_MISC && st==WAIT && fwr && !h_dsn[bytesel];
assign pal_amux  = {la[14:2], half, bytesel};
assign pal_din   = bytesel ? h_wdat[15:8] : h_wdat[7:0];
assign misc_din  = pal_din;
assign misc_addr = {half, bytesel};
// network registers: 0x7d at byte address 2, 0xff on even, 0 on odd bytes
assign net_b0 = ({la[7:2],half}==7'b0000001) ? 8'h7d : 8'hff;
assign net_b1 = 8'h00;

// read data mux
always @* begin
    case( tgt )
    T_WRAM, T_COM: rd16 = wram_data;
    T_NVRAM: rd16 = backup_dout;
    T_SHARE: rd16 = share_dout;
    T_VRAM:  rd16 = cvram_dout;
    // byte devices assemble the low byte a pass earlier; hdone must not wipe it
    T_PAL:   rd16 = {bdat, half ? f_hi[7:0] : f_lo[7:0]};
    T_ROZR:  rd16 = crozram_dout;
    T_ORAM:  rd16 = coram_dout;
    T_SCFG:  rd16 = scfg_dout;
    T_ROZC:  rd16 = rozcfg_dout;
    T_INT:   rd16 = half ? intram[la[3:2]][31:16] : intram[la[3:2]][15:0];
    T_NET:   rd16 = {net_b1, net_b0};
    T_UNK:   rd16 = 16'hffff;
    default: rd16 = 16'h0;      // sysreg reads 0, like MAME
    endcase
end

// half done: latch the data, move to the other half or finish
task hdone;
begin
    if( half ) f_hi <= rd16; else f_lo <= rd16;
    cnt     <= 0;
    bytesel <= 0;
    if( half || skip_hi ) begin
        st <= IDLE;
        if( !fwr || tgt==T_SYS ) fok <= 1;
    end else begin
        half <= 1;
        st   <= tgt==T_WRAM || tgt==T_COM ? SETUP : WAIT;
    end
end
endtask

always @(posedge clk) begin
    if( rst ) begin
        st       <= IDLE;
        fok      <= 0;
        half     <= 0;
        bytesel  <= 0;
        cnt      <= 0;
        f_lo     <= 0;
        f_hi     <= 0;
        fa       <= 0;
        fd       <= 0;
        fdsn     <= 4'hf;
        fwr      <= 0;
        bank_sel <= 1;          // ROM at 0 after reset
        wram_cs  <= 0;
        wram_we  <= 0;
        wram_addr<= 0;
        wram_din <= 0;
        wram_dsn <= 3;
        for( j=0; j<4; j=j+1 ) intram[j] <= 0;
    end else begin
        if( fok && !ccs ) fok <= 0;
        case( st )
        IDLE: if( ccs && !fok && !is_rom32 && !is_w32 ) begin
            fa      <= ca;
            fd      <= cdout;
            fdsn    <= cdsn;
            fwr     <= cwr;
            half    <= cwr && &cdsn[1:0];   // skip a masked low half
            bytesel <= 0;
            cnt     <= 0;
            st      <= WAIT;
            if( post ) fok <= 1;
            if( is_wram || is_cm ) begin
                wram_cs   <= 1;
                wram_we   <= cwr;
                wram_addr <= is_cm ? {2'b11, 5'd0, a[13:2], cwr && &cdsn[1:0]} :
                                     {1'b0,  a[19:2],       cwr && &cdsn[1:0]};
                wram_din  <= cwr && &cdsn[1:0] ? cdout[31:16] : cdout[15:0];
                wram_dsn  <= cwr && &cdsn[1:0] ? cdsn[3:2] : cdsn[1:0];
            end
        end
        SETUP: begin    // one clock with wram_cs low between halves
            wram_cs   <= 1;
            wram_we   <= fwr;
            wram_addr <= tgt==T_COM ? {2'b11, 5'd0, la[13:2], half} :
                                      {1'b0,  la[19:2],       half};
            wram_din  <= h_wdat;
            wram_dsn  <= h_dsn;
            st        <= WAIT;
        end
        WAIT: begin
            cnt <= cnt + 2'd1;
            case( tgt )
            T_WRAM, T_COM: if( wram_ok ) begin
                wram_cs <= 0;
                wram_we <= 0;
                hdone;
            end
            T_PAL, T_MISC: begin // one byte per pass
                if( cnt==2'd3 ) begin
                    if( bytesel ) begin
                        if( half ) f_hi[15:8] <= bdat;
                        else       f_lo[15:8] <= bdat;
                        hdone;
                    end else begin
                        if( half ) f_hi[7:0] <= bdat;
                        else       f_lo[7:0] <= bdat;
                        bytesel <= 1;
                        cnt     <= 0;
                    end
                end
            end
            T_SYS: begin // side effects, single cycle
                if( fwr && !half && la[6:2]==5'h02 && !h_dsn[0] ) bank_sel <= h_wdat[0];
                hdone;
            end
            T_INT: begin
                if( fwr ) begin
                    if( half ) begin
                        if( !h_dsn[0] ) intram[la[3:2]][23:16] <= h_wdat[ 7:0];
                        if( !h_dsn[1] ) intram[la[3:2]][31:24] <= h_wdat[15:8];
                    end else begin
                        if( !h_dsn[0] ) intram[la[3:2]][ 7: 0] <= h_wdat[ 7:0];
                        if( !h_dsn[1] ) intram[la[3:2]][15: 8] <= h_wdat[15:8];
                    end
                end
                hdone;
            end
            default: if( cnt==2'd1 ) hdone; // BRAM / MMR / stubs
            endcase
        end
        default: st <= IDLE;
        endcase
    end
end

always @* cdin = is_rom32 ? main_data : is_w32 ? wram32_data : {f_hi, f_lo};

always @(posedge clk) begin
    if( rst ) begin
        sh_v <= 0;
        sh_d <= 0;
        for( si=0; si<SHW; si=si+1 ) sh_a[si] <= 0;
    end else begin
        if( wram32_cs && wram32_ok && !sh_hit ) begin  // slot fetched a new word
            for( si=SHW-1; si>0; si=si-1 ) begin
                sh_a[si] <= sh_a[si-1];
                sh_v[si] <= sh_v[si-1];
                sh_d[si] <= sh_d[si-1];
            end
            sh_a[0] <= a[20:2];
            sh_v[0] <= 1;
            sh_d[0] <= 0;
        end
        if( st==IDLE && ccs && !fok && is_wram && cwr )
            for( si=0; si<SHW; si=si+1 ) if( sh_v[si] && sh_a[si]==a[20:2] ) sh_d[si] <= 1;
    end
end

// interrupt generation: level FFs cleared by sysreg writes at 0x40/44/48
wire irq_ack = st==WAIT && tgt==T_SYS && fwr && !half && la[6:4]==3'b100;
reg  hs_l, lvbl_l, rst_irqn_l;
reg  [2:0] vbl_line;

always @(posedge clk) begin
    if( rst ) begin
        irq0_ff <= 0; irq1_ff <= 0; irq2_ff <= 0;
        hs_l <= 0; lvbl_l <= 1; rst_irqn_l <= 1;
        vbl_line <= 7;
    end else begin
        hs_l       <= hs;
        lvbl_l     <= lvbl;
        rst_irqn_l <= raster_irqn;
        if( lvbl_l && !lvbl ) vbl_line <= 0;                // vblank starts
        if( hs && !hs_l && vbl_line!=7 ) begin
            vbl_line <= vbl_line + 3'd1;
            if( vbl_line==3'd0 ) irq2_ff <= 1;              // MAME: line max_y+1
            if( vbl_line==3'd2 ) begin irq0_ff <= 1; vbl_line <= 7; end // max_y+3
        end
        if( rst_irqn_l && !raster_irqn ) irq1_ff <= 1;
        if( irq_ack ) case( la[3:2] )                        // sysreg 10-13
            2'd0: irq0_ff <= 0;
            2'd1: irq1_ff <= 0;
            2'd2: irq2_ff <= 0;
            default:;   // IRQ3 unused
        endcase
    end
end

// 8kB at the 48 MHz base; the real KA has 512B but its zero-wait DRAM
// cannot be matched by the SDRAM
`ifndef SYSFL_ICACHE_BLK
`define SYSFL_ICACHE_BLK 16
`endif
jt960 #(.ICACHE_BLK(`SYSFL_ICACHE_BLK)) u_cpu(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cpu_cen   ),
    .addr   ( ca        ),
    .din    ( cdin      ),
    .dout   ( cdout     ),
    .dsn    ( cdsn      ),
    .bus_cs ( ccs       ),
    .bus_wr ( cwr       ),
    .fetch  ( cfetch    ),
    .bus_ok ( cok       ),
    .irq_n  ( ~{1'b0, irq2_ff, irq1_ff, irq0_ff} ),
    .halted ( halted    )
);

`ifdef SIMULATION
// boot milestones, one-shot (see cores/sysfl/ver/speedrcr boot notes)
localparam MSN=13;
reg  [MSN-1:0] mseen;
reg  [31:0] mile[0:MSN-1];
reg         rstseen=0;
integer k;
initial begin
    mile[ 0]=32'h790;   mile[ 1]=32'h800;   mile[ 2]=32'h850;
    mile[ 3]=32'hd00;   mile[ 4]=32'hf4c;   mile[ 5]=32'hf5c;
    mile[ 6]=32'hf8c;   mile[ 7]=32'h10c8;  mile[ 8]=32'h1100;
    mile[ 9]=32'h1130;  mile[10]=32'h1160;  mile[11]=32'h13b0;
    mile[12]=32'h100004e0;
end
always @(posedge clk) begin
    if( rst ) begin
        mseen   <= 0;
        rstseen <= 1;
    end else if( rstseen ) begin
        if( cpu_cen && ccs && cok && !cwr ) begin
            for( k=0; k<MSN; k=k+1 )
                if( a==mile[k] && !mseen[k] ) begin
                    mseen[k] <= 1;
                    $display("jt960 milestone %08x at %t", a, $time);
                end
        end
        if( st==WAIT && tgt==T_SYS && fwr && !half
            && la[6:2]!=5'h15 && la[6:2]!=5'h14 ) // skip watchdog kicks
            $display("SYSREG wr [%02x] = %08x at %t", {la[6:2],2'd0}, fd, $time);
        if( halted ) begin
            $display("ERROR: jt960 HALTED, PIP=%08x IR=%08x at %t",
                u_cpu.PIP, u_cpu.IR, $time);
            $finish;
        end
    end
end
reg [20:0] prog_cnt=0;
reg [31:0] lastacc=0;
`endif

endmodule

// ---------------------------------------------------------------------------
// C75 sound/IO island: M37702 + internal BIOS + C352
// MCU map (namcofl.cpp namcoc75_am): 002000-002fff C352, 004000-00bfff shared
// RAM, 00c000-00ffff internal ROM, 200000-27ffff external data ROM
// IRQ0/IRQ2 ticked at 60Hz (vblank), per the MAME timer configuration
// Inputs: an5 wheel, an6 brake (flr only, 0xff on speedrcr), an7 accel
module jtsysfl_c75(
    input             rst,
    input             clk,
    input             xin_cen, c352_cen,
    input             lvbl,
    // cabinet, active low: {SERVICE1, TEST, COIN1, COIN2} on MISC[7:4]
    input      [ 3:0] cab_misc,
    input      [ 7:0] joystick,     // active low, b1 gas, b2 brake (flr), b2-b4 weapons 1-3
    input      [15:0] joyana_l, joyana_r,
    input      [ 2:0] ctrl_type,
    input             start,        // active low, Start / Jump
    input             flr,          // header: Final Lap R cabinet
    // shared RAM, MCU side of the dual port
    output     [14:1] mcu_addr,
    output     [15:0] mcu_din,
    output     [ 1:0] mcu_we,
    input      [15:0] mcu_dout,
    // internal BIOS ROM (BRAM)
    output     [13:1] bios_addr,
    input      [15:0] bios_data,
    // external data ROM (SDRAM)
    output     [18:1] mcurom_addr,
    output            mcurom_cs,
    input      [15:0] mcurom_data,
    input             mcurom_ok,
    // C352 sample ROM (SDRAM bank 2)
    output     [21:0] pcm_addr,
    output            pcm_cs,
    input      [ 7:0] pcm_data,
    input             pcm_ok,
    // audio
    output signed [15:0] snd_l, snd_r,
    output            sample,
    input      [ 7:0] debug_bus
);

wire [23:0] ma;
wire [15:0] mdout;
reg  [15:0] mdin;
wire [ 1:0] mdsn;
wire        mcs, mrnw, mok;
wire        rom_cs;
reg         rom_okr;
wire [ 7:0] p6o;
reg  [ 7:0] p7mux;
wire [ 7:0] accel, wheel, brake;
wire        gear;

// port 7 input mux, selected by p6[7:4] (MAME port7_r)
// MISC: bit4 COIN2, bit5 COIN1, bit6 TEST(service sw), bit7 SERVICE1
always @* begin
    case( p6o[7:4] )
        4'h0: p7mux = 8'hff;                    // IN0
        4'h2: p7mux = {cab_misc, 4'hf};         // MISC
        4'h4: p7mux = {3'b111, flr ? ~gear : 1'b1, 4'hf}; // IN1: bit5 freeze dip off, bit4 shifter
        4'h6: p7mux = { start, joystick[6:5], joystick[7], 4'hf }; // IN2
        default: p7mux = 8'hff;
    endcase
end
`ifdef SYSFL_COINDBG
reg [3:0] misc_l=4'hf;
reg [7:0] p6_l=0;
integer p6cnt=0, fcnt=0;
reg lvbl_d=0;
always @(posedge clk) begin
    misc_l <= cab_misc;
    lvbl_d <= lvbl;
    if( lvbl_d && !lvbl ) fcnt <= fcnt+1;
    p6_l   <= p6o;
    if( misc_l!=cab_misc ) $display("C75 cab_misc %h frame %0d", cab_misc, fcnt);
    if( p6_l!=p6o && p6cnt<200 ) begin p6cnt<=p6cnt+1; $display("C75 p6 %h (misc %h) frame %0d", p6o, cab_misc, fcnt); end
end
`endif
wire [15:0] dout352;
wire [23:0] pcm_a24;
reg  [ 1:0] okcnt;
reg  [26:0] bus_l;
wire        lvbl_pulse;
// back-to-back cycles keep mcs high, so restart the handshake on any change
wire        bsame = bus_l == {ma, mrnw, mdsn};

assign pcm_addr = pcm_a24[21:0];    // 4MB sample ROM

// decode
wire is_352   = mcs && ma[23:12]==12'h002;
wire is_share = mcs && ma[23:16]==8'd0 &&
                (ma[15:14]==2'b01 || ma[15:14]==2'b10);   // 4000-bfff
wire is_mrom  = mcs && ma[23:19]==5'b00100;               // 200000-27ffff

assign mcu_addr    = ma[14:1] - 14'h2000;
assign mcu_din     = mdout;
assign mcu_we      = (is_share && !mrnw && okcnt==2'd1 && bsame) ? ~mdsn : 2'd0;
assign mcurom_addr = ma[18:1];
assign mcurom_cs   = is_mrom;
assign mok         = is_mrom ? mcurom_ok : okcnt==2'd3 && bsame;

always @* begin
    mdin = 16'hffff;    // open bus
    if( is_352   ) mdin = dout352;
    if( is_share ) mdin = mcu_dout;
    if( is_mrom  ) mdin = mcurom_data;
end

always @(posedge clk) begin
    if( rst ) begin
        okcnt   <= 0;
        rom_okr <= 0;
        bus_l   <= 0;
    end else begin
        bus_l <= {ma, mrnw, mdsn};
        if( !mcs || !bsame )    okcnt <= 0;
        else if( okcnt!=2'd3 )  okcnt <= okcnt + 2'd1;
        rom_okr <= rom_cs;    // BRAM data ready next cen
    end
end

// vblank tick, one rising edge per frame for the 60Hz IRQs
assign lvbl_pulse = ~lvbl;

// instructions run at full clk (jt37702 needs ~3 cen per bus byte, so this
// is near real M37702 throughput). Timers and ADC count real XIN on tcen
jt37702 u_mcu(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .cen      ( 1'b1      ),
    .tcen     ( xin_cen   ),
    .addr     ( ma        ),
    .bus_cs   ( mcs       ),
    .rnw      ( mrnw      ),
    .dout     ( mdout     ),
    .din      ( mdin      ),
    .dsn      ( mdsn      ),
    .bus_ok   ( mok       ),
    .rom_cs   ( rom_cs    ),
    .rom_addr ( bios_addr ),
    .rom_data ( bios_data ),
    .rom_ok   ( rom_okr   ),
    .p4_din   ( 8'hff     ),
    .p5_din   ( 8'hff     ),
    .p6_din   ( p6o       ),  // MAME port6_r returns the last written value
    .p7_din   ( p7mux     ),  // input mux by p6[7:4]: IN0/MISC/IN1/IN2
    .p8_din   ( 8'hff     ),
    .p4_dout  (           ),
    .p5_dout  (           ),
    .p6_dout  ( p6o       ),
    .p7_dout  (           ),
    .p8_dout  (           ),
    .p4_diro  (           ),
    .p5_diro  (           ),
    .p6_diro  (           ),
    .p7_diro  (           ),
    .p8_diro  (           ),
    // an0-4 = 0xff constants, an5 wheel, an6 brake (flr) or 0xff, an7 accel
    .an       ( {accel, flr ? brake : 8'hff, wheel, 8'hff, 8'hff, 8'hff, 8'hff, 8'hff} ),
    .irq0     ( lvbl_pulse ),  // rises at vblank start
    .irq1     ( 1'b0      ),
    .irq2     ( lvbl_pulse ), // same phase as INT0, like the MAME 60Hz timers
    .tain     ( 5'd0      ),  // TA2/TA3 event pins: unknown board source, MAME leaves them idle
    .stp      (           )
);


jtsysfl_ctrl u_ctrl(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .lvbl     ( lvbl      ),
    .joystick ( joystick  ),
    .joyana_l ( joyana_l  ),
    .joyana_r ( joyana_r  ),
    .ctrl_type( ctrl_type ),
    .accel    ( accel     ),
    .brake    ( brake     ),
    .wheel    ( wheel     ),
    .gear     ( gear      )
);

jt352 u_pcm(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .cen      ( c352_cen  ),
    .cs       ( is_352 && (mrnw || (okcnt==2'd1 && bsame)) ),
    .addr     ( ma[15:1]  ),
    .rnw      ( mrnw      ),
    .dsn      ( mdsn      ),
    .din      ( mdout     ),
    .dout     ( dout352   ),
    .rom_addr ( pcm_a24   ),
    .rom_data ( pcm_data  ),
    .rom_cs   ( pcm_cs    ),
    .rom_ok   ( pcm_ok    ),
    .snd_l    ( snd_l     ),
    .snd_r    ( snd_r     ),
    .sample   ( sample    ),
    .debug_bus( debug_bus ),
    .st_dout  (           )
);

endmodule

// ---------------------------------------------------------------------------
// TEMPORARY C75 STUB - kept for A/B debugging, enable with -d C75_STUB
// Mimics the C75 BIOS shareram behavior observed in MAME (speedrcr):
// - heartbeat byte 0x6000: 0x00 written at vblank start, 0x80 at vblank end
//   (the game busy-waits on bit 7 toggling at 0x10c8 and polls it per frame)
// - neutral input blocks at 0x6007-0x6017 and 0x6086-0x60c5
// - C75 version/config words at 0x6036-0x6051
// Sound commands written by the i960 (0x0000-0x01xx area) are ignored
module jtsysfl_c75stub(
    input             rst,
    input             clk,
    input             lvbl,
    output reg [14:1] mcu_addr,
    output reg [15:0] mcu_din,
    output reg [ 1:0] mcu_we
);

reg        lvbl_l, run, hb2;
reg [ 5:0] idx;
reg [31:0] tbl;     // {we[1:0], byte addr[14:1], data[15:0]}

function [31:0] went( input [1:0] we, input [15:0] ba, input [15:0] d );
    went = {we, ba[14:1], d};
endfunction

always @* begin
    case( idx )
    // input mirror block 0x6006-0x6017
    6'd00: tbl = went(2'b11, 16'h6006, 16'h8000);
    6'd01: tbl = went(2'b11, 16'h6008, 16'h0000);
    6'd02: tbl = went(2'b11, 16'h600a, 16'h00ff);
    6'd03: tbl = went(2'b11, 16'h600c, 16'h00ff);
    6'd04: tbl = went(2'b11, 16'h600e, 16'h00ff);
    6'd05: tbl = went(2'b11, 16'h6010, 16'h00ff);
    6'd06: tbl = went(2'b11, 16'h6012, 16'h00ff);
    6'd07: tbl = went(2'b11, 16'h6014, 16'h0080);
    6'd08: tbl = went(2'b11, 16'h6016, 16'h00ff);
    // version/config block 0x6036-0x6051
    6'd09: tbl = went(2'b11, 16'h6036, 16'h0534);
    6'd10: tbl = went(2'b11, 16'h6038, 16'hb000);
    6'd11: tbl = went(2'b11, 16'h603a, 16'hb080);
    6'd12: tbl = went(2'b11, 16'h603c, 16'hb000);
    6'd13: tbl = went(2'b11, 16'h603e, 16'hb080);
    6'd14: tbl = went(2'b11, 16'h6040, 16'hb100);
    6'd15: tbl = went(2'b11, 16'h6042, 16'hb080);
    6'd16: tbl = went(2'b11, 16'h6044, 16'h0501);
    6'd17: tbl = went(2'b11, 16'h6046, 16'hb200);
    6'd18: tbl = went(2'b11, 16'h6048, 16'hb900);
    6'd19: tbl = went(2'b11, 16'h604a, 16'hb200);
    6'd20: tbl = went(2'b11, 16'h604c, 16'hb900);
    6'd21: tbl = went(2'b11, 16'h604e, 16'hc000);
    6'd22: tbl = went(2'b11, 16'h6050, 16'hb900);
    // input block 0x6086-0x60c5
    6'd23: tbl = went(2'b11, 16'h6086, 16'h8000);
    6'd24: tbl = went(2'b11, 16'h6088, 16'h0000);
    6'd25: tbl = went(2'b11, 16'h608a, 16'h00ff);
    6'd26: tbl = went(2'b11, 16'h608c, 16'h00ff);
    6'd27: tbl = went(2'b11, 16'h608e, 16'h00ff);
    6'd28: tbl = went(2'b11, 16'h6090, 16'h00ff);
    6'd29: tbl = went(2'b11, 16'h6092, 16'h00ff);
    6'd30: tbl = went(2'b11, 16'h6094, 16'h0080);
    6'd31: tbl = went(2'b11, 16'h6096, 16'h00ff);
    6'd32: tbl = went(2'b11, 16'h609e, 16'hff80);
    6'd33: tbl = went(2'b11, 16'h60a4, 16'h007f);
    6'd34: tbl = went(2'b11, 16'h60b0, 16'hffff);
    6'd35: tbl = went(2'b11, 16'h60b2, 16'hffff);
    6'd36: tbl = went(2'b11, 16'h60b4, 16'hff7f);
    6'd37: tbl = went(2'b11, 16'h60b6, 16'hffff);
    6'd38: tbl = went(2'b11, 16'h60b8, 16'hffff);
    6'd39: tbl = went(2'b11, 16'h60be, 16'h0000);
    6'd40: tbl = went(2'b11, 16'h60c4, 16'hffff);
    // heartbeat low phase, byte 0x6000 only
    6'd41: tbl = went(2'b01, 16'h6000, 16'h0000);
    default: tbl = 32'd0;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        lvbl_l   <= 1;
        run      <= 0;
        idx      <= 0;
        mcu_we   <= 0;
        mcu_addr <= 0;
        mcu_din  <= 0;
    end else begin
        lvbl_l <= lvbl;
        mcu_we <= 0;
        if( lvbl_l && !lvbl ) begin     // vblank start: table + heartbeat low
            run <= 1;
            idx <= 0;
        end
        if( !lvbl_l && lvbl ) begin     // vblank end: heartbeats high
            mcu_addr <= 14'h3000;       // byte 0x6000
            mcu_din  <= 16'h0080;
            mcu_we   <= 2'b01;
            hb2      <= 1;
        end else if( hb2 ) begin
            mcu_addr <= 14'h3003;       // byte 0x6006, second heartbeat
            mcu_din  <= 16'h0080;
            mcu_we   <= 2'b01;
            hb2      <= 0;
        end
        if( run ) begin
            {mcu_we, mcu_addr, mcu_din} <= tbl;
            idx <= idx + 6'd1;
            if( idx==6'd42 ) run <= 0;
        end
    end
end



endmodule
