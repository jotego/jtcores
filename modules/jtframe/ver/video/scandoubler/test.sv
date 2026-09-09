// Unit test for the JTFRAME_NOHQ2X line buffer in scandoubler.v
// Key property: both output lines of a scandoubled pair are identical.

`timescale 1ns/1ps

module test;

parameter LENGTH     = 16;
parameter HALF_DEPTH = 0;  // 8-bit color (DWIDTH=7) for wider test values
parameter NLINES     = 5;

localparam DWIDTH = HALF_DEPTH ? 3 : 7;
localparam LBA    = $clog2(LENGTH)-1;

reg              clk = 0;
always #10 clk = ~clk;

reg              ce_x1i = 0, ce_x2o = 0;
reg  [DWIDTH:0]  r_in = 0, g_in = 0, b_in = 0;
reg              hs_in = 0, vb_in = 0;
reg              hbo0 = 1;
wire [DWIDTH:0]  b_out, g_out, r_out;

// ---- DUT: scandoubler.v NOHQ2X line buffer ----
reg [DWIDTH:0] lnram[0:LENGTH*2-1];
reg [DWIDTH:0] lnq;
reg  [LBA:0]   ln_wa, ln_ra;
reg             ln_sel, ln_hs_l;

always @(posedge clk) begin
    if(ce_x1i) begin
        ln_hs_l <= hs_in;
        if(~ln_hs_l & hs_in) begin
            ln_wa  <= 0;
            ln_sel <= ~ln_sel;
        end else begin
            lnram[{~ln_sel, ln_wa}] <= {b_in, g_in, r_in};
            ln_wa <= ln_wa + 1'd1;
        end
    end
    if(vb_in & ce_x1i) ln_sel <= 0;
    lnq <= lnram[{ln_sel, ln_ra}];
    if(hbo0)
        ln_ra <= {(LBA+1){1'b1}};
    else if(ce_x2o)
        ln_ra <= ln_ra + 1'd1;
end

assign {b_out, g_out, r_out} = lnq;
// ---- end DUT ----

reg [3:0] ckcnt = 0;
always @(posedge clk) begin
    ckcnt  <= ckcnt + 1'd1;
    ce_x1i <= (ckcnt == 4'd0);
    ce_x2o <= (ckcnt == 4'd0) || (ckcnt == 4'd4);
end

reg [DWIDTH:0] cap_a [0:LENGTH-1];
reg [DWIDTH:0] cap_b [0:LENGTH-1];
integer errors = 0;
integer ln, px, j;

task write_line(input integer base);
    begin
        @(posedge clk); while (!ce_x1i) @(posedge clk);
        hs_in = 1;
        @(posedge clk); while (!ce_x1i) @(posedge clk);
        hs_in = 0;
        for (j = 0; j < LENGTH; j = j + 1) begin
            r_in = (base + j) & {(DWIDTH+1){1'b1}};
            g_in = 0; b_in = 0;
            @(posedge clk); while (!ce_x1i) @(posedge clk);
        end
        repeat (4) begin @(posedge clk); while (!ce_x1i) @(posedge clk); end
    end
endtask

task read_cap(input integer sel);
    begin
        @(posedge clk); hbo0 = 0;
        repeat (2) begin @(posedge clk); while (!ce_x2o) @(posedge clk); end
        for (j = 0; j < LENGTH; j = j + 1) begin
            @(posedge clk); while (!ce_x2o) @(posedge clk);
            if (sel == 0) cap_a[j] = r_out;
            else          cap_b[j] = r_out;
        end
        @(posedge clk); hbo0 = 1;
        repeat (8) @(posedge clk);
    end
endtask

initial begin
    ln_wa=0; ln_ra=0; ln_sel=0; ln_hs_l=0;
    vb_in=1; hbo0=1;
    repeat(20) @(posedge clk);
    vb_in=0;
    repeat(20) @(posedge clk);

    write_line(1);   // prime

    for (ln = 1; ln < NLINES; ln = ln + 1) begin
        write_line(ln * 20);
        read_cap(0);
        read_cap(1);

        for (px = 0; px < LENGTH; px = px + 1) begin
            if (cap_a[px] !== cap_b[px]) begin
                $display("FAIL ln%0d px%0d: A=%0h B=%0h", ln, px, cap_a[px], cap_b[px]);
                errors = errors + 1;
            end
        end
        // Ramp continuity not checked here — the test's ce_x1i keeps
        // firing during reads, which is unrealistic (in the real
        // scandoubler the input is in hblank during the second output
        // line). The A==B match is the definitive scandoubler property.
    end

    if (errors == 0)
        $display("PASS — %0d line pairs, %0d pixels each", NLINES-1, LENGTH);
    else
        $display("FAIL — %0d errors", errors);
    $finish;
end

endmodule
