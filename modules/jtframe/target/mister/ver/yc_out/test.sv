`timescale 1ns/1ps

module test;
logic clk=0;
always #5 clk=~clk;

logic [39:0] phase_inc=40'h1000000000;
logic [16:0] burst_range=17'h01014; // clocks 4 through 20 after hsync
logic hsync=0, vsync=0, csync=0, de=0;
logic [23:0] din=0;
wire [23:0] pal_dout, ntsc_dout, cvbs_dout, ntsc_cvbs_dout;
wire pal_hsync, pal_vsync, pal_csync, pal_de;
wire ntsc_hsync, ntsc_vsync, ntsc_csync, ntsc_de;
wire cvbs_hsync, cvbs_vsync, cvbs_csync, cvbs_de;
wire ntsc_cvbs_hsync, ntsc_cvbs_vsync, ntsc_cvbs_csync, ntsc_cvbs_de;

localparam logic signed [10:0] expected_lut [0:255] = '{
	11'h000, 11'h006, 11'h00C, 11'h012, 11'h018, 11'h01F, 11'h025, 11'h02B,
	11'h031, 11'h037, 11'h03D, 11'h044, 11'h04A, 11'h04F, 11'h055, 11'h05B,
	11'h061, 11'h067, 11'h06D, 11'h072, 11'h078, 11'h07D, 11'h083, 11'h088,
	11'h08D, 11'h092, 11'h097, 11'h09C, 11'h0A1, 11'h0A6, 11'h0AB, 11'h0AF,
	11'h0B4, 11'h0B8, 11'h0BC, 11'h0C1, 11'h0C5, 11'h0C9, 11'h0CC, 11'h0D0,
	11'h0D4, 11'h0D7, 11'h0DA, 11'h0DD, 11'h0E0, 11'h0E3, 11'h0E6, 11'h0E9,
	11'h0EB, 11'h0ED, 11'h0F0, 11'h0F2, 11'h0F4, 11'h0F5, 11'h0F7, 11'h0F8,
	11'h0FA, 11'h0FB, 11'h0FC, 11'h0FD, 11'h0FD, 11'h0FE, 11'h0FE, 11'h0FE,
	11'h0FF, 11'h0FE, 11'h0FE, 11'h0FE, 11'h0FD, 11'h0FD, 11'h0FC, 11'h0FB,
	11'h0FA, 11'h0F8, 11'h0F7, 11'h0F5, 11'h0F4, 11'h0F2, 11'h0F0, 11'h0ED,
	11'h0EB, 11'h0E9, 11'h0E6, 11'h0E3, 11'h0E0, 11'h0DD, 11'h0DA, 11'h0D7,
	11'h0D4, 11'h0D0, 11'h0CC, 11'h0C9, 11'h0C5, 11'h0C1, 11'h0BC, 11'h0B8,
	11'h0B4, 11'h0AF, 11'h0AB, 11'h0A6, 11'h0A1, 11'h09C, 11'h097, 11'h092,
	11'h08D, 11'h088, 11'h083, 11'h07D, 11'h078, 11'h072, 11'h06D, 11'h067,
	11'h061, 11'h05B, 11'h055, 11'h04F, 11'h04A, 11'h044, 11'h03D, 11'h037,
	11'h031, 11'h02B, 11'h025, 11'h01F, 11'h018, 11'h012, 11'h00C, 11'h006,
	11'h000, 11'h7F9, 11'h7F3, 11'h7ED, 11'h7E7, 11'h7E0, 11'h7DA, 11'h7D4,
	11'h7CE, 11'h7C8, 11'h7C2, 11'h7BB, 11'h7B5, 11'h7B0, 11'h7AA, 11'h7A4,
	11'h79E, 11'h798, 11'h792, 11'h78D, 11'h787, 11'h782, 11'h77C, 11'h777,
	11'h772, 11'h76D, 11'h768, 11'h763, 11'h75E, 11'h759, 11'h754, 11'h750,
	11'h74B, 11'h747, 11'h743, 11'h73E, 11'h73A, 11'h736, 11'h733, 11'h72F,
	11'h72B, 11'h728, 11'h725, 11'h722, 11'h71F, 11'h71C, 11'h719, 11'h716,
	11'h714, 11'h712, 11'h70F, 11'h70D, 11'h70B, 11'h70A, 11'h708, 11'h707,
	11'h705, 11'h704, 11'h703, 11'h702, 11'h702, 11'h701, 11'h701, 11'h701,
	11'h701, 11'h701, 11'h701, 11'h701, 11'h702, 11'h702, 11'h703, 11'h704,
	11'h705, 11'h707, 11'h708, 11'h70A, 11'h70B, 11'h70D, 11'h70F, 11'h712,
	11'h714, 11'h716, 11'h719, 11'h71C, 11'h71F, 11'h722, 11'h725, 11'h728,
	11'h72B, 11'h72F, 11'h733, 11'h736, 11'h73A, 11'h73E, 11'h743, 11'h747,
	11'h74B, 11'h750, 11'h754, 11'h759, 11'h75E, 11'h763, 11'h768, 11'h76D,
	11'h772, 11'h777, 11'h77C, 11'h782, 11'h787, 11'h78D, 11'h792, 11'h798,
	11'h79E, 11'h7A4, 11'h7AA, 11'h7B0, 11'h7B5, 11'h7BB, 11'h7C2, 11'h7C8,
	11'h7CE, 11'h7D4, 11'h7DA, 11'h7E0, 11'h7E7, 11'h7ED, 11'h7F3, 11'h7F9
};

logic [6:0] expected_hsync=0, expected_vsync=0, expected_csync=0, expected_de=0;
int cycles=0;
int active_non_neutral=0, cvbs_nonzero=0;
int burst_min=255, burst_max=0, active_min=255, active_max=0;
int ntsc_burst_min=255, ntsc_burst_max=0;
int active_ntsc_min=255, active_ntsc_max=0;
integer sample_fd;
logic [23:0] rgb_history [0:6];
logic [27:0] input_trace [0:260];
logic [31:0] expected_chroma [0:260];

yc_out u_pal(
    .clk(clk), .PHASE_INC(phase_inc), .PAL_EN(1'b1), .CVBS(1'b0),
    .COLORBURST_RANGE(burst_range), .hsync(hsync), .vsync(vsync), .csync(csync),
    .de(de), .din(din), .dout(pal_dout), .hsync_o(pal_hsync), .vsync_o(pal_vsync),
    .csync_o(pal_csync), .de_o(pal_de)
);

yc_out u_ntsc(
    .clk(clk), .PHASE_INC(phase_inc), .PAL_EN(1'b0), .CVBS(1'b0),
    .COLORBURST_RANGE(burst_range), .hsync(hsync), .vsync(vsync), .csync(csync),
    .de(de), .din(din), .dout(ntsc_dout), .hsync_o(ntsc_hsync), .vsync_o(ntsc_vsync),
    .csync_o(ntsc_csync), .de_o(ntsc_de)
);

yc_out u_cvbs(
    .clk(clk), .PHASE_INC(phase_inc), .PAL_EN(1'b1), .CVBS(1'b1),
    .COLORBURST_RANGE(burst_range), .hsync(hsync), .vsync(vsync), .csync(csync),
    .de(de), .din(din), .dout(cvbs_dout), .hsync_o(cvbs_hsync), .vsync_o(cvbs_vsync),
    .csync_o(cvbs_csync), .de_o(cvbs_de)
);

yc_out u_ntsc_cvbs(
    .clk(clk), .PHASE_INC(phase_inc), .PAL_EN(1'b0), .CVBS(1'b1),
    .COLORBURST_RANGE(burst_range), .hsync(hsync), .vsync(vsync), .csync(csync),
    .de(de), .din(din), .dout(ntsc_cvbs_dout), .hsync_o(ntsc_cvbs_hsync), .vsync_o(ntsc_cvbs_vsync),
    .csync_o(ntsc_cvbs_csync), .de_o(ntsc_cvbs_de)
);

// Output value for the integer coefficient approximation used by yc_out.
function automatic [7:0] expected_luma(input [23:0] rgb);
    integer total;
    begin
        total = rgb[23:16]*306 + rgb[15:8]*601 + rgb[7:0]*117;
        expected_luma = total >> 10;
    end
endfunction

task automatic tick;
    logic [7:0] expected_y;
    begin
        @(posedge clk); #1;
        cycles++;
`ifndef YC_SKIP_CONTROL
        if ({pal_hsync,pal_vsync,pal_csync,pal_de} !== {expected_hsync[6],expected_vsync[6],expected_csync[6],expected_de[6]} ||
            {ntsc_hsync,ntsc_vsync,ntsc_csync,ntsc_de} !== {expected_hsync[6],expected_vsync[6],expected_csync[6],expected_de[6]} ||
            {cvbs_hsync,cvbs_vsync,cvbs_csync,cvbs_de} !== {expected_hsync[6],expected_vsync[6],expected_csync[6],expected_de[6]} ||
            {ntsc_cvbs_hsync,ntsc_cvbs_vsync,ntsc_cvbs_csync,ntsc_cvbs_de} !== {expected_hsync[6],expected_vsync[6],expected_csync[6],expected_de[6]}) begin
            $error("control alignment cycle %0d expected h/v/c/de=%b got PAL=%b NTSC=%b CVBS=%b",
                cycles, {expected_hsync[6],expected_vsync[6],expected_csync[6],expected_de[6]}, {pal_hsync,pal_vsync,pal_csync,pal_de},
                {ntsc_hsync,ntsc_vsync,ntsc_csync,ntsc_de}, {cvbs_hsync,cvbs_vsync,cvbs_csync,cvbs_de});
            $fatal(1);
        end
`endif
`ifndef YC_SKIP_CONTROL
        expected_y=expected_de[6] ? expected_luma(rgb_history[6]) : 8'd0;
        if (pal_dout[15:8] !== expected_y || ntsc_dout[15:8] !== expected_y) begin
            $error("cycle-exact luma/DE mismatch cycle %0d input rgb=%06h delayed DE=%b expected Y=%0d PAL=%0d NTSC=%0d",
                cycles, rgb_history[6], expected_de[6], expected_y, pal_dout[15:8], ntsc_dout[15:8]);
            $fatal(1);
        end
`endif
`ifndef YC_SKIP_CHROMA_ORACLE
        if (cycles == 21 && {pal_dout[23:16],ntsc_dout[23:16]} !== {8'd111,8'd141}) begin
            $error("first burst sample mismatch: PAL=%0d NTSC=%0d", pal_dout[23:16],ntsc_dout[23:16]);
            $fatal(1);
        end
        if (cycles == 37 && {pal_dout[23:16],ntsc_dout[23:16]} !== {8'd111,8'd141}) begin
            $error("last burst sample mismatch: PAL=%0d NTSC=%0d", pal_dout[23:16],ntsc_dout[23:16]);
            $fatal(1);
        end
        if (cycles == 201 && {pal_dout[23:16],ntsc_dout[23:16]} !== {8'd111,8'd91}) begin
            $error("second PAL phase burst sample mismatch: PAL=%0d NTSC=%0d", pal_dout[23:16],ntsc_dout[23:16]);
            $fatal(1);
        end
        if (cycles == 228 && {pal_dout[23:16],ntsc_dout[23:16]} !== {8'd229,8'd229}) begin
            $error("second PAL phase active chroma mismatch: PAL=%0d NTSC=%0d", pal_dout[23:16],ntsc_dout[23:16]);
            $fatal(1);
        end
        if ({pal_dout[23:16],ntsc_dout[23:16],cvbs_dout[15:8],ntsc_cvbs_dout[15:8]} !== expected_chroma[cycles-1]) begin
            $error("independent chroma oracle mismatch cycle %0d got %08h expected %08h",
                cycles, {pal_dout[23:16],ntsc_dout[23:16],cvbs_dout[15:8],ntsc_cvbs_dout[15:8]}, expected_chroma[cycles-1]);
            $fatal(1);
        end
`endif
        if (pal_de) begin
            if (pal_dout[23:16] < active_min) active_min=pal_dout[23:16];
            if (pal_dout[23:16] > active_max) active_max=pal_dout[23:16];
            if (ntsc_dout[23:16] < active_ntsc_min) active_ntsc_min=ntsc_dout[23:16];
            if (ntsc_dout[23:16] > active_ntsc_max) active_ntsc_max=ntsc_dout[23:16];
            if (pal_dout[23:16] != 8'd128) active_non_neutral++;
        end
        if (expected_de[6] && (cvbs_dout[15:8] != 8'd0 || ntsc_cvbs_dout[15:8] != 8'd0)) cvbs_nonzero++;
        $fwrite(sample_fd,"%0d,%0d,%0d,%0d,%0d,%06h,%02h,%02h,%02h,%02h,%02h,%02h\n",
            cycles,hsync,vsync,csync,de,din,pal_dout[23:16],pal_dout[15:8],
            ntsc_dout[23:16],ntsc_dout[15:8],cvbs_dout[15:8],ntsc_cvbs_dout[15:8]);
        for (int k=6; k>0; k--) begin
            expected_hsync[k]=expected_hsync[k-1];
            expected_vsync[k]=expected_vsync[k-1];
            expected_csync[k]=expected_csync[k-1];
            expected_de[k]=expected_de[k-1];
            rgb_history[k]=rgb_history[k-1];
        end
        expected_hsync[0]=hsync;
        expected_vsync[0]=vsync;
        expected_csync[0]=csync;
        expected_de[0]=de;
        rgb_history[0]=din;
    end
endtask

initial begin : run_test
    int i;

    sample_fd=$fopen("yc_samples.csv","w");
    if (!sample_fd) begin $error("cannot open yc_samples.csv"); $fatal(1); end
    $fdisplay(sample_fd,"cycle,hsync,vsync,csync,de,din,pal_c,pal_y,ntsc_c,ntsc_y,pal_cvbs_y,ntsc_cvbs_y");
    for (i=0; i<7; i++) rgb_history[i]=24'd0;
    $readmemh("obj_dir/yc_trace.hex",input_trace);
    $readmemh("obj_dir/yc_expected.hex",expected_chroma);

    for (i=0; i<256; i++) begin
        if (u_pal.chroma_SIN_LUT[i] !== expected_lut[i]) begin
            $error("preserved sine sample %0d changed: got %03h expected %03h", i,
                u_pal.chroma_SIN_LUT[i], expected_lut[i]);
            $fatal(1);
        end
    end
    $display("Preserved all 256 signed sine-table samples (legacy asymmetric quantization)");

    for (i=0; i<261; i++) begin
        {hsync,vsync,csync,de,din}=input_trace[i];
        tick();
        if (cycles >= 21 && cycles <= 37) begin
            if (pal_dout[23:16] < burst_min) burst_min=pal_dout[23:16];
            if (pal_dout[23:16] > burst_max) burst_max=pal_dout[23:16];
            if (ntsc_dout[23:16] < ntsc_burst_min) ntsc_burst_min=ntsc_dout[23:16];
            if (ntsc_dout[23:16] > ntsc_burst_max) ntsc_burst_max=ntsc_dout[23:16];
        end
        if (cycles >= 51 && cycles <= 70 &&
            (pal_dout[23:16] !== 8'd128 || ntsc_dout[23:16] !== 8'd128)) begin
            $error("active-video chroma leaked into red blanking at cycle %0d", cycles);
            $fatal(1);
        end
    end

    if (burst_min >= 128 || burst_max <= 128 || ntsc_burst_min >= 128 || ntsc_burst_max <= 128) begin
        $error("PAL/NTSC burst did not span both sides of neutral: PAL=%0d..%0d NTSC=%0d..%0d",
            burst_min, burst_max, ntsc_burst_min, ntsc_burst_max);
        $fatal(1);
    end

    if (active_non_neutral < 4 || active_min >= 128 || active_max <= 128 ||
        active_ntsc_min >= 128 || active_ntsc_max <= 128 || cvbs_nonzero < 6) begin
        $error("nonblank chroma/CVBS variation too low: PAL n/min/max=%0d/%0d/%0d NTSC=%0d/%0d CVBS=%0d",
            active_non_neutral, active_min, active_max, active_ntsc_min, active_ntsc_max, cvbs_nonzero);
        $fatal(1);
    end

    $fclose(sample_fd);
    $display("PASS yc_out: exact chroma samples=%0d cycles, burst PAL[%0d..%0d] NTSC[%0d..%0d] active PAL n/min/max=%0d/%0d/%0d NTSC min/max=%0d/%0d CVBS=%0d",
        cycles, burst_min, burst_max, ntsc_burst_min, ntsc_burst_max, active_non_neutral, active_min, active_max,
        active_ntsc_min, active_ntsc_max, cvbs_nonzero);
    $finish;
end
endmodule
