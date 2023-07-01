module jt7400( // ref: 74??00
    input       in1,  // pin: 1
    input       in2,  // pin: 2
    output      out3, // pin: 3
    input       in4,  // pin: 4
    input       in5,  // pin: 5
    output      out6, // pin: 6
    input       in9,  // pin: 9
    input       in10, // pin: 10
    output      out8, // pin: 8
    input       in12, // pin: 12
    input       in13, // pin: 13
    output      out11, // pin: 11
    input       VDD,   // pin: 14
    input       VSS    // pin: 7
    );

assign #10 out3  = ~(in1 &in2 );
assign #10 out6  = ~(in4 &in5 );
assign #10 out8  = ~(in10&in9 );
assign #10 out11 = ~(in12&in13);

endmodule

module jt7402( // ref: 74??02
    output      out1, // pin: 1
    input       in2,  // pin: 2
    input       in3,  // pin: 3
    output      out4, // pin: 4
    input       in5,  // pin: 5
    input       in6,  // pin: 6
    input       in9,  // pin: 9
    input       in8,  // pin: 10
    output      out10,// pin: 8
    input       in12, // pin: 12
    input       in11, // pin: 13
    output      out13, // pin: 11
    input       VDD,   // pin: 14
    input       VSS    // pin: 7
    );

assign #10 out1 = ~( in2| in3 );
assign #10 out4 = ~( in5| in6 );
assign #10 out10= ~( in9| in8 );
assign #10 out13= ~(in12| in11);

endmodule

module jt7404( // ref: 74??04
    input       in1,   // pin: 1
    output      out2,  // pin: 2
    input       in3,   // pin: 3
    output      out4,  // pin: 4
    input       in5,   // pin: 5
    output      out6,  // pin: 6
    input       in9,   // pin: 9
    output      out8,  // pin: 8
    input       in11,  // pin: 11
    output      out10, // pin: 10
    input       in13,  // pin: 13
    output      out12, // pin: 12
    input       VDD,   // pin: 14
    input       VSS    // pin: 7
    );

assign #10 out2  = ~in1;
assign #10 out4  = ~in3;
assign #10 out6  = ~in5;
assign #10 out8  = ~in9;
assign #10 out10 = ~in11;
assign #10 out12 = ~in13;

endmodule

//////// Quad and gate
module jt7408( // ref: 74??08
    input       in1,  // pin: 1
    input       in2,  // pin: 2
    output      out3, // pin: 3
    input       in4,  // pin: 4
    input       in5,  // pin: 5
    output      out6, // pin: 6
    input       in9,  // pin: 9
    input       in10, // pin: 10
    output      out8, // pin: 8
    input       in12, // pin: 12
    input       in13, // pin: 13
    output      out11, // pin: 11
    input       VDD,   // pin: 14
    input       VSS    // pin: 7
    );

assign #10 out3  = in1 &in2;
assign #10 out6  = in4 &in5;
assign #10 out8  = in10&in9;
assign #10 out11 = in12&in13;

endmodule

/////////////////////////////////////
// triple 3-input positive-nand gates
module jt7410( // ref: 74??10
    input   [2:0] A,    // pin: 1,2,13
    input   [2:0] B,    // pin: 3,4,5
    input   [2:0] C,    // pin: 11,10,9
    output       Ya,    // pin: 12
    output       Yb,    // pin: 6
    output       Yc     // pin: 8
);

assign #15 Ya = ~&A;
assign #15 Yb = ~&B;
assign #15 Yc = ~&C;

endmodule

//////// trip 3-input and gate
module jt7411( // ref: 74??11
    input       in1,  // pin: 1
    input       in2,  // pin: 2
    input       in13, // pin: 13
    output      out12,// pin: 12

    input       in3,  // pin: 3
    input       in4,  // pin: 4
    input       in5,  // pin: 5
    output      out6, // pin: 6

    input       in11, // pin: 11
    input       in10, // pin: 10
    input       in9,  // pin: 9
    output      out8, // pin: 8

    input       VDD,   // pin: 14
    input       VSS    // pin: 7
    );

assign #10 out12 = in1 & in2 & in13;
assign #10 out6  = in3 & in4 & in5;
assign #10 out8  = in11& in10& in9;

endmodule

///////////////////////////////////
/////// 8-INPUT POSITIVE-NAND GATES
module jt7430( // ref: 74??30
    input [7:0] in, // pin: 1,2,3,4,5,6,11,12
    output Y        // pin: 8
);

assign #(15,20) Y = ~&in;

endmodule

/////////////////////
//////// Quad or gate
module jt7432( // ref: 74??32
    input       in1,  // pin: 1
    input       in2,  // pin: 2
    output      out3, // pin: 3
    input       in4,  // pin: 4
    input       in5,  // pin: 5
    output      out6, // pin: 6
    input       in9,  // pin: 9
    input       in10, // pin: 10
    output      out8, // pin: 8
    input       in12, // pin: 12
    input       in13, // pin: 13
    output      out11, // pin: 11
    input       VDD,   // pin: 14
    input       VSS    // pin: 7
    );

assign #10 out3  = in1 |in2;
assign #10 out6  = in4 |in5;
assign #10 out8  = in10|in9;
assign #10 out11 = in12|in13;

endmodule

//////// Quad xor gate
module jt7486( // ref: 74??86
    input       in1,  // pin: 1
    input       in2,  // pin: 2
    output      out3, // pin: 3
    input       in4,  // pin: 4
    input       in5,  // pin: 5
    output      out6, // pin: 6
    input       in9,  // pin: 9
    input       in10, // pin: 10
    output      out8, // pin: 8
    input       in12, // pin: 12
    input       in13, // pin: 13
    output      out11, // pin: 11
    input       VDD,   // pin: 14
    input       VSS    // pin: 7
    );

assign #10 out3  = in1 ^in2;
assign #10 out6  = in4 ^in5;
assign #10 out8  = in10^in9;
assign #10 out11 = in12^in13;

endmodule

/////////////////////////////
module jt74157( // ref: 74??157
    input      S,    // pin: 1
    input      Gn,   // pin: 15
    input   [3:0] A, // pin: 14,11,5,2
    input   [3:0] B, // pin: 13,10,6,3
    output  [3:0] Y, // pin: 12,9,7,4
    input       VDD, // pin: 16
    input       VSS  // pin: 8
    
);
wire #11 Sdly = S;
wire #6  Gndly = Gn;
assign #14 Y = Gndly ? 4'h0 : (Sdly ? B : A); 
endmodule

// synchronous presettable 4-bit binary counter, asynchronous clear
module jt74161( // ref: 74??161
    input            cet,   // pin: 10
    input            cep,   // pin: 7
    input            ld_b,  // pin: 9
    input            clk,   // pin: 2
    input            cl_b,  // pin: 1
    input      [3:0] d,     // pin: 6,5,4,3
    output     [3:0] q,     // pin: 11,12,13,14
    output           ca,    // pin: 15
    input            VDD,   // pin: 16
    input            VSS    // pin: 8
 );

    assign ca = &{q, cet};

    initial qq=4'd0;
    reg [3:0] qq;
    assign #30 q = qq;
    always @(posedge clk or negedge cl_b)
        if( !cl_b )
            qq <= 4'd0;
        else begin
            if(!ld_b) qq <= d;
            else if( cep&&cet ) qq <= qq+4'd1;
        end

endmodule // jt74161

// synchronous presettable 4-bit binary counter, synchronous clear
module jt74163(
    input cet,
    input cep,
    input ld_b,
    input clk,
    input cl_b,
    input [3:0] d,
    output reg [3:0] q,
    output ca
 );

    assign ca = &{q, cet};

    initial q=4'd0;

    always @(posedge clk)
        if( !cl_b )
            q <= 4'd0;
        else begin
            if(!ld_b) q <= d;
            else if( cep&&cet ) q <= q+4'd1;
        end

endmodule // jt74163

module jt7437( // ref: 74??37
    input       in1,  // pin: 1
    input       in2,  // pin: 2
    output      out3, // pin: 3
    input       in4,  // pin: 4
    input       in5,  // pin: 5
    output      out6, // pin: 6
    input       in9,  // pin: 9
    input       in10, // pin: 10
    output      out8, // pin: 8
    input       in12, // pin: 12
    input       in13, // pin: 13
    output      out11, // pin: 11
    input       VDD,   // pin: 14
    input       VSS    // pin: 7
    );

assign #10 out3  = ~(in1 &in2 );
assign #10 out6  = ~(in4 &in5 );
assign #10 out8  = ~(in10&in9 );
assign #10 out11 = ~(in12&in13);

endmodule

// Dual D-type flip-flop with set and reset; positive edge-trigger
module jt7474(  // ref: 74??74
    // first FF
    input      d1,      // pin: 2
    input      pr1_b,   // pin: 4
    input      cl1_b,   // pin: 1
    input      clk1,    // pin: 3
    output     q1,      // pin: 5
    output     q1_b,    // pin: 6
    // second FF
    input      d2,      // pin: 12
    input      pr2_b,   // pin: 10
    input      cl2_b,   // pin: 13
    input      clk2,    // pin: 11
    output     q2,      // pin: 9
    output     q2_b,    // pin: 8
    input       VDD,   // pin: 14
    input       VSS    // pin: 7
);
    reg qq1, qq2;

    assign #25 q1   =  qq1;
    assign #25 q2   =  qq2;
    assign #25 q1_b = ~qq1;
    assign #25 q2_b = ~qq2;

    initial begin
        qq1=1'b0;
        qq2=1'b0;
    end

    always @( posedge clk1 or negedge cl1_b or negedge pr1_b )
        if( !pr1_b ) qq1<= 1'b1;
        else if(!cl1_b) qq1 <= 1'b0;
        else qq1 <= d1;

    always @( posedge clk2 or negedge cl2_b or negedge pr2_b )
        if( !pr2_b ) qq2<= 1'b1;
        else if(!cl2_b) qq2 <= 1'b0;
        else qq2 <= d2;
endmodule

// 3-to-8 line decoder/demultiplexer; inverting
module jt74138( // ref: 74??138
    input        e1_b,  // pin: 4
    input        e2_b,	// pin: 5
    input        e3,    // pin: 6
    input  [2:0] a,     // pin: 3,2,1
    output [7:0] y_b,   // pin: 7,9,10,11,12,13,14,15
    input        VDD,   // pin: 16
    input        VSS    // pin: 8
);
    reg [7:0] yb_nodly;
    always @(*)
        if( e1_b || e2_b || !e3 )
            yb_nodly <= 8'hff;
        else yb_nodly = ~ ( 8'b1 << a );
    assign #30 y_b = yb_nodly;
endmodule

// Dual 2-to-4 line decoder/demultiplexer
module jt74139(
    input   en1_b,
    input       [1:0]       a1,
    output      [3:0]       y1_b,
    input   en2_b,
    input       [1:0]       a2,
    output      [3:0]       y2_b
);
    assign #20 y1_b = en1_b ? 4'hf : ~( (4'b1)<<a1 );
    assign #20 y2_b = en2_b ? 4'hf : ~( (4'b1)<<a2 );
endmodule

////////////////////////////////////////////////////////////////////
// dual j-k negative-edge-triggered flip-flops with clear and preset
module jt74112( // ref: 74??112
    input  pr1_b,   // pin: 4
    input  cl1_b,   // pin: 15
    input  clk1_b,  // pin: 1
    input  j1,      // pin: 3
    input  k1,      // pin: 2
    output q1,      // pin: 5
    output q1_b,    // pin: 6

    input  pr2_b,   // pin: 10
    input  cl2_b,   // pin: 14
    input  clk2_b,  // pin: 13
    input  j2,      // pin: 11
    input  k2,      // pin: 12
    output q2,      // pin: 9
    output q2_b     // pin: 7
);
    reg qq1=1'b0;
    reg qq2=1'b0;

    assign #20 q1   =  qq1;
    assign #20 q1_b = ~qq1;

    always @( negedge clk1_b or negedge pr1_b or negedge cl1_b )
        if( !pr1_b ) qq1 <= 1'b1;
        else if( !cl1_b ) qq1 <= 1'b0;
        else if( !clk1_b )
            case( {j1,k1} )
                2'b01: qq1<=1'b0;
                2'b10: qq1<=1'b1;
                2'b11: qq1<=~qq1;
            endcase

    assign #20 q2   =  qq2;
    assign #20 q2_b = ~qq2;

    always @( negedge clk2_b or negedge pr2_b or negedge cl2_b )
        if( !pr2_b ) qq2 <= 1'b1;
        else if( !cl2_b ) qq2 <= 1'b0;
        else if( !clk2_b )
            case( {j2,k2} )
                2'b01: qq2<=1'b0;
                2'b10: qq2<=1'b1;
                2'b11: qq2<=~qq2;
            endcase

endmodule

// 4-bit bidirectional universal shift register
module jt74194(     // ref: 74??194
    input [3:0] D,  // pin: 6,5,4,3
    input [1:0] S,  // pin: 10,9
    input clk,      // pin: 11
    input cl_b,     // pin: 1
    input R,        // pin: 2
    input L,        // pin: 7
    output[3:0] Q   // pin: 12,13,14,15
);
    reg [3:0] qq;
    assign #26 Q = qq;
    wire #4 clb_dly = cl_b;
    always @(posedge clk or negedge clb_dly)
        if( !clb_dly )
            qq <= 4'd0;
        else case( S )
            2'b10: qq <= { L, qq[3:1] };
            2'b01: qq <= { qq[2:0], R };
            2'b11: qq <= D;
        endcase
endmodule

// Octal bus transceiver; 3-state
module jt74245(
    inout [7:0] a,
    inout [7:0] b,
    input dir,
    input en_b
);

    assign #2 a = en_b || dir  ? 8'hzz : b;
    assign #2 b = en_b || !dir ? 8'hzz : a;

endmodule

// Octal D-type flip-flop with reset; positive-edge trigger
module jt74233(
    input [7:0] d,
    output reg [7:0] q,
    input cl_b, // CLEAR, reset
    input clk
);
    initial q=8'd0;
    always @(posedge clk or negedge cl_b)
        if( !cl_b ) q<=8'h0;
        else q<= d;

endmodule

// Hex D-type flip-flop with reset; positive-edge trigger
module jt74174( // ref: 74??174
    input      [5:0] d,  // pin: 14,13,11,6,4,3
    output     [5:0] q,  // pin: 15,12,10,7,5,2
    input         cl_b,  // pin: 1
    input         clk,   // pin: 9
    input         VDD,   // pin: 16
    input         VSS    // pin: 8    
);
    reg [5:0] qq;
    assign #30 q=qq;
    initial qq=6'd0;
    wire #5 clb_dly = cl_b;
    always @(posedge clk or negedge clb_dly)
        if( !clb_dly ) qq<=6'h0;
        else qq<= d;

endmodule

//////////////////////////////////////////
// quadruple d-type flip-flops with clear
module jt74175( // ref: 74??175
    input      [3:0] d,  // pin: 13,12,5,4
    output     [3:0] q,  // pin: 15,10,7,2
    output     [3:0] qn, // pin: 14,11,6,3
    input         cl_b,  // pin: 1
    input         clk,   // pin: 9
    input         VDD,   // pin: 16
    input         VSS    // pin: 8    
);
    reg [3:0] qq;
    assign #25 q =qq;
    assign #25 qn=~qq;
    initial qq=4'd0;
    wire #5 clb_dly = cl_b;
    always @(posedge clk or negedge clb_dly)
        if( !clb_dly ) qq<=4'h0;
        else qq<= d;
endmodule

////////////////////////////////
module jt74365( // ref: 74??365
    input  [5:0] A,     // pin: 2,4,6,14,12,10
    output [5:0] Y,     // pin: 3,5,7,13,11,9
    input        oe1_b, // pin: 1
    input        oe2_b, // pin: 15
    input        VDD,   // pin: 16
    input        VSS    // pin: 8
);
    assign #25 Y = (!oe1_b && !oe2_b) ? A : 6'bzz_zzzz;
endmodule

module jt74367( // ref: 74??367
    input  [5:0] A,     // pin: 14,12,10,6,4,2
    output [5:0] Y,     // pin: 13,11, 9,7,5,3
    input        oe1_b, // pin: 1
    input        oe2_b, // pin: 15
    input        VDD,   // pin: 16
    input        VSS    // pin: 8
);
    // a line per signal, do not use a bus assignment
    // or the delay will apply to the bus as a whole
    assign #25 Y[0] = !oe1_b ? A[0] : 1'bz;
    assign #25 Y[1] = !oe1_b ? A[1] : 1'bz;
    assign #25 Y[2] = !oe1_b ? A[2] : 1'bz;
    assign #25 Y[3] = !oe1_b ? A[3] : 1'bz;
    assign #25 Y[4] = !oe2_b ? A[4] : 1'bz;
    assign #25 Y[5] = !oe2_b ? A[5] : 1'bz;
endmodule

///////////////////////////////////////////////////////////////
// hex inverting buffers and line drivers with 3-state outputs
module jt74368(        // ref: 74??368
    input   oe_n1,     // pin: 1
    input   oe_n2,     // pin: 15
    input   [3:0] A,   // pin: 10,6,4,2
    input   [1:0] B,   // pin: 14,12
    output  [3:0] Ya,  // pin: 9,7,5,3
    output  [1:0] Yb   // pin: 13,11
);
wire #20 oen1_dly = oe_n1;
wire #20 oen2_dly = oe_n2;

assign #16 Ya[0] = !oen1_dly ? A[0] : 1'bz;
assign #16 Ya[1] = !oen1_dly ? A[1] : 1'bz;
assign #16 Ya[2] = !oen1_dly ? A[2] : 1'bz;
assign #16 Ya[3] = !oen1_dly ? A[3] : 1'bz;
assign #16 Yb[0] = !oen2_dly ? B[0] : 1'bz;
assign #16 Yb[1] = !oen2_dly ? B[1] : 1'bz;

endmodule

// Octal D-type flip-flop with reset; positive-edge trigger
module jt74273(            // ref: 74??273
    input      [7:0] d,    // pin: 18,17,14,13,8,7,4,3
    input            clk,  // pin: 11
    input            cl_b, // pin: 1
    output reg [7:0] q,    // pin: 19,16,15,12,9,6,5,2
    input     VDD,   // pin: 20
    input     VSS    // pin: 10
    
);

    always @(posedge clk or negedge cl_b)
        if(!cl_b)
            q <= 8'd0;
        else if(clk) q<=d;

endmodule

// Quad 2-input multiplexer; 3-state
module jt74257(      // ref: 74??257
    input  sel,      // pin: 1
    input  en_b,     // pin: 15
    input  [3:0] a,  // pin: 14,11,5,2
    input  [3:0] b,  // pin: 13,10,6,3
    output [3:0] y,  // pin: 12,9,7,4
    input     VDD,   // pin: 16
    input     VSS    // pin: 8
);

reg [3:0] y_nodly;
assign #20 y = y_nodly;

always @(*)
    if( !en_b )
        y_nodly = sel ? b : a;
    else
        y_nodly = 4'hz;

endmodule

// 8-bit addressable latch
module jt74259(
    input       D,
    input [2:0] A,
    input       LE_b,
    input       MR_b,
    output     [7:0]    Q
);

reg [7:0] qq;
assign #20 Q = qq;
initial qq=8'd0;

always @(*)
    if(!MR_b) qq=8'd0;
        else if(!LE_b) qq[A] <= D;

endmodule

// 4-bit binary full adder with fast carry
module jt74283( // ref: 74??283
    input [3:0] a,   // pin: 12,14,3,5
    input [3:0] b,   // pin: 11,15,2,6
    input       cin, // pin: 7
    output  [3:0] s, // pin: 10,13,1,4
    output  cout,    // pin: 9
    input     VDD,   // pin: 16
    input     VSS    // pin: 8    
);
    wire [4:0] pre = a+b+cin;
    assign #24    s = pre[3:0];
    assign #17 cout = pre[4];

endmodule

// octal d-type flip-flops with clock enable
module jt74377(  // ref: 74??377
    input   [7:0]   D, // pin: 18,17,14,13, 8,7,4,3
    output  [7:0]   Q, // pin: 19,16,15,12, 9,6,5,2
    input       cen_b, // pin: 1
    input         clk  // pin: 11
);
    reg [7:0] qq;

    assign #27 Q = qq;

    initial begin
        qq=8'b0;
    end

    always @( posedge clk )
        qq <= D;
endmodule

///////////////////////////////////////////////////////7
// Non 74-series cells

// 5501 RAM. USed in Popeye
module RAM_5501( // ref: RAM_5501
    input  [7:0] A, // pin: 7,6,5,21,1,2,3,4
    input  [3:0] D, // pin: 15,13,11,9
    output [3:0] Q, // pin: 16,14,12,10
    input      WEn  // pin: 20
);

parameter SIMFILE="";

reg [3:0] mem [0:255];
reg [3:0] QQ;

assign #300 Q = QQ;     // speed used on Popeye PCB
initial begin : clr_mem
    integer cnt;
    integer f,c;
    if( SIMFILE=="" ) begin
        for( cnt=0; cnt<256; cnt=cnt+1 ) mem[cnt] = 4'd0;
    end
    else begin
        f=$fopen(SIMFILE,"rb");
        if( f!=0 ) begin
            c=$fread( mem, f );
            $fclose(f);
            $display("INFO: %m %s (%d bytes)", SIMFILE, c);
        end
        else begin
            $display("ERROR: cannot load file %s of ROM %m", SIMFILE);
            $finish;
        end
    end
end

always @(negedge WEn) begin
    mem[A] <= D;
end

always @(*) begin
    QQ <= mem[A];
end

endmodule
////////////////////////////////////////////////////////////////////
module RAM_7063( // ref: RAM_7063
    input [5:0] A, // pin: 3,2,1,27,26,25
    input [8:0] I, // pin: 12,11,10,9,8,7,6,5,4,3,2,1,0
    inout [8:0] O, // pin: 16,17,18,19,20,21,22,23,24
    input WEn, // pin: 13
    input CEn  // pin: 15
);

reg [8:0] pre;
reg [8:0] mem[0:63];

initial begin : clr_mem
    integer cnt;
    for( cnt=0; cnt<54; cnt=cnt+1 ) mem[cnt] = 9'd0;
end

// output is all 1's (open collector -> Z)
assign #100 O = (CEn||!WEn) ? 9'hzzz : pre;

always @(negedge WEn) mem[A] <= I;
always @(*) pre <= mem[A];

endmodule

////////////////////////////////////////////////////////////////////
module RAM_2016( // ref: RAM_2016
    input [10:0] A,   // pin: 19,22,23,1,2,3,4,5,6,7,8
    inout [ 7:0] D,   // pin: 17,16,15,14,13,11,10,9
    input        WEn, // pin: 21
    input        CEn  // pin: 18
);

reg [8:0] pre;
reg [8:0] mem[0:2047];

assign #100 D = CEn ? 8'hzz : pre;

initial begin : clr_mem
    integer cnt;
    for( cnt=0; cnt<2048; cnt=cnt+1 ) mem[cnt] = 8'd0;
end

always @(negedge WEn) mem[A] <= D;
always @(*) pre <= mem[A];

endmodule

///////////////////////////////////////////////////////////////////
module ROM_2764( // ref: ROM_2764
    input [12:0] A, // pin: 2,23,21,24,25,3,4,5,6,7,8,9,10
    output [7:0] D, // pin: 19,18,17,16,15,13,12,11
    input      OEn, // pin: 22
    input      CEn, // pin: 20
    input        P  // pin: 27
);
// P input is ignored
parameter SIMFILE="blank_filename";

reg [7:0] mem[0:2**13-1];

initial begin : rom_load
    integer f,c;
    f=$fopen(SIMFILE,"rb");
    if( f!=0 ) begin
        c=$fread( mem, f );
        $fclose(f);
        $display("INFO: %m %s (%d bytes)", SIMFILE, c);
    end
    else begin
        $display("ERROR: cannot load file %s of ROM %m", SIMFILE);
        $finish;
    end
end

wire [12:0] AA;
assign #300 AA = A;
assign #150 D = !OEn && !CEn ? mem[AA] : 8'hZZ;

endmodule

/////////////////
module rpullup( // ref: rpullup
    inout x // pin: 1
);

pullup pu(x);

endmodule

/////////////////
module rpulldown( // ref: rpulldown
    inout x // pin: 1
);

pulldown pd(x);

endmodule

////////////////////////////////////////
module delay( // ref: delay
    input a, // pin: 1
    output y // pin: 2
);

parameter delay_time=10;
assign #delay_time y=a;

endmodule