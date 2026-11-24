`timescale 1ns/1ps

module transfer_case #(parameter WIDE=0)(input clk, output reg done=0);

localparam STEP = WIDE ? 2 : 1;
localparam DW = WIDE ? 15 : 7;

reg        fp_enable=0, io_strobe=0;
reg [15:0] io_din=0;
reg [DW:0] ioctl_din=0;
reg        host_wait=0;
tri [48:0] HPS_BUS;
tri [35:0] EXT_BUS;
tri [21:0] gamma_bus;
wire       ioctl_download, ioctl_upload, ioctl_wr, ioctl_rd;
wire [26:0] ioctl_addr;
wire [DW:0] ioctl_dout;
wire [DW:0] memory_dout;

assign HPS_BUS[35:33] = {fp_enable,1'b1,io_strobe};
assign HPS_BUS[31:16] = io_din;
assign HPS_BUS[48:38] = 0;
assign EXT_BUS[32] = 0;

function automatic [DW:0] memory_value(input [26:0] address);
    if(WIDE) memory_value=address[15:0]^16'ha53c;
    else memory_value=address[7:0]^8'ha5;
endfunction

// The upload consumer samples the requested address into a synchronous output,
// matching the address-driven JTFRAME/NVRAM read path.
always @(posedge clk) ioctl_din <= memory_value(ioctl_addr);

/* verilator lint_off PINMISSING */
hps_io #(.WIDE(WIDE), .PS2DIV(0), .STRLEN(1), .CONF_STR_BRAM(0)) uut(
    .clk_sys             ( clk          ),
    .HPS_BUS             ( HPS_BUS      ),
    .joy_raw             ( 16'd0        ),
    .gamma_bus           ( gamma_bus   ),
    .new_vmode           ( 1'b0         ),
    .video_rotated        ( 1'b0         ),
    .ioctl_download       ( ioctl_download ),
    .ioctl_upload         ( ioctl_upload ),
    .ioctl_wr             ( ioctl_wr     ),
    .ioctl_addr           ( ioctl_addr   ),
    .ioctl_dout           ( ioctl_dout   ),
    .ioctl_din            ( ioctl_din    ),
    .ioctl_rd             ( ioctl_rd     ),
    .ioctl_wait           ( host_wait | dwnld_wait ),
    .EXT_BUS              ( EXT_BUS      )
);
/* verilator lint_on PINMISSING */

reg rst=1;
wire dwnld_wr, dwnld_rom, dwnld_ram, dwnld_cart, dwnld_cheat, dwnld_lock;
wire dwnld_wait, ddram_rd;
wire [26:0] dwnld_addr;
wire [7:0] dwnld_dout;
wire [17:0] core_mod;
wire [7:0] game_vol;
wire [31:0] dipsw, cheat;
wire [7:0] ddram_burstcnt;
wire [28:0] ddram_addr;

jtframe_mister_dwnld dwnld(
    .rst              ( rst          ),
    .clk              ( clk          ),
    .dwnld_busy       ( 1'b0         ),
    .prog_we          ( 1'b0         ),
    .prog_rdy         ( 1'b0         ),
    .hps_download     ( ioctl_download ),
    .hps_upload       ( ioctl_upload ),
    .hps_index        ( 8'd0         ),
    .hps_wr           ( ioctl_wr     ),
    .hps_addr         ( ioctl_addr   ),
    .hps_dout         ( ioctl_dout[7:0] ),
    .hps_wait         ( dwnld_wait   ),
    .ioctl_rom        ( dwnld_rom    ),
    .ioctl_wr         ( dwnld_wr     ),
    .ioctl_ram        ( dwnld_ram    ),
    .ioctl_cart       ( dwnld_cart   ),
    .ioctl_cheat      ( dwnld_cheat  ),
    .ioctl_lock       ( dwnld_lock   ),
    .ioctl_addr       ( dwnld_addr   ),
    .ioctl_dout       ( dwnld_dout   ),
    .core_mod         ( core_mod     ),
    .game_vol         ( game_vol     ),
    .status           ( 32'd0        ),
    .dipsw            ( dipsw        ),
    .cheat            ( cheat        ),
    .ddram_busy       ( 1'b0         ),
    .ddram_burstcnt   ( ddram_burstcnt ),
    .ddram_addr       ( ddram_addr   ),
    .ddram_dout       ( 64'd0        ),
    .ddram_dout_ready ( 1'b0         ),
    .ddram_rd          ( ddram_rd    )
);

integer write_count=0;
reg [26:0] write_addr[0:3];
reg [7:0]  write_data[0:3];
reg [26:0] hps_write_addr[0:3];
reg [DW:0] hps_write_data[0:3];
integer hps_write_count=0;
integer read_count=0;
reg [26:0] read_addr[0:7];
always @(posedge clk) begin
    if(ioctl_rd) begin
        read_addr[read_count] <= ioctl_addr;
        read_count <= read_count+1;
    end
    if(ioctl_wr) begin
        hps_write_addr[hps_write_count] <= ioctl_addr;
        hps_write_data[hps_write_count] <= ioctl_dout;
        hps_write_count <= hps_write_count+1;
    end
    if(dwnld_wr) begin
        write_addr[write_count] <= dwnld_addr;
        write_data[write_count] <= dwnld_dout;
        write_count <= write_count+1;
    end
end

task tick(input integer n);
    repeat(n) @(negedge clk);
endtask

task wait_hps_ready;
    integer waits;
    begin
        waits=0;
        while(HPS_BUS[37]!==1'b0) begin
            if(io_strobe) begin
                $display("FAIL WIDE=%0d: host drove strobe while HPS wait was asserted",WIDE);
                $fatal(1);
            end
            @(negedge clk);
            waits=waits+1;
            if(waits>100) begin
                $display("FAIL WIDE=%0d: HPS wait did not clear",WIDE);
                $fatal(1);
            end
        end
    end
endtask

task packet_word(input [15:0] value);
    @(negedge clk); wait_hps_ready(); io_din=value; io_strobe=1;
    @(negedge clk); io_strobe=0;
    @(negedge clk);
endtask

task packet_begin(input [15:0] command);
    @(negedge clk); wait_hps_ready(); fp_enable=1;
    packet_word(command);
endtask

task packet_start;
    packet_begin(16'h0053);
endtask

task packet_end;
    @(negedge clk); io_strobe=0; fp_enable=0;
    tick(1);
endtask

task set_start_address(input [26:0] address, input [7:0] kind);
    packet_start();
    assert_inactive("transfer activated on the command word");
    packet_word({8'd0,kind});
    assert_inactive("transfer activated before the kind word packet ended");
    packet_word(address[15:0]);
    assert_inactive("transfer activated before the low address word packet ended");
    packet_word({5'd0,address[26:16]});
    assert_inactive("transfer activated before the high address word packet ended");
    packet_end();
endtask

task packet_stop;
    packet_start();
    packet_word(16'h0000);
    packet_end();
endtask

task assert_check(input condition, input [8*96-1:0] message);
    if(!condition) begin
        $display("FAIL WIDE=%0d: %0s",WIDE,message);
        $fatal(1);
    end
endtask

task assert_inactive(input [8*96-1:0] message);
`ifndef BASELINE_CONTROL
    assert_check(!ioctl_upload && !ioctl_download && !ioctl_rd && !ioctl_wr,message);
`endif
endtask

initial begin
    tick(4); rst=0; tick(4);

    // The upload is activated only after its requested address is complete.
    read_count=0;
    host_wait=1;
    fork
        begin packet_begin(16'h0053); end
        begin
            tick(3);
            assert_check(HPS_BUS[37]===1'b1 && !io_strobe,
                "HPS host wait must block the command strobe");
            host_wait=0;
        end
    join
    assert_inactive("transfer activated on the command word");
    packet_word(16'h00aa);
    assert_inactive("upload activated on its kind word");
    packet_word(16'h2345);
    assert_inactive("upload activated on its low address word");
    packet_word(16'h0001);
    assert_inactive("upload activated on its high address word");
    packet_end();
`ifdef BASELINE_CONTROL
    tick(1);
`else
    assert_check(ioctl_upload && ioctl_rd && ioctl_addr==27'h12345,
        "first upload read must pulse at the requested address");
`endif
    tick(1);
    assert_check(read_count==1 && read_addr[0]==27'h12345,
        "first upload read must pulse at the requested address");
    assert_check(!ioctl_rd,"initial upload read must be exactly one pulse");

    packet_begin(16'h0054);
    packet_word(16'h0000);
    assert_check(read_count==2 && read_addr[1]==27'h12345+STEP && ioctl_addr==27'h12345+STEP,
        "first upload data request must advance exactly one item");
    assert_check(HPS_BUS[15:0]==memory_value(27'h12345),
        "registered address-dependent upload data must be returned on HPS_BUS");
    packet_word(16'h0000);
    assert_check(read_count==3 && read_addr[2]==27'h12345+2*STEP && ioctl_addr==27'h12345+2*STEP,
        "second upload data request must advance one more item");
    assert_check(HPS_BUS[15:0]==memory_value(27'h12345+STEP),
        "subsequent registered upload data must follow its requested address");
    packet_end();

    // Stop the upload, then write a two-item download at a nonzero address.
    packet_stop();
    read_count=0;
    set_start_address(27'h6543210,8'haa);
    assert_check(ioctl_upload && ioctl_rd && ioctl_addr==27'h6543210,
        "second upload must retain all high requested address bits");
    tick(1);
    assert_check(read_count==1 && read_addr[0]==27'h6543210 && !ioctl_rd,
        "high-address upload must generate one initial read pulse");
    packet_stop();

    read_count=0;
    set_start_address(27'd0,8'haa);
    assert_check(ioctl_upload && ioctl_rd && ioctl_addr==0,
        "zero-address upload must preserve its valid start address");
    tick(1);
    assert_check(read_count==1 && read_addr[0]==0 && !ioctl_rd,
        "zero-address upload must generate one initial read pulse");
    packet_stop();

    set_start_address(27'h12345,8'h01);
    assert_check(ioctl_download && !ioctl_upload && ioctl_addr==27'h12345,
        "download activates at its requested address after packet end");
    write_count=0;
    packet_begin(16'h0054); packet_word(WIDE ? 16'hbbaa : 16'h00aa);
    packet_word(WIDE ? 16'hddcc : 16'h00cc); packet_end();
    tick(4);
    assert_check(write_count==2,"downstream wrapper must observe two download writes");
    assert_check(hps_write_count==2 && hps_write_addr[0]==27'h12345 &&
        hps_write_addr[1]==27'h12345+STEP,
        "HPS write pulses must carry both complete byte/word addresses");
    assert_check(write_addr[0]==27'h12345 && write_addr[1]==27'h12345+STEP,
        "downstream wrapper write addresses must match byte/word stepping");
    assert_check(hps_write_data[0]==(WIDE ? 16'hbbaa : 8'haa) &&
        hps_write_data[1]==(WIDE ? 16'hddcc : 8'hcc),
        "HPS writes must preserve every payload bit in byte and WIDE modes");
    assert_check(write_data[0]==8'haa && write_data[1]==8'hcc,
        "downstream wrapper data must match the low byte of each item");
    packet_stop();
    assert_check(ioctl_addr==27'h12345+2*STEP,
        "download stop address must be one past the last written item");

    // A single item still carries its complete WIDE word and a one-past stop.
    set_start_address(27'h45678,8'h01);
    write_count=0; hps_write_count=0;
    packet_begin(16'h0054);
    packet_word(WIDE ? 16'h5ac3 : 16'h00c3);
    packet_end();
    tick(4);
    assert_check(write_count==1 && write_addr[0]==27'h45678 && write_data[0]==8'hc3,
        "one-item download must reach the byte wrapper at the requested address");
    assert_check(hps_write_count==1 && hps_write_addr[0]==27'h45678 &&
        hps_write_data[0]==(WIDE ? 16'h5ac3 : 8'hc3),
        "one-item download must preserve its full WIDE payload");
    packet_stop();
    assert_check(ioctl_addr==27'h45678+STEP,
        "one-item download stop address must be one past its payload");

    // An empty download is a zero-length DDR request, not a phantom byte.
    set_start_address(27'd0,8'h01);
    assert_check(ioctl_download && ioctl_addr==0,"empty download starts at zero");
    packet_stop();
    tick(6);
    assert_check(!dwnld_wr,"empty download must not create a payload write");
    assert_check(dwnld.ddr_len==0 && !dwnld.ddr_dwn,
        "empty download must remain zero length in the DDR wrapper");

    // The DDR wrapper also uses the staged address as a length when no HPS
    // payload writes occurred; stopping must preserve that complete value.
    set_start_address(27'h23456,8'h01);
    packet_stop();
    tick(4);
    assert_check(dwnld.ddr_len==27'h23456 && dwnld.ddr_dwn,
        "empty DDR download must retain its staged nonzero byte length");
    assert_check(!dwnld_wr,"DDR source must not fabricate an HPS payload write");
    assert_check(dwnld_wait && HPS_BUS[37],
        "real DDR wrapper wait must reach the HPS host interface");
    done=1;
end
endmodule

module test;
reg clk=0;
wire done_byte, done_wide;
always #5 clk=~clk;

transfer_case #(.WIDE(0)) byte_mode(.clk(clk),.done(done_byte));
transfer_case #(.WIDE(1)) wide_mode(.clk(clk),.done(done_wide));

initial begin
    wait(done_byte && done_wide);
    $display("PASS");
    $finish;
end

initial begin
    #1000000;
    $display("FAIL: transfer regression timed out");
    $fatal(1);
end
endmodule
