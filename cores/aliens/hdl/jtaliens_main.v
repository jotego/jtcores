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

module jtaliens_main(
    input               rst,
    input               clk,
    input               cen_ref,
    input               cen12,
    output              cpu_cen,

    input       [ 1:0]  cfg,
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
    input       [ 3:0]  cab_1p,
    input       [ 3:0]  coin,
    input       [ 6:0]  joystick1,
    input       [ 6:0]  joystick2,
    input       [ 6:0]  joystick3,
    input       [ 6:0]  joystick4,
    input               service,

    // From video
    input               rst8,
    input               irq_n,
    input               nmi_n,

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
    output reg  [ 7:0]  snd_latch,
    // DIP switches
    input               dip_pause,
    input       [19:0]  dipsw,
    // PMC chip
    output              cpu2pmc_we,
    input       [ 7:0]  pmc2main_data,
    output              pmc_we,
    output      [10:0]  pmc_addr,
    input       [ 7:0]  pmc_dout,
    output      [ 7:0]  pmc_din,
    // Debug
    input       [ 7:0]  debug_bus,
    output reg  [ 7:0]  st_dout
);
`ifndef NOMAIN
`include "jtaliens.inc"

wire [ 7:0] Aupper, pmc_st;
reg  [ 7:0] cpu_din, port_in;
reg  [ 3:0] bank;
reg  [ 3:0] eff_bank;
wire [15:0] A, pcbad;
wire        buserror;
reg         ram_cs, banked_cs, io_cs, pal_cs, work, pmc_work,
            ioout, incs , chain, berr_l,
            e19_o16, e19_o12, objaux;
wire        dtack;  // to do: add delay for io_cs
reg         rst_cmb, eff_nmi_n,
            pmc_start, pmc_cs, pmc_bk;
wire        norA65, norA43, eff_firqn, pmc_out0;

assign dtack     = ~rom_cs | rom_ok;
assign ram_we    = ram_cs & cpu_we;
assign pal_we    = pal_cs & cpu_we;
assign norA65    = ~|A[6:5],
       norA43    = ~|A[4:3];
assign eff_firqn = cfg!=THUNDERX | pmc_out0; // only Thunder X uses FIRQ

always @(*) begin
    case( debug_bus[1:0] )
        0: st_dout = Aupper;
        1: st_dout = { 2'd0, pmc_st[1:0], 3'd0, berr_l };
        2: st_dout = pcbad[7:0];
        3: st_dout = pcbad[15:8];
    endcase
end

always @(*) begin
    case( cfg )
        SCONTRA, THUNDERX: begin
            rom_addr[17]    = 0;
            rom_addr[16]    =  banked_cs && eff_bank[3];
            rom_addr[15]    = (banked_cs && eff_bank[3]) ? eff_bank[2] : A[15];
            rom_addr[14:13] = banked_cs ? eff_bank[1:0] : A[14:13];
            rom_addr[12:0]  = A[12:0];
        end
        CRIMFGHT: begin
            rom_addr = { 1'b0, A[15] ?  {2'b11,A[14:13]} : Aupper[3:0], A[12:0] };
        end
        default: begin // Aliens
            rom_addr = banked_cs ? {  Aupper[4:0], A[12:0] } // 5+13=18
                                  : { 2'b10, A }; // 2+16=18
        end
    endcase
    if( !rom_cs ) rom_addr[15:0] = A[15:0]; // necessary to address gfx chips correctly
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
        { 3'd0, pmc_cs     } +
        { 3'd0, tilesys_cs } > 1;
wire none_cs = ~|{ rom_cs, pal_cs, ram_cs, io_cs, objsys_cs, tilesys_cs };
wire test_cs = A[15:0]>=16'h2000 && A[15:0]<16'h6000;
wire bad2_cs = test_cs & ~tilesys_cs & ~objsys_cs;
`endif

always @(*) begin
    ioout = 0;
    incs  = 0;
    chain = 0;
    objaux  = 0;
    e19_o16 = 0;
    e19_o12 = 0;
    pmc_cs  = A[15:11]==5'b01011 && cfg==THUNDERX && pmc_work;
    case( cfg )
        CRIMFGHT: begin
            e19_o16   = init && A[15:11]==5'b01011;
            e19_o12   = A[15:10]==0 && work;
            ram_cs    = A[15:13]==0 && (A[12:10]!=0 || ~work );
            banked_cs = A[15] | &{init,A[14:13]};
            chain     = ~A[15] & ( A[14] & ~init |
                                  ~A[14] &  A[13]  |
                                   A[14] & ~A[13]  |
                                  ~A[14] & ~A[12] & ~A[11] & ~A[10] & work ); // /E19_o17
            incs      = init && A[15:10]==6'b001111; // ~E19_o15
            io_cs     = &A[9:7] & norA65 & incs;
            pal_cs    = chain && e19_o12;
            objaux    = ~rmrd & (
                            A[10] & e19_o16
                          | A[9:7]==0 & norA65 & norA43 & e19_o16 );
            objsys_cs = chain & objaux;
            tilesys_cs = ~( objaux
                          | ~chain
                          | e19_o12
                          | &A[9:7] & norA65 & incs );
        end
        SCONTRA, THUNDERX: begin
            banked_cs  = A[15:13]==3 && (init || cfg==THUNDERX); // 6000-7FFFF
            pal_cs     = A[15:12]==5 && A[11] && ~work; // CRAMCS in sch
            ram_cs     = A[15:13]==2 && (!A[11] || !A[12]&&A[11] || work);
            ioout      = A[15:13]==0;
            incs       = !init && A[15:13]==3'b011;
            chain      = A[15:12]==4'b11 && !rmrd;
            io_cs      = ioout && A[12:8]==5'h1f && A[7];
            objsys_cs  = chain && A[11] && ( A[10] || A[9:3]==0 );
            tilesys_cs = !( !incs && (
                        A[15:14]!=0 ||
                        chain && A[11] && (A[10] || A[9:3]==0) ||
                        &A[12:7] && ioout ));
        end
        default: begin
            banked_cs  = /*!Aupper[4] &&*/ A[15:13]==1; // 2000-3FFFF
            ram_cs     = A[15:13]==0 && ( A[12] || A[11] || A[10] || !work);
            // after second decoder:
            io_cs      = A[15:7]=='b0101_1111_1 && norA65;
            pal_cs     = A[15:10]==0 && work; // CRAMCS in sch
            objsys_cs  = A[15:11]=='b01111 && !rmrd && init &&
                            (A[10] || (A[9:7]==0 && norA65 && norA43));
            tilesys_cs = A[15:14]==1 && ( !init || (!io_cs && !pal_cs && !objsys_cs));
        end
    endcase
    rom_cs = !rst_cmb && (A[15] || banked_cs) && !cpu_we; // >=8000
    if( pmc_cs ) {pal_cs,ram_cs}=0;
end

always @* begin
    cpu_din = rom_cs     ? rom_data  :
              ram_cs     ? ram_dout  :
              io_cs      ? port_in   :    // io_cs must take precedence over tilesys_cs
              pal_cs     ? pal_dout  :
              tilesys_cs ? tilesys_dout :
              objsys_cs  ? objsys_dout  :
              pmc_cs     ? pmc2main_data: 8'hff;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd_irq   <= 0;
        snd_latch <= 0;
        port_in   <= 0;
        work      <= 0;
        pmc_work  <= 0;
        prio      <= 0;
        rmrd      <= 0;
        init      <= 0; // missing this will result in garbled scroll after reset
        eff_bank  <= 0;
        eff_nmi_n <= 1;
        berr_l    <= 0;
    end else begin
        if( buserror ) berr_l <= 1;
        eff_nmi_n <= (cfg==ALIENS || cfg==THUNDERX) ? nmi_n : 1'b1;
        eff_bank  <= cfg==SCONTRA ? bank : Aupper[3:0]; // Only Super Contra uses a latch
        if( cfg==CRIMFGHT ) begin
            init <= Aupper[7];
            rmrd <= Aupper[6];
            work <= Aupper[5];
        end
        if(cpu_cen) snd_irq <= 0;
        if( io_cs ) case(cfg)
            CRIMFGHT: begin
                case( A[3:2] )
                    0: begin // CONTROL1 in schematics
                        case( A[1:0] )
                            0: port_in <= { 3'b111, service, coin };
                            1: port_in <= { cab_1p[0], joystick1[6:0] };
                            2: port_in <= { cab_1p[1], joystick2[6:0] };
                            3: port_in <= dipsw[15:8];
                        endcase
                    end
                    1: begin // CONTROL2 in schematics
                        case( A[1:0] )
                            0: port_in <= { init, rmrd, work, 1'b1, dipsw[19:16] };
                            1: port_in <= { cab_1p[2], joystick3[6:0] };
                            2: port_in <= { cab_1p[3], joystick4[6:0] };
                            3: port_in <= dipsw[7:0];
                        endcase
                    end
                    // 2: watchdog
                    3: begin
                        snd_latch <= cpu_dout;
                        snd_irq   <= 1;
                    end
                endcase
            end
            THUNDERX: begin // Thunder Cross
                if( !A[5] ) case( A[4:2] )
                    0: begin
                        { prio[1], pmc_work, prio[0], work } <= { cpu_dout[5:3], cpu_dout[0] };
                    end
                    1: snd_latch <= cpu_dout;
                    2: snd_irq   <= 1;
                    // 3: AFR (watchdog)
                    4: begin // COINEN
                        case( A[1:0] )
                            0: port_in <= { 3'b111, cab_1p[1:0], service, coin[1:0] };
                            1: port_in <= { 2'b11, joystick1[5:0] };
                            2: port_in <= { 2'b11, joystick2[5:0] };
                            3: port_in <= { 2'b11, joystick1[6], joystick2[6], dipsw[19:16] };
                            default: port_in <= 8'hff;
                        endcase
                    end
                    5: port_in <= A[0] ? dipsw[15:8] : dipsw[7:0];
                    6: { pmc_start, pmc_bk, rmrd } <= cpu_dout[2:0];
                    default:;
                endcase
            end
            SCONTRA: begin
                if( !A[5] ) case( A[4:2] )
                    0: begin
                        prio[1:0] <= {1'b0, cpu_dout[7]};
                        { work, bank } <= cpu_dout[4:0];
                    end
                    1: snd_latch <= cpu_dout;
                    2: snd_irq   <= 1;
                    // 3: AFR (watchdog)
                    4: begin // COINEN
                        case( A[1:0] )
                            0: port_in <= { 3'b111, cab_1p[1:0], service, coin[1:0] };
                            1: port_in <= { 2'b11, joystick1[5:0] };
                            2: port_in <= { 2'b11, joystick2[5:0] };
                            3: port_in <= { 2'b11, joystick1[6], joystick2[6], dipsw[19:16] };
                            default: port_in <= 8'hff;
                        endcase
                    end
                    5: port_in <= A[0] ? dipsw[15:8] : dipsw[7:0];
                    6: rmrd <= cpu_dout[0];
                    7: init <= cpu_dout[0];
                    default:;
                endcase
            end
            ALIENS: begin // Aliens
                if( cpu_we ) begin
                    case( A[3:0] )
                        4'h8: begin
                            { init, rmrd, work } <= cpu_dout[7:5];
                            // bits 1:0 are coin counters
                        end
                        4'hc: begin
                            snd_latch <= cpu_dout;
                            snd_irq   <= 1;
                        end
                        default:;
                    endcase
                end else case( A[3:0] )
                    0: port_in <= { 3'b111, service, dipsw[19:16] };
                    1: port_in <= { cab_1p[0], coin[0], joystick1[5:0] };
                    2: port_in <= { cab_1p[1], coin[1], joystick2[5:0] };
                    3: port_in <= dipsw[15:8];
                    4: port_in <= dipsw[ 7:0];
                    // 8 watchdog
                    default: port_in <= 8'hff;
                endcase
            end
            default:;
        endcase
    end
end

jt052591 u_pmc(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen12     ),

    .cs         ( pmc_cs    ),
    .cpu_we     ( cpu_we    ),
    .cpu2ram_we ( cpu2pmc_we),

    .ram_we     ( pmc_we    ),
    .ram_addr   ( pmc_addr  ),
    .ram_dout   ( pmc_dout  ),
    .ram_din    ( pmc_din   ),

    .bk         ( pmc_bk    ),     // 1=internal RAM, 0=external RAM
    .out0       ( pmc_out0  ),     // connected to PCMFIRQ in Thunder Cross
    .start      ( pmc_start ),     // triggers the programmed process
    .st_dout    ( pmc_st    )
);

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
    .nmi_n  ( eff_nmi_n ),
    .irq_n  ( irq_n | ~dip_pause ),
    .firq_n ( eff_firqn ),
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