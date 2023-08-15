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
    Date: 12-8-2023 */

module jttmnt_main(
    input                rst,
    input                clk, // 48 MHz
    input                LVBL,

    output        [18:1] main_addr,
    output        [ 1:0] ram_dsn,
    output        [15:0] cpu_dout,
    // 8-bit interface
    output        [ 7:0] cpu_d8,
    output               cpu_we,
    output               pal_we,

    output reg           rom_cs,
    output reg           ram_cs,
    output reg           vram_cs,
    output reg           obj_cs,

    input         [ 7:0] oram_dout,
    input         [ 7:0] vram_dout,
    input         [ 7:0] pal_dout,
    input         [15:0] ram_dout,
    input         [15:0] rom_data,
    input                ram_ok,
    input                rom_ok,

    // Sound interface
    output reg    [ 7:0] snd_latch,
    output reg           sndon,

    // video configuration
    output reg           rmrd,
    output reg    [ 1:0] prio,

    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input         [ 6:0] joystick3,
    input         [ 6:0] joystick4,
    input         [ 3:0] start_button,
    input         [ 3:0] coin_input,
    input                service,
    input                dip_pause,
    input         [19:0] dipsw,
    output        [ 7:0] st_dout
);

wire [23:1] A;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, allFC, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
reg         pal_cs, snddt_cs, shoot_cs,
            dip_cs, dip3_cs, syswr_cs, iowr_cs, int16en;
reg  [ 7:0] cab_dout;
reg  [15:0] cpu_din;
reg         intn, LVBLl;
wire        bus_cs, bus_busy, BUSn;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign main_addr= A[18:1];
assign ram_dsn  = {UDSn, LDSn};
assign IPLn     = { intn, 1'b1, intn };
assign bus_cs   = rom_cs | ram_cs;
assign bus_busy = (rom_cs & ~rom_ok) | ( ram_cs & ~ram_ok);
assign BUSn     = ASn | (LDSn & UDSn);

assign cpu_d8   = UDSn ? cpu_dout[15:8] : cpu_dout[7:0];
assign cpu_we   = ~RnW;
assign pal_we   = pal_cs & ~LDSn & ~RnW;

assign st_dout  = 0;
assign VPAn     = ~( A[23] & ~ASn );

always @* begin
    rom_cs   = 0;
    ram_cs   = 0;
    pal_cs   = 0;
    iowr_cs  = 0;
    snddt_cs = 0;
    shoot_cs = 0;
    dip_cs   = 0;
    dip3_cs  = 0;
    syswr_cs = 0;
    vram_cs  = 0;
    obj_cs   = 0;
    if(!ASn) begin
        if(!A[20]) case( A[19:17] )
            0,1,2: rom_cs = 1;
            3: ram_cs = ~BUSn;
            4: pal_cs = 1;
            5: if(!A[16]) case( { RnW, A[4:3] } )
                    0: iowr_cs  = 1;
                    1: snddt_cs = 1;
                    // 2: watchdog
                    4: shoot_cs = 1;
                    6: dip_cs   = 1;
                    7: dip3_cs  = 1;
                    default:;
                endcase
            6: syswr_cs = 1;
            default:;
        endcase else case(A[18:17])
            0: vram_cs = 1;
            2: obj_cs  = 1;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    cpu_din <= rom_cs  ? rom_data  :
               ram_cs  ? ram_dout  :
               obj_cs  ? {2{oram_dout}} :
               vram_cs ? {2{vram_dout}} :
               pal_cs  ? {2{pal_dout}}  :
               dip3_cs ? { 12'd0, dipsw[19:16] } :
               (shoot_cs | dip_cs) ? { 8'd0, cab_dout } :
               16'hffff;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        LVBLl <= 0;
        intn  <= 1;
    end else begin
        LVBLl <= LVBL;
        if( !LVBL && LVBLl )
            intn <= 0;
        if( !int16en )
            intn <= 1;
    end
end

always @(posedge clk) begin
    if(dip_cs) case( A[2:1] )
        ~2'd0: cab_dout <= 0;
        ~2'd1: cab_dout <= dipsw[7:0];
        ~2'd2: cab_dout <= dipsw[15:8];
        ~2'd3: cab_dout <= { start_button[3], joystick4[6:0] };
    endcase
    else case( A[2:1] )
        ~2'd0: cab_dout <= { start_button[2], joystick3[6:0] };
        ~2'd1: cab_dout <= { start_button[1], joystick2[6:0] };
        ~2'd2: cab_dout <= { start_button[0], joystick1[6:0] };
        ~2'd3: cab_dout <= { {4{service}}, coin_input };
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        prio    <= 0;
        rmrd    <= 0;
        int16en <= 0;
        sndon   <= 0;
    end else begin
        if( syswr_cs ) prio <= cpu_dout[3:2];
        if( iowr_cs  )
            { rmrd, int16en, sndon } <= {cpu_dout[7], cpu_dout[5], cpu_dout[3]};
        if( snddt_cs ) snd_latch <= cpu_dout[7:0];
    end
end

jtframe_68kdtack #(.W(6),.RECOVERY(1)) u_dtack(
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
    .den        ( 6'd6      ),  // denominator
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    // Frequency report
    .fave       (           ),
    .fworst     (           ),
    .frst       (           )
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

endmodule
