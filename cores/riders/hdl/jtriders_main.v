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
    Date: 7-7-2024 */

module jtriders_main(
    input                rst,
    input                clk, // 48 MHz
    input                lgtnfght,
    input                glfgreat,
    input                LVBL, dma_bsy,
    input                cpu_n,       // low when CPU can access video RAM

    output        [19:1] main_addr,
    output        [ 1:0] ram_dsn, lmem_we,
    output        [15:0] cpu_dout,
    input                BRn,
    input                BGACKn,
    output               BGn,
    // 8-bit interface
    output               cpu_we,
    output reg           pal_cs,
    output reg           pcu_cs,
    output reg           psreg_cs, psac_bank,
    // Sound interface
    output               snd_wrn,   // K053260 (PCM sound)
    input         [ 7:0] snd2main,  // K053260 (PCM sound)
    output reg           sndon,     // irq trigger

    output reg           rom_cs,
    output reg           ram_cs,
    output reg           vram_cs,
    output reg           obj_cs,

    input         [15:0] oram_dout,
    input         [15:0] prot_dout, lmem_dout,
    input         [ 7:0] vram_dout, platch,
    input         [15:0] pal_dout,
    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,
    input                vdtac,
    input                tile_irqn,
    input                prot_irqn,
    output reg           prot_cs,

    // Object RAM containing ROM address MSB bits, used in tmnt2
    output               omsb_we,
    output      [ 8:0]   omsb_addr,
    input       [ 7:0]   omsb_dout,
    // video configuration
    output reg           objreg_cs,
    output reg           rmrd,
    output reg           dimmod,
    output reg           dimpol,
    output reg  [ 2:0]   dim,
    output reg  [ 2:0]   cbnk,      // unconnected in ssriders
    // EEPROM
    output      [ 6:0]   nv_addr,
    input       [ 7:0]   nv_dout,
    output      [ 7:0]   nv_din,
    output               nv_we,
    // Cabinet
    input         [ 6:0] joystick1, joystick2, joystick3, joystick4,
    input         [19:0] dipsw,
    input         [ 3:0] cab_1p,
    input         [ 3:0] coin,
    input         [ 3:0] service,
    input                dip_pause,
    input                dip_test,
    output        [ 7:0] st_dout,
    input         [ 7:0] debug_bus
);
`ifndef NOMAIN
wire [23:1] A;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, allFC, ASn, VPAn, DTACKn;
wire [ 2:0] FC;
reg  [ 2:0] IPLn, riders_dim;
reg         cab_cs, snd_cs, iowr_hi, iowr_lo, iowr_cs, HALTn,
            eep_di, eep_clk, eep_cs, omsb_cs, pslrm_cs, psvrm_cs,
            riders_son, riders_rmrd, adc_cs, out_cs, hit_cs;
reg  [15:0] cpu_din, cab_dout;
wire [15:0] glfgreat_cab;
wire [ 7:0] riders_cab, lgtnfght_cab;
wire [ 2:0] lgtnfght_dim;
wire        eep_rdy, eep_do, bus_cs, bus_busy, BUSn, adc=0;
wire        dtac_mux, lgtnfght_son, lgtnfght_rmrd;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign main_addr= lgtnfght ? {2'd0,A[17:1]} : A[19:1];
assign ram_dsn  = {UDSn, LDSn};
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | (ram_cs & ~ram_ok);
assign BUSn     = ASn | (LDSn & UDSn);

assign cpu_we   = ~RnW;
assign omsb_we  = omsb_cs && cpu_we && !LDSn;
assign omsb_addr= { cbnk, A[6:1] };
assign lmem_we  = ~ram_dsn & {2{ pslrm_cs & ~RnW}};

assign st_dout  = 0; //{ rmrd, 1'd0, prio, div8, game_id };
assign VPAn     = (lgtnfght | glfgreat) ? ~&{A[23],~ASn} : ~&{BGACKn, FC[1:0], ~ASn};
assign dtac_mux = DTACKn | ~vdtac;
assign snd_wrn  = ~(snd_cs & ~RnW);

reg none_cs/*, wdog*/;
// not following the PALs as the dumps from PLD Archive are not readable
// with MAME's JEDUTIL
always @* begin
    rom_cs     = 0;
    ram_cs     = 0;
    pal_cs     = 0;
    iowr_lo    = 0;
    iowr_hi    = 0;
    iowr_cs    = 0;
    cab_cs     = 0;
    vram_cs    = 0; // tilesys_cs
    omsb_cs    = 0;
    obj_cs     = 0;
    objreg_cs  = 0;
    snd_cs     = 0;
    riders_son = 0;
    pcu_cs     = 0;
    prot_cs    = 0;
    // 053936
    pslrm_cs   = 0;
    psreg_cs   = 0;
    psvrm_cs   = 0;
    // glfgreat
    adc_cs     = 0;
    out_cs     = 0;
    hit_cs     = 0;
    // wdog     = 0;
    if(!ASn) begin if(lgtnfght) casez(A[20:16])
        5'o0?: rom_cs = 1;
        5'o10: pal_cs = 1;      // 0x08'0000
        5'o11: ram_cs = ~BUSn;  // 0x09'0000
        5'o12: case(A[5:3])     // 0x0A'0000
            0,1,2: cab_cs = 1;  // 0x0A'0000~B
            3: iowr_cs = 1;     // 0x0A'0018
            4: snd_cs  = 1;
            // 5: wdog_cs = 1;
            default:;
        endcase
        5'o13: obj_cs = 1;      // 0x0B'0000
        5'o14: objreg_cs = 1;   // 0x0C'0000
        // 5'o15: bw_cs = 1; ???
        5'o16: pcu_cs  = 1;     // 0x0E'0000
        5'o20: vram_cs = 1;     // 0x10'0000
        default:;
    endcase else if(glfgreat) begin if(!A[23]) casez(A[21:12]) // 2-4-4
       //   22 1111 1111
       //   10 9876 5432
        10'b00_????_????: rom_cs  = 1;     // 00'0000 ~ 0F'FFFF - LS139 @ 3F
        10'b01_??00_00??: ram_cs  = ~BUSn; // 10'0000 ~ 10'3FFF - LS138 @ 4F
        10'b01_??00_01??: obj_cs  = 1;     // 10'4000 ~ 10'7FFF
        10'b01_??00_10??: pal_cs  = 1;     // 10'8000 ~ 10'8FFF
        10'b01_??00_11??: pslrm_cs= 1;     // 10'C000 ~ 10'CFFF 053936 line RAM
        10'b01_??01_00??: objreg_cs=1;     // 11'0000 ~ 11'0FFF OBJSET1
    //  10'b01_??01_01??: objreg_cs=1;     // 11'4000 ~ 11'4FFF OBJSET2
        10'b01_??01_10??: psreg_cs= 1;     // 11'8000 ~ 11'8FFF 053936 regs
        10'b01_??01_11??: pcu_cs  = 1;     // 11'C000 ~ 11'CFFF
        10'b01_??1?_?000: cab_cs  = 1;     // 12'0000           - LS138 @ 7E
        10'b01_??1?_?001: hit_cs  = 1;     // 12'0001           - LS138 @ 7E
        10'b01_??1?_?010: out_cs  = 1;     // 12'0001           - LS138 @ 7E
        10'b01_??1?_?011: adc_cs  = 1;     // 12'0001           - LS138 @ 7E
        10'b01_??1?_?101: snd_cs  = 1;     // 12'0001           - LS138 @ 7E

        10'b10_????_????: vram_cs = 1;     // 20'0000 ~ 2F'FFFF - LS139 @ 3F
        10'b11_????_????: psvrm_cs= 1;     // 30'0000 ~ 3F'FFFF - LS139 @ 3F
        default:;
    endcase end else case(A[23:20]) // tmnt2/ssriders
        0: rom_cs = 1;
        1: case(A[19:18])
            0: ram_cs  = A[14] & ~BUSn;
            1: pal_cs  = 1;  // 14'xxxx
            2: obj_cs  = 1;  // 18'xxxx (not all A bits go to OBJ chip 053245)
            3: case(A[11:8]) // decoder 13G (pdf page 16)
              0,1: cab_cs  = 1;
                2: iowr_lo = 1; // EEPROM
                3: iowr_hi = 1;
                // 4: wdog    = 1;
                5: omsb_cs = 1;
                8: prot_cs = 1;
                default:;
            endcase
            default:;
        endcase
        5: case(A[19:16])
            4'ha: objreg_cs = 1;
            4'hc: case(A[11:8]) // 13G
                6: begin
                    snd_cs = !A[2]; // 053260
                    riders_son  =  A[2];
                end
                7: pcu_cs = 1;      // 053251
                default:;
                endcase
            default:;
            endcase
        6: vram_cs = 1; // probably different at boot time
        default:;
    endcase end
`ifdef SIMULATION
    none_cs = ~BUSn & ~|{rom_cs, ram_cs, pal_cs, iowr_lo, iowr_hi, iowr_cs, /*wdog,*/
        cab_cs, vram_cs, obj_cs, objreg_cs, snd_cs, riders_son, pcu_cs, prot_cs};
`endif
end

always @(posedge clk) begin
    IPLn    <= {tile_irqn,1'b1, (lgtnfght | glfgreat) ? tile_irqn : prot_irqn};
    HALTn   <= dip_pause & ~rst;
    cab_dout<= glfgreat ? glfgreat_cab:
               lgtnfght ? {8'd0,lgtnfght_cab}:
                          {8'd0,riders_cab  };
    sndon   <= lgtnfght ? lgtnfght_son  : riders_son;
    dim     <= lgtnfght ? lgtnfght_dim  : riders_dim;
    rmrd    <= lgtnfght ? lgtnfght_rmrd : riders_rmrd;
    cpu_din <= rom_cs   ? rom_data         :
               ram_cs   ? ram_dout         :
               obj_cs   ? oram_dout        :
               prot_cs  ? prot_dout        :
               vram_cs  ? {2{vram_dout}}   :
               hit_cs   ? {8'd0,platch }   :
               pal_cs   ? pal_dout         :
               pslrm_cs ? lmem_dout        :
               snd_cs   ? {8'd0,snd2main } :
               omsb_cs  ? {8'd0,omsb_dout} :
               cab_cs   ? cab_dout         : 16'h0;
    if(out_cs) begin // glfgreat
        rmrd <= cpu_dout[4];
        psac_bank <= cpu_dout[5];
    end
end

jtriders_cab u_riders_cab(
    .clk        ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    .cs         ( cab_cs        ),
    .addr       ( A[8:1]        ),
    .IPLn       ( IPLn          ),
    .LVBL       ( LVBL          ),
    .eep_do     ( eep_do        ),
    .eep_rdy    ( eep_rdy       ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .joystick3  ( joystick3     ),
    .joystick4  ( joystick4     ),
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .service    ( service       ),
    .dip_test   ( dip_test      ),
    .dout       ( riders_cab    )
);

jtglfgreat_cab u_cab(
    .clk        ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    .cs         ( cab_cs        ),
    .dma        ( dma_bsy       ),
    .dipsw      ( dipsw         ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .joystick3  ( joystick3     ),
    .joystick4  ( joystick4     ),
    .addr       ( A[8:1]        ),
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .service    ( service[0]    ),
    .dip_test   ( dip_test      ),
    .adc        ( adc           ),
    .dout       ( glfgreat_cab  )
);

jtlgtnfght_cab u_lgtnfght_cab(
    .clk        ( clk           ),
    .cpu_n      ( cpu_n         ),       // low when CPU can access video RAM
    .addr       ( A[4:1]        ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .dipsw      ( dipsw         ),
    .cab_1p     ( cab_1p[1:0]   ),
    .coin       ( coin[1:0]     ),
    .service    ( service[0]    ),
    .dip_test   ( dip_test      ),
    .dout       ( lgtnfght_cab  )
);

jtlgtnfght_com u_lgtnfght_com(
    .clk    ( clk           ),
    .din    ( cpu_dout      ),
    .dsn    ( {UDSn,LDSn}   ),
    .rnw    ( RnW           ),
    .cs     ( iowr_cs       ),
    .cl     ( lgtnfght_dim  ),
    .sndon  ( lgtnfght_son  ),
    .vromrd ( lgtnfght_rmrd )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        riders_dim  <= 0;
        riders_rmrd <= 0;
        dimpol  <= 0;
        dimmod  <= 0;
        eep_di  <= 0;
        eep_cs  <= 0;
        eep_clk <= 0;
        cbnk    <= 0;
    end else begin
        if( iowr_lo  ) { cbnk, dimpol, dimmod, eep_clk, eep_cs, eep_di } <= cpu_dout[7:0];
        if( iowr_hi  ) { riders_dim, riders_rmrd } <= cpu_dout[6:3];
    end
end

jt5911 #(.SIMFILE("nvram.bin")) u_eeprom(
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

// The board seems to control DTACKn with combinational logic
// DTACKn follows ASn with a delay of ~15.6ns
jtframe_68kdtack_cen #(.W(6),.RECOVERY(1)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 5'd1      ),  // numerator
    .den        ( 6'd3      ),  // denominator, 3 (16MHz)
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    // Frequency report
    .fave       (           ),
    .fworst     (           )
);

jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .RESETn     (             ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

    // Buses
    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),


    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),

    .BERRn      ( 1'b1        ),
    // Bus arbitrion
    .HALTn      ( HALTn       ),
    .BRn        ( BRn         ),
    .BGACKn     ( BGACKn      ),
    .BGn        ( BGn         ),

    .DTACKn     ( dtac_mux    ),
    .IPLn       ( IPLn        ) // VBLANK
);
`else
    reg [7:0] saved[0:0];
    integer f,fcnt=0;

    initial begin
        f=$fopen("other.bin","rb");
        if( f!=0 ) begin
            fcnt=$fread(saved,f);
            $fclose(f);
            $display("Read %1d bytes for dimming configuration", fcnt);
            {dimpol,dimmod,dim} = {saved[0][5:4],saved[0][2:0]};
        end else begin
            {dimpol,dimmod,dim} = 0;
        end
    end
    initial begin
        cbnk      = 0;
        obj_cs    = 0;
        objreg_cs = 0;
        pal_cs    = 0;
        pcu_cs    = 0;
        ram_cs    = 0;
        rmrd      = 0;
        rom_cs    = 0;
        sndon     = 0;
        vram_cs   = 0;
        prot_cs   = 0;
    end
    assign
        cpu_dout  = 0,
        cpu_we    = 0,
        main_addr = 0,
        ram_dsn   = 0,
        snd_wrn   = 0,
        st_dout   = 0,
        nv_addr   = 0,
        nv_din    = 0,
        omsb_addr = 0,
        omsb_we   = 0,
        BGn       = 0,
        nv_we     = 0;
`endif
endmodule
