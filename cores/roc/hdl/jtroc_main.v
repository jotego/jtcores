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
    Date: 15-8-2022 */

module jtroc_main(
    input               rst,
    input               clk,        // 24 MHz
    input               cpu4_cen,   // 6.14 MHz
    output              cpu_cen,    // Q clock

    output      [10:0]  bus_addr,
    // ROM
    output      [15:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,

    // cabinet I/O
    input       [ 1:0]  cab_1p,
    input       [ 1:0]  coin,
    input       [ 5:0]  joystick1,
    input       [ 5:0]  joystick2,
    input               service,

    // GFX
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,
    output reg          vram_cs,
    output reg          objram_cs,

    // Sound
    output reg  [ 7:0]  snd_latch,
    output reg          snd_on,
    output reg          mute,

    // configuration
    output reg          flip,

    // interrupt triggers
    input               LVBL,

    input      [7:0]    vram_dout,
    input      [7:0]    obj_dout,
    // DIP switches
    input               dip_pause,
    input     [23:0]    dipsw,

    output    [ 7:0]    st_dout
);

reg  [ 7:0] cabinet, cpu_din, vectors_dout;
wire [ 7:0] ram_dout;
wire [15:0] A;
reg  [ 7:0] vectors[0:15];
wire        RnW, irq_n, nmi_n;
wire        irq_trigger;
reg         vector_rd, io_cs, ram_cs,
            vector_cs, dip3_cs, dip1_cs, imux_cs,
            snd_cs, oreg_cs,
            firq_n, firq_en, irq_en, even, LVBLl;
wire        VMA;

assign irq_trigger = ~LVBL & dip_pause;
assign cpu_rnw     = RnW;
assign rom_addr    = A[15:0]-16'h6000;
assign bus_addr    = A[10:0];
assign st_dout     = { 2'd0, bus_error, mute, snd_on, flip, firq_en, irq_en };

reg bus_error;

always @(*) begin
    vector_rd = &A[15:4] & ~&A[3:1];
        // The KONAMI-1 chip seems to have pin #26 serve as
        // an interrupt vector request signal
    io_cs     = VMA && A[15:9]==(RnW ? 7'h18 : 7'h40);
    vector_cs = io_cs && A[8:7] == 3;
    dip3_cs   = io_cs && { RnW, A[8:7] } == 3'b1_10;
    imux_cs   = io_cs && { RnW, A[8:7] } == 3'b1_01;
    dip1_cs   = io_cs && { RnW, A[8:7] } == 3'b1_00;
    snd_cs    = io_cs && { RnW, A[8:7] } == 3'b0_10;
    oreg_cs   = io_cs && { RnW, A[8:7] } == 3'b0_01;
    objram_cs = VMA && A[15:11]==5'b0100_0; // $40../$44..
    vram_cs   = VMA && A[15:11]==5'b0100_1; // $48../$4C..
    ram_cs    = VMA && A[15:12]==4'b0101; // $5...
    rom_cs    = VMA && A[15:12]>=6 && !vector_rd && RnW; // ROM = 6000 - FFFF
    bus_error = VMA && {io_cs,vector_cs,dip3_cs,imux_cs,dip1_cs,snd_cs,oreg_cs,objram_cs,vram_cs,ram_cs,rom_cs,vector_rd}==0;
end

always @(posedge clk) begin
    if( vector_cs && cpu_cen && !RnW ) vectors[A[3:0]] <= cpu_dout;
    vectors_dout <= vectors[ A[3:0] ];
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        LVBLl  <= 0;
        even   <= 0;
        firq_n <= 1;
    end else begin
        // There is an interrupt triggered
        // every two frames. Not clear which one is FIRQ and which one IRQ
        LVBLl <= LVBL;
        if( !LVBL && LVBLl && dip_pause ) begin
            even <= ~even;
            if( ~even ) firq_n <= 0;
        end
        if( !firq_en || !dip_pause ) firq_n <= 1;
    end
end

always @(posedge clk) begin
    case( A[1:0] )
        0: cabinet <= { ~3'd0, cab_1p, service, coin };
        1: cabinet <= { 2'd3, joystick1[5:0] };
        2: cabinet <= { 2'd3, joystick2[5:0] };
        3: cabinet <= dipsw[ 7-:8]; //
    endcase
    cpu_din <= rom_cs     ? rom_data  :
               vram_cs    ? vram_dout :
               objram_cs  ? obj_dout :
               ram_cs     ? ram_dout :
               dip1_cs    ? dipsw[15-:8] : //
               dip3_cs    ? dipsw[23-:8] :
               imux_cs    ? cabinet :
               vector_cs || vector_rd ? vectors_dout :
               8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        flip      <= 0;
        snd_on    <= 0;
        mute      <= 0;
        snd_latch <= 0;
    end else if(cpu_cen && !RnW) begin
        if( snd_cs ) snd_latch <= cpu_dout;
        if( oreg_cs ) begin
            case(A[2:0]) // 74LS259
                0: flip   <= cpu_dout[0];
                1: snd_on <= cpu_dout[0];
                2: mute   <= cpu_dout[0];
                // 3, 4, coin counters
                // 5 unconnected
                6: firq_en <= cpu_dout[0];
                7: irq_en  <= cpu_dout[0];
                default:;
            endcase
        end
    end
end

jtframe_ff u_irq(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( irq_n       ),
    .set      (             ),    // active high
    .clr      ( ~irq_en     ),    // active high
    .sigedge  ( irq_trigger )     // signal whose edge will trigger the FF
);

jtframe_sys6809 #(.RAM_AW(12),.KONAMI(1)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cpu4_cen  ),   // This is normally the input clock to the CPU
    .cpu_cen    ( cpu_cen   ),   // 1/4th of cen -> 3MHz

    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( firq_n    ),
    .nNMI       ( 1'b1      ),
    .irq_ack    (           ),
    // Bus sharing
    .bus_busy   ( 1'b0      ),
    // memory interface
    .A          ( A         ),
    .RnW        ( RnW       ),
    .VMA        ( VMA       ),
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    // Bus multiplexer is external
    .ram_dout   ( ram_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   )
);

endmodule
