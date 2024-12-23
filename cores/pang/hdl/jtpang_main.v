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
    Date: 20-5-2022 */

module jtpang_main(
    input               clk,    // must run at 48MHz for Kabuki to be in time
    input               rst,
    input               cpu_cen,
    input               int_n,
    input        [ 1:0] ctrl_type,

    // BUS sharing
    output       [11:0] cpu_addr,
    output              cpu_rnw,
    output       [ 7:0] cpu_dout,

    // Video configuration
    output reg          flip,
    input               LVBL,
    input               LHBL,
    input         [2:0] hcnt,
    input               dip_pause,
    input               init_n,
    output reg          char_en,
    output reg          obj_en,
    output reg          video_enq,

    // Video
    output  reg         attr_cs,
    output  reg         vram_cs,
    output  reg         vram_msb,
    output  reg         pal_bank,
    output  reg         pal_cs,
    input         [7:0] attr_dout,
    input         [7:0] pal_dout,
    input         [7:0] vram_dout,
    // DMA
    input               busrq_n,
    output              busak_n,
    output reg          dma_go,
    // sound
    output reg          fm_cs,
    output reg          pcm_cs,
    output reg          pcm_bank,
    input         [7:0] pcm_dout,
    // cabinet I/O
    input         [7:0] joystick1,
    input         [7:0] joystick2,
    input         [1:0] cab_1p,
    input               coin,
    input               service,
    input               test,
    input        [ 7:0] mouse_1p,
    input        [ 7:0] mouse_2p,
    // NVRAM dump/restoration
    input        [12:0] prog_addr,
    input        [ 7:0] prog_data,
    output       [ 7:0] prog_din,
    input               prog_we,
    input               prog_ram,
    // Kabuki
    input               kabuki_we,
    input               kabuki_en,
    input       [7:0]   debug_bus,
    // ROM access
    output reg   [19:0] rom_addr,
    output reg          rom_cs,
    input        [ 7:0] rom_data,
    input               rom_ok
);

localparam [1:0] BLOCK=2'd1, CWORLD=2'd2, BLOCKJOY=2'd3;

wire [ 7:0] dec_dout, sys_dout, ram_dout, nvram_dout;
wire [15:0] A;
reg  [ 3:0] bank;
reg  [ 7:0] cpu_din, cab_dout;
reg         dial_sel;

//wire        nvram_we,
reg         eeprom_we;
wire        m1_n, rd_n, wr_n, mreq_n, rfsh_n,
            iorq_n, LHVBLK;
reg         ram_cs, cab_cs, misc_cs, sys_cs, input_cs,
            vbank_cs, bank_cs, LHVBLK_l, video_enb,
            scs, sclk, sdi; // EEPROM control signals
wire        sdo_raw;
reg         sdo, sclk_l;

// NVRAM & EEPROM can be dumped to the SD card
//assign nvram_we  = prog_ram & prog_we & !prog_addr[12];
//assign eeprom_we = prog_ram & prog_we; // & prog_addr[12];
// assign prog_din  =  // !prog_addr[12] ? nvram_dout :
//                     !prog_addr[ 0] ? eeprom_dout[7:0] : eeprom_dout[15:8];

assign sys_dout  = { sdo, 3'b111, video_enq, 1'b1, test, LVBL };
assign cpu_addr = A[11:0];
assign cpu_rnw  = wr_n;

always @(posedge clk) begin
    sclk_l <= sclk;
    if( !sclk && sclk_l ) sdo <= sdo_raw;
end

always @* begin
    rom_addr = { 6'd0, A[13:0] };
    rom_cs = !mreq_n && rfsh_n && A[15:14]!=2'b11;
    if( rom_cs ) begin
        if( A[15] )
            rom_addr[19:14] = 6'd2 + { 2'd0, bank };
        else
            rom_addr[14] = A[14];
    end
    pal_cs   = !mreq_n && rfsh_n && A[15:12]==4'hc && !A[11];
    attr_cs  = !mreq_n && rfsh_n && A[15:12]==4'hc &&  A[11];
    vram_cs  = !mreq_n && rfsh_n && A[15:12]==4'hd;
    ram_cs   = !mreq_n && rfsh_n && A[15:12]>=4'he;
    misc_cs  = !iorq_n && A[4:0]==0 && !wr_n;
    input_cs = !iorq_n && A[4:0]==1 && !wr_n;
    bank_cs  = !iorq_n && A[4:0]==2 && !wr_n;
    cab_cs   = !iorq_n && A[4:0]<3  && !rd_n;
    dma_go   = !iorq_n && A[4:0]==6;
    vbank_cs = !iorq_n && A[4:0]==7 && !wr_n;
    fm_cs    = !iorq_n && (A[4:0]==3 || A[4:0]==4) && !wr_n;
    pcm_cs   = !iorq_n && A[4:0]==5 && !wr_n;
    sys_cs   = !iorq_n && A[4:0]==5 && !rd_n;
end

assign LHVBLK = LHBL | LVBL;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank      <= 0;
        flip      <= 0;
        char_en   <= 1;
        obj_en    <= 1;
        video_enb <= 0;
        video_enq <= 0;
        vram_msb  <= 0;
        scs       <= 0;
        sclk      <= 0;
        sdi       <= 0;
        LHVBLK_l  <= 0;
        dial_sel  <= 0;
    end else begin
        LHVBLK_l <= LHVBLK;
        if( LHVBLK && !LHVBLK_l ) video_enq <= ~video_enb;
        if( bank_cs ) bank     <= cpu_dout[3:0];
        if( vbank_cs) vram_msb <= cpu_dout[0];
        if( input_cs) dial_sel <= ~cpu_dout[7];
        if( misc_cs ) begin
            // chip 11D takes bits 0,1,2,5
            // chip 12D takes bits 3,4,6,7
            // bit 0 = coin lock
            // bit 1 = coin counter
            // bit 6 is CHAR enable, but it goes
            // through a jumper. Pang! does not connect it
            flip      <= cpu_dout[2];
            video_enb <= cpu_dout[3]; // PALENB
            pcm_bank  <= cpu_dout[4];
            pal_bank  <= cpu_dout[5];
            char_en   <= cpu_dout[6]; // can act as CHAR bank selection too
            obj_en    <= cpu_dout[7];
        end
        if( !iorq_n && !wr_n ) begin
            case( A[4:0] )
                5'h08: scs  <= cpu_dout[7];
                5'h10: sclk <= cpu_dout[7];
                5'h18: sdi  <= cpu_dout[7];
                default:;
            endcase
        end
    end
end

function [3:0] reverse( input [3:0] a );
    reverse = { a[0], a[1], a[2], a[3] };
endfunction

always @(posedge clk) begin
    // init_n low means that the game had no NVRAM contents
    // and needs to run the initialization procedure. This
    // is needed for Super Pang. If the MRA could have a
    // default value for the NVRAM, this wouldn't be needed
    cab_dout <= 8'hff;
    case( A[1:0] )
        0:
            case( ctrl_type )
                CWORLD:
                    cab_dout <= { coin, service, 5'h1f, service };
                default:
                    cab_dout <= { coin, service, 2'b11,
                    cab_1p[0] & init_n, 1'b1, cab_1p[1], 1'b1 };
            endcase
        1: begin
            case( ctrl_type )
                CWORLD: cab_dout <=
                    { reverse(joystick1[7:4]& joystick1[3:0]), 1'b1, cab_1p[0], 2'b11 };
                BLOCK: begin
                    if( dial_sel ) begin
                        cab_dout <= { mouse_1p[6:1],2'b11 };
                    end else begin
                        cab_dout[7] <= joystick1[4];
                        cab_dout[3] <= ~mouse_1p[7];
                    end
                end
                BLOCKJOY: begin
                    cab_dout <= { joystick1[4]&joystick1[5], joystick1[2:0], joystick1[4], joystick1[5], 2'b11 };
                end
                default:
                    cab_dout <= { joystick1[3:0], joystick1[4], joystick1[5], 2'b11 };
            endcase
        end
        2: begin
            case( ctrl_type )
                CWORLD: cab_dout <=
                    { reverse(joystick2[7:4]& joystick2[3:0]), 1'b1, cab_1p[1], 2'b11 };
                BLOCK: begin
                    if( dial_sel ) begin
                        cab_dout <= { mouse_2p[6:1],2'b11 };
                    end else begin
                        cab_dout[7] <= joystick2[4];
                        cab_dout[3] <= ~mouse_2p[7];
                    end
                end
                BLOCKJOY: begin
                    cab_dout <= { joystick2[4]&joystick2[5], joystick2[2:0], joystick2[4], joystick2[5], 2'b11 };
                end
                default:
                    cab_dout <= { joystick2[3:0], joystick2[4], joystick2[5], 2'b11 };
            endcase
        end
        default:;
    endcase
    cpu_din <=
        rom_cs  ? dec_dout  :
        ram_cs  ? ram_dout  :
        pal_cs  ? pal_dout  :
        attr_cs ? attr_dout :
        vram_cs ? vram_dout :
        sys_cs  ? sys_dout  :
        cab_cs  ? cab_dout  : 8'hff;
end

jtframe_kabuki u_kabuki(
    .clk        ( clk         ),    // Uses same clock as u_prom_we
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .rd_n       ( rd_n        ),
    .addr       ( A           ),
    .din        ( rom_data    ),
    .en         ( kabuki_en   ),
    // Decode keys
    .prog_data  ( prog_data   ),
    .prog_we    ( kabuki_we   ),
    .dout       ( dec_dout    )
);

wire cen_gated;
reg  cen_haltn, vram_csl;

assign cen_gated = cpu_cen & cen_haltn;

// This should give roughly the same bus contention as
// the original circuit when accessing the video memory
always @(posedge clk, negedge rst) begin
    if( !rst ) begin
        cen_haltn <= 1;
    end else begin
        vram_csl <= vram_cs;
        if( !vram_cs )
            cen_haltn <= 1;
        else if( vram_cs ) begin
            if( hcnt[0] &  ~vram_csl ) begin
                cen_haltn <= 1;
            end else if( hcnt[2] ) begin
                cen_haltn <= 1;
            end
        end
    end
end

`ifndef NOMAIN
jtframe_sysz80_nvram #(
    .RAM_AW     ( 13        ),
    .CLR_INT    ( 1         ),
    .M1_WAIT    ( 2         )
) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_gated ),
    .cpu_cen    (           ),
    .int_n      ( int_n | ~dip_pause ),
    .nmi_n      ( 1'b1      ),
    .busrq_n    ( busrq_n   ),
    .m1_n       ( m1_n      ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     ( rfsh_n    ),
    .halt_n     (           ),
    .busak_n    ( busak_n   ),
    .A          ( A         ),
    .cpu_din    ( cpu_din   ),
    .cpu_dout   ( cpu_dout  ),
    .ram_dout   ( ram_dout  ),
    // NVRAM dump/restoration
    .prog_addr  ( prog_addr ),
    .prog_data  ( prog_data ),
    .prog_din   ( nvram_dout),
    .prog_we    ( 1'b0      ),
    // ROM access
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
);
`else
    assign A        = 0;
    assign busak_n  = 1;
    assign mreq_n   = 1;
    assign iorq_n   = 1;
    assign wr_n     = 1;
    assign rd_n     = 1;
    assign m1_n     = 1;
    assign rfsh_n   = 1;
    assign cpu_dout = 0;
    assign prog_din = 0;
    assign ram_dout = 0;
`endif

// 128 bytes
jt9346_16b8b #(.DW(16),.AW(6)) u_eeprom(
    .rst        ( rst       ),  // system reset
    .clk        ( clk       ),  // system clock
    // chip interface
    .sclk       ( sclk      ),  // serial clock
    .sdi        ( sdi       ),  // serial data in
    .sdo        ( sdo_raw   ),  // serial data out and ready/not busy signal
    .scs        ( scs       ),  // chip select, active high. Goes low in between instructions
    // Dump access
    .dump_clk   ( clk       ),  // same as prom_we module
    .dump_addr  ( prog_addr[7:0] ),
    .dump_we    ( prog_we && prog_ram ),
    .dump_din   ( prog_data  ),
    .dump_dout  ( prog_din   ),
    .dump_flag  (            ),
    .dump_clr   ( 1'b0       )
);

endmodule