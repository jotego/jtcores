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
    Date: 13-12-2022 */

module jtkarnov_main(
    input              rst,
    input              clk,

    input              LVBL,
    input       [ 8:0] hdump,

    // Bus signals
    output      [15:0] cpu_dout,
    output reg  [18:1] cpu_addr,
    output      [ 1:0] dsn,
    output             RnW,

    // Sound control
    output reg         sonreq,
    output reg  [ 7:0] snd_latch,

    // Video RAMs
    output reg         vram_cs,
    output reg         scrram_cs,
    output reg         objram_cs,
    input       [15:0] vram2main_data,
    input       [15:0] scrram2main_data,
    input       [15:0] objram2main_data,
    input              sdtkn,   // DTAK signal for the video
    output reg  [ 8:0] scrx,
    output reg  [ 8:0] scry,
    output reg         flip,
    output reg         dmarq,   // object RAM DMA. The DMA does not halt the CPU

    // MCU
    input              mcu2main_irq,
    input       [15:0] mcu_dout,
    output reg  [15:0] mcu_din,
    output reg         secreq,      // original signal name

    // cabinet I/O
    input       [ 7:0] joystick1,
    input       [ 7:0] joystick2,

    input       [ 1:0] cab_1p,
    input       [ 1:0] coin,
    input              service,

    // RAM access
    output             ram_cs,
    input       [15:0] ram_data,   // coming from VRAM or RAM
    input              ram_ok,

    output reg         rom_cs,
    input       [15:0] rom_data,
    input              rom_ok,

    // DIP switches
    input              dip_pause,
    input              dip_test,
    input       [15:0] dipsw,

    // Debug
    input    [7:0]     st_addr,
    output   [7:0]     st_dout
);
`ifndef NOMAIN
wire [23:1] A;
reg  [ 2:0] IPLn;
wire [ 2:0] FC;
reg  [15:0] cpu_din;
reg         pre_ram_cs, cab_cs, pos_cs, vint_ctl,
            ok_dly, secr, vint_en, seclr;
wire        pre_vb_int, vb_int, mcu2main_int;
wire        VPAn, ASn, DTACKn, BUSn;
wire        cpu_cen, cpu_cenb;
wire [15:0] fave;
reg  [15:0] cab_dout;
wire        bus_cs, bus_busy, bus_legit, disp_cs, disp_busy;

`ifdef SIMULATION wire [23:0] A_full = {A,1'b0}; `endif

assign vb_int     = pre_vb_int & vint_en;
assign VPAn       = ~&FC | ASn;
assign st_dout    = st_addr[0] ? fave[15:8] : fave[7:0]; // 10,000kHz = 2710 in hex
assign bus_cs     = pre_ram_cs || rom_cs;
assign disp_cs    = vram_cs | scrram_cs;
assign disp_busy  = hdump[1]; // This has approximately the same effect as the original 4-flip flop circuit
assign bus_busy   = |{ rom_cs & ~ok_dly, ram_cs & ~ram_ok, disp_cs & disp_busy };
assign bus_legit  = disp_cs;
assign BUSn       = ASn | &dsn;
assign ram_cs     = ~BUSn & pre_ram_cs;

always @* begin
    cpu_addr = A[18:1];
    if( scrram_cs && A[11] )
        cpu_addr[10:1] = { A[5:1], A[10:6] }; // This col-row swap is a feature of the tile mapper mux (sch. page 7/16)
end

always @* begin
    IPLn =~(vb_int ? 3'd7:
            mcu2main_int ? 3'd6 : 3'd0);
end

wire bus_bad = !ASn && A[21:17]>6;

always @* begin
    rom_cs    = 0; // rom & ram have immediate DTACK
    pre_ram_cs= 0;
    objram_cs = 0;
    vram_cs   = 0;
    scrram_cs = 0;
    cab_cs    = 0;
    seclr     = 0;
    secr      = 0; // CPU reads from MCU
    secreq    = 0; // CPU writes to MCU
    sonreq    = 0;
    dmarq     = 0;
    pos_cs    = 0;
    vint_ctl  = 0;
    if( !ASn && (RnW || dsn!=3)) begin
        rom_cs    = A[21:17]<=2; // 00000~5FFFF
        pre_ram_cs= A[21:17]==3; // 60000~6FFFF
        objram_cs = A[21:17]==4; // 80000
        vram_cs   = A[21:17]==5 && !A[12]; // A0000 ~ A07FF
        scrram_cs = A[21:17]==5 &&  A[12]; // A1000~A17FF  --
        if( A[21:17]==6 ) begin // IO SEL
            // Reads
            cab_cs   =  RnW && A[2:1]< 3;
            secr     =  RnW && A[2:1]==3;
            // Writes
            seclr    = !RnW && A[3:1]==0;
            sonreq   = !RnW && A[3:1]==1;
            dmarq    = !RnW && A[3:1]==2;
            secreq   = !RnW && A[3:1]==3;
            pos_cs   = !RnW && (A[3:1]==4 || A[3:1]==5);
            vint_ctl = !RnW && A[3:1]>=6; // A[1] high enables the interrupt, A[1] low disables it
        end
// `ifdef SIMULATION
//         if( A[21:17]>6 ) begin
//             $display("M68k went out of the memory space");
//             $finish;
//         end
// `endif
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scrx      <= 0;
        scry      <= 0;
        vint_en   <= 0;
        snd_latch <= 0;
        ok_dly    <= 0;
        mcu_din   <= 0;
    end else begin
        ok_dly <= rom_ok;
        if( pos_cs ) begin
            if( A[1]) scry <= cpu_dout[8:0];
            if(!A[1]) begin
                scrx <= cpu_dout[8:0];
                flip <= cpu_dout[15];
            end
        end
        if( vint_ctl ) vint_en <= A[1];
        if( sonreq   ) snd_latch <= cpu_dout[7:0];
        if( secreq   ) mcu_din   <= cpu_dout;
    end
end

always @(posedge clk) begin
    case(A[2:1])
        0: cab_dout <= { joystick2, joystick1 };
        1: cab_dout <= { 8'hff, ~LVBL, 3'd7, cab_1p, 2'b11 }; // button 5 should be bits 1:0, not adding it
        2: cab_dout <= dipsw;
        3: cab_dout <= 16'hffff;
    endcase

    cpu_din <= rom_cs    ? rom_data :
               ram_cs    ? ram_data :
               vram_cs   ? vram2main_data :
               scrram_cs ? scrram2main_data :
               objram_cs ? objram2main_data :
               secr      ? mcu_dout :
               cab_cs    ? cab_dout : 16'h0;
end

jtframe_edge u_mcuint(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .edgeof     ( mcu2main_irq  ),
    .clr        ( seclr         ),
    .q          ( mcu2main_int  )
);

jtframe_edge u_vbint(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .edgeof     ( ~LVBL & dip_pause ),
    .clr        ( vint_ctl & A[1]   ),
    .q          ( pre_vb_int    )
);

jtframe_68kdtack_cen #(.W(8)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( bus_legit ),
    .ASn        ( ASn       ),
    .DSn        ( dsn       ),
    .num        ( 7'd5      ),  // numerator
    .den        ( 8'd24     ),  // denominator
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    // Frequency report
    .fave       ( fave      ),
    .fworst     (           ),
    .frst       ( 1'b0      )
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
    .LDSn       ( dsn[0]      ),
    .UDSn       ( dsn[1]      ),
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
assign rom_cs   = 0;
assign ram_cs   = 0;
assign vram_cs  = 0;
assign scrram_cs= 0;
assign objram_cs= 0;
assign cpu_dout = 0;
assign cpu_addr = 0;
assign snd_latch= 0;
assign sonreq   = 0;
assign RnW      = 1;
assign st_dout  = 0;
assign secreq   = 0;
assign flip     = 0;
assign mcu_din  = 0;
assign dsn      = 3;
// Read the scroll values in simulation
reg [8:0] scrfile[0:1];

initial begin
    $readmemh( "scrpos.hex", scrfile);
    scrx = scrfile[0];
    scry = scrfile[1];
end
always @(negedge LVBL) begin
    scrx <= scrx+1'd1;
end
always @(posedge clk) dmarq <= LVBL;

`endif
endmodule