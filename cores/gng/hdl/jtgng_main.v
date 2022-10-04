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
    input              cen6,
    output             cpu_cen,
    input              rst,
    input              LVBL,   // vertical blanking when 0
    input              block_flash,
    output  reg        blue_cs,
    output  reg        redgreen_cs,
    output  reg        flip,
    // Sound
    output  reg        sres_b, // Z80 reset
    output  reg [7:0]  snd_latch,
    // Characters
    input       [7:0]  char_dout,
    output      [7:0]  cpu_dout,
    output  reg        char_cs,
    input              char_busy,
    // scroll
    input       [7:0]  scr_dout,
    output  reg        scr_cs,
    input              scr_busy,
    output  reg [8:0]  scr_hpos,
    output  reg [8:0]  scr_vpos,
    input              scr_holdn,
    // cabinet I/O
    input       [1:0]  start_button,
    input       [1:0]  coin_input,
    input       [5:0]  joystick1,
    input       [5:0]  joystick2,
    // BUS sharing
    output             bus_ack,
    input              bus_req,
    input              blcnten,
    input   [ 8:0]     obj_AB,
    output  [12:0]     cpu_AB,
    output             RnW,
    output reg         OKOUT,
    output  [7:0]      ram_dout,
    // ROM access
    output  reg        rom_cs,
    output  reg [16:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,
    // DIP switches
    input              service,
    input              dip_pause,
    input  [7:0]       dipsw_a,
    input  [7:0]       dipsw_b
);

wire [15:0] A;
wire waitn;
wire nRESET;
wire cen_E, cen_Q;
reg  sound_cs, scrpos_cs, in_cs, flip_cs, ram_cs, bank_cs;

//`ifdef SIMULATION
//reg dump_on = 1'b0;
//always @(posedge bank_cs/*, posedge scr_cs, posedge char_cs*/) begin
//    if( !dump_on ) begin
//        dump_on <= 1'b1;
//        $display("DUMP starts because of CS edge");
//        $dumpfile("test.lxt");
//        $dumpvars(0,mist_test);
//        $dumpon;
//    end
//end
//`endif

reg [7:0] AH;

always @(*) begin
    sound_cs    = 1'b0;
    OKOUT       = 1'b0;
    scrpos_cs   = 1'b0;
    scr_cs      = 1'b0;
    in_cs       = 1'b0;
    blue_cs     = 1'b0;
    redgreen_cs = 1'b0;
    flip_cs     = 1'b0;
    ram_cs      = 1'b0;
    char_cs     = 1'b0;
    bank_cs     = 1'b0;
    rom_cs      = 1'b0;
    if( /* (E || Q || !waitn) && */ nRESET ) case(A[15:13])
        3'b000: ram_cs = 1'b1;
        3'b001: case( A[12:11])
                2'd0: char_cs = 1'b1;
                2'd1: scr_cs  = 1'b1;
                2'd2: in_cs   = 1'b1;
                2'd3: case( A[10:8] )
                    3'd0: redgreen_cs = block_flash ? ~LVBL : 1'b1;
                    3'd1: blue_cs     = block_flash ? ~LVBL : 1'b1;
                    3'd2: sound_cs    = 1'b1;
                    3'd3: scrpos_cs   = 1'b1;
                    3'd4: OKOUT       = 1'b1;
                    3'd5: flip_cs     = 1'b1;
                    3'd6: bank_cs     = 1'b1;
                    default:;
                endcase
            endcase
        default: rom_cs = 1'b1;
    endcase
end

// SCROLL H/V POSITION
always @(posedge clk or negedge nRESET)
    if( !nRESET ) begin
        scr_hpos <= 8'd0;
        scr_vpos <= 8'd0;
    end else if(cen_Q) begin
        if( scrpos_cs && A[3] && scr_holdn)
        case(A[1:0])
            2'd0: scr_hpos[7:0] <= cpu_dout;
            2'd1: scr_hpos[8]   <= cpu_dout[0];
            2'd2: scr_vpos[7:0] <= cpu_dout;
            2'd3: scr_vpos[8]   <= cpu_dout[0];
        endcase
    end

// special registers
reg [2:0] bank;
always @(posedge clk or negedge nRESET)
    if( !nRESET ) begin
        bank   <= 3'd0;
    end
    else if(cen_Q) begin
        if( bank_cs && !RnW ) begin
            bank <= cpu_dout[2:0];
        end
    end

// CPU reset
jt12_rst u_rst(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .rst_n  ( nRESET    )
);

localparam coinw = 4;
reg [coinw-1:0] coin_cnt1, coin_cnt2;

always @(posedge clk)
    if( rst ) begin
        coin_cnt1 <= {coinw{1'b0}};
        coin_cnt2 <= {coinw{1'b0}};
        flip <= 1'b0;
        sres_b <= 1'b1;
        end
    else if(cen_Q) begin
        if( flip_cs )
            case(A[2:0])
                3'd0: flip <= ~cpu_dout[0];
                3'd1: sres_b <= cpu_dout[0];
                3'd2: coin_cnt1 <= coin_cnt1+{ {(coinw-1){1'b0}}, cpu_dout[0] };
                3'd3: coin_cnt2 <= coin_cnt2+{ {(coinw-1){1'b0}}, cpu_dout[0] };
                default:;
            endcase
    end

always @(posedge clk)
    if( rst )
        snd_latch <= 8'd0;
    else if(cen_Q) begin
        if( sound_cs ) snd_latch <= cpu_dout;
    end

reg [7:0] cabinet_input;

always @(*)
    case( cpu_AB[3:0])
        4'd0: cabinet_input = { coin_input, // COINS
                     service,
                     1'b1, // tilt?
                     2'h3, // undocumented. The game start screen has background when set to 0!
                     start_button }; // START
        4'd1: cabinet_input = { 2'b11, joystick1 };
        4'd2: cabinet_input = { 2'b11, joystick2 };
        4'd3: cabinet_input = dipsw_a;
        4'd4: cabinet_input = dipsw_b;
        default: cabinet_input = 8'hff;
    endcase


// RAM, 8kB
wire cpu_ram_we = ram_cs && !RnW;
assign cpu_AB = A[12:0];

wire [12:0] RAM_addr = blcnten ? { 4'hf, obj_AB } : cpu_AB;
wire RAM_we   = blcnten ? 1'b0 : cpu_ram_we;

jtframe_ram #(.aw(13)) u_ram(
    .clk        ( clk       ),
    .cen        ( cen_Q     ),
    .addr       ( RAM_addr  ),
    .data       ( cpu_dout  ),
    .we         ( RAM_we    ),
    .q          ( ram_dout  )
);

reg [7:0] cpu_din;

always @(*)
    case( {ram_cs, char_cs, scr_cs, rom_cs, in_cs} )
        5'b10_000: cpu_din =  ram_dout;
        5'b01_000: cpu_din =  char_dout;
        5'b00_100: cpu_din =  scr_dout;
        5'b00_010: cpu_din =  rom_data;
        5'b00_001: cpu_din =  cabinet_input;
        default:   cpu_din =  rom_data;
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

always @(posedge clk) if(cen_Q) begin
    last_LVBL <= LVBL;
    if( {BS,BA}==2'b10 )
        nIRQ <= 1'b1;
    else
        if(last_LVBL && !LVBL ) nIRQ<=1'b0 | ~dip_pause; // when LVBL goes low
end

wire bus_busy = scr_busy | char_busy;

jtframe_6809wait u_wait(
    .rstn       ( nRESET    ),
    .clk        ( clk       ),
    .cen        ( cen6      ),
    .cpu_cen    ( cpu_cen   ),
    .dev_busy   ( bus_busy  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .cen_E      ( cen_E     ),
    .cen_Q      ( cen_Q     )
);

// cycle accurate core
wire [111:0] RegData;

mc6809i u_cpu (
    .clk     ( clk     ),
    .cen_E   ( cen_E   ),
    .cen_Q   ( cen_Q   ),
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
    .nDMABREQ( 1'b1    ),
    // unused:
    .RegData ( RegData ),
    .AVMA    (         ),
    .BUSY    (         ),
    .LIC     (         ),
    .OP      (         )
);

`ifdef GNG_CPUDUMP
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
always @(negedge cen_E) begin
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

endmodule // jtgng_main