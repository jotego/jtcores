/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Toaplan TP-009 / Twin Cobra DSP subsystem: the TMS320C10 and the glue that
 * lets it reach the host CPU's RAM while the host is halted.
 *
 * Setting the run bit interrupts the DSP and halts the host. The DSP points a
 * window at host RAM through port 0 and reads or writes it through port 1.
 * A zero written to work RAM word 0 or 1 arms the release, and a zero written
 * to port 3 then lets the host run again. TWINCOBR selects the 68000 decode;
 * only the Wardner decode has been tested.
 */
module jttoaplan1_dsp #(parameter TWINCOBR=0) (
    input             rst,
    input             clk,
    input             cen,

    input             dsp_on,
    output reg        halt_main,

    output     [13:1] host_addr,
    output reg [ 1:0] host_sel,
    output     [15:0] host_dout,
    input      [15:0] host_din,
    output            host_we,

    output     [11:0] rom_addr,
    input      [15:0] rom_data
);

localparam [1:0] SEL_WORK = 2'd0,
                 SEL_OBJ  = 2'd1,
                 SEL_PAL  = 2'd2,
                 SEL_NONE = 2'd3;

reg  [12:0] addr_l;
reg         bio, execute;
reg         on_l;
reg  [ 3:0] int_cnt;

wire [15:0] pdout, pdin;
wire [ 2:0] pa;
wire        pwr, prd;

// the top three bits of the port 0 word select the RAM, the rest is a word
// index into it: 11 bits on Wardner, 13 on Twin Cobra
wire [ 2:0] seg_sel = pdout[15:13];
wire [12:0] off_new = TWINCOBR ? pdout[12:0] : {2'd0, pdout[10:0]};

reg  [1:0] sel_new;
always @* begin
    case( seg_sel )
        3'b011:  sel_new = SEL_WORK;
        3'b100:  sel_new = SEL_OBJ;
        3'b101:  sel_new = SEL_PAL;
        default: sel_new = SEL_NONE;
    endcase
end

// the port strobes hold while the DSP is frozen, so they are gated the same way
wire dsp_step = cen & dsp_on;
wire exec_hit = (host_sel == SEL_WORK) && (addr_l[12:1] == 12'd0) && (pdout == 16'd0);

assign host_addr = addr_l;
assign host_dout = pdout;
assign host_we   = dsp_step & pwr & (pa == 3'd1) & (host_sel != SEL_NONE);
assign pdin      = (pa == 3'd1 && host_sel != SEL_NONE) ? host_din : 16'd0;

// INT_n is a short pulse on each rise of the run bit: IKA32010 samples it on
// the DSP's clock enable, so a level would still be low when the next
// activation starts and give no edge
wire on_rise = dsp_on & ~on_l;
wire int_n   = int_cnt == 4'd0;

always @(posedge clk) begin
    if( rst ) begin
        addr_l    <= 13'd0;
        host_sel  <= SEL_NONE;
        bio       <= 1'b0;
        execute   <= 1'b0;
        halt_main <= 1'b0;
        on_l      <= 1'b0;
        int_cnt   <= 4'd0;
    end else begin
        on_l      <= dsp_on;

        if( on_rise ) begin
            int_cnt   <= 4'd8;
            halt_main <= 1'b1;
        end else if( dsp_step && int_cnt != 4'd0 ) begin
            int_cnt   <= int_cnt - 4'd1;
        end

        if( dsp_step ) begin
            if( pwr ) begin
                case( pa )
                3'd0: begin
                    addr_l   <= off_new;
                    host_sel <= sel_new;
                end
                3'd1: begin
                    if( exec_hit ) execute <= 1'b1;
                end
                3'd3: begin
                    if( pdout[15] ) bio <= 1'b0;
                    if( pdout == 16'd0 ) begin
                        if( execute ) begin
                            halt_main <= 1'b0;
                            execute   <= 1'b0;
                        end
                        bio <= 1'b1;
                    end
                end
                default:;
                endcase
            end
        end
    end
end

jtframe_tms32010 u_cpu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .hold       ( ~dsp_on   ),
    .int_n      ( int_n     ),
    .bio_n      ( ~bio      ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( rom_data  ),
    .port       ( pa        ),
    .din        ( pdin      ),
    .dout       ( pdout     ),
    .wr         ( pwr       ),
    .rd         ( prd       )
);

endmodule
