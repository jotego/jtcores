`timescale 1ns/1ps

// The simunit macro selects {DDRLOAD, VERTICAL}. The mux is included here
// because iverilog reads the gather.f files before this one.
`ifdef DDRMUX01
    `define JTFRAME_VERTICAL
`endif
`ifdef DDRMUX10
    `define JTFRAME_MR_DDRLOAD
`endif
`ifdef DDRMUX11
    `define JTFRAME_MR_DDRLOAD
    `define JTFRAME_VERTICAL
`endif

`include "../../hdl/jtframe_mr_ddrmux.v"

// jtframe_mr_ddrmux between the real ROM loader (jtframe_mister_dwnld) and a
// video client that behaves like the capture writer: it holds lock from the
// start of a 32-beat burst to its last beat and waits on busy. The DDR model
// has random busy and delayed read data. Busy stays low while read data
// returns, because the loader only counts beats when it sees busy low.
module test;

`include "test_tasks.vh"

localparam [28:0] SLOT = 29'h07FC_0000,    // 0x3FE0_0000 in 64-bit words
                  SLOT_END = SLOT + 29'h4_0000;
localparam [26:0] LEN = 27'd3000;           // ROM bytes: three loader pages
`ifdef JTFRAME_MR_DDRLOAD
localparam DDRLOAD=1;
`else
localparam DDRLOAD=0;
`endif

reg clk=0, rst=1, ld_rst=1;   // the loader reset also marks a new core load
always #5 clk = ~clk;

function [63:0] rom_word(input [28:0] a);
    rom_word = {~a, 3'd5, a, 3'd2};
endfunction

function [63:0] cap_word(input [28:0] a, input [4:0] beat);
    cap_word = {a, 3'd1, 27'd0, beat};
endfunction

// ---------------------------------------------------------------- loader
reg         hps_download=0, hps_wr=0;
reg  [26:0] hps_addr=0;
wire        ioctl_rom, ioctl_wr;
wire [26:0] ioctl_addr;
wire [ 7:0] ioctl_dout;
wire [ 7:0] ddrld_burstcnt;
wire [28:0] ddrld_addr;
wire        ddrld_rd, ddrld_busy;
wire [63:0] ddr_dout;
reg         ddr_dout_ready=0;
reg  [63:0] rom_last;

jtframe_mister_dwnld u_dwnld(
    .rst            ( ld_rst         ),
    .clk            ( clk            ),
    .dwnld_busy     ( 1'b0           ),
    .prog_we        ( 1'b0           ),
    .prog_rdy       ( 1'b1           ),
    .hps_download   ( hps_download   ),
    .hps_upload     ( 1'b0           ),
    .hps_index      ( 8'd0           ),
    .hps_wr         ( hps_wr         ),
    .hps_addr       ( hps_addr       ),
    .hps_dout       ( 8'd0           ),
    .hps_wait       (                ),
    .ioctl_rom      ( ioctl_rom      ),
    .ioctl_wr       ( ioctl_wr       ),
    .ioctl_ram      (                ),
    .ioctl_cart     (                ),
    .ioctl_cheat    (                ),
    .ioctl_lock     (                ),
    .ioctl_addr     ( ioctl_addr     ),
    .ioctl_dout     ( ioctl_dout     ),
    .core_mod       (                ),
    .game_vol       (                ),
    .status         ( 32'd0          ),
    .dipsw          (                ),
    .cheat          (                ),
    .ddram_busy     ( ddrld_busy     ),
    .ddram_burstcnt ( ddrld_burstcnt ),
    .ddram_addr     ( ddrld_addr     ),
    .ddram_dout     ( ddr_dout       ),
    .ddram_dout_ready( ddr_dout_ready),
    .ddram_rd       ( ddrld_rd       )
);

// every byte sent to the core must be the ROM byte at its address
integer rom_bytes=0;
always @(posedge clk) if(ioctl_wr && DDRLOAD) begin
    rom_last = rom_word(29'h0600_0000 + ioctl_addr[26:3]);
    if(ioctl_dout !== rom_last[ioctl_addr[2:0]*8+:8]) begin
        $display("loader byte %0d is %02x", ioctl_addr, ioctl_dout); fail();
    end
    rom_bytes = rom_bytes+1;
end

// ---------------------------------------------------------------- video client
integer     pending=0;          // bursts the client has data for
reg         burst=0;
reg  [ 4:0] beat=0;
reg  [12:0] bidx=0;             // 256-byte block in the slot, pixels from 1
wire        cap_sel, cap_lock, cap_busy, vid_busy, rot_busy;
wire [28:0] cap_addr;
wire [63:0] cap_din;

assign cap_sel  = pending!=0 || burst;
assign cap_lock = burst;
assign cap_addr = SLOT + {11'd0, bidx, 5'd0};
assign cap_din  = cap_word(cap_addr, beat);
// as in jtframe_mister.sv, with the rotation client idle
assign rot_busy = vid_busy |  cap_sel;
assign cap_busy = vid_busy | ~cap_sel;

always @(posedge clk) begin
    if(!burst && pending!=0) begin
        burst <= 1;
        beat  <= 0;
        bidx  <= bidx + 1'd1;
    end
    if(burst && !cap_busy) begin
        beat <= beat + 1'd1;
        if(&beat) begin
            burst   <= 0;
            pending <= pending - 1;
        end
    end
end

// ---------------------------------------------------------------- mux
wire [ 7:0] ddr_burstcnt, ddr_be;
wire [28:0] ddr_addr;
wire        ddr_rd, ddr_we, ddr_clk;
wire [63:0] ddr_din;
reg         ddr_busy=0;

jtframe_mr_ddrmux uut(
    .rst            ( rst            ),
    .clk            ( clk            ),
    .ioctl_rom      ( ioctl_rom      ),
    .ddrld_burstcnt ( ddrld_burstcnt ),
    .ddrld_addr     ( ddrld_addr     ),
    .ddrld_rd       ( ddrld_rd       ),
    .ddrld_busy     ( ddrld_busy     ),
    .rot_clk        ( clk            ),
    .rot_burstcnt   ( 8'd32          ),
    .rot_addr       ( cap_addr       ),
    .rot_rd         ( 1'b0           ),
    .rot_we         ( burst          ),
    .rot_lock       ( cap_lock       ),
    .rot_be         ( 8'hff          ),
    .rot_din        ( cap_din        ),
    .rot_busy       ( vid_busy       ),
    .ddr_clk        ( ddr_clk        ),
    .ddr_busy       ( ddr_busy       ),
    .ddr_burstcnt   ( ddr_burstcnt   ),
    .ddr_addr       ( ddr_addr       ),
    .ddr_rd         ( ddr_rd         ),
    .ddr_be         ( ddr_be         ),
    .ddr_we         ( ddr_we         ),
    .ddr_din        ( ddr_din        )
);

// ---------------------------------------------------------------- DDR model
integer     stall_pct=30, wbeats=0, reads=0, bursts=0, rd_left=0, rd_wait=0;
reg  [28:0] waddr, raddr, first_waddr;
reg         first_seen=0, loader_seen=0, rom_in_burst=0;

assign ddr_dout = rom_word(raddr);

always @(posedge clk) begin
    ddr_busy       <= rd_left==0 && ($urandom%100) < stall_pct;
    ddr_dout_ready <= 0;
    if(ddr_dout_ready) raddr <= raddr+1'd1;
    if(rd_left!=0) begin
        if(rd_wait!=0) rd_wait <= rd_wait-1;
        else if($urandom%4!=0) begin
            ddr_dout_ready <= 1;
            rd_left <= rd_left-1;
        end
    end
    if(!ddr_busy && ddr_rd) begin
        if(ddr_we || wbeats!=0 || rd_left!=0) begin
            $display("read overlaps another transfer"); fail();
        end
        if(ddr_addr[28:25]!=3 || ddr_burstcnt!=128) begin
            $display("read at %x, %0d beats: not a loader read", ddr_addr, ddr_burstcnt); fail();
        end
        raddr   <= ddr_addr;
        rd_left <= 128;
        rd_wait <= 4 + $urandom%16;
        reads   <= reads+1;
    end
    if(!ddr_busy && ddr_we) begin
        if(wbeats==0) begin
            if(ddr_burstcnt!=32 || ddr_be!=8'hff || ddr_addr<SLOT+32 || ddr_addr+32>SLOT_END) begin
                $display("write burst at %x outside the slot", ddr_addr); fail();
            end
            waddr = ddr_addr;
            if(!first_seen) first_waddr = ddr_addr;
            first_seen = 1;
        end else if(ddr_addr!=waddr) begin
            $display("address changed within a write burst"); fail();
        end
        if(ddr_din !== cap_word(waddr, wbeats[4:0])) begin
            $display("write beat %0d of %x carries the wrong data", wbeats, waddr); fail();
        end
        wbeats = wbeats==31 ? 0 : wbeats+1;
        if(wbeats==0) bursts = bursts+1;
    end
    if(uut.ddrld_en) loader_seen = 1;
    if(ioctl_rom && wbeats!=0) rom_in_burst = 1;
    if(uut.ddrld_en && wbeats!=0) begin
        $display("the loader took the port during a write burst"); fail();
    end
end

// ---------------------------------------------------------------- stimulus
task start_load;
begin
    @(negedge clk); hps_download = 1; hps_addr = 0;
    if(!DDRLOAD) begin  // regular download: the HPS writes every byte
        repeat(4) begin
            @(negedge clk) hps_wr = 1; @(negedge clk) hps_wr = 0;
        end
    end
    repeat(8) @(negedge clk);
    hps_addr = LEN;     // the ROM length is notified as the download ends
    hps_download = 0;
end
endtask

integer t0;

task check_release;
begin
    wait(!ioctl_rom);
    t0 = $time;
    first_seen = 0;
    while(uut.ddrld_en) @(posedge clk);
    assert_msg($time-t0 < 500, "the loader releases the port");
    wait(first_seen);
    assert_msg(first_waddr==cap_addr, "first capture burst after the load in the slot");
    repeat(4) @(posedge clk);
    assert_msg(!DDRLOAD || (rom_bytes==LEN && loader_seen), "ROM read through the loader");
    assert_msg(DDRLOAD || (reads==0 && !loader_seen), "no DDR loader without DDRLOAD");
end
endtask

initial begin
    repeat(10) @(posedge clk);
    rst = 0; ld_rst = 0;
    repeat(10) @(posedge clk);
    // 1. a ROM load starts while a capture burst is on the bus
    pending = 3;
    wait(wbeats==8);
    start_load;
    assert_msg(ioctl_rom && rom_in_burst, "load requested during a capture burst");
    check_release;
    wait(pending==0 && !burst);
    assert_msg(bursts==3, "three capture bursts");
    assert_msg(reads==(DDRLOAD ? 3 : 0), "one read per loader page");
    // 2. heavy stalls, a new load between bursts
    stall_pct = 80;
    rom_bytes = 0;
    pending = 6;
    wait(bursts==5);
    @(negedge clk) ld_rst = 1;
    @(negedge clk) ld_rst = 0;
    start_load;
    check_release;
    wait(pending==0 && !burst);
    assert_msg(bursts==9, "all capture bursts written");
    assert_msg(reads==(DDRLOAD ? 6 : 0), "no loader read replayed");
    pass();
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
end

initial begin
    #2_000_000 $display("timeout"); fail();
end

endmodule
