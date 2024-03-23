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
    Date: 18-9-2022 */

module jtkiwi_snd(
    input               rst,
    input               clk,
    input               cen6,
    input               cen3,
    input               cen1p5,

    input               LVBL,
    input               fm_en,
    input               psg_en,
    input               fast_fm,

    // MCU
    input               mcu_en,
    input               kabuki,
    input               kabuki_mod,
    input               kageki,
    input      [10:0]   prog_addr,  // 2kB
    input      [ 7:0]   prog_data,
    input               prom_we,

    // Cabinet inputs
    input      [ 1:0]   cab_1p,
    input      [ 1:0]   coin,
    input      [ 6:0]   joystick1,
    input      [ 6:0]   joystick2,
    input      [ 1:0]   dial_x,
    input      [ 1:0]   dial_y,

    // ROM interface
    output reg [15:0]   rom_addr,
    output reg          rom_cs,
    input      [ 7:0]   rom_data,

    // Audio CPU (Z80)
    output     [16:0]   audiocpu_addr,
    output              audiocpu_cs,
    input      [ 7:0]   audiocpu_data,
    input               audiocpu_ok,

    // Sub CPU (sound)
    input               snd_rstn,

    // PCM (Kageki)
    output reg [15:0]   pcm_addr,
    input      [ 7:0]   pcm_data,
    input               pcm_ok,
    output              pcm_cs,
    //      access to RAM
    output     [12:0]   ram_addr,
    output     [ 7:0]   ram_din,
    output              cpu_rnw,
    output reg          ram_cs,
    input      [ 7:0]   ram_dout,
    input               mshramen,
    output reg          pal_cs,
    input      [ 7:0]   pal_dout,

    // DIP switches
    input               dip_pause,
    input      [ 1:0]   fx_level,
    input               service,
    input               tilt,
    input      [15:0]   dipsw,

    // Sound output
    output signed [15:0] snd,
    output               sample,
    output               peak,
    // Debug
    input      [ 7:0]    debug_bus,
    input      [ 7:0]    st_addr,
    output reg [ 7:0]    st_dout
);
`ifndef NOSOUND

wire        irq_ack, mreq_n, m1_n, iorq_n, rd_n, wr_n,
            fmint_n, int_n, cpu_cen, rfsh_n;
reg  [ 7:0] din, cab_dout, psg_gain, fm_gain, pcm_gain, p1_din, porta_din;
wire [ 7:0] fm_dout, dout, p2_din, p2_dout, mcu_dout, mcu_st, porta_dout, portb_dout,
            dial_dout, p1_dout;
reg  [ 1:0] bank, dial_rst;
wire [15:0] A;
wire [ 9:0] psg_snd;
reg         bank_cs, fm_cs, cab_cs, mcu_cs, dial_cs, kabuki_dipsnd,
            dev_busy, fm_busy, fmcs_l,
            mcu_rstn, comb_rstn=0;
wire signed [15:0] fm_snd;
wire        mem_acc, mcu_comb_rst;
wire  [1:0] mcu_we, mcu_rd;

`ifdef SIMULATION
wire shared_rd = ram_cs && !A[0] && !rd_n;
wire shared_wr = ram_cs && !A[0] && !wr_n;
`endif

assign mem_acc  = ~mreq_n & rfsh_n;
assign ram_din  = dout;
assign ram_addr = A[12:0];
assign cpu_rnw  = wr_n | ~cpu_cen;
assign mcu_comb_rst = ~(mcu_rstn & comb_rstn);
// assign mcu_comb_rst = ~comb_rstn;
assign p2_din   = { 6'h3f, tilt, service };
assign pcm_cs   = kageki;
assign mcu_we   = {2{mcu_cs & ~wr_n}} & { A[0], ~A[0] };
assign mcu_rd   = {2{mcu_cs & ~rd_n}} & { A[0], ~A[0] };

assign irq_ack = /*!m1_n &&*/ !iorq_n; // The original PCB just uses iorq_n,
    // the orthodox way to do it is to use m1_n too

always @* begin
    rom_addr = A;
    if( A[15] ) begin // Bank access
        rom_addr[14:13] = bank;
    end
end

always @* begin
    dev_busy = mshramen & ram_cs | fm_busy;
end

always @(posedge clk) begin
    case( fx_level )
        2'd0: psg_gain <= 8'h02;
        2'd1: psg_gain <= 8'h05;
        2'd2: psg_gain <= 8'h07;
        2'd3: psg_gain <= 8'h09;
    endcase
    if( !psg_en ) psg_gain <= 0;
    pcm_gain <= kabuki ? 8'h04 : kageki ? 8'h0A : 8'h0;
    fm_gain  <= kabuki ? 8'h60 : kageki ? 8'h20 : 8'h30;
    if( !fm_en ) fm_gain <= 0;
end

always @(posedge clk) begin
    comb_rstn <= snd_rstn & ~rst;
    if( cen6 ) begin
        fmcs_l <= fm_cs;
        fm_busy <= fm_cs & ~fmcs_l;
    end
end

always @(posedge clk) begin
    rom_cs  <= mem_acc &&  A[15:12]  < 4'ha;
    bank_cs <= mem_acc &&  A[15:12] == 4'ha; // this cleans the watchdog counter - not implemented
    fm_cs   <= mem_acc &&  A[15:12] == 4'hb && !kabuki;
    kabuki_dipsnd <= mem_acc && A[15:12] == 4'hb && kabuki;
    cab_cs  <= mem_acc &&  A[15:12] == 4'hc && !mcu_en;
    mcu_cs  <= mem_acc &&  A[15:12] == 4'hc &&  mcu_en;
    ram_cs  <= mem_acc && (A[15:12] == 4'hd || A[15:12] == 4'he);
    dial_cs <= mem_acc &&  A[15:12] == 4'hf;
    pal_cs  <= mem_acc &&  A[15:12] == 4'hf && (A[11] ^ kabuki_mod) && !A[10] && kabuki;
end

always @(posedge clk, negedge comb_rstn) begin
    if( !comb_rstn ) begin
        bank     <= 0;
        mcu_rstn <= 1;
        dial_rst <= 0;
    end else begin
        if( bank_cs ) begin
            bank     <= dout[1:0];
            dial_rst <= dout[3:2];
            mcu_rstn <= dout[4];
`ifdef SIMULATION
            if( !mcu_rstn && dout[4] ) $display("MCU reset released");
            if( mcu_rstn && !dout[4] ) $display("MCU reset");
`endif
        end
    end
end

wire [7:0] kabuki_dipsw = A[0] ? dipsw[15:8] : dipsw[7:0];

always @(posedge clk) begin
    if( !dip_pause )
        cab_dout <= 8'hff; // do not let inputs disturb the pause
    else begin
        case( A[2:0] )
            0: cab_dout <= { cab_1p[0], joystick1 };
            1: cab_dout <= { cab_1p[1], joystick2 };
            2: cab_dout <= (kabuki | kageki) ?
                { 2'h3, coin[1], coin[0], 2'h3, tilt, service } :
                { 4'hf, coin[0], coin[1],       tilt, service };
            // 3: cab_dout <= { 7'h7f, ~coin[0] };
            // 4: cab_dout <= { 7'h7f, ~coin[1] };
            default: cab_dout <= 8'h00;
        endcase
    end
    din <= rom_cs ? rom_data :
           ram_cs ? ram_dout :
           fm_cs  ? fm_dout  :
           mcu_cs ? mcu_dout :
           cab_cs ? cab_dout :
           pal_cs ? pal_dout :
           (kabuki_dipsnd & !A[2]) ? kabuki_dipsw :
           dial_cs ? dial_dout :
           8'h00;
end

always @(posedge clk) begin
    case( p2_dout[2:0] )
        3'h4: p1_din <= { cab_1p[0], joystick1 };
        3'h5: p1_din <= { cab_1p[1], joystick2 };
        3'h2: p1_din <= { 6'h3f, tilt, service };
        default: p1_din <= 8'hff;
    endcase
end

// Kageki's PCM
reg  [7:0] pcm_lsb, pcm_re;
wire [7:0] pcm_dcrm;
reg  [1:0] pcm_st;
reg  [2:0] pcm_cnt;
reg        pcm_cen, sample_l, pb7l;

always @(posedge clk, negedge comb_rstn) begin
    if( !comb_rstn ) begin
        pcm_cnt  <= 1;
        pcm_cen  <= 0;
        sample_l <= 0;
    end else begin
        sample_l <= sample;
        pcm_cen  <= 0;
        if( sample && !sample_l ) begin
            pcm_cnt <= { pcm_cnt[1:0], pcm_cnt[2] };
            pcm_cen <= pcm_cnt[2];
        end
    end
end

always @(posedge clk) begin
    case( st_addr[5:4] )
        0: st_dout <= { 3'd0, mcu_en, 3'd0, mcu_comb_rst };
        1: st_dout <= mcu_st;
        2: case( st_addr[1:0])
            0: st_dout <= { pcm_st, portb_dout[5:0] };
            1: st_dout <= pcm_addr[15:8];
            2: st_dout <= pcm_gain;
            3: st_dout <= pcm_re;
        endcase
        3: case( st_addr[1:0] )
            0: st_dout <= p1_din;
            1: st_dout <= p2_din;
            3: st_dout <= p2_dout;
            default: st_dout <= 0;
        endcase
    endcase
end

always @(posedge clk, negedge comb_rstn) begin
    if( !comb_rstn ) begin
        pcm_st   <= 0;
        pcm_addr <= 0;
        pcm_re   <= 8'h80;
        pb7l     <= 0;
    end else begin
        pb7l <= portb_dout[7];
        if( pcm_cen && pcm_ok ) begin
            case( pcm_st )
                default:;
                1: begin
                    pcm_lsb     <= pcm_data;
                    pcm_addr[0] <= 1;
                    pcm_st      <= 2;
                end
                2: begin
                    pcm_addr <= { pcm_data, pcm_lsb };
                    pcm_st   <= 3;
                end
                3: begin
                    if( pcm_data == 0 || (&pcm_addr) ) begin
                        pcm_st <= 0;
                        pcm_re <= 8'h80;
                    end else begin
                        // the 0 value is not part of the sample.
                        // pcm_re will keep the last valid value
                        // this prevents noise at the start and end of samples
                        pcm_re   <= pcm_data;
                    end
                    pcm_addr <= pcm_addr + 1'd1;
                end
            endcase
        end
        if( portb_dout[7] && !pb7l ) begin
            pcm_st   <= 1;
            pcm_addr <= { 9'd0, portb_dout[5:0], 1'b0 } + 16'h90;
        end
    end
end

jtframe_dcrm u_dcrm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .sample     ( pcm_cen   ),
    .din        ( kabuki ? portb_dout : pcm_re ),
    .dout       ( pcm_dcrm  )
);

`ifdef SIMULATION
    integer line_cnt=1;

    always @(negedge ram_cs, posedge rst) begin
        if( rst )
            line_cnt <= 1;
        else
            line_cnt <= line_cnt+1;
    end
`endif

jtframe_ff u_irq(
    .clk    ( clk       ),
    .rst    ( ~comb_rstn),
    .cen    ( 1'b1      ),
    .din    ( 1'b1      ),
    .q      (           ),
    .qn     ( int_n     ),
    .set    ( 1'b0      ),
    .clr    ( irq_ack   ),
    .sigedge( ~LVBL     )
);

jtframe_z80_devwait #(.RECOVERY(0)) u_gamecpu(
    .rst_n    ( comb_rstn      ),
    .clk      ( clk            ),
    .cen      ( cen6           ),
    .cpu_cen  ( cpu_cen        ),
`ifdef NOINT
    .int_n    ( 1'b1           ),
    .nmi_n    ( 1'b1           ),
`else
    .int_n    ( int_n          ),
    .nmi_n    ( kabuki | fmint_n ),
`endif
    .busrq_n  ( 1'b1           ),
    .m1_n     ( m1_n           ),
    .mreq_n   ( mreq_n         ),
    .iorq_n   ( iorq_n         ),
    .rd_n     ( rd_n           ),
    .wr_n     ( wr_n           ),
    .rfsh_n   ( rfsh_n         ),
    .halt_n   (                ),
    .busak_n  (                ),
    .A        ( A              ),
    .din      ( din            ),
    .dout     ( dout           ),
    .rom_cs   ( rom_cs         ),
    .rom_ok   ( 1'b1           ),
    .dev_busy ( dev_busy       )
);

`ifndef NOMCU
// `ifdef SIMULATION
//     reg mcu_rdl, mcu_wel;

//     always @(posedge clk ) begin
//         mcu_rdl <= |mcu_rd;
//         mcu_wel <= |mcu_we;
//         if( mcu_we==0 && mcu_wel ) $display("Wr %X to   %X", dout, A);
//         if( mcu_rd==0 && mcu_rdl ) $display("Rd %X from %X",din, A);
//     end
// `endif

jtframe_i8742 #(
    .SIMFILE("../../firmware/arknoid2.bin")
) u_mcu(
    .rst        ( mcu_comb_rst ),
    .clk        ( clk        ),
    .cen        ( cen6       ),

    // CPU communication
    .a0         ( A[0]       ),
    .cs_n       ( ~mcu_cs    ),
    .cpu_rdn    ( rd_n       ),
    .cpu_wrn    ( wr_n       ),
    .din        ( dout       ),
    .dout       ( mcu_dout   ),

    // Ports
    .p1_din     ( p1_din     ),
    .p2_din     ( p2_din     ),
    .p1_dout    ( p1_dout    ),
    .p2_dout    ( p2_dout    ),

    // Test pins (used in the assembler TEST instruction)
    .t0_din     (~coin[0]),
    .t1_din     (~coin[1]),

    .prog_addr  ( prog_addr  ),
    .prog_data  ( prog_data  ),
    .prom_we    ( prom_we    ),

    // Debug
    .st_addr    ( st_addr    ),
    .st_dout    ( mcu_st     )
);
`else
    assign p2_dout  = 0;
    assign mcu_dout = 8'hff;
`endif

always @(posedge clk) begin
    if( kageki ) begin
        case( portb_dout[1:0] )
            0: porta_din <= { 4'd0, dipsw[4+8], dipsw[0+8], dipsw[4], dipsw[0] };
            2: porta_din <= { 4'd0, dipsw[5+8], dipsw[1+8], dipsw[5], dipsw[1] };
            1: porta_din <= { 4'd0, dipsw[6+8], dipsw[2+8], dipsw[6], dipsw[2] };
            3: porta_din <= { 4'd0, dipsw[7+8], dipsw[3+8], dipsw[7], dipsw[3] };
        endcase
    end else porta_din <= dipsw[7:0];
end

// Kabuki sound CPU
wire        snd_mreq_n, snd_m1_n, snd_iorq_n, snd_rd_n, snd_wr_n, snd_rfsh_n, snd_cpu_cen;
reg         snd_int_n;
reg  [ 7:0] snd_latch;
wire [ 7:0] snd_dout, snd_ram_dout;
wire [15:0] snd_A;
wire  [2:0] snd_bank = porta_dout[2:0];
reg         snd_rom_cs, snd_ram_cs, snd_bank_cs, snd_fm_cs, snd_latch_cs;
assign      audiocpu_cs = snd_rom_cs | snd_bank_cs;
assign      audiocpu_addr = {snd_bank_cs ? snd_bank[2:0] : {2'd0, snd_A[14]}, snd_A[13:0]};

always @(posedge clk) begin
    snd_rom_cs  <= ~snd_mreq_n && snd_rfsh_n && !snd_A[15];
    snd_ram_cs  <= ~snd_mreq_n && snd_rfsh_n &&  snd_A[15:14] == 2'b11 && (snd_A[13] ^ kabuki_mod); // E000-FFFF or C000-DFFF
    snd_bank_cs <= ~snd_mreq_n && snd_rfsh_n &&  snd_A[15:14] == 2'b10 && !kabuki_mod;  // 8000-BFFF
    snd_fm_cs   <= ~snd_iorq_n && snd_m1_n && !snd_A[1];
    snd_latch_cs<= ~snd_iorq_n && snd_m1_n &&  snd_A[1];

    if (kabuki_dipsnd && !A[1]) begin
        snd_int_n <= 0;
        snd_latch <= dout;
    end
    if (snd_latch_cs) snd_int_n <= 1;
end

wire [7:0] snd_din =
    (snd_rom_cs | snd_bank_cs) ? audiocpu_data :
    snd_ram_cs ? snd_ram_dout :
    snd_fm_cs  ? fm_dout :
    snd_latch_cs ? snd_latch : 8'hFF;

jtframe_z80_devwait #(.RECOVERY(0)) u_sndcpu(
    .rst_n    ( comb_rstn & kabuki ),
    .clk      ( clk            ),
    .cen      ( cen6           ),
    .cpu_cen  ( snd_cpu_cen    ),
`ifdef NOINT
    .int_n    ( 1'b1           ),
    .nmi_n    ( 1'b1           ),
`else
    .int_n    ( snd_int_n      ),
    .nmi_n    ( fmint_n        ),
`endif
    .busrq_n  ( 1'b1           ),
    .m1_n     ( snd_m1_n       ),
    .mreq_n   ( snd_mreq_n     ),
    .iorq_n   ( snd_iorq_n     ),
    .rd_n     ( snd_rd_n       ),
    .wr_n     ( snd_wr_n       ),
    .rfsh_n   ( snd_rfsh_n     ),
    .halt_n   (                ),
    .busak_n  (                ),
    .A        ( snd_A          ),
    .din      ( snd_din        ),
    .dout     ( snd_dout       ),
    .rom_cs   ( audiocpu_cs    ),
    .rom_ok   ( audiocpu_ok    ),
    .dev_busy ( dev_busy       )
);

jtframe_ram #(.AW(13)) u_sndram(
    .clk    ( clk          ),
    .cen    ( 1'b1         ),
    // Main CPU
    .addr   ( snd_A[12:0]  ),
    .data   ( snd_dout     ),
    .we     ( snd_ram_cs & ~snd_wr_n ),
    .q      ( snd_ram_dout )
);

// only used by Arkanoid 2
jt4701 u_dial(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .x_in   ( dial_x    ),
    .y_in   ( dial_y    ),
    .rightn ( service   ),
    .leftn  (coin[0]),
    .middlen(coin[1]),
    .x_rst  (dial_rst[0]),
    .y_rst  (dial_rst[1]),
    .csn    ( ~dial_cs  ),
    .uln    ( A[0]      ),
    .xn_y   ( A[1]      ),
    .cfn    (           ),
    .sfn    (           ),
    .dout   ( dial_dout ),
    .dir    (           )
);

`ifndef VERILATOR_KEEP_JT03
/* verilator tracing_off */
`endif
reg fm_cen;

always @(negedge clk) fm_cen <= fast_fm ? cen3 : cen1p5;

jt03 u_2203(
    .rst        ( ~comb_rstn ),
    .clk        ( clk        ),
    .cen        ( fm_cen     ),
    .din        ( kabuki ? snd_dout : dout ),
    .dout       ( fm_dout    ),
    .addr       ( kabuki ? snd_A[0] : A[0] ),
    .cs_n       ( ~fm_cs & ~snd_fm_cs ),
    .wr_n       ( kabuki ? snd_wr_n : wr_n ),
    .psg_snd    ( psg_snd    ),
    .fm_snd     ( fm_snd     ),
    .snd_sample ( sample     ),
    .irq_n      ( fmint_n    ),
    // IO ports
    .IOA_in     ( porta_din  ),
    .IOB_in     ( dipsw[15:8]),
    .IOA_oe     (            ),
    .IOA_out    ( porta_dout ),
    .IOB_out    ( portb_dout ),
    .IOB_oe     (            ),
    // unused outputs
    .psg_A      (            ),
    .psg_B      (            ),
    .psg_C      (            ),
    .snd        (            ),
    .debug_view (            )
);

jtframe_mixer #(.W1(10),.W2(8)) u_mixer(
    .rst    ( rst          ),
    .clk    ( clk          ),
    .cen    ( cen1p5       ),
    .ch0    ( fm_snd       ),
    .ch1    ( psg_snd      ),
    .ch2    ( pcm_dcrm     ),
    .ch3    ( 16'd0        ),
    .gain0  ( fm_gain      ), // YM2203
    .gain1  ( psg_gain     ), // PSG
    .gain2  ( pcm_gain     ),
    .gain3  ( 8'd0         ),
    .mixed  ( snd          ),
    .peak   ( peak         )
);
/* verilator tracing_on */

`else
    initial begin
        rom_addr = 0;
        rom_cs   = 0;
        $display("WARNING: without the sound CPU, the main CPU won't work correctly");
    end
    assign ram_addr = 0;
    assign ram_din  = 0;
    initial ram_cs  = 0;
    assign cpu_rnw  = 1;
    assign snd      = 0;
    assign sample   = 0;
    assign peak     = 0;
`endif
endmodule