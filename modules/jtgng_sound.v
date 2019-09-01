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

module jtgng_sound(
    input           rst,
    input           clk,
    input           cen3,   //  3   MHz
    input           cen1p5, //  1.5 MHz
    // Interface with main CPU
    input           sres_b, // Z80 reset
    input   [7:0]   snd_latch,
    input           snd_int,
    // Sound control
    input           enable_psg,
    input           enable_fm,
    input   [7:0]   psg_gain,
    // ROM
    output  [14:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,

    // Sound output
    output  signed [15:0] ym_snd,
    output  sample
);

parameter       BIGROM=1;
parameter [7:0] FM_GAIN=8'h20;

wire [15:0] A;
assign rom_addr = A[14:0];

reg fm1_cs,fm0_cs, latch_cs, ram_cs;
// reg [4:0] map_cs;
// 
// assign { rom_cs, fm1_cs, fm0_cs, latch_cs, ram_cs } = map_cs;
// 
// reg [7:0] AH;
// 
// always @(*)
//     casez(A[15:11])
//         5'b0???_?: map_cs = 5'h10; // 0000-7FFF, ROM
//         5'b1100_0: map_cs = 5'h1;  // C000-C7FF, RAM
//         5'b1100_1: map_cs = 5'h2;  // C800-C8FF, Sound latch
//         5'b1110_0: map_cs = A[1] ? 5'h8 : 5'h4; // E000-E0FF, Yamaha
//         default: map_cs = 5'h0;
//     endcase

wire mreq_n, rfsh_n;

always @(*) begin
    rom_cs   = 1'b0;
    ram_cs   = 1'b0;
    latch_cs = 1'b0;
    fm0_cs   = 1'b0;
    fm1_cs   = 1'b0;
    if( rfsh_n && !mreq_n) 
        if( BIGROM ) begin
            // Memory map for: GnG, Gun Smoke, 1943
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
        end else begin
            // Memory map for Commando
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
        end
end


wire rd_n;
wire wr_n;

wire RAM_we = ram_cs && !wr_n;
wire [7:0] ram_dout, dout;

jtgng_ram #(.aw(11),.simfile("snd_ram.hex")) u_ram(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( dout     ),
    .addr   ( A[10:0]  ),
    .we     ( RAM_we   ),
    .q      ( ram_dout )
);

reg [7:0] din;

always @(*)
    case( 1'b1 )
        // Real hardware cannot read data from FM chips:
        // fm1_cs:   din = fm1_dout;
        // fm0_cs:   din = fm0_dout;
        latch_cs: din = snd_latch;
        ram_cs:   din = ram_dout;
        default:  din = rom_data;
    endcase // {latch_cs,rom_cs,ram_cs}

// posedge of snd_int
reg snd_int_last;
wire snd_int_edge = !snd_int_last && snd_int;
always @(posedge clk) if(cen3) begin
    snd_int_last <= snd_int;
end

reg reset_n=1'b0;

// interrupt latch
reg int_n;
wire iorq_n;
always @(posedge clk or negedge reset_n)
    if( !reset_n ) int_n <= 1'b1;
    else if(cen3) begin
        if(!iorq_n) int_n <= 1'b1;
        else if( snd_int_edge ) int_n <= 1'b0;
    end

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
        fm_wait  <= {  fm_wait[0], fmx_cs_posedge };
    end // else if(cen3)

reg last_rom_cs, rom_lock;

always @(posedge clk or negedge reset_n)
    if( !reset_n )
        wait_n <= 1'b1;
    else begin
        last_fmx_cs <= fmx_cs;
        last_rom_cs <= rom_cs;
        if( rom_cs && !last_rom_cs ) rom_lock <= 1'b1;
        if( rom_ok ) rom_lock <= 1'b0;
        wait_n <= !fm_lock && !rom_lock;
    end

jtframe_z80 u_cpu(
    .rst_n      ( reset_n     ),
    .clk        ( clk         ),
    .cen        ( cen3        ),
    .wait_n     ( wait_n      ),
    .int_n      ( int_n       ),
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( 1'b1        ),
    .m1_n       (             ),
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

wire signed [15:0] fm0_snd,  fm1_snd;
wire        [ 9:0] psg0_snd, psg1_snd;
wire        [10:0] psg01 = {1'b0,psg0_snd} + {1'b0,psg1_snd};
// wire signed [15:0]
//     psg0_signed = {1'b0, psg0_snd, 4'b0 },
//     psg1_signed = {1'b0, psg1_snd, 4'b0 };

wire signed [10:0] psg2x; // DC-removed version of psg01

jt49_dcrm2 #(.sw(11)) u_dcrm (
    .clk    (  clk    ),
    .cen    (  cen1p5 ),
    .rst    (  rst    ),
    .din    (  psg01  ),
    .dout   (  psg2x  )
);

wire signed [7:0] psg_gain2 = enable_psg ? psg_gain : 8'h0;
wire signed [7:0]  fm_gain2 = enable_fm  ?  FM_GAIN : 8'h0;

jt12_mixer #(.w0(16),.w1(16),.w2(15),.w3(8),.wout(16)) u_mixer(
    .clk    ( clk          ),
    .cen    ( cen1p5       ),
    .ch0    ( fm0_snd      ),
    .ch1    ( fm1_snd      ),
    .ch2    ( {psg2x, 4'b0}),
    .ch3    ( 8'd0         ),
    .gain0  ( fm_gain2     ),
    .gain1  ( fm_gain2     ),
    .gain2  ( psg_gain2    ),
    .gain3  ( 8'd0         ),
    .mixed  ( ym_snd       )
);

jt03 u_fm0(
    .rst    ( ~reset_n  ),
    // CPU interface
    .clk    ( clk        ),
    .cen    ( cen1p5     ),
    .din    ( dout       ),
    .addr   ( A[0]       ),
    .cs_n   ( ~fm0_cs    ),
    .wr_n   ( wr_n       ),
    .psg_snd( psg0_snd   ),
    .fm_snd ( fm0_snd    ),
    .snd_sample ( sample ),
    // unused outputs
    .dout   (),
    .irq_n  (),
    .psg_A  (),
    .psg_B  (),
    .psg_C  (),
    .snd    ()
);

jt03 u_fm1(
    .rst    ( ~reset_n  ),
    // CPU interface
    .clk    ( clk       ),
    .cen    ( cen1p5    ),
    .din    ( dout      ),
    .addr   ( A[0]      ),
    .cs_n   ( ~fm1_cs   ),
    .wr_n   ( wr_n      ),
    .psg_snd( psg1_snd  ),
    .fm_snd ( fm1_snd   ),
    // unused outputs
    .dout   (),
    .irq_n  (),
    .psg_A  (),
    .psg_B  (),
    .psg_C  (),
    .snd    (),
    .snd_sample()
);

endmodule // jtgng_sound