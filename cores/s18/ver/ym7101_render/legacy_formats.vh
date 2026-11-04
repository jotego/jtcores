// Optional PASSIVE=0 historical-format fixture selected by legacy_formats.
reg legacy_format_capture_en = 0;
reg legacy_format_compare_en = 0;
reg legacy_format_capture_done = 0;
reg legacy_format_epoch_active = 0;
reg legacy_format_frame_armed = 0;
reg legacy_format_seen_de_v_low = 0;
reg legacy_format_prev_de_v = 0;
reg legacy_format_prev_de_h = 0;
reg legacy_format_row_active = 0;
integer legacy_format_kind = 0; // 1=Mode5 H32, 2=Mode4
reg [8:0] legacy_format_last_h = 9'h1ff;
reg [8:0] legacy_format_event_last_h = 9'h1ff;
reg legacy_format_h32_started = 0;
integer legacy_format_line_events = 0;
integer legacy_format_active_events = 0;
integer legacy_format_first_de_h = -1;
integer legacy_format_last_de_h = -1;
integer legacy_format_active_rows = 0;
integer legacy_format_row_id = -1;
integer legacy_format_capture_first_h = -1;
integer legacy_format_capture_expected_first_h = -1;
integer legacy_format_capture_expected_last_h = -1;
integer legacy_format_capture_frames = 0;
integer legacy_format_mode5_lines = 0;
integer legacy_format_mode4_lines = 0;
integer legacy_format_required_rows = 224;
integer legacy_format_h32_lines = 0;
integer legacy_format_current_nonzero = 0;
integer legacy_format_legacy_nonzero = 0;
integer legacy_format_current_changes = 0;
integer legacy_format_legacy_changes = 0;
integer legacy_format_total_cur_nonzero = 0;
integer legacy_format_total_ref_nonzero = 0;
integer legacy_format_total_cur_changes = 0;
integer legacy_format_total_ref_changes = 0;
reg [24:0] legacy_format_cur_row [0:255];
reg [24:0] legacy_format_ref_row [0:255];
reg [24:0] legacy_format_prev_cur = 0;
reg [24:0] legacy_format_prev_ref = 0;
integer legacy_format_x;
integer legacy_format_compare_count = 0;

// Unlike the ordinary task-local comparator, this continuously checks the
// whole 94-bit output tuple at every 96 MHz MCLK edge, including CPU setup.
always @(posedge clk) begin
    #1;
    if (legacy_format_compare_en) begin
        legacy_format_compare_count = legacy_format_compare_count + 1;
        if (ym_outputs !== ym_outputs_legacy ||
            {ym_vram_ad_o,ym_vram_ad_d,ym_vram_sd_o,ym_vram_sd_d} !==
            {ym_vram_ad_o_legacy,ym_vram_ad_d_legacy,ym_vram_sd_o_legacy,ym_vram_sd_d_legacy}) begin
            $display("FAIL: legacy-format MCLK aggregate mismatch cycle=%0d mode=%0d current=%h reference=%h",
                legacy_format_compare_count,legacy_format_kind,ym_outputs,ym_outputs_legacy);
            $fatal(1);
        end
    end
end

always @(posedge clk) begin
    #1;
    if (legacy_format_capture_en) begin
        // Arm only after the current vertical-active interval ends. The next
        // DE_V rise is row zero of one complete measured image epoch.
        if (!ym_de_v) begin
            legacy_format_seen_de_v_low=1;
            legacy_format_frame_armed=1;
        end
        if (legacy_format_frame_armed && legacy_format_seen_de_v_low &&
            ym_de_v && !legacy_format_prev_de_v) begin
            legacy_format_epoch_active=1;
            legacy_format_frame_armed=0;
            legacy_format_seen_de_v_low=0;
            legacy_format_active_rows=0;
            legacy_format_row_id=0;
            legacy_format_capture_frames++;
            $display("LEGACY_FORMAT_EPOCH_START mode=%0d epoch=%0d",legacy_format_kind,legacy_format_capture_frames);
        end

        if (legacy_format_epoch_active && ym_de_v && ym_de_h && !legacy_format_prev_de_h) begin
            if (legacy_format_row_active || legacy_format_row_id>=legacy_format_required_rows ||
                legacy_format_row_id!=legacy_format_active_rows) begin
                $display("FAIL: duplicate/gapped/extra visible row start mode=%0d row=%0d completed=%0d",
                    legacy_format_kind,legacy_format_row_id,legacy_format_active_rows);
                $fatal(1);
            end
            legacy_format_row_active=1;
            legacy_format_active_events=0;
            legacy_format_current_nonzero=0;
            legacy_format_legacy_nonzero=0;
            legacy_format_current_changes=0;
            legacy_format_legacy_changes=0;
            legacy_format_first_de_h=-1;
            legacy_format_last_de_h=-1;
            legacy_format_last_h=9'h1ff;
            legacy_format_prev_cur=0;
            legacy_format_prev_ref=0;
        end

        if (legacy_format_epoch_active && legacy_format_row_active && ym_de_h && ym_de_v &&
            uut_ym.l106 !== legacy_format_last_h) begin
            if (legacy_format_active_events >= 256) begin
                $display("FAIL: format produced more than 256 active events in row %0d",legacy_format_row_id);
                $fatal(1);
            end
            if (uut_ym.l106 !== uut_ym_legacy.l106) begin
                $display("FAIL: H-counter mismatch during row capture row=%0d candidate=%0d reference=%0d",
                    legacy_format_row_id,uut_ym.l106,uut_ym_legacy.l106);
                $fatal(1);
            end
            legacy_format_x=legacy_format_active_events;
            if (legacy_format_active_events==0) begin
                legacy_format_first_de_h={23'd0,uut_ym.l106};
                legacy_format_capture_first_h={23'd0,uut_ym.l106};
            end else if (uut_ym.l106 !== legacy_format_last_h+9'd1) begin
                $display("FAIL: noncontiguous active H sequence row=%0d x=%0d previous=%0d current=%0d",
                    legacy_format_row_id,legacy_format_x,legacy_format_last_h,uut_ym.l106);
                $fatal(1);
            end
            legacy_format_last_de_h={23'd0,uut_ym.l106};
            legacy_format_cur_row[legacy_format_x]={ym_ys,ym_r,ym_g,ym_b};
            legacy_format_ref_row[legacy_format_x]={ym_ys_legacy,ym_r_legacy,ym_g_legacy,ym_b_legacy};
            if ({ym_r,ym_g,ym_b}!=24'h000000) legacy_format_current_nonzero++;
            if ({ym_r_legacy,ym_g_legacy,ym_b_legacy}!=24'h000000) legacy_format_legacy_nonzero++;
            if (legacy_format_x>0 && legacy_format_cur_row[legacy_format_x]!=legacy_format_prev_cur)
                legacy_format_current_changes++;
            if (legacy_format_x>0 && legacy_format_ref_row[legacy_format_x]!=legacy_format_prev_ref)
                legacy_format_legacy_changes++;
            legacy_format_prev_cur=legacy_format_cur_row[legacy_format_x];
            legacy_format_prev_ref=legacy_format_ref_row[legacy_format_x];
            legacy_format_active_events++;
            legacy_format_last_h=uut_ym.l106;
        end

        if (legacy_format_epoch_active && legacy_format_row_active && legacy_format_prev_de_h &&
            !(ym_de_h && ym_de_v)) begin
            if (legacy_format_active_events!=256) begin
                $display("FAIL: incomplete row=%0d pixels=%0d expected=256",legacy_format_row_id,legacy_format_active_events);
                $fatal(1);
            end
            if (legacy_format_capture_expected_first_h<0) begin
                legacy_format_capture_expected_first_h=legacy_format_first_de_h;
                legacy_format_capture_expected_last_h=legacy_format_last_de_h;
            end else if (legacy_format_first_de_h!=legacy_format_capture_expected_first_h ||
                         legacy_format_last_de_h!=legacy_format_capture_expected_last_h) begin
                $display("FAIL: DE H range changed row=%0d current=%0d..%0d expected=%0d..%0d",
                    legacy_format_row_id,legacy_format_first_de_h,legacy_format_last_de_h,
                    legacy_format_capture_expected_first_h,legacy_format_capture_expected_last_h);
                $fatal(1);
            end
            for (legacy_format_x=0;legacy_format_x<256;legacy_format_x=legacy_format_x+1) begin
                if (legacy_format_cur_row[legacy_format_x] !== legacy_format_ref_row[legacy_format_x]) begin
                    $display("FAIL: row tuple differs mode=%0d row=%0d X=%0d current=%07x reference=%07x",
                        legacy_format_kind,legacy_format_row_id,legacy_format_x,
                        legacy_format_cur_row[legacy_format_x],legacy_format_ref_row[legacy_format_x]);
                    $fatal(1);
                end
            end
            if (legacy_format_kind==1 && legacy_format_row_id==0) begin
                if ({legacy_format_cur_row[0][23:16],legacy_format_cur_row[0][15:8],legacy_format_cur_row[0][7:0]} !== 24'hce31ff ||
                    {legacy_format_ref_row[0][23:16],legacy_format_ref_row[0][15:8],legacy_format_ref_row[0][7:0]} !== 24'hce31ff) begin
                    $display("FAIL: expected active H32 sprite pixel at row0/x0 to be ce31ff; current=%06x reference=%06x",
                        legacy_format_cur_row[0][23:0],legacy_format_ref_row[0][23:0]);
                    $fatal(1);
                end
            end
            legacy_format_total_cur_nonzero+=legacy_format_current_nonzero;
            legacy_format_total_ref_nonzero+=legacy_format_legacy_nonzero;
            legacy_format_total_cur_changes+=legacy_format_current_changes;
            legacy_format_total_ref_changes+=legacy_format_legacy_changes;
            $display("LEGACY_FORMAT_ROW mode=%0d row=%0d pixels=256 cur_nonzero=%0d ref_nonzero=%0d changes=%0d/%0d H=%0d..%0d",
                legacy_format_kind,legacy_format_row_id,legacy_format_current_nonzero,legacy_format_legacy_nonzero,
                legacy_format_current_changes,legacy_format_legacy_changes,legacy_format_first_de_h,legacy_format_last_de_h);
            legacy_format_active_rows++;
            legacy_format_row_id++;
            legacy_format_row_active=0;
        end

        if (legacy_format_epoch_active && legacy_format_prev_de_v && !ym_de_v) begin
            if (legacy_format_row_active || legacy_format_active_rows!=legacy_format_required_rows) begin
                $display("FAIL: incomplete vertical epoch mode=%0d rows=%0d expected=%0d row_active=%b",
                    legacy_format_kind,legacy_format_active_rows,legacy_format_required_rows,legacy_format_row_active);
                $fatal(1);
            end
            if (legacy_format_h32_lines==0) begin
                $display("FAIL: no complete 342-event line was checked for mode=%0d",
                    legacy_format_kind);
                $fatal(1);
            end
            if (legacy_format_total_cur_nonzero==0 || legacy_format_total_ref_nonzero==0 ||
                legacy_format_total_cur_changes<4 || legacy_format_total_ref_changes<4) begin
                $display("FAIL: visible format image is black or constant mode=%0d",legacy_format_kind);
                $fatal(1);
            end
            legacy_format_epoch_active=0;
            legacy_format_capture_en=0;
            legacy_format_capture_done=1;
            $display("LEGACY_FORMAT_EPOCH_DONE mode=%0d rows=%0d complete342Lines=%0d DE_H=%0d..%0d",
                legacy_format_kind,legacy_format_active_rows,legacy_format_h32_lines,
                legacy_format_capture_expected_first_h,legacy_format_capture_expected_last_h);
        end

        if (uut_ym.l106 !== legacy_format_event_last_h) begin
            if (uut_ym.l106==0) begin
                if (legacy_format_h32_started && legacy_format_event_last_h>300) begin
                    legacy_format_h32_lines++;
                    if (legacy_format_line_events!=342) begin
                        $display("FAIL: H32 native line traversal had %0d events, expected342",legacy_format_line_events);
                        $fatal(1);
                    end
                end
                legacy_format_h32_started=1;
                legacy_format_line_events=1;
            end else legacy_format_line_events++;
            legacy_format_event_last_h=uut_ym.l106;
        end
    end
    legacy_format_prev_de_v=ym_de_v;
    legacy_format_prev_de_h=ym_de_h && ym_de_v;
end

task legacy_format_set_byte;
    input [15:0] cpu_address;
    input [7:0] value;
    reg [15:0] physical;
    begin
        physical=physical_addr(cpu_address);
        ym_vram.mem[physical]=value;
        ym_vram_legacy.mem[physical]=value;
    end
endtask

task legacy_format_set_word;
    input [15:0] cpu_address;
    input [15:0] value;
    begin
        legacy_format_set_byte(cpu_address,value[7:0]);
        legacy_format_set_byte(cpu_address+1,value[15:8]);
    end
endtask

function [15:0] legacy_format_mode4_addr;
    input [15:0] cpu_address;
    begin legacy_format_mode4_addr={cpu_address[8:1],cpu_address[15:9],cpu_address[0]}; end
endfunction

task legacy_format_mode4_set_byte;
    input [15:0] cpu_address;
    input [7:0] value;
    reg [15:0] physical;
    begin
        physical=legacy_format_mode4_addr(cpu_address);
        ym_vram.mem[physical]=value;
        ym_vram_legacy.mem[physical]=value;
    end
endtask

task legacy_format_mode4_set_word;
    input [15:0] cpu_address;
    input [15:0] value;
    begin
        legacy_format_mode4_set_byte(cpu_address,value[7:0]);
        legacy_format_mode4_set_byte(cpu_address+1,value[15:8]);
    end
endtask

task legacy_format_register;
    input [7:0] index;
    input [7:0] value;
    begin
        cpu_write(23'h600002,{(8'h80|index),value});
        $display("LEGACY_FORMAT_REG mode=%0d R%0d=%02x",legacy_format_kind,index,value);
    end
endtask

task legacy_format_clear_memories;
    integer i;
    begin
        for(i=0;i<65536;i=i+1) begin
            ym_vram.mem[i]=0;
            ym_vram_legacy.mem[i]=0;
        end
        for(i=0;i<64;i=i+1) begin
            uut_ym.color_ram[i]=0;
            uut_ym_legacy.color_ram[i]=0;
        end
        for(i=0;i<40;i=i+1) begin
            uut_ym.vsram[i]=0;
            uut_ym_legacy.vsram[i]=0;
        end
    end
endtask

task legacy_format_wait_rows;
    integer timeout;
    begin
        legacy_format_capture_done=0;
        legacy_format_required_rows=(legacy_format_kind==1) ? 224 : 192;
        legacy_format_epoch_active=0;
        legacy_format_frame_armed=0;
        legacy_format_seen_de_v_low=0;
        legacy_format_prev_de_v=ym_de_v;
        legacy_format_prev_de_h=ym_de_h && ym_de_v;
        legacy_format_row_active=0;
        legacy_format_active_rows=0;
        legacy_format_row_id=-1;
        legacy_format_active_events=0;
        legacy_format_h32_started=0;
        legacy_format_line_events=0;
        legacy_format_h32_lines=0;
        legacy_format_first_de_h=-1;
        legacy_format_last_de_h=-1;
        legacy_format_capture_expected_first_h=-1;
        legacy_format_capture_expected_last_h=-1;
        legacy_format_capture_frames=0;
        legacy_format_capture_en=1;
        timeout=0;
        while(!legacy_format_capture_done && timeout<4000000) begin
            tick();
            timeout++;
        end
        legacy_format_capture_en=0;
        if(!legacy_format_capture_done) begin
            $display("FAIL: mode %0d timed out waiting for one complete active epoch; rows=%0d epoch=%b H/V=%0d/%0d",
                legacy_format_kind,legacy_format_active_rows,legacy_format_epoch_active,uut_ym.l106,uut_ym.l105);
            $fatal(1);
        end
        if(legacy_format_capture_frames!=1 || legacy_format_active_rows!=legacy_format_required_rows) begin
            $display("FAIL: mode %0d captured %0d epochs/%0d rows, expected exactly one/%0d",
                legacy_format_kind,legacy_format_capture_frames,legacy_format_active_rows,legacy_format_required_rows);
            $fatal(1);
        end
        if(legacy_format_kind==1) legacy_format_mode5_lines=legacy_format_h32_lines;
        else legacy_format_mode4_lines=legacy_format_h32_lines;
    end
endtask

initial begin : legacy_formats_test
    integer i, j, row, wait_count;
    reg [15:0] status_word;
    reg [7:0] pattern_byte;
    reg [15:0] name_word;
    repeat(8) @(negedge clk);
    reset_n=1;
    repeat(80) tick();
    use48=0;
    compare_en=1;
    legacy_format_compare_en=1;
    legacy_format_total_cur_nonzero=0;
    legacy_format_total_ref_nonzero=0;
    legacy_format_total_cur_changes=0;
    legacy_format_total_ref_changes=0;

    // Prove CPU register/status service before graphics setup at M5 clear.
    legacy_format_kind=1;
    cpu_read(23'h600002,status_word);
    if ((^status_word)===1'bx) begin $display("FAIL: pre-program status is unknown"); $fatal(1); end

    // Mode5 H32: preserve the proven legacy PatternA nibble pattern but place
    // the A table in the H32 C000 base, with varied palette/H-flip names.
    legacy_format_clear_memories();
    for(i=0;i<32;i=i+1) begin
        case(i%8)
            0: pattern_byte=8'h12; 1: pattern_byte=8'h34; 2: pattern_byte=8'h56; 3: pattern_byte=8'h78;
            4: pattern_byte=8'h87; 5: pattern_byte=8'h65; 6: pattern_byte=8'h43; default: pattern_byte=8'h21;
        endcase
        // Existing PatternA data proves this serial nibble order; use tile 2.
        legacy_format_set_byte(16'h0040+i[15:0],pattern_byte);
        pattern_byte=(i[0] ? 8'hf0 : 8'h0f) ^ {3'b000,i[4:0]};
        legacy_format_set_byte(16'h0060+i[15:0],pattern_byte);
    end
    for(i=0;i<1024;i=i+1) begin
        name_word=16'h4002 | ((i%4)==1 ? 16'h0800 : 16'h0000) | ((i%8)==2 ? 16'h2000 : 16'h0000);
        legacy_format_set_word(16'hc000+(i[15:0]<<1),name_word);
    end
    if ({ym_vram.mem[physical_addr(16'hc000)],ym_vram.mem[physical_addr(16'hc001)],
         ym_vram.mem[physical_addr(16'h0040)],ym_vram.mem[physical_addr(16'h0041)],
         ym_vram.mem[physical_addr(16'h0060)],ym_vram.mem[physical_addr(16'h0061)]} !==
        {8'h02,8'h40,8'h12,8'h34,8'h0f,8'hf1} ||
        {ym_vram_legacy.mem[physical_addr(16'hc000)],ym_vram_legacy.mem[physical_addr(16'hc001)],
         ym_vram_legacy.mem[physical_addr(16'h0040)],ym_vram_legacy.mem[physical_addr(16'h0041)],
         ym_vram_legacy.mem[physical_addr(16'h0060)],ym_vram_legacy.mem[physical_addr(16'h0061)]} !==
        {8'h02,8'h40,8'h12,8'h34,8'h0f,8'hf1}) begin
        $display("FAIL: H32 PatternA/A-table/tile3 initializer sentinels are wrong"); $fatal(1);
    end
    uut_ym.color_ram[0]=9'h000; uut_ym_legacy.color_ram[0]=9'h000;
    for(i=1;i<64;i=i+1) begin
        uut_ym.color_ram[i]={i[2:0],i[5:3],(i[2:0]^i[5:3])};
        uut_ym_legacy.color_ram[i]=uut_ym.color_ram[i];
    end
    // CRAM[33] is {i[2:0],i[5:3],i[2:0]^i[5:3]} for i=6'b100001,
    // which evaluates to {001,100,101}=9'h065.
    if (uut_ym.color_ram[6'h0f]!==9'h1ce || uut_ym_legacy.color_ram[6'h0f]!==9'h1ce ||
        uut_ym.color_ram[6'h21]!==9'h065 || uut_ym_legacy.color_ram[6'h21]!==9'h065 ||
        uut_ym.color_ram[6'h0f]===uut_ym.color_ram[6'h21]) begin
        $display("FAIL: normal-color H32 sprite/background palette sentinels are not distinct"); $fatal(1);
    end
    legacy_format_register(0,8'h04); // LCB clear, normal color, M3 clear
    legacy_format_register(2,8'h30); // H32 Plane A base C000
    legacy_format_register(4,8'h00); // Plane B points at zero-filled tile/name area
    legacy_format_register(5,8'h7e); // SAT base FC00
    legacy_format_register(7,8'h00);
    legacy_format_register(8,8'h00);
    legacy_format_register(9,8'h00);
    legacy_format_register(11,8'h00);
    legacy_format_register(12,8'h00); // H32/native internal clock selection
    legacy_format_register(13,8'h00); // H-scroll table is kept away from SAT
    legacy_format_register(16,8'h00); // 32x32 planes
    legacy_format_register(1,8'h44); // Mode5 + display on
    wait_count=0;
    while((uut_ym.reg_m5!==1 || uut_ym.reg_disp!==1 || uut_ym_legacy.reg_m5!==1 || uut_ym_legacy.reg_disp!==1) && wait_count<4096) begin tick(); wait_count++; end
    if(wait_count>=4096 ||
       {uut_ym.reg_80_b7,uut_ym.reg_80_b6,uut_ym.reg_lcb,uut_ym.reg_ie1,uut_ym.reg_80_b3,uut_ym.reg_80_b2,uut_ym.reg_m3,uut_ym.reg_80_b0}!==8'h04 ||
       {uut_ym_legacy.reg_80_b7,uut_ym_legacy.reg_80_b6,uut_ym_legacy.reg_lcb,uut_ym_legacy.reg_ie1,uut_ym_legacy.reg_80_b3,uut_ym_legacy.reg_80_b2,uut_ym_legacy.reg_m3,uut_ym_legacy.reg_80_b0}!==8'h04 ||
       {uut_ym.reg_81_b7,uut_ym.reg_disp,uut_ym.reg_ie0,uut_ym.reg_m1,uut_ym.reg_m2,uut_ym.reg_m5,uut_ym.reg_81_b1,uut_ym.reg_81_b0}!==8'h44 ||
       {uut_ym_legacy.reg_81_b7,uut_ym_legacy.reg_disp,uut_ym_legacy.reg_ie0,uut_ym_legacy.reg_m1,uut_ym_legacy.reg_m2,uut_ym_legacy.reg_m5,uut_ym_legacy.reg_81_b1,uut_ym_legacy.reg_81_b0}!==8'h44 ||
       {uut_ym.reg_rs0,uut_ym.reg_8c_b6,uut_ym.reg_8c_b5,uut_ym.reg_8c_b4,uut_ym.reg_ste,uut_ym.reg_lsm1,uut_ym.reg_lsm0,uut_ym.reg_rs1}!==8'h00 ||
       {uut_ym_legacy.reg_rs0,uut_ym_legacy.reg_8c_b6,uut_ym_legacy.reg_8c_b5,uut_ym_legacy.reg_8c_b4,uut_ym_legacy.reg_ste,uut_ym_legacy.reg_lsm1,uut_ym_legacy.reg_lsm0,uut_ym_legacy.reg_rs1}!==8'h00) begin
        $display("FAIL: Mode5 R0/R1/R12 programming did not retire to 04/44/00"); $fatal(1);
    end
    $display("LEGACY_FORMAT_MODE mode5-h32 R1=%02x R12=%02x M5=%b disp=%b",{uut_ym.reg_81_b7,uut_ym.reg_disp,uut_ym.reg_ie0,uut_ym.reg_m1,uut_ym.reg_m2,uut_ym.reg_m5,uut_ym.reg_81_b1,uut_ym.reg_81_b0},{uut_ym.reg_rs0,uut_ym.reg_8c_b6,uut_ym.reg_8c_b5,uut_ym.reg_8c_b4,uut_ym.reg_ste,uut_ym.reg_lsm1,uut_ym.reg_lsm0,uut_ym.reg_rs1},uut_ym.reg_m5,uut_ym.reg_disp);
    // Legal CPU data-port SAT write: R15 increment2; VRAM write command FC00.
    legacy_format_register(15,8'h02);
    cpu_write(23'h600002,16'h7c00);
    cpu_write(23'h600002,16'h0003);
    cpu_write(23'h600000,16'h0080);
    cpu_write(23'h600000,16'h0000);
    cpu_write(23'h600000,16'h8003);
    cpu_write(23'h600000,16'h0080);
    timeout=0;
    while(timeout<4000000 &&
          ({ym_vram.mem[physical_addr(16'hfc00)],ym_vram.mem[physical_addr(16'hfc01)],
            ym_vram.mem[physical_addr(16'hfc02)],ym_vram.mem[physical_addr(16'hfc03)],
            ym_vram.mem[physical_addr(16'hfc04)],ym_vram.mem[physical_addr(16'hfc05)],
            ym_vram.mem[physical_addr(16'hfc06)],ym_vram.mem[physical_addr(16'hfc07)]} !==
           {8'h80,8'h00,8'h00,8'h00,8'h03,8'h80,8'h80,8'h00} ||
           {ym_vram_legacy.mem[physical_addr(16'hfc00)],ym_vram_legacy.mem[physical_addr(16'hfc01)],
            ym_vram_legacy.mem[physical_addr(16'hfc02)],ym_vram_legacy.mem[physical_addr(16'hfc03)],
            ym_vram_legacy.mem[physical_addr(16'hfc04)],ym_vram_legacy.mem[physical_addr(16'hfc05)],
            ym_vram_legacy.mem[physical_addr(16'hfc06)],ym_vram_legacy.mem[physical_addr(16'hfc07)]} !==
           {8'h80,8'h00,8'h00,8'h00,8'h03,8'h80,8'h80,8'h00} ||
           uut_ym.sat[0]!==21'h040000 || uut_ym_legacy.sat[0]!==21'h040000)) begin
        tick(); timeout++;
    end
    if(timeout>=4000000 ||
       {ym_vram.mem[physical_addr(16'hfc00)],ym_vram.mem[physical_addr(16'hfc01)],
        ym_vram.mem[physical_addr(16'hfc02)],ym_vram.mem[physical_addr(16'hfc03)],
        ym_vram.mem[physical_addr(16'hfc04)],ym_vram.mem[physical_addr(16'hfc05)],
        ym_vram.mem[physical_addr(16'hfc06)],ym_vram.mem[physical_addr(16'hfc07)]} !==
       {8'h80,8'h00,8'h00,8'h00,8'h03,8'h80,8'h80,8'h00} ||
       {ym_vram_legacy.mem[physical_addr(16'hfc00)],ym_vram_legacy.mem[physical_addr(16'hfc01)],
        ym_vram_legacy.mem[physical_addr(16'hfc02)],ym_vram_legacy.mem[physical_addr(16'hfc03)],
        ym_vram_legacy.mem[physical_addr(16'hfc04)],ym_vram_legacy.mem[physical_addr(16'hfc05)],
        ym_vram_legacy.mem[physical_addr(16'hfc06)],ym_vram_legacy.mem[physical_addr(16'hfc07)]} !==
       {8'h80,8'h00,8'h00,8'h00,8'h03,8'h80,8'h80,8'h00} ||
       uut_ym.sat[0]!==21'h040000 || uut_ym_legacy.sat[0]!==21'h040000) begin
        $display("FAIL: CPU SAT descriptor/cache not retired; sat=%06x/%06x wait=%0d",
            uut_ym.sat[0],uut_ym_legacy.sat[0],timeout); $fatal(1);
    end
    $display("LEGACY_FORMAT_SAT physical words=0080,0000,8003,0080 cache=%06x/%06x",uut_ym.sat[0],uut_ym_legacy.sat[0]);
    legacy_format_wait_rows();
    $display("LEGACY_FORMAT_NONBLACK mode5-h32 totals=%0d/%0d changes=%0d/%0d lines342=%0d",legacy_format_total_cur_nonzero,legacy_format_total_ref_nonzero,legacy_format_total_cur_changes,legacy_format_total_ref_changes,legacy_format_mode5_lines);

    // Mode4 setup: four independent bit planes per 8x8 tile, 32-column name
    // row at 3800 and distinct 32-entry palette. No Mode5 nibble data reused.
    legacy_format_kind=2;
    legacy_format_required_rows=192;
    legacy_format_capture_done=0;
    legacy_format_active_rows=0;
    legacy_format_total_cur_nonzero=0;
    legacy_format_total_ref_nonzero=0;
    legacy_format_total_cur_changes=0;
    legacy_format_total_ref_changes=0;
    legacy_format_active_events=0;
    legacy_format_first_de_h=-1;
    legacy_format_last_de_h=-1;
    legacy_format_last_h=9'h1ff;
    legacy_format_event_last_h=uut_ym.l106;
    legacy_format_h32_started=0;
    legacy_format_line_events=0;
    legacy_format_current_nonzero=0;
    legacy_format_legacy_nonzero=0;
    legacy_format_current_changes=0;
    legacy_format_legacy_changes=0;
    legacy_format_register(1,8'h40); // display enabled, M5 clear, 192-line
    cpu_read(23'h600002,status_word);
    legacy_format_clear_memories();
    for(row=0;row<8;row=row+1) begin
        legacy_format_mode4_set_byte(16'h0020+(row[15:0]<<2),8'haa);
        legacy_format_mode4_set_byte(16'h0021+(row[15:0]<<2),8'hcc);
        legacy_format_mode4_set_byte(16'h0022+(row[15:0]<<2),8'hf0);
        legacy_format_mode4_set_byte(16'h0023+(row[15:0]<<2),8'h00);
        legacy_format_mode4_set_byte(16'h0040+(row[15:0]<<2),8'hf0^(row[7:0]*8'h11));
        legacy_format_mode4_set_byte(16'h0041+(row[15:0]<<2),8'h0f^(row[7:0]*8'h03));
        legacy_format_mode4_set_byte(16'h0042+(row[15:0]<<2),8'hcc^(row[7:0]*8'h11));
        legacy_format_mode4_set_byte(16'h0043+(row[15:0]<<2),8'h33^(row[7:0]*8'h0f));
    end
    for(i=0;i<768;i=i+1) begin
        name_word=16'h0001;
        if((i%32)==7) name_word=16'h0a02; // tile2 with Hflip and palette 1
        else if((i%32)>0 && (i%5)==0) name_word=16'h0002;
        legacy_format_mode4_set_word(16'h3800+(i[15:0]<<1),name_word);
    end
    for(i=0;i<32;i=i+1) begin
        uut_ym.color_ram[i]=(i==31) ? 9'h1ff : {1'b0,i[4:3],i[2:0],i[4:3],i[2]};
        uut_ym_legacy.color_ram[i]=uut_ym.color_ram[i];
    end
    for(i=0;i<32;i=i+1) begin
        if ((^uut_ym.color_ram[i])===1'bx || uut_ym.color_ram[i]!==uut_ym_legacy.color_ram[i]) begin
            $display("FAIL: Mode4 CRAM entry %0d is unknown or differs",i); $fatal(1);
        end
        for(j=i+1;j<32;j=j+1) begin
            if (uut_ym.color_ram[i]===uut_ym.color_ram[j]) begin
                $display("FAIL: Mode4 CRAM entries %0d and %0d are not distinct",i,j); $fatal(1);
            end
        end
    end
    legacy_format_mode4_set_byte(16'h3f00,8'hd0); // first SAT entry terminates
    if ({ym_vram.mem[16'h1000],ym_vram.mem[16'h1001],
         ym_vram.mem[16'h1100],ym_vram.mem[16'h1101],
         ym_vram.mem[16'h0038],ym_vram.mem[16'h0039],
         ym_vram.mem[16'h803e],uut_ym.color_ram[6'h1f]} !==
        {8'haa,8'hcc,8'hf0,8'h00,8'h01,8'h00,8'hd0,9'h1ff} ||
        {ym_vram_legacy.mem[16'h1000],ym_vram_legacy.mem[16'h1001],
         ym_vram_legacy.mem[16'h1100],ym_vram_legacy.mem[16'h1101],
         ym_vram_legacy.mem[16'h0038],ym_vram_legacy.mem[16'h0039],
         ym_vram_legacy.mem[16'h803e]} !==
        {8'haa,8'hcc,8'hf0,8'h00,8'h01,8'h00,8'hd0} ||
        uut_ym.color_ram[6'h1f]!==9'h1ff || uut_ym_legacy.color_ram[6'h1f]!==9'h1ff) begin
        $display("FAIL: Mode4 planar/name/SAT initializer sentinels are wrong"); $fatal(1);
    end
    legacy_format_register(0,8'h04); // Mode4 select, M3 clear
    legacy_format_register(2,8'h0e); // 192-line name base 3800
    legacy_format_register(5,8'h7e); // SAT base 3f00
    legacy_format_register(6,8'h00);
    legacy_format_register(7,8'h00);
    legacy_format_register(8,8'h00); // zero horizontal scroll
    legacy_format_register(9,8'h00); // zero vertical scroll
    legacy_format_register(1,8'h40); // display on, M5 clear
    wait_count=0;
    while((uut_ym.reg_m5!==0 || uut_ym.reg_disp!==1 || uut_ym_legacy.reg_m5!==0 || uut_ym_legacy.reg_disp!==1) && wait_count<4096) begin tick(); wait_count++; end
    if(wait_count>=4096 ||
       {uut_ym.reg_80_b7,uut_ym.reg_80_b6,uut_ym.reg_lcb,uut_ym.reg_ie1,uut_ym.reg_80_b3,uut_ym.reg_80_b2,uut_ym.reg_m3,uut_ym.reg_80_b0}!==8'h04 ||
       {uut_ym_legacy.reg_80_b7,uut_ym_legacy.reg_80_b6,uut_ym_legacy.reg_lcb,uut_ym_legacy.reg_ie1,uut_ym_legacy.reg_80_b3,uut_ym_legacy.reg_80_b2,uut_ym_legacy.reg_m3,uut_ym_legacy.reg_80_b0}!==8'h04 ||
       {uut_ym.reg_81_b7,uut_ym.reg_disp,uut_ym.reg_ie0,uut_ym.reg_m1,uut_ym.reg_m2,uut_ym.reg_m5,uut_ym.reg_81_b1,uut_ym.reg_81_b0}!==8'h40 ||
       {uut_ym_legacy.reg_81_b7,uut_ym_legacy.reg_disp,uut_ym_legacy.reg_ie0,uut_ym_legacy.reg_m1,uut_ym_legacy.reg_m2,uut_ym_legacy.reg_m5,uut_ym_legacy.reg_81_b1,uut_ym_legacy.reg_81_b0}!==8'h40 ||
       {uut_ym.reg_rs0,uut_ym.reg_8c_b6,uut_ym.reg_8c_b5,uut_ym.reg_8c_b4,uut_ym.reg_ste,uut_ym.reg_lsm1,uut_ym.reg_lsm0,uut_ym.reg_rs1}!==8'h00 ||
       {uut_ym_legacy.reg_rs0,uut_ym_legacy.reg_8c_b6,uut_ym_legacy.reg_8c_b5,uut_ym_legacy.reg_8c_b4,uut_ym_legacy.reg_ste,uut_ym_legacy.reg_lsm1,uut_ym_legacy.reg_lsm0,uut_ym_legacy.reg_rs1}!==8'h00 ||
       uut_ym.reg_80_b2!==1'b1 || uut_ym_legacy.reg_80_b2!==1'b1) begin
        $display("FAIL: Mode4 R0/R1/R12 programming did not retire to 04/40/00"); $fatal(1);
    end
    $display("LEGACY_FORMAT_MODE mode4 R0=04 R1=40 R2=0e R5=7e M5=%b disp=%b R0_M4bit=%b",
        uut_ym.reg_m5,uut_ym.reg_disp,uut_ym.reg_80_b2);
    cpu_read(23'h600002,status_word);
    if ((^status_word)===1'bx) begin $display("FAIL: post-program M5-clear status is unknown"); $fatal(1); end
    legacy_format_wait_rows();
    $display("LEGACY_FORMAT_NONBLACK mode4 totals=%0d/%0d changes=%0d/%0d lines342=%0d",legacy_format_total_cur_nonzero,legacy_format_total_ref_nonzero,legacy_format_total_cur_changes,legacy_format_total_ref_changes,legacy_format_mode4_lines);
    legacy_format_compare_en=0;
    $display("LEGACY_FORMAT_PASS M5H32 rows=224 M4 rows=192 96MHzMCLKcycles=%0d H32lines=%0d",
        legacy_format_compare_count,legacy_format_mode5_lines+legacy_format_mode4_lines);
    $display("PASS");
    $finish;
end
