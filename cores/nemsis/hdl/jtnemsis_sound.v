/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2026.
// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// JTCORES project edits: 2026-11-08.

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

*/

//================================================================================
//  Nemesis Sound Module (audio components of main CPU board)
//================================================================================

`default_nettype none

module jtnemsis_sound(
    input         rst,
    input         clk,             // 48 MHz
    input         cen_3p5,
    input         cen_1p7,
    input         audio_div_cen,
    input         cpu_cen,         // generated audio ROM wait enable

    input  [ 7:0] main_db,         // Sound input data (DATA Bus 0-7)
    input         data_n,          // Sound request (/DATA)
    input         sound_on_n,      // Sound On (/SOUND_ON)

    output        z80_cs,
    output [13:0] z80_addr,
    input  [ 7:0] z80_data,

    output [ 7:0] wav1_addr,
    output [ 7:0] wav1_vol_addr,
    output [ 7:0] wav2_addr,
    output [ 7:0] wav2_vol_addr,
    input  [ 3:0] wav1_data,
    input  [ 7:0] wav1_vol_data,
    input  [ 3:0] wav2_data,
    input  [ 7:0] wav2_vol_data,

    output [ 9:0] ay7e,
    output [ 9:0] ay8e,
    output [ 7:0] wav1,
    output [ 7:0] wav2,
    output        rc33_en,
    output        rc47_en,

    input  [ 7:0] debug_bus,
    output reg [7:0] st_dout
);

`ifndef NOSOUND

// Sound CPU and peripheral state.
wire        cpu_rst_n, cpu_int_n, cpu_rfsh_n, cpu_mreq_n, cpu_iorq_n, cpu_rd_n, cpu_wr_n;
wire [15:0] cpu_addr;
reg  [ 7:0] cpu_data_in;
wire [ 7:0] cpu_data_out, cpu_ram_data, ay7_data, ay8_data, data_ff_out;
reg         rom_ce_n, ram_cs, k5289_ld1, k5289_ld2, k5289_tg1, k5289_tg2;
reg         ay7_sel_n, ay8_sel_n, filter_ff_clk, data_oc_n;
reg  [ 7:0] clk_div_cnt;
reg  [ 7:0] ay8_ioa_in;
wire [ 4:0] prom1_addr, prom2_addr;
wire [ 7:0] ay7_ioa_out, ay7_iob_out;
wire        ay7_bc1, ay7_bdir, ay8_bc1, ay8_bdir;
wire        ram_we, cpu_irq_clear;
wire [ 1:0] filter_addr, filter_control;

wire [1:0] filter_ff_clk_edge_2;
wire [7:0] data_n_edge_8;

assign filter_ff_clk_edge_2 = {2{filter_ff_clk}};
assign data_n_edge_8 = {8{data_n}};

assign cpu_rst_n = ~rst;
assign z80_cs    = ~rom_ce_n;
assign z80_addr  = cpu_addr[13:0];
assign wav1_addr = {ay7_ioa_out[7:5], prom1_addr};
assign wav2_addr = {ay7_iob_out[7:5], prom2_addr};
assign wav1_vol_addr = {ay7_ioa_out[3:0], wav1_data};
assign wav2_vol_addr = {ay7_iob_out[3:0], wav2_data};
assign wav1 = wav1_vol_data;
assign wav2 = wav2_vol_data;
assign ay7_bdir = ~|{ay7_sel_n, cpu_addr[9]};
assign ay7_bc1  = ~|{ay7_sel_n, cpu_addr[10]};
assign ay8_bdir = ~|{ay8_sel_n, cpu_addr[7]};
assign ay8_bc1  = ~|{ay8_sel_n, cpu_addr[8]};
assign ram_we = ~ram_cs & ~cpu_wr_n;
assign cpu_irq_clear = ~&{cpu_rst_n, cpu_iorq_n};
assign filter_addr = {cpu_addr[12], cpu_addr[11]};
assign {rc47_en, rc33_en} = filter_control;

// Stable on-screen status pages; the byte source is the latched main-CPU command.
always @(*) begin
    case (debug_bus[1:0])
        2'd0:    st_dout = {6'd0, rc47_en, rc33_en};
        2'd1:    st_dout = data_ff_out;
        default: st_dout = 8'd0;
    endcase
end

// Sound ROM/RAM and peripheral address decoding.
always @(*) begin
    reg rfsh_not_mreq, u11c_g2b_n;

    rfsh_not_mreq = cpu_rfsh_n & ~cpu_mreq_n;
    rom_ce_n      = !(rfsh_not_mreq && cpu_addr[15:14] == 2'b00);
    ram_cs        = !(rfsh_not_mreq && cpu_addr[15:13] == 3'b010);
    k5289_ld1     = !(rfsh_not_mreq && cpu_addr[15:13] == 3'b101);
    k5289_ld2     = !(rfsh_not_mreq && cpu_addr[15:13] == 3'b110);
    u11c_g2b_n    = !(rfsh_not_mreq && cpu_addr[15:13] == 3'b111);

    data_oc_n     = !(~u11c_g2b_n && cpu_addr[2:0] == 3'b001);
    k5289_tg1     = !(~u11c_g2b_n && cpu_addr[2:0] == 3'b011);
    k5289_tg2     = !(~u11c_g2b_n && cpu_addr[2:0] == 3'b100);
    ay7_sel_n     = !(~u11c_g2b_n && cpu_addr[2:0] == 3'b101);
    ay8_sel_n     = !(~u11c_g2b_n && cpu_addr[2:0] == 3'b110);
    filter_ff_clk = !(~u11c_g2b_n && cpu_addr[2:0] == 3'b111);
end

// Z80 data input mux.
always @(*) begin
    case (1'b1)
        ~rom_ce_n:             cpu_data_in = z80_data;
        ~ram_cs && ~cpu_rd_n:  cpu_data_in = cpu_ram_data;
        ~ay7_bdir && ay7_bc1:  cpu_data_in = ay7_data;
        ~ay8_bdir && ay8_bc1:  cpu_data_in = ay8_data;
        ~data_oc_n:            cpu_data_in = data_ff_out;
        default:               cpu_data_in = 8'hff;
    endcase
end

always @(posedge clk) begin
    if (audio_div_cen) begin
        clk_div_cnt <= clk_div_cnt + 8'd1;
        ay8_ioa_in  <= {4'b0, clk_div_cnt[7:4]};
    end
end

// JTFRAME channel RAM, K5289, and PSG instances.
jtframe_ram #(.AW(11)) u_audio_cpu_ram(
    .clk  (clk),
    .cen  (cpu_cen),
    .addr (cpu_addr[10:0]),
    .data (cpu_data_out),
    .we   (ram_we),
    .q    (cpu_ram_data)
);

jtnemsis_k5289 u_k5289(
    .rst_n    (cpu_rst_n),
    .clk      (clk),
    .sound_cen(cen_3p5),
    .ld1      (k5289_ld1),
    .tg1      (k5289_tg1),
    .ld2      (k5289_ld2),
    .tg2      (k5289_tg2),
    .counter  (cpu_addr[11:0]),
    .q1       (prom1_addr),
    .q2       (prom2_addr)
);

/* verilator lint_off PINCONNECTEMPTY */
jt49_bus #(.COMP(3'd6)) u_ay_7(
    .rst_n   (cpu_rst_n),
    .clk     (clk),
    .clk_en  (cen_1p7),
    .bdir    (ay7_bdir),
    .bc1     (ay7_bc1),
    .din     (cpu_data_out),
    .sel     (1'b1),
    .dout    (ay7_data),
    .sound   (ay7e),
    .A       (),
    .B       (),
    .C       (),
    .sample  (),
    .IOA_in  (8'b0),
    .IOA_out (ay7_ioa_out),
    .IOB_in  (8'b0),
    .IOB_out (ay7_iob_out),
    .IOA_oe  (),
    .IOB_oe  ()
);

jt49_bus #(.COMP(3'd6)) u_ay_8(
    .rst_n   (cpu_rst_n),
    .clk     (clk),
    .clk_en  (cen_1p7),
    .bdir    (ay8_bdir),
    .bc1     (ay8_bc1),
    .din     (cpu_data_out),
    .sel     (1'b1),
    .dout    (ay8_data),
    .sound   (ay8e),
    .A       (),
    .B       (),
    .C       (),
    .sample  (),
    .IOA_in  (ay8_ioa_in),
    .IOA_out (),
    .IOB_in  (8'b0),
    .IOB_out (),
    .IOA_oe  (),
    .IOB_oe  ()
);
/* verilator lint_on PINCONNECTEMPTY */

// Sound-on interrupt latch and filter-control/address data latches.
jtframe_ff u_sound_on_ff(
    .rst     (rst),
    .clk     (clk),
    .cen     (1'b1),
    .sigedge (sound_on_n),
    .set     (1'b0),
    .clr     (cpu_irq_clear),
    .din     (1'b1),
    .q       (),
    .qn      (cpu_int_n)
);

jtframe_ff #( .W( 2 ), .EDGE_RESET( 1'b1 ) ) u_ay_filter_ff(
    .rst     ( rst ),
    .clk     ( clk ),
    .cen     ( 1'b1 ),
    .din     ( filter_addr ),
    .q       ( filter_control ),
    .qn      (  ),
    .set     ( 2'd0 ),
    .clr     ( 2'd0 ),
    .sigedge ( filter_ff_clk_edge_2 )
);

jtframe_ff #( .W( 8 ), .EDGE_RESET( 1'b1 ) ) u_data_ff(
    .rst     ( rst ),
    .clk     ( clk ),
    .cen     ( 1'b1 ),
    .din     ( main_db ),
    .q       ( data_ff_out ),
    .qn      (  ),
    .set     ( 8'd0 ),
    .clr     ( 8'd0 ),
    .sigedge ( data_n_edge_8 )
);

// Z80 is last so its pin mapping stays together after the supporting logic.
/* verilator lint_off PINCONNECTEMPTY */
T80s u_audio_cpu(
    .RFSH_n  (cpu_rfsh_n),
    .MREQ_n  (cpu_mreq_n),
    .INT_n   (cpu_int_n),
    .IORQ_n  (cpu_iorq_n),
    .RESET_n (cpu_rst_n),
    .NMI_n   (1'b1),
    .BUSRQ_n (1'b1),
    .WAIT_n  (1'b1),
    .BUSAK_n (),
    .CLK     (clk),
    .M1_n    (),
    .HALT_n  (),
    .CEN     (cpu_cen),
    .RD_n    (cpu_rd_n),
    .WR_n    (cpu_wr_n),
    .A       (cpu_addr),
    .DI      (cpu_data_in),
    .DOUT    (cpu_data_out),
    .OUT0    (1'b0)
);
/* verilator lint_on PINCONNECTEMPTY */

`else

assign z80_cs        = 1'b0;
assign z80_addr      = 14'd0;
assign wav1_addr     = 8'd0;
assign wav1_vol_addr = 8'd0;
assign wav2_addr     = 8'd0;
assign wav2_vol_addr = 8'd0;
assign ay7e          = 10'd0;
assign ay8e          = 10'd0;
assign wav1          = 8'd0;
assign wav2          = 8'd0;
assign rc33_en       = 1'b0;
assign rc47_en       = 1'b0;
initial st_dout = 8'd0;

`endif

endmodule
