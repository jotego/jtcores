/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

// Ghosts'n Goblins: Main CPU

module jtgng_main(
    input              clk, 
    input              cen6  /* synthesis direct_enable = 1 */,   // 6MHz
    input              cen3  /* synthesis direct_enable = 1 */,   // 3MHz
    input              cen1p5  /* synthesis direct_enable = 1 */,   // 1.5MHz
    input              rst,
    input              soft_rst,
    input              ch_mrdy,
    input              [7:0] char_dout,
    input              LVBL,   // vertical blanking when 0
    output             [7:0] cpu_dout,
    output             main_cs,
    output             char_cs,
    output             blue_cs,
    output             redgreen_cs,    
    output  reg        flip,
    // Sound
    output  reg        sres_b, // Z80 reset
    output  reg [7:0]  snd_latch,
    // scroll
    input              scr_mrdy,
    input   [7:0]      scr_dout,
    output             scr_cs,
    output             scrpos_cs,
    // cabinet I/O
    input   [7:0]      joystick1,
    input   [7:0]      joystick2,
    // BUS sharing
    output             bus_ack,
    input              bus_req,
    input              blcnten,
    input   [ 8:0]     obj_AB,
    output  [12:0]     cpu_AB,
    output             RnW,
    output             OKOUT,
    output  [7:0]      ram_dout,
    // ROM access
    output  reg [16:0] rom_addr,
    input       [ 7:0] rom_dout,
    // DIP switches
    input              dip_flip,
    input              dip_game_mode,
    input              dip_attract_snd,
    input              dip_upright
);

wire [15:0] A;
wire MRDY_b = ch_mrdy & scr_mrdy;
reg nRESET;
wire in_cs;
wire sound_cs, ram_cs, bank_cs, screpos_cs, flip_cs;

reg [11:0] map_cs;

assign { 
    sound_cs, OKOUT, scrpos_cs,   scr_cs, 
    in_cs,  blue_cs, redgreen_cs, flip_cs, 
    ram_cs, char_cs, bank_cs,     main_cs } = map_cs;

reg [7:0] AH;

always @(*)
    casez(A[15:8])
        8'b0011_1010: map_cs = 12'h800; // 3A00-3AFF, sound
        8'b0011_1100: map_cs = 12'h400; // OKOUT 
        8'b0011_1011: map_cs = 12'h200; // 3B00-3BFF Scroll position
        8'b0010_1???: map_cs = 12'h100; // 2800-2FFF    Scroll
        8'b0011_0???: map_cs = 12'h080; // 3000-37FF input
        8'b0011_1001: map_cs = 12'h040; // 3900-39FF, blue
        8'b0011_1000: map_cs = 12'h020; // 3800-38FF, Red, green
        8'b0011_1101: map_cs = 12'h010; // 3D?? flip
        8'b000?_????: map_cs = 12'h008; // 0000-1FFF, RAM
        8'b0010_0???: map_cs = 12'h004; // 2000-27FF Char
        8'b0011_1110: map_cs = 12'h002; // 3E00-3EFF bank
        8'b01??_????: map_cs = 12'h001; // ROMs
        8'b1???_????: map_cs = 12'h001; // ROMs
        default:      map_cs = 12'h000;
    endcase

// special registers
reg [2:0] bank;
always @(posedge clk)
    if( rst ) begin
        nRESET <= 1'b0;
        bank   <= 3'd0;
    end
    else if(cen6) begin
        if( bank_cs && !RnW ) begin
            bank <= cpu_dout[2:0];
        end
        else nRESET <= ~(rst | soft_rst);
    end

localparam coinw = 4;
reg [coinw-1:0] coin_cnt1, coin_cnt2;

always @(posedge clk)
    if( rst ) begin
        coin_cnt1 <= {coinw{1'b0}};
        coin_cnt2 <= {coinw{1'b0}};
        flip <= 1'b0;
        sres_b <= 1'b1;
        end
    else if(cen6) begin
        if( flip_cs ) 
            case(A[2:0])
                3'd0: flip <= cpu_dout[0];
                3'd1: sres_b <= cpu_dout[0];
                3'd2: coin_cnt1 <= coin_cnt1+{ {(coinw-1){1'b0}}, cpu_dout[0] };
                3'd3: coin_cnt2 <= coin_cnt2+{ {(coinw-1){1'b0}}, cpu_dout[0] };
                default:;
            endcase
    end

always @(posedge clk)
    if( rst ) 
        snd_latch <= 8'd0;
    else if(cen6) begin
        if( sound_cs ) snd_latch <= cpu_dout;
    end

reg [7:0] cabinet_input;
wire [7:0] dipsw_a = { dip_flip, dip_game_mode, dip_attract_snd, 5'h1F /* 1 coin, 1 credit */ };
wire [7:0] dipsw_b = { 3'd3, /* normal game */
    2'd3, /* bonus at 20k and every 70k */
    dip_upright, 2'd3 /* 3 lifes */ };
/*
reg [7:0] joystick1_sync, joystick2_sync;

// 1 FF synchronizer
always @(negedge clk) begin
    joystick1_sync <= joystick1;
    joystick2_sync <= joystick2;
end
*/
always @(*)
    case( cpu_AB[3:0])
        4'd0: cabinet_input = { joystick2[7],joystick1[7], // COINS
                     4'hf, // undocumented. The game start screen has background when set to 0!
                     joystick2[6], joystick1[6] }; // START
        4'd1: cabinet_input = { 2'b11, joystick1[5:0] };
        4'd2: cabinet_input = { 2'b11, joystick2[5:0] };
        4'd3: cabinet_input = dipsw_a;
        4'd4: cabinet_input = dipsw_b;
        default: cabinet_input = 8'hff;
    endcase


// RAM, 8kB
wire cpu_ram_we = ram_cs && !RnW;
assign cpu_AB = A[12:0];

wire [12:0] RAM_addr = blcnten ? { 4'hf, obj_AB } : cpu_AB;
wire RAM_we   = blcnten ? 1'b0 : cpu_ram_we;

jtgng_ram #(.aw(13)) RAM(
    .clk        ( clk       ),
    .cen        ( cen6      ),
    .addr       ( RAM_addr  ),
    .data       ( cpu_dout  ),
    .we         ( RAM_we    ),
    .q          ( ram_dout  )
);

reg [7:0] cpu_din;

always @(*)
    case( {ram_cs, char_cs, scr_cs, main_cs, in_cs} )
        5'b10_000: cpu_din =  ram_dout;
        5'b01_000: cpu_din = char_dout;
        5'b00_100: cpu_din =  scr_dout;
        5'b00_010: cpu_din =  rom_dout;
        5'b00_001: cpu_din =  cabinet_input;
        default:   cpu_din =  rom_dout;
    endcase

always @(A,bank) begin
    rom_addr[12:0] = A[12:0];
    casez( A[15:13] )
        3'b1??: rom_addr[16:13] = { 2'h0, A[14:13] }; // 8N, 9N (32kB) 0x8000-0xFFFF
        3'b011: rom_addr[16:13] = 4'b101; // 10N - 0x6000-0x7FFF (8kB)
        3'b010:  // 0x4000-0x5FFF
          rom_addr[16:13] = bank==3'd4 ? 4'b100 : {2'd0,bank[1:0]}+4'b110; // 13N
        default: rom_addr[16:13] = 4'd0;
    endcase
end

// Bus access
reg nIRQ, last_LVBL;
wire BS,BA;

assign bus_ack = BA && BS;

always @(posedge clk) if(cen6) begin
    last_LVBL <= LVBL;
    if( {BS,BA}==2'b10 )
        nIRQ <= 1'b1;
    else 
        if(last_LVBL && !LVBL ) nIRQ<=1'b0; // when LVBL goes low
end


`ifndef ALT6809
// cycle accurate core
wire EXTAL = ~(clk &cen6);
wire [111:0] RegData;
wire E;
mc6809 u_cpu (
    .D       ( cpu_din ),
    .DOut    ( cpu_dout),
    .ADDR    ( A       ),
    .RnW     ( RnW     ),
    .BS      ( BS      ),
    .BA      ( BA      ),
    .nIRQ    ( nIRQ    ),
    .nFIRQ   ( 1'b1    ),
    .nNMI    ( 1'b1    ),
    .EXTAL   ( EXTAL   ),
    .nHALT   ( ~bus_req),
    .nRESET  ( nRESET  ),
    .MRDY    ( MRDY_b  ),
    .nDMABREQ( 1'b1    ),
    // unused:
    .XTAL    ( 1'b0    ),
    .E       ( E       ),
    .Q(),
    .RegData ( RegData )
    //.AVMA()
);
`ifdef SIMULATION
wire [ 7:0] reg_a  = RegData[7:0];
wire [ 7:0] reg_b  = RegData[15:8];
wire [15:0] reg_x  = RegData[31:16];
wire [15:0] reg_y  = RegData[47:32];
wire [15:0] reg_s  = RegData[63:48];
wire [15:0] reg_u  = RegData[79:64];
wire [ 7:0] reg_cc = RegData[87:80];
wire [ 7:0] reg_dp = RegData[95:88];
wire [15:0] reg_pc = RegData[111:96];
reg [95:0] last_regdata;

integer fout;
integer ticks=0, last_ticks=0;
initial begin
    fout = $fopen("m6809.log","w");    
end
always @(negedge E) begin
    last_regdata <= RegData[95:0];
    ticks <= ticks+1;
    if( last_regdata != RegData[95:0] ) begin
        $fwrite(fout,"%d,%X, %X,%X,%X,%X,%X,%X,%X,%X,%X\n", 
            ticks-last_ticks, nIRQ,
            reg_pc, reg_cc, reg_dp, reg_x, reg_y, reg_s, reg_u,
            reg_a, reg_b);
        last_ticks <= ticks;
    end
end
`endif
`else 
// This is cpu09I_128a.vhd core
// but it doesn't seem to work fine
cpu09 u_cpu(
    .clk     ( clk       ),
    .ce      ( cen1p5    ),
    .rst     ( rst       ),
    .ba      ( BA        ),
    .bs      ( BS        ),
    .addr    (  A        ),
    .rw      ( RnW       ),
    .data_out( cpu_dout  ),
    .data_in ( cpu_din   ),
    .irq     ( ~nIRQ     ),
    .firq    ( 1'b0      ),
    .nmi     ( 1'b0      ),
    .halt    ( bus_req   ),
    // unused outputs
    .vma     (           ),
    .lic_out (           ),
    .ifetch  (           ),
    .opfetch (           )
);
`endif
/*
`ifndef VERILATOR_LINT
wire VMA;
mc6809_cen cpu (
    .clk     ( clk     ),
    .clk_en  ( cen6    ),
    .D       ( cpu_din ),
    .DOut    ( cpu_dout),
    .ADDR    ( A       ),
    .RnW     ( RnW     ),
    .BS      ( BS      ),
    .BA      ( BA      ),
    .nIRQ    ( nIRQ    ),
    .nFIRQ   ( 1'b1    ),
    .nNMI    ( 1'b1    ),
    .nHALT   ( ~bus_req),
    .nRESET  ( nRESET  ),
    .MRDY    ( MRDY_b  ),
    .nDMABREQ( 1'b1    ),
    .VMA     ( VMA     )
);
`endif
*/
endmodule // jtgng_main