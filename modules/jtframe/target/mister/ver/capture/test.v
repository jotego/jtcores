`timescale 1ns/1ps

// jtframe_mister_capture through the real jtframe_mister_uio transport.
// The testbench plays Main: it sends ARM (0x91) word by word and reads the
// status (0x90) and the JTC3 result (0x92) back. CAB interval starts are
// driven directly: interval f carries generator frame f, so its picture is
// frame f+1; the CAB state stays RUNNING except in the last case. A DDR model with random stalls records every write. The checker
// rebuilds each expected picture independently and compares pixels, row
// padding, the descriptor and the GFW1 hash of the DDR payload.
module test;

`include "test_tasks.vh"

localparam [31:0] BASE   = 32'h3FE0_0000;
localparam [31:0] STRIDE = 32'h0020_0000;
localparam SLOT_WORDS    = STRIDE/8;
localparam [15:0] CAP_STATUS=16'h90, CAP_ARM=16'h91, CAP_RESULT=16'h92;

reg clk=0, rst=1;
always #5 clk = ~clk;

// ---------------------------------------------------------------- video
integer W=13, H=5, HB=24, VB=4;     // active and blanking sizes
integer frame=0;                    // generator frame = CAB interval index
integer bad_row=-1;                 // shorten this row to break geometry
reg [1:0] cen_cnt=0;
wire pxl_cen = cen_cnt==0;
reg  [23:0] rgb2, rgb1, rgb;
reg  de2=0, de1=0, de=0, lvbl=0, video_ok=1;
integer hc=0, vc=0;
reg  cab_frame_start=0;
reg  [2:0] cab_state=2;           // RUNNING

function [23:0] pix(input integer f, input integer x, input integer y);
    pix = {f[7:0]^y[7:0], x[7:0]+8'd3*y[7:0], f[7:0]*8'd7+x[7:0]};
endfunction

always @(posedge clk) begin
    cen_cnt <= cen_cnt+1'd1;
    cab_frame_start <= 0;
    if(pxl_cen) begin
        if(hc == W+HB-1) begin
            hc <= 0;
            if(vc == H+VB-1) begin
                vc <= 0;
                frame <= frame+1;
            end else vc <= vc+1;
        end else hc <= hc+1;
        lvbl <= vc < H;                 // game LVBL
        if(vc==0 && hc==1) cab_frame_start <= 1;
        // two pixels of pipeline delay before the native video output
        de2 <= vc < H && hc < (vc==bad_row ? W-1 : W);
        rgb2 <= pix(frame, hc, vc);
        de1 <= de2; rgb1 <= rgb2;
        de  <= de1; rgb  <= rgb1;
    end
end

// ---------------------------------------------------------------- DDR model
reg  [63:0] mem[0:SLOT_WORDS-1];
wire        ddr_sel, ddr_lock, ddr_we;
wire [ 7:0] ddr_burstcnt, ddr_be;
wire [28:0] ddr_addr;
wire [63:0] ddr_din;
reg         ddr_busy=0;
integer     stall_pct=30, beats=0, writes=0, w0;
reg  [28:0] waddr;

always @(posedge clk) begin
    ddr_busy <= ($urandom%100) < stall_pct;
    if(ddr_we && !ddr_busy) begin
        if(!ddr_sel || !ddr_lock) begin $display("write without DDR ownership"); fail(); end
        if(beats==0) begin
            if(ddr_burstcnt!=32 || ddr_be!=8'hff || ddr_addr[4:0]!=0 ||
               ddr_addr < ((BASE+256)>>3) || ddr_addr+32 > ((BASE+STRIDE)>>3)) begin
                $display("bad burst addr=%x cnt=%d", ddr_addr, ddr_burstcnt); fail();
            end
            waddr = ddr_addr;
        end else if(ddr_addr != waddr) begin
            $display("address changed within burst"); fail();
        end
        mem[waddr-(BASE>>3)+beats] <= ddr_din;
        beats = beats==31 ? 0 : beats+1;
        writes = writes+1;
    end
end

// ---------------------------------------------------------------- UUT
reg         io_strobe=0, io_enable=0;
reg  [15:0] host_word=0;
wire        uio_finish, uio_bad_word, response_enable;
wire [15:0] uio_command, response_word;
wire [ 6:0] uio_words;
wire [95:0] uio_payload;
wire [127:0] cap_caps, cap_result;

jtframe_mister_uio transport(
    .rst                ( rst             ),
    .clk                ( clk             ),
    .io_enable          ( io_enable       ),
    .io_strobe          ( io_strobe       ),
    .host_word          ( host_word       ),
    .cab_caps           ( 128'd0          ),
    .cap_caps           ( cap_caps        ),
    .cap_result         ( cap_result      ),
    .cab_snapshot       ( 256'd0          ),
    .cab_snapshot_valid ( 1'b0            ),
    .response_enable    ( response_enable ),
    .response_word      ( response_word   ),
    .start              (                 ),
    .finish             ( uio_finish      ),
    .active             (                 ),
    .command            ( uio_command     ),
    .words              ( uio_words       ),
    .payload            ( uio_payload     ),
    .bad_word           ( uio_bad_word    ),
    .bad_index          (                 )
);

jtframe_mister_capture #(.BASE(BASE)) uut(
    .rst              ( rst                ),
    .clk              ( clk                ),
    .uio_finish       ( uio_finish         ),
    .uio_command      ( uio_command        ),
    .uio_words        ( uio_words          ),
    .uio_payload      ( uio_payload[14:0]  ),
    .uio_bad_word     ( uio_bad_word       ),
    .uio_caps         ( cap_caps           ),
    .uio_result       ( cap_result         ),
    .lvbl             ( lvbl               ),
    .cab_frame_start  ( cab_frame_start    ),
    .cab_frame_index  ( frame[14:0]        ),
    .cab_state        ( cab_state          ),
    .pxl_cen          ( pxl_cen            ),
    .red              ( rgb[ 7: 0]         ),
    .green            ( rgb[15: 8]         ),
    .blue             ( rgb[23:16]         ),
    .de               ( de                 ),
    .video_ok         ( video_ok           ),
    .ddr_sel          ( ddr_sel            ),
    .ddr_lock         ( ddr_lock           ),
    .ddr_busy         ( ddr_busy           ),
    .ddr_burstcnt     ( ddr_burstcnt       ),
    .ddr_addr         ( ddr_addr           ),
    .ddr_we           ( ddr_we             ),
    .ddr_be           ( ddr_be             ),
    .ddr_din          ( ddr_din            )
);

// ---------------------------------------------------------------- Main side
reg  [63:0] st;
reg [127:0] res;
wire        ready  = st[47];
wire [14:0] sframe = st[46:32], starget = st[62:48];
wire        st_video_ok = st[63];

task word(input [15:0] w);
begin
    @(negedge clk); host_word = w; io_strobe = 1;
    @(posedge clk); #1 io_strobe = 0;
end
endtask

task begin_tx(input [15:0] cmd); begin @(negedge clk); io_enable = 1; word(cmd); end endtask
task end_tx; begin @(negedge clk); io_enable = 0; repeat(3) @(posedge clk); #1; end endtask

task read_status;
    integer i;
begin
    begin_tx(CAP_STATUS);
    for(i=0;i<4;i=i+1) begin word(0); st[i*16+:16] = response_word; end
    end_tx;
end
endtask

task read_result;
    integer i;
begin
    begin_tx(CAP_RESULT);
    for(i=0;i<8;i=i+1) begin word(0); res[i*16+:16] = response_word; end
    end_tx;
end
endtask

task send_arm(input [15:0] data, input integer n);
    integer i;
begin
    begin_tx(CAP_ARM);
    for(i=0;i<n;i=i+1) word({8'd0, data[(i%2)*8+:8]});
    end_tx;
end
endtask

task arm(input [14:0] t); begin send_arm({1'b0,t}, 2); read_status; end endtask

task wait_frames(input integer n);
    integer f0;
begin
    f0 = frame;
    wait(frame >= f0+n);
end
endtask

// poll as Main does: ready, or the frame number passes the target
task wait_ready(input [14:0] t);
begin
    read_status;
    while(!ready && sframe <= t) read_status;
    if(!ready) begin
        $display("target %0d missed: frame %0d", t, sframe);
        fail();
    end
    assert_msg(sframe==t && starget==t, "status frame and target at READY");
end
endtask

task wait_missed(input [14:0] t);
begin
    read_status;
    while(!ready && sframe <= t) read_status;
    assert_msg(!ready, "a broken target frame is not READY");
end
endtask

function [31:0] gfw1(input [31:0] h, input [31:0] w);
    gfw1 = {h[30:0],1'b0} ^ (h[31] ? 32'h0040_0007 : 32'd0) ^ w;
endfunction

task slot_hash(output [31:0] h);
    integer wi, words;
begin
    words = ((W*3+255)/256)*256*H/8;
    h = 0;
    for(wi=0;wi<words;wi=wi+1) begin
        h = gfw1(h, mem[32+wi][31:0]);
        h = gfw1(h, mem[32+wi][63:32]);
    end
end
endtask

// Independent check of a READY slot against generator frame t-1
task check_capture(input [14:0] t);
    integer pitch, x, y, b, f;
    reg [31:0] h;
    reg [7:0] got, want;
    reg [23:0] p;
begin
    read_result;
    f = t-1;
    pitch = ((W*3+255)/256)*256;
    assert_msg(res[15:0]==16'h544A && res[31:16]==16'h3343, "JTC3 magic");
    assert_msg(res[47:32]==t, "frame");
    assert_msg(res[63:48]==W && res[79:64]==H, "geometry");
    assert_msg(res[95:80]==BASE[31:21], "slot base");
    for(y=0;y<H;y=y+1) for(b=0;b<pitch;b=b+1) begin
        got = mem[32 + (y*pitch+b)/8][((y*pitch+b)%8)*8+:8];
        if(b < W*3) begin
            x = b/3;
            p = pix(f, x, y);
            want = p[(b%3)*8+:8];
        end else want = 0;
        if(got!==want) begin
            $display("frame %0d pixel byte y=%0d b=%0d got %02x want %02x", t, y, b, got, want);
            fail();
        end
    end
    slot_hash(h);
    assert_msg(h==res[127:96], "GFW1 hash of DDR payload");
end
endtask

task capture(input [14:0] t);
begin
    arm(t);
    assert_msg(!ready && starget==t && sframe<t, "ARM accepted");
    wait_ready(t);
    w0 = writes;
    check_capture(t);
    assert_msg(writes==w0, "the slot is complete at READY");
end
endtask

task new_geometry(input integer w, input integer h, input integer hb, input integer vb);
begin
    wait(vc==0 && hc==0);
    W = w; H = h; HB = hb; VB = vb;
    wait_frames(2);
end
endtask

// ---------------------------------------------------------------- tests
reg [31:0] frozen, later;
integer t, i;

initial begin
    for(i=0;i<SLOT_WORDS;i=i+1) mem[i] = 64'hDEAD_BEEF_DEAD_BEEF;
    repeat(10) @(posedge clk);
    rst = 0;
    repeat(10) @(posedge clk);
    read_status;
    assert_msg(st[15:0]==16'hCA50 && st[31:16]==3, "status signature");
    assert_msg(!ready && sframe==0 && starget==0 && st_video_ok, "idle after reset");
    // 1. capture a frame and keep it frozen while the game runs
    capture(frame+3);
    slot_hash(frozen);
    wait_frames(3);
    slot_hash(later);
    assert_msg(frozen==later, "slot frozen while READY");
    read_status;
    assert_msg(ready && sframe>res[47:32], "still READY while the frames go on");
    // 2. the next ARM releases the slot and keeps the frame count; capture
    // again with heavy DDR stalls
    t = sframe;
    arm(frame+3);
    assert_msg(!ready && sframe>=t, "ARM keeps the frame number");
    stall_pct = 85;
    capture(frame+3);
    stall_pct = 30;
    // DDR stalled across the frame start that ends the target frame
    t = frame+3;
    arm(t);
    wait(frame==t-1 && vc==H-1);
    stall_pct = 101;
    wait(frame==t && vc==1);
    read_status;
    assert_msg(!ready, "not READY while the last words wait for DDR");
    stall_pct = 30;
    wait_ready(t);
    check_capture(t);
    // 3. ARM 0 only releases: nothing is written afterwards
    arm(0);
    assert_msg(!ready && starget==0, "ARM 0 releases");
    w0 = writes;
    wait_frames(3);
    assert_msg(writes==w0, "no writes after ARM 0");
    // 4. a target already in the past, or armed while its picture is drawn
    wait(vc==0);
    t = frame;
    arm(t);
    wait_missed(t);
    arm(0);
    wait_frames(1);
    wait(vc==2);
    t = frame+1;
    arm(t);
    wait_missed(t);
    // 5. ARM while armed moves the target
    arm(frame+20);
    capture(frame+3);
    // 6. video mode change in the target frame
    t = frame+3;
    arm(t);
    wait(frame==t-1 && vc==2);
    video_ok = 0;
    read_status;
    assert_msg(!st_video_ok, "video_ok in the status");
    video_ok = 1;
    wait_missed(t);
    // 7. geometry change in the target frame
    t = frame+3;
    arm(t);
    wait(frame==t-1);
    bad_row = 2;
    wait_missed(t);
    bad_row = -1;
    // 8. malformed ARM commands are ignored
    send_arm(16'd5, 1);
    send_arm(16'd5, 3);
    begin_tx(CAP_ARM); word(16'h0105); word(16'h0000); end_tx;
    read_status;
    assert_msg(starget==t, "short, long and bad-word ARM ignored");
    // 9. every partial-word case at the end of a row (widths 9..16)
    for(i=9;i<=16;i=i+1) begin
        new_geometry(i, 5, 24, 4);
        capture(frame+2);
    end
    // 10. large frame: 400x240 = 1200 bursts
    new_geometry(400, 240, 80, 6);
    capture(frame+2);
    // 11. a stalled DDR overruns the FIFO; the next target captures again
    t = frame+3;
    arm(t);
    stall_pct = 101;
    wait_frames(3);
    stall_pct = 30;
    wait_missed(t);
    capture(frame+3);
    // 12. a new CAB session clears the frame number
    cab_state = 1;
    wait_frames(1);
    read_status;
    assert_msg(sframe==0, "frame cleared by a new CAB session");
    cab_state = 2;
    pass();
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    $dumpoff;
end

initial begin
    #400_000_000 $display("timeout"); fail();
end

endmodule
