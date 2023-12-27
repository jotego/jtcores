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
    Date: 2-2-2023 */

// Clocks are derived from H counter on the original PCB
// Yet, that doesn't seem to be important and it only
// matters the frequency of the signals:
// E,Q: 3 MHz
// Q is 1/4th of wave advanced

module jtcastle_main(
    input               rst,
    input               clk,        // 48 MHz
    input               cen24,
    input               cen12,
    output              cpu_cen,
    // communication with sound CPU
    output reg          snd_irq,
    output reg  [ 7:0]  snd_latch,
    // ROM
    output reg  [17:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,
    // RAM
    output      [12:0]  ram_addr,
    output              ram_we,
    input       [ 7:0]  ram_dout,
    // cabinet I/O
    input       [ 1:0]  cab_1p,
    input       [ 1:0]  coin,
    input       [ 6:0]  joystick1,
    input       [ 6:0]  joystick2,
    input               service,
    // GFX
    output      [15:0]  cpu_addr,
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,
    input               gfx_firqn,
    input               gfx_irqn,
    input               gfx_nmin,
    inout               gfx1_cs,
    inout               gfx2_cs,
    inout               pal_cs,

    output reg [1:0]    video_bank,
    output reg          prio,

    input      [7:0]    gfx1_dout,
    input      [7:0]    gfx2_dout,
    input      [7:0]    pal_dout,
    // DIP switches
    input               dip_pause,
    input      [7:0]    dipsw_a,
    input      [7:0]    dipsw_b,
    input      [3:0]    dipsw_c,
    output              buserror
);

localparam RAM_AW = 13;

wire [ 7:0] Aupper;
reg  [ 7:0] cpu_din;
wire [15:0] A;
wire        irq_n, nmi_n, irq_ack;
reg         ram_cs, work;
wire        cpu_we, dtack;
reg         pal_cs_r, gfx1_cs_r, gfx2_cs_r;

assign cpu_addr     = A;
assign cpu_rnw      = ~cpu_we;
assign dtack        = ~rom_cs | rom_ok;
assign ram_we       = ram_cs & cpu_we;
assign ram_addr = { A[12], A[12] ? A[11] : work, A[10:0] };

reg        io_cs;
reg  [3:0] bank; // 5 bits in schematics, but MSB is unused, so pruning it here
reg  [7:0] port_in;
wire [7:0] div_dout;

`ifdef SIMULATION
wire banked_cs = A[15:12]>=6 && A[15:12]<8;
`endif

// Decoder 052127 takes as inputs A[15:9]
// The schematics available are for a board version
// with small ROM chips, whereas all available dumps
// use a 32kB+128kB combination
always @(*) begin
    io_cs    = A[15:8]==4;
    pal_cs_r   = A[15:8]==6;
    ram_cs   = A[15:8]>=8'h08 && A[15:8]<8'h20;
    rom_cs   = A[15:12]>=6 && !cpu_we;
    gfx1_cs_r  = A[15:8]==0 || A[15:13]==3'd2>>1;
    gfx2_cs_r  = A[15:8]==2 || A[15:13]==3'd4>>1;
    rom_addr = { A[15], A[15] ? {2'd0,A[14:13]} : bank, A[12:0] };
end

assign pal_cs = pal_cs_r;
assign gfx1_cs = gfx1_cs_r;
assign gfx2_cs = gfx2_cs_r;

always @* begin
    cpu_din = rom_cs  ? rom_data  :
              ram_cs  ? ram_dout  :
              io_cs   ? port_in   :
              pal_cs  ? pal_dout  :
              gfx1_cs ? gfx1_dout :
              gfx2_cs ? gfx2_dout : 8'hff;
end

// reg ram_wel;

// always @(posedge clk) begin
//     ram_wel <= ram_we;
//     if( ram_we && !ram_wel ) begin
//         $display("%02X -> %04X",cpu_dout,cpu_addr );
//     end
// end

// wire gfx2_we = A[15:12]==4 && cpu_we;
// reg gfx2_wel;

// always @(posedge clk) begin
//     gfx2_wel <= gfx2_we;
//     if( gfx2_we && !gfx2_wel ) begin
//         $display("%02X -> %04X",cpu_dout,cpu_addr );
//     end
// end

// localparam [15:0] TSTADDR=16'h14b2;
// wire bug_wr = cpu_addr==TSTADDR && cpu_we;

// always @(posedge clk) begin
//     // if( cpu_addr=='h1006 && cpu_we ) $display("Written %X to %X",cpu_dout,cpu_addr);
//     if( cpu_addr==TSTADDR && cpu_we ) $display("Written %X to %X",cpu_dout,cpu_addr);
// end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank       <= 0;
        snd_irq    <= 0;
        snd_latch  <= 0;
        port_in    <= 0;
        prio       <= 0;
        video_bank <= 0;
    end else begin
        if(cpu_cen) snd_irq <= 0;
        if( io_cs ) begin
            case( A[4:2] )
                0: if( cpu_we ) begin
                    work <= cpu_dout[5];
                    bank <= cpu_dout[3:0]; // coin lock and a bit for a RAM bank seem to be here too
                end
                1: if( cpu_we ) snd_latch <= cpu_dout;
                2: if( cpu_we ) snd_irq   <= 1;
                // 3: AFR in sch - watchdog
                4: case( A[1:0] ) // COINEN in sch.
                    0: port_in <= {3'b111, cab_1p, service, coin };
                    1: port_in <= {2'b11, joystick1[5:0] };
                    2: port_in <= {2'b11, joystick2[5:0] };
                    3: port_in <= {2'b11, joystick2[6], joystick1[6], dipsw_c[3:0] };
                endcase
                5: port_in <= A[0] ? dipsw_b : dipsw_a;
                6: begin
                    if( cpu_we ) { prio, video_bank } <= cpu_dout[2:0];
                    port_in <= {5'd0, prio, video_bank};
                end
                default: port_in <= 8'hff;
            endcase
        end
    end
end

assign buserror=0;
/* xxverilator tracing_off */
jtkcpu u_cpu(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen2   ( cen24     ),
    .cen_out( cpu_cen   ),

    //.buserror(buserror  ),

    .halt   ( 1'd0      ),
    .dtack  ( dtack     ),
    .nmi_n  ( gfx_nmin               ),
    .irq_n  ( gfx_irqn  | ~dip_pause ),
    .firq_n (gfx_firqn               ),

    // memory bus
    .din        ( cpu_din   ),
    .dout       ( cpu_dout  ),
    .addr       ({Aupper, A}),
    .we         ( cpu_we    ),
    // Debug
    .pcbad      (           ),
    .buserror   (           )
);
/* verilator tracing_on */
endmodule
