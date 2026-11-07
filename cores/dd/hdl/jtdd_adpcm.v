/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-12-2019 */

// Clocks are derived from H counter on the original PCB
// Yet, that doesn't seem to be important and it only
// matters the frequency of the signals:
// E,Q: 3 MHz
// Q is 1/4th of wave advanced

module jtdd_adpcm(
    input               clk,
    input               rst,
    input               cpu_cen,
    input               cen_oki,        // 375 kHz
    // communication with main CPU
    input   [ 7:0]      cpu_dout,
    input   [ 1:0]      cpu_AB,
    input               cs,
    // ROM
    output     [15:0]   rom_addr,
    output              rom_cs,
    input      [ 7:0]   rom_data,
    input               rom_ok,

    // Sound output
    output  signed [11:0] snd,
    output              sample
);

reg [9:0] cnt;
reg [3:0] din;
reg [7:0] addr0, addr1;
reg       ad_rst, start;
wire     over = addr0 == addr1;

always @(posedge clk, posedge rst) begin
    if(rst) begin
        addr0  <= 8'd0;
        addr1  <= 8'd0;
        ad_rst <= 1'b1;
        cnt    <= 10'd0;
        din    <= 4'b0;
    end else begin
        if(cs) begin
            case(cpu_AB)
                2'd0: ad_rst <= 1'b0;
                2'd1: addr1  <= cpu_dout;
                2'd2: addr0  <= cpu_dout;
                2'd3: begin
                    ad_rst <= 1'b1;       // stop
                    cnt    <= 10'd0;
                end
            endcase
            if( cpu_AB != 2'd0 ) begin
                ad_rst <= 1'b1;
                cnt    <= 10'd0;
            end
        end
        if(rom_ok) din  <= !cnt[0] ? rom_data[7:4] : rom_data[3:0];
        if( !ad_rst ) begin
            if( sample ) begin
                cnt  <= cnt + 10'd1;
                if(&cnt) addr0 <= addr0+8'd1;
            end
            if( over ) begin
                ad_rst <= 1'b1;
                cnt    <= 10'd0;
            end
        end
    end
end

assign rom_addr = { addr0[6:0], cnt[9:1] };
assign rom_cs   = 1'b1;

jt5205 #(.INTERPOL(0)) u_decod(
    .rst    ( ad_rst    ),
    .clk    ( clk       ),
    .cen    ( cen_oki   ),
    .sel    ( 2'b10     ),
    .din    ( din       ),
    .sound  ( snd       ),
    .irq    ( sample    ),
    // unused
    .vclk_o (           ),
    .sample (           )
);

endmodule