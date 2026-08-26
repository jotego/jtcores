/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-8-2024 */

module jt054321(
    input            rst,
    input            clk,
    input      [3:0] maddr,
    input      [7:0] mdout,
    output reg [7:0] mdin,
    input            mwe,

    input      [1:0] saddr,
    input      [7:0] sdout,
    output reg [7:0] sdin,
    input            swe,

    // Z80 bus control
    input            snd_on,
    input            siorq_n,
    output reg       int_n
);

reg [7:0] snd_latch[0:2];
// reg [7:0] active;
reg [5:0] vol;
reg       sndon_l;

always @(posedge clk) begin
    if( rst ) begin
        int_n   <= 1;
        sndon_l <= 0;
    end else begin
        sndon_l <= snd_on;
        if( snd_on && !sndon_l ) int_n<=0;
        if( !siorq_n ) int_n <= 1;
    end
end

always @(posedge clk) begin
    if(rst) begin
        vol          <= 0;
        // active    <= 0;
        snd_latch[0] <= 0;
        snd_latch[1] <= 0;
        snd_latch[2] <= 0;
    end else begin
        // Main CPU
        if(mwe) case(maddr)
            // 0: active <= mdout;
            2: vol <= 0;
            3: if( ~&vol ) vol <= vol+6'd1;
            6: snd_latch[0] <= mdout;
            7: snd_latch[1] <= mdout;
        endcase
        mdin <= maddr==4'd10 ? snd_latch[2] : 8'd0;
        // Sound CPU
        if(swe && saddr==0 ) snd_latch[2] <= sdout;
        sdin <= saddr[0] ? snd_latch[1] : snd_latch[0];
    end
end

endmodule