localparam [26:0] CPUTEST_STATUS_ADDR = 27'h7ff0048;
localparam [ 3:0] T06_SPRDMA_SCENE_WRITES = 4'd12;

reg        cputest_status_wr_l;
reg        t06_sprdma_scene_active;
reg [ 3:0] t06_sprdma_scene_idx;

wire cputest_status_wr    = !rd_wr_n && main_addr == CPUTEST_STATUS_ADDR;
wire cputest_status_pulse = cputest_status_wr && !cputest_status_wr_l;

function [10:0] t06_sprdma_expected_addr;
    input [3:0] idx;
    begin
        t06_sprdma_expected_addr = {7'd0, idx};
    end
endfunction

function [31:0] t06_sprdma_expected_data;
    input [3:0] idx;
    begin
        case (idx)
            4'd0:    t06_sprdma_expected_data = 32'h2460_1803;
            4'd1:    t06_sprdma_expected_data = 32'h000b_000f;
            4'd2:    t06_sprdma_expected_data = 32'h1122_3344;
            4'd3:    t06_sprdma_expected_data = 32'h5566_7788;
            4'd4:    t06_sprdma_expected_data = 32'h1234_0805;
            4'd5:    t06_sprdma_expected_data = 32'h0011_0014;
            4'd6:    t06_sprdma_expected_data = 32'ha1a2_a3a4;
            4'd7:    t06_sprdma_expected_data = 32'hb1b2_b3b4;
            4'd8:    t06_sprdma_expected_data = 32'h8000_0000;
            default: t06_sprdma_expected_data = 32'd0;
        endcase
    end
endfunction

always @(posedge clk) begin
    if (rst) begin
        cputest_status_wr_l <= 1'b0;
        t06_sprdma_scene_active <= 1'b0;
        t06_sprdma_scene_idx <= 4'd0;
    end else begin
        cputest_status_wr_l <= cputest_status_wr;

        if (cputest_status_pulse && cpu_dout[31:16] == 16'h1006) begin
            if (cpu_dout[7:0] == 8'h05) begin
                t06_sprdma_scene_active <= 1'b1;
                t06_sprdma_scene_idx <= 4'd0;
            end
            if (cpu_dout[7:0] == 8'h07) begin
                t06_sprdma_scene_active <= 1'b0;
                if (t06_sprdma_scene_idx != T06_SPRDMA_SCENE_WRITES) begin
                    $display("FAIL test=T06 code=sprite-scene-count pc=available");
                    $finish;
                end
            end
        end

        if (t06_sprdma_scene_active && scene_we == 4'hf) begin
            if (t06_sprdma_scene_idx >= T06_SPRDMA_SCENE_WRITES) begin
                $display("FAIL test=T06 code=sprite-scene-extra pc=available");
                $finish;
            end else if (scene_addr != t06_sprdma_expected_addr(t06_sprdma_scene_idx)) begin
                $display("FAIL test=T06 code=sprite-scene-addr-%0d pc=available",
                    t06_sprdma_scene_idx);
                $finish;
            end else if (scene_din != t06_sprdma_expected_data(t06_sprdma_scene_idx)) begin
                $display("FAIL test=T06 code=sprite-scene-data-%0d pc=available got=%08X",
                    t06_sprdma_scene_idx, scene_din);
                $finish;
            end else begin
                t06_sprdma_scene_idx <= t06_sprdma_scene_idx + 4'd1;
            end
        end
    end
end