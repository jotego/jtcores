/*  This file is part of JTBUBL.
    JTBUBL program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTBUBL program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTBUBL.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 18-9-2022 */

module jtkiwi_snd(
    input               rst,
    input               clk,
    input               cen6,
    input               cen1p5,

    input               LVBL,
    input               fm_en,
    input               psg_en,

    // MCU
    input               mcu_en,
    input               kabuki,
    input               kageki,
    input      [10:0]   prog_addr,  // 2kB
    input      [ 7:0]   prog_data,
    input               prom_we,

    // Cabinet inputs
    input      [ 1:0]   start_button,
    input      [ 1:0]   coin_input,
    input      [ 6:0]   joystick1,
    input      [ 6:0]   joystick2,

    // ROM interface
    output reg [15:0]   rom_addr,
    output reg          rom_cs,
    input               rom_ok,
    input      [ 7:0]   rom_data,

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
    input      [ 7:0]   st_addr,
    output reg [ 7:0]   st_dout
);
`ifndef NOSOUND

wire        irq_ack, mreq_n, m1_n, iorq_n, rd_n, wr_n,
            fmint_n, int_n, cpu_cen, rfsh_n;
reg  [ 7:0] din, cab_dout, psg_gain, fm_gain, pcm_gain, p1_din, porta_din;
wire [ 7:0] fm_dout, dout, p2_din, p2_dout, mcu_dout, mcu_st, portb_dout;
reg  [ 1:0] bank;
wire [15:0] A;
wire [ 9:0] psg_snd;
reg         bank_cs, fm_cs, cab_cs, mcu_cs,
            dev_busy, fm_busy, fmcs_l,
            mcu_rstn, comb_rstn=0;
wire signed [15:0] fm_snd;
wire        mem_acc, mcu_we, mcu_comb_rst;

`ifdef SIMULATION
wire shared_rd = ram_cs && !A[0] && !rd_n;
wire shared_wr = ram_cs && !A[0] && !wr_n;
`endif

assign mem_acc  = ~mreq_n & rfsh_n;
assign ram_din  = dout;
assign ram_addr = A[12:0];
assign cpu_rnw  = wr_n | ~cpu_cen;
assign mcu_comb_rst = ~(mcu_rstn & comb_rstn);
assign p2_din   = { 6'h3f, tilt, service };
assign pcm_cs   = kageki;

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
        2'd0: psg_gain <= 8'h03;
        2'd1: psg_gain <= 8'h06;
        2'd2: psg_gain <= 8'h08;
        2'd3: psg_gain <= 8'h0a;
    endcase
    if( !psg_en ) psg_gain <= 0;
    pcm_gain <= kageki ? 8'h0A : 8'h0;
    fm_gain  <= !fm_en ? 8'h0 : kageki ? 8'h20 : 8'h30;
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
    fm_cs   <= mem_acc &&  A[15:12] == 4'hb;
    cab_cs  <= mem_acc &&  A[15:12] == 4'hc && !mcu_en;
    mcu_cs  <= mem_acc &&  A[15:12] == 4'hc &&  mcu_en;
    ram_cs  <= mem_acc && (A[15:12] == 4'hd || A[15:12] == 4'he);
end

always @(posedge clk, negedge comb_rstn) begin
    if( !comb_rstn ) begin
        bank     <= 0;
        mcu_rstn <= 1;
    end else begin
        if( bank_cs ) begin
            bank     <= dout[1:0];
            mcu_rstn <= dout[4];
`ifdef SIMULATION
            if( !mcu_rstn && dout[4] ) $display("MCU reset released");
            if( mcu_rstn && !dout[4] ) $display("MCU reset");
`endif
        end
    end
end

always @(posedge clk) begin
    if( !dip_pause )
        cab_dout <= 8'hff; // do not let inputs disturb the pause
    else begin
        case( A[2:0] )
            0: cab_dout <= { start_button[0], joystick1 };
            1: cab_dout <= { start_button[1], joystick2 };
            2: cab_dout <= kageki ?
                { 2'h3, coin_input[1], coin_input[0], 2'h3, tilt, service } :
                { 4'hf, coin_input[0], coin_input[1],       tilt, service };
            // 3: cab_dout <= { 7'h7f, ~coin_input[0] };
            // 4: cab_dout <= { 7'h7f, ~coin_input[1] };
            default: cab_dout <= 8'h00;
        endcase
    end
    din <= rom_cs ? rom_data :
           ram_cs ? ram_dout :
           fm_cs  ? fm_dout  :
           mcu_cs ? mcu_dout :
           cab_cs ? cab_dout : 8'h00;
end

always @(posedge clk) begin
    case( p2_dout[2:0] )
        3'h4: p1_din <= { start_button[0], joystick1 };
        3'h5: p1_din <= { start_button[1], joystick2 };
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
    .din        ( pcm_re    ),
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

jtframe_z80_devwait #(.RECOVERY(1)) u_gamecpu(
    .rst_n    ( comb_rstn      ),
    .clk      ( clk            ),
    .cen      ( cen6           ),
    .cpu_cen  ( cpu_cen        ),
`ifdef NOINT
    .int_n    ( 1'b1           ),
    .nmi_n    ( 1'b1           ),
`else
    .int_n    ( int_n          ),
    .nmi_n    ( fmint_n        ),
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
    .rom_ok   ( rom_ok         ),
    .dev_busy ( dev_busy       )
);

`ifndef NOMCU
jtframe_i8742 u_mcu(
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
    .p1_dout    (            ),
    .p2_dout    ( p2_dout    ),

    // Test pins (used in the assembler TEST instruction)
    .t0_din     (~coin_input[0]),
    .t1_din     (~coin_input[1]),

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

`ifndef VERILATOR_KEEP_JT03
/* verilator tracing_off */
`endif
jt03 u_2203(
    .rst        ( ~comb_rstn ),
    .clk        ( clk        ),
    .cen        ( cen1p5     ),
    .din        ( dout       ),
    .dout       ( fm_dout    ),
    .addr       ( A[0]       ),
    .cs_n       ( ~fm_cs     ),
    .wr_n       ( wr_n       ),
    .psg_snd    ( psg_snd    ),
    .fm_snd     ( fm_snd     ),
    .snd_sample ( sample     ),
    .irq_n      ( fmint_n    ),
    // IO ports
    .IOA_in     ( porta_din  ),
    .IOB_in     ( dipsw[15:8]),
    .IOA_out    (            ),
    .IOB_out    ( portb_dout ),
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