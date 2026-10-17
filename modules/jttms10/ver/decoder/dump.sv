`timescale 1ns/1ps
module test;
    reg [15:0] opcode;
    integer fd, i;
    string path;
    jttms10_ctrl u_ctrl(.rst(1'b1), .clk(1'b0), .md(opcode));
    initial begin
        if(!$value$plusargs("output=%s", path)) $fatal(1,"missing output path");
        fd=$fopen(path,"w");
        if(!fd) $fatal(1,"cannot open dispatch output");
        for(i=0;i<2048;i=i+1) begin
            // Low five bits 00001 select the common family in every group.
            opcode={i[10:0],5'b00001};
            $fdisplay(fd,"%02h",u_ctrl.decode_family(opcode));
        end
        $fclose(fd);
        $finish;
    end
endmodule
