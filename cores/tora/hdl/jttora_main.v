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
    Date: 12-10-2019 */

// Tiger Road: Main CPU
// 10MHz 68000 CPU


module jttora_main(
    input              rst,
    input              clk,
    output             cen10,
    output             cen10b,
    output             cpu_cen,
    // Timing
    output  reg        flip,
    input   [8:0]      V,
    input              LHBL,
    input              LVBL,
    // Sound
    output  reg  [7:0] snd_latch,
    // Characters
    input       [15:0] char_dout,
    output      [15:0] cpu_dout,
    output  reg        char_cs,
    input              char_busy,
    output             UDSWn,
    output             LDSWn,
    // scroll
    output reg [15:0]  scrposh,
    output reg [15:0]  scrposv,
    output reg         scr_bank,
    // cabinet I/O
    input   [6:0]      joystick1,
    input   [6:0]      joystick2,
    input   [1:0]      start_button,
    input   [1:0]      coin_input,
    input              service,
    // BUS sharing
    output  [13:1]     cpu_AB,
    output  [15:0]     oram_dout,
    input   [13:1]     obj_AB,
    output             RnW,
    output  reg        OKOUT,
    input              obj_br,   // Request bus
    output             bus_ack,  // bus acknowledge
    input              blcnten,  // bus line counter enable
    // MCU interface
    input              mcu_cen,
    input              mcu_brn,
    input      [ 7:0]  mcu_dout,
    output reg [ 7:0]  mcu_din,
    input      [16:1]  mcu_addr,
    input              mcu_wr,
    input              mcu_DMAn,
    output  reg        mcu_DMAONn,
    // Palette
    output             col_uw,
    output             col_lw,
    // ROM access
    output  reg        rom_cs,
    output      [17:1] rom_addr,
    input       [15:0] rom_data,
    input              rom_ok,
    // DIP switches
    input              dip_pause,
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b
);

wire [19:1] A;
wire [3:0] ncA;

`ifdef SIMULATION
wire [24:0] A_full = {ncA, A,1'b0};
`endif

wire [15:0] wram_dout;
wire        BRn, BGACKn, BGn;
reg         io_cs, ram_cs, obj_cs, col_cs;
reg         scrhpos_cs, scrvpos_cs;
(*keep*) wire        ASn;

assign cpu_cen = cen10;
reg BERRn;

// high during DMA transfer
wire UDSn, LDSn;
assign UDSWn = RnW | UDSn;
assign LDSWn = RnW | LDSn;

assign col_uw = col_cs & ~UDSWn;
assign col_lw = col_cs & ~LDSWn;

wire CPUbus = !blcnten && mcu_DMAn; // main CPU in control of the bus

always @(*) begin
    rom_cs     = 1'b0;
    ram_cs     = 1'b0;
    obj_cs     = 1'b0;
    col_cs     = 1'b0;
    io_cs      = 1'b0;
    char_cs    = 1'b0;
    OKOUT      = 1'b0;
    mcu_DMAONn = 1'b1;   // for once, I leave the original active low setting
    scrvpos_cs = 1'b0;
    scrhpos_cs = 1'b0;

    BERRn         = 1'b1;
    // address decoder is not shared with MCU contrary to the original design
    if( CPUbus ) case(A[19:18])
            2'd0: rom_cs = 1'b1;
            2'd1, 2'd2: BERRn = ASn;
            2'd3: if(A[17]) case(A[16:14])  // 111X
                    3'd0:   obj_cs  = 1'b1; // E_0000
                    3'd1:   begin
                        io_cs      = 1'b1; // E_4000
                        mcu_DMAONn = !(A[1] && !RnW);// E_4002
                    end
                    3'd2: if( (!UDSWn || !LDSWn) && !A[4]) begin // E_8000
                        // scrpt_cs
                        case( A[3:1]) // SCRPTn in the schematics
                                3'd0: scrhpos_cs = 1'b1;
                                3'd1: scrvpos_cs = 1'b1;
                                3'd7: begin
                                    OKOUT       = 1'b1;
                                    // $display("OKOUT");
                                end
                            default:;
                        endcase
                    end
                    3'd3:   char_cs = 1'b1; // E_C000
                    3'd6:   col_cs  = 1'b1; // F_8000
                    3'd7:   ram_cs  = 1'b1; // F_C000
                    default:;
                endcase
        endcase
end

// MCU DMA address decoder
reg mcu_ram_cs;

always @(*) begin
    mcu_ram_cs   = 1'b0;
    if( !mcu_DMAn )
        mcu_ram_cs   = 1'b1;
end

// SCROLL H/V POSITION
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scrposh <= 16'd0;
        scrposv <= 16'd0;
    end else if(cpu_cen) begin
        if( scrhpos_cs ) begin
            if(!UDSWn) scrposh[15:8] <= cpu_dout[15:8];
            if(!LDSWn) scrposh[ 7:0] <= cpu_dout[ 7:0];
        end
        if( scrvpos_cs ) begin
            if(!UDSWn) scrposv[15:8] <= cpu_dout[15:8];
            if(!LDSWn) scrposv[ 7:0] <= cpu_dout[ 7:0];
        end
    end
end

// special registers
always @(posedge clk)
    if( rst ) begin
        flip         <= 1'b0;
        snd_latch    <= 8'b0;
        scr_bank     <= 1'b0;
    end
    else if(cpu_cen) begin
        if( !UDSWn && io_cs)
            case( { A[1]} )
                1'b0: begin
                    flip      <= cpu_dout[1];
                    scr_bank  <= cpu_dout[2];
                end
                1'b1: snd_latch <= cpu_dout[15:8];
            endcase
    end

/////////////////////////////////////////////////////
// RAMs data input mux
reg [7:0] ram_udin, ram_ldin;

always @(*) begin
    if( !mcu_DMAn ) begin
        ram_udin = 8'hff;       // unused
        ram_ldin = mcu_dout;
    end else begin
        ram_udin = cpu_dout[15:8];
        ram_ldin = cpu_dout[ 7:0];
    end
end

/////////////////////////////////////////////////////
// MCU DMA data output mux
always @(posedge clk) begin
    mcu_din <= mcu_ram_cs ? wram_dout[7:0] : 8'hff;
end

/////////////////////////////////////////////////////
// Work RAM, 16kB
reg [13:1]  work_A;
reg         work_uwe, work_lwe;
reg         ram_cen;

always @(*) begin
    if( mcu_ram_cs ) begin
        // MCU access
        work_A   = mcu_addr[13:1];
        work_uwe = 1'b0;
        work_lwe = mcu_wr;
        ram_cen  = mcu_cen;
    end else begin
        // CPU access
        work_A   = A[13:1];
        work_uwe = ram_cs & !UDSWn;
        work_lwe = ram_cs & !LDSWn;
        ram_cen  = cpu_cen;
    end
end

jtframe_ram #(.aw(13),.cen_rd(1)) u_ramu(
    .clk        ( clk              ),
    .cen        ( ram_cen          ),
    .addr       ( work_A           ),
    .data       ( ram_udin         ),
    .we         ( work_uwe         ),
    .q          ( wram_dout[15:8]  )
);

jtframe_ram #(.aw(13),.cen_rd(1)) u_raml( // cen_rd must be set for proper MCU access
    .clk        ( clk              ),
    .cen        ( ram_cen          ),
    .addr       ( work_A           ),
    .data       ( ram_ldin         ),
    .we         ( work_lwe         ),
    .q          ( wram_dout[7:0]   )
);

/////////////////////////////////////////////////////
// Object RAM, 4kB
assign cpu_AB = A[13:1];
reg [10:0] oram_addr;
reg  obj_uwe, obj_lwe;

always @(*) begin
    if( blcnten) begin // Object DMA
        oram_addr = obj_AB[11:1];
        obj_uwe   = 1'b0;
        obj_lwe   = 1'b0;
    end else begin
        oram_addr = A[11:1];
        obj_uwe   = obj_cs & !UDSWn;
        obj_lwe   = obj_cs & !LDSWn;
    end
end

jtframe_ram #(.aw(11),.cen_rd(0)) u_obj_ramu(
    .clk        ( clk              ),
    .cen        ( ram_cen          ),
    .addr       ( oram_addr        ),
    .data       ( ram_udin         ),
    .we         ( obj_uwe          ),
    .q          ( oram_dout[15:8]  )
);

jtframe_ram #(.aw(11),.cen_rd(0)) u_obj_raml(
    .clk        ( clk              ),
    .cen        ( ram_cen          ),
    .addr       ( oram_addr        ),
    .data       ( ram_ldin         ),
    .we         ( obj_lwe          ),
    .q          ( oram_dout[7:0]   )
);

// Cabinet input
reg [15:0] cabinet_input;

always @(posedge clk) if(cpu_cen) begin
    case( A[2:1] )
        2'b00: cabinet_input <= {
            2'b11, joystick2[5:0],
            2'b11, joystick1[5:0] };
        2'b01: cabinet_input <=
            { coin_input,
                service, // just a guess
                2'b11,
                ~LVBL, start_button, 8'hff };
        2'b10: cabinet_input <= { dipsw_a, dipsw_b };
    endcase
end

// Data bus input
reg  [15:0] cpu_din;
reg  [ 7:0] video_dout;
reg  [15:0] owram_dout;
wire        owram_cs = obj_cs | ram_cs;

always @(posedge clk) begin
    owram_dout <= obj_cs ? oram_dout : wram_dout;
end

always @(*)
    case( {owram_cs, char_cs, io_cs} )
        3'b100:  cpu_din = owram_dout;
        3'b010:  cpu_din = char_dout;
        3'b001:  cpu_din = cabinet_input;
        default: cpu_din = rom_data;
    endcase

assign rom_addr = A[17:1];

// DTACKn generation
wire       inta_n;
(*keep*) wire       bus_cs =   |{ rom_cs, char_cs };
(*keep*) wire       bus_busy = |{ rom_cs & ~rom_ok, char_busy };
wire DTACKn;
wire BUSn = ASn | (LDSn & UDSn);

jtframe_68kdtack u_dtack( // 24 -> 10MHz
    .rst        ( rst       ),
    .clk        ( clk       ),
    .num        ( 4'd5      ),
    .den        ( 4'd12     ),
    .cpu_cen    ( cen10     ),
    .cpu_cenb   ( cen10b    ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( char_busy ),
    .BUSn       ( BUSn      ),   // BUSn = ASn | (LDSn & UDSn)
    .DTACKn     ( DTACKn    )
);

/*
(*keep*) reg DTACKn;

always @(posedge clk, posedge rst) begin : dtack_gen
    reg       last_ASn;
    if( rst ) begin
        DTACKn <= 1'b1;
    end else if(cen10b) begin
        DTACKn   <= 1'b1;
        last_ASn <= ASn;
        if( !ASn  ) begin
            if( bus_cs ) begin
                if (!bus_busy) DTACKn <= 1'b0;
            end
            else DTACKn <= 1'b0;
        end
        if( ASn && !last_ASn ) DTACKn <= 1'b1;
    end
end
*/

// interrupt generation
reg        int1, int2;
wire [2:0] FC;
assign inta_n = ~&{ FC[2], FC[1], FC[0], ~ASn }; // interrupt ack.

always @(posedge clk, posedge rst) begin : int_gen
    reg last_LVBL, last_V256;
    if( rst ) begin
        int1 <= 1'b1;
        int2 <= 1'b1;
    end else begin
        last_LVBL <= LVBL;
        last_V256 <= V[8];

        if( !inta_n ) begin
            int1 <= 1'b1;
            int2 <= 1'b1;
        end
        else if(dip_pause) begin
            if( V[8] && !last_V256 ) int2 <= 1'b0;
            if( !LVBL && last_LVBL ) int1 <= 1'b0;
        end
    end
end

(*keep*) wire [1:0] dev_br = { ~mcu_brn, obj_br };
assign bus_ack = ~BGACKn;

// reg cen10dly, cen10bdly;
// always @(posedge clk) {cen10dly, cen10bdly} <= {cen10, cen10b};

jtframe_68kdma #(.BW(2)) u_arbitration(
    .clk        (  clk          ),
    .rst        (  rst          ),
    .cen        ( cen10b        ),
    .cpu_BRn    (  BRn          ),
    .cpu_BGACKn (  BGACKn       ),
    .cpu_BGn    (  BGn          ),
    .cpu_ASn    (  ASn          ),
    .cpu_DTACKn (  DTACKn       ),
    .dev_br     (  dev_br       )
);

fx68k u_cpu(
    .clk        ( clk         ),
    .extReset   ( rst         ),
    .pwrUp      ( rst         ),
    .enPhi1     ( cen10       ),
    .enPhi2     ( cen10b      ),
    .HALTn      ( 1'b1        ),

    // Buses
    .eab        ( { ncA, A }  ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),


    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( inta_n      ),
    .FC0        ( FC[0]       ),
    .FC1        ( FC[1]       ),
    .FC2        ( FC[2]       ),

    .BERRn      ( BERRn       ),
    // Bus arbitrion
    .BRn        ( BRn         ),
    .BGACKn     ( BGACKn      ),
    .BGn        ( BGn         ),

    .DTACKn     ( DTACKn      ),
    .IPL0n      ( 1'b1        ),
    .IPL1n      ( int1        ),
    .IPL2n      ( int2        ),

    // Unused
    .oRESETn    (             ),
    .oHALTEDn   (             ),
    .VMAn       (             ),
    .E          (             )
);

endmodule