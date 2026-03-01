`timescale 1ns/1ps


module test;

localparam BLOCK_BYTES = 256;
localparam BLOCKS      = 128;
localparam TOTAL_BYTES = BLOCK_BYTES * BLOCKS;
localparam STRLEN      = 1024;
localparam SDIN_LEAD   = 2; // cycles before sav_wait deassert


wire clk;
wire rst;

`include "test_tasks.vh"

reg         OSD_STATUS;
reg         downloading;
reg [1:0]   ram_save;
reg         ram_load;
reg         sav_change;
reg         sav_wait;

wire [7:0]  sd_buff_addr;
wire [7:0]  sd_buff_dout;
wire [7:0]  sd_buff_din;
wire        sd_buff_wr;
wire        sd_ack;
wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        bk_ena;
wire        sd_wait;

wire [15:0] sav_dout;
wire [15:0] sav_addr;
wire [1:0]  sav_wr;
wire        sav_ack;
wire [15:0] sav_din;
reg  [15:0] sav_din_r;

wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;

reg  [7:0] sd_image_read  [0:TOTAL_BYTES-1];
reg  [7:0] sd_image_write [0:TOTAL_BYTES-1];
integer i;
integer j;
reg [7:0] io_byte;

// HPS bus (minimal drive for IO)
wire [48:0] HPS_BUS;
reg         io_strobe;
reg         io_enable;
reg         fp_enable;
reg  [15:0] io_din;

// inouts for hps_io
wire [21:0] gamma_bus;
wire [35:0] EXT_BUS;

assign HPS_BUS[35] = fp_enable;
assign HPS_BUS[34] = io_enable;
assign HPS_BUS[33] = io_strobe;
assign HPS_BUS[31:16] = io_din;
assign gamma_bus = 22'd0;
assign EXT_BUS   = 36'd0;

// hps_io SD arrays (VDNUM=1)
wire [31:0] sd_lba_arr    [0:0];
wire [5:0]  sd_blk_cnt_arr[0:0];
wire [7:0]  sd_buff_din_arr [0:0];
wire [7:0]  sd_buff_dout_wide;
wire [13:0] sd_buff_addr_wide;
wire [0:0]  sd_rd_arr;
wire [0:0]  sd_wr_arr;
wire [0:0]  sd_ack_arr;

assign sd_lba_arr[0]     = sd_lba;
assign sd_blk_cnt_arr[0] = 6'd0;
assign sd_buff_din_arr[0]= sd_buff_din;
assign sd_rd_arr[0]      = sd_rd;
assign sd_wr_arr[0]      = sd_wr;
assign sd_ack            = sd_ack_arr[0];
assign sd_buff_addr      = sd_buff_addr_wide[7:0];
assign sd_buff_dout      = sd_buff_dout_wide[7:0];

localparam integer SAVE_AW = 14;
wire [15:0] ram_q0;
wire [15:0] ram_q1;
reg  [15:0] ram_d1;
reg  [SAVE_AW:1] ram_a1;
reg  [1:0]  ram_we1;

jtframe_dual_ram16 #(
    .AW            ( SAVE_AW        ),
    .SIMHEXFILE_LO ( "save_lo.hex"  ),
    .SIMHEXFILE_HI ( "save_hi.hex"  )
) u_save_ram (
    .clk0  ( clk                 ),
    .data0 ( sav_dout            ),
    .addr0 ( sav_addr[SAVE_AW:1] ),
    .we0   ( sav_wr              ),
    .q0    ( ram_q0              ),
    .clk1  ( clk                 ),
    .data1 ( ram_d1              ),
    .addr1 ( ram_a1              ),
    .we1   ( ram_we1             ),
    .q1    ( ram_q1              )
);
assign sav_din = sav_din_r;

// HPS IO instance (same as jtframe_mister.sv)
/* verilator lint_off PINMISSING */
hps_io #(
    .STRLEN(STRLEN), .PS2DIV(32), .WIDE(0), .BLKSZ(1), .VDNUM(1), .CONF_STR_BRAM(0)
) u_hps_io (
    .clk_sys         ( clk           ),
    .HPS_BUS         ( HPS_BUS        ),

    .joy_raw         ( 16'd0         ),
    .buttons         (               ),
    .status          (               ),
    .status_in       ( 128'd0        ),
    .status_set      ( 1'b0          ),
    .status_menumask ( 16'd0         ),
    .gamma_bus       ( gamma_bus     ),
    .direct_video    (               ),
    .forced_scandoubler(             ),
    .video_rotated   ( 1'b0          ),
    .new_vmode       ( 1'b0          ),

    .info_req        ( 1'b0          ),
    .info            ( 8'd0          ),

    .img_mounted     ( img_mounted   ),
    .img_readonly    ( img_readonly  ),
    .img_size        ( img_size      ),

    .sd_lba          ( sd_lba_arr     ),
    .sd_blk_cnt      ( sd_blk_cnt_arr),
    .sd_rd           ( sd_rd_arr      ),
    .sd_wr           ( sd_wr_arr      ),
    .sd_ack          ( sd_ack_arr     ),

    .sd_buff_addr    ( sd_buff_addr_wide ),
    .sd_buff_dout    ( sd_buff_dout_wide ),
    .sd_buff_din     ( sd_buff_din_arr   ),
    .sd_buff_wr      ( sd_buff_wr        ),

    .ioctl_download  (               ),
    .ioctl_wr        (               ),
    .ioctl_addr      (               ),
    .ioctl_dout      (               ),
    .ioctl_din       ( 8'd0          ),
    .ioctl_index     (               ),
    .ioctl_upload    (               ),
    .ioctl_upload_req( 1'b0          ),
    .ioctl_upload_index( 8'd0        ),
    .ioctl_rd        (               ),
    .ioctl_file_ext  (               ),
    .ioctl_wait      ( sd_wait       ),

    .ps2_kbd_clk_out (               ),
    .ps2_kbd_data_out(               ),
    .ps2_kbd_clk_in  ( 1'b0          ),
    .ps2_kbd_data_in ( 1'b0          ),
    .ps2_kbd_led_status(3'd0         ),
    .ps2_kbd_led_use ( 3'd0          ),
    .ps2_mouse_clk_out(              ),
    .ps2_mouse_data_out(             ),
    .ps2_mouse_clk_in( 1'b0          ),
    .ps2_mouse_data_in(1'b0          ),
    .ps2_key         (               ),
    .ps2_mouse       (               ),
    .ps2_mouse_ext   (               ),

    .joystick_0      (               ),
    .joystick_1      (               ),
    .joystick_2      (               ),
    .joystick_3      (               ),
    .joystick_4      (               ),
    .joystick_5      (               ),
    .joystick_l_analog_0(            ),
    .joystick_l_analog_1(            ),
    .joystick_l_analog_2(            ),
    .joystick_l_analog_3(            ),
    .joystick_l_analog_4(            ),
    .joystick_l_analog_5(            ),
    .joystick_r_analog_0(            ),
    .joystick_r_analog_1(            ),
    .joystick_r_analog_2(            ),
    .joystick_r_analog_3(            ),
    .joystick_r_analog_4(            ),
    .joystick_r_analog_5(            ),
    .joystick_0_rumble( 16'd0        ),
    .joystick_1_rumble( 16'd0        ),
    .joystick_2_rumble( 16'd0        ),
    .joystick_3_rumble( 16'd0        ),
    .joystick_4_rumble( 16'd0        ),
    .joystick_5_rumble( 16'd0        ),
    .paddle_0        (               ),
    .paddle_1        (               ),
    .paddle_2        (               ),
    .paddle_3        (               ),
    .paddle_4        (               ),
    .paddle_5        (               ),
    .spinner_0       (               ),
    .spinner_1       (               ),
    .spinner_2       (               ),
    .spinner_3       (               ),
    .spinner_4       (               ),
    .spinner_5       (               ),

    .sdram_sz        (               ),
    .RTC             (               ),
    .TIMESTAMP       (               ),
    .uart_mode       (               ),
    .uart_speed      (               ),
    .EXT_BUS         ( EXT_BUS       )
);
/* verilator lint_on PINMISSING */

jtframe_mister_cartsave uut(
    .clk         ( clk          ),
    .OSD_STATUS  ( OSD_STATUS   ),
    .io_strobe   ( HPS_BUS[33]  ),
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
    .sav_din     ( sav_din      ),
    .sav_dout    ( sav_dout     ),
    .sav_addr    ( sav_addr     ),
    .sav_wr      ( sav_wr       ),
    .sav_ack     ( sav_ack      )
);

jtframe_test_clocks #(.MAXFRAMES(100)) clocks(
    .rst        ( rst           ),
    .clk        ( clk           )
);

task ram_read_byte(input [15:0] addr, output reg [7:0] value);
    begin
        ram_we1 = 2'b00;
        ram_d1  = 16'h0000;
        ram_a1  = addr[15:1];
        @(posedge clk); @(posedge clk)
            value = addr[0] ? ram_q1[15:8] : ram_q1[7:0];
    end
endtask

// emulate SDRAM ok -> sav_wait (random 3-9 cycles after sav_ack)
reg sav_pending, ack_l;
integer sav_delay;
initial sav_din_r = 0;

always @(posedge clk) begin
    ack_l <= sav_ack;
    if (!sav_pending && sav_ack && !ack_l) begin
        sav_pending <= 1;
        sav_delay   <= $urandom_range(3, 9);
        sav_wait    <= 1;
    end else if (sav_pending) begin
        if (sav_delay == SDIN_LEAD) begin
            sav_din_r <= ram_q0;
        end
        if (sav_delay == 0) begin
            sav_wait    <= 0;
            sav_pending <= 0;
        end else begin
            sav_delay <= sav_delay - 1;
        end
    end else begin
        sav_wait <= 0;
    end
end

// HPS bus helpers
initial begin
    fp_enable = 1'b0;
    io_enable = 1'b0;
    io_strobe = 1'b0;
    io_din    = 16'h0000;
end

task io_write16(input [15:0] word);
    begin
        while (sd_wait) @(posedge clk);
        io_din = word;
        io_strobe = 1'b1;
        @(posedge clk);
        io_strobe = 1'b0;
        @(posedge clk);
    end
endtask

task io_read8(output [7:0] value);
    begin
        while (sd_wait) @(posedge clk);
        io_din = 16'h0000;
        io_strobe = 1'b1;
        @(posedge clk);
        io_strobe = 1'b0;
        @(posedge clk);
        value = HPS_BUS[7:0];
    end
endtask

task io_drop_enable;
    begin
        io_enable = 1'b0;
        @(posedge clk);
        io_enable = 1'b1;
        @(posedge clk);
    end
endtask

task hps_set_img(input [63:0] size);
    begin
        io_write16(16'h001D);
        io_write16(size[15:0]);
        io_write16(size[31:16]);
        io_write16(size[47:32]);
        io_write16(size[63:48]);
        io_drop_enable(); // reset byte counter
        io_write16(16'h001C);
        io_write16(16'h0001); // mounted, not readonly
    end
endtask

task hps_init;
    begin
        io_enable = 1'b0;
        @(posedge clk);
        io_enable = 1'b1;
        @(posedge clk);
        hps_set_img(64'd0);
    end
endtask

integer fd;
reg file_open;
reg hps_ready;

reg [31:0] hps_lba;
reg [ 7:0] hps_idx;
reg [ 3:0] hps_state;
reg [ 1:0] hps_read_pending;
reg hps_op_write, hps_saw_wait;
integer hps_latency, hps_tick;
reg [7:0] hps_last_byte;

localparam HPS_STROBE_DIV = 11;
localparam HPS_GAP_WRITE = 1;
localparam HPS_IDLE    = 4'd0;
localparam HPS_LAT     = 4'd1;
localparam HPS_PRE0    = 4'd2;
localparam HPS_PRE1    = 4'd3;
localparam HPS_CMD     = 4'd4;
localparam HPS_WAITACK = 4'd5;
localparam HPS_XFER    = 4'd6;
localparam HPS_DROP0   = 4'd7;
localparam HPS_DROP1   = 4'd8;

// HPS SD driver using real hps_io (byte-paced)
initial begin
    fd = 0;
    file_open = 0;
    hps_ready = 0;
    io_byte = 0;
    j = 0;
    hps_state = HPS_IDLE;
    hps_idx = 0;
    hps_lba = 0;
    hps_op_write = 0;
    hps_read_pending = 2'd0;
    hps_saw_wait = 0;
    hps_latency = 0;
    hps_tick = 0;
    hps_last_byte = 8'h00;

    @(negedge rst);
    repeat (2) @(posedge clk);

    io_enable = 1'b1;
    wait (hps_ready);

    forever begin
        @(posedge clk);

        if (io_strobe) io_strobe <= 1'b0;

        case (hps_state)
            HPS_IDLE: begin
                if (hps_ready && (sd_wr || sd_rd)) begin
                    hps_op_write <= sd_wr;
                    hps_lba <= sd_lba;
                    hps_latency <= $urandom_range(3, 9);
                    hps_state <= HPS_LAT;
                end
            end
            HPS_LAT: begin
                if (hps_latency <= 0) hps_state <= HPS_PRE0;
                else hps_latency <= hps_latency - 1;
            end
            HPS_PRE0: begin
                io_enable <= 1'b0;
                hps_state <= HPS_PRE1;
            end
            HPS_PRE1: begin
                io_enable <= 1'b1;
                hps_state <= HPS_CMD;
            end
            HPS_CMD: begin
                if (!sd_wait) begin
                    io_din <= hps_op_write ? 16'h0018 : 16'h0017;
                    io_strobe <= 1'b1;
                    hps_idx <= 0;
                    hps_tick <= 0;
                    hps_read_pending <= 2'd0;
                    hps_saw_wait <= 0;
                    if (hps_op_write && !file_open) begin
                        fd = $fopen("cartsave_out.sav", "wb");
                        if (fd == 0) begin
                            $display("FAIL: cannot open cartsave_out.sav");
                            $finish;
                        end
                        file_open = 1;
                    end
                    hps_state <= HPS_WAITACK;
                end
            end
            HPS_WAITACK: begin
                if (hps_op_write) begin
                    if (sd_wait) hps_saw_wait <= 1;
                    if (sd_ack && hps_saw_wait && !sd_wait) begin
                        hps_state <= HPS_XFER;
                    end
                end else begin
                    if (sd_ack) begin
                        hps_state <= HPS_XFER;
                    end
                end
            end
            HPS_XFER: begin
                if (!sd_ack) begin
                    hps_state <= HPS_WAITACK;
                end else if (hps_op_write) begin
                    if (hps_read_pending == 2'd1) begin
                        io_byte <= HPS_BUS[7:0];
                        hps_last_byte <= HPS_BUS[7:0];
                        sd_image_write[{hps_lba[6:0], hps_idx}] <= HPS_BUS[7:0];
                        if (file_open) $fwrite(fd, "%c", HPS_BUS[7:0]);
                        hps_read_pending <= 2'd0;
                        if (hps_idx == 8'hFF) hps_state <= HPS_DROP0;
                        else hps_idx <= hps_idx + 1'b1;
                    end else if (hps_read_pending != 2'd0) begin
                        hps_read_pending <= hps_read_pending - 1'b1;
                    end else if (hps_tick == 0) begin
                        hps_tick <= HPS_STROBE_DIV - 1;
                        if (!sd_wait) begin
                            io_din <= 16'h0000;
                            io_strobe <= 1'b1;
                            hps_read_pending <= 2'd2;
                        end else if (HPS_GAP_WRITE) begin
                            sd_image_write[{hps_lba[6:0], hps_idx}] <= hps_last_byte;
                            if (file_open) $fwrite(fd, "%c", hps_last_byte);
                            if (hps_idx == 8'hFF) hps_state <= HPS_DROP0;
                            else hps_idx <= hps_idx + 1'b1;
                        end
                    end else begin
                        hps_tick <= hps_tick - 1'b1;
                    end
                end else begin
                    if (hps_tick == 0) begin
                        hps_tick <= HPS_STROBE_DIV - 1;
                        if (!sd_wait) begin
                            io_din <= {8'h00, sd_image_read[{hps_lba[6:0], hps_idx}]};
                            io_strobe <= 1'b1;
                            if (hps_idx == 8'hFF) hps_state <= HPS_DROP0;
                            else hps_idx <= hps_idx + 1'b1;
                        end
                    end else begin
                        hps_tick <= hps_tick - 1'b1;
                    end
                end
            end
            HPS_DROP0: begin
                io_enable <= 1'b0;
                hps_state <= HPS_DROP1;
            end
            HPS_DROP1: begin
                io_enable <= 1'b1;
                if (file_open && hps_op_write && hps_lba[6:0] == 7'h7F) begin
                    $fclose(fd);
                    file_open = 0;
                end
                hps_state <= HPS_IDLE;
            end
            default: hps_state <= HPS_IDLE;
        endcase
    end
end

integer timeout_s;
task wait_save_done;
    begin
        timeout_s = 0;
        while (!(sd_lba[6:0] == 7'h7F && sd_ack == 0 && sd_wr == 0)) begin
            @(posedge clk);
            timeout_s = timeout_s + 1;
            if (timeout_s > 32'h200000) begin
                $display("FAIL: save timeout");
                $finish;
            end
        end
    end
endtask

integer timeout_l;
task wait_load_done;
    begin
        timeout_l = 0;
        while (!(sd_lba[6:0] == 7'h7F && sd_ack == 0 && sd_rd == 0)) begin
            @(posedge clk);
            timeout_l = timeout_l + 1;
            if (timeout_l > 32'h200000) begin
                $display("FAIL: load timeout");
                $finish;
            end
        end
    end
endtask

reg saving, loading, check_save, check_load;

initial begin
    {saving, loading, check_save, check_load}=0;
    OSD_STATUS = 0;
    downloading = 0;
    ram_save = 0;
    ram_load = 0;
    sav_change = 0;
    sav_pending = 0;
    sav_wait = 0;
    sav_delay = 0;

    ram_we1 = 2'b00;
    ram_d1  = 16'h0000;
    ram_a1  = {SAVE_AW{1'b0}};
    for (i = 0; i < TOTAL_BYTES; i = i + 1) begin
        sd_image_read[i] = 8'hA5 ^ i[7:0];
        sd_image_write[i] = 8'h00;
    end

    @(negedge rst);
    repeat (5) @(posedge clk);
    hps_init();
    hps_ready = 1;

    downloading = 1;
    hps_set_img(TOTAL_BYTES);
    repeat (10) @(posedge clk);
    downloading = 0;

    ram_save = 2'b10;
    @(posedge clk);
    ram_save = 2'b00;
    saving=1;

    wait_save_done();
    hps_set_img(TOTAL_BYTES);
    saving=0; check_save=1;

    for (i = 0; i < TOTAL_BYTES; i = i + 1) begin
        reg [7:0] b, write;
        write = sd_image_write[i];
        ram_read_byte(i[15:0], b);
        assert_msg(sd_image_write[i] == b, "save data mismatch");
    end
    check_save=0;

    @(posedge clk) ram_load = 1;
    @(posedge clk) ram_load = 0;
    loading=1;

    wait_load_done();
    loading=0;check_load=1;

    for (i = 0; i < TOTAL_BYTES; i = i + 1) begin
        reg [7:0] b, read;
        read = sd_image_read[i];
        ram_read_byte(i[15:0], b);
        assert_msg(b == sd_image_read[i], "load data mismatch");
    end

    check_load=0;
    pass();
end

endmodule
