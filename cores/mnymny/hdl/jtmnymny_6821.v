/*  jtmnymny_6821.v — MC6821 PIA
    Full control-word implementation from the Motorola datasheet (DS9435R5):
    DDR/OR per port, CA1/CB1/CA2/CB2 edge flags, CA2/CB2 output modes
    including read/write strobes with CA1/CB1 or E restore, port A pin
    readback vs port B latch readback, flag masking in output mode.
    Register writes follow the bus (6802 multi-clock cycles); read side
    effects and strobe events fire on cen only (E-qualified).
    EDIV = cen ticks per E cycle (strobe E-restore width).
    GPL3 — see jtcores LICENSE
*/

module jtmnymny_6821 #(parameter EDIV=4)(
    input            rst,
    input            clk,
    input            cen,          // EDIV x E clock
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
    output           ca2_oe,
    input            cb1,
    input            cb2_in,
    output           cb2_out,
    output           cb2_oe,
    output           irqa_n,
    output           irqb_n
);

reg [7:0] ora, orb, ddra, ddrb;
reg [5:0] cra, crb;          // control bits 5..0 (7:6 are the flags)
reg       irqa1, irqa2, irqb1, irqb2;
reg       ca1_l, cb1_l, ca2_l, cb2_l;
reg       ca2str, cb2str;    // strobe-mode output level
reg [2:0] ca2cnt, cb2cnt;    // E-restore countdown

// active transitions per control bits 1 (CA1/CB1) and 4 (CA2/CB2)
wire ca1_edge = ca1    != ca1_l && ca1    == cra[1];
wire cb1_edge = cb1    != cb1_l && cb1    == crb[1];
wire ca2_edge = ca2_in != ca2_l && ca2_in == cra[4];
wire cb2_edge = cb2_in != cb2_l && cb2_in == crb[4];

// E-qualified data register accesses (side-effect events)
wire rd_ora = cen && cs && rnw  && rs==2'd0 && cra[2];
wire rd_orb = cen && cs && rnw  && rs==2'd2 && crb[2];
wire wr_orb = cen && cs && !rnw && rs==2'd2 && crb[2];

assign pa_out  = ora;
assign pa_oe   = ddra;
assign pb_out  = orb;
assign pb_oe   = ddrb;
assign ca2_oe  = cra[5];
assign cb2_oe  = crb[5];
// b5=1,b4=1: set/reset (b3). b5=1,b4=0: strobe. b5=0: input (pin released)
assign ca2_out = !cra[5] ? 1'b1 : cra[4] ? cra[3] : ca2str;
assign cb2_out = !crb[5] ? 1'b1 : crb[4] ? crb[3] : cb2str;
assign irqa_n  = ~( (irqa1 & cra[0]) | (irqa2 & ~cra[5] & cra[3]) );
assign irqb_n  = ~( (irqb1 & crb[0]) | (irqb2 & ~crb[5] & crb[3]) );

// port A reads the pin (inputs have internal pullups: caller drives pa_in
// high for undriven lines); port B reads the output latch on output pins
wire [7:0] pa_mix = (pa_in & ~ddra) | (ora & ddra);
wire [7:0] pb_mix = (pb_in & ~ddrb) | (orb & ddrb);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        { ora, orb, ddra, ddrb } <= 0;
        { cra, crb } <= 0;
        { irqa1, irqa2, irqb1, irqb2 } <= 0;
        { ca1_l, cb1_l, ca2_l, cb2_l } <= 0;
        { ca2str, cb2str } <= 2'b11;
        { ca2cnt, cb2cnt } <= 0;
    end else begin
        ca1_l <= ca1;
        cb1_l <= cb1;
        ca2_l <= ca2_in;
        cb2_l <= cb2_in;
        // interrupt flags: set on active edges (CA2/CB2 only as inputs),
        // cleared by an E-qualified read of the data register
        if( ca1_edge ) irqa1 <= 1;
        if( cb1_edge ) irqb1 <= 1;
        if( !cra[5] && ca2_edge ) irqa2 <= 1;
        if( !crb[5] && cb2_edge ) irqb2 <= 1;
        if( rd_ora ) { irqa1, irqa2 } <= 0;
        if( rd_orb ) { irqb1, irqb2 } <= 0;
        // register writes follow the bus (multi-clock 6802 cycles)
        if( cs && !rnw ) case( rs )
            2'd0: if( cra[2] ) ora  <= din; else ddra <= din;
            2'd1: cra <= din[5:0];
            2'd2: if( crb[2] ) orb  <= din; else ddrb <= din;
            2'd3: crb <= din[5:0];
        endcase
        // CA2 strobe (b5=1, b4=0): low after ORA read; restore by CA1
        // active edge (b3=0) or after one E (b3=1)
        if( rd_ora && cra[5] && !cra[4] ) begin
            ca2str <= 0;
            ca2cnt <= EDIV[2:0];
        end else if( cra[3] ) begin
            if( cen && ca2cnt!=0 ) begin
                ca2cnt <= ca2cnt-3'd1;
                if( ca2cnt==3'd1 ) ca2str <= 1;
            end
        end else if( ca1_edge ) ca2str <= 1;
        // CB2 strobe: low after ORB write; restore by CB1 edge or one E
        if( wr_orb && crb[5] && !crb[4] ) begin
            cb2str <= 0;
            cb2cnt <= EDIV[2:0];
        end else if( crb[3] ) begin
            if( cen && cb2cnt!=0 ) begin
                cb2cnt <= cb2cnt-3'd1;
                if( cb2cnt==3'd1 ) cb2str <= 1;
            end
        end else if( cb1_edge ) cb2str <= 1;
    end
end

// flag bits 7:6; bit 6 reads 0 while CA2/CB2 is an output
always @* begin
    case( rs )
        2'd0: dout = cra[2] ? pa_mix : ddra;
        2'd1: dout = { irqa1, irqa2 & ~cra[5], cra };
        2'd2: dout = crb[2] ? pb_mix : ddrb;
        2'd3: dout = { irqb1, irqb2 & ~crb[5], crb };
    endcase
end

endmodule
