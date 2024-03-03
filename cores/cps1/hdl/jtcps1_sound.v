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
    Date: 28-1-2020 */

module jtcps1_sound(
    input                rst,
    input                clk,

    input                filter_old,
    input         [ 1:0] dip_fxlevel,
    // Interface with main CPU
    input         [ 7:0] snd_latch0,
    input         [ 7:0] snd_latch1,

    // ROM
    output    reg [15:0] rom_addr,
    output    reg        rom_cs,
    input         [ 7:0] rom_data,
    input                rom_ok,

    // ADPCM ROM
    output        [17:0] adpcm_addr,
    output               adpcm_cs,
    input         [ 7:0] adpcm_data,
    input                adpcm_ok,

    // Sound output
    output signed [15:0] left,
    output signed [15:0] right,
    output               sample,
    output reg           peak,
    input         [ 7:0] debug_bus
);

wire signed [13:0] oki_pre, pcm_rc, pcm_butter;
reg  signed [13:0] pcm_snd;
wire signed [15:0] fm_left, fm_right;
reg         [ 7:0] fmgain, pcmgain, din, cmd_latch, dev_latch, mem_latch;
wire        [ 7:0] ram_dout, dout, oki_dout, fm_dout, pcmbase;
wire        [15:0] A;
reg                fm_cs, latch0_cs, latch1_cs, ram_cs, oki_cs, oki7_cs, bank_cs,
                   oki7, bank, latch_cs, dev_cs, mem_cs, rom_ok2;
wire               cen_fm, cen_fm2, cen_oki, nc, cpu_cen, io_cs,
                   peak_l, peak_r, pcm_en, fm_en, iorq_n, m1_n,
                   mreq_n, int_n, WRn, oki_wrn, rd_n, wr_n, RAM_we;

assign RAM_we   = ram_cs && !WRn;
assign WRn      = wr_n | mreq_n;
assign adpcm_cs = 1'b1;
assign oki_wrn  = ~(oki_cs & ~WRn);
assign pcm_en   = 1; //~debug_bus[0];
assign fm_en    = 1; //~debug_bus[1];
assign io_cs    = !mreq_n && A[15:12] == 4'b1111;
assign pcmbase  = pcm_en ? 8'h18 : 8'h0;

always @(posedge clk) begin
    peak    <= peak_r | peak_l;
    fmgain  <= fm_en  ? 8'h08 : 8'h0;
    pcm_snd <= filter_old ? pcm_rc : pcm_butter;
    case(dip_fxlevel)
        0: pcmgain <= pcmbase>>1;
        1: pcmgain <= pcmbase-(pcmbase>>1);
        2: pcmgain <= pcmbase;
        3: pcmgain <= pcmbase+(pcmbase>>1);
    endcase
    // case(debug_bus[1:0])
    //     2: pcm_snd <= pcm_rc;
    //     3: pcm_snd <= pcm_butter;
    //     default: pcm_snd <= oki_pre;
    // endcase
end

jtframe_mixer #(.W1(14)) u_left(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( sample    ),
    // input signals
    .ch0    ( fm_left   ),
    .ch1    ( pcm_snd   ),
    .ch2    ( 16'd0     ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( fmgain    ),
    .gain1  ( pcmgain   ),
    .gain2  ( 8'h00     ),
    .gain3  ( 8'h00     ),
    .mixed  ( left      ),
    .peak   ( peak_l    )
);

jtframe_mixer #(.W1(14)) u_right(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( sample    ),
    // input signals
    .ch0    ( fm_right  ),
    .ch1    ( pcm_snd   ),
    .ch2    ( 16'd0     ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( fmgain    ),
    .gain1  ( pcmgain   ),
    .gain2  ( 8'h00     ),
    .gain3  ( 8'h00     ),
    .mixed  ( right     ),
    .peak   ( peak_r    )
);

jtframe_cen3p57 u_fmcen(
    .clk        (  clk       ),       // 48 MHz
    .cen_3p57   (  cen_fm    ),
    .cen_1p78   (  cen_fm2   )
);

jtframe_frac_cen u_okicen(
    .clk        (  clk              ),
    .n          ( 10'd1             ),
    .m          ( 10'd48            ),
    .cen        ( { nc, cen_oki }   ),
    .cenb       (                   )
);

always @(posedge clk) begin
    if ( rst ) begin
        rom_cs    <= 1'b0;
        rom_addr  <= 16'd0;
        ram_cs    <= 1'b0;
        fm_cs     <= 1'b0;
        oki_cs    <= 1'b0;
        bank_cs   <= 1'b0;
        oki7_cs   <= 1'b0;
        latch0_cs <= 1'b0;
        latch1_cs <= 1'b0;
    end else begin
        rom_cs    <= !mreq_n && !rd_n && (!A[15] || A[15:14]==2'b10);
        rom_addr  <= A[15] ? { 1'b1, bank, A[13:0] } : { 1'b0, A[14:0] };
        ram_cs    <= !mreq_n && A[15:12] == 4'b1101;
        fm_cs     <= io_cs && A[3:1]==3'd0;
        oki_cs    <= io_cs && A[3:1]==3'd1;
        bank_cs   <= io_cs && A[3:1]==3'd2;
        oki7_cs   <= io_cs && A[3:1]==3'd3;
        latch0_cs <= io_cs && A[3:1]==3'd4;
        latch1_cs <= io_cs && A[3:1]==3'd5;
    end
end

always @(posedge clk, posedge rst) begin
    if(rst) begin
        bank <= 1'b0;
        oki7 <= 1'b0;
    end else if(!wr_n && cen_fm) begin
        if(bank_cs) bank <= dout[0];
        if(oki7_cs) oki7 <= dout[0];
    end
end

jtframe_ram #(.AW(11)) u_ram(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( dout     ),
    .addr   ( A[10:0]  ),
    .we     ( RAM_we   ),
    .q      ( ram_dout )
);

// As we operate much faster than cen_fm, the input data mux is done
// in two clock cycles. Data will always be ready before next cen_fm pulse
//
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        din     <= 8'hff;
        rom_ok2 <= 1'b0;
    end
    else begin
        cmd_latch <= latch0_cs ? snd_latch0 : snd_latch1;
        latch_cs  <= latch1_cs | latch0_cs;
        dev_latch <= fm_cs ? fm_dout : oki_dout;
        dev_cs    <= fm_cs | oki_cs;
        mem_latch <= ram_cs ? ram_dout : rom_data;
        mem_cs    <= ram_cs | rom_cs;
        rom_ok2   <= rom_ok;
        case( 1'b1 )
            dev_cs:    din <= dev_latch;
            latch_cs:  din <= cmd_latch;
            mem_cs:    din <= mem_latch;
            default:   din <= 8'hff;
        endcase
    end
end

jtframe_z80_romwait u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( cen_fm      ),
    .cpu_cen    ( cpu_cen     ),
    .int_n      ( int_n       ),
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     (             ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .din        ( din         ),
    .dout       ( dout        ),
    // manage access to ROM data from SDRAM
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok & rom_ok2     )
);
/* verilator tracing_off */
jt51 u_jt51(
    .rst        ( rst       ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( !fm_cs    ), // chip select
    .wr_n       ( WRn       ), // write
    .a0         ( A[0]      ),
    .din        ( dout      ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      ( int_n     ),  // I do not synchronize this signal
    // Low resolution output (same as real chip)
    .sample     (           ),
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_left   ),
    .xright     ( fm_right  )
);
/* verilator tracing_on */
jt6295 #(.INTERPOL(0)) u_adpcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_oki   ),
    .ss         ( oki7      ),
    // CPU interface
    .wrn        ( oki_wrn   ),  // active low
    .din        ( dout      ),
    .dout       ( oki_dout  ),
    // ROM interface
    .rom_addr   ( adpcm_addr),
    .rom_data   ( adpcm_data),
    .rom_ok     ( adpcm_ok  ),
    // Sound output
    .sound      ( oki_pre   ),
    // .sound      ( pcm_snd ),
    .sample     ( sample    )   // 48 kHz
);

jtframe_pole #(.WA(8), .WS(14)) u_pole(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sample     ( sample    ),
    .a          ( 8'he7     ),  // pole at 770Hz for a 48kHz sample rate
    .sin        ( oki_pre   ),
    .sout       ( pcm_rc    )
);

jtframe_iir2 #(.G(2), .WS(14)) u_butter(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sample     ( sample    ),
    .a1         ( 14'd10483 ),
    .a2         (-14'd3912  ),
    .b0         ( 14'd405   ),
    .b1         ( 14'd811   ),
    .b2         ( 14'd405   ),
    .sin        ( oki_pre   ),
    .sout       ( pcm_butter)
);

endmodule
