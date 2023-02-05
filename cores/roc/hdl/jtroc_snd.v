/*  This file is part of JTKICKER.
    JTKICKER program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKICKER program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKICKER.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-8-2022 */

module jtroc_snd(
    input                rst,
    input                clk,
    // ROM
    output       [13:0]  rom_addr, // the schematics a third 4kB ROM chip, which is unused
    output  reg          rom_cs,
    input        [ 7:0]  rom_data,
    input                rom_ok,
    // From main CPU
    input        [ 7:0]  main_latch,
    input                snd_on,
    input                mute,

    output signed [15:0] snd,
    output               sample,
    output               peak,
    output        [ 7:0] st_dout
);

localparam [7:0] PSG_GAIN = 8'h10;

reg  [ 7:0] din;
wire [ 7:0] ram_dout, dout, psg0_dout, psg1_dout;
wire        irq_ack, int_n;
wire        psg_cen;
wire [ 9:0] psg0_snd, psg1_snd;
reg         ram_cs, filter_cs;
reg  [ 4:1] sen; // control lines for PSG chips
wire [ 1:0] bdir, bc1;
wire        mreq_n, rfsh_n, iorq_n, m1_n,
            wrn, rdn;
wire [15:0] A;
reg  [11:0] filter_en;
reg  [ 8:0] cnt;
reg  [ 3:0] biq_cnt;

assign irq_ack = ~iorq_n & ~m1_n;
assign rom_addr = A[13:0];
assign bdir[0]  = ~(sen[1] | wrn) | ~sen[2];
assign bc1[0]   = ~(sen[1] | rdn) | ~sen[2];
assign bdir[1]  = ~(sen[3] | wrn) | ~sen[4];
assign bc1[1]   = ~(sen[3] | rdn) | ~sen[4];
assign st_dout  = filter_en[7:0];

jtframe_cen3p57 #(.CLK24(1)) u_cen3p57(
    .clk      ( clk      ),
    .cen_3p57 (          ),
    .cen_1p78 ( psg_cen  )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cnt       <= 0;
        biq_cnt   <= 0;
        filter_en <= 12'hfff;
    end else begin
        if( psg_cen ) begin
            cnt<=cnt+1'd1;
            if( &cnt ) begin
                biq_cnt <= biq_cnt[2:0]==3'b100 ? { ~biq_cnt[3], 3'd0 } : { biq_cnt[3], biq_cnt[2:0]+3'd1 };
            end
        end
        if( filter_cs ) filter_en <= A[11:0];
    end
end

always @* begin
    rom_cs      = 0;
    ram_cs      = 0;
    sen         = 4'b1111;
    filter_cs   = A[15];
    if( !mreq_n && rfsh_n && !A[15]) begin
        case(A[14:12])
            0,1,2: rom_cs = 1;
            3:     ram_cs = 1; // 8000
            4:     sen[1] = 0;
            5:     sen[2] = 0;
            6:     sen[3] = 0;
            7:     sen[4] = 0;
        endcase
    end
end

always @(posedge clk) begin
    din  <= rom_cs   ? rom_data   :
            ram_cs   ? ram_dout   :
            sen[2:1]!=3 ? psg0_dout :
            sen[4:3]!=3 ? psg1_dout :
            8'hff;
end

jt49_bus u_psg0(
    .rst_n      ( ~rst      ),
    .clk        (  clk      ),    // signal on positive edge
    .clk_en     (  psg_cen  ) /* synthesis direct_enable = 1 */,
    .bdir       (  bdir[0]  ),
    .bc1        (  bc1[0]   ),
    .din        (  dout ),

    .sel        ( 1'b1      ),
    .dout       ( psg0_dout ),
    .sound      ( psg0_snd  ),
    .A          (           ),      // linearised channel output
    .B          (           ),
    .C          (           ),
    .sample     ( sample    ),

    .IOA_in     ( main_latch),
    .IOA_out    (           ),

    .IOB_in     ( { biq_cnt[3:1], cnt[8], 4'd0} ),
    .IOB_out    (           )
);

jt49_bus u_psg1(
    .rst_n      ( ~rst      ),
    .clk        (  clk      ),    // signal on positive edge
    .clk_en     (  psg_cen  ) /* synthesis direct_enable = 1 */,
    .bdir       (  bdir[1]  ),
    .bc1        (  bc1[1]   ),
    .din        (  dout ),

    .sel        ( 1'b1      ),
    .dout       ( psg1_dout ),
    .sound      ( psg1_snd  ),
    .A          (           ),      // linearised channel output
    .B          (           ),
    .C          (           ),
    .sample     (           ),

    .IOA_in     ( 8'd0      ),
    .IOA_out    (           ),

    .IOB_in     ( 8'd0      ),
    .IOB_out    (           )
);

jtframe_mixer #(.W0(10),.W1(10)) u_mixer(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( psg_cen   ),
    // input signals
    .ch0    ( psg0_snd  ),
    .ch1    ( psg1_snd  ),
    .ch2    ( 16'd0     ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( PSG_GAIN  ),
    .gain1  ( PSG_GAIN  ),
    .gain2  ( 8'h00     ),
    .gain3  ( 8'h00     ),
    .mixed  ( snd       ),
    .peak   ( peak      )
);

jtframe_ff u_irq(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( int_n       ),
    .set      (             ),
    .clr      ( irq_ack     ),
    .sigedge  ( snd_on      )
);

/* verilator tracing_off */

jtframe_sysz80 #(.RAM_AW(10)) u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( psg_cen     ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rdn         ),
    .wr_n       ( wrn         ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( din         ),
    .cpu_dout   ( dout        ),
    .ram_dout   ( ram_dout    ),
    // manage access to ROM data from SDRAM
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);

endmodule
