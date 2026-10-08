`timescale 1ns/1ps

// Cross-check individual instructions against the independent silicon model.
// The full game-program test covers program fetch and external RAM timing.
module test;
reg clk=0, rst=1, cen=0, start=0;
reg cs=0, cpu_we=0, bk=0;
reg [12:0] cpu_addr=0;
reg [7:0] cpu_dout=0, ram_byte=0;
wire [7:0] cpu_din, ram_din, st_dout;
wire [12:0] ram_addr;
wire cpu2ram_we, ram_we, ram_oe, out0;

jt052591 uut(
    .rst(rst), .clk(clk), .cen(cen), .cs(cs), .cpu_we(cpu_we),
    .cpu_addr(cpu_addr), .cpu_dout(cpu_dout), .cpu_ram_dout(8'h5a),
    .cpu_din(cpu_din), .cpu2ram_we(cpu2ram_we),
    .ram_addr(ram_addr), .ram_din(ram_din), .ram_we(ram_we),
    .ram_oe(ram_oe), .ram_dout(ram_byte),
    .bk(bk), .start(start), .out0(out0), .st_dout(st_dout)
);
wire [7:0] ref_db, ref_ed;
wire [12:0] ref_ea;
wire ref_out, ref_cs, ref_oe, ref_we;
k052591 reference(
    .pin_M12(1'b0), .pin_RST(1'b1), .pin_CS(1'b1), .pin_NRD(1'b1),
    .pin_START(1'b1), .pin_BK(1'b0), .pin_OUT0(ref_out),
    .pin_AB(13'd0), .pin_DB(ref_db), .pin_EA(ref_ea), .pin_ED(ref_ed),
    .pin_ERCS(ref_cs), .pin_EROE(ref_oe), .pin_ERWE(ref_we), .PIN21(1'b0)
);

reg [35:0] ins;
reg [15:0] a, b, old_acc;
reg [7:0] msb;
reg hist_sub, hist_mux;
wire ref_k110 = !hist_mux;
wire [35:0] ref_iram_din = {28'd0,msb};
reg [5:0] current_pc, return_pc, entry_pc, sequential_pc;
reg [15:0] old_regs[0:7], expected_regs[0:7];
reg [15:0] expected_acc, expected_alu;
reg [5:0] expected_pc, expected_ret;
reg expected_sub, expected_mux, expected_out;
reg [7:0] expected_msb, expected_data;
reg [12:0] expected_addr;
reg expected_oe, expected_we, expected_write;
integer n, j, seed=32'h052591;

initial begin
    $dumpfile("test.lxt");
    $dumpvars(1,test);
end

task tick;
    begin #5 clk=1; #5 clk=0; end
endtask

task host;
    input [12:0] addr;
    input [7:0] value;
    begin
        cpu_addr=addr; cpu_dout=value; cs=1; cpu_we=1;
        repeat(3) tick;
        cs=0; cpu_we=0;
        repeat(2) tick;
    end
endtask

task word;
    input [35:0] value;
    begin
        host(0,value[7:0]); host(0,value[15:8]);
        host(0,value[23:16]); host(0,value[31:24]);
        host(0,{4'hf,value[35:32]});
    end
endtask

initial begin
    // Hold the gate model at its stable execute phase. Its ALU and mux logic
    // remain completely untouched; only architectural inputs are injected.
    force reference.clk=1'b1;
    force reference.RUN=1'b1;
    force reference.RUN_DLY=1'b1;
    force reference.ir=ins;
    force reference.rega=a;
    force reference.regb=b;
    force reference.acc=old_acc;
    force reference.N68=hist_sub;
    force reference.K110=ref_k110;
    force reference.D_MUX=ram_byte;
    force reference.iram_din=ref_iram_din;
    force reference.iram_a_next=sequential_pc;
    force reference.iram_a_ret=return_pc;
    force reference.LD=entry_pc;

    tick; rst=0; tick;
    if(out0!==1) $fatal(1,"FAIL reset OUT0");
    // Partial instruction followed by AB9 must reset byte position. Fifth
    // byte's high nibble is ignored, loading wraps, and locked writes target 0.
    host(13'h200,8'h3f);
    host(0,8'hde); host(0,8'had);
    host(13'h200,8'h3f);
    word(36'h123456789);
    word(36'habcdef012);
    if(uut.ram_msb!==8'h12) $fatal(1,"FAIL shared upload/high-byte latch");
    if(uut.load_pc!==1 || uut.load_byte!==0)
        $fatal(1,"FAIL load counter/wrap");
    host(13'h200,8'h3f); repeat(2) tick;
    if(uut.ir!==36'h123456789) $fatal(1,"FAIL loader partial reset/fifth nibble");
    host(13'h200,8'h00); repeat(2) tick;
    if(uut.ir!==36'habcdef012) $fatal(1,"FAIL loader wrap data");
    host(13'h200,8'h85);
    word(36'h987654321); repeat(2) tick;
    if(uut.ir!==36'h987654321 || uut.load_pc!==6)
        $fatal(1,"FAIL locked program address or LD increment");
    // Host writes cannot alter configuration while START is asserted.
    start=1; host(13'h200,8'h01);
    if(uut.load_pc!==6) $fatal(1,"FAIL running program write accepted");
    start=0; tick;

    force uut.ir=ins;
    // Cover all sources, operations, destinations and shift modes repeatedly,
    // including operand edge cases, signed immediates and division histories.
    for(n=0;n<65536;n=n+1) begin
        ins={$random(seed),$random(seed)};
        ins[5:0]=n[5:0];
        ins[8:6]=n[8:6];
        ins[33:32]=n[10:9];
        hist_sub=n[11]; hist_mux=n[12];
        for(j=0;j<8;j=j+1) old_regs[j]=$random(seed);
        old_acc=$random(seed);
        case(n[15:13])
            0: begin old_acc=0; old_regs[ins[11:9]]=0; end
            1: begin old_acc=16'hffff; old_regs[ins[11:9]]=16'hffff; end
            2: begin old_acc=16'h7fff; old_regs[ins[11:9]]=1; end
            3: begin old_acc=16'h8000; old_regs[ins[11:9]]=16'h8000; end
            4: begin old_acc=16'h5555; old_regs[ins[11:9]]=16'haaaa; end
        endcase
        a=old_regs[ins[11:9]]; b=old_regs[ins[14:12]];
        msb=$random(seed); ram_byte=$random(seed);
        current_pc=$random(seed); return_pc=$random(seed); entry_pc=$random(seed);
        sequential_pc=current_pc+6'd1;
        start=1; cen=1;
        uut.run=1; uut.phase=1;
        uut.pc=current_pc; uut.ret=return_pc; uut.load_pc=entry_pc;
        uut.acc=old_acc; uut.div_sub=hist_sub; uut.div_mux=hist_mux;
        uut.ram_msb=msb; uut.out0=n[0];
        uut.ext_addr=13'h1234; uut.ext_data=8'h6a;
        uut.oe_n=n[1]; uut.we_n=n[2];
        for(j=0;j<8;j=j+1) uut.gpr[j]=old_regs[j];
        #2;
        if({uut.result,uut.carry[16],uut.overflow,uut.reg_result} !==
           {reference.alu,reference.flag_carry,reference.flag_ovf,reference.reg_wr_mux})
            $fatal(1,"FAIL ALU vector=%0d IR=%09h A=%04h B=%04h acc=%04h history=%b%b got=%04h/%b%b expected=%04h/%b%b",n,ins,a,b,old_acc,hist_sub,hist_mux,uut.result,uut.carry[16],uut.overflow,reference.alu,reference.flag_carry,reference.flag_ovf);
        expected_alu=reference.alu;
        expected_pc=reference.iram_a_mux;
        expected_ret=(!ins[15] && ins[25:24]==0) ? sequential_pc : return_pc;
        for(j=0;j<8;j=j+1) expected_regs[j]=old_regs[j];
        if(ins[8] || ins[7]) expected_regs[ins[14:12]]=reference.reg_wr_mux;
        expected_acc=old_acc;
        if(!ins[6] && (ins[8] || !ins[7])) begin
            case(ins[8:7])
                0,1: expected_acc=reference.alu;
                2: expected_acc={ins[33] ? reference.alu[0] : reference.CIN0,old_acc[15:1]};
                3: expected_acc={old_acc[14:0],ins[33] ? 1'b0 : !reference.alu[15]};
            endcase
        end
        expected_sub=(ins[33:32]==1 && !reference.alu[15]);
        expected_mux=&ins[33:32];
        expected_out=ins[15] && !ins[34] ? ins[16] : n[0];
        expected_msb=!ins[35] && !ins[15] ? ram_byte : msb;
        expected_addr=ins[31:30]==2 ? reference.EXT[12:0] : 13'h1234;
        expected_data=!ins[31] ? (ins[30] ? reference.EXT[15:8] : reference.EXT[7:0]) : 8'h6a;
        expected_oe=ins[15] ? n[1] : ins[28];
        expected_we=ins[15] ? n[2] : ins[27];
        expected_write=!ins[29] && !n[2];
        if(ram_we!==expected_write) $fatal(1,"FAIL write apply vector=%0d",n);
        tick;
        if(uut.pc!==expected_pc || uut.ret!==expected_ret)
            $fatal(1,"FAIL branch vector=%0d IR=%09h pc=%02h expected=%02h ret=%02h expected=%02h",n,ins,uut.pc,expected_pc,uut.ret,expected_ret);
        for(j=0;j<8;j=j+1)
            if(uut.gpr[j]!==expected_regs[j])
                $fatal(1,"FAIL register vector=%0d reg=%0d",n,j);
        if(uut.acc!==expected_acc || uut.div_sub!==expected_sub || uut.div_mux!==expected_mux)
            $fatal(1,"FAIL accumulator/division vector=%0d",n);
        if(out0!==expected_out || uut.ram_msb!==expected_msb ||
           ram_addr!==expected_addr || ram_din!==expected_data ||
           uut.oe_n!==expected_oe || uut.we_n!==expected_we)
            $fatal(1,"FAIL external/output/latch vector=%0d",n);
    end
    release uut.ir;
    start=0; tick;
    if(out0!==1 || ram_we!==0 || ram_oe!==0) $fatal(1,"FAIL stop behavior");
    $display("PASS: 65536 silicon-reference ISA vectors, loader and stop controls");
    $finish;
end
initial begin #2000000; $fatal(1,"FAIL timeout"); end
endmodule
