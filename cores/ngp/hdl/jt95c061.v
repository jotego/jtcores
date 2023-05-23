/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 19-3-2023 */

// Compatible with TMP95C061

module jt95c061(
    input                 rst,
    input                 clk,
    input                 cen,

    input                 int4,
    input                 nmi,

    output     [23:0]     addr,
    input      [15:0]     din,
    output     [15:0]     dout,
    output     [ 1:0]     we,

    output reg [ 3:0]     map_cs  // cs[0] used as flash chip 0, cs[1] chip 1
                                  // cs[2/3] used for BIOS ROM
);

wire       port_cs;
reg  [7:0] mmr[0:127];
reg  [3:0] pre_map_cs;

// interrupts
wire [ 2:0] intrq;
reg  [ 2:0] nx_ilvl, ilvl;
reg  [ 7:0] nx_iaddr, iaddr;
reg  [21:0] act, nx_act;
wire        irq_ack;
reg         irq;
reg  [10:0] adc_cnt;

// ADC
wire adc_bsy, adc_end;
reg  adc_go;

assign port_cs = addr[23:7]==0;
assign intrq = 0;
assign {adc_end, adc_bsy} = mmr[ADMOD][7:6];

localparam      ADC_BSY = 6,
                ADC_END = 7;

// memory mapper
// MSA registers set the starting address, counting in 64kB pages
// MAM registers set the size, from 256 bytes to 8MB
// the starting address is a multiple of the size, rounded down to the nearest
// 64kB page
localparam [6:0]
                 // 34~37 event capture, ignored
                 MSAR0   = 7'h3C, // set to 20 by NGPC firmware
                 MAMR0   = 7'h3D, // set to FF by NGPC firmware
                 MSAR1   = 7'h3E, // set to 80 by NGPC firmware
                 MAMR1   = 7'h3F, // set to 7F by NGPC firmware
                 // 44~47 event capture, ignored
                 // 4C~4E pattern generator, ignored
                 DREFCR  = 7'h5A, // DRAM refresh rate, ignored
                 DMEMCR  = 7'h5B, // DRAM mode, ignored
                 MSAR2   = 7'h5C, // set to FF by NGPC firmware
                 MAMR2   = 7'h5D, // set to FF by NGPC firmware
                 MSAR3   = 7'h5E, // set to FF by NGPC firmware
                 MAMR3   = 7'h5F, // set to FF by NGPC firmware
                 // 60~67 ADC, ignored
                 B0CS    = 7'h68, // set to 17 = 8 bits, 0 wait
                 B1CS    = 7'h69, // set to 17
                 B2CS    = 7'h6A, // set to 03 = 16 bits, 0 wait
                 B3CS    = 7'h6B, // set to 03
                 // ADC
                 ADREG0L = 7'h60,
                 ADREG0H = 7'h61,
                 ADREG1L = 7'h62,
                 ADREG1H = 7'h63,
                 ADREG2L = 7'h64,
                 ADREG2H = 7'h65,
                 ADREG3L = 7'h66,
                 ADREG3H = 7'h67,
                 ADMOD   = 7'h6D,
                 // interrupt controller
                 INTE0AD = 7'h70,
                 INTE45  = 7'h71,
                 INTE67  = 7'h72,
                 INTET01 = 7'h73,
                 INTET23 = 7'h74,
                 INTET45 = 7'h75,
                 INTET67 = 7'h76,
                 INTES0  = 7'h77,
                 INTES1  = 7'h78,
                 INTTC01 = 7'h79,
                 INTTC23 = 7'h7A;

always @* begin
    pre_map_cs[0]=&{addr[23:21]^mmr[MSAR0][7:5],
                   (addr[20:16]^mmr[MSAR0][4:0])|mmr[MAMR0][7:3],
                    addr[15]   | mmr[MAMR0][2],
                    addr[14:9] | {6{mmr[MAMR0][1]}},
                    addr[8] | mmr[MAMR0][0]
                };
    pre_map_cs[1]=&{addr[23:22]^mmr[MSAR1][7:6],
                   (addr[21:16]^mmr[MSAR1][5:0])|mmr[MAMR1][7:2],
                    addr[15:9] | {7{mmr[MAMR1][1]}},
                    addr[8] | mmr[MAMR1][0], ~pre_map_cs[0]
                };
    pre_map_cs[2]=&{addr[23]   ^mmr[MSAR2][7],
                   (addr[22:16]^mmr[MSAR2][6:0])|mmr[MAMR2][7:1],
                    addr[15] | mmr[MAMR2][0], ~pre_map_cs[1:0]
                };
    pre_map_cs[3]=&{addr[23]   ^mmr[MSAR3][7],
                   (addr[22:16]^mmr[MSAR3][6:0])|mmr[MAMR3][7:1],
                    addr[15] | mmr[MAMR3][0], ~pre_map_cs[2:0]
                };
end
/*
if( int0  & mmr[INTE0AD][3] )
if( intad & mmr[INTE0AD][7] )
if( int4  & mmr[INTE45 ][3] )
if( int5  & mmr[INTE45 ][7] )
if( int6  & mmr[INTE67 ][3] )
if( int7  & mmr[INTE67 ][7] )
if( intt0 & mmr[INTET01][3] )
if( intt1 & mmr[INTET01][7] )
if( intt2 & mmr[INTET23][3] )
if( intt3 & mmr[INTET23][7] )
if( inttr4& mmr[INTET45][3] )
if( inttr5& mmr[INTET45][7] )
if( inttr6& mmr[INTET67][3] )
if( inttr7& mmr[INTET67][7] )
if( intrx0& mmr[INTES0 ][3] )
if( inttx0& mmr[INTES0 ][7] )
if( intrx1& mmr[INTES1 ][3] )
if( inttx1& mmr[INTES1 ][7] )
if( inttc0& mmr[INTTC01][3] )
if( inttc1& mmr[INTTC01][7] )
if( inttc2& mmr[INTTC23][3] )
if( inttc3& mmr[INTTC23][7] )
    */

`ifdef SIMULATION
    wire [2:0] inttc3_lvl =  mmr[INTTC23][6:4];
    wire [2:0] inttc2_lvl =  mmr[INTTC23][2:0];
    wire [2:0] inttc1_lvl =  mmr[INTTC01][6:4];
    wire [2:0] inttc0_lvl =  mmr[INTTC01][2:0];
    wire [2:0] inte0ad_lvl =  mmr[INTE0AD][6:4];
    wire [2:0] intetx1_lvl  =  mmr[INTES1 ][6:4];
    wire [2:0] interx1_lvl  =  mmr[INTES1 ][2:0];
    wire [2:0] intetx0_lvl  =  mmr[INTES0 ][6:4];
    wire [2:0] interx0_lvl  =  mmr[INTES0 ][2:0];
    wire [2:0] intet7_lvl =  mmr[INTET67][6:4];
    wire [2:0] intet6_lvl =  mmr[INTET67][2:0];
    wire [2:0] intet5_lvl =  mmr[INTET45][6:4];
    wire [2:0] intet4_lvl =  mmr[INTET45][2:0];
    wire [2:0] intet3_lvl =  mmr[INTET23][6:4];
    wire [2:0] intet2_lvl =  mmr[INTET23][2:0];
    wire [2:0] intet1_lvl =  mmr[INTET01][6:4];
    wire [2:0] intet0_lvl =  mmr[INTET01][2:0];
    wire [2:0] inte7_lvl  =  mmr[INTE67 ][6:4];
    wire [2:0] inte6_lvl  =  mmr[INTE67 ][2:0];
    wire [2:0] inte5_lvl  =  mmr[INTE45 ][6:4];
    wire [2:0] inte4_lvl  =  mmr[INTE45 ][2:0];
    wire [2:0] inte0_lvl  =  mmr[INTE0AD][2:0];
    wire int3_ff   = mmr[INTTC23][7];
    wire int2_ff   = mmr[INTTC23][3];
    wire inttc1_ff = mmr[INTTC01][7];
    wire inttc0_ff = mmr[INTTC01][3];
    wire intad_ff  = mmr[INTE0AD][7];
    wire inttx1_ff = mmr[INTES1 ][7];
    wire intrx1_ff = mmr[INTES1 ][3];
    wire inttx0_ff = mmr[INTES0 ][7];
    wire intrx0_ff = mmr[INTES0 ][3];
    wire intt7_ff  = mmr[INTET67][7];
    wire intt6_ff  = mmr[INTET67][3];
    wire intt5_ff  = mmr[INTET45][7];
    wire intt4_ff  = mmr[INTET45][3];
    wire intt3_ff  = mmr[INTET23][7];
    wire intt2_ff  = mmr[INTET23][3];
    wire intt1_ff  = mmr[INTET01][7];
    wire intt0_ff  = mmr[INTET01][3];
    wire int7_ff   = mmr[INTE67 ][7];
    wire int6_ff   = mmr[INTE67 ][3];
    wire int5_ff   = mmr[INTE45 ][7];
    wire int4_ff   = mmr[INTE45 ][3];
    wire int0_ff   = mmr[INTE0AD][3];
    reg [21:0] act_l;
    always @(posedge clk) begin
        act_l <= act;
        if( act != act_l ) $display("Interrupts changed to %h",act);
    end
`endif

wire nmi_rq, nmi_clr;

assign nmi_clr = irq_ack && nmi_rq && ilvl==7;

jtframe_ff u_nmi_ff (
    .rst    (rst    ),
    .clk    (clk    ),
    .cen    (1'b1   ),
    .din    (1'b1   ), // TODO: Check connection ! Signal/port not matching : Expecting logic [0:0]  -- Found logic [15:0]
    .q      (nmi_rq ),
    .qn     (       ),
    .set    ( 1'b0  ),
    .clr    (nmi_clr),
    .sigedge(nmi    )
);

always @* begin // TMP95C061.pdf pages 12, 19
    nx_ilvl  = ilvl;
    nx_iaddr = iaddr;
    nx_act   = act;
    // If all are set to the same level, priority is given by the vector
    // address: smaller addresses are served first
    if( mmr[INTTC23][7] && mmr[INTTC23][6:4]>nx_ilvl ) { nx_act[00], nx_iaddr, nx_ilvl } = { 1'b1, 8'h80, mmr[INTTC23][6:4] }; else
    if( mmr[INTTC23][3] && mmr[INTTC23][2:0]>nx_ilvl ) { nx_act[01], nx_iaddr, nx_ilvl } = { 1'b1, 8'h7C, mmr[INTTC23][2:0] }; else
    if( mmr[INTTC01][7] && mmr[INTTC01][6:4]>nx_ilvl ) { nx_act[02], nx_iaddr, nx_ilvl } = { 1'b1, 8'h78, mmr[INTTC01][6:4] }; else
    if( mmr[INTTC01][3] && mmr[INTTC01][2:0]>nx_ilvl ) { nx_act[03], nx_iaddr, nx_ilvl } = { 1'b1, 8'h74, mmr[INTTC01][2:0] }; else
    if( mmr[INTE0AD][7] && mmr[INTE0AD][6:4]>nx_ilvl ) { nx_act[04], nx_iaddr, nx_ilvl } = { 1'b1, 8'h70, mmr[INTE0AD][6:4] }; else
    if( mmr[INTES1 ][7] && mmr[INTES1 ][6:4]>nx_ilvl ) { nx_act[05], nx_iaddr, nx_ilvl } = { 1'b1, 8'h6C, mmr[INTES1 ][6:4] }; else
    if( mmr[INTES1 ][3] && mmr[INTES1 ][2:0]>nx_ilvl ) { nx_act[06], nx_iaddr, nx_ilvl } = { 1'b1, 8'h68, mmr[INTES1 ][2:0] }; else
    if( mmr[INTES0 ][7] && mmr[INTES0 ][6:4]>nx_ilvl ) { nx_act[07], nx_iaddr, nx_ilvl } = { 1'b1, 8'h64, mmr[INTES0 ][6:4] }; else
    if( mmr[INTES0 ][3] && mmr[INTES0 ][2:0]>nx_ilvl ) { nx_act[08], nx_iaddr, nx_ilvl } = { 1'b1, 8'h60, mmr[INTES0 ][2:0] }; else
    if( mmr[INTET67][7] && mmr[INTET67][6:4]>nx_ilvl ) { nx_act[09], nx_iaddr, nx_ilvl } = { 1'b1, 8'h5C, mmr[INTET67][6:4] }; else
    if( mmr[INTET67][3] && mmr[INTET67][2:0]>nx_ilvl ) { nx_act[10], nx_iaddr, nx_ilvl } = { 1'b1, 8'h58, mmr[INTET67][2:0] }; else
    if( mmr[INTET45][7] && mmr[INTET45][6:4]>nx_ilvl ) { nx_act[11], nx_iaddr, nx_ilvl } = { 1'b1, 8'h54, mmr[INTET45][6:4] }; else
    if( mmr[INTET45][3] && mmr[INTET45][2:0]>nx_ilvl ) { nx_act[12], nx_iaddr, nx_ilvl } = { 1'b1, 8'h50, mmr[INTET45][2:0] }; else
    if( mmr[INTET23][7] && mmr[INTET23][6:4]>nx_ilvl ) { nx_act[13], nx_iaddr, nx_ilvl } = { 1'b1, 8'h4C, mmr[INTET23][6:4] }; else
    if( mmr[INTET23][3] && mmr[INTET23][2:0]>nx_ilvl ) { nx_act[14], nx_iaddr, nx_ilvl } = { 1'b1, 8'h48, mmr[INTET23][2:0] }; else
    if( mmr[INTET01][7] && mmr[INTET01][6:4]>nx_ilvl ) { nx_act[15], nx_iaddr, nx_ilvl } = { 1'b1, 8'h44, mmr[INTET01][6:4] }; else
    if( mmr[INTET01][3] && mmr[INTET01][2:0]>nx_ilvl ) { nx_act[16], nx_iaddr, nx_ilvl } = { 1'b1, 8'h40, mmr[INTET01][2:0] }; else
    if( mmr[INTE67 ][7] && mmr[INTE67 ][6:4]>nx_ilvl ) { nx_act[17], nx_iaddr, nx_ilvl } = { 1'b1, 8'h38, mmr[INTE67 ][6:4] }; else
    if( mmr[INTE67 ][3] && mmr[INTE67 ][2:0]>nx_ilvl ) { nx_act[18], nx_iaddr, nx_ilvl } = { 1'b1, 8'h34, mmr[INTE67 ][2:0] }; else
    if( mmr[INTE45 ][7] && mmr[INTE45 ][6:4]>nx_ilvl ) { nx_act[19], nx_iaddr, nx_ilvl } = { 1'b1, 8'h30, mmr[INTE45 ][6:4] }; else
    if( mmr[INTE45 ][3] && mmr[INTE45 ][2:0]>nx_ilvl ) { nx_act[20], nx_iaddr, nx_ilvl } = { 1'b1, 8'h2c, mmr[INTE45 ][2:0] }; else
    if( mmr[INTE0AD][3] && mmr[INTE0AD][2:0]>nx_ilvl ) { nx_act[21], nx_iaddr, nx_ilvl } = { 1'b1, 8'h28, mmr[INTE0AD][2:0] };
    // NMI
    if( nmi_rq ) begin
        nx_ilvl = 7;
        nx_act  = 0;
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ilvl  <= 0;
        iaddr <= 0;
        act   <= 0;
        irq   <= 0;
    end else begin
        ilvl  <= nx_ilvl;
        iaddr <= nx_iaddr;
        act   <= nx_act;
        irq   <= |{ nx_act, nmi_rq };
    end
end

always @(posedge clk) begin
    map_cs <= pre_map_cs;
end

integer k;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        for( k=0; k<64; k=k+1 ) mmr[k] <= 0;
        // Fake ADC
        mmr[ADREG0H] <=8'hff;   // channel 0 is the battery, we give it a high reading
        mmr[ADREG0L] <=8'hff;
        adc_go <= 0;
        adc_cnt <= 0;
    end else begin
        if( port_cs ) begin
            if( addr[6:0]==ADMOD ) begin
                if( we[0] ) begin
                    mmr[ ADMOD ][5:0] <= { dout[5:3], 1'b0, dout[1:0] };
                    if( dout[2] ) begin
                        $display("ADC conversion requested");
                        adc_go <= 1;
                        mmr[ADMOD][7:6] <= 0;
                    end
                end
            end else if( addr[6:0]<7'h70 || addr[6:0]>7'h7a ) begin
                if( we[0] ) begin mmr[ {addr[6:1],1'b0} ] <= dout[ 7:0]; /*$display("MMR[%X]=%X",{addr[6:1],1'b0}, dout[ 7:0] );*/ end
                if( we[1] ) begin mmr[ {addr[6:1],1'b1} ] <= dout[15:8]; /*$display("MMR[%X]=%X",{addr[6:1],1'b1}, dout[16:8] );*/ end
            end else begin // interrupt control
                if( we[0] ) begin { mmr[ {addr[6:1],1'b0} ][6:4], mmr[ {addr[6:1],1'b0} ][2:0] } <= { dout[ 6:4], dout[ 2:0]}; $display("MMR[%X]=%X",{addr[6:1],1'b0}, dout[ 7:0] ); end
                if( we[1] ) begin { mmr[ {addr[6:1],1'b1} ][6:4], mmr[ {addr[6:1],1'b1} ][2:0] } <= { dout[14:12],dout[10:8]}; $display("MMR[%X]=%X",{addr[6:1],1'b1}, dout[15:8] ); end
                // clear the interrupt flip flop
                if( we[0] && !dout[ 3] ) mmr[ {addr[6:1],1'b0} ][3] <= 0;
                if( we[0] && !dout[ 7] ) mmr[ {addr[6:1],1'b0} ][7] <= 0;
                if( we[1] && !dout[11] ) mmr[ {addr[6:1],1'b1} ][3] <= 0;
                if( we[1] && !dout[15] ) mmr[ {addr[6:1],1'b1} ][7] <= 0;
            end
        end
        // interrupt flip flop
        if( irq_ack && act[00] ) mmr[INTTC23][7] <= 0;
        if( irq_ack && act[01] ) mmr[INTTC23][3] <= 0;
        if( irq_ack && act[02] ) mmr[INTTC01][7] <= 0;
        if( irq_ack && act[03] ) mmr[INTTC01][3] <= 0;
        if( irq_ack && act[04] ) mmr[INTE0AD][7] <= 0;
        if( irq_ack && act[05] ) mmr[INTES1 ][7] <= 0;
        if( irq_ack && act[06] ) mmr[INTES1 ][3] <= 0;
        if( irq_ack && act[07] ) mmr[INTES0 ][7] <= 0;
        if( irq_ack && act[08] ) mmr[INTES0 ][3] <= 0;
        if( irq_ack && act[09] ) mmr[INTET67][7] <= 0;
        if( irq_ack && act[10] ) mmr[INTET67][3] <= 0;
        if( irq_ack && act[11] ) mmr[INTET45][7] <= 0;
        if( irq_ack && act[12] ) mmr[INTET45][3] <= 0;
        if( irq_ack && act[13] ) mmr[INTET23][7] <= 0;
        if( irq_ack && act[14] ) mmr[INTET23][3] <= 0;
        if( irq_ack && act[15] ) mmr[INTET01][7] <= 0;
        if( irq_ack && act[16] ) mmr[INTET01][3] <= 0;
        if( irq_ack && act[17] ) mmr[INTE67 ][7] <= 0;
        if( irq_ack && act[18] ) mmr[INTE67 ][3] <= 0;
        if( irq_ack && act[19] ) mmr[INTE45 ][7] <= 0;
        if( irq_ack && act[20] ) mmr[INTE45 ][3] <= 0;
        if( irq_ack && act[21] ) mmr[INTE0AD][3] <= 0;
        // interrupt set
        if( int4 ) mmr[INTE45][3] <= 1;
        // ADC
        if( adc_go &&  !adc_bsy ) begin
            adc_go <= 0;
            mmr[ADMOD][ADC_END] <= 0;
            mmr[ADMOD][ADC_BSY] <= 1;
            adc_cnt <= 11'd1228 >> ~mmr[ADMOD][3]; // 12.8us for high speed, 25.6us for low
        end
        if( adc_bsy && !adc_end ) begin // count for 48MHz clock
            { mmr[ADMOD][ADC_END], adc_cnt } <= {1'd0, adc_cnt} - 1'd1;
        end
        if( adc_end && adc_bsy ) begin
            mmr[INTE0AD][ADC_BSY] <= 0;
            mmr[INTE0AD][7] <= 1; // set interrupt flag
        end
    end
end

jt900h #(.PC_RSTVAL(32'hFF1800)) u_cpu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),

    .addr       ( addr      ),
    .din        ( din       ),
    .dout       ( dout      ),
    .we         ( we        ),

    // interrupts
    .irq        ( irq       ),
    .intrq      ( ilvl      ),
    .irq_ack    ( irq_ack   ),
    .inta_en    ( irq       ),
    .int_addr   ( iaddr     ),
    // Register dump
    .dmp_addr   (           ),     // dump
    .dmp_dout   (           )
);


endmodule

