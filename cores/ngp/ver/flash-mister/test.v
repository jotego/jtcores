`timescale 1ns/1ps

module test;


wire clk;
reg  rst;

`include "test_tasks.vh"

localparam BLOCK_BYTES = 256;
localparam MAX_BLOCKS  = 16;
localparam MAX_BYTES   = BLOCK_BYTES * MAX_BLOCKS;

integer minb;
integer maxb;

// cartsave interface
reg         OSD_STATUS;
reg         downloading, downloading_l;
reg  [ 1:0] ram_save;
reg         ram_load;

wire [31:0] sd_lba;
wire [ 7:0] sd_buff_din, sd_buff_addr, sd_buff_dout;
wire        sd_ack, sd_rd, sd_wr, sd_wait, sd_buff_wr;
wire        bk_ena, io_strobe;

wire [15:0] sav_dout, sav_addr, sav_din;
wire [ 1:0] sav_wr;
wire        sav_ack, sav_change, sav_wait, sav_done;
reg         done_l;

reg  [63:0] img_size;
reg         img_mounted, img_readonly;

// Save RAM - gs_mem
localparam integer GS_WORDS = 1<<15; // 32k words (64kB)
reg  [15:0] gs_data;
wire [20:1] gs_addr;
wire [15:0] gs_din;
wire [ 1:0] gs_dsn, gs_we0;
wire        gs_we, gs_cs, gs_ok;

wire [15:0] ram_q1;
reg  [15:0] ram_d1;
reg  [15:1] ram_a1;
reg  [ 1:0] ram_we1;

assign gs_ok  = 1'b1;
assign gs_we0 = gs_we & gs_cs ? ~gs_dsn : 2'b00;

always @(posedge clk) begin
    done_l <= sav_done;
    downloading_l <= downloading;
end

jtframe_dual_ram16 #(
    .AW            ( 15        )
) u_save_ram (
    .clk0  ( clk           ),
    .data0 ( gs_din        ),
    .addr0 ( gs_addr[15:1] ),
    .we0   ( gs_we0        ),
    .q0    ( gs_data       ),
    .clk1  ( clk           ),
    .data1 ( ram_d1        ),
    .addr1 ( ram_a1        ),
    .we1   ( ram_we1       ),
    .q1    ( ram_q1        )
);

// mister cartsave
jtframe_mister_cartsave u_cartsave(
    .clk         ( clk          ),
    .OSD_STATUS  ( OSD_STATUS   ),
    .io_strobe   ( io_strobe    ),
    .img_size    ( img_size     ),
    .img_mounted ( img_mounted  ),
    .img_readonly( img_readonly ),
    .ram_save    ( ram_save     ),
    .ram_load    ( ram_load     ),
    .downloading ( downloading  ),
    .sd_buff_addr( sd_buff_addr ),
    .sd_buff_dout( sd_buff_dout ),
    .sd_buff_din ( sd_buff_din  ),
    .sd_buff_wr  ( sd_buff_wr   ),
    .sd_ack      ( sd_ack       ),
    .sd_lba      ( sd_lba       ),
    .sd_rd       ( sd_rd        ),
    .sd_wr       ( sd_wr        ),
    .bk_ena      ( bk_ena       ),
    .sd_wait     ( sd_wait      ),
    .sav_change  ( sav_change   ),
    .sav_wait    ( sav_wait     ),
    .sav_done    ( sav_done     ),
    .sav_din     ( sav_din      ),
    .sav_dout    ( sav_dout     ),
    .sav_addr    ( sav_addr     ),
    .sav_wr      ( sav_wr       ),
    .sav_ack     ( sav_ack      )
);

// jtngp_flash
reg  [20:1] cpu_addr;
reg  [15:0] cpu_dout;
reg  [ 3:0] dev_type;
reg  [ 1:0] cpu_we;
reg         cpu_cs;
wire [20:1] cart_addr;
wire [15:0] cpu_din, cart_data, cart_din;
wire [ 1:0] cart_dsn;
wire        cpu_ok, rdy;
wire        cart, cart_we, cart_cs, cart_ok;

assign cart_ok   = 1'b1;
assign cart_data = 16'h0000;
assign cart      = downloading && !downloading_l;

jtngp_flash u_flash(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .dev_type   ( dev_type  ),
    // interface to CPU
    .cpu_addr   ( cpu_addr  ),
    .cpu_cs     ( cpu_cs    ),
    .cpu_we     ( cpu_we    ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   ),
    .rdy        ( rdy       ),
    .cpu_ok     ( cpu_ok    ),

    // interface to SDRAM
    .cart_addr  ( cart_addr ),
    .cart_we    ( cart_we   ),
    .cart_cs    ( cart_cs   ),
    .cart_ok    ( cart_ok   ),
    .cart_data  ( cart_data ),
    .cart_dsn   ( cart_dsn  ),
    .cart_din   ( cart_din  ),

    // save/load memory
    .cart       ( cart      ),
    .sav_addr   ( sav_addr  ),
    .sav_dout   ( sav_dout  ),
    .sav_wr     ( sav_wr    ),
    .sav_ack    ( sav_ack   ),
    .sav_din    ( sav_din   ),
    .sav_done   ( sav_done  ),
    .sav_wait   ( sav_wait  ),
    .sav_change ( sav_change),

    .gs_data    ( gs_data   ),
    .gs_din     ( gs_din    ),
    .gs_addr    ( gs_addr   ),
    .gs_dsn     ( gs_dsn    ),
    .gs_ok      ( gs_ok     ),
    .gs_we      ( gs_we     ),
    .gs_cs      ( gs_cs     )
);

// Tasks
integer i;
task clear_buffers;
    begin
        for (i = 0; i < MAX_BYTES; i = i + 1) begin
            hps.save_buf[i] = 8'h00;
            hps.load_buf[i] = 8'h00;
        end
    end
endtask

task clear_gs_mem;
    begin
        ram_d1  = 16'h0000;
        ram_we1 = 2'b11;
        for (i = 0; i < GS_WORDS; i = i + 1) begin
            @(posedge clk) ram_a1 = i[14:0];
        end
        ram_we1 = 0;
    end
endtask

task fill_gs_mem_pattern;
    input [7:0] seed;
    integer blk, off;
    reg [20:1] addr;
    reg [12:0] effb;
    reg [ 7:0] word;
    begin
        for (blk = minb; blk <= maxb; blk = blk + 1) begin
            effb = blk[12:0];
            for (off = 0; off < BLOCK_BYTES; off = off + 1) begin
                ram_a1  = {effb, off[7:1]};
                word    = seed ^ off[7:0] ^ effb[7:0];
                ram_d1  = {2{word}};
                ram_we1 = {off[0],~off[0]};
                repeat(2) @(posedge clk);
            end
        end
        ram_we1 = 0;
    end
endtask

// prepare load buffer with header + data pattern

task prepare_load_buffer;
    input [ 7:0] seed;
    integer addr;
    integer total_blocks;
    reg [20:1] gs_addr_local;
    reg [15:0] word;
    reg [12:0] effb;
    reg [ 7:0] lba;
    begin
        total_blocks = (maxb - minb + 1) + 1;
        for (addr = 0; addr < total_blocks*BLOCK_BYTES; addr = addr + 1) begin
            if (addr[15:8] == 8'h00 && addr[7:2] == 6'd0) begin
                case (addr[1:0])
                    2'd0: hps.load_buf[addr] = maxb[7:0];
                    2'd1: hps.load_buf[addr] = {3'b0, maxb[12:8]};
                    2'd2: hps.load_buf[addr] = minb[7:0];
                    2'd3: hps.load_buf[addr] = {3'b0, minb[12:8]};
                    default: hps.load_buf[addr] = 8'h00;
                endcase
            end else if (addr[15:8] == 8'h00) begin
                hps.load_buf[addr] = 8'h00;
            end else begin
                lba  = addr[15:8] - 8'd1;
                effb = minb + lba;
                gs_addr_local = {effb[12:0], addr[7:1]};
                word = {8'h00, seed} ^ {8'h00, addr[7:0]} ^ {8'h00, effb[7:0]};
                hps.load_buf[addr] = addr[0] ? word[15:8] : word[7:0];
            end
        end
    end
endtask

// check save buffer header + data

task check_save_buffer;
    input [7:0] seed;
    integer addr;
    integer total_blocks;
    reg [12:0] effb;
    reg [ 7:0] lba, exp, got;
    begin
        total_blocks = (maxb - minb + 1) + 1;
        for (addr = 0; addr < total_blocks*BLOCK_BYTES; addr = addr + 1) begin
            if (addr[15:8] == 8'h00 && addr[7:2] == 6'd0) begin
                case (addr[1:0])
                    2'd0: exp = maxb[7:0];
                    2'd1: exp = {3'b0, maxb[12:8]};
                    2'd2: exp = minb[7:0];
                    2'd3: exp = {3'b0, minb[12:8]};
                    default: exp = 8'h00;
                endcase
            end else if (addr[15:8] == 8'h00) begin
                exp = 8'h00;
            end else begin
                lba  = addr[15:8] - 8'd1;
                effb = minb + lba;
                exp = seed ^ addr[7:0] ^ effb[7:0];
            end
            got = hps.save_buf[addr];
            @(posedge clk)

            if (got !== exp) begin
                $display("FAIL: save mismatch addr %0d got %02x exp %02x", addr, hps.save_buf[addr], exp);
                repeat (10) @(posedge clk);
                $finish;
            end
        end
    end
endtask

task check_ram_after_load;
    input [7:0] seed;
    integer blk, off;
    reg [12:0] effb;
    reg [15:0] got;
    reg [ 7:0] exp;
    begin
        check_minmax();
        ram_we1 = 2'b00;
        for (blk = minb; blk <= maxb; blk = blk + 1) begin
            effb = blk[12:0];
            for (off = 0; off < BLOCK_BYTES; off = off + 2) begin
                ram_a1 = {effb,  off[7:1]};
                exp    =  seed ^ off[7:0] ^ effb[7:0];
                @(posedge clk);
                @(posedge clk);
                got = off[0] ? ram_q1[15:8] : ram_q1[7:0];
                if (got !== exp) begin
                    $display("FAIL: ram mismatch addr %0d got %04x exp %04x", ram_a1, got, exp);
                    $finish;
                end
            end
        end
    end
endtask

integer timeout_l, fin;
task wait_load_done;
    begin
        timeout_l = 0;
        fin = 0;
        while (!(sd_lba[6:0] == 7'h7F && sd_ack == 0 && sd_rd == 0) && !fin) begin
            @(posedge clk);
            timeout_l = timeout_l + 1;
            if(!sav_done && done_l) fin = 1;
            if (timeout_l > 32'h200000) begin
                $display("FAIL: load timeout");
                $finish;
            end
        end
    end
endtask

integer timeout_s;
task wait_save_done;
    begin
        timeout_s = 0;
        fin = 0;
        while (!(sd_lba[6:0] == 7'h7F && sd_ack == 0 && sd_wr == 0) && !fin) begin
            @(posedge clk);
            timeout_s = timeout_s + 1;
            if(!sav_done && done_l) fin = 1;
            if (timeout_s > 32'h200000) begin
                $display("FAIL: load timeout");
                $finish;
            end
        end
    end
endtask

task check_minmax;
    begin
        if (u_flash.auto_addr_min !== minb[12:0] || u_flash.auto_addr_max !== maxb[12:0]) begin
            $display("FAIL: auto_addr mismatch min %0h/%0h max %0h/%0h", u_flash.auto_addr_min, minb[12:0], u_flash.auto_addr_max, maxb[12:0]);
            $finish;
        end
    end
endtask

// ------------------------------------------------------------
// Main test
// ------------------------------------------------------------
initial begin
    rst = 1;
    OSD_STATUS = 0;
    downloading = 0;
    ram_save = 0;
    ram_load = 0;
    img_mounted = 1'b1;
    img_readonly = 1'b0;
    img_size = MAX_BYTES;

    minb = 13'h0002;
    maxb = 13'h0005;

    dev_type = 4'd8;
    cpu_addr = 0;
    cpu_cs = 0;
    cpu_we = 0;
    cpu_dout = 0;

    clear_buffers();
    clear_gs_mem();

    rst = 0;
    repeat (5) @(posedge clk);

    // enable bk_ena
    prepare_load_buffer(8'h5A);
    downloading = 1;
    repeat (4) @(posedge clk);
    downloading = 0;
    wait (sd_rd); wait (!sd_rd);

    wait_load_done();
    check_ram_after_load(8'h5A);

    // save path: fill gs_mem and check save buffer
    fill_gs_mem_pattern(8'hA2);
    clear_buffers();
    repeat (50) @(posedge clk);
    ram_save = 2'b10;
    @(posedge clk);
    ram_save = 2'b00;
    wait (sd_wr); wait (!sd_wr);
    wait_save_done();
    check_save_buffer(8'hA2);

    pass();
end


jtframe_test_clocks clocks(
    .rst (     ),
    .clk ( clk )
);

hps_io_simple #(
    .BLOCK_BYTES ( BLOCK_BYTES ),
    .MAX_BYTES   ( MAX_BYTES   )
) hps (
    .clk          ( clk          ),
    .rst          ( rst          ),
    .sd_lba       ( sd_lba       ),
    .sd_rd        ( sd_rd        ),
    .sd_wr        ( sd_wr        ),
    .sd_wait      ( sd_wait      ),
    .sd_buff_din  ( sd_buff_din  ),
    .io_strobe    ( io_strobe    ),
    .sd_ack       ( sd_ack       ),
    .sd_buff_addr ( sd_buff_addr ),
    .sd_buff_dout ( sd_buff_dout ),
    .sd_buff_wr   ( sd_buff_wr   )
);

endmodule

// ------------------------------------------------------------------
// Minimal HPS model (no HPS bus, only what cartsave needs)
// ------------------------------------------------------------------
module hps_io_simple #(
    parameter BLOCK_BYTES = 256,
    parameter MAX_BYTES   = 4096
) (
    input             clk,
    input             rst,
    input      [31:0] sd_lba,
    input             sd_rd,
    input             sd_wr,
    input             sd_wait,
    input      [ 7:0] sd_buff_din,
    output reg        io_strobe,
    output reg        sd_ack,
    output reg [ 7:0] sd_buff_addr,
    output reg [ 7:0] sd_buff_dout,
    output reg        sd_buff_wr
);

    reg [7:0] load_buf [0:MAX_BYTES-1];
    reg [7:0] save_buf [0:MAX_BYTES-1];

    reg [8:0] addr;
    reg [7:0] saved_val;
    reg [2:0] b_wr;
    reg [1:0] cooldown;
    reg active, mode_load;

    integer idx;

    initial begin
        io_strobe    = 0;
        sd_ack       = 0;
        sd_buff_addr = 0;
        sd_buff_dout = 0;
        sd_buff_wr   = 0;
        saved_val    = 0;
        active       = 0;
        mode_load    = 0;
        addr         = 0;
        cooldown     = 0;
        for (idx = 0; idx < MAX_BYTES; idx = idx + 1) begin
            load_buf[idx] = 8'h00;
            save_buf[idx] = 8'h00;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            sd_ack     <= 1'b0;
            active     <= 1'b0;
            mode_load  <= 1'b0;
            addr       <= 9'h00;
            cooldown   <= 2'd0;
            io_strobe  <= 1'b0;
            sd_buff_wr <= 1'b0;
            b_wr       <= 1'b0;
            saved_val  <= 1'b0;
        end else begin
            io_strobe  <= 1'b0;
            sd_buff_wr <= b_wr[0];
            if(b_wr[2] && (~&sd_buff_addr)) sd_buff_addr <= sd_buff_addr + 1'b1;
            b_wr <= (b_wr<<1);
            if (!active && cooldown == 0) begin
                if (sd_rd || sd_wr) begin
                    active    <= 1'b1;
                    io_strobe <= 1'b1;
                    mode_load <= sd_rd;
                    addr      <= 9'h00;
                end
            end else if (active) begin
                if(!sd_ack) begin
                    sd_ack    <= 1'b1;
                    sd_buff_addr <= addr[7:0];
                end else if (!sd_wait && !(sd_rd || sd_wr)) begin
                    if(io_strobe) begin
                        if (mode_load) begin
                            sd_buff_dout <= load_buf[{sd_lba[7:0], sd_buff_addr}];
                            b_wr   <= 3'b1;
                        end else begin
                            sd_buff_addr <= addr[7:0];
                            save_buf[{sd_lba[7:0], sd_buff_addr}] <= sd_buff_din;
                            saved_val    <= sd_buff_din;
                        end
                    end else begin
                        if (addr == 9'h100) begin
                            active   <= 1'b0;
                            cooldown <= 2'd2;
                        end else begin
                            io_strobe <= 1'b1;
                            addr <= addr + 1'b1;
                        end
                    end
                end
            end else if (cooldown != 0) begin
                cooldown <= cooldown - 1'b1;
                if (cooldown == 1) begin
                    sd_ack <= 1'b0;
                    addr   <= 9'h00;
                end
            end
        end
    end

endmodule
