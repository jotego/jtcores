`timescale 1ns/1ps

// jtframe_mister_capture through the real jtframe_mister_uio transport.
// The testbench plays the HPS: it sends CAP_* commands word by word and reads
// CAPS and the descriptor back. CAB replay signals are driven directly: the
// interval of generator frame f has index f and its checkpoint is f+1.
// A DDR model with random stalls records every write. The checker rebuilds
// each expected frame independently and compares pixels, row padding,
// descriptor fields, descriptor CRC and the GFW1 hash of the DDR payload.
module test;

`include "test_tasks.vh"

localparam [31:0] BASE   = 32'h3FE0_0000;
localparam [31:0] STRIDE = 32'h0020_0000;
localparam SLOT_WORDS    = STRIDE/8;
localparam [15:0] CAP_CAPS=16'h90, CAP_ARM=16'h91, CAP_READ=16'h92,
                  CAP_RELEASE=16'h93, CAP_ABORT=16'h94;

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
reg  [2:0] cab_state=0;
reg  [7:0] cab_error=0;
reg  cab_frame_start=0;

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
integer     stall_pct=30, beats=0;
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
    end
end

// ---------------------------------------------------------------- UUT
reg         io_strobe=0, io_enable=0;
reg  [15:0] host_word=0;
wire        uio_start, uio_finish, uio_active, uio_bad_word, response_enable, result_valid;
wire [15:0] uio_command, response_word;
wire [ 6:0] uio_words, uio_bad_index;
wire [95:0] uio_payload;
wire [127:0] cap_caps;
wire [ 5:0] result_index;
wire [ 7:0] result_byte;

jtframe_mister_uio transport(
    .rst(rst), .clk(clk), .io_enable(io_enable), .io_strobe(io_strobe), .host_word(host_word),
    .cab_caps(128'd0), .cap_caps(cap_caps), .cab_snapshot(256'd0),
    .cap_result_index(result_index), .cap_result_byte(result_byte),
    .cab_snapshot_valid(1'b0), .cap_result_valid(result_valid),
    .response_enable(response_enable), .response_word(response_word),
    .start(uio_start), .finish(uio_finish), .active(uio_active), .command(uio_command),
    .words(uio_words), .payload(uio_payload), .bad_word(uio_bad_word), .bad_index(uio_bad_index)
);

jtframe_mister_capture #(.BASE(BASE)) uut(
    .rst              ( rst                ),
    .clk              ( clk                ),
    .host_word        ( host_word          ),
    .uio_start        ( uio_start          ),
    .uio_finish       ( uio_finish         ),
    .uio_active       ( uio_active         ),
    .uio_command      ( uio_command        ),
    .uio_words        ( uio_words          ),
    .uio_payload      ( uio_payload[63:0]  ),
    .uio_bad_word     ( uio_bad_word       ),
    .uio_bad_index    ( uio_bad_index      ),
    .uio_caps         ( cap_caps           ),
    .uio_result_valid ( result_valid       ),
    .result_index     ( result_index       ),
    .result_byte      ( result_byte        ),
    .lvbl             ( lvbl               ),
    .cab_frame_start  ( cab_frame_start    ),
    .cab_frame_index  ( frame[14:0]        ),
    .cab_completed    ( frame[14:0]        ),
    .cab_state        ( cab_state          ),
    .cab_error        ( cab_error          ),
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

// ---------------------------------------------------------------- HPS side
reg [127:0] caps;
reg [511:0] desc;
wire busy = caps[48], armed = caps[49], ready = caps[50], faulted = caps[51],
     released = caps[52], draining = caps[53];
wire [7:0] code = caps[63:56];
wire [15:0] cmd_fresh = caps[79:64], res_fresh = caps[111:96];

task word(input [15:0] w);
begin
    @(negedge clk); host_word = w; io_strobe = 1;
    @(posedge clk); #1 io_strobe = 0;
end
endtask

task begin_tx(input [15:0] cmd); begin @(negedge clk); io_enable = 1; word(cmd); end endtask
task end_tx; begin @(negedge clk); io_enable = 0; repeat(3) @(posedge clk); #1; end endtask

task read_caps;
    integer i;
begin
    begin_tx(CAP_CAPS);
    for(i=0;i<8;i=i+1) begin word(0); caps[i*16+:16] = response_word; end
    end_tx;
end
endtask

task read_result;
    integer i;
begin
    begin_tx(CAP_READ);
    for(i=0;i<64;i=i+1) begin word(0); desc[i*8+:8] = response_word[7:0]; end
    end_tx;
end
endtask

task send(input [15:0] cmd, input [63:0] data, input integer n);
    integer i;
begin
    begin_tx(cmd);
    for(i=0;i<n;i=i+1) word({8'd0, data[i*8+:8]});
    end_tx;
end
endtask

task arm(input [14:0] cp, input [10:0] hold);
begin
    send(CAP_ARM, {21'd0, hold, 17'd0, cp}, 8);
    read_caps;
end
endtask

task release_cp(input [14:0] cp); begin send(CAP_RELEASE, {49'd0, cp}, 4); read_caps; end endtask
task abort_cp(input [14:0] cp);
    integer n;
begin
    send(CAP_ABORT, {49'd0, cp}, 4);
    read_caps;
    n = 0;
    while(busy && n<1000) begin read_caps; n=n+1; end
end
endtask

task wait_frames(input integer n);
    integer f0;
begin
    f0 = frame;
    wait(frame >= f0+n);
end
endtask

task wait_ready(input integer max_frames);
    integer f0;
begin
    f0 = frame;
    read_caps;
    while(!ready && !faulted && frame < f0+max_frames) read_caps;
    if(!ready) begin
        $display("not READY: flags %04x fault %02x frame %0d", caps[63:48], code, frame);
        fail();
    end
end
endtask

task wait_fault(input [7:0] want, input integer max_frames);
    integer f0;
begin
    f0 = frame;
    read_caps;
    while(!faulted && frame < f0+max_frames) read_caps;
    if(code!==want) begin
        $display("fault %02x, want %02x (flags %04x)", code, want, caps[63:48]);
        fail();
    end
end
endtask

function [31:0] gfw1(input [31:0] h, input [31:0] w);
    gfw1 = {h[30:0],1'b0} ^ (h[31] ? 32'h0040_0007 : 32'd0) ^ w;
endfunction

function [31:0] crc_desc(input [511:0] r);
    integer i, b;
    reg [31:0] c;
    begin
        c = 32'hFFFF_FFFF;
        for(i=0;i<56;i=i+1) begin
            c = c ^ {24'd0, r[i*8+:8]};
            for(b=0;b<8;b=b+1) c = (c>>1) ^ (c[0] ? 32'hEDB8_8320 : 32'd0);
        end
        crc_desc = ~c;
    end
endfunction

function [31:0] r32(input [511:0] r, input integer i); r32 = r[i*8+:32]; endfunction

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

// Independent check of a READY slot against generator frame cp-1
task check_capture(input [14:0] cp);
    integer pitch, x, y, b, f;
    reg [31:0] h;
    reg [7:0] got, want;
    reg [23:0] p;
begin
    read_result;
    f = cp-1;
    pitch = ((W*3+255)/256)*256;
    assert_msg(r32(desc,0)==32'h3243_544A, "JTC2 magic");
    assert_msg(desc[32+:16]==2 && desc[48+:16]==64, "version/size");
    assert_msg(desc[64+:16]==cp && desc[80+:16]==cp-1, "checkpoint/interval");
    assert_msg(r32(desc,12)==BASE && r32(desc,16)==STRIDE, "slot base/stride");
    assert_msg(desc[160+:16]==W && desc[176+:16]==H, "geometry");
    assert_msg(r32(desc,24)==pitch && r32(desc,28)==pitch*H, "pitch/payload");
    assert_msg(r32(desc,32)==32'h2C01, "mode");
    assert_msg(r32(desc,36)==1+pitch*H/256, "block count");
    assert_msg(r32(desc,40)==32'h3157_4647, "GFW1 tag");
    assert_msg(desc[48*8+:64]==0, "reserved bytes");
    assert_msg(r32(desc,56)==crc_desc(desc), "descriptor CRC");
    assert_msg(r32(desc,60)==32'h3259_4452, "RDY2 commit");
    for(y=0;y<H;y=y+1) for(b=0;b<pitch;b=b+1) begin
        got = mem[32 + (y*pitch+b)/8][((y*pitch+b)%8)*8+:8];
        if(b < W*3) begin
            x = b/3;
            p = pix(f, x, y);
            want = p[(b%3)*8+:8];
        end else want = 0;
        if(got!==want) begin
            $display("cp %0d pixel byte y=%0d b=%0d got %02x want %02x", cp, y, b, got, want);
            fail();
        end
    end
    slot_hash(h);
    assert_msg(h==r32(desc,44), "GFW1 hash of DDR payload");
end
endtask

task capture(input [14:0] cp);
    reg [15:0] fresh;
begin
    arm(cp, 500);
    assert_msg(armed && !faulted && !busy, "ARM accepted");
    fresh = res_fresh;
    wait_ready(cp-frame+3);
    assert_msg(armed && res_fresh==fresh+1'd1, "READY with a fresh result");
    check_capture(cp);
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
reg [15:0] fresh;
integer cp, i;

initial begin
    for(i=0;i<SLOT_WORDS;i=i+1) mem[i] = 64'hDEAD_BEEF_DEAD_BEEF;
    repeat(10) @(posedge clk);
    rst = 0;
    repeat(10) @(posedge clk);
    read_caps;
    assert_msg(caps[15:0]==16'hCA50 && caps[31:16]==2 && caps[47:32]==64 && caps[54], "CAPS signature");
    assert_msg(!draining && !armed && !faulted, "idle with CAB IDLE");
    // 1. ARM needs a CAB session armed from IDLE
    arm(5, 500);
    assert_msg(!armed && code==8'h03, "ARM without a CAB session");
    cab_state = 1;                      // ARMED from IDLE
    wait_frames(1);
    cab_state = 2;                      // RUNNING
    // 2. capture a frame and keep it frozen while the game runs
    capture(frame+3);
    slot_hash(frozen);
    wait_frames(3);
    slot_hash(later);
    assert_msg(frozen==later, "slot frozen while READY");
    read_caps;
    assert_msg(ready && armed, "still READY");
    // 3. release, then capture again with heavy DDR stalls
    fresh = cmd_fresh;
    release_cp(desc[64+:15]);
    assert_msg(released && !armed && !ready && !busy && !draining && cmd_fresh==fresh+1'd1,
        "release to idle");
    release_cp(desc[64+:15]);
    assert_msg(released && !faulted, "repeated release is accepted");
    stall_pct = 85;
    capture(frame+3);
    release_cp(desc[64+:15]);
    stall_pct = 30;
    // 4. a wrong release faults, abort cleans up
    cp = frame+3;
    capture(cp);
    release_cp(cp+1);
    assert_msg(faulted && code==8'h0C && armed, "bad release faults");
    abort_cp(cp);
    assert_msg(!armed && !busy, "abort ends the ownership");
    // 5. a target already in the past is late
    wait(vc==0);
    cp = frame;
    arm(cp, 500);
    wait_fault(8'h04, 3);
    abort_cp(cp);
    // 6. armed in the middle of the frame before the target: late, not geometry
    wait(vc==2);
    cp = frame+1;
    arm(cp, 500);
    wait_fault(8'h04, 3);
    abort_cp(cp);
    // 7. abort while armed
    cp = frame+20;
    arm(cp, 500);
    assert_msg(armed && !faulted, "re-ARM clears the fault");
    wait_frames(1);
    abort_cp(cp);
    assert_msg(!armed && !faulted, "clean abort");
    // 8. video mode change faults
    cp = frame+20;
    arm(cp, 500);
    video_ok = 0;
    read_caps;
    assert_msg(faulted && code==8'h06, "mode fault");
    video_ok = 1;
    abort_cp(cp);
    // 9. geometry change in the target frame
    cp = frame+3;
    arm(cp, 500);
    wait(frame==cp-1);
    bad_row = 2;
    wait_fault(8'h0E, 3);
    bad_row = -1;
    abort_cp(cp);
    // 10. bad ARM payloads
    arm(frame+10, 99);
    assert_msg(!armed && code==8'h03, "hold below 100 ms");
    arm(frame+10, 2001);
    assert_msg(!armed && code==8'h03, "hold above 2000 ms");
    arm(0, 500);
    assert_msg(!armed && code==8'h03, "checkpoint zero");
    send(CAP_ARM, 64'd5, 7);
    read_caps;
    assert_msg(!armed && code==8'h03, "short ARM keeps the first fault");
    // 11. lifecycle drop while armed
    cp = frame+20;
    arm(cp, 500);
    assert_msg(armed && !faulted, "ARM after bad payloads");
    cab_state = 0;
    wait_frames(1);
    read_caps;
    assert_msg(faulted && code==8'h05 && armed, "lifecycle fault keeps ownership");
    abort_cp(cp);
    assert_msg(!armed, "abort after a lifecycle fault");
    cab_state = 1;
    wait_frames(1);
    cab_state = 2;
    // 12. a malformed command is a length fault
    cp = frame+20;
    arm(cp, 500);
    send(CAP_RELEASE, {49'd0, cp}, 3);
    read_caps;
    assert_msg(armed && code==8'h01, "short RELEASE");
    abort_cp(cp);
    // 13. every partial-word case at the end of a row (widths 9..16)
    for(i=9;i<=16;i=i+1) begin
        new_geometry(i, 5, 24, 4);
        capture(frame+2);
        release_cp(desc[64+:15]);
    end
    // 14. large frame: 400x240 = 1200 bursts
    new_geometry(400, 240, 80, 6);
    capture(frame+2);
    assert_msg(r32(desc,36)==1201, "1200 payload bursts");
    release_cp(desc[64+:15]);
    // 15. a stalled DDR overruns the FIFO; abort waits for the stall to end
    cp = frame+20;
    arm(cp, 500);
    stall_pct = 101;
    wait_fault(8'h08, 4);
    send(CAP_ABORT, {49'd0, cp}, 4);
    read_caps;
    assert_msg(busy && armed, "abort waits for the open burst");
    stall_pct = 30;
    abort_cp(cp);
    assert_msg(!armed && !busy, "abort after the stall");
    capture(frame+3);
    release_cp(desc[64+:15]);
    // 16. the replay ends before the target
    new_geometry(13, 5, 24, 4);
    cp = frame+30;
    arm(cp, 500);
    wait_frames(1);
    cab_state = 3;                      // DONE: no more tags
    wait_fault(8'h04, 4);
    abort_cp(cp);
    // 17. armed after DONE for a checkpoint whose tag has already passed
    cp = frame;
    arm(cp, 500);
    assert_msg(armed && !faulted, "ARM in DONE");
    wait_fault(8'h04, 3);
    abort_cp(cp);
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
