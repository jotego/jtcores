/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-10-2026 */

module jtnarc_sndmain #(parameter ACK_LEN=14'd15552)(
    input             rst,
    input             clk,
    input             cen8,
    input             cen_fm,
    input             cen_fm2,
    input             cen192,
    input             board_rst,

    input      [ 7:0] scd,
    input             strobe,
    input             nmi_n,

    output reg [ 7:0] comm,
    output reg        comm_st,
    output reg [ 7:0] tb,
    output reg        ack_n,

    output     [16:0] rom_addr,
    output            rom_cs,
    input      [ 7:0] rom_data,
    input             rom_ok,

    output reg [ 7:0] dac,
    output signed [15:0] fm_l,
    output signed [15:0] fm_r
);

wire [15:0] A;
wire [ 7:0] cpu_dout, ram_dout, fm_dout;
wire        RnW, cpu_cen, firq_n;
reg         cpu_rstn;
reg  [ 7:0] cpu_din, call;
wire        irq_n;
wire        fm_csn, fm_wrn, fm_rst;
reg  [13:0] ack_cnt;
reg         ram_cs, io_cs, rom_win, fm_cs, tb_cs, comm_cs, dac_cs, port_cs, bank_cs, sync_cs;
reg  [ 3:0] bank;
reg  [ 1:0] chip;
reg         a15;

assign fm_rst   = ~cpu_rstn;
assign fm_csn   = ~fm_cs;
assign fm_wrn   = RnW;
assign rom_cs   = rom_win && chip[1];
assign rom_addr = { chip[0], a15, A[15], A[13:0] };

always @(posedge clk) cpu_rstn <= ~(rst | board_rst);

always @(*) begin
    ram_cs  = A[15:13]==3'b000;
    io_cs   = A[15:13]==3'b001;
    rom_win = A[15:14]!=2'b00;
    fm_cs   = io_cs && A[12:10]==3'd0;
    tb_cs   = io_cs && A[12:10]==3'd2;
    comm_cs = io_cs && A[12:10]==3'd3;
    dac_cs  = io_cs && A[12:10]==3'd4;
    port_cs = io_cs && A[12:10]==3'd5;
    bank_cs = io_cs && A[12:10]==3'd6;
    sync_cs = io_cs && A[12:10]==3'd7;
    if( A[15:14]==2'b11 ) begin
        chip = 2'd3;
        a15  = 1;
    end else begin
        chip = bank[2:1];
        a15  = bank[0];
    end
end

always @(posedge clk) begin
    case( 1'b1 )
        rom_win: cpu_din <= rom_cs ? rom_data : 8'hff;
        ram_cs:  cpu_din <= ram_dout;
        fm_cs:   cpu_din <= fm_dout;
        port_cs: cpu_din <= call;
        default: cpu_din <= 8'hff;
    endcase
end

always @(posedge clk) begin
    if( rst )
        call <= 0;
    else if( strobe )
        call <= scd;
end

wire        port_clr = cpu_cen & port_cs;

jtframe_edge #(.QSET(0)) u_irq(
    .rst    ( rst      ),
    .clk    ( clk      ),
    .edgeof ( strobe   ),
    .clr    ( port_clr ),
    .q      ( irq_n    )
);

always @(posedge clk) begin
    if( rst ) begin
        bank    <= 0;
        tb      <= 0;
        comm    <= 0;
        comm_st <= 0;
        dac     <= 0;
    end else begin
        comm_st <= 0;
        if( cpu_cen ) begin
            if( !RnW && bank_cs ) bank <= cpu_dout[3:0];
            if( !RnW && tb_cs   ) tb   <= cpu_dout;
            if( !RnW && comm_cs ) comm <= cpu_dout;
            if( comm_cs ) comm_st <= 1;
        end
        if( board_rst )
            dac <= 0;
        else if( cpu_cen && !RnW && dac_cs )
            dac <= cpu_dout;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        ack_cnt <= 0;
        ack_n   <= 1;
    end else begin
        if( cpu_cen && sync_cs )
            ack_cnt <= ACK_LEN;
        else if( cen192 && ack_cnt!=0 )
            ack_cnt <= ack_cnt-1'd1;
        ack_n <= ack_cnt==0;
    end
end

jtframe_sys6809 #(.RAM_AW(13)) u_cpu(
    .rstn     ( cpu_rstn ),
    .clk      ( clk      ),
    .cen      ( cen8     ),
    .cpu_cen  ( cpu_cen  ),
    .VMA      (          ),
    .nIRQ     ( irq_n    ),
    .nFIRQ    ( firq_n   ),
    .nNMI     ( nmi_n    ),
    .irq_ack  (          ),
    .bus_busy ( 1'b0     ),
    .A        ( A        ),
    .RnW      ( RnW      ),
    .ram_cs   ( ram_cs   ),
    .rom_cs   ( rom_cs   ),
    .rom_ok   ( rom_ok   ),
    .ram_dout ( ram_dout ),
    .cpu_dout ( cpu_dout ),
    .cpu_din  ( cpu_din  )
);

jt51 u_jt51(
    .rst    ( fm_rst   ),
    .clk    ( clk      ),
    .cen    ( cen_fm   ),
    .cen_p1 ( cen_fm2  ),
    .cs_n   ( fm_csn   ),
    .wr_n   ( fm_wrn   ),
    .a0     ( A[0]     ),
    .din    ( cpu_dout ),
    .dout   ( fm_dout  ),
    .ct1    (          ),
    .ct2    (          ),
    .irq_n  ( firq_n   ),
    .sample (          ),
    .left   (          ),
    .right  (          ),
    .xleft  ( fm_l     ),
    .xright ( fm_r     )
);

endmodule
