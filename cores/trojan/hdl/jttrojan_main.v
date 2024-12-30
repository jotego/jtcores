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
    Date: 8-9-2024 */

// based on jtcommnd_main
module jttrojan_main(
    input              rst,
    input              clk,
    input              base_cen,
    output             cpu_cen,

    input              nmi_sel,
    // Timing
    output  reg        flip,
    input   [8:0]      V,
    input              LHBL,
    input              LVBL,
    input              H1,
    // MCU
    input        [7:0] main_latch,
    output  reg  [7:0] mcu_latch,
    output  reg        mcu_wr,
    output  reg        mcu_rd,
    // Sound
    output  reg        sres_b, // sound reset
    output             snd_int,
    output  reg  [7:0] snd_latch,
    output  reg  [7:0] snd2_latch, // only used by Trojan
    // Characters
    input        [7:0] char_dout,
    output       [7:0] cpu_dout,
    output  reg        char_cs,
    input              char_busy,
    // scroll
    input   [7:0]      scr_dout,
    output  reg        scr_cs,
    input              scr_busy,
    output reg [ 8:0]  scr_hpos,
    output reg [ 8:0]  scr_vpos,
    // Scroll 2 of Trojan
    output reg [15:0]  scr2_hpos,
    // Palette
    output  reg        blue_cs,
    output  reg        redgreen_cs,
    // cabinet I/O
    input   [5:0]      joystick1,
    input   [5:0]      joystick2,
    input   [1:0]      cab_1p,
    input   [1:0]      coin,
    // BUS sharing
    output  [12:0]     cpu_AB,
    output  [ 7:0]     ram_dout,
    input   [ 8:0]     obj_AB,
    output             RnW,
    output  reg        OKOUT,
    input              bus_req,  // Request bus
    output             bus_ack,  // bus acknowledge
    input              blcnten,  // bus line counter enable
    // ROM access
    output  reg        rom_cs,
    output  reg [16:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,
    // PROM 6L (interrupts)
    input    [7:0]     prog_addr,
    input              prom_6l_we,
    input    [3:0]     prog_din,
    // DIP switches
    input              service,
    input              dip_pause,
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b
);
`ifndef NOMAIN
// bit locations
localparam FLIP = 0;
localparam NMI  = 3;
localparam SRES = 5;

wire [15:0] A;
reg  [ 7:0] cab_dout;
wire        t80_rst_n;
reg         in_cs, ram_cs, misc_cs, scrpos_cs;
reg         snd_latch_cs, snd2_latch_cs;
wire        rd_n, wr_n, mreq_n, rfsh_n, busak_n;

reg  [ 1:0] bank;
reg         nmi_mask;

assign RnW     = wr_n;
assign bus_ack = ~busak_n;
assign snd_int = V[5]; // same as Ghosts'n Goblins

always @(*) begin
    rom_cs        = 0;
    ram_cs        = 0;
    mcu_wr        = 0;
    snd_latch_cs  = 0;
    snd2_latch_cs = 0;
    misc_cs       = 0;
    in_cs         = 0;
    char_cs       = 0;
    scr_cs        = 0;
    scrpos_cs     = 0;
    OKOUT         = 0;
    blue_cs       = 0;
    redgreen_cs   = 0;

    if( rfsh_n && !mreq_n ) casez(A[15:13])
        3'b0??,3'b10?: rom_cs = 1'b1; // 48 kB
        3'b110: ram_cs = 1'b1; // CXXX, DXXX
        3'b111: // EXXX, FXXX
            case(A[12:11])
                2'b00: // E000-E7FF
                    char_cs = 1'b1;
                2'b01: // E800-EFFF
                    scr_cs = 1'b1;
                2'b10: begin // F0
                    redgreen_cs = !A[10];
                    blue_cs     =  A[10];
                end
                2'b11: begin// F8
                    scrpos_cs    = !A[3] && !wr_n; // F800-F807
                    in_cs        =  A[3] && !rd_n; // F808-F80F
                    OKOUT        =  A[3:0]== 8 && !wr_n; // F808
                    mcu_wr       =  A[3:0]== 9 && !wr_n; // F809
                    snd_latch_cs =  A[3:0]==12 && !wr_n; // F80C
                    snd2_latch_cs=  A[3:0]==13 && !wr_n; // F80D
                    misc_cs      =  A[3:0]==14 && !wr_n; // F80E
                end
            endcase
    endcase
end

always @* begin
    mcu_rd = 0;
    case( A[2:0] )
        3'd0: cab_dout = { coin, 4'hf,cab_1p }; // F808
        3'd1: cab_dout = { 2'b11, joystick1  }; // F809
        3'd2: cab_dout = { 2'b11, joystick2  }; // F80A
        3'd3: cab_dout = dipsw_a;               // F80B
        3'd4: cab_dout = dipsw_b;               // F80C
        3'd5: begin                             // F80D
            cab_dout = main_latch;
            mcu_rd   = in_cs;
        end
        default: cab_dout = 8'hff;
    endcase
end

// SCROLL H/V POSITION
always @(posedge clk) begin
    if( !t80_rst_n ) begin
        scr_hpos  <= 0;
        scr_vpos  <= 0;
        scr2_hpos <= 0;
    end else if(base_cen && scrpos_cs) begin
        if( !A[2] ) case(A[1:0])
            2'd0: scr_hpos[7:0] <= cpu_dout;
            2'd1: scr_hpos[8]   <= cpu_dout[0];
            2'd2: scr_vpos[7:0] <= cpu_dout;
            2'd3: scr_vpos[8]   <= cpu_dout[0];
        endcase else case(A[1:0]) // A[2]==1
            0: scr2_hpos[ 7:0] <= cpu_dout;
            1: scr2_hpos[15:8] <= cpu_dout;
            default:;
        endcase
    end
end

// special registers
always @(posedge clk)
    if( rst ) begin
        flip       <= 0;
        sres_b     <= 1;
        bank       <= 0;
        nmi_mask   <= 0;
        mcu_latch  <= 0;
        snd_latch  <= 0;
        snd2_latch <= 0;
    end
    else if(base_cen) begin
        if( misc_cs  && !wr_n ) begin
            flip     <= ~cpu_dout[FLIP];
            sres_b   <= ~cpu_dout[SRES]; // inverted through NPN
            nmi_mask <= cpu_dout[3];
            bank     <= cpu_dout[2:1];
        end
        if( mcu_wr        ) mcu_latch  <= cpu_dout;
        if( snd_latch_cs  ) snd_latch  <= cpu_dout;
        if( snd2_latch_cs ) snd2_latch <= cpu_dout;
    end

jt12_rst u_rst(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .rst_n  ( t80_rst_n )
);

// RAM, 16kB
wire cpu_ram_we = ram_cs && !wr_n;
assign cpu_AB = A[12:0];

wire [12:0] RAM_addr = blcnten ? {4'b1111, obj_AB} : cpu_AB;
wire RAM_we   = blcnten ? 1'b0 : cpu_ram_we;

jtframe_ram #(.AW(13),.CEN_RD(0)) RAM(
    .clk        ( clk       ),
    .cen        ( base_cen  ),
    .addr       ( RAM_addr  ),
    .data       ( cpu_dout  ),
    .we         ( RAM_we    ),
    .q          ( ram_dout  )
);

// Data bus input
reg  [7:0] cpu_din;
wire [3:0] int_ctrl;
wire       iorq_n, m1_n;
wire       irq_ack = !iorq_n && !m1_n;

always @(posedge clk) begin
    cpu_din <= ram_cs  ? ram_dout  :
               char_cs ? char_dout :
               scr_cs  ? scr_dout  :
               rom_cs  ? rom_data  :
               in_cs   ? cab_dout  : 8'hff;
    // Interrupt address
    if( irq_ack && !nmi_sel )
        cpu_din <= 8'hd7;
end

always @(A,bank) begin
    rom_addr[13: 0] = A[13:0];
    rom_addr[16:14] = A[15] ? { 1'b0, bank } : { 2'b10, A[14] };
end

/////////////////////////////////////////////////////////////////
jtframe_z80wait u_wait(
    .rst_n      ( t80_rst_n ),
    .clk        ( clk       ),
    .cen_in     ( base_cen  ),
    .cen_out    ( cpu_cen   ),
    // Recover cycles
    .mreq_n     ( mreq_n & m1_n   ),
    .iorq_n     ( iorq_n    ),
    .busak_n    ( busak_n   ),
    // manage access to shared memory
    .dev_busy   ( { scr_busy, char_busy } ),
    // manage access to ROM data from SDRAM
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .gate       (           )
);

jtframe_prom #(.AW(8),.DW(4)) u_vprom(
    .clk    ( clk          ),
    .cen    ( base_cen      ),
    .data   ( prog_din     ),
    .wr_addr( prog_addr    ),
    .rd_addr( V[7:0]       ),
    .we     ( prom_6l_we   ),
    .q      ( int_ctrl     )
);

reg  irqn, LVBLl;
wire int_n, nmi_n;

assign int_n = nmi_sel ? 1'b1 : irqn;
assign nmi_n = nmi_sel ? irqn : 1'b1;

// interrupt generation
always @(posedge clk) begin
    if( rst ) begin
        irqn  <= 1'b1;
        LVBLl <= 1'b0;
    end else begin
        LVBLl <= LVBL;
        if( !LVBL  &&  LVBLl    ) irqn <= ~nmi_mask  | ~dip_pause;
        if( nmi_sel ? ~nmi_mask : irq_ack ) irqn <= 1'b1;
    end
end

jtframe_z80 u_cpu(
    .rst_n      ( t80_rst_n   ),
    .clk        ( clk         ),
    .cen        ( cpu_cen     ),
    .wait_n     ( 1'b1        ),
    .int_n      ( int_n       ),
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( ~bus_req    ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    ( busak_n     ),
    .A          ( A           ),
    .din        ( cpu_din     ),
    .dout       ( cpu_dout    )
);
`else
    assign bus_ack  = 0;
    assign cpu_AB   = 0;
    assign cpu_cen  = 0;
    assign cpu_dout = 0;
    assign ram_dout = 0;
    assign RnW      = 0;
    initial begin
        blue_cs     = 0;
        char_cs     = 0;
        flip        = 0;
        obj_on      = 0;
        OKOUT       = 0;
        redgreen_cs = 0;
        rom_addr    = 0;
        rom_cs      = 0;
        scr1_on     = 0;
        scr1_pal    = 0;
        scr2_hpos   = 0;
        scr2_on     = 0;
        scr2_pal    = 0;
        scr_cs      = 0;
        scr_hpos    = 0;
        scr_vpos    = 0;
        snd2_latch  = 0;
        snd_int     = 0;
        snd_latch   = 0;
        sres_b      = 0;
    end
`endif
endmodule