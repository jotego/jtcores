//disassembly message
int     pc_z;
int     rst_cyc = 0;
int     tbl_cyc = 0;
string  disasm, num_data;

//NOP, ABS
function void disasm_type0;
    input   string  mnemonic;
    input   [11:0]  pc;
    disasm = "";
    `ifdef IKA32010_DISASSEMBLY_SHOWID
        disasm = {"IKA32010_", `IKA32010_DEVICE_ID, ": "};
    `endif
    $sformat(num_data, " PC=0x%3h |", {pc-1}[11:0]);
    disasm = {disasm, num_data};
    disasm = {disasm, " ", mnemonic};
    disasm = {disasm, "\n"};
    if(pc_z != pc) $display(disasm);
    pc_z = pc;
endfunction

//ADD, LAC, SUB...
function void disasm_type1;
    input   string  mnemonic;
    input   [15:0]  opcodereg;
    input   [11:0]  pc;
    input           shb;
    disasm = "";
    `ifdef IKA32010_DISASSEMBLY_SHOWID
        disasm = {"IKA32010_", `IKA32010_DEVICE_ID, ": "};
    `endif
    $sformat(num_data, " PC=0x%h |", {pc-1}[11:0]);
    disasm = {disasm, num_data};
    disasm = {disasm, " ", mnemonic};
    if(!opcodereg[7]) begin
        $sformat(num_data, " DAT0x%h, %d", opcodereg[6:0], opcodereg[11:8]);
        disasm = {disasm, num_data};
    end
    else begin
             if(opcodereg[5:4] == 2'b00) disasm = {disasm, " *"}; //inc/dec
        else if(opcodereg[5:4] == 2'b01) disasm = {disasm, " *-"};
        else if(opcodereg[5:4] == 2'b10) disasm = {disasm, " *+"};
        if(shb == 1'b0) $sformat(num_data, ", %d", opcodereg[11:8]);
        else $sformat(num_data, ", %d", opcodereg[10:8]);
        disasm = {disasm, num_data};
        if(!opcodereg[3]) begin
            num_data = "";
            $sformat(num_data, ", %b", opcodereg[0]);
            disasm = {disasm, num_data};
        end
    end
    disasm = {disasm, "\n"};
    if(pc_z != pc) $display(disasm);
    pc_z = pc;
endfunction

//ADDH, AND, OR...
function void disasm_type2;
    input   string  mnemonic;
    input   [15:0]  opcodereg;
    input   [11:0]  pc;
    input           aux;
    input           tbl;
    disasm = "";
    `ifdef IKA32010_DISASSEMBLY_SHOWID
        disasm = {"IKA32010_", `IKA32010_DEVICE_ID, ": "};
    `endif
    $sformat(num_data, " PC=0x%h |", {pc-1}[11:0]);
    disasm = {disasm, num_data};
    disasm = {disasm, " ", mnemonic};
    if(aux) begin
        $sformat(num_data, " AR%b,", opcodereg[8]);
        disasm = {disasm, num_data};
    end
    if(!opcodereg[7]) begin
        $sformat(num_data, " DAT0x%h", opcodereg[6:0]);
        disasm = {disasm, num_data};
    end
    else begin
             if(opcodereg[5:4] == 2'b00) disasm = {disasm, " *"}; //inc/dec
        else if(opcodereg[5:4] == 2'b01) disasm = {disasm, " *-"};
        else if(opcodereg[5:4] == 2'b10) disasm = {disasm, " *+"};
        if(!opcodereg[3]) begin
            num_data = "";
            $sformat(num_data, ", %b", opcodereg[0]);
            disasm = {disasm, num_data};
        end
    end
    disasm = {disasm, "\n"};
    if(pc_z != pc) begin 
        if(tbl == 0) $display(disasm);
        else begin
            if(tbl_cyc > 2) tbl_cyc = 0;
            if(tbl_cyc == 0) $display(disasm);
            tbl_cyc = tbl_cyc + 1;
        end
    end
    pc_z = pc;
endfunction

//LACK
function void disasm_type3;
    input   string  mnemonic;
    input   [15:0]  opcodereg;
    input   [11:0]  pc;
    input           aux;
    input           mul;
    disasm = "";
    `ifdef IKA32010_DISASSEMBLY_SHOWID
        disasm = {"IKA32010_", `IKA32010_DEVICE_ID, ": "};
    `endif
    $sformat(num_data, " PC=0x%h |", {pc-1}[11:0]);
    disasm = {disasm, num_data};
    disasm = {disasm, " ", mnemonic};
    if(aux) begin
        $sformat(num_data, " AR%b,", opcodereg[8]);
        disasm = {disasm, num_data};
    end
    if(mul == 0) $sformat(num_data, " 0x%h", opcodereg[7:0]);
    else         $sformat(num_data, " 0x%d", signed'(opcodereg[12:0]));
    disasm = {disasm, num_data};
    disasm = {disasm, "\n"};
    if(pc_z != pc) $display(disasm);
    pc_z = pc;
endfunction

//B
function void disasm_type4;
    input   string  mnemonic;
    input   [11:0]  pc;
    input   [1:0]   cycle;
    input   [15:0]  branch;
    input           ret;
    if(cycle == 2'd0) begin
        disasm = "";
        `ifdef IKA32010_DISASSEMBLY_SHOWID
            disasm = {"IKA32010_", `IKA32010_DEVICE_ID, ": "};
        `endif
        $sformat(num_data, " PC=0x%h |", {pc-1}[11:0]);
        disasm = {disasm, num_data};
        disasm = {disasm, " ", mnemonic};
    end
    else if(cycle == 2'd1) begin
        if(ret == 1'b0) begin
            $sformat(num_data, " 0x%h", branch[11:0]);
            disasm = {disasm, num_data};
            disasm = {disasm, "\n"};
            if(pc_z != pc) $display(disasm);
            pc_z = pc;
        end
        else begin
            disasm = {disasm, "\n"};
            if(pc_z != pc) $display(disasm);
            pc_z = pc;
        end
    end
endfunction

//LARP, LDPK
function void disasm_type5;
    input   string  mnemonic;
    input   [15:0]  opcodereg;
    input   [11:0]  pc;
    disasm = "";
    `ifdef IKA32010_DISASSEMBLY_SHOWID
        disasm = {"IKA32010_", `IKA32010_DEVICE_ID, ": "};
    `endif
    $sformat(num_data, " PC=0x%h |", {pc-1}[11:0]);
    disasm = {disasm, num_data};
    disasm = {disasm, " ", mnemonic};
    $sformat(num_data, " 0x%b", opcodereg[0]);
    disasm = {disasm, num_data};
    disasm = {disasm, "\n"};
    if(pc_z != pc) $display(disasm);
    pc_z = pc;
endfunction

function void disasm_type6;
    input   string  mnemonic;
    input   [15:0]  opcodereg;
    input   [11:0]  pc;
    disasm = "";
    `ifdef IKA32010_DISASSEMBLY_SHOWID
        disasm = {"IKA32010_", `IKA32010_DEVICE_ID, ": "};
    `endif
    $sformat(num_data, " PC=0x%h |", {pc-1}[11:0]);
    disasm = {disasm, num_data};
    disasm = {disasm, " ", mnemonic};
    if(!opcodereg[7]) begin
        $sformat(num_data, " DAT0x%h", opcodereg[6:0]);
        disasm = {disasm, num_data};
        $sformat(num_data, ", PA%d", opcodereg[10:8]);
        disasm = {disasm, num_data};
    end
    else begin
             if(opcodereg[5:4] == 2'b00) disasm = {disasm, " *"}; //inc/dec
        else if(opcodereg[5:4] == 2'b01) disasm = {disasm, " *-"};
        else if(opcodereg[5:4] == 2'b10) disasm = {disasm, " *+"};
        $sformat(num_data, ", PA%d", opcodereg[10:8]);
        disasm = {disasm, num_data};
        if(!opcodereg[3]) begin
            num_data = "";
            $sformat(num_data, ", %b", opcodereg[0]);
            disasm = {disasm, num_data};
        end
    end
    disasm = {disasm, "\n"};
    if(pc_z != pc) $display(disasm);
    pc_z = pc;
endfunction