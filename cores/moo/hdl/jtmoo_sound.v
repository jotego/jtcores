/* SPDX-FileCopyrightText: 2026 meathax
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Author: meathax
 * Date: 2-9-2026 */

module jtmoo_sound(
    input           rst,
    input           clk,
    input           cen_8,
    input           cen_4,
    input           cen_2,
    input           cen_pcm,

    input           pair_we,
    // communication with main CPU
    input    [ 7:0] main_dout,
    output   [ 7:0] pair_dout,
    input    [ 4:1] main_addr,

    input           snd_irq,
    // ROM
    output   [17:0] rom_addr,
    output reg      rom_cs,
    input    [ 7:0] rom_data,
    input           rom_ok,
    // PCM ROM
    output   [20:0] pcm_addr,
    input    [ 7:0] pcm_data,
    output          pcm_cs,
    input           pcm_ok,
    // Sound output
    output signed [15:0] k539_l, k539_r,
    // Debug
    input    [ 7:0] debug_bus,
    output   [ 7:0] st_dout
);

`ifndef NOSOUND
wire [ 7:0] cpu_dout, cpu_din, ram_dout, fm_dout, k39_dout, latch_dout;
wire [ 3:0] rom_hi;
reg  [ 3:0] bank;
wire [15:0] A;
wire        m1_n, mreq_n, rd_n, wr_n, iorq_n, rfsh_n, nmi_n,
            cpu_cen, fm_intn, latch_we, int_n, bank_we_fall, k39_busy;
reg         ram_cs, fm_cs, k39_cs, k21_cs, bank_we, mem_acc, nmi_clr, bank_we_l;
wire signed [15:0] fm_l, fm_r, pcm_l, pcm_r;
wire [ 2:0] nc;
// Board-local K054321 volume stage, in series with the AD1868;
// the shared latch module keeps its existing interface.
reg  [ 6:0] k21_vol;    // 0..64, 40 = unity, MAME k054321.cpp:99-113
reg  [ 2:0] vol_dec;    // k21_vol/10
reg  [ 3:0] vol_frac;   // k21_vol%10
// pair_we is a level held for the whole 68000 bus cycle (jtmoo_main.v:109), so
// the up counter must see one edge per write, not one per clock
reg         pair_we_l;
wire        pair_wr = pair_we & ~pair_we_l;

assign latch_we = k21_cs && !wr_n;
assign rom_hi   = A[15] ? bank : {3'd0, A[14]};
assign rom_addr = {rom_hi, A[13:0]};
assign cpu_din  = rom_cs ? rom_data   :
                  ram_cs ? ram_dout   :
                  k39_cs ? k39_dout   :
                  k21_cs ? latch_dout :
                  fm_cs  ? fm_dout    : 8'hff;
assign bank_we_fall = bank_we_l & ~bank_we;

// 054744 PAL: no A10 term, so each window is 2 kB
always @(*) begin
    mem_acc = !mreq_n && rfsh_n;
    rom_cs  = mem_acc && !(A[15] && A[14]) && !rd_n; // /SROM     0000-BFFF
    ram_cs  = mem_acc && A[15:13]==3'b110;           // /SRAM     C000-DFFF
    k39_cs  = mem_acc && A[15:11]==5'b1110_0;        // /PCM      E000-E7FF
    fm_cs   = mem_acc && A[15:11]==5'b1110_1;        // /FM       E800-EFFF
    k21_cs  = mem_acc && A[15:11]==5'b1111_0;        // /SLATCHES F000-F7FF
    bank_we = mem_acc && A[15:10]==6'b1111_10;       // /SBANK_WR F800-FBFF
end

// the bank latch clocks on any F800-FBFF access, not gated by write
always @(posedge clk) if(cpu_cen) bank_we_l <= bank_we;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank    <= 0;
        nmi_clr <= 1;
    end else if( bank_we_fall ) begin
        bank    <= cpu_dout[3:0];
        nmi_clr <= ~cpu_dout[4];
    end
end

// K054321 main-side register 2 resets the volume, register 3 steps it up while
// the written data is non zero (MAME k054321.cpp:44-45,99-113)
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        k21_vol   <= 0;
        vol_dec   <= 0;
        vol_frac  <= 0;
        pair_we_l <= 0;
    end else begin
        pair_we_l <= pair_we;
        if( pair_wr ) case( main_addr )
        4'd2: begin k21_vol <= 0; vol_dec <= 0; vol_frac <= 0; end
        4'd3: if( |main_dout && k21_vol!=7'd64 ) begin
            k21_vol <= k21_vol+7'd1;
            if( vol_frac==4'd9 ) begin
                vol_frac <= 0;
                vol_dec  <= vol_dec+3'd1;
            end else begin
                vol_frac <= vol_frac+4'd1;
            end
        end
        default:;
        endcase
    end
end

// gain = 2^((vol-40)/10) = (2^((vol%10)/10) << (vol/10)) >> 4, Q16
function [16:0] pow2_dec(input [3:0] n);
    case(n)
        4'd0: pow2_dec = 17'd65536;   4'd1: pow2_dec = 17'd70239;
        4'd2: pow2_dec = 17'd75281;   4'd3: pow2_dec = 17'd80684;
        4'd4: pow2_dec = 17'd86475;   4'd5: pow2_dec = 17'd92682;
        4'd6: pow2_dec = 17'd99333;   4'd7: pow2_dec = 17'd106462;
        4'd8: pow2_dec = 17'd114102;  4'd9: pow2_dec = 17'd122292;
        default: pow2_dec = 17'd65536;
    endcase
endfunction

function signed [15:0] clip16(input signed [19:0] v);
    clip16 = (v >  20'sd32767) ?  16'sd32767 :
             (v < -20'sd32768) ? -16'sd32768 : v[15:0];
endfunction

wire [22:0] gsh = {6'd0, pow2_dec(vol_frac)} << vol_dec;
wire signed [19:0] k21_gain = $signed({1'b0, gsh[22:4]});
wire signed [35:0] volp_l = pcm_l * k21_gain;
wire signed [35:0] volp_r = pcm_r * k21_gain;

assign k539_l = clip16(volp_l[35:16]);
assign k539_r = clip16(volp_r[35:16]);

// NMI latches on the YM2151 IRQ assertion edge
jtframe_edge #(.QSET(0)) u_edge (
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( ~fm_intn  ),
    .clr    ( nmi_clr   ),
    .q      ( nmi_n     )
);

/* verilator tracing_off */
jtframe_sysz80 #(`ifdef SND_RAMW .RAM_AW(`SND_RAMW), `endif .CLR_INT(1)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen_8 & ~k39_busy ),
    .cpu_cen    ( cpu_cen   ),
    .int_n      ( int_n     ),
    .nmi_n      ( nmi_n     ),
    .busrq_n    ( 1'b1      ),
    .m1_n       ( m1_n      ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     ( rfsh_n    ),
    .halt_n     (           ),
    .busak_n    (           ),
    .A          ( A         ),
    .cpu_din    ( cpu_din   ),
    .cpu_dout   ( cpu_dout  ),
    .ram_dout   ( ram_dout  ),
    // ROM access
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
);

/* verilator tracing_off */
jt51 u_jt51(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_4     ),
    .cen_p1     ( cen_2     ),
    .cs_n       ( !fm_cs    ),
    .wr_n       ( wr_n      ),
    .a0         ( A[0]      ),
    .din        ( cpu_dout  ),
    .dout       ( fm_dout   ),
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      ( fm_intn   ),
    .sample     (           ),
    // board feeds the YM2151 serial DAC stream (SO, pin 21) into the
    // K054539 AUX input, not the full-resolution internal accumulator
    .left       ( fm_l      ),
    .right      ( fm_r      ),
    .xleft      (           ),
    .xright     (           )
);

/* verilator tracing_on */
jtmoo_k054539 #(.VOLSHIFT(1)) u_k54539(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_pcm   ),
    .timeout    (           ),
    // CPU interface
    .addr       ({A[9],A[7:0]}),
    .we         ( ~wr_n     ),
    .rd         ( ~rd_n     ),
    .cs         ( k39_cs    ),
    .din        ( cpu_dout  ),
    .dout       ( k39_dout  ),
    .busy       ( k39_busy  ),
    // ROM
    .rom_cs     ( pcm_cs    ),
    .rom_addr   ({nc,pcm_addr}),
    .rom_data   ( pcm_data  ),
    .rom_ok     ( pcm_ok    ),
    // YM input, AUX1
    .aux_l      ( fm_l      ),
    .aux_r      ( fm_r      ),
    // Sound output, through the K054321 volume stage below
    .left       ( pcm_l     ),
    .right      ( pcm_r     ),
    // debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_dout   )
);

jt054321 u_54321(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .maddr      ( main_addr ),
    .mdout      ( main_dout ),
    .mdin       ( pair_dout ),
    .mwe        ( pair_we   ),

    .saddr      ( A[1:0]    ),
    .sdout      ( cpu_dout  ),
    .sdin       ( latch_dout),
    .swe        ( latch_we  ),

    // Z80 bus control
    .snd_on     ( snd_irq   ),
    .siorq_n    ( iorq_n    ),
    .int_n      ( int_n     )
);
`else
initial rom_cs   = 0;
assign  rom_addr = 0;
assign  pcm_addr = 0;
assign  pcm_cs   = 0;
assign  st_dout  = 0;
assign  { pair_dout, k539_l, k539_r } = 0;
`endif
endmodule
