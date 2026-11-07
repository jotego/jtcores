/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-1-2025 */

module jtframe_pause(
    input      rst, clk,
               key_pause, joy_pause, osd_pause, adv_frame,
               lvbl,
    output     game_pause
);
    reg  toggle=0;
    wire frame;

    always @(posedge clk) begin
        toggle <= |{key_pause, joy_pause, osd_pause, frame };
    end

    jtframe_pause_adv_frame u_frame(
        .clk    ( clk       ),
        .adv    ( adv_frame ),
        .lvbl   ( lvbl      ),
        .pause  ( game_pause),
        .frame  ( frame     )
    );

    jtframe_toggle #(.W(1)) u_toggle(
        .rst    ( rst        ),
        .clk    ( clk        ),
        .toggle ( toggle     ),
        .q      ( game_pause )
    );
endmodule        

module jtframe_pause_adv_frame(
    input       clk, adv, lvbl, pause,
    output reg  frame=0
);
    reg lvbl_l=0, adv_l=0, adv_event=0, restore=0;

    always @(posedge clk) begin
        lvbl_l     <= lvbl;
        adv_l  <= adv;
        frame <= 0;
        if( adv && !adv_l ) adv_event <= pause;
        if( !lvbl && lvbl_l ) begin
            frame    <= adv_event | restore;
            restore  <= adv_event;
            adv_event <= 0;
        end
    end
endmodule