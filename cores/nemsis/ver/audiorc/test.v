`timescale 1ns/1ps
module test;
    localparam integer FS=192000, AMP=12000;
    reg clk=0, rst=1, sample=0;
    reg [1:0] switches=0; // {A12 / C23, A11 / 33 nF}
    reg signed [15:0] sin=0;
    wire rc33_en=switches[0], rc47_en=switches[1];
    wire [2:0] ay7e_rcen={~rc33_en & rc47_en,rc33_en & ~rc47_en,rc33_en & rc47_en};
    wire ay8e_rcen=rc47_en, wav1_rcen=rc47_en, wav2_rcen=rc47_en;
    wire [29:0] p0,p1,p2,p3;
`include "generated_audio_coeffs.vh"

    wire signed [15:0] stage1, ay7e_filtered, common_filtered;
    reg signed [15:0] sine_10hz[0:19199];
    always #1 clk=~clk;
    initial $readmemh("sine_10hz.hex",sine_10hz);

    jtframe_pole #(.WS(16),.WA(15)) u_ay7e_pole1(
        .rst(rst),.clk(clk),.sample(sample),.sin(sin),.a(p0[14:0]),.sout(stage1)
    );
    jtframe_pole #(.WS(16),.WA(15)) u_ay7e_pole2(
        .rst(rst),.clk(clk),.sample(sample),.sin(stage1),.a(p0[29:15]),.sout(ay7e_filtered)
    );
    jtframe_pole #(.WS(16),.WA(15)) u_ay8e_common_pole(
        .rst(rst),.clk(clk),.sample(sample),.sin(sin),.a(p1[14:0]),.sout(common_filtered)
    );

    function real pole_gain(input integer coefficient,input integer frequency);
        real a,w,re,im,numerator,denominator;
        begin
            if(coefficient==0) pole_gain=1.0;
            else begin
                a=coefficient/32768.0;
                w=6.283185307179586*frequency/FS;
                re=1.0-a*$cos(w); im=a*$sin(w);
                numerator=(1.0-a)*$sqrt(2.0+2.0*$cos(w));
                denominator=2.0*$sqrt(re*re+im*im);
                pole_gain=numerator/denominator;
            end
        end
    endfunction

    function integer sine_value(input integer frequency,input integer index);
        integer lut_index;
        begin
            lut_index=(index*(frequency/10))%(FS/10);
            sine_value=$signed(sine_10hz[lut_index]);
        end
    endfunction

    task reset_filter(input [1:0] state);
        begin
            @(negedge clk); rst=1; sample=0; switches=state; sin=0;
            repeat(4) @(negedge clk);
            rst=0;
        end
    endtask

    task check_bank(input [1:0] state);
        reg [29:0] expected;
        begin
            case(state)
                2'b00: expected=30'h0;
                2'b01: expected={15'h0000,A33_COEF};
                2'b10: expected={A47_COEF,15'h0000};
                2'b11: expected={A47_COEF,A33_COEF};
            endcase
            #0;
            if(p0!==expected) begin
                $display("FAIL: generated AY7E bank state=%b got=%h expected=%h",state,p0,expected); $fatal(1);
            end
            if(p1!==p2 || p1!==p3) begin
                $display("FAIL: generated common-pole banks differ p1=%h p2=%h p3=%h",p1,p2,p3); $fatal(1);
            end
            if(rc47_en && p1!=={15'h0000,A47_COEF}) begin
                $display("FAIL: A12 common pole missing %h",p1); $fatal(1);
            end
            if(!rc47_en && (p1!==30'h0 || p2!==30'h0 || p3!==30'h0)) begin
                $display("FAIL: common poles should bypass p1=%h p2=%h p3=%h",p1,p2,p3); $fatal(1);
            end
        end
    endtask

    task pulse_sample(input integer x,output integer y,output integer yc);
        begin
            @(negedge clk); sin=x; sample=1;
            @(negedge clk); y=$signed(ay7e_filtered); yc=$signed(common_filtered); sample=0;
            @(negedge clk);
        end
    endtask

    task measure_response(input [1:0] state,input integer frequency,
                          input integer discard,input integer periods,
                          input real expected_p0,input real expected_common);
        integer n,count,x,y,yc,period_samples;
        real in_sq,p0_sq,common_sq,in_rms,p0_rms,common_rms,p0_gain,common_gain,p0_tol,common_tol;
        begin
            period_samples=FS/frequency; count=period_samples*periods;
            in_sq=0.0; p0_sq=0.0; common_sq=0.0;
            reset_filter(state); check_bank(state);
            for(n=0;n<discard+count;n=n+1) begin
                x=sine_value(frequency,n); pulse_sample(x,y,yc);
                if(n>=discard) begin
                    in_sq=in_sq+1.0*x*x; p0_sq=p0_sq+1.0*y*y; common_sq=common_sq+1.0*yc*yc;
                end
            end
            in_rms=$sqrt(in_sq/count);
            p0_rms=$sqrt(p0_sq/count);
            common_rms=$sqrt(common_sq/count);
            p0_gain=p0_rms/in_rms; common_gain=common_rms/in_rms;
            p0_tol=(expected_p0*0.025>0.002)?expected_p0*0.025:0.002;
            common_tol=(expected_common*0.025>0.002)?expected_common*0.025:0.002;
            if(in_rms<5000 || p0_rms<1 || common_rms<1) begin
                $display("FAIL: silent response state=%b f=%0d input=%0.2f p0=%0.2f common=%0.2f N=%0d",state,frequency,in_rms,p0_rms,common_rms,count); $fatal(1);
            end
            if((p0_gain-expected_p0>p0_tol) || (expected_p0-p0_gain>p0_tol)) begin
                $display("FAIL: AY7E state=%b f=%0d measured=%0.6f expected=%0.6f tol=%0.6f",state,frequency,p0_gain,expected_p0,p0_tol); $fatal(1);
            end
            if((common_gain-expected_common>common_tol) || (expected_common-common_gain>common_tol)) begin
                $display("FAIL: common state=%b f=%0d measured=%0.6f expected=%0.6f tol=%0.6f",state,frequency,common_gain,expected_common,common_tol); $fatal(1);
            end
            $display("MEASURE state=%b f=%0dHz Fs=%0d N=%0d discarded=%0d inputRMS=%0.2f ay7RMS=%0.2f ay7gain=%0.6f ay7expected=%0.6f commonRMS=%0.2f commongain=%0.6f commonExpected=%0.6f",state,frequency,FS,count,discard,in_rms,p0_rms,p0_gain,expected_p0,common_rms,common_gain,expected_common);
            $display("CSV,%0d,%0d,%0d,%0d,%0d,%0.4f,%0.4f,%0.8f,%0.8f,%0.4f,%0.8f,%0.8f",
                state,frequency,FS,count,discard,in_rms,p0_rms,p0_gain,expected_p0,
                common_rms,common_gain,expected_common);
        end
    endtask

    task check_transitions;
        integer i,x,y,yc,peak_abs,state_i;
        reg [1:0] state;
        begin
            rst=0; sample=0; switches=0; peak_abs=0;
            for(state_i=0;state_i<4;state_i=state_i+1) begin
                state=state_i[1:0];
                switches=state; check_bank(state);
                for(i=0;i<32;i=i+1) begin
                    x=sine_value(1000,i+500); pulse_sample(x,y,yc);
                    if(y<0) y=-y; if(yc<0) yc=-yc;
                    if(y>peak_abs) peak_abs=y; if(yc>peak_abs) peak_abs=yc;
                    if(y>15000 || yc>15000) begin
                        $display("FAIL: transition bound state=%b AY7=%0d common=%0d",state,y,yc); $fatal(1);
                    end
                end
            end
            $display("TRANSITIONS PASS: all output samples bounded to +/-15000, peak=%0d",peak_abs);
        end
    endtask

    initial begin
        $display("CSV,state,freq_hz,fs_hz,samples,discard,input_rms,ay7_rms,ay7_gain,ay7_expected,common_rms,common_gain,common_expected");
        check_bank(2'b00);
        measure_response(2'b00,1000,0,10,1.0,1.0);
        measure_response(2'b01,1000,500,10,pole_gain(A33_COEF,1000),1.0);
        measure_response(2'b01,4000,500,10,pole_gain(A33_COEF,4000),1.0);
        measure_response(2'b01,8000,500,10,pole_gain(A33_COEF,8000),1.0);
        measure_response(2'b10,10,16000,3,pole_gain(A47_COEF,10),pole_gain(A47_COEF,10));
        measure_response(2'b10,20,16000,3,pole_gain(A47_COEF,20),pole_gain(A47_COEF,20));
        measure_response(2'b10,40,16000,3,pole_gain(A47_COEF,40),pole_gain(A47_COEF,40));
        measure_response(2'b11,10,16000,3,pole_gain(A33_COEF,10)*pole_gain(A47_COEF,10),pole_gain(A47_COEF,10));
        measure_response(2'b11,20,16000,3,pole_gain(A33_COEF,20)*pole_gain(A47_COEF,20),pole_gain(A47_COEF,20));
        measure_response(2'b11,40,16000,3,pole_gain(A33_COEF,40)*pole_gain(A47_COEF,40),pole_gain(A47_COEF,40));
        check_transitions();
        $display("PASS: generated jtframe_pole response matches quantized digital transfer within 2.5%% or 0.002 absolute gain");
        $finish;
    end
endmodule
