/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jtcps3crc_main(
    input             rst,
    input             clk,
    input             cen,
    input             lvbl,

    input      [ 7:0] cache_data,
    input             cache_ok,
    input             cache_flushing,
    input             cache_flush_done,
    output     [25:0] cache_addr,
    output     [ 7:0] cache_din,
    output            cache_rd,
    output            cache_we,
    output            cache_flush,
    output     [ 0:0] cache_dsn,
    output     [ 7:0] cache_status,

    output     [ 9:0] text_addr,
    output     [ 7:0] text_din,
    input      [ 7:0] text_dout,
    output            text_we
);

localparam [1:0] OP_IDLE  = 2'd0,
                 OP_READ  = 2'd1,
                 OP_FLUSH = 2'd2;

reg         mpu_wr_l;
reg  [ 1:0] cache_op;
reg  [ 7:0] cache_din_l, cache_data_l;
reg  [25:0] cache_addr_l;
reg         cache_rd_l, cache_we_l, cache_flush_l;
reg         cache_busy, cache_done_l, cache_flush_done_l;

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
assign reg_dout     = mpu_addr[3:0]==4'h3 ? cache_data_l :
                      mpu_addr[3:0]==4'h4 ? cache_status :
                      mpu_addr[3:0]==4'h5 ? { 6'd0, ~lvbl, frame_irq } : 8'd0;
assign mpu_din      = ram_cs  ? ram_dout  :
                      text_cs ? text_dout :
                      reg_cs  ? reg_dout  :
                      rom_cs  ? rom_dout  : 8'h0;

assign cache_addr   = cache_addr_l;
assign cache_din    = cache_din_l;
assign cache_rd     = cache_rd_l;
assign cache_we     = cache_we_l;
assign cache_flush  = cache_flush_l;
assign cache_dsn    = 1'b0;
assign cache_status = { 4'd0, cache_flush_done_l, cache_flushing, cache_busy, cache_done_l };

always @(posedge clk) begin
    if( rst ) begin
        mpu_wr_l           <= 1'b0;
        cache_op           <= OP_IDLE;
        cache_addr_l       <= 26'd0;
        cache_din_l        <= 8'd0;
        cache_data_l       <= 8'd0;
        cache_rd_l         <= 1'b0;
        cache_we_l         <= 1'b0;
        cache_flush_l      <= 1'b0;
        cache_busy         <= 1'b0;
        cache_done_l       <= 1'b0;
        cache_flush_done_l <= 1'b0;
    end else begin
        mpu_wr_l      <= mpu_wr;
        cache_rd_l    <= 1'b0;
        cache_we_l    <= 1'b0;
        cache_flush_l <= 1'b0;

        if( reg_wr ) begin
            case( mpu_addr[3:0] )
                4'h0: cache_addr_l[ 7: 0] <= mpu_dout;
                4'h1: cache_addr_l[15: 8] <= mpu_dout;
                4'h2: cache_addr_l[23:16] <= mpu_dout;
                4'h3: cache_din_l         <= mpu_dout;
                4'h6: cache_addr_l[25:24] <= mpu_dout[1:0];
                default: begin
                end
            endcase
        end

        if( cmd_wr && mpu_dout[7] ) begin
            cache_busy         <= 1'b0;
            cache_done_l       <= 1'b0;
            cache_flush_done_l <= 1'b0;
            cache_op           <= OP_IDLE;
        end else if( cmd_wr && !cache_busy ) begin
            cache_done_l       <= 1'b0;
            cache_flush_done_l <= 1'b0;
            if( mpu_dout[1] ) begin
                cache_rd_l <= 1'b1;
                cache_busy <= 1'b1;
                cache_op   <= OP_READ;
            end else if( mpu_dout[2] ) begin
                cache_flush_l <= 1'b1;
                cache_busy    <= 1'b1;
                cache_op      <= OP_FLUSH;
            end else begin
                cache_op <= OP_IDLE;
            end
        end

        case( cache_op )
            OP_READ: begin
                if( cache_ok ) begin
                    cache_data_l <= cache_data;
                    cache_done_l <= 1'b1;
                    cache_busy   <= 1'b0;
                    cache_op     <= OP_IDLE;
                end
            end
            OP_FLUSH: begin
                if( cache_flush_done ) begin
                    cache_done_l       <= 1'b1;
                    cache_flush_done_l <= 1'b1;
                    cache_busy         <= 1'b0;
                    cache_op           <= OP_IDLE;
                end
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

`ifdef SIMULATION
reg [31:0] sim_found [0:3];
reg [3:0]  sim_match, sim_done, sim_pass_seen;
reg [1:0]  sim_bank;

always @(posedge clk) begin
    if( rst ) begin
        sim_done      <= 4'd0;
        sim_match     <= 4'd0;
        sim_pass_seen <= 4'd0;
        sim_found[0]  <= 32'd0;
        sim_found[1]  <= 32'd0;
        sim_found[2]  <= 32'd0;
        sim_found[3]  <= 32'd0;
    end else if( mpu_wr ) begin
        if( mpu_addr >= 16'h0030 && mpu_addr < 16'h0040 ) begin
            case( mpu_addr[3:0] )
                4'h0: sim_found[0][ 7: 0] <= mpu_dout;
                4'h1: sim_found[0][15: 8] <= mpu_dout;
                4'h2: sim_found[0][23:16] <= mpu_dout;
                4'h3: sim_found[0][31:24] <= mpu_dout;
                4'h4: sim_found[1][ 7: 0] <= mpu_dout;
                4'h5: sim_found[1][15: 8] <= mpu_dout;
                4'h6: sim_found[1][23:16] <= mpu_dout;
                4'h7: sim_found[1][31:24] <= mpu_dout;
                4'h8: sim_found[2][ 7: 0] <= mpu_dout;
                4'h9: sim_found[2][15: 8] <= mpu_dout;
                4'ha: sim_found[2][23:16] <= mpu_dout;
                4'hb: sim_found[2][31:24] <= mpu_dout;
                4'hc: sim_found[3][ 7: 0] <= mpu_dout;
                4'hd: sim_found[3][15: 8] <= mpu_dout;
                4'he: sim_found[3][23:16] <= mpu_dout;
                4'hf: sim_found[3][31:24] <= mpu_dout;
            endcase
        end
        if( mpu_addr >= 16'h0040 && mpu_addr < 16'h0044 ) begin
            sim_match[mpu_addr[1:0]] <= |mpu_dout;
        end
        if( mpu_addr == 16'h0017 ) begin
            sim_done <= mpu_dout[3:0];
            if( |(mpu_dout[3:0] & ~sim_done) ) begin
                casez( mpu_dout[3:0] & ~sim_done )
                    4'b???1: sim_bank = 2'd0;
                    4'b??10: sim_bank = 2'd1;
                    4'b?100: sim_bank = 2'd2;
                    default: sim_bank = 2'd3;
                endcase
                $display("CPS3CRC simulation monitor: bank%0d done crc=%08x match=%0d",
                         sim_bank, sim_found[sim_bank], sim_match[sim_bank]);
                if( sim_match[sim_bank] ) begin
                    sim_pass_seen[sim_bank] <= 1'b1;
                    if( &(sim_pass_seen | (4'b0001 << sim_bank)) ) begin
                        $display("PASS: CPS3CRC simulation monitor: all banks matched expected CRCs");
                        $finish;
                    end
                end
            end
        end
    end
end
`endif

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
