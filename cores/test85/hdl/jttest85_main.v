/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jttest85_main(
    input             rst,
    input             clk,
    input             cen,
    input             lvbl,

    input      [ 7:0] sdram_data,
    input             sdram_ok,
    output     [22:0] sdram_addr,
    output     [ 7:0] sdram_din,
    output            sdram_cs,
    output            sdram_we,
    output     [ 1:0] sdram_dsn,
    output     [ 7:0] sdram_status,

    output     [ 9:0] text_addr,
    output     [ 7:0] text_din,
    input      [ 7:0] text_dout,
    output            text_we
);

localparam [1:0] OP_IDLE  = 2'd0,
                 OP_READ  = 2'd1,
                 OP_WRITE = 2'd2,
                 OP_FLUSH = 2'd3;

reg         mpu_wr_l;
reg  [ 1:0] sdram_op;
reg  [ 7:0] sdram_din_l, sdram_data_l;
reg  [22:0] sdram_addr_l;
reg         sdram_cs_l, sdram_we_l;
reg         sdram_busy, sdram_done_l, sdram_flush_done_l;

wire        mpu_wr, mpu_rd, ram_cs, text_cs, reg_cs, rom_cs;
wire        reg_wr, cmd_wr, frame_irq, frame_irq_edge, frame_irq_clr;
wire [15:0] mpu_addr;
wire [ 7:0] mpu_din, mpu_dout, ram_dout, reg_dout, rom_dout;

assign ram_cs       = mpu_addr[15:9]==7'd0;
assign text_cs      = mpu_addr[15:10]==6'b001000;
assign reg_cs       = mpu_addr[15:4]==12'h300;
assign rom_cs       = mpu_addr[15:14]==2'b11;
assign reg_wr       = mpu_wr & reg_cs & ~mpu_wr_l;
assign cmd_wr        = reg_wr & mpu_addr[3:0]==4'h4;
assign frame_irq_edge= ~lvbl;
assign frame_irq_clr = reg_cs & mpu_addr[3:0]==4'h5 & (mpu_rd | mpu_wr);

assign text_addr    = mpu_addr[9:0];
assign text_din     = mpu_dout;
assign text_we      = mpu_wr & text_cs;
assign reg_dout     = mpu_addr[3:0]==4'h3 ? sdram_data_l :
                      mpu_addr[3:0]==4'h4 ? sdram_status :
                      mpu_addr[3:0]==4'h5 ? { 6'd0, ~lvbl, frame_irq } : 8'd0;
assign mpu_din      = ram_cs  ? ram_dout  :
                      text_cs ? text_dout :
                      reg_cs  ? reg_dout  :
                      rom_cs  ? rom_dout  : 8'h0;

assign sdram_addr   = sdram_addr_l;
assign sdram_din    = sdram_din_l;
assign sdram_cs     = sdram_cs_l;
assign sdram_we     = sdram_we_l;
assign sdram_dsn    = { ~sdram_addr_l[0], sdram_addr_l[0] };
assign sdram_status = { 4'd0, sdram_flush_done_l, 1'b0, sdram_busy, sdram_done_l };

always @(posedge clk) begin
    if( rst ) begin
        mpu_wr_l           <= 1'b0;
        sdram_op           <= OP_IDLE;
        sdram_addr_l       <= 23'd0;
        sdram_din_l        <= 8'd0;
        sdram_data_l       <= 8'd0;
        sdram_cs_l         <= 1'b0;
        sdram_we_l         <= 1'b0;
        sdram_busy         <= 1'b0;
        sdram_done_l       <= 1'b0;
        sdram_flush_done_l <= 1'b0;
    end else begin
        mpu_wr_l      <= mpu_wr;

        if( reg_wr ) begin
            case( mpu_addr[3:0] )
                4'h0: sdram_addr_l[ 7: 0] <= mpu_dout;
                4'h1: sdram_addr_l[15: 8] <= mpu_dout;
                4'h2: sdram_addr_l[22:16] <= mpu_dout[6:0];
                4'h3: sdram_din_l         <= mpu_dout;
                default: begin
                end
            endcase
        end

        if( cmd_wr && !sdram_busy ) begin
            sdram_done_l       <= 1'b0;
            sdram_flush_done_l <= 1'b0;
            if( mpu_dout[0] ) begin
                sdram_cs_l   <= 1'b1;
                sdram_we_l   <= 1'b1;
                sdram_busy   <= 1'b1;
                sdram_op     <= OP_WRITE;
            end else if( mpu_dout[1] ) begin
                sdram_cs_l   <= 1'b1;
                sdram_we_l   <= 1'b0;
                sdram_busy   <= 1'b1;
                sdram_op     <= OP_READ;
            end else if( mpu_dout[2] ) begin
                sdram_done_l       <= 1'b1;
                sdram_flush_done_l <= 1'b1;
                sdram_op           <= OP_FLUSH;
            end else begin
                sdram_op <= OP_IDLE;
            end
        end

        case( sdram_op )
            OP_READ: begin
                if( sdram_ok ) begin
                    sdram_data_l <= sdram_data;
                    sdram_done_l <= 1'b1;
                    sdram_busy   <= 1'b0;
                    sdram_cs_l   <= 1'b0;
                    sdram_op     <= OP_IDLE;
                end
            end
            OP_WRITE: begin
                if( sdram_ok ) begin
                    sdram_done_l <= 1'b1;
                    sdram_busy   <= 1'b0;
                    sdram_cs_l   <= 1'b0;
                    sdram_we_l   <= 1'b0;
                    sdram_op     <= OP_IDLE;
                end
            end
            OP_FLUSH: begin
                sdram_op <= OP_IDLE;
            end
            default: begin
            end
        endcase
    end
end

jt65c02 u_cpu(
    .rst        ( rst      ),
    .clk        ( clk      ),
    .cen        ( cen      ),
    .irq        ( frame_irq ),
    .nmi        ( 1'b0     ),
    .wr         ( mpu_wr   ),
    .rd         ( mpu_rd   ),
    .addr       ( mpu_addr ),
    .din        ( mpu_din  ),
    .dout       ( mpu_dout )
);

jtframe_edge u_frame_irq(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .edgeof     ( frame_irq_edge ),
    .clr        ( frame_irq_clr ),
    .q          ( frame_irq     )
);

jtframe_ram #(
    .AW      ( 9 ),
    .DW      ( 8 )
) u_work_ram(
    .clk     ( clk            ),
    .cen     ( 1'b1           ),
    .data    ( mpu_dout       ),
    .addr    ( mpu_addr[8:0]  ),
    .we      ( mpu_wr & ram_cs ),
    .q       ( ram_dout       )
);

jtframe_ram #(
    .AW      ( 14         ),
    .DW      (  8         ),
    .SYNFILE ( "boot.hex" )
) u_boot_rom(
    .clk     ( clk             ),
    .cen     ( 1'b1            ),
    .data    ( 8'd0            ),
    .addr    ( mpu_addr[13:0]  ),
    .we      ( 1'b0            ),
    .q       ( rom_dout        )
);

endmodule
