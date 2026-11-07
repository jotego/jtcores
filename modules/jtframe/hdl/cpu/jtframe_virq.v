/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 9-4-2021 */

module jtframe_virq(
    input      rst,
    input      clk,
    input      LVBL,
    input      dip_pause,
    input      skip_en,        // enable slow motion (if button pressed)
    input      skip_but,       // button press for slow motion

    input      clr,            // clear the interrupt
    input      custom_in,      // trigger the custom interrupt
    output reg blin_n,         // low when entering VBLANK
    output reg blout_n,        // low when leaving  VBLANK
    output reg custom_n        // custom condition
);

reg last_LVBL, last_cin, skip;

always @(posedge clk) begin : int_gen
    if( rst ) begin
        custom_n <= 1;
        blin_n   <= 1;
        blout_n  <= 1;
        last_cin <= 0;
        skip     <= 0;
    end else begin
        last_LVBL <= LVBL;
        last_cin  <= custom_in;

        if( !skip_en) begin
            skip <= 0;
        end else begin
            if( LVBL && !last_LVBL ) begin
                if( skip_but )
                    skip <= ~skip;
                else
                    skip <= 0;
            end
        end

        if( clr ) begin
            custom_n <= 1;
            blin_n   <= 1;
            blout_n  <= 1;
        end else if( !skip && dip_pause ) begin
            if( custom_in && !last_cin ) custom_n <= 0;
            if( !LVBL &&  last_LVBL    ) blin_n   <= 0;
            if(  LVBL && !last_LVBL    ) blout_n  <= 0;
        end
    end
end

endmodule