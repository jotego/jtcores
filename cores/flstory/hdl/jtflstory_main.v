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
    Date: 17-11-2024 */

module jtflstory_main(
    input            rst,
    input            clk,
    input            cen,
    input            lvbl,       // video interrupt

    input            mirror, gfxcfg, cabcfg, dec_en, iocfg, osdflip,
    input     [ 1:0] bankcfg,

    output    [ 7:0] cpu_dout,
    output    [15:0] bus_addr,
    output    [ 7:0] bus_dout,
    output    [ 7:0] bus_din,

    // sound
    input     [ 7:0] s2m_data,
    output reg       m2s_wr,
    output reg       s2m_rd,

    // video memories
    output    [ 1:0] pal16_we,
    output    [ 9:0] pal16_addr,
    output    [ 1:0] vram_we,
    output           oram_we,
    input     [15:0] pal16_dout,
    input     [15:0] vram16_dout,
    input     [ 7:0] oram8_dout,
    output reg[ 1:0] pal_bank,
    output reg[ 1:0] scr_bank,
    output reg       scr_flen,
    output reg       gvflip,
    output reg       ghflip,

    // sub CPU
    input     [15:0] sub_addr,
    input            sub_cs,
    input            sub_wr_n,
    input            sub_rd_n,
    input     [ 7:0] sub_dout,
    output    [ 7:0] sub_din,
    output           sub_wait,
    output reg       sub_busrq_n, sub_rstn,

    // shared memory with MCU
    input            busrq_n,
    output           busak_n,
    // MCU as master
    input     [15:0] c2b_addr,
    input     [ 7:0] c2b_dout,
    input            c2b_we,
    input            c2b_rd,
    // communication with MCU
    output reg       b2c_wr,
    output reg       b2c_rd,
    input     [ 7:0] mcu2bus,
    input            mcu_ibf,
    input            mcu_obf,
    // shared memory (although no sub CPU in the core)
    output           sha_we,
    input     [ 7:0] sha_dout,
    // Cabinet inputs
    input     [ 1:0] cab_1p,
    input     [ 1:0] coin,
    input     [ 9:0] joystick1,
    input     [ 9:0] joystick2,
    input     [23:0] dipsw,
    input            service,
    input            dip_pause,
    input            tilt,
    // ROM access
    output reg       rom_cs,
    output reg[16:0] rom_addr,
    input     [ 7:0] rom_data,
    input            rom_ok,

    input     [ 7:0] debug_bus
);
`ifndef NOMAIN

localparam [1:0] NOBANKS=2'd0,TWOBANKS=2'd1,FOURBANKS=2'd2;

wire [15:0] cpu_addr;
reg  [ 7:0] cab, din, vram8_dout, rom_dec;
reg  [ 1:0] bank=0, unused_IO, pre_flip=0;
wire [ 3:0] extra1p, extra2p;
wire        mreq_n,  rfsh_n, rd_n, wr_n, bus_we, bus_rd, int_n, bus_cen,
            bus_cem, main_wait, sub_sel, m_reqref;
reg         rst_n,
            pal_hi,  pal_lo,
            vcfg_cs, rumba_cfg, flstory_cfg,  bank_cs, ctl_cs, CDEF_cs,
            ram_cs,  vram_cs,   sha_cs,       oram_cs, cab_cs,
            subhalt_cs,         trcrt_cs,     gunx_cs, guny_cs;

assign sub_sel    = sub_cs & ~sub_wait;
assign bus_addr   = !busak_n ? c2b_addr : sub_sel ? sub_addr : cpu_addr;
assign bus_dout   = !busak_n ? c2b_dout : sub_sel ? sub_dout : cpu_dout;
assign bus_we     = !busak_n ? c2b_we : sub_sel ? ~sub_wr_n : ~wr_n;
assign bus_rd     = !busak_n ? c2b_rd : sub_sel ? ~sub_rd_n : ~rd_n;
assign bus_din    = din;
assign bus_cen    = cen & ~main_wait;
assign sub_din    = din;

assign pal16_we   = {2{bus_we}} & {pal_hi,pal_lo};
assign pal16_addr = {pal_bank,bus_addr[7:0]};
assign sha_we     =    sha_cs & bus_we;
assign vram_we    = {2{vram_cs& bus_we}} & { bus_addr[0], ~bus_addr[0] };
assign oram_we    =   oram_cs & bus_we;
assign int_n      = ~dip_pause | lvbl;
assign m_reqref   = !mreq_n && rfsh_n;

always @* begin
    rom_addr   = {1'b0,bus_addr};
    if(bank_cs) begin
        rom_addr[16]   =1;
        if( bankcfg==TWOBANKS )
            rom_addr[15:14]={1'b0,bank[1]};
        else
            rom_addr[15:14]=bank;
    end
end

always @* begin
    rom_cs      = 0; bank_cs = 0; ctl_cs = 0;
    vram_cs     = 0;
    sha_cs      = 0;
    cab_cs      = 0;
    oram_cs     = 0;
    pal_lo      = 0;
    pal_hi      = 0;
    m2s_wr      = 0;
    s2m_rd      = 0;
    b2c_wr      = 0;
    b2c_rd      = 0;
    flstory_cfg = 0;
    rumba_cfg   = 0;
    subhalt_cs  = 0;
    gunx_cs     = 0;
    guny_cs     = 0;
    trcrt_cs    = 0;
    if( m_reqref ) case(cpu_addr[15:14])
        0,1: rom_cs = 1;
        2: begin
            rom_cs  = 1;
            bank_cs = bankcfg!=NOBANKS;
        end
        default:;
    endcase
    if( bus_addr[15:14]==3 && (m_reqref | sub_cs) ) case(bus_addr[13:12])
        0: vram_cs = 1;
        1: begin
            case(bus_addr[11:10]) // D000
                0: if(bus_we) case(bus_addr[1:0])
                    0: b2c_wr = 1; // CPU writes to MCU latch
                    1: begin
                        subhalt_cs = 1;
                        // watchdog = bus_rd
                    end
                    2: ctl_cs = bus_we; // sub CPU reset and coin lock
                    // 3: sub CPU NMI
                    default:;
                endcase else if(bus_rd) case(bus_addr[1:0])
                    0: b2c_rd = 1; // CPU reads from MCU latch
                    default:;
                endcase
                1: {m2s_wr, s2m_rd} = {bus_we, bus_rd}; // D400
                2: cab_cs = 1;  // D80?
                3: case(bus_addr[9:8]) // DC?? ~ DF??
                    0: begin // DC??
                        oram_cs = 1; // DC??
                        rumba_cfg = bus_we && bus_addr[7:0]==8'he0; // DCE? used by rumba
                    end
                    1: pal_lo  = 1; // DD??
                    2: pal_hi  = 1; // DE?? includes priority bits
                    3: case(bus_addr[1:0]) // DF??
                        0: gunx_cs  = 1;
                        1: guny_cs  = 1;
                        2: trcrt_cs = 1;
                        3: flstory_cfg = bus_we;
                        default:;
                    endcase
                endcase
            endcase
        end
        2,3: sha_cs = 1; // E000~FFFF
        default:;
    endcase
    vcfg_cs = gfxcfg ? rumba_cfg : flstory_cfg;
    CDEF_cs = cpu_addr[15:14]==2'b11 && m_reqref;
end

jtframe_wait_on_shared u_wait(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .mreq   ( CDEF_cs   ),
    .sreq   ( sub_cs    ),
    .mwait  ( main_wait ),
    .swait  ( sub_wait  )
);

localparam [1:0] LOW_FOR_FLSTORY=2'd0, HI_FOR_NYCAPTOR=2'b11;

assign extra1p = cabcfg ? joystick1[9:6] : 4'b1111;
assign extra2p = cabcfg ? joystick2[9:6] : 4'b1111;

always @(posedge clk) begin
    if(rst) begin
        bank        <= 0;
        sub_rstn    <= 0;
        sub_busrq_n <= 0;
    end else begin
        if( subhalt_cs ) sub_busrq_n <= ~cpu_dout[0];
        if( ctl_cs ) begin
            sub_rstn <= cpu_dout[1];
            bank     <= cpu_dout[3:2];
        end
    end
end

always @(posedge clk) begin
    rst_n     <= ~rst;
    unused_IO <= iocfg ? HI_FOR_NYCAPTOR : LOW_FOR_FLSTORY;
    if( vcfg_cs ) begin
        // hvlatch <= bus_dout[7]
        pal_bank <= bus_dout[6:5];
        scr_bank <= bus_dout[4:3];
        scr_flen <= bus_dout[2];
        pre_flip <= bus_dout[1:0]^{2{mirror}};
    end
    { gvflip, ghflip } <= pre_flip^{2{osdflip}};
    case(bus_addr[2:0])
        0: cab <= dipsw[ 7: 0];
        1: cab <= dipsw[15: 8];
        2: cab <= dipsw[23:16];
        3: cab <= {unused_IO,coin,tilt,service,cab_1p};
        4: cab <= {2'b11,joystick1[3:0],joystick1[5:4]};
        5: cab <= {2'b00,extra1p, mcu_obf, ~mcu_ibf}; // bits 5-2 could well be zero
        6: cab <= {2'b11,joystick2[3:0],joystick2[5:4]};
        7: cab <= {2'b11,extra2p,2'b11};
        default: cab <= 8'hff;
    endcase
end

function [7:0] reverse(input [7:0] a); begin
    reverse = {a[0],a[1],a[2],a[3],a[4],a[5],a[6],a[7]};
end endfunction

always @* begin
    vram8_dout = bus_addr[0] ? vram16_dout[15:8] : vram16_dout[7:0];
    rom_dec    = dec_en ? reverse(rom_data) : rom_data;

    din = rom_cs   ? rom_dec    :
          sha_cs   ? sha_dout   :
          cab_cs   ? cab        :
          oram_cs  ? oram8_dout :
          s2m_rd   ? s2m_data   :
          b2c_rd   ? mcu2bus    :
          pal_lo   ? pal16_dout[ 7:0] :
          pal_hi   ? pal16_dout[15:8] :
          vram_cs  ? vram8_dout :
          trcrt_cs ? 8'h1       :
          8'd0;
end

jtframe_sysz80 #(.RAM_AW(11),.CLR_INT(1),.RECOVERY(1)) u_cpu(
    .rst_n      ( rst_n       ),
    .clk        ( clk         ),
    .cen        ( bus_cen     ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ), // int clear logic is internal
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( busrq_n     ),
    .busak_n    ( busak_n     ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     (             ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .A          ( cpu_addr    ),
    .cpu_din    ( din         ),
    .cpu_dout   ( cpu_dout    ),
    .ram_dout   (             ),
    // ROM access
    .ram_cs     ( 1'b0        ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);
`else
integer f,rdcnt;
reg [7:0] sim_data[0:7];
initial begin
    f=$fopen("rest.bin","rb");
    rdcnt=$fread(sim_data,f);
    $display("%d bytes read from rest.bin",rdcnt);
    $fclose(f);
    {scr_flen, gvflip, ghflip, pal_bank, scr_bank} = sim_data[0][6:0];
end

assign cpu_dout   = 0;
assign bus_addr   = 0;
assign bus_dout   = 0;
assign bus_din    = 0;
assign pal16_we   = 0;
assign pal16_addr = 0;
assign vram_we    = 0;
assign oram_we    = 0;
assign busak_n    = 0;
assign sha_we     = 0;
assign rom_addr   = 0;
initial m2s_wr    = 0;
initial s2m_rd    = 0;
initial b2c_wr    = 0;
initial b2c_rd    = 0;
initial rom_cs    = 0;
`endif
endmodule