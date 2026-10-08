// Dummy block for simulation only

module hps_io #(parameter STRLEN=0, PS2DIV=2000, WIDE=0, VDNUM=1, PS2WE=0,
     DW = (WIDE) ? 15 : 7, AW = (WIDE) ?  7 : 8, VD = VDNUM-1 )
(
    input             clk_sys,
    inout      [45:0] HPS_BUS,

    // parameter STRLEN and the actual length of conf_str have to match
    input [(8*STRLEN)-1:0] conf_str,

    input      [ 5:0] joy_raw,
    output     [15:0] joystick_0,
    output     [15:0] joystick_1,
    output     [15:0] joystick_2,
    output     [15:0] joystick_3,
    // output     [15:0] joystick_4,
    // output     [15:0] joystick_5,
    output     [15:0] joystick_analog_0,
    output     [15:0] joystick_analog_1,
    // output     [15:0] joystick_analog_2,
    // output     [15:0] joystick_analog_3,
    // output     [15:0] joystick_analog_4,
    // output     [15:0] joystick_analog_5,

    output      [1:0] buttons,
    output            forced_scandoubler,
    output            direct_video,

    output     [31:0] status,
    // input      [31:0] status_in,
    // input             status_set,
    input      [15:0] status_menumask,


    //toggle to force notify of video mode change
    // input             new_vmode,

    // SD config
    // output     [VD:0] img_mounted,  // signaling that new image has been mounted
    // output            img_readonly, // mounted as read only. valid only for active bit in img_mounted
    // output     [63:0] img_size,     // size of image in bytes. valid only for active bit in img_mounted

    // SD block level access
    // input      [31:0] sd_lba,
    // input      [VD:0] sd_rd,       // only single sd_rd can be active at any given time
    // input      [VD:0] sd_wr,       // only single sd_wr can be active at any given time
    // output            sd_ack,

    // do not use in new projects.
    // CID and CSD are fake except CSD image size field.
    // input             sd_conf,
    // output            sd_ack_conf,

    // SD byte level access. Signals for 2-PORT altsyncram.
    // output     [AW:0] sd_buff_addr,
    // output     [DW:0] sd_buff_dout,
    // input      [DW:0] sd_buff_din,
    // output            sd_buff_wr,

    // ARM -> FPGA download
    output            ioctl_download, // signal indicating an active download
    output      [7:0] ioctl_index,        // menu index used to upload the file
    (*keep*) output            ioctl_wr,
    (*keep*) output     [26:0] ioctl_addr,         // in WIDE mode address will be incremented by 2
    (*keep*) output     [DW:0] ioctl_dout,
    output     [31:0] ioctl_file_ext,
    // input             ioctl_wait,

    // RTC MSM6242B layout
    output     [64:0] RTC,

    // Seconds since 1970-01-01 00:00:00
    output     [32:0] TIMESTAMP,

    // UART flags
    // input      [15:0] uart_mode,

    // ps2 keyboard emulation
    output            ps2_kbd_clk_out,
    output            ps2_kbd_data_out,
    // input             ps2_kbd_clk_in,
    // input             ps2_kbd_data_in,

    // input       [2:0] ps2_kbd_led_status,
    // input       [2:0] ps2_kbd_led_use,

    // output            ps2_mouse_clk_out,
    // output            ps2_mouse_data_out,
    // input             ps2_mouse_clk_in,
    // input             ps2_mouse_data_in,

    // ps2 alternative interface.

    // [8] - extended, [9] - pressed, [10] - toggles with every press/release
    output     [10:0] ps2_key,

    // [24] - toggles with every event
    output     [24:0] ps2_mouse,
    output reg [15:0] ps2_mouse_ext = 0, // 15:8 - reserved(additional buttons), 7:0 - wheel movements

    inout      [21:0] gamma_bus
);

// localparam DW = (WIDE) ? 15 : 7;
// localparam AW = (WIDE) ?  7 : 8;
// localparam VD = VDNUM-1;

assign joystick_0 = 16'h0;
assign joystick_1 = 16'h0;

assign ps2_kbd_clk_out = 1'b0;
assign ps2_kbd_data_out= 1'b0;
assign ps2_key = 11'd0;

// Download simulations not available
assign ioctl_download = 1'b0;
assign ioctl_wr = 1'b0;

assign status = 32'd0;
assign forced_scandoubler = 1'b0;

assign buttons = 2'b0;

assign direct_video = 1'b0;

assign joystick_analog_0 = 16'd0;
assign joystick_analog_1 = 16'd0;

endmodule // hps_io