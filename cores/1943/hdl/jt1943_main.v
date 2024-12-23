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
    Date: 18-2-2019
    Version: 2.0
    Date:  8-8-2020 (added Side Arms support)
    */

// GAME = 0 1943        (default)
// GAME = 1 Side Arms

// 1943 uses the waitn signal for bus arbitrion and for slowing down the CPU
// Side Arms, gates the clock for bus arbitrion and uses waitn to slow down the CPU
// in the same way as 1943
// This CPU slow down must be to meet memory timings
// I use waitn signal for bus arbitrion for both games for convenience

module jt1943_main #(
    parameter GAME=0 // 0=1943, 1=Side Arms
)(
    input              clk,
    input              cpu_cen,   // 6MHz or 4MHz
    input              rst,
    // Timing
    output  reg        flip,
    input   [8:0]      V,
    input              LVBL,
    // Sound
    output  reg        sres_b, // sound reset
    output  reg [7:0]  snd_latch,
    // Characters
    input              [7:0] char_dout,
    output             [7:0] cpu_dout,
    output  reg        char_cs,
    output  reg        CHON,    // 1 enables character output
    input              char_wait,
    // scroll
    output  reg [(GAME ? 15 : 7):0]  scrposv,
    output  reg [15:0] scr1posh,
    output  reg [15:0] scr2posh,
    output  reg        SC1ON,
    output  reg        SC2ON,
    output  reg        OBJON,
    // Palette (only Side Arms)
    output  reg        blue_cs,
    output  reg        redgreen_cs,
    output  reg        eres_n,
    input              wrerr_n,
    // cabinet I/O
    input   [6:0]      joystick1,
    input   [6:0]      joystick2,
    input   [1:0]      cab_1p,
    input   [1:0]      coin,
    input              service,
    // BUS sharing
    output  [12:0]     cpu_AB,
    output  [ 7:0]     ram_dout,
    input   [12:0]     obj_AB,
    output             rd_n,
    output             wr_n,
    output  reg        OKOUT,
    input              bus_req,  // Request bus
    output             bus_ack,  // bus acknowledge
    input              blcnten,  // bus line counter enable
    // ROM access
    output  reg        rom_cs,
    output  reg [17:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,
    // DIP switches
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b,
    input    [7:0]     dipsw_c,
    input              dip_pause,
    output reg         coin_cnt
);

localparam CHON_BIT  = GAME==0 ? 7 : 6;
localparam FLIP_BIT  = GAME==0 ? 6 : 7;
localparam SRES_BIT  = GAME==0 ? 5 : 4;
localparam BANK_BIT1 = GAME==0 ? 4 : 2;
localparam BANK_BIT0 = GAME==0 ? 2 : 0;
localparam BANKW     = 3;

wire [15:0] A;
wire t80_rst_n;
reg in_cs, ram_cs, bank_cs, scrposv_cs, gfxen_cs, snd_latch_cs;
reg misc_cs, star_cs;
reg SECWR_cs;
reg [1:0]  scr1posh_cs, scr2posh_cs;

// special registers
reg [BANKW-1:0] bank;

wire mreq_n, rfsh_n, busak_n;
assign bus_ack = ~busak_n;

reg banked_cs;

always @(*) begin
    banked_cs     = !mreq_n && rfsh_n && A[15:14]==2'b10;
    rom_cs        = (!mreq_n && rfsh_n && !A[15]) || banked_cs;
    ram_cs        = !mreq_n && rfsh_n && A[15:13]==3'b111;
    snd_latch_cs  = 0;
    bank_cs       = 0;
    in_cs         = 0;
    char_cs       = !mreq_n && rfsh_n && A[15:12]==4'hd && (GAME==1 || !A[11]);
    scr1posh_cs   = 2'b0;
    scr2posh_cs   = 2'b0;
    scrposv_cs    = 0;
    gfxen_cs      = 0;
    OKOUT         = 0;
    SECWR_cs      = 0;
    blue_cs       = 0;
    redgreen_cs   = 0;
    misc_cs       = 0;
    star_cs       = 0;
    eres_n        = 1;
    if( rfsh_n && !mreq_n && A[15:13]==3'b110 /* CSCD */ ) begin
        if( GAME==0 ) begin // 1943
            case(A[12:11])
                2'b00: // 0xC000 part 11B
                    in_cs = 1'b1;
                2'b01: // 0xC800
                    casez(A[2:0])
                        3'b000: snd_latch_cs = 1'b1;
                        3'b100: begin
                            bank_cs = 1;
                            misc_cs = 1;
                        end
                        3'b110: OKOUT        = 1'b1;
                        3'b111: SECWR_cs     = 1'b1;
                        default:;
                    endcase
                2'b10: // D0CS (D phi CS on schematics)
                    char_cs = 1'b1; // D0CS
                2'b11: // D8CS
                    if( !A[3] && !wr_n) case(A[2:0])
                        3'd0: scr1posh_cs = 2'b01; // LSB
                        3'd1: scr1posh_cs = 2'b10; // MSB
                        3'd2: scrposv_cs  = 1'b1;
                        3'd3: scr2posh_cs = 2'b01; // LSB
                        3'd4: scr2posh_cs = 2'b10; // MSB
                        3'd6: gfxen_cs    = 1'b1;
                        default:;
                    endcase
                default:;
            endcase
        end else begin // Side Arms
            casez(A[12:11])
                2'b00: begin // 0xC000
                    redgreen_cs = !A[10];
                    blue_cs     =  A[10];
                end
                2'b01: begin // 0xC800
                    if( !wr_n ) begin
                        casez(A[3:0])
                            4'd0: snd_latch_cs  = 1;
                            4'd1: bank_cs       = 1;
                            4'd2: OKOUT         = 1;
                            4'd3: eres_n        = 0;
                            4'd4: misc_cs       = 1;
                            4'd5, 4'd6: star_cs = 1;
                            4'd8: scr1posh_cs = 2'b01; // LSB
                            4'd9: scr1posh_cs = 2'b10; // MSB
                            4'd10,4'd11: scrposv_cs  = 1'b1;
                            4'd12: gfxen_cs    = 1'b1;
                            default:;
                        endcase
                    end
                    in_cs = !rd_n;
                end
                default:;
            endcase
        end
    end
end

always @(posedge clk, posedge rst)
    if( rst ) begin
        bank      <= {BANKW{1'b0}};
        scr1posh  <= 16'd0;
        scr2posh  <= 16'd0;
        scrposv   <= 0;
        flip      <= 0;
        sres_b    <= 1;
        coin_cnt  <= 1;  // omitting inverter in M54532 for coin counter.
        {OBJON, SC2ON, SC1ON, CHON } <= 4'd0;
        snd_latch <= 8'd0;
    end
    else if(cpu_cen) begin
        if( bank_cs && !wr_n ) begin
            bank     <= cpu_dout[BANK_BIT1:BANK_BIT0];
            `ifdef SIMULATION
                if(cpu_dout[BANK_BIT1:BANK_BIT0]!=bank)
                    $display("INFO: Bank changed to %d", cpu_dout[4:2]);
            `endif
        end
        if( misc_cs  && !wr_n ) begin
            CHON     <= cpu_dout[CHON_BIT];
            flip     <= cpu_dout[FLIP_BIT];
            if( GAME==1 ) SC2ON <= cpu_dout[5]; // Star on signal for Side Arms
            sres_b   <= ~cpu_dout[SRES_BIT]; // inverted through M54532
            coin_cnt <= |cpu_dout[1:0];
            `ifdef SIMULATION
                if (!cpu_dout[SRES_BIT])
                    $display("INFO: Sound CPU reset");
            `endif
        end
        if( snd_latch_cs && !wr_n ) snd_latch <= cpu_dout;
        if( scrposv_cs ) begin
            if(GAME==0) scrposv[7:0] <= cpu_dout[7:0];
            if(GAME==1) begin
                if( !A[0] ) scrposv[ 7:0] <= cpu_dout;
                /* verilator lint_off SELRANGE */
                if(  A[0] ) scrposv[15:8] <= cpu_dout;
                /* verilator lint_on SELRANGE */
            end
        end
        if( scr1posh_cs[0] )  scr1posh[ 7:0] <= cpu_dout;
        if( scr1posh_cs[1] )  scr1posh[15:8] <= cpu_dout;
        if( GAME==0 ) begin
            if( scr2posh_cs[0] )  scr2posh[ 7:0] <= cpu_dout;
            if( scr2posh_cs[1] )  scr2posh[15:8] <= cpu_dout;
        end else begin
            if( star_cs && !wr_n ) begin
                scr2posh[0] <= !A[0];
                scr2posh[1] <=  A[0];
            end else begin
                scr2posh <= 16'd0;
            end
        end
        if( gfxen_cs ) begin
            if(GAME==0)
                {OBJON, SC2ON, SC1ON } <= cpu_dout[6:4];
            else
                {SC1ON, OBJON} <= cpu_dout[1:0];
        end
    end

jt12_rst u_rst(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .rst_n  ( t80_rst_n )
);

reg [7:0] cabinet_input;
wire [7:0] security;

always @(*) begin
    case( A[2:0] )
        3'd0: cabinet_input = { coin, // COINS
                     service, 1'b1 /* tilt */, // undocumented. D5 & D4 what are those?
                            // service and tilt in Side Arms
                     ~LVBL,
                     GAME==1 ? wrerr_n : 1'b1, // /WRERR - palette write error (Side Arms)
                     cab_1p }; // START
        3'd1: cabinet_input = { 1'b1, joystick1 };
        3'd2: cabinet_input = { 1'b1, joystick2 };
        3'd3: cabinet_input = dipsw_a;
        3'd4: cabinet_input = dipsw_b;
        3'd5: cabinet_input = GAME==1 ? dipsw_c  : 8'hff;
        3'd7: cabinet_input = GAME==0 ? security : 8'hff;
        default: cabinet_input = 8'hff;
    endcase
end


// RAM, 16kB
wire cpu_ram_we = ram_cs && !wr_n;
assign cpu_AB = A[12:0];

wire [12:0] RAM_addr = blcnten ? obj_AB : cpu_AB;
wire RAM_we   = blcnten ? 1'b0 : cpu_ram_we;

jtframe_ram #(.AW(13),.CEN_RD(0)) RAM(
    .clk        ( clk       ),
    .cen        ( cpu_cen   ),
    .addr       ( RAM_addr  ),
    .data       ( cpu_dout  ),
    .we         ( RAM_we    ),
    .q          ( ram_dout  )
);

// Data bus input
reg [7:0] cpu_din;
wire iorq_n, m1_n;
wire irq_ack = !iorq_n && !m1_n;

always @(*)
    case( {ram_cs, char_cs, rom_cs, in_cs} )
        4'b10_00: cpu_din = ram_dout;
        4'b01_00: cpu_din = char_dout;
        4'b00_10: cpu_din = rom_data;
        4'b00_01: cpu_din = cabinet_input;
        default:  cpu_din = rom_data;
    endcase

`ifdef SIMULATION
always @(negedge rd_n)
    if( in_cs && A[2:0]=='d7 ) $display("INFO: Security code read %m ");
`endif

// ROM ADDRESS: 32kB + 8 banks of 16kB
always @(*) begin
    rom_addr[13: 0] = A[13:0];
    rom_addr[17:14] = !A[15] ? { 3'b0, A[14] } : ( 4'b0010 + { 1'b0, bank});
end

///////////////////////////////////////////////////////////////////
// interrupt generation. Schematics page 5/9, parts 12J and 14K (1943)
// schematics page 1/9 and timing (Side Arms)
reg int_n, int_rqb, int_rqb_last;
wire int_middle = V[7:5]!=3'd3;
wire int_rqb_edge = GAME==0 ?
                        (!int_rqb &&  int_rqb_last) : // 1943: Neg edge
                        ( int_rqb && !int_rqb_last);  // Side Arms: Pos edge

always @(posedge clk)
    if(rst) begin
        int_n <= 1'b1;
    end else if(cpu_cen) begin
        int_rqb_last <= int_rqb;
        if( GAME==0 )
            int_rqb <= LVBL && int_middle;
        else begin
            if( V[7:0]==8'h6F || V[7:0]==8'hEF ) int_rqb <= 0;
            if( V[7:0]==8'h70 || V[7:0]==8'hF0 ) int_rqb <= 1;
        end
        if( irq_ack )
            int_n <= 1'b1;
        else
            if ( int_rqb_edge && dip_pause ) int_n <= 1'b0;
    end

/////////////////////////////////////////////////////////////////
// wait_n generation
reg [1:0] mem_wait_n;
reg wait_n;
reg last_rom_cs;
wire rom_cs_posedge = !last_rom_cs && rom_cs;

reg char_free, rom_free, mem_free;
reg char_clr, rom_clr, mem_clr;
always @(*) begin
    char_clr = !char_free || (!char_wait     && char_free);
    rom_clr  = !rom_free  || ( rom_ok        && rom_free );
    mem_clr  = !mem_free  || ( mem_wait_n[0] && mem_free );
end

always @(posedge clk or negedge t80_rst_n)
    if( !t80_rst_n ) begin
        wait_n <= 1'b1;
        mem_wait_n[0] <= 1'b1;
        char_free <= 1'b0;
        rom_free  <= 1'b0;
        mem_free  <= 1'b0;
    end else begin
        last_rom_cs <= rom_cs;
        if(cpu_cen) begin
            mem_wait_n[0] <= !mem_wait_n[1] ? 1'b1 : m1_n; // & mreq_n; // mreq_n
            mem_wait_n[1] <= mem_wait_n[0];
        end
        if( (char_wait&&char_cs) || rom_cs_posedge || !mem_wait_n[0]) begin
            // The PCB has a slow down mechanism for the main CPU
            // it loses one clock cycle at the beginning of every machine cycle
            if( char_wait&&char_cs ) char_free <= 1'b1;
            if( rom_cs_posedge ) rom_free  <= 1'b1;
            if( !mem_wait_n[0] ) mem_free  <= 1'b1;
            wait_n <= 1'b0;
        end
        else begin
            wait_n    <= char_clr & rom_clr & mem_clr;
            rom_free  <= !rom_clr;
            char_free <= !char_clr;
            mem_free  <= !mem_clr;
        end
    end

generate
    if( GAME==0 )
    jt1943_security u_security(
        .clk    ( clk      ),
        .cen    ( cpu_cen  ),
        .wr_n   ( wr_n     ),
        .cs     ( SECWR_cs ),
        .din    ( cpu_dout ),
        .dout   ( security )
    );
    else assign security = 8'd0;
endgenerate

jtframe_z80 u_cpu(
    .rst_n      ( t80_rst_n   ),
    .clk        ( clk         ),
    .cen        ( cpu_cen     ),
    .wait_n     ( wait_n      ),
    .int_n      ( int_n       ),
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( ~bus_req    ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    ( busak_n     ),
    .A          ( A           ),
    .din        ( cpu_din     ),
    .dout       ( cpu_dout    )
);

endmodule