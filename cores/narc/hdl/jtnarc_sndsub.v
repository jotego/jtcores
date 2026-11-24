/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-10-2026 */

module jtnarc_sndsub(
    input             rst,
    input             clk,
    input             cen8,
    input             board_rst,

    input      [ 7:0] comm,
    input             comm_st,

    output     [17:0] rom_addr,
    output            rom_cs,
    input      [ 7:0] rom_data,
    input             rom_ok,

    output reg [ 7:0] dac,
    output reg        cvsd_clk,
    output reg        cvsd_din
);

wire [15:0] A;
wire [ 7:0] cpu_dout, ram_dout;
wire        RnW, cpu_cen;
reg         cpu_rstn;
reg  [ 7:0] cpu_din, latch;
wire        firq_n;
reg         ram_cs, io_cs, cvsdc_cs, cvsdd_cs, dac_cs, port_cs, bank_cs;
reg  [ 3:0] bank;
reg  [ 1:0] chip;
reg         a15;

assign rom_cs   = A[15:14]!=2'b00;
assign rom_addr = { chip, a15, A[15], A[13:0] };

always @(posedge clk) cpu_rstn <= ~(rst | board_rst);

always @(*) begin
    ram_cs   = A[15:13]==3'b000;
    io_cs    = A[15:13]==3'b001;
    cvsdc_cs = io_cs && A[12:10]==3'd0;
    cvsdd_cs = io_cs && A[12:10]==3'd1;
    dac_cs   = io_cs && A[12:10]==3'd4;
    port_cs  = io_cs && A[12:10]==3'd5;
    bank_cs  = io_cs && A[12:10]==3'd6;
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
        rom_cs:  cpu_din <= rom_data;
        ram_cs:  cpu_din <= ram_dout;
        port_cs: cpu_din <= latch;
        default: cpu_din <= 8'hff;
    endcase
end

always @(posedge clk) begin
    if( rst )
        latch <= 0;
    else if( comm_st )
        latch <= comm;
end

wire        port_clr = cpu_cen & port_cs;

jtframe_edge #(.QSET(0)) u_firq(
    .rst    ( rst      ),
    .clk    ( clk      ),
    .edgeof ( comm_st  ),
    .clr    ( port_clr ),
    .q      ( firq_n   )
);

always @(posedge clk) begin
    if( rst ) begin
        bank     <= 0;
        dac      <= 0;
        cvsd_clk <= 0;
        cvsd_din <= 0;
    end else begin
        if( cpu_cen ) begin
            if( !RnW && bank_cs ) bank <= cpu_dout[3:0];
            if( cvsdc_cs ) cvsd_clk <= 1;
            if( cvsdd_cs ) cvsd_clk <= 0;
            if( !RnW && cvsdd_cs ) cvsd_din <= cpu_dout[0];
        end
        if( board_rst )
            dac <= 0;
        else if( cpu_cen && !RnW && dac_cs )
            dac <= cpu_dout;
    end
end

jtframe_sys6809 #(.RAM_AW(13)) u_cpu(
    .rstn     ( cpu_rstn ),
    .clk      ( clk      ),
    .cen      ( cen8     ),
    .cpu_cen  ( cpu_cen  ),
    .VMA      (          ),
    .nIRQ     ( 1'b1     ),
    .nFIRQ    ( firq_n   ),
    .nNMI     ( 1'b1     ),
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

endmodule
