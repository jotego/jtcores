/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtslap_main(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             cpu_cen, mcu_cen,
    input             LVBL,
    input       [8:0] hdump,
    input             dip_pause,
    input             a76,
    input             tigerh,
    output     [15:0] cpu_addr,
    output      [7:0] cpu_dout,
    output            ram_we, sha_we, objram_we,
    output      [1:0] scrram_we, fixram_we,
    input       [7:0] ram_dout, sha_dout, objram_dout,
    input      [15:0] scrram_dout, fixram_dout,
    output            sound_en,
    output reg        sha_cs,
    input             sha_ok,
    output      [8:0] scrx,
    output      [7:0] scry,
    output            flip,
    output     [10:0] mcu_addr,
    input       [7:0] mcu_data,
    output     [15:0] main_addr,
    output reg        main_cs,
    input       [7:0] main_data,
    input             main_ok,
    input       [1:0] ioctl_addr,
    output      [7:0] ioctl_din,
    input       [7:0] debug_bus,
    output      [7:0] st_dout
);

wire [1:0] mmr_addr;
wire [7:0] mmr_din;
wire       mmr_cs;
`ifndef NOMAIN
wire        rst_n, mreq_n, iorq_n, wr_n, rd_n, rfsh_n;
wire        cpu_acc, cpu_wr, cpu_rd, irq, int_clr, irq_trigger, wait_n, video_wait_n;
reg         ram_cs, objram_cs, scrram_cs, fixram_cs, mmr_main_cs, mcu_cs;
reg  [7:0]  cpu_din, control;
wire [7:0]  mcu_dout, scroll_data;
wire [1:0]  scroll_wr;
wire        ibf, obf, mcu_flip, host_wr, host_rd;
reg         mcu_rst, flip_l;
wire        nx_flip;

assign rst_n = ~rst;
assign sound_en = control[0];
assign cpu_acc = !mreq_n && rfsh_n;
assign cpu_wr = cpu_acc && !wr_n;
assign cpu_rd = cpu_acc && !rd_n;
assign ram_we = ram_cs && cpu_wr;
assign sha_we = sha_cs && cpu_wr && sha_ok;
assign objram_we = objram_cs && cpu_wr;
assign scrram_we = {2{scrram_cs && cpu_wr}} & {cpu_addr[11],~cpu_addr[11]};
assign fixram_we = {2{fixram_cs && cpu_wr}} & {cpu_addr[11],~cpu_addr[11]};
assign main_addr = cpu_addr[15] && !tigerh ? {1'b1,control[4],cpu_addr[13:0]} : cpu_addr;

// Tiger-Heli predates the extra tile-RAM WAIT circuitry on the A77 board.
assign wait_n = (!sha_cs || sha_ok) && (tigerh || video_wait_n);
assign irq_trigger = !LVBL && dip_pause && control[3];
assign int_clr = !control[3];
assign host_wr = mcu_cs && cpu_wr;
assign host_rd = mcu_cs && cpu_rd;
assign nx_flip = a76 || tigerh ? ~control[1] : mcu_flip;
assign mmr_cs = mmr_main_cs && cpu_wr || |scroll_wr || nx_flip!=flip_l;
assign mmr_addr = |scroll_wr ? {1'b0,scroll_wr[1]} :
                  mmr_main_cs && cpu_wr ? cpu_addr[1:0] : 2'd3;
assign mmr_din = |scroll_wr ? scroll_data :
                mmr_main_cs && cpu_wr ? cpu_dout : {7'd0,nx_flip};

always @* begin
    main_cs     = cpu_rd  && cpu_addr[15:14]!=2'b11;
    ram_cs      = cpu_acc && cpu_addr[15:11]==5'b11000;
    sha_cs      = cpu_acc && cpu_addr[15:11]==5'b11001;
    scrram_cs   = cpu_acc && cpu_addr[15:12]==4'hd;
    objram_cs   = cpu_acc && cpu_addr[15:11]==5'b11100;
    mmr_main_cs = cpu_acc && cpu_addr[15:11]==5'b11101 && cpu_addr[1:0]!=3;
    mcu_cs      = cpu_acc && cpu_addr[15:11]==5'b11101 && cpu_addr[1:0]==3;
    fixram_cs   = cpu_acc && cpu_addr[15:12]==4'hf;
    cpu_din = !iorq_n ? {5'd0,~obf,~ibf,~LVBL} :
              main_cs ? main_data :
              ram_cs ? ram_dout :
              sha_cs ? sha_dout :
              objram_cs ? objram_dout :
              scrram_cs ? (cpu_addr[11] ? scrram_dout[15:8] : scrram_dout[7:0]) :
              fixram_cs ? (cpu_addr[11] ? fixram_dout[15:8] : fixram_dout[7:0]) :
              mcu_cs ? mcu_dout : 8'hff;
end

always @(posedge clk) begin
    if(rst) begin
        control <= 0;
        flip_l <= 0;
    end else begin
        flip_l <= nx_flip;
        if(cpu_cen && !iorq_n && !wr_n) control[cpu_addr[3:1]] <= cpu_addr[0];
    end
end

// U9J Q7 drives the 68705's active-low RESET pin (0E/0F).
// Tiger-Heli uses global MCU reset, following MAME; its MCU wiring is absent from the PDF.
always @(posedge clk) mcu_rst <= rst || (!tigerh && !control[7]);

jtslap_wait u_wait(
    .rst    ( rst          ),
    .clk    ( clk          ),
    .pxl_cen( pxl_cen      ),
    .hdump  ( hdump        ),
    .scrx   ( scrx         ),
    .flip   ( flip         ),
    .fix_cs ( fixram_cs    ),
    .scr_cs ( scrram_cs    ),
    .wait_n ( video_wait_n )
);

jtslap_mcu u_mcu(
    .rst        ( mcu_rst      ),
    .clk        ( clk          ),
    .cen        ( mcu_cen      ),
    .tigerh     ( tigerh       ),
    .host_wr    ( host_wr      ),
    .host_rd    ( host_rd      ),
    .host_dout  ( cpu_dout     ),
    .host_din   ( mcu_dout     ),
    .ibf        ( ibf          ),
    .obf        ( obf          ),
    .flip       ( mcu_flip     ),
    .scroll_data( scroll_data  ),
    .scroll_wr  ( scroll_wr    ),
    .rom_addr   ( mcu_addr     ),
    .rom_data   ( mcu_data     )
);

jtframe_edge #(.QSET(0)) u_irq(
    .rst    ( rst          ),
    .clk    ( clk          ),
    .edgeof ( irq_trigger  ),
    .clr    ( int_clr      ),
    .q      ( irq          )
);

jtframe_z80 u_z80(
    .rst_n  ( rst_n    ),
    .clk    ( clk      ),
    .cen    ( cpu_cen  ),
    .wait_n ( wait_n   ),
    .int_n  ( irq      ),
    .nmi_n  ( 1'b1     ),
    .busrq_n( 1'b1     ),
    .m1_n   (          ),
    .mreq_n ( mreq_n   ),
    .iorq_n ( iorq_n   ),
    .rd_n   ( rd_n     ),
    .wr_n   ( wr_n     ),
    .rfsh_n ( rfsh_n   ),
    .halt_n (          ),
    .busak_n(          ),
    .A      ( cpu_addr ),
    .din    ( cpu_din  ),
    .dout   ( cpu_dout )
);
`else
assign cpu_addr=0, cpu_dout=0, ram_we=0, sha_we=0, objram_we=0;
assign scrram_we=0, fixram_we=0, sound_en=0, sha_cs=0;
assign mcu_addr=0, main_addr=0, mmr_cs=0, mmr_addr=0, mmr_din=0;
initial main_cs=0;
`endif

jtslap_video_mmr u_video_mmr(
    .rst       ( rst         ),
    .clk       ( clk         ),
    .cs        ( mmr_cs      ),
    .addr      ( mmr_addr    ),
    .rnw       ( 1'b0        ),
    .din       ( mmr_din     ),
    .scrx      ( scrx        ),
    .scry      ( scry        ),
    .flip      ( flip        ),
    .ioctl_addr( ioctl_addr  ),
    .ioctl_din ( ioctl_din   ),
    .debug_bus ( debug_bus   ),
    .st_dout   ( st_dout     )
);
endmodule
