// Carried core-locally because there is no modules/jt89 submodule in this
// tree. Should move to a real modules/jt89 submodule if one is added.

/*  This file is part of JT89.

    JT89 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT89 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT89.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: March, 8th 2017

    This work was originally based in the implementation found on the
    SMS core of MiST. Some of the changes, all according to data sheet:

        -Fixed volume
        -Fixed tone 2 rate option of noise generator
        -Fixed rate of noise generator
        -Fixed noise shift clear
        -Fixed noise generator update bug by which it gets updated
            multiple times if v='0'
        -Added all 0's prevention circuit to noise generator

    */

/* verilator tracing_off */

module jt89(
    input          rst,
    input          clk,
(* direct_enable = 1 *) input   clk_en,
    input          wr_n,
    input          cs_n,    // set to 0 if not needed
    input    [7:0] din,
    output signed [10:0] sound,
    output reg     ready
);

parameter INTERPOL16=0,MODE=0;

wire signed [ 8:0] ch0, ch1, ch2, noise;

(* direct_enable = 1 *) reg cen_16;
(* direct_enable = 1 *) reg cen_4;

jt89_mixer #(.INTERPOL16(INTERPOL16),.MODE(MODE)) mix(
    .clk    ( clk   ),
    .clk_en ( clk_en), // uses main clock enable
    .cen_16 ( cen_16),
    .cen_4  ( cen_4 ),
    .rst    ( rst   ),
    .ch0    ( ch0   ),
    .ch1    ( ch1   ),
    .ch2    ( ch2   ),
    .noise  ( noise ),
    .sound  ( sound )
);

// configuration registers
reg [9:0] tone0, tone1, tone2;
reg [3:0] vol0, vol1, vol2, vol3;
reg [2:0] ctrl3;
reg [2:0] regn;

reg [3:0] clk_div;

always @(posedge clk ) begin
    if( rst ) begin
        cen_16 <= 1'b1;
        cen_4  <= 1'b1;
    end else begin
        cen_16 <= clk_en & (&clk_div);
        cen_4  <= clk_en & (&clk_div[1:0]);
    end
end

// Ready signal control
reg       last_wr, last_csn;
reg [4:0] rdy_cnt;
wire      wr;

assign wr = ~cs_n & ~wr_n;

always @(posedge clk ) begin
    if( rst ) begin
        rdy_cnt <= 0;
        ready   <= 1;
        last_csn<= 1;
    end else begin
        last_csn <= cs_n;
        if( rdy_cnt==0 ) ready <= 1;
        if( rdy_cnt!=0 && clk_en ) rdy_cnt <= rdy_cnt-1'd1;
        if( !cs_n && last_csn ) begin
            ready   <= 0;
            rdy_cnt <= 5'h1f;
        end
    end
end

always @(posedge clk ) begin
    if( rst )
        clk_div <= 4'd0;
    else if( clk_en )
        clk_div <= clk_div + 1'b1;
end

reg clr_noise;
wire [2:0] reg_sel = din[7] ? din[6:4] : regn;

always @(posedge clk) begin
    if( rst ) begin
        { vol0, vol1, vol2, vol3 } <= {16{1'b1}};
        { tone0, tone1, tone2 } <= 30'd0;
        ctrl3 <= 3'b100;
    end
    else begin
        last_wr <= wr;
        if( wr && !last_wr ) begin
            // MODIFIED 2026-07-28 (Arcade-Ikki): MAME resets the noise LFSR on
            // any access to register 6, including the data byte that follows a
            // latch, not only on the latch byte itself.
            clr_noise <= reg_sel == 3'b110; // clear noise
            // when there is an access to the control register
            regn <= reg_sel;
            case( reg_sel )
                3'b00_0: if( din[7] ) tone0[3:0]<=din[3:0]; else tone0[9:4]<=din[5:0];
                3'b01_0: if( din[7] ) tone1[3:0]<=din[3:0]; else tone1[9:4]<=din[5:0];
                3'b10_0: if( din[7] ) tone2[3:0]<=din[3:0]; else tone2[9:4]<=din[5:0];
                3'b11_0: ctrl3 <= din[2:0];
                3'b00_1: vol0  <= din[3:0];
                3'b01_1: vol1  <= din[3:0];
                3'b10_1: vol2  <= din[3:0];
                3'b11_1: vol3  <= din[3:0];
            endcase
        end
        else clr_noise <= 1'b0;
    end
end

jt89_tone u_tone0(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .clk_en ( cen_16    ),
    .vol    ( vol0      ),
    .tone   ( tone0     ),
    .snd    ( ch0       ),
    .out    (           )
);

jt89_tone u_tone1(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .clk_en ( cen_16    ),
    .vol    ( vol1      ),
    .tone   ( tone1     ),
    .snd    ( ch1       ),
    .out    (           )
);

wire out2;

jt89_tone u_tone2(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .clk_en ( cen_16    ),
    .vol    ( vol2      ),
    .tone   ( tone2     ),
    .snd    ( ch2       ),
    .out    ( out2      )
);

jt89_noise u_noise(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .clk_en ( cen_16    ),
    .clr    ( clr_noise ),
    .vol    ( vol3      ),
    .ctrl3  ( ctrl3     ),
    .tone2  ( out2      ),
    .snd    ( noise     )
);

endmodule
