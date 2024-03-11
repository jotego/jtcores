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
    Date: 27-10-2017 */

// This module is equivalent to the function
// of CAPCOM's 85H001 package found in GunSmoke, GnG, etc.
// when using LAYOUT 0

// watch points for MAME:
// wpset e000,1,w,1,{printf "reg = %X", wpdata;g}
// wpset e001,1,w,1,{printf "val = %X", wpdata;g}

module jtgng_sound(
    input            rst,
    input            clk,
    input            cen3,   //  3   MHz
    input            cen1p5, //  1.5 MHz
    // Interface with main CPU
    input            sres_b, // Z80 reset
    input   [7:0]    snd_latch,
    input            snd_int,
    // Interface with second sound CPU (Tiger Road)
    output reg [7:0] snd2_latch,
    // Interface with MCU (F1 Dream)
    // input   [7:0]    snd_din,
    // output  [7:0]    snd_dout,
    // output           snd_mcu_wr,
    // ROM
    output  [14:0]   rom_addr,
    output  reg      rom_cs,
    input   [ 7:0]   rom_data,
    input            rom_ok,

    // Sound output
    output signed [15:0] fm0, fm1,
    output        [ 9:0] psg0, psg1,

    // Debug
    input      [ 7:0] debug_bus,
    output reg [ 7:0] debug_view
);
parameter       LAYOUT=0;
`ifndef NOSOUND
    // 0 GnG, most games
    // 1 Commando:
    //      -Smaller ROM
    // 3 Tiger Road/F1-Dream:
    //      -Can readback from FM chip
    //      -IRQ controlled by FM chips
    //      -FM clock speed same as CPU
    // 4 Black Tiger
    //      -Can readback from FM chip
    //      -IRQ controlled by FM chips
    //      -FM clock speed same as CPU
    //      -CPU memory map same as GnG
    // 8 Side Arms:
    //      -Can readback from FM chip
    //      -IRQ controlled by FM chips
    //      -FM clock speed same as CPU
    //      -Different memory map from Tiger Road
    // 10 The Speed Rumbler
    //      -Can readback from FM chip
    //      -IRQ controlled by FM chips
    //      -FM clock speed same as CPU

localparam IRQ_FM     = LAYOUT==3 || LAYOUT==4 || LAYOUT==8 || LAYOUT==10;
localparam READ_FM    = LAYOUT==3 || LAYOUT==4 || LAYOUT==8 || LAYOUT==10;
localparam FM_SAMECEN = LAYOUT==3 || LAYOUT==4 || LAYOUT==8 || LAYOUT==10;

wire [15:0] A, fave;
wire        iorq_n, m1_n, wr_n, rd_n, cenfm;
wire [ 7:0] ram_dout, dout, fm0_dout, fm1_dout;
reg         fm1_cs, fm0_cs, latch_cs, ram_cs;
wire        mreq_n, rfsh_n;
wire [ 7:0] fm0_debug, fm1_debug;

assign rom_addr = A[14:0];
assign cenfm    = FM_SAMECEN ? cen3 : cen1p5;
// assign snd_dout   = dout;
// assign snd_mcu_wr = 1'b0;

always @* begin
    case( debug_bus[7:6] )
        1: debug_view = fave[ 7:0];
        3,2: debug_view = fave[15:8];
        default: debug_view ={ fm1_debug[3:0], fm0_debug[3:0] };
    endcase
end

always @(*) begin
    rom_cs   = 1'b0;
    ram_cs   = 1'b0;
    latch_cs = 1'b0;
    fm0_cs   = 1'b0;
    fm1_cs   = 1'b0;
    if( rfsh_n && !mreq_n)
        case( LAYOUT )
        0,4:  // Memory map for: GnG, Gun Smoke, 1943, Black Tiger, SectionZ
            casez(A[15:13])
                3'b0??: rom_cs   = 1'b1;
                3'b110: if(A[11])
                            latch_cs = 1'b1;
                        else
                            ram_cs   = 1'b1;
                        // 1943 has the security device mapped at A[12:11]==2'b11
                        // but it doesn't use it at all. So I am leaving it out.
                3'b111: begin
                    fm0_cs = ~A[1];
                    fm1_cs =  A[1];
                end
                default:;
            endcase
        1:  // Memory map for Commando
            casez(A[15:13])
                3'b00?: rom_cs   = 1'b1;
                3'b010: ram_cs   = 1'b1;
                3'b011: latch_cs = 1'b1;
                3'b100: begin
                    fm0_cs = ~A[1];
                    fm1_cs =  A[1];
                end
                default:;
            endcase
        3, 10: // Tiger Road, The Speed Rumbler
            casez(A[15:13])
                3'b0??: rom_cs   = 1'b1;
                3'b100: fm0_cs   = 1'b1;
                3'b101: fm1_cs   = 1'b1;
                3'b110: ram_cs   = 1'b1;
                3'b111: latch_cs = 1'b1;
                default:;
            endcase
        8: // Side Arms
            casez(A[15:12])
                4'b0???: rom_cs   = 1'b1;
                4'b1100: ram_cs   = 1'b1;
                4'b1101: latch_cs = 1'b1;
                4'b1111: begin
                    fm0_cs   = ~A[1];
                    fm1_cs   =  A[1];
                end
                default:;
            endcase
        `ifdef SIMULATION
        default: begin
            $display("ERROR: Wrong sound layout");
            $finish;
        end
        `endif
        endcase
end

// only used in games with ADPCM Z80
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd2_latch <= 8'd0;
    end else begin
        if( !iorq_n && !wr_n && !A[8]) snd2_latch <= dout;
    end
end

wire intn_fm0, intn_fm1;

wire RAM_we = ram_cs && !wr_n;

// `define SIM_SND_RAM ,.SIMFILE("snd_ram.hex")
`ifndef SIM_SND_RAM
`define SIM_SND_RAM
`endif

jtframe_ram #(
    .AW(11)
    `SIM_SND_RAM
) u_ram(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( dout     ),
    .addr   ( A[10:0]  ),
    .we     ( RAM_we   ),
    .q      ( ram_dout )
);

reg [7:0] din;

// Only some layouts can read the status register
// from FM chips:
wire fm0_mx = fm0_cs && READ_FM;
wire fm1_mx = fm1_cs && READ_FM;

always @(posedge clk) begin
    case( 1'b1 )
        rom_cs:   din = rom_data;
        fm0_mx:   din = fm0_dout;
        fm1_mx:   din = fm1_dout;
        latch_cs: din = snd_latch;
        ram_cs:   din = ram_dout;
        default:  din = 8'hff;
    endcase
end

reg reset_n=1'b0;
reg int_n;

generate
    if( IRQ_FM ) begin
        // Interrupt directly generated by the FM chip
        always @(*) int_n = intn_fm0;
    end else begin : irq_latch
        // posedge of snd_int
        reg snd_int_last;
        wire snd_int_edge = !snd_int_last && snd_int;
        always @(posedge clk) if(cen3) begin
            snd_int_last <= snd_int;
        end
        // interrupt latch
        wire irq_ack = !iorq_n && !m1_n;

        always @(posedge clk or negedge reset_n)
            if( !reset_n ) int_n <= 1'b1;
            else if(cen3) begin
                if(irq_ack) int_n <= 1'b1;
                else if( snd_int_edge ) int_n <= 1'b0;
            end
    end
endgenerate

// local reset
reg [3:0] rst_cnt;

always @(negedge clk)
    if( rst | ~sres_b ) begin
        rst_cnt <= 'd0;
        reset_n <= 1'b0;
    end else begin
        if( rst_cnt != ~4'b0 ) begin
            reset_n <= 1'b0;
            rst_cnt <= rst_cnt + 4'd1;
        end else reset_n <= 1'b1;
    end

// Wait_n generation

reg [1:0] fm_wait;
reg wait_n;
wire fmx_cs = fm0_cs|fm1_cs;
reg last_fmx_cs;
wire fmx_cs_posedge = !last_fmx_cs && fmx_cs;
wire fm_lock = |fm_wait;

always @(posedge clk or negedge reset_n)
    if( !reset_n ) begin
        fm_wait  <= 2'b11;
    end else if(cen3) begin
        last_fmx_cs <= fmx_cs;
        fm_wait  <= {  fm_wait[0], fmx_cs_posedge };
    end

reg last_rom_cs, rom_lock;

always @(posedge clk or negedge reset_n) begin
    if( !reset_n )
        wait_n <= 1'b1;
    else begin
        last_rom_cs <= rom_cs;
        if( rom_cs && !last_rom_cs ) rom_lock <= 1'b1;
        if( rom_ok ) rom_lock <= 1'b0;
        wait_n <= !fm_lock && !rom_lock;
    end
end

jtframe_z80 u_cpu(
    .rst_n      ( reset_n     ),
    .clk        ( clk         ),
    .cen        ( cen3        ),
    .wait_n     ( wait_n      ),
    .int_n      ( int_n       ),
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .din        ( din         ),
    .dout       ( dout        )
);

jtframe_freqinfo #(
    .KHZ   (        0 ),
    .MFREQ (   24_000 )
) u_freqinfo(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .pulse  ( int_n ),
    .fave   ( fave  ),
    .fworst (       )
);

jt03 u_fm0(
    .rst    ( ~reset_n  ),
    // CPU interface
    .clk    ( clk        ),
    .cen    ( cenfm      ),
    .din    ( dout       ),
    .addr   ( A[0]       ),
    .cs_n   ( ~fm0_cs    ),
    .wr_n   ( wr_n       ),
    .psg_snd( psg0       ),
    .fm_snd ( fm0        ),
    .snd_sample (        ),
    .dout   ( fm0_dout   ),
    .irq_n  ( intn_fm0   ),
    // unused ports
    .IOA_in (            ),
    .IOB_in (            ),
    .IOA_out(            ),
    .IOB_out(            ),
    .IOA_oe (            ),
    .IOB_oe (            ),
    .psg_A  (            ),
    .psg_B  (            ),
    .psg_C  (            ),
    .snd    (            ),
    //.debug_bus ( debug_bus ),
    .debug_view( fm0_debug )
);

jt03 u_fm1(
    .rst    ( ~reset_n   ),
    // CPU interface
    .clk    ( clk        ),
    .cen    ( cenfm      ),
    .din    ( dout       ),
    .addr   ( A[0]       ),
    .cs_n   ( ~fm1_cs    ),
    .wr_n   ( wr_n       ),
    .psg_snd( psg1       ),
    .fm_snd ( fm1        ),
    .dout   ( fm1_dout   ),
    .irq_n  ( intn_fm1   ),
    // unused ports
    .IOA_in (            ),
    .IOB_in (            ),
    .IOA_out(            ),
    .IOB_out(            ),
    .IOA_oe (            ),
    .IOB_oe (            ),
    .psg_A  (            ),
    .psg_B  (            ),
    .psg_C  (            ),
    .snd    (            ),
    .snd_sample(         ),
    //.debug_bus ( debug_bus ),
    .debug_view( fm1_debug )
);
`else
    initial snd2_latch = 0;
    initial debug_view = 0;
    initial rom_cs     = 0;
    assign  rom_addr   = 0;
    assign  fm0        = 0;
    assign  fm1        = 0;
    assign  psg0       = 0;
    assign  psg1       = 0;
`endif
endmodule // jtgng_sound