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

    input               paroda,

    output      [ 7:0]  cpu_dout,
    output reg          init,

    output reg  [18:0]  rom_addr,
    input       [ 7:0]  rom_data,
    output reg          rom_cs,
    input               rom_ok,
    // RAM
    output              ram_we,
    output              cpu_we,
    input       [ 7:0]  ram_dout,
    // cabinet I/O
    input       [ 3:0]  cab_1p,
    input       [ 3:0]  coin,
    input       [ 6:0]  joystick1,
    input       [ 6:0]  joystick2,
    input       [ 6:0]  joystick3,
    input       [ 6:0]  joystick4,
    input               service,

    // From video
    input               rst8,
    input               irq_n,  // from tile map
    input               dma_bsy,

    input      [7:0]    tilesys_dout, objsys_dout,
    input      [7:0]    pal_dout,

    // To video
    output reg          rmrd,
    output              pal_we,
    output reg          pal_bank,
    output reg          pcu_cs,
    output reg          tilesys_cs,
    output reg          objsys_cs,
    output reg          objreg_cs,
    output reg          objcha_n,
    // To sound
    output reg          snd_irq,
    output              snd_wrn,
    output reg          mono,
    input       [ 7:0]  snd2main,
    // EEPROM
    output      [ 6:0]  nv_addr,
    input       [ 7:0]  nv_dout,
    output      [ 7:0]  nv_din,
    output              nv_we,

    // DIP switches
    input               dip_test,
    input               dip_pause,
    input       [23:0]  dipsw,          // used by Parodius
    // Debug
    input       [ 7:0]  debug_bus,
    output reg  [ 7:0]  st_dout
);
`ifndef NOMAIN

wire [ 7:0] Aupper;
reg  [ 7:0] cpu_din, port_in;reg  [ 3:0] bank;
wire [15:0] A, pcbad;
wire        buserror;
reg         ram_cs, banked_cs, io_cs, pal_cs, snd_cs,
            berr_l, prog_cs, eeprom_cs, joystk_cs,
            out_cs, basel_cs,
            i6n, i7n, paro_i6n, paro_i7n,
            misc_cs, paro_aux, io_aux, unpaged;
wire        dtack;  // to do: add delay for io_cs
reg         rst_cmb;
wire        eep_rdy, eep_do, firqn_ff;
reg         eep_di, eep_clk, eep_cs, firqen, WOC1, WOC0,
            bankr;

assign dtack   = ~rom_cs | rom_ok;
assign ram_we  = ram_cs & cpu_we;
assign snd_wrn = ~(snd_cs & cpu_we);
assign pal_we  = pal_cs & cpu_we;

always @(*) begin
    case( debug_bus[1:0] )
        0: st_dout = Aupper;
        1: st_dout = { 7'd0, berr_l };
        2: st_dout = pcbad[7:0];
        3: st_dout = pcbad[15:8];
    endcase
end

// Decoder 053326 takes as inputs A[15:10], BK4, WOC0
// Decoder 053327 after it, takes A[10:7] for generating
// OBJCS, VRAMCS, CRAMCS, IOCS
`ifdef SIMULATION
wire bad_cs =
        { 3'd0, rom_cs     } +
        { 3'd0, pal_cs     } +
        { 3'd0, ram_cs     } +
        { 3'd0, io_cs      } +
        { 3'd0, objsys_cs  } +
        { 3'd0, objreg_cs  } +
        { 3'd0, pcu_cs     } +
        { 3'd0, joystk_cs  } +
        { 3'd0, basel_cs   } +
        { 3'd0, out_cs     } +
        { 3'd0, snd_cs     } +
        { 3'd0, snd_irq    } +
        { 3'd0, tilesys_cs } > 1;
wire none_cs = ~|{ rom_cs, pal_cs, ram_cs, io_cs, objsys_cs,
    objreg_cs, pcu_cs, joystk_cs, tilesys_cs, eeprom_cs, basel_cs, out_cs, snd_cs, snd_irq };
`endif

always @(*) begin
    rom_addr[12: 0] = A[12:0];
    // used only by simpsons
    i6n = ~(A[15:10]==7 || (!init && A[15:10]==6'h1f ));
    i7n = ~((A[15:10]==7 && !WOC0) || (
            init ? (A[15:13]==1 && !WOC1) || (A[15:13]==0 && !WOC0) || A[15:12]==1 :
                    A[15:10]==7 && (WOC1  || WOC0) ));
    io_aux   = &{ ~i6n, ~i7n, A[9:7] };
    // used only by parodius
    paro_i6n = !(A[15:10]==6'hf);
    paro_i7n = A[15:12]==3 || (A[15:14]==1 && (!A[13]||!bankr)) || (A[15:12]==2 && (!WOC1 || A[11]));
    paro_aux = &{ ~paro_i6n, A[9:7] };
    misc_cs  = paro_aux && A[6:4]==3'b100;
    out_cs   = misc_cs && A[3:2]==0;
    basel_cs = misc_cs && A[3:2]==1;
    unpaged  = A[15:13]>=5;
    if( paroda ) begin
        eeprom_cs = 0;
        prog_cs   = 0;

        joystk_cs  = paro_aux && A[6:4]==3'b000;
        io_cs      = paro_aux && A[6:4]==3'b001;
        objreg_cs  = paro_aux && A[6:4]==3'b010;
        pcu_cs     = paro_aux && A[6:4]==3'b011; // 053251
        tilesys_cs = paro_i7n && (A[8:7]==1 || A[9:8]==1 || !A[7] || paro_i6n );
        snd_irq    = misc_cs && A[3:2]==2;
        snd_cs     = misc_cs && A[3:2]==3;
        ram_cs     = A[15:13]==0 && |{A[12:11],~WOC0};
        pal_cs     = A[15:11]==0 && WOC0;
        objsys_cs  = A[15:11]==4 && WOC1;
        banked_cs  = A[15:13]==4 || (A[15:13]==3 && bankr); // 6000~7FFF on bankr, 8000~9FFF always
        rom_cs     = banked_cs || A[15];
        rom_addr[16:13] = banked_cs ? {~Aupper[2:0], A[15]} : {1'b1,A[15:13]};
        rom_addr[17] = !Aupper[3]||!banked_cs;
        rom_addr[18] = 0;
    end else begin
        banked_cs  =  init && A[15:13]==3 && !Aupper[4]; // 6000~7FFF
        prog_cs    = (init && A[14:13]==3 &&  Aupper[4]) || A[15];
        ram_cs     = A[15:13]==2 && init;
        // after second decoder:
        pal_cs     = A[15:12]==0 && WOC0; // COLOCS in sch
        objsys_cs  = A[15:13]==1 && WOC1 && init;
        eeprom_cs  = io_aux && A[6:4]==3'b000;
        joystk_cs  = io_aux && A[6:4]==3'b001;
        objreg_cs  = io_aux && A[6:4]==3'b010;
        pcu_cs     = io_aux && A[6:4]==3'b011; // 053251
        io_cs      = io_aux && A[6:4]==3'b100;
        tilesys_cs = (~i6n & (~A[9] | ~A[8] | ~A[7] | (A[6]&(A[5]|A[4])))) | (i6n^i7n);

        snd_irq    = io_cs && A[3:1]==2;
        snd_cs     = io_cs && A[3:1]==3;

        rom_cs     = prog_cs | banked_cs;
        rom_addr[16:13] = A[15] ? {2'b11,A[14:13]} : Aupper[3:0];
        rom_addr[17]    = A[15] | Aupper[5];
        rom_addr[18]    = ~banked_cs;
        if( !rom_cs ) rom_addr[15:0] = A[15:0]; // necessary to address gfx chips correctly
    end
end

always @* begin
    cpu_din = rom_cs     ? rom_data  : // maximum priority
              ram_cs     ? ram_dout  :
              (joystk_cs|eeprom_cs ) ? port_in : // io_cs must take precedence over tilesys_cs (?)
              pal_cs     ? pal_dout  :
              tilesys_cs ? tilesys_dout :
              snd_cs     ? snd2main  :
              objsys_cs  ? objsys_dout  : 8'h00;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        port_in   <= 0;
        rmrd      <= 0;
        init      <= 0; // missing this will result in garbled scroll after reset
        berr_l    <= 0;
        WOC0      <= 0;
        WOC1      <= 0;
        // simpsons only:
        firqen    <= 0;
        eep_di    <= 0;
        eep_cs    <= 0;
        eep_clk   <= 0;
        mono      <= 0;
        objcha_n  <= 0;
        // parodius only:
        pal_bank  <= 0;
        bankr     <= 0;
    end else begin
        if( buserror ) berr_l <= 1;
        if( paroda ) begin
            objcha_n <= 1;
            if(basel_cs) {pal_bank,WOC1,WOC0} <= cpu_dout[2:0];
            if(out_cs && cpu_we) begin
                {bankr, rmrd } <= cpu_dout[4:3]; // coin counters are 1:0 here, unconnected brightness in bits 7:5
                $display("write to out_cs %X",cpu_dout);
            end
            if(io_cs) port_in <= dipsw[15:8];
            if( joystk_cs ) case( A[1:0] )
                2'd0: port_in <= { joystick1[5:4],joystick1[6],joystick1[1:0],joystick1[3:2],cab_1p[0] };
                2'd1: port_in <= { joystick2[5:4],joystick2[6],joystick2[1:0],joystick2[3:2],cab_1p[1] };
                2'd2: port_in <= { dipsw[23:20], coin[1:0], 1'b1, service };
                2'd3: port_in <= dipsw[7:0];
            endcase
        end else begin // simpsons
            if( io_cs ) case( A[3:1] )
                0: { objcha_n, init, rmrd, mono } <= cpu_dout[5:2]; // bits 1:0 are coin counters
                1: { eep_di, eep_clk, eep_cs, firqen, WOC1, WOC0 } <= { cpu_dout[7], cpu_dout[4:0] };
                // 4: CRCS ?
                // 5: AFR (watchdog)
                default:;
            endcase

            if( joystk_cs ) case( A[1:0] )
                2'd0: port_in <= { cab_1p[0], joystick1[6:0] };
                2'd1: port_in <= { cab_1p[1], joystick2[6:0] };
                2'd2: port_in <= { cab_1p[2], joystick3[6:0] };
                2'd3: port_in <= { cab_1p[3], joystick4[6:0] };
            endcase
        end
        if( eeprom_cs ) port_in <= A[0] ? { WOC1, WOC0, eep_rdy, eep_do,
                                            eep_di, eep_clk, eep_cs, dip_test } // real PCB */
                                        //{ 2'b11, eep_rdy, eep_do, 3'b111, dip_test } // use for MAME comparisons
                                        : { {4{service}}, coin };
    end
end

jt5911 #(.SIMFILE("nvram.bin"),.SYNHEX("default.hex")) u_eeprom(
    .rst        ( rst       ),
    .clk        ( clk       ),
    // chip interface
    .sclk       ( eep_clk   ),         // serial clock
    .sdi        ( eep_di    ),         // serial data in
    .sdo        ( eep_do    ),         // serial data out
    .rdy        ( eep_rdy   ),
    .scs        ( eep_cs    ),         // chip select, active high. Goes low in between instructions
    // Dump access
    .mem_addr   ( nv_addr   ),
    .mem_din    ( nv_din    ),
    .mem_we     ( nv_we     ),
    .mem_dout   ( nv_dout   ),
    // NVRAM contents changed
    .dump_clr   ( 1'b0      ),
    .dump_flag  (           )
);

jtframe_edge #(.QSET(0)) u_firq (
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( ~dma_bsy  ), // FIRQ triggered at the end of the DMA transfer
    .clr    ( ~firqen   ),
    .q      ( firqn_ff  )
);

/* xverilator tracing_off */
// there is a reset for the first 8 frames, skip it in sims
always @(posedge clk) rst_cmb <= rst `ifndef SIMULATION | rst8 `endif ;
// always @(posedge clk) rst_cmb <= rst | rst8;

/* verilator tracing_off */
jtkcpu u_cpu(
    .rst    ( rst_cmb   ),
    .clk    ( clk       ),
    .cen2   ( cen_ref   ),
    .cen_out( cpu_cen   ),

    .halt   ( berr_l    ),
    .dtack  ( dtack     ),
    .nmi_n  ( 1'b1      ),
    .irq_n  ( irq_n | ~dip_pause ),
    .firq_n ( firqn_ff  ),
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
    assign cpu_cen   = 0;
    assign cpu_dout  = 0;
    assign ram_we    = 0;
    assign cpu_we    = 0;
    assign st_dout   = 0;
    assign pal_we    = 0;
    assign rom_addr  = 0;
    assign snd_wrn   = 1;
    assign nv_din    = 0;
    assign nv_addr   = 0;
    assign nv_we     = 0;

    initial begin
        init       = 0;
        rom_addr   = 0;
        rom_cs     = 0;
        rmrd       = 0;
        pcu_cs     = 0;
        tilesys_cs = 0;
        objsys_cs  = 0;
        objreg_cs  = 0;
        objcha_n   = 1;
        snd_irq    = 0;
        mono       = 0;
        pal_bank   = 0;
        st_dout    = 0;
    end
`endif
endmodule