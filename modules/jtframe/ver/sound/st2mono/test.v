`timescale 1ns/1ps;

module test;

wire signed [11:0] out_l, out_r, mono_out, passthru;
reg  signed [11:0] in_l, in_r, mono_in;

jtframe_st2mono #(.STEREO_IN(1),.STEREO_OUT(1))u_stereo2stereo(
    .sin    ({ in_l,  in_r}),
    .sout   ({out_l, out_r})
);

jtframe_st2mono #(.STEREO_IN(1),.STEREO_OUT(0))u_stereo2mono(
    .sin    ({ in_l,  in_r}),
    .sout   (  mono_out    )
);

jtframe_st2mono #(.STEREO_IN(0),.STEREO_OUT(0))u_mono2mono(
    .sin    (  mono_in  ),
    .sout   (  passthru )
);

initial begin
    in_l=0;
    in_r=0;
    mono_in=0;
    #5;
    if({out_l,out_r,mono_out,passthru}!=0||mono_in!=passthru) begin
        $display("assertion failed at line %d.\nFAIL",`__LINE__-1);
        $finish;
    end

    in_l=50;
    in_r=0;
    mono_in=35;
    #5;
    if({out_l,out_r,mono_out}!={12'd50,12'd0,12'd50} ||
        passthru!=12'd35 || mono_in!=passthru ) begin
        $display("assertion failed at line %d.\nFAIL",`__LINE__-1);
        $finish;
    end

    in_l=20;
    in_r=-23;
    mono_in=-125;
    #5;
    if({out_l,out_r,mono_out}!={12'd20,-12'd23,-12'd3} ||
        passthru!=-12'd125 || mono_in!=passthru ) begin
        $display("assertion failed at line %d.\nFAIL",`__LINE__-1);
        $finish;
    end

    in_l=12'h700;
    in_r=12'h760;
    mono_in=12'h7f0;
    #5;
    if({out_l,out_r,mono_out}!={12'h700,12'h760,12'h7ff} ||
        passthru!=12'h7f0 || mono_in!=passthru ) begin
        $display("assertion failed at line %d.\nFAIL",`__LINE__-1);
        $finish;
    end

    in_l=12'h80f;
    in_r=12'h8f0;
    mono_in=12'h8f0;
    #5;
    if({out_l,out_r,mono_out}!={12'h80f,12'h8f0,12'h800} ||
        passthru!=12'h8f0 || mono_in!=passthru) begin
        $display("assertion failed at line %d.\nFAIL",`__LINE__-1);
        $finish;
    end

    $display("PASS");
end

endmodule