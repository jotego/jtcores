/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

module jt680x_bus(
    input             rst, abort, clk, cen, enable,
    input             ready, mr_n,
    input             cycle_active, cycle_vma, cycle_wr,
    input      [15:0] cycle_addr,
    input      [ 7:0] cycle_dout,
    output reg        e, vma, wr,
    output reg [15:0] addr,
    output reg [ 7:0] dout,
    output            done
);

reg [1:0] phase;
reg active;

assign done=!rst && !abort && active && cen && enable && phase==3 && ready && mr_n;

always @(posedge clk) begin
    if(rst) begin
        phase <= 0;
        e <= 0;
        vma <= 0;
        wr <= 0;
        addr <= 0;
        dout <= 0;
        active <= 0;
    end else begin
        if(abort) begin
            active <= 0;
            vma <= 0;
            wr <= 0;
        end
        if(cen && enable) begin
            case(phase)
                0: begin
                    addr <= cycle_addr;
                    dout <= cycle_dout;
                    wr <= cycle_wr && !abort && cycle_active;
                    vma <= cycle_vma && !abort && cycle_active;
                    active <= !abort && cycle_active;
                    phase <= 1;
                end
                1: begin
                    e <= 1;
                    phase <= 2;
                end
                2: phase <= 3;
                3: begin
                    if(abort || !active) begin
                        e <= 0;
                        phase <= 0;
                    end else if(ready) begin
                        if(mr_n) begin
                            e <= 0;
                            phase <= 0;
                        end else begin
                            phase <= 2;
                        end
                    end
                end
            endcase
        end
    end
end

endmodule
