// Runs a short DSP program through jttoaplan1_dsp twice and checks the host
// interlock: the host is halted when the run bit rises, stays halted through a
// zero on port 3 that comes before the zero written to work RAM word 0, and is
// released by the zero on port 3 that follows it. Every DSP write must happen
// while the host is halted. The second run checks that raising the run bit
// again still interrupts the DSP.
module test;

reg         clk = 0, rst = 1, cen = 0, dsp_on = 0;
reg  [ 1:0] div = 0;
reg  [15:0] rom[0:4095];
reg  [15:0] rom_data;
reg  [15:0] work[0:2047], obj[0:2047], pal[0:2047];
reg  [15:0] host_din;
wire [11:0] rom_addr;
wire [13:1] host_addr;
wire [ 1:0] host_sel;
wire [15:0] host_dout;
wire        halt_main, host_we;
integer     k, pc, releases = 0, bad_we = 0;

task op(input [15:0] word);
    begin
        rom[pc] = word;
        pc = pc + 1;
    end
endtask

initial begin
    for( k=0; k<4096; k=k+1 ) rom[k] = 16'h7f80;   // NOP
    for( k=0; k<2048; k=k+1 ) begin
        work[k] = 16'hffff;
        obj[k]  = 16'd0;
        pal[k]  = 16'd0;
    end
    work[5] = 16'h1230;
    pc = 'h000; op(16'hf900); op(16'h0010);         // B 010
    pc = 'h002; op(16'hf900); op(16'h0040);         // B 040, interrupt vector
    pc = 'h010;
    op(16'h6e00);                                   // LDPK 0
    op(16'h7f82);                                   // EINT
    op(16'hf900); op(16'h0012);                     // B 012
    pc = 'h040;
    op(16'h7e03); op(16'h5010);                     // 10h = 3
    op(16'h7e05); op(16'h5011);                     // 11h = 5
    op(16'h7e01); op(16'h5014);                     // 14h = 1
    op(16'h7f89); op(16'h5015);                     // 15h = 0
    op(16'h4b15);                                   // OUT 15h,PA3: too early
    op(16'h2d10); op(16'h0011); op(16'h5012);       // 12h = 6005h
    op(16'h4812);                                   // OUT 12h,PA0
    op(16'h4113);                                   // IN  13h,PA1
    op(16'h2013); op(16'h0014); op(16'h5013);       // 13h += 1
    op(16'h4913);                                   // OUT 13h,PA1: work[5]++
    op(16'h2f14); op(16'h0011); op(16'h5012);       // 12h = 8005h
    op(16'h4812);                                   // OUT 12h,PA0
    op(16'h4910);                                   // OUT 10h,PA1: obj[5] = 3
    op(16'h7e05); op(16'h5016);                     // 16h = 5
    op(16'h2d16); op(16'h0014); op(16'h5012);       // 12h = a001h
    op(16'h4812);                                   // OUT 12h,PA0
    op(16'h4911);                                   // OUT 11h,PA1: pal[1] = 5
    op(16'h2d10); op(16'h5012);                     // 12h = 6000h
    op(16'h4812);                                   // OUT 12h,PA0
    op(16'h4915);                                   // OUT 15h,PA1: work[0] = 0
    op(16'h4b15);                                   // OUT 15h,PA3: release
    op(16'h7f82);                                   // EINT
    op(16'h7f8d);                                   // RET
end

always #10 clk = ~clk;

always @* begin
    case( host_sel )
        2'd0:    host_din = work[host_addr[11:1]];
        2'd1:    host_din = obj [host_addr[11:1]];
        2'd2:    host_din = pal [host_addr[11:1]];
        default: host_din = 16'd0;
    endcase
end

always @(posedge clk) begin
    div      <= div + 2'd1;
    cen      <= div == 2'd3;
    rom_data <= rom[rom_addr];
    if( host_we ) begin
        if( !halt_main ) bad_we <= bad_we + 1;
        case( host_sel )
            2'd0: work[host_addr[11:1]] <= host_dout;
            2'd1: obj [host_addr[11:1]] <= host_dout;
            2'd2: pal [host_addr[11:1]] <= host_dout;
            default:;
        endcase
    end
end

always @(negedge halt_main) if( !rst ) releases = releases + 1;

jttoaplan1_dsp uut(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .dsp_on     ( dsp_on    ),
    .halt_main  ( halt_main ),
    .host_addr  ( host_addr ),
    .host_sel   ( host_sel  ),
    .host_dout  ( host_dout ),
    .host_din   ( host_din  ),
    .host_we    ( host_we   ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( rom_data  )
);

task activate(input integer n);
    integer t;
    begin
        @(negedge clk) dsp_on = 1;
        repeat(3) @(posedge clk);
        if( !halt_main ) begin
            $display("FAIL: run %0d did not halt the host", n);
            $finish;
        end
        for( t=0; t<200000 && halt_main; t=t+1 ) @(posedge clk);
        if( halt_main ) begin
            $display("FAIL: run %0d never released the host", n);
            $finish;
        end
        repeat(2000) @(posedge clk);
        @(negedge clk) dsp_on = 0;
        repeat(2000) @(posedge clk);
    end
endtask

initial begin
    repeat(40)   @(posedge clk);
    rst = 0;
    repeat(2000) @(posedge clk);
    if( halt_main ) begin
        $display("FAIL: host halted before the run bit");
        $finish;
    end
    activate(1);
    if( work[5] != 16'h1231 || work[0] != 16'd0 || obj[5] != 16'd3 || pal[1] != 16'd5 ) begin
        $display("FAIL: run 1 work[5]=%04x work[0]=%04x obj[5]=%04x pal[1]=%04x",
            work[5], work[0], obj[5], pal[1]);
        $finish;
    end
    work[0] = 16'hffff;
    activate(2);
    if( work[5] != 16'h1232 || work[0] != 16'd0 ) begin
        $display("FAIL: run 2 work[5]=%04x (want 1232) work[0]=%04x", work[5], work[0]);
        $finish;
    end
    if( releases != 2 || bad_we != 0 ) begin
        $display("FAIL: releases=%0d (want 2) writes while the host ran=%0d", releases, bad_we);
        $finish;
    end
    $display("PASS");
    $finish;
end

endmodule
