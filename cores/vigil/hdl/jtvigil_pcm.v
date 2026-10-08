/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 1-5-2022 */

// some PCM codes
//      0020: punch
//      0F20: kick
//      0720: cry when hit
module jtvigil_pcm(
    input             rst,
                      clk,

    input             hi_cs, lo_cs, cnt_up,
    input     [ 7:0]  din,

    output            rom_cs,
    output reg [15:0] rom_addr,
    input      [ 7:0] rom_data,
    input             rom_ok,    

    output reg signed [7:0] snd
);

localparam [7:0] SAMPLE_DONE=0;

reg cntup_l, up;

assign rom_cs = 1;

function signed [7:0] filter_clip_at_end(input [7:0]sample); begin
    reg signed [7:0] pcm_signed;
    reg is_sample_end;

    pcm_signed         = 8'h80 - sample;
    is_sample_end      = sample==SAMPLE_DONE;
    filter_clip_at_end = is_sample_end ? 8'h0 : pcm_signed;
end endfunction

always @(posedge clk) begin
    if( rst ) begin
        rom_addr <= 16'd0;
        cntup_l  <= 0;
        snd      <= 0;
        up       <= 0;
    end else begin
        cntup_l    <= cnt_up;
        if( up && rom_ok ) begin
            snd <= filter_clip_at_end(rom_data);
            up  <= 0;
        end
        if( hi_cs ) begin up <= 1; rom_addr[15:8] <= din; end
        if( lo_cs ) begin up <= 1; rom_addr[ 7:0] <= din; end
        if( cnt_up && !cntup_l ) begin
            rom_addr <= rom_addr + 16'd1;
            up       <= 1;
        end
    end
end

endmodule