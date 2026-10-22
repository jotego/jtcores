`timescale 1ns/1ps
module test;
    reg [15:0] opcode;
    integer fd, i;
    string path;
    jttms10_ctrl u_ctrl(
        .rst(1'b1), .clk(1'b0), .enable(1'b0), .ready(1'b0), .md(opcode),
        .shift_count(5'd0), .lmo_more(1'b0), .multi_bit(1'b0),
        .multi_steps(5'd0), .multi_load(1'b0), .mul_count(5'd0),
        .div_early_cond(1'b0), .reti_pbx(1'b0), .slot_valid(1'b0),
        .slot_opcode(16'd0), .gfx_active(1'b0), .gfx_done(1'b0),
        .gfx_checkpoint(1'b0), .gfx_pbx_ir(16'd0), .irq_req(1'b0),
        .nmi_req(1'b0), .nmi_nostack(1'b0), .halt_req(1'b0),
        .emu_run(1'b0), .ie(1'b0)
    );
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
