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

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 19-9-2026
*/

// M37702 on-chip peripherals: I/O ports, timers A0-A4/B0-B2, 8-bit ADC,
// interrupt controller. Register file at 00-7F, byte access only
// (the bus unit splits word accesses). UART and watchdog are stubs

module jt37702_per(
    input             rst,
    input             clk,
    input             cen,
    input             tcen,     // XIN time base for timers and ADC, subset of cen
    // register bus, one byte per access
    input      [ 6:0] pa,
    input             psel,     // qualified with cen by the bus unit
    input             pwr,
    input      [ 7:0] pdin,
    output reg [ 7:0] pdout,
    // I/O ports 4-8 (0-3 not bonded on the C75)
    input      [ 7:0] p4_din, p5_din, p6_din, p7_din, p8_din,
    output     [ 7:0] p4_dout, p5_dout, p6_dout, p7_dout, p8_dout,
    output     [ 7:0] p4_diro, p5_diro, p6_diro, p7_diro, p8_diro,
    // ADC inputs, 8 bits per channel
    input      [63:0] an,
    // external interrupt pins, rising edge
    input             irq0, irq1, irq2,
    // timer A external event inputs
    input      [ 4:0] tain,
    // CPU interrupt interface
    output reg        irq_rq,
    output reg [ 2:0] irq_lvl,
    output reg [ 4:0] irq_ix,
    input             irq_ack,
    input      [ 4:0] irq_ackix
);

integer i;

// I/O ports
reg  [7:0] pdat[0:8], pdir[0:8];
wire [7:0] pin_mx[0:8];

assign pin_mx[0] = 8'd0;
assign pin_mx[1] = 8'd0;
assign pin_mx[2] = 8'd0;
assign pin_mx[3] = 8'd0;
assign pin_mx[4] = p4_din;
assign pin_mx[5] = p5_din;
assign pin_mx[6] = p6_din;
assign pin_mx[7] = p7_din;
assign pin_mx[8] = p8_din;
assign p4_dout = pdat[4]; assign p4_diro = pdir[4];
assign p5_dout = pdat[5]; assign p5_diro = pdir[5];
assign p6_dout = pdat[6]; assign p6_diro = pdir[6];
assign p7_dout = pdat[7]; assign p7_diro = pdir[7];
assign p8_dout = pdat[8]; assign p8_diro = pdir[8];

// port address helper: valid for pa in 02-15
wire [4:0] pk    = pa[4:0]-5'd2;
wire [3:0] pnum  = {pk[4:2],1'b0}+{3'd0,pk[0]};
wire       pisdir= pk[1];
wire       psel_port = pa>=7'h02 && pa<=7'h15 && pnum<=4'd8;

// ADC
reg  [ 7:0] ad_ctl, ad_sweep, ad_res[0:7];
reg  [ 8:0] ad_cnt;
wire [ 2:0] ad_ch  = ad_ctl[2:0];
wire [ 7:0] ad_in  = an[{ad_ch,3'd0} +: 8];
wire [ 2:0] ad_lim = {ad_sweep[1:0],1'b1}; // sweep end channel

// timers
reg  [15:0] treload[0:7], tcnt[0:7];
reg  [ 7:0] tmode[0:7];
reg  [ 8:0] tpre[0:7];
reg  [ 7:0] count_start, os_start, up_down;
wire [ 4:0] taev; // timer A event pulses

// UART / watchdog / processor mode stubs
reg  [ 7:0] ustub[0:15];
reg  [ 7:0] proc_mode, wdog_freq;

// interrupt controller. MAME line order: 4=ADC, 9..11=TB2..TB0,
// 12..16=TA4..TA0, 17=INT2, 18=INT1, 19=INT0. bit3 = request
reg  [ 7:0] intc[0:19];
wire [ 4:0] intix[0:15];
wire        irqp [0:2];

assign intix[ 0]=5'd4;  assign intix[ 1]=5'd7;  assign intix[ 2]=5'd8;
assign intix[ 3]=5'd5;  assign intix[ 4]=5'd6;  assign intix[ 5]=5'd16;
assign intix[ 6]=5'd15; assign intix[ 7]=5'd14; assign intix[ 8]=5'd13;
assign intix[ 9]=5'd12; assign intix[10]=5'd11; assign intix[11]=5'd10;
assign intix[12]=5'd9;  assign intix[13]=5'd19; assign intix[14]=5'd18;
assign intix[15]=5'd17;
wire [4:0] icix = intix[pa[3:0]]; // pa 70-7f

jtframe_edge_pulse u_irq0(.rst(rst),.clk(clk),.cen(cen),.sigin(irq0),.pulse(irqp[0]));
jtframe_edge_pulse u_irq1(.rst(rst),.clk(clk),.cen(cen),.sigin(irq1),.pulse(irqp[1]));
jtframe_edge_pulse u_irq2(.rst(rst),.clk(clk),.cen(cen),.sigin(irq2),.pulse(irqp[2]));

generate
    genvar g;
    for( g=0; g<5; g=g+1 ) begin : taedge
        jtframe_edge_pulse u_ta(.rst(rst),.clk(clk),.cen(cen),
            .sigin(tain[g]),.pulse(taev[g]));
    end
endgenerate

// timer index for reload registers 46-55: (pa-0x46)/2
wire [6:0] tixw = pa-7'h46;
wire [2:0] tix  = tixw[3:1];
// prescaler limit per mode bits 7:6
function [8:0] tscale(input [1:0] sel);
    case( sel )
        2'd0: tscale = 9'd1;    // f2/2
        2'd1: tscale = 9'd15;   // f2/16
        2'd2: tscale = 9'd63;   // f2/64
        default: tscale = 9'd511;
    endcase
endfunction

// register read
always @* begin
    pdout = 0;
    if( psel_port )
        pdout = pisdir ? pdir[pnum[3:0]] :
                (pin_mx[pnum[3:0]] & ~pdir[pnum[3:0]]) |
                (pdat  [pnum[3:0]] &  pdir[pnum[3:0]]);
    else casez( pa )
        7'h1e: pdout = ad_ctl;
        7'h1f: pdout = ad_sweep;
        7'b010_????: pdout = pa[0] ? 8'd0 : ad_res[pa[3:1]]; // 20-2f
        7'b011_????: pdout = ustub[pa[3:0]];                 // 30-3f UART
        7'h40: pdout = count_start;
        7'h42: pdout = os_start;
        7'h44: pdout = up_down;
        7'h46,7'h47,7'h48,7'h49,7'h4a,7'h4b,7'h4c,7'h4d,
        7'h4e,7'h4f,7'h50,7'h51,7'h52,7'h53,7'h54,7'h55:
            pdout = pa[0] ? tcnt[tix][15:8] : tcnt[tix][7:0];
        7'h56,7'h57,7'h58,7'h59,7'h5a,7'h5b,7'h5c,7'h5d:
            pdout = tmode[pa[2:0]-3'd6];
        7'h5e: pdout = proc_mode;
        7'h61: pdout = wdog_freq;
        7'b111_????: pdout = intc[icix];                     // 70-7f
        default: pdout = 0;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        for(i=0;i<9;i=i+1) begin pdat[i]<=0; pdir[i]<=0; end
        for(i=0;i<8;i=i+1) begin
            treload[i]<=0; tcnt[i]<=0; tmode[i]<=0; tpre[i]<=0;
            ad_res[i]<=0;
        end
        for(i=0;i<16;i=i+1) ustub[i]<=0;
        for(i=0;i<20;i=i+1) intc[i]<=0;
        ad_ctl<=0; ad_sweep<=8'h03; ad_cnt<=0;
        count_start<=0; os_start<=0; up_down<=0;
        proc_mode<=0; wdog_freq<=0;
    end else if( cen ) begin
        // interrupt acknowledge from the CPU clears the request flag
        if( irq_ack ) intc[irq_ackix][3] <= 0;
        // external interrupt pins
        if( irqp[0] ) intc[19][3] <= 1;
        if( irqp[1] ) intc[18][3] <= 1;
        if( irqp[2] ) intc[17][3] <= 1;
        // timers
        for(i=0;i<8;i=i+1) if( count_start[i] && tcen ) begin
            if( tmode[i][1:0]==2'b00 ) begin // timer mode
                if( tpre[i]==tscale(tmode[i][7:6]) ) begin
                    tpre[i] <= 0;
                    if( tcnt[i]==0 ) begin
                        tcnt[i] <= treload[i];
                        intc[16-i][3] <= 1; // A0..A4=16..12, B0..B2=11..9
                    end else begin
                        tcnt[i] <= tcnt[i]-16'd1;
                    end
                end else begin
                    tpre[i] <= tpre[i]+9'd1;
                end
            end
        end
        // timer A event counter mode
        for(i=0;i<5;i=i+1)
            if( count_start[i] && tmode[i][1:0]==2'b01 && taev[i] ) begin
                if( up_down[i] ) begin // count up, reload+irq on overflow
                    if( tcnt[i]==16'hffff ) begin
                        tcnt[i] <= treload[i];
                        intc[16-i][3] <= 1;
                    end else tcnt[i] <= tcnt[i]+16'd1;
                end else begin
                    if( tcnt[i]==0 ) begin
                        tcnt[i] <= treload[i];
                        intc[16-i][3] <= 1;
                    end else tcnt[i] <= tcnt[i]-16'd1;
                end
            end
        // ADC conversion
        if( ad_ctl[6] && tcen ) begin
            if( ad_cnt==0 ) begin
                ad_res[ad_ch] <= ad_in;
                if( ad_ctl[3] || (ad_ctl[4] && ad_ch!=ad_lim) ) begin
                    // repeat or sweep continues, no interrupt
                    if( ad_ctl[4] ) ad_ctl[2:0] <= ad_ch+3'd1;
                    ad_cnt <= ad_ctl[7] ? 9'd228 : 9'd456;
                end else begin
                    intc[4][3] <= 1;
                    ad_ctl[6]  <= 0;
                end
            end else ad_cnt <= ad_cnt-9'd1;
        end
        // register writes
        if( psel && pwr ) begin
            if( psel_port ) begin
                if( pisdir ) pdir[pnum[3:0]] <= pdin;
                else         pdat[pnum[3:0]] <= pdin;
            end else casez( pa )
                7'h1e: begin
                    ad_ctl <= pdin;
                    if( pdin[6] && !ad_ctl[6] ) begin
                        ad_cnt <= pdin[7] ? 9'd228 : 9'd456;
                        if( pdin[4] ) ad_ctl <= {pdin[7:3],3'd0}; // sweep from ch0
                    end
                end
                7'h1f: ad_sweep <= pdin;
                7'b011_????: ustub[pa[3:0]] <= pdin;
                7'h40: begin
                    count_start <= pdin;
                    for(i=0;i<8;i=i+1) if( pdin[i] && !count_start[i] ) begin
                        tcnt[i] <= treload[i];
                        tpre[i] <= 0;
                    end
                end
                7'h42: os_start <= pdin;
                7'h44: up_down  <= pdin;
                7'h46,7'h47,7'h48,7'h49,7'h4a,7'h4b,7'h4c,7'h4d,
                7'h4e,7'h4f,7'h50,7'h51,7'h52,7'h53,7'h54,7'h55: begin
                    if( pa[0] ) treload[tix][15:8] <= pdin;
                    else        treload[tix][ 7:0] <= pdin;
                end
                7'h56,7'h57,7'h58,7'h59,7'h5a,7'h5b,7'h5c,7'h5d:
                    tmode[pa[2:0]-3'd6] <= pdin;
                7'h5e: proc_mode <= pdin;
                7'h60:; // watchdog restart, stub
                7'h61: wdog_freq <= pdin;
                7'b111_????: intc[icix] <= pdin;
                default:;
            endcase
        end
    end
end

`ifdef SYSFL_COINDBG
integer dbg_clk=0, dbg_n=0;
always @(posedge clk) begin
    dbg_clk <= dbg_clk+1;
    if( !rst && cen && dbg_n<400 ) begin
        if( psel && pwr && !psel_port && pa==7'h1e ) begin dbg_n<=dbg_n+1; $display("ADC ctl wr %h (was %h) f%0d", pdin, ad_ctl, dbg_clk/806400); end
        if( psel && pwr && !psel_port && pa==7'h70 ) begin dbg_n<=dbg_n+1; $display("ADC ic wr %h (was %h) f%0d", pdin, intc[4], dbg_clk/806400); end
        if( ad_ctl[6] && ad_cnt==0 && !(ad_ctl[3] || (ad_ctl[4] && ad_ch!=ad_lim)) ) begin dbg_n<=dbg_n+1; $display("ADC done f%0d", dbg_clk/806400); end
        if( irq_ack ) begin dbg_n<=dbg_n+1; $display("IRQ ack %0d f%0d", irq_ackix, dbg_clk/806400); end
    end
end
`endif

// priority resolver: highest level wins, ties favor the higher index
// (INT0 over timers), as in MAME m37710i_update_irqs
always @* begin
    irq_rq  = 0;
    irq_lvl = 0;
    irq_ix  = 0;
    for(i=0;i<20;i=i+1)
        if( intc[i][3] && intc[i][2:0]!=0 && intc[i][2:0]>=irq_lvl ) begin
            irq_rq  = 1;
            irq_lvl = intc[i][2:0];
            irq_ix  = i[4:0];
        end
end

endmodule
