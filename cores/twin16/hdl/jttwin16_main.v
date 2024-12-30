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
    Date: 27-8-2023 */

module jttwin16_main(
    input                rst,
    input                clk, // 48 MHz
    input                LVBL,

    output        [19:1] main_addr,
    output        [ 1:0] ram_dsn,
    output        [15:0] cpu_dout,
    output               ram_we,
    // 8-bit interface
    output               pal_we,
    // sub CPU
    output reg           sint,
    // video status
    output reg           rom_cs,
    output reg           ram_cs,
    output reg           dma_on,
    input                dma_bsy,
    input                tim,
    input                mint,
    // shared RAM
    output        [ 1:0] sh_we,
    input         [15:0] sh_dout,
    // NVRAM
    output        [14:1] nvram_addr,
    input         [15:0] nvram_dout,
    output        [ 1:0] nvram_we,
    // video RAM outputs,
    input         [15:0] ma_dout,   // scroll A
    input         [15:0] mb_dout,   // scroll B
    input         [15:0] mf_dout,   // fixed layer
    input         [15:0] mo_dout,   // objects
    input         [ 7:0] mp_dout,
    output        [ 1:0] va_we,
    output        [ 1:0] vb_we,
    output        [ 1:0] fx_we,
    output        [ 1:0] oram_we,

    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,

    // Sound interface
    output reg    [ 7:0] snd_latch,
    output reg           sndon,

    // video configuration
    output reg           hflip, vflip, vramcvf,
    output reg    [ 2:0] prio,
    output reg    [ 8:0] scra_x, scra_y, scrb_x, scrb_y,
    output reg    [15:0] obj_dx, obj_dy,

    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input         [ 6:0] joystick3,
    input         [ 2:0] cab_1p,
    input         [ 2:0] coin,
    input                service,
    input                dip_pause,
    input         [19:0] dipsw,
    output reg    [ 7:0] st_dout,
    input         [ 7:0] debug_bus
);
`ifndef NOMAIN

wire [23:1] A;
wire [ 1:0] dws;
wire        cpu_cen, cpu_cenb, pre_dtackn, cpu_we, oeff_cs,
            UDSn, LDSn, RnW, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
reg         fix_cs, snd_cs, syswr_cs, io_cs, vram_cs, oram_cs,
            pal_cs, dma_cs, sh_cs,    nvram_cs, mint_en;
reg  [15:0] cpu_din;
wire [15:0] vdout;
reg  [ 7:0] cab_dout;
reg  [ 4:0] nvram_ahi;
reg         LVBLl;
wire        bus_cs, bus_busy, BUSn, ab_sel;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign main_addr  = A[19:1];
assign nvram_addr = {nvram_ahi,A[9:1]};
assign ram_dsn    = {UDSn, LDSn};
assign bus_cs     = rom_cs | ram_cs;
assign bus_busy   = (rom_cs  & ~rom_ok) | (ram_cs  & ~ram_ok);
assign BUSn       = ASn | (LDSn & UDSn);
assign cpu_we     = ~RnW;
assign ram_we     = ~RnW;
assign pal_we     = pal_cs & cpu_we & ~LDSn;
assign dws        = ~({2{RnW}} | {UDSn, LDSn});
assign sh_we      = dws & {2{sh_cs}};
assign nvram_we   = dws & {2{nvram_cs&!A[10]}};
assign ab_sel     = ~A[13];
assign va_we      = dws & {2{vram_cs & ~A[13]}};
assign vb_we      = dws & {2{vram_cs &  A[13]}};
assign fx_we      = dws & {2{fix_cs}};
assign oram_we    = dws & {2{oeff_cs}};

always @* begin
    case( debug_bus[3:0] )
        0: st_dout = scra_x[7:0];
        1: st_dout = scrb_x[7:0];
        2: st_dout = scra_y[7:0];
        3: st_dout = scrb_y[7:0];
        4: st_dout = { vflip, hflip, prio[1:0], scrb_y[8],scra_y[8], scrb_x[8], scra_x[8] };
        7: st_dout = obj_dx[ 7:0];
        8: st_dout = obj_dx[15:8];
        9: st_dout = obj_dy[ 7:0];
       10: st_dout = obj_dy[15:8];
       11: st_dout = { dma_on, 2'd0, mint_en, 2'd0, prio[1:0] };
       default: st_dout = 0;
    endcase
end

always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    oram_cs  = 0;
    vram_cs  = 0;
    sh_cs    = 0;
    fix_cs   = 0;
    pal_cs   = 0;
    io_cs    = 0;
    dma_cs   = 0;
    syswr_cs = 0;
    nvram_cs = 0;

    if(!ASn) casez( A[20:17] )
        // decoder 3L
        4'b000?: rom_cs = 1;
        4'b0010: sh_cs  = 1;
        4'b0011: ram_cs = !BUSn;
        4'b0100: pal_cs = 1;
        4'b0101: begin
            io_cs    =!A[16];     // A'0000~A'001F
            nvram_cs = A[16]; // B'0000~
        end
        4'b0110: begin // sysflag
            dma_cs   =  RnW;
            syswr_cs = !RnW;
        end
        // decoder 3N
        4'b1?00: fix_cs  = 1;
        4'b1?01: vram_cs = 1;
        4'b1?10: oram_cs = 1;
        default:;
    endcase
end

always @(posedge clk) begin
    cpu_din <= rom_cs   ? rom_data   :
               ram_cs   ? ram_dout   :
               oram_cs  ? vdout      :
               vram_cs  ? vdout      :
               sh_cs    ? sh_dout    :
               fix_cs   ? mf_dout    :
               nvram_cs ? nvram_dout :
               pal_cs   ? {  8'd0, mp_dout  } :
               io_cs    ? {  8'd0, cab_dout } :
               dma_cs   ? { 15'd0, dma_bsy  } :
               16'h0;
end

jttwin16_dtack u_tim_dtack(
    .clk        ( clk       ),
    .ASn        ( ASn       ),
    .RnW        ( RnW       ),
    .LDSn       ( LDSn      ),
    .UDSn       ( UDSn      ),
    .oram_cs    ( oram_cs   ),
    .vram_cs    ( vram_cs   ),
    .dma_bsy    ( dma_bsy   ),
    .oeff_cs    ( oeff_cs   ),
    .tim        ( tim       ),
    .ab_sel     ( ab_sel    ),
    .ma_dout    ( ma_dout   ),
    .mb_dout    ( mb_dout   ),
    .mo_dout    ( mo_dout   ),
    .vdout      ( vdout     ),
    .pre_dtackn ( pre_dtackn),
    .DTACKn     ( DTACKn    )
);

jttwin16_ints u_ints(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .LVBL   ( LVBL      ),
    .ASn    ( ASn       ),
    .A23    ( A[23]     ),

    // request from the other CPU
    .intn   ( mint      ),
    .int_en ( mint_en   ),

    .VPAn   ( VPAn      ),
    .IPLn   ( IPLn      )
);

always @(posedge clk) begin
    case( A[4:3] )
        0: case( A[2:1] )
            0: cab_dout <= {1'b1, service, cab_1p, coin };
            1: cab_dout <= { 1'b1, joystick1 };
            2: cab_dout <= { 1'b1, joystick2 };
            3: cab_dout <= { 1'b1, joystick3 };
        endcase
        2: cab_dout <= A[1] ? dipsw[7:0] : dipsw[15:8];
        3: cab_dout <= { 4'hf, dipsw[19:16] };
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        prio     <= 0;
        scra_x   <= 0;
        scra_y   <= 0;
        scrb_x   <= 0;
        scrb_y   <= 0;
        hflip    <= 0;
        vflip    <= 0;
        obj_dx   <= 0;
        obj_dy   <= 0;
        mint_en  <= 0;
        sndon    <= 0;
        dma_on   <= 0;
        vramcvf  <= 0;
        sint     <= 1;
    end else begin
        if( nvram_cs && A[10] ) nvram_ahi <= cpu_dout[12:8];
        if( syswr_cs )
            // this register is partly implemented on 007779 and
            // partly on discrete standard logic
            case( A[3:1] )
                0:  { vramcvf, prio, hflip, vflip } <= cpu_dout[5:0];
                1: obj_dx <= cpu_dout[15:0];
                2: obj_dy <= cpu_dout[15:0];
                3: scra_x <= cpu_dout[ 8:0];
                4: scra_y <= cpu_dout[ 8:0];
                5: scrb_x <= cpu_dout[ 8:0];
                6: scrb_y <= cpu_dout[ 8:0];
                default:;
            endcase
        if( io_cs ) begin
            case( {RnW, A[4:3]} )
                0: {dma_on, mint_en, sint, sndon} <= cpu_dout[6:3];
                1: snd_latch <= cpu_dout[7:0];
                //2: watchdog
                default:;
            endcase
        end
    end
end

jtframe_68kdtack_cen #(.W(5),.RECOVERY(1)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 4'd3      ),  // numerator
    .den        ( 5'd16     ),  // denominator, => 9216
    .DTACKn     ( pre_dtackn),
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
    .HALTn      ( dip_pause   ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        (             ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        ) // VBLANK
);
`else
    integer fin, fcnt;
    reg [7:0] mmr[0:11];

    initial begin
        for( fcnt=0; fcnt<11; fcnt=fcnt+1 ) mmr[fcnt]=0;
        fin=$fopen("rest.bin","rb");
        fcnt = $fread(mmr,fin);
        $display("Read %d bytes from rest.bin",fcnt);
        $fclose(fin);

        scra_x   = { mmr[4][0], mmr[0] };
        scrb_x   = { mmr[4][1], mmr[1] };
        scra_y   = { mmr[4][2], mmr[2] };
        scrb_y   = { mmr[4][3], mmr[3] };
        prio     = {1'b0,mmr[4][5:4]};
        hflip    = mmr[4][6];
        vflip    = mmr[4][7];
        obj_dx   = {mmr[8],mmr[7]};
        obj_dy   = {mmr[10],mmr[9]};
        dma_on   = mmr[11][0];
    end
    // integer framecnt=0;
    // always @(posedge LVBL) begin
    //     framecnt <=framecnt+1;
    //     sndon    <=framecnt==10;
    // end
    initial begin
        rom_cs    = 0;
        ram_cs    = 0;
        vramcvf   = 0;
        snd_latch = 0;
        sndon     = 0;
        sint      = 0;
        st_dout   = 0;
    end
    assign
        main_addr = 0,
        ram_dsn   = 0,
        cpu_dout  = 0,
        pal_we    = 0,
        va_we     = 0,
        vb_we     = 0,
        fx_we     = 0,
        nvram_addr= 0,
        nvram_we  = 0,
        ram_we    = 0,
        sh_we     = 0,
        oram_we   = 0;
`endif
endmodule
