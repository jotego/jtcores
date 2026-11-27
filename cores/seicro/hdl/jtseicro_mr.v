/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

module jtseicro_mr(
    input       rst, clk,
    input       e, vma, a15,
    input       release_clk,
    output      mr_n
);

// Physical pins, polarity and timing qualifications: ../doc/hardware_verification.md.
wire request=e & vma & a15;
reg request_l, release_l;
reg pending, armed;

assign mr_n=!pending;

always @(posedge clk) begin
    request_l <= request;
    release_l <= release_clk;
    if(rst) begin
        pending <= 0;
        armed <= 0;
    end else if(!pending) begin
        armed <= 0;
        if(request && !request_l) pending <= 1;
    end else begin
        if(release_clk && !release_l) armed <= 1;
        if(!release_clk && release_l && armed) begin
            pending <= 0;
            armed <= 0;
        end
    end
end

endmodule
