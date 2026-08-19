// Unit test: uPD78C11 ADC scan-group switching in jttc0030cmd.
//
// Taito's C-chip firmware reads all eight AN pins as digital inputs by
// alternating ANM between scan/AN0-AN3 and scan/AN4-AN7 with the mode bit
// held constant. uPD78C1x manual 8.2: writing ANM stops the running conversion
// and restarts from the newly selected group into CR0. Before the fix the
// group counter only re-initialised on a mode-bit change, so AN4-AN7 were
// never sampled and their CR results were stale group-0 data (Volfied's P2
// left/right/button on AN7/AN4/AN5 stayed dead while up/down on AN1/AN2
// worked).
//
// `adcscan_mrom.hex` (custom firmware, see the file) copies CR0..CR3 to
// shared-RAM words 0..3 after the AN0-AN3 scan and to words 4..7 after the
// AN4-AN7 scan. Each AN pin is driven with a distinct level so every CR
// result identifies exactly which channel was converted: the wrapper returns
// 0xFF for an[ch]=1 and 0x00 for an[ch]=0, matching taitocchip.cpp.
`timescale 1ns/1ps
module test;
    reg        clk = 0, rst = 1;
    reg  [2:0] cdiv = 0;
    wire       cen  = (cdiv == 3'd5);        // /6 MCU clock enable
    always #10 clk = ~clk;
    always @(posedge clk) cdiv <= cen ? 3'd0 : cdiv + 3'd1;

    reg         cs = 0, rnw = 1;
    reg  [10:0] addr = 0;
    reg  [ 7:0] din = 0;
    wire [ 7:0] dout;
    wire        dtack_n;
    reg  [ 7:0] an = 8'h00;

    wire [11:0] mrom_addr;
    wire [12:0] eprom_addr;
    wire [ 7:0] mrom_data;

    jttc0030cmd uut(
        .rst(rst), .clk(clk), .cen(cen),
        .cs(cs), .addr(addr), .din(din), .dout(dout), .rnw(rnw), .dtack_n(dtack_n),
        .int1(1'b0), .nmi_n(1'b1),
        .pa_in(8'd0), .pb_in(8'd0), .pc_in(8'd0),
        .pa_out(), .pb_out(), .pc_out(),
        .an(an),
        .mrom_addr(mrom_addr), .mrom_data(mrom_data),
        .eprom_addr(eprom_addr), .eprom_data(8'd0),
        .dbg_pc(), .dbg_fetch()
    );

    jtframe_prom #(.DW(8),.AW(12),.SIMHEX("adcscan_mrom.hex")) u_mask(
        .clk(clk), .cen(1'b1), .data(8'd0),
        .rd_addr(mrom_addr), .wr_addr(12'd0), .we(1'b0), .q(mrom_data)
    );

    integer errors = 0;
    reg [7:0] q, mark;
    integer i, timeout;

    task host_read(input [10:0] a, output [7:0] d);
        begin
            @(posedge clk); cs = 1; rnw = 1; addr = a;
            repeat (3) @(posedge clk);
            d = dout;
            cs = 0;
            @(posedge clk);
        end
    endtask

    task expect_eq(input [7:0] got, input [7:0] exp, input [127:0] name);
        begin
            if (got !== exp) begin
                $display("FAIL: %0s = %02x, expected %02x", name, got, exp);
                errors = errors + 1;
            end else begin
                $display("ok: %0s = %02x", name, got);
            end
        end
    endtask

    // The firmware toggles shared-RAM word 8 (00<->FF) at the end of every
    // loop, after all eight CR copies. Wait for it to change N times, so N
    // complete iterations have run against the current `an`.
    task wait_loops(input integer n);
        integer k;
        begin
            for (k = 0; k < n; k = k + 1) begin
                host_read(11'h008, mark);
                timeout = 0;
                host_read(11'h008, q);
                while (q == mark && timeout < 4000) begin
                    repeat (200) @(posedge clk);
                    host_read(11'h008, q);
                    timeout = timeout + 1;
                end
                if (q == mark) begin
                    $display("FAIL: firmware loop marker stuck at %02x", mark);
                    errors = errors + 1;
                end
            end
        end
    endtask

    // Check one full loop's worth of results against the current `an` pattern.
    // words 0..3 <- AN0..AN3, words 4..7 <- AN4..AN7
    task check_all(input [127:0] label);
        reg [7:0] exp;
        begin
            for (i = 0; i < 8; i = i + 1) begin
                exp = an[i] ? 8'hFF : 8'h00;
                host_read(i[10:0], q);
                expect_eq(q, exp, {label, " AN", "0"+i[7:0]});
            end
        end
    endtask

    initial begin
        repeat (20) @(posedge clk);
        rst = 0;
        // bank_68k = 0 (host window on shared-RAM bank 0)
        @(posedge clk); cs = 1; rnw = 0; addr = 11'h600; din = 8'h00;
        @(posedge clk); cs = 0; rnw = 1;

        // ---- pattern 1: only the upper group has a set bit per channel ----
        // AN7..AN0 = 1010_0110  -> upper: AN7=1 AN6=0 AN5=1 AN4=0
        //                          lower: AN3=0 AN2=1 AN1=1 AN0=0
        an = 8'b1010_0110;
        // two full loops so both groups reflect `an`
        wait_loops(2);
        check_all("p1");

        // ---- pattern 2: the Volfied case, all pins idle-high but one ----
        // P2 LEFT is AN7 low with everything else high: idle port = FF,
        // pressed = 7F. Before the fix AN7 was never sampled.
        an = 8'b0111_1111;
        wait_loops(2);
        check_all("p2");

        // ---- pattern 3: lower group all clear, upper group all set ----
        // Distinguishes a real AN4-AN7 scan from stale AN0-AN3 data outright.
        an = 8'b1111_0000;
        wait_loops(2);
        check_all("p3");

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
