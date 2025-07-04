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
    Date: 28-6-2025 */

module jtajax_main(
    input               rst,
    input               clk,
    input               cen_ref,
    input               cen12,
    output              cpu_cen,
    output reg          srstn, sub_firq,

    output      [ 7:0]  cpu_dout,

    output reg  [16:0]  rom_addr,
    input       [ 7:0]  rom_data,
    output reg          rom_cs,
    input               rom_ok,
    // RAM
    output              com_we,
    output              ram_we,
    output              cpu_we,
    input       [ 7:0]  ram_dout, com_dout,
    // cabinet I/O
    input       [ 1:0]  cab_1p,
    input       [ 1:0]  coin,
    input       [ 6:0]  joystick1,
    input               service,

    // From video
    input               rst8,
    input               irq_n,

    input      [7:0]    objsys_dout,
    input      [7:0]    pal_dout,

    // To video
    output reg          prio,
    output              pal_we,
    output reg          objsys_cs,
    // To sound
    output reg          snd_irq,
    output reg  [ 7:0]  snd_latch,
    // DIP switches
    input               dip_pause,
    input       [19:0]  dipsw,
    // Debug
    input       [ 7:0]  debug_bus,
    output reg  [ 7:0]  st_dout
);
`ifndef NOMAIN

wire [ 7:0] Aupper;
reg  [ 7:0] cpu_din, cab_dout;
reg  [ 3:0] bank;
wire [15:0] A, pcbad;
wire        buserror;
reg         ram_cs, banked_cs, io_cs, pal_cs, cab_cs, berr_l, bank_cs, com_cs;
wire        dtack;  // to do: add delay for io_cs
reg         rst_cmb, slatch_cs, nonbanked;

assign dtack  = ~rom_cs | rom_ok;
assign com_we = com_cs & cpu_we;
assign ram_we = ram_cs & cpu_we;
assign pal_we = pal_cs & cpu_we;

always @(*) begin
    case( debug_bus[1:0] )
        0: st_dout = { 7'd0, berr_l };
        2: st_dout = pcbad[7:0];
        3: st_dout = pcbad[15:8];
        default: st_dout = 0;
    endcase
end

always @(*) begin
    rom_addr[15:0] = A[15:0]; // also necessary to address gfx chips correctly
    if( banked_cs ) begin
        rom_addr[16]    =~bank[3];
        rom_addr[15]    =~bank[3] & bank[2];
        rom_addr[14:13] = bank[1:0];
    end else begin
        rom_addr[16] = 1'b0;
    end
end

// address decoding done using the same A lines as in the original
always @(*) begin
    sub_firq   = 0;
    snd_irq    = 0;
    slatch_cs  = 0;
    bank_cs    = 0;
    cab_cs     = 0;
    com_cs     = 0;
    ram_cs     = 0;
    objsys_cs  = 0;
    pal_cs     = 0;
    banked_cs  = 0;
    nonbanked  = 0;
    rom_cs     = 0;
    casez(A[15:6])
        10'b0000_0000_00: sub_firq  = !A[5]; // AFE = A[5]
        10'b0000_0000_01: snd_irq   = 1;
        10'b0000_0000_10: slatch_cs = 1;
        10'b0000_0000_11: bank_cs   = 1;
        // 10'b0000_0001_00: // unused on PCB/cabinet
        // 10'b0000_0001_01: // cabinet lights and vibration
        10'b0000_0001_1?: cab_cs    = 1;
        10'b0000_1???_??: objsys_cs = 1; // 0800~0FFF
        10'b0001_????_??: pal_cs    = 1; // 1000~1FFF
        10'b001?_????_??: com_cs    = 1; // 2000~3FFF
        10'b010?_????_??: ram_cs    = 1; // 4000~5FFF
        10'b011?_????_??: banked_cs = 1; // 6000~7FFF
        10'b1???_????_??: nonbanked = 1; // 8000~FFFF
        default:;
    endcase
    rom_cs = banked_cs | nonbanked;
end

always @* begin
    cpu_din = rom_cs    ? rom_data  :
              ram_cs    ? ram_dout  :
              cab_cs    ? cab_dout  :
              pal_cs    ? pal_dout  :
              com_cs    ? com_dout  :
              objsys_cs ? objsys_dout  : 8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        berr_l <= 0;
        bank   <= 0;
        srstn  <= 0;
    end else begin
        if( buserror ) berr_l <= 1;
        case( {A[6],A[1:0]} )
            3'b0_00: cab_dout <= { 3'd0, cab_1p, service, coin};
            3'b0_01: cab_dout <= { 1'b0, joystick1 };
            3'b0_10: cab_dout <= dipsw[ 7:0];
            3'b0_11: cab_dout <= dipsw[15:8];
            default: cab_dout <= {4'hf,dipsw[19:16]};
        endcase
        if( slatch_cs ) snd_latch <= cpu_dout;
        if( bank_cs ) begin
            srstn <=  cpu_dout[4];
            prio  <=  cpu_dout[3];
            bank  <= {cpu_dout[7],cpu_dout[2:0]};
        end
    end
end

/* xverilator tracing_off */
// there is a reset for the first 8 frames, skip it in sims
// always @(posedge clk) rst_cmb <= rst `ifndef SIMULATION | rst8 `endif ;
always @(posedge clk) rst_cmb <= rst | rst8;

jtkcpu u_cpu(
    .rst    ( rst_cmb   ),
    .clk    ( clk       ),
    .cen2   ( cen_ref   ),
    .cen_out( cpu_cen   ),

    .halt   ( berr_l    ),
    .dtack  ( dtack     ),
    .nmi_n  ( 1'b1      ),
    .irq_n  ( irq_n | ~dip_pause ),
    .firq_n ( 1'b1      ),
    .pcbad  ( pcbad     ),
    .buserror( buserror ),

    // memory bus
    .din    ( cpu_din   ),
    .dout   ( cpu_dout  ),
    .addr   ({Aupper, A}),
    .we     ( cpu_we    )
);
`else
    assign cpu_cen  = 0;
    assign cpu_dout = 0;
    assign ram_we   = 0;
    assign cpu_we   = 0;
    assign st_dout  = 0;
    assign pal_we   = 0;
    assign rom_addr = 0;
    assign com_we =0;

    reg [7:0] prio_init[0:0];
    integer f,fcnt=0;
    initial begin
        rom_cs     = 0;
        prio       = 0;
        objsys_cs  = 0;
        snd_irq    = 0;
        snd_latch  = 0;
        srstn =0;
        sub_firq =0;

        f=$fopen("prio.bin","rb");
        if( f!=0 ) begin
            fcnt=$fread(prio_init,f);
            $fclose(f);
            prio = prio_init[0][0];
        end else begin
            prio = 0;
        end
    end
`endif
endmodule