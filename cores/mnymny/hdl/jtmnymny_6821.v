/*  jtmnymny_6821.v — minimal MC6821 PIA
    Covers the features used on the 1B11142 board: DDR/OR per port,
    CA1/CB1 edge interrupts, CA2/CB2 as plain outputs (modes 110/111)
    or input with edge flag. GPL3 — see jtcores LICENSE
*/

module jtmnymny_6821(
    input            rst,
    input            clk,
    input            cen,          // E clock
    input            cs,
    input      [1:0] rs,
    input            rnw,
    input      [7:0] din,
    output reg [7:0] dout,
    input      [7:0] pa_in,
    output     [7:0] pa_out,
    output     [7:0] pa_oe,
    input      [7:0] pb_in,
    output     [7:0] pb_out,
    output     [7:0] pb_oe,
    input            ca1,
    input            ca2_in,
    output           ca2_out,
    input            cb1,
    input            cb2_in,
    output           cb2_out,
    output           irqa_n,
    output           irqb_n
);

reg [7:0] ora, orb, ddra, ddrb;
reg [5:0] cra, crb;          // control bits 5..0
reg       irqa1, irqa2, irqb1, irqb2;
reg       ca1_l, cb1_l, ca2_l, cb2_l, ca2r, cb2r;

assign pa_out  = ora;
assign pa_oe   = ddra;
assign pb_out  = orb;
assign pb_oe   = ddrb;
assign ca2_out = cra[5] ? (cra[4] ? cra[3] : ca2r) : 1'b1;
assign cb2_out = crb[5] ? (crb[4] ? crb[3] : cb2r) : 1'b1;
assign irqa_n  = ~( (irqa1 & cra[0]) | (irqa2 & ~cra[5] & cra[3]) );
assign irqb_n  = ~( (irqb1 & crb[0]) | (irqb2 & ~crb[5] & crb[3]) );

wire [7:0] pa_mix = (pa_in & ~ddra) | (ora & ddra);
wire [7:0] pb_mix = (pb_in & ~ddrb) | (orb & ddrb);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        { ora, orb, ddra, ddrb } <= 0;
        { cra, crb } <= 0;
        { irqa1, irqa2, irqb1, irqb2 } <= 0;
        { ca1_l, cb1_l, ca2_l, cb2_l, ca2r, cb2r } <= 0;
    end else begin
        ca1_l <= ca1;
        cb1_l <= cb1;
        ca2_l <= ca2_in;
        cb2_l <= cb2_in;
        if( ca1 != ca1_l && ca1 == cra[1] ) irqa1 <= 1;
        if( cb1 != cb1_l && cb1 == crb[1] ) irqb1 <= 1;
        if( !cra[5] && ca2_in != ca2_l && ca2_in == cra[4] ) irqa2 <= 1;
        if( !crb[5] && cb2_in != cb2_l && cb2_in == crb[4] ) irqb2 <= 1;
        // writes follow the bus (multi-clock cycles), read side effects only
        // when the CPU actually completes the read (cen)
        if( cs && !rnw ) case( rs )
            2'd0: if( cra[2] ) ora  <= din; else ddra <= din;
            2'd1: cra <= din[5:0];
            2'd2: if( crb[2] ) orb  <= din; else ddrb <= din;
            2'd3: crb <= din[5:0];
        endcase
        if( cen && cs && rnw ) case( rs )
            2'd0: if( cra[2] ) { irqa1, irqa2 } <= 0;
            2'd2: if( crb[2] ) { irqb1, irqb2 } <= 0;
            default:;
        endcase
    end
end

always @* begin
    case( rs )
        2'd0: dout = cra[2] ? pa_mix : ddra;
        2'd1: dout = { irqa1, irqa2, cra };
        2'd2: dout = crb[2] ? pb_mix : ddrb;
        2'd3: dout = { irqb1, irqb2, crb };
    endcase
end

endmodule
