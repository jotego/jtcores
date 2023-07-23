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
    Date: 5-5-2023 */

module jtsimson_main(
    input               rst,
    input               clk,
    input               cen_ref,
    output              cpu_cen,

    output      [ 7:0]  cpu_dout,
    output reg          init,

    output reg  [17:0]  rom_addr,
    input       [ 7:0]  rom_data,
    output reg          rom_cs,
    input               rom_ok,
    // RAM
    output              ram_we,
    output              cpu_we,
    input       [ 7:0]  ram_dout,
    // cabinet I/O
    input       [ 3:0]  start_button,
    input       [ 3:0]  coin_input,
    input       [ 6:0]  joystick1,
    input       [ 6:0]  joystick2,
    input       [ 6:0]  joystick3,
    input       [ 6:0]  joystick4,
    input               service,

    // From video
    input               rst8,
    input               irq_n,  // from tile map
    input               firq_n,

    input      [7:0]    tilesys_dout, objsys_dout,
    input      [7:0]    pal_dout,

    // To video
    output reg          rmrd,
    output reg [ 1:0]   prio,
    output              pal_we,
    output reg          tilesys_cs,
    output reg          objsys_cs,
    // To sound
    output reg          snd_irq,
    output reg          snd_reg,
    // DIP switches
    input               dip_test,
    input               dip_pause,
    // Debug
    input       [ 7:0]  debug_bus,
    output reg  [ 7:0]  st_dout
);
`ifndef NOMAIN

wire [ 7:0] Aupper;
reg  [ 7:0] cpu_din, port_in;
reg  [ 3:0] bank;
reg  [ 3:0] eff_bank;
wire [15:0] A, pcbad;
wire        buserror;
reg         ram_cs, banked_cs, io_cs, pal_cs, work, pmc_work,
            ioout, incs , chain, berr_l,
            e19_o16, e19_o12, objaux;
wire        dtack;  // to do: add delay for io_cs
reg         rst_cmb;
wire        norA65, norA43;

assign dtack   = ~rom_cs | rom_ok;
assign ram_we  = ram_cs & cpu_we;
assign pal_we  = pal_cs & cpu_we;
assign norA65  = ~|A[6:5],
       norA43  = ~|A[4:3];

always @(*) begin
    case( debug_bus[1:0] )
        0: st_dout = Aupper;
        1: st_dout = { 7'd0, berr_l };
        2: st_dout = pcbad[7:0];
        3: st_dout = pcbad[15:8];
    endcase
end

// Decoder 053326 takes as inputs A[15:10], BK4, W0C0
// Decoder 053327 after it, takes A[10:7] for generating
// OBJCS, VRAMCS, CRAMCS, IOCS
`ifdef SIMULATION
wire bad_cs =
        { 3'd0, rom_cs     } +
        { 3'd0, pal_cs     } +
        { 3'd0, ram_cs     } +
        { 3'd0, io_cs      } +
        { 3'd0, objsys_cs  } +
        { 3'd0, tilesys_cs } > 1;
wire none_cs = ~|{ rom_cs, pal_cs, ram_cs, io_cs, objsys_cs, tilesys_cs };
wire test_cs = A[15:0]>=16'h2000 && A[15:0]<16'h6000;
wire bad2_cs = test_cs & ~tilesys_cs & ~objsys_cs;
`endif

reg A98;

always @(*) begin
    ioout = 0;
    incs  = 0;
    chain = 0;
    objaux  = 0;
    i6 = A[15:10]==7 && (!init && A[15:10]==6'h1f);
    i7 = (A[15:10]==7 && !w0c0) || (
        init ? A[15:13]==1 || (A[15:13]==0 && !W0C0) || A[15:12]==1 :
               A[15:10]==7 && (W0C1 || W0C0) );

    banked_cs  =  init && A[15:13]==3 && !Aupper[4]; // 6000~7FFF
    prog_cs    = (init && A[14:13]==3 &&  Aupper[4]) || A[15];
    ram_cs     = A[15:13]==2 && init;
    // after second decoder:
    pal_cs     = A[15:12]==0 && W0C0; // COLOCS in sch
    objsys_cs  = A[15:13]==1 && W0C1 && init;
    A98        = &A[9:8];
    objreg_cs  = i6 && i7 && A98 && A[6:4]==3'b010;
    eeprom_cs  = i6 && i7 && A98 && A[6:4]==3'b000;
    pcu_cs     = i6 && i7 && A98 && A[6:4]==3'b011; // 053251
    joystk_cs  = i6 && i7 && A98 && A[6:4]==3'b001;
    io_cs      = i6 && i7 && A98 && A[6:4]==3'b100;
    tilesys_cs = A[15:14]==1 && ( !init || (!io_cs && !pal_cs && !objsys_cs));

    rom_cs     = prog_cs | banked_cs;
    rom_addr[12: 0] = A[12:0];
    rom_addr[16:13] = A[15] ? {2'b11,A[14:13]} : Aupper[3:0];
    rom_addr[17]    = A[15] | Aupper[5];
    rom_addr[18]    = banked_cs;
    if( !rom_cs ) rom_addr[15:0] = A[15:0]; // necessary to address gfx chips correctly
end

always @* begin
    cpu_din = rom_cs     ? rom_data  :
              ram_cs     ? ram_dout  :
              io_cs      ? port_in   :    // io_cs must take precedence over tilesys_cs
              pal_cs     ? pal_dout  :
              tilesys_cs ? tilesys_dout :
              objsys_cs  ? objsys_dout  : 8'hff;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd_irq   <= 0;
        snd_reg   <= 0;
        port_in   <= 0;
        work      <= 0;
        pmc_work  <= 0;
        prio      <= 0;
        rmrd      <= 0;
        init      <= 0; // missing this will result in garbled scroll after reset
        eff_bank  <= 0;
        berr_l    <= 0;
    end else begin
        if( buserror ) berr_l <= 1;
        eff_bank <= cfg==SCONTRA ? bank : Aupper[3:0]; // Only Super Contra uses a latch
        if( cfg==CRIMFGHT ) begin
            init <= Aupper[7];
            rmrd <= Aupper[6];
            work <= Aupper[5];
        end
        if(cpu_cen) snd_irq <= 0;
        if( io_cs ) case( A[3:1] )
            0: { objcha, init, rmrd, mono } <= cpu_dout[5:2]; // bits 1:0 are coin counters
            1: { eep_di, eep_clk, eep_cs, firqen, W0C1, W0C0 } <= { cpu_dout[7], cpu_dout[4:0] };
            2: snd_irq <= 1;
            3: snd_reg <= 1;
            // 4: CRCS ?
            // 5: AFR (watchdog)
            default:;
        endcase

        if( joystk_cs ) case( A[1:0] )
            2'd0: port_in <= { start_button[0], joystick1[6:0] };
            2'd1: port_in <= { start_button[1], joystick2[6:0] };
            2'd2: port_in <= { start_button[2], joystick3[6:0] };
            2'd3: port_in <= { start_button[3], joystick4[6:0] };
        endcase

        if( eeprom_cs ) port_in <= A[0] ? { 2'b11, eeprom_rdy, eeprom_dout, 3'b111, dip_test }
                                        : { {4{service}}, coin_input };
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
// `ifdef SIMULATION
//     .irq_n  ( 1'b1      ),
// `else
    .irq_n  ( irq_n | ~dip_pause ),
// `endif
    .firq_n ( firq_n    ),
    .pcbad  ( pcbad     ),
    .buserror( buserror ),

    // memory bus
    .din    ( cpu_din   ),
    .dout   ( cpu_dout  ),
    .addr   ({Aupper, A}),
    .we     ( cpu_we    )
);
/* verilator tracing_on */
`else
    assign cpu_cen  = 0;
    assign cpu_dout = 0;
    assign ram_we   = 0;
    assign cpu_we   = 0;
    assign st_dout  = 0;
    assign pal_we   = 0;
    assign rom_addr = 0;

    reg [7:0] prio_init[0:0];
    integer f,fcnt=0;
    initial begin
        rom_cs     = 0;
        rmrd       = 0;
        prio       = 0;
        tilesys_cs = 0;
        objsys_cs  = 0;
        snd_irq    = 0;
        snd_latch  = 0;
        init       = 0;

        f=$fopen("prio.bin","rb");
        if( f!=0 ) begin
            fcnt=$fread(prio_init,f);
            $fclose(f);
            prio = prio_init[0][1:0];
        end else begin
            prio = 0;
        end
    end
`endif
endmodule