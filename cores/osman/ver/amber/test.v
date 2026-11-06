`timescale 1ns/1ps
module test;
reg clk=0, run_clocks=0;
always #5 if(run_clocks) clk=~clk;
reg rst=1;
localparam CPU_DIV = `ifdef ALTERA_FPGA 7 `else 8 `endif,
           CEN_NUM = `ifdef ALTERA_FPGA 2 `else 1 `endif,
           CEN_DEN = `ifdef ALTERA_FPGA 7 `else 4 `endif;
wire ce, open_cen;
jtframe_gated_cen #(
    .W     ( 2       ),
    .NUM   ( CEN_NUM ),
    .DEN   ( CEN_DEN )
) u_cpu_cen(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .busy   ( 1'b0          ),
    .cen    ( {ce,open_cen} ),
    .fave   (               ),
    .fworst (               )
);
wire [31:0] addr,wdata;
wire [3:0] sel;
wire we,cyc,stb,tga;
reg [31:0] mem[0:255];
reg [7:0] latency=0;
integer delay_cycles=1;
integer clocks=0, ticks=0, advances=0, transfers=0, writes=0;
integer index, lane;
integer runs=0;
integer words=50, expected_writes=7;
reg [2047:0] program_file;
reg [31:0] check_pc, check_alu, check_rn, check_address;
reg check_execute, check_abort, check_data, check_pc_wen;
reg [1:0] check_pc_sel;
reg [3:0] check_sel;
integer adex_checks=0, check_iteration, check_index;
reg [31:0] boundary [0:15];
reg [31:0] shift_data;
reg [7:0] shift_amount;
reg [1:0] shift_function;
reg shift_carry, shift_zero;
wire [31:0] shift_generic, shift_fpga;
wire carry_generic, carry_fpga;
integer shift_checks=0, shift_pattern, shift_control;
a23_barrel_shift reference_shift(
    .i_in             ( shift_data     ),
    .i_carry_in       ( shift_carry    ),
    .i_shift_amount   ( shift_amount   ),
    .i_shift_imm_zero ( shift_zero     ),
    .i_function       ( shift_function ),
    .o_out            ( shift_generic  ),
    .o_carry_out      ( carry_generic  )
);
a23_barrel_shift_fpga fpga_shift(
    .i_in             ( shift_data     ),
    .i_carry_in       ( shift_carry    ),
    .i_shift_amount   ( shift_amount   ),
    .i_shift_imm_zero ( shift_zero     ),
    .i_function       ( shift_function ),
    .o_out            ( shift_fpga     ),
    .o_carry_out      ( carry_fpga     )
);
wire req=cyc&&stb;
wire ack=req&&(latency>=delay_cycles);
wire [31:0] rdata=ack ? mem[addr[9:2]] : 32'hffffffff;
a23_core cpu(.i_clk(clk),.i_reset(rst),.i_irq(1'b0),.i_firq(1'b0),
    .i_system_rdy(ce),.o_wb_adr(addr),.o_wb_sel(sel),.o_wb_we(we),
    .i_wb_dat(rdata),.o_wb_dat(wdata),.o_wb_cyc(cyc),.o_wb_stb(stb),
    .i_wb_ack(ack),.i_wb_err(1'b0),.o_wb_tga(tga));

wire [907:0] audited_state = {
    cpu.u_execute.u_register_bank.r0,
    cpu.u_execute.u_register_bank.r1,
    cpu.u_execute.u_register_bank.r2,
    cpu.u_execute.u_register_bank.r3,
    cpu.u_execute.u_register_bank.r4,
    cpu.u_execute.u_register_bank.r5,
    cpu.u_execute.u_register_bank.r6,
    cpu.u_execute.u_register_bank.r7,
    cpu.u_execute.u_register_bank.r8,
    cpu.u_execute.u_register_bank.r9,
    cpu.u_execute.u_register_bank.r10,
    cpu.u_execute.u_register_bank.r11,
    cpu.u_execute.u_register_bank.r12,
    cpu.u_execute.u_register_bank.r13,
    cpu.u_execute.u_register_bank.r14,
    cpu.u_execute.u_register_bank.r15,
    cpu.u_execute.u_register_bank.r8_firq,
    cpu.u_execute.u_register_bank.r9_firq,
    cpu.u_execute.u_register_bank.r10_firq,
    cpu.u_execute.u_register_bank.r11_firq,
    cpu.u_execute.u_register_bank.r12_firq,
    cpu.u_execute.u_register_bank.r13_firq,
    cpu.u_execute.u_register_bank.r14_firq,
    cpu.u_execute.u_register_bank.r13_svc,
    cpu.u_execute.u_register_bank.r14_svc,
    cpu.u_execute.u_register_bank.r13_irq,
    cpu.u_execute.u_register_bank.r14_irq,
    cpu.u_execute.status_bits_mode,
    cpu.u_execute.status_bits_mode_rds,
    cpu.u_execute.status_bits_mode_rds_oh,
    cpu.u_execute.o_address,
    cpu.u_decode.o_rm_sel,
    cpu.u_decode.o_rds_sel,
    cpu.u_decode.o_rn_sel
};
reg [907:0] previous_audited_state;
reg audit_valid=0, audit_reset=1, audit_step=0;
integer audit_cycle=0, last_step=-100, last_cen=-100, audit_checks=0;
always @(posedge clk) begin
    audit_cycle=audit_cycle+1;
    audit_step=!cpu.fetch_stall;
    audit_reset=rst;
    if(!rst) begin
        if(ce) begin
            if(last_cen>=0 && audit_cycle-last_cen!=CPU_DIV)
                $fatal(1,"FAIL: CPU enable spacing");
            last_cen=audit_cycle;
        end
        if(cpu.u_execute.fetch_stall!==cpu.fetch_stall)
            $fatal(1,"FAIL: execute bypasses shared stall");
        if(audit_step) begin
            if(!ce || audit_cycle-last_step<2)
                $fatal(1,"FAIL: multicycle register updates too close");
            last_step=audit_cycle;
        end
    end else begin
        last_step=-100;
        last_cen=-100;
    end
    #1;
    if(audit_valid && !audit_reset && !audit_step && audited_state!==previous_audited_state)
        $fatal(1,"FAIL: constrained register changed outside CPU enable");
    previous_audited_state=audited_state;
    audit_valid=!audit_reset;
    audit_checks=audit_checks+1;
end
initial begin
    if (!$value$plusargs("delay=%d",delay_cycles)) delay_cycles=1;
    if (!$value$plusargs("words=%d",words)) words=50;
    if (!$value$plusargs("writes=%d",expected_writes)) expected_writes=7;
    if (!$value$plusargs("rom=%s",program_file)) program_file="program.hex";
    for(index=0;index<256;index=index+1) mem[index]=0;
    $readmemh(program_file,mem,0,words-1);
    force cpu.u_execute.pc=check_pc;
    force cpu.u_execute.alu_out=check_alu;
    force cpu.u_execute.rn=check_rn;
    force cpu.u_execute.o_address=check_address;
    force cpu.u_execute.execute=check_execute;
    force cpu.u_execute.i_fetch_abort=check_abort;
    force cpu.u_execute.i_data_access_exec=check_data;
    force cpu.u_execute.pc_wen=check_pc_wen;
    force cpu.u_execute.i_pc_sel=check_pc_sel;
    force cpu.u_execute.i_address_sel=check_sel;
    boundary[0]=0; boundary[1]=1; boundary[2]=3; boundary[3]=4;
    boundary[4]=32'h03fffffb; boundary[5]=32'h03fffffc;
    boundary[6]=32'h03fffffd; boundary[7]=32'h03fffffe;
    boundary[8]=32'h03ffffff; boundary[9]=32'h04000000;
    boundary[10]=32'hfbffffff; boundary[11]=32'hfffffffb;
    boundary[12]=32'hfffffffc; boundary[13]=32'hfffffffd;
    boundary[14]=32'hfffffffe; boundary[15]=32'hffffffff;
    for(check_iteration=0;check_iteration<4112;check_iteration=check_iteration+1) begin
        check_pc=check_iteration<16 ? boundary[check_iteration] : $random;
        check_alu=check_pc;
        check_rn=check_pc;
        check_address=check_pc;
        if(check_iteration>=16) begin
            check_alu=$random;
            check_rn=$random;
            check_address=$random;
        end
        if(check_iteration<128)
            check_alu=(32'hffffffff >> check_iteration[6:2]) + {30'd0,check_iteration[1:0]};
        for(check_index=0;check_index<256;check_index=check_index+1) begin
            check_sel=check_index[3:0];
            check_execute=check_index[4];
            check_abort=check_index[5];
            check_data=check_index[6];
            check_pc_wen=check_index[7];
            check_pc_sel=check_index[7] ? 2'd1 : 2'd0;
            #1;
            if(cpu.u_execute.alu_plus4 !== check_alu+32'd4)
                $fatal(1,"ALU address increment mismatch input=%h",check_alu);
            if(cpu.u_execute.adex_nxt !== ((|cpu.u_execute.o_address_nxt[31:26]) && !check_data))
                $fatal(1,"address exception mismatch address=%h select=%h",check_pc,check_sel);
            adex_checks=adex_checks+1;
        end
    end
    release cpu.u_execute.pc;
    release cpu.u_execute.alu_out;
    release cpu.u_execute.rn;
    release cpu.u_execute.o_address;
    release cpu.u_execute.execute;
    release cpu.u_execute.i_fetch_abort;
    release cpu.u_execute.i_data_access_exec;
    release cpu.u_execute.pc_wen;
    release cpu.u_execute.i_pc_sel;
    release cpu.u_execute.i_address_sel;
    $display("Checked %0d address exception equivalence cases",adex_checks);
    for(shift_pattern=0;shift_pattern<128;shift_pattern=shift_pattern+1) begin
        case(shift_pattern)
            0: shift_data=0;
            1: shift_data=32'hffffffff;
            2: shift_data=32'ha5a5a5a5;
            3: shift_data=32'h5a5a5a5a;
            default: shift_data=shift_pattern<36 ? 32'd1 << (shift_pattern-4) : $random;
        endcase
        for(shift_control=0;shift_control<4096;shift_control=shift_control+1) begin
            shift_function=shift_control[1:0];
            shift_amount=shift_control[9:2];
            shift_zero=shift_control[10];
            shift_carry=shift_control[11];
            #1;
            if({carry_fpga,shift_fpga}!=={carry_generic,shift_generic})
                $fatal(1,"shifter mismatch data=%h amount=%0d function=%0d zero=%b carry=%b got=%h expected=%h",
                    shift_data,shift_amount,shift_function,shift_zero,shift_carry,
                    {carry_fpga,shift_fpga},{carry_generic,shift_generic});
            shift_checks=shift_checks+1;
        end
    end
    $display("Checked %0d barrel shifter equivalence cases",shift_checks);
    run_clocks=1;
    repeat(16) @(negedge clk);
    rst=0;
end
always @(posedge clk) begin
    if(rst || !req) latency<=0;
    else if(!ack) latency<=latency+1'b1;
    if(!rst) begin
        clocks=clocks+1;
        if(ce) begin
            ticks=ticks+1;
            if(!cpu.fetch_stall) advances=advances+1;
        end
        if(ack) begin
            transfers=transfers+1;
            if(we) begin
                writes=writes+1;
                for(lane=0;lane<4;lane=lane+1)
                    if(sel[lane]) mem[addr[9:2]][lane*8+:8]<=wdata[lane*8+:8];
                if(addr==32'h200) begin
                    $display("MEASURE delay=%0d clocks=%0d ticks=%0d advances=%0d transfers=%0d writes=%0d",delay_cycles,clocks,ticks,advances,transfers,writes);
                    if(wdata!=32'h5a) $fatal(1,"ARM instruction test failed at PC=%08x",cpu.u_execute.o_address);
                    // Each architectural write must reach the target once.
                    if(writes!=expected_writes) $fatal(1,"Repeated/lost writes: %0d (expected %0d)",writes,expected_writes);
                    $display("PASS delay=%0d clocks=%0d ticks=%0d advances=%0d transfers=%0d writes=%0d",delay_cycles,clocks,ticks,advances,transfers,writes);
                    if(runs==1) begin
                        $display("PASS instruction program after warm reset; %0d clock-enable audit checks",audit_checks);
                        $finish;
                    end
                    // Exercise warm reset after status changes: SVC, masks,
                    // flags and bank-selection state must be reset too.
                    @(negedge clk);
                    cpu.u_execute.status_bits_flags=4'ha;
                    cpu.u_execute.status_bits_mode=2'd0;
                    cpu.u_execute.status_bits_irq_mask=0;
                    cpu.u_execute.status_bits_firq_mask=0;
                    rst=1;
                    repeat(3) @(negedge clk);
                    if(cpu.u_execute.o_status_bits!==32'h0c000003)
                        $fatal(1,"Warm reset status wrong: %08x",cpu.u_execute.o_status_bits);
                    $display("PASS warm reset: SVC, IRQ/FIRQ masked, flags cleared");
                    runs=1;
                    clocks=0; ticks=0; advances=0; transfers=0; writes=0;
                    rst=0;
                end
            end
        end
        if(clocks>40000) $fatal(1,"Timeout PC=%08x advances=%0d ticks=%0d",cpu.u_execute.o_address,advances,ticks);
    end
end
endmodule
