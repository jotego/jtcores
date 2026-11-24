// Opt-in nonzero graphics feature profile. Expected pixels come from these
// semantic source descriptors, never from YM fetch/cell state.
localparam FEATURE_ROWS = 11;
integer feature_row_y[0:10];
reg [24:0] feature_current[0:10][0:319];
reg [24:0] feature_legacy[0:10][0:319];
integer feature_row_count[0:10], feature_row_last[0:10];
reg [3:0] feature_pixels[0:15][0:7][0:7];
reg [15:0] feature_names_a[0:2047], feature_names_b[0:2047], feature_names_w[0:2047];
reg [15:0] feature_sat_words[0:7];
reg [8:0] feature_cram[0:63];
reg [10:0] feature_vsram[0:39];
reg [15:0] feature_hscroll[0:511];
reg feature_capture=0, feature_done=0, feature_line_variant=0;
reg feature_legacy_armed=0, feature_legacy_started=0, feature_legacy_done=0;
reg feature_legacy_row_active=0;
integer feature_legacy_row_latched=-1, feature_legacy_prev_h=-1, feature_legacy_native_frames=0;
integer feature_target_frame=0, feature_total_samples=0, feature_legacy_total=0;
integer feature_legacy_count[0:10], feature_legacy_last[0:10];
integer feature_sprite_visible=0, feature_window_visible=0, feature_a_visible=0, feature_b_visible=0;
integer feature_palette_mask=0, feature_top_sprite=0, feature_bottom_sprite=0;
integer feature_csv_fd=0;
reg feature_candidate_state_guarded=0, feature_legacy_state_guarded=0;
integer feature_capture_state_failures=0;
time feature_setup_time=0, feature_capture_start_time=0;
integer feature_hs_candidate_events=0, feature_hs_legacy_events=0;
reg [3:0] feature_hs_candidate_load_prev=0, feature_hs_legacy_load_prev=0;
reg [1:0] feature_hs_candidate_select_prev=0, feature_hs_legacy_select_prev=0;
reg feature_scroll_trace_candidate_started=0, feature_scroll_trace_candidate_done=0;
reg feature_scroll_trace_legacy_started=0, feature_scroll_trace_legacy_done=0;
integer feature_scroll_trace_candidate_samples=0, feature_scroll_trace_legacy_samples=0;
integer feature_scroll_trace_candidate_pages=0, feature_scroll_trace_legacy_pages=0;
integer feature_scroll_trace_candidate_sc=0, feature_scroll_trace_legacy_sc=0;
integer feature_scroll_trace_candidate_w570=0, feature_scroll_trace_candidate_w571=0;
integer feature_scroll_trace_candidate_w572=0, feature_scroll_trace_candidate_w573=0;
integer feature_scroll_trace_legacy_w570=0, feature_scroll_trace_legacy_w571=0;
integer feature_scroll_trace_legacy_w572=0, feature_scroll_trace_legacy_w573=0;
reg feature_scroll_trace_candidate_overflow=0, feature_scroll_trace_legacy_overflow=0;

function [8:0] feature_cram_code;
    input integer slot;
    begin
        case(slot & 7)
            0: feature_cram_code=9'h007;
            1: feature_cram_code=9'h038;
            2: feature_cram_code=9'h1c0;
            3: feature_cram_code=9'h1c7;
            4: feature_cram_code=9'h0e0;
            5: feature_cram_code=9'h00e;
            6: feature_cram_code=9'h070;
            default: feature_cram_code=9'h1c8;
        endcase
    end
endfunction

function [23:0] feature_rgb_code;
    input integer slot;
    begin
        case(slot & 7)
            0: feature_rgb_code=24'hff0000; // CRAM 007
            1: feature_rgb_code=24'h00ff00; // CRAM 038
            2: feature_rgb_code=24'h0000ff; // CRAM 1c0
            3: feature_rgb_code=24'hff00ff; // CRAM 1c7
            4: feature_rgb_code=24'h008e72; // CRAM 0e0
            5: feature_rgb_code=24'hce3100; // CRAM 00e, independently observed in native VDP row
            6: feature_rgb_code=24'h00ce31; // CRAM 070
            default: feature_rgb_code=24'h0031ff; // CRAM 1c8
        endcase
    end
endfunction

function [3:0] feature_nibble;
    input integer tile;
    input integer x;
    input integer y;
    integer t;
    begin
        t=0;
        case(tile)
            1,4: begin
                if (((x+y+tile)&3)!=0) t=1+((x+2*y+tile)&3)%3;
            end
            2,5: t=4+((2*x+y+tile)&3)%3;
            3: t=7+((x+y)&3)%3;
            8,9,10,11: begin
                if (x!=0 && x!=7 && ((x+y)&3)!=0) t=10+((x+2*y+tile)&3)%3;
            end
            default: t=0;
        endcase
        feature_nibble=t[3:0];
    end
endfunction

function [15:0] feature_name_word;
    input integer layer;
    input integer row;
    input integer col;
    integer tile_id, palette, hflip, vflip, pri;
    begin
        tile_id=0; palette=0; hflip=0; vflip=0; pri=0;
        case(layer)
            0: begin
                tile_id=((row+col)&1) ? 4 : 1;
                hflip=(row==1 && col==3) || (row==2 && col==6);
                vflip=(row==1 && col==5);
            end
            1: begin
                tile_id=((row+col)&1) ? 5 : 2;
                palette=1;
                hflip=(row==2 && col==4);
            end
            default: begin
                tile_id=3;
                palette=2;
                pri=1;
            end
        endcase
        feature_name_word={pri[0],palette[1:0],vflip[0],hflip[0],tile_id[10:0]};
    end
endfunction

function [24:0] feature_expected_pixel;
    input integer x;
    input integer y;
    input integer line_variant;
    integer layer, sx, sy, col, row, index, word, tile, tx, ty, palette, nib;
    integer sprite, sprx, spry, dx, dy, width, height, attr, linkword;
    integer hscroll, vscroll, pal_slot;
    reg [23:0] rgb;
    reg opaque;
    begin
        layer=0; sx=0; sy=0; col=0; row=0; index=0; word=0; tile=0; tx=0; ty=0; palette=0; nib=0;
        rgb=24'd0; opaque=0; sprite=-1; sprx=0; spry=0; dx=0; dy=0; width=1; height=2; attr=0; linkword=0;
        // Horizontal window starts at physical x160; the selected vertical
        // window lines span the full width, matching the documented OR rule.
        if (x>=160 || y>=16) begin
            layer=2; sx=x; sy=y;
            word=feature_names_w[((sy>>3)&31)*64+((sx>>3)&63)];
            palette=(word>>13)&3; tile=word&11'h7ff;
            tx=sx&7; ty=sy&7;
            if (word&16'h0800) tx=7-tx;
            if (word&16'h1000) ty=7-ty;
            nib=feature_nibble(tile,tx,ty);
            if (nib!=0) begin opaque=1; rgb=feature_rgb_code((palette*3+nib-1)&7); end
        end else begin
            // Plane A: source=(screen-Hscroll, screen+Vscroll), modulo
            // the programmed 512x256 plane. The alternate profile selects
            // H-scroll per line and V-scroll per 16-pixel column.
            layer=0;
            if (line_variant!=0) begin
                hscroll=feature_hscroll[(y&255)*2];
                vscroll=feature_vsram[((x>>4)&31)*2];
            end else begin hscroll=5; vscroll=feature_vsram[0]; end
            sx=(x-hscroll)&511; sy=(y+vscroll)&255;
            word=feature_names_a[((sy>>3)&31)*64+((sx>>3)&63)];
            palette=(word>>13)&3; tile=word&11'h7ff;
            tx=sx&7; ty=sy&7;
            if (word&16'h0800) tx=7-tx;
            if (word&16'h1000) ty=7-ty;
            nib=feature_nibble(tile,tx,ty);
            if (nib!=0) begin opaque=1; rgb=feature_rgb_code((palette*3+nib-1)&7); end
            if (!opaque) begin
                layer=1;
                if (line_variant!=0) begin
                    hscroll=feature_hscroll[(y&255)*2+1];
                    vscroll=feature_vsram[(((x>>4)&31)*2)+1];
                end else begin hscroll=16'h03fd; vscroll=feature_vsram[1]; end
                sx=(x-hscroll)&511; sy=(y+vscroll)&255;
                word=feature_names_b[((sy>>3)&31)*64+((sx>>3)&63)];
                palette=(word>>13)&3; tile=word&11'h7ff;
                tx=sx&7; ty=sy&7;
                if (word&16'h0800) tx=7-tx;
                if (word&16'h1000) ty=7-ty;
                nib=feature_nibble(tile,tx,ty);
                if (nib!=0) begin opaque=1; rgb=feature_rgb_code((palette*3+nib-1)&7); end
            end
        end
        // The two CPU-programmed SAT descriptors clip against the 320x224
        // viewport. Priority-one opaque sprite pixels sit above these layers.
        for (sprite=0;sprite<2;sprite=sprite+1) begin
            if (sprite==0) begin sprx=-4; spry=0; attr=16'h8008; linkword=16'h0101; end
            else begin sprx=316; spry=221; attr=16'ha00a; linkword=16'h0100; end
            dx=x-sprx; dy=y-spry;
            width=1; height=2;
            if (dx>=0 && dx<width*8 && dy>=0 && dy<height*8) begin
                tile=(attr&11'h7ff)+(dy>>3)*width+(dx>>3);
                tx=dx&7; ty=dy&7;
                if (attr&16'h0800) tx=7-tx;
                if (attr&16'h1000) ty=7-ty;
                nib=feature_nibble(tile,tx,ty);
                if (nib!=0 && attr[15]) begin
                    palette=(attr>>13)&3;
                    rgb=feature_rgb_code((palette*3+nib-1)&7);
                    opaque=1;
                end
            end
        end
        if (opaque) feature_expected_pixel={1'b1,rgb};
        else feature_expected_pixel=25'd0;
    end
endfunction

function integer feature_expected_layer;
    input integer x;
    input integer y;
    input integer line_variant;
    integer sx,sy,word,tile,tx,ty,nib,palette,hscroll,vscroll,dx,dy,sprx,spry,sprite,attr;
    reg opaque_a, opaque_b;
    begin
        if (x>=160 || y>=16) feature_expected_layer=2;
        else begin
            if (line_variant!=0) begin
                hscroll=feature_hscroll[(y&255)*2]; vscroll=feature_vsram[((x>>4)&31)*2];
            end else begin hscroll=5; vscroll=feature_vsram[0]; end
            sx=(x-hscroll)&511; sy=(y+vscroll)&255;
            word=feature_names_a[((sy>>3)&31)*64+((sx>>3)&63)];
            tile=word&11'h7ff; tx=sx&7; ty=sy&7;
            if (word&16'h0800) tx=7-tx;
            if (word&16'h1000) ty=7-ty;
            nib=feature_nibble(tile,tx,ty); opaque_a=(nib!=0);
            if (line_variant!=0) begin
                hscroll=feature_hscroll[(y&255)*2+1]; vscroll=feature_vsram[(((x>>4)&31)*2)+1];
            end else begin hscroll=16'h03fd; vscroll=feature_vsram[1]; end
            sx=(x-hscroll)&511; sy=(y+vscroll)&255;
            word=feature_names_b[((sy>>3)&31)*64+((sx>>3)&63)];
            tile=word&11'h7ff; tx=sx&7; ty=sy&7;
            if (word&16'h0800) tx=7-tx;
            if (word&16'h1000) ty=7-ty;
            nib=feature_nibble(tile,tx,ty); opaque_b=(nib!=0);
            feature_expected_layer=opaque_a ? 0 : (opaque_b ? 1 : 4);
        end
        if (x>=160 || y>=16) begin
            // Preserve the selected window base while still considering the
            // sprite priority layer that is composited above it.
            feature_expected_layer=2;
        end
        for(sprite=0;sprite<2;sprite=sprite+1) begin
            if(sprite==0) begin sprx=-4; spry=0; attr=16'h8008; end
            else begin sprx=316; spry=221; attr=16'ha00a; end
            dx=x-sprx; dy=y-spry;
            if(dx>=0 && dx<8 && dy>=0 && dy<16) begin
                tile=(attr&11'h7ff)+(dy>>3); tx=dx&7; ty=dy&7;
                if(attr&16'h0800) tx=7-tx;
                if(attr&16'h1000) ty=7-ty;
                nib=feature_nibble(tile,tx,ty);
                if(nib!=0 && attr[15]) feature_expected_layer=3;
            end
        end
    end
endfunction

function integer feature_row_slot;
    input integer y;
    begin
        case(y)
            0:feature_row_slot=0; 1:feature_row_slot=1;
            7:feature_row_slot=2; 8:feature_row_slot=3;
            15:feature_row_slot=4; 16:feature_row_slot=5;
            111:feature_row_slot=6; 112:feature_row_slot=7;
            216:feature_row_slot=8; 221:feature_row_slot=9;
            223:feature_row_slot=10;
            default:feature_row_slot=-1;
        endcase
    end
endfunction

task feature_guard_r0;
    input [7:0] checkpoint;
    reg [7:0] current_r0, pristine_r0;
    begin
        current_r0={uut_ym.reg_80_b7,uut_ym.reg_80_b6,uut_ym.reg_lcb,uut_ym.reg_ie1,
                    uut_ym.reg_80_b3,uut_ym.reg_80_b2,uut_ym.reg_m3,uut_ym.reg_80_b0};
        pristine_r0={uut_ym_legacy.reg_80_b7,uut_ym_legacy.reg_80_b6,uut_ym_legacy.reg_lcb,uut_ym_legacy.reg_ie1,
                     uut_ym_legacy.reg_80_b3,uut_ym_legacy.reg_80_b2,uut_ym_legacy.reg_m3,uut_ym_legacy.reg_80_b0};
        $display("FEATURE_R0_GUARD checkpoint=%02x current=%02x pristine=%02x currentFields=%b%b%b%b%b%b%b%b pristineFields=%b%b%b%b%b%b%b%b",
            checkpoint,current_r0,pristine_r0,
            uut_ym.reg_80_b7,uut_ym.reg_80_b6,uut_ym.reg_lcb,uut_ym.reg_ie1,uut_ym.reg_80_b3,uut_ym.reg_80_b2,uut_ym.reg_m3,uut_ym.reg_80_b0,
            uut_ym_legacy.reg_80_b7,uut_ym_legacy.reg_80_b6,uut_ym_legacy.reg_lcb,uut_ym_legacy.reg_ie1,uut_ym_legacy.reg_80_b3,uut_ym_legacy.reg_80_b2,uut_ym_legacy.reg_m3,uut_ym_legacy.reg_80_b0);
        if(current_r0!==8'h06 || pristine_r0!==8'h06) begin
            $display("FEATURE_FAIL R0 checkpoint=%02x expected=06 candidate=%02x pristine=%02x",checkpoint,current_r0,pristine_r0); $fatal(1);
        end
    end
endtask

// Capture-time state is checked independently of the semantic pixel model.
// This guards the programmed source and frame origin without using DUT fetch
// outputs as expected pixel values.
task feature_capture_state_guard;
    input model_legacy;
    reg [7:0] r0, r1, r12;
    reg [15:0] hscroll_a, hscroll_b, sat0, sat1, sat2, sat3;
    reg [15:0] sat4, sat5, sat6, sat7;
    reg [15:0] a_base, b_base, w_base, hscroll_base, sprite_base;
    reg [10:0] vs0, vs1;
    reg hscroll_mode, line_scroll_mode;
    integer native_h, native_v;
    begin
        if(model_legacy) begin
            r0={uut_ym_legacy.reg_80_b7,uut_ym_legacy.reg_80_b6,uut_ym_legacy.reg_lcb,uut_ym_legacy.reg_ie1,
                uut_ym_legacy.reg_80_b3,uut_ym_legacy.reg_80_b2,uut_ym_legacy.reg_m3,uut_ym_legacy.reg_80_b0};
            r1={uut_ym_legacy.reg_81_b7,uut_ym_legacy.reg_disp,uut_ym_legacy.reg_ie0,uut_ym_legacy.reg_m1,
                uut_ym_legacy.reg_m2,uut_ym_legacy.reg_m5,uut_ym_legacy.reg_81_b1,uut_ym_legacy.reg_81_b0};
            r12={uut_ym_legacy.reg_rs0,uut_ym_legacy.reg_8c_b6,uut_ym_legacy.reg_8c_b5,uut_ym_legacy.reg_8c_b4,
                 uut_ym_legacy.reg_ste,uut_ym_legacy.reg_lsm1,uut_ym_legacy.reg_lsm0,uut_ym_legacy.reg_rs1};
            a_base=uut_ym_legacy.reg_sa; b_base=uut_ym_legacy.reg_sb; w_base=uut_ym_legacy.reg_wd;
            hscroll_base=uut_ym_legacy.reg_hs; sprite_base=uut_ym_legacy.reg_at;
            hscroll_mode=uut_ym_legacy.reg_hscr; line_scroll_mode=|uut_ym_legacy.reg_lscr;
            vs0=uut_ym_legacy.vsram[0]; vs1=uut_ym_legacy.vsram[1];
            hscroll_a={ym_vram_legacy.mem[physical_addr(16'hfc01)],ym_vram_legacy.mem[physical_addr(16'hfc00)]};
            hscroll_b={ym_vram_legacy.mem[physical_addr(16'hfc03)],ym_vram_legacy.mem[physical_addr(16'hfc02)]};
            sat0={ym_vram_legacy.mem[physical_addr(16'h8001)],ym_vram_legacy.mem[physical_addr(16'h8000)]};
            sat1={ym_vram_legacy.mem[physical_addr(16'h8003)],ym_vram_legacy.mem[physical_addr(16'h8002)]};
            sat2={ym_vram_legacy.mem[physical_addr(16'h8005)],ym_vram_legacy.mem[physical_addr(16'h8004)]};
            sat3={ym_vram_legacy.mem[physical_addr(16'h8007)],ym_vram_legacy.mem[physical_addr(16'h8006)]};
            sat4={ym_vram_legacy.mem[physical_addr(16'h8009)],ym_vram_legacy.mem[physical_addr(16'h8008)]};
            sat5={ym_vram_legacy.mem[physical_addr(16'h800b)],ym_vram_legacy.mem[physical_addr(16'h800a)]};
            sat6={ym_vram_legacy.mem[physical_addr(16'h800d)],ym_vram_legacy.mem[physical_addr(16'h800c)]};
            sat7={ym_vram_legacy.mem[physical_addr(16'h800f)],ym_vram_legacy.mem[physical_addr(16'h800e)]};
            native_h=uut_ym_legacy.l106; native_v=uut_ym_legacy.l105;
        end else begin
            r0={uut_ym.reg_80_b7,uut_ym.reg_80_b6,uut_ym.reg_lcb,uut_ym.reg_ie1,
                uut_ym.reg_80_b3,uut_ym.reg_80_b2,uut_ym.reg_m3,uut_ym.reg_80_b0};
            r1={uut_ym.reg_81_b7,uut_ym.reg_disp,uut_ym.reg_ie0,uut_ym.reg_m1,
                uut_ym.reg_m2,uut_ym.reg_m5,uut_ym.reg_81_b1,uut_ym.reg_81_b0};
            r12={uut_ym.reg_rs0,uut_ym.reg_8c_b6,uut_ym.reg_8c_b5,uut_ym.reg_8c_b4,
                 uut_ym.reg_ste,uut_ym.reg_lsm1,uut_ym.reg_lsm0,uut_ym.reg_rs1};
            a_base=uut_ym.reg_sa; b_base=uut_ym.reg_sb; w_base=uut_ym.reg_wd;
            hscroll_base=uut_ym.reg_hs; sprite_base=uut_ym.reg_at;
            hscroll_mode=uut_ym.reg_hscr; line_scroll_mode=|uut_ym.reg_lscr;
            vs0=uut_ym.vsram[0]; vs1=uut_ym.vsram[1];
            hscroll_a={ym_vram.mem[physical_addr(16'hfc01)],ym_vram.mem[physical_addr(16'hfc00)]};
            hscroll_b={ym_vram.mem[physical_addr(16'hfc03)],ym_vram.mem[physical_addr(16'hfc02)]};
            sat0={ym_vram.mem[physical_addr(16'h8001)],ym_vram.mem[physical_addr(16'h8000)]};
            sat1={ym_vram.mem[physical_addr(16'h8003)],ym_vram.mem[physical_addr(16'h8002)]};
            sat2={ym_vram.mem[physical_addr(16'h8005)],ym_vram.mem[physical_addr(16'h8004)]};
            sat3={ym_vram.mem[physical_addr(16'h8007)],ym_vram.mem[physical_addr(16'h8006)]};
            sat4={ym_vram.mem[physical_addr(16'h8009)],ym_vram.mem[physical_addr(16'h8008)]};
            sat5={ym_vram.mem[physical_addr(16'h800b)],ym_vram.mem[physical_addr(16'h800a)]};
            sat6={ym_vram.mem[physical_addr(16'h800d)],ym_vram.mem[physical_addr(16'h800c)]};
            sat7={ym_vram.mem[physical_addr(16'h800f)],ym_vram.mem[physical_addr(16'h800e)]};
            native_h=uut_ym.l106; native_v=uut_ym.l105;
        end
        $display("FEATURE_STATE model=%0d captureFrame=%0d nativeFrame=%0d t=%0t elapsedSetup=%0t H/V=%0d/%0d R0/R1/R12=%02x/%02x/%02x basesA/B/W/Hscroll/SAT=%x/%x/%x/%x/%x scrollMode=%b/%b FC00/FC02=%04x/%04x VSRAM0/1=%03x/%03x SAT=%04x/%04x/%04x/%04x/%04x/%04x/%04x/%04x cache=%06x/%06x HScrollBanks=%02x%02x/%02x%02x load=%b%b%b%b select=%b%b effective=%03x",
            model_legacy,source_frame_id,feature_legacy_native_frames,$time,$time-feature_setup_time,native_h,native_v,r0,r1,r12,
            a_base,b_base,w_base,hscroll_base,sprite_base,hscroll_mode,line_scroll_mode,hscroll_a,hscroll_b,vs0,vs1,
            sat0,sat1,sat2,sat3,sat4,sat5,sat6,sat7,
            model_legacy ? uut_ym_legacy.sat[0] : uut_ym.sat[0],model_legacy ? uut_ym_legacy.sat[1] : uut_ym.sat[1],
            model_legacy ? uut_ym_legacy.l194 : uut_ym.l194,model_legacy ? uut_ym_legacy.l191 : uut_ym.l191,
            model_legacy ? uut_ym_legacy.l195 : uut_ym.l195,model_legacy ? uut_ym_legacy.l192 : uut_ym.l192,
            model_legacy ? uut_ym_legacy.w570 : uut_ym.w570,model_legacy ? uut_ym_legacy.w571 : uut_ym.w571,
            model_legacy ? uut_ym_legacy.w572 : uut_ym.w572,model_legacy ? uut_ym_legacy.w573 : uut_ym.w573,
            model_legacy ? uut_ym_legacy.w574 : uut_ym.w574,model_legacy ? uut_ym_legacy.w575 : uut_ym.w575,
            model_legacy ? uut_ym_legacy.w554 : uut_ym.w554);
        if(r0!==8'h06 || r1!==8'h44 || r12!==8'h81 || a_base!==4'h7 || b_base!==4'h6 || w_base!==6'h14 || hscroll_base!==7'h3f || sprite_base!==8'h40 ||
           hscroll_mode!==feature_line_variant || line_scroll_mode!==feature_line_variant ||
           hscroll_a!==(feature_line_variant ? 16'h0010 : 16'h0005) || hscroll_b!==(feature_line_variant ? 16'h03e0 : 16'h03fd) ||
           vs0!==11'd3 || vs1!==11'd9 || sat0!==16'h0080 || sat1!==16'h0101 || sat2!==16'h8008 || sat3!==16'h007c ||
           sat4!==16'h015d || sat5!==16'h0100 || sat6!==16'ha00a || sat7!==16'h01bc ||
           (model_legacy ? (uut_ym_legacy.sat[0]!==21'h040081 || uut_ym_legacy.sat[1]!==21'h0ae880) : (uut_ym.sat[0]!==21'h040081 || uut_ym.sat[1]!==21'h0ae880))) begin
            feature_capture_state_failures=feature_capture_state_failures+1;
            $display("FEATURE_CAPTURE_STATE_MISMATCH model=%0d variant=%0d frame=%0d expected R0/R1/R12=06/44/81 lineMode=%0d scroll FC00/02=%04x/%04x VSRAM=003/009 SAT/cache exact",
                model_legacy,feature_line_variant,source_frame_id,feature_line_variant,
                feature_line_variant ? 16'h0010 : 16'h0005,feature_line_variant ? 16'h03e0 : 16'h03fd);
        end
        if(!model_legacy && (source_frame_id!=feature_target_frame || source_x_sample!=0 || source_y_sample!=0 || native_h!=9'd26 || native_v!=0)) begin
            feature_capture_state_failures=feature_capture_state_failures+1;
            $display("FEATURE_CAPTURE_ORIGIN_MISMATCH model=candidate frame=%0d target=%0d ext=%0d/%0d H/V=%0d/%0d",source_frame_id,feature_target_frame,source_x_sample,source_y_sample,native_h,native_v);
        end
        if(model_legacy && (feature_legacy_native_frames!=1 || native_h!=9'd26 || native_v!=0)) begin
            feature_capture_state_failures=feature_capture_state_failures+1;
            $display("FEATURE_CAPTURE_ORIGIN_MISMATCH model=pristine frameSerial=%0d H/V=%0d/%0d",feature_legacy_native_frames,native_h,native_v);
        end
    end
endtask

// Feature status polling stays on the isolated per-model pins. The generic
// cpu_read task drives the shared fixture bus, which is masked while
// feature_bus_active selects feature_ca/feature_as_n/etc.
task feature_cpu_read_model;
    input model_legacy;
    input [22:0] address;
    output [15:0] data;
    integer timeout;
    begin
        feature_bus_active=1;
        feature_ca=0; feature_cd=16'hffff; feature_as_n=1; feature_uds=1; feature_lds=1; feature_rw=1;
        feature_ca_legacy=0; feature_cd_legacy=16'hffff; feature_as_n_legacy=1; feature_uds_legacy=1; feature_lds_legacy=1; feature_rw_legacy=1;
        if(!ym_dtackn || !ym_dtackn_legacy) begin
            $display("FEATURE_FAIL prior feature CPU read has not released both DTACKs"); $fatal(1);
        end
        if(model_legacy) feature_ca_legacy=address;
        else feature_ca=address;

        @(posedge cpu_clk); // S0 address
        @(negedge cpu_clk);
        if(model_legacy) feature_as_n_legacy=0; else feature_as_n=0; // S1 AS/RW
        @(posedge cpu_clk); // S2 read setup
        @(negedge cpu_clk);
        if(model_legacy) begin feature_uds_legacy=0; feature_lds_legacy=0; end
        else begin feature_uds=0; feature_lds=0; end // S3 DS

        timeout=0;
        while((model_legacy ? ym_dtackn_legacy : ym_dtackn) && timeout<1024) begin
            @(posedge cpu_clk); #2; timeout=timeout+1;
            if(model_legacy ? !ym_dtackn : !ym_dtackn_legacy) begin
                $display("FEATURE_FAIL inactive YM asserted DTACK during isolated read target=%0d addr=%06x",model_legacy,address); $fatal(1);
            end
        end
        if(model_legacy ? ym_dtackn_legacy : ym_dtackn) begin
            $display("FEATURE_FAIL isolated read missed ACK target=%0d addr=%06x",model_legacy,address); $fatal(1);
        end

        @(negedge cpu_clk);
        @(posedge cpu_clk); // S6 legal read-data sample and release
        #2;
        data=model_legacy ? ym_cd_o_legacy : ym_cd_o;
        if ((^data)===1'bx) begin
            $display("FEATURE_FAIL isolated read returned unknown target=%0d addr=%06x data=%04x",model_legacy,address,data); $fatal(1);
        end
        if(model_legacy) begin feature_as_n_legacy=1; feature_uds_legacy=1; feature_lds_legacy=1; end
        else begin feature_as_n=1; feature_uds=1; feature_lds=1; end
        timeout=0;
        while(!(model_legacy ? ym_dtackn_legacy : ym_dtackn) && timeout<32) begin
            @(posedge cpu_clk); #2; timeout=timeout+1;
        end
        if(!(model_legacy ? ym_dtackn_legacy : ym_dtackn)) begin
            $display("FEATURE_FAIL isolated read DTACK did not release target=%0d addr=%06x",model_legacy,address); $fatal(1);
        end
        if(model_legacy ? !ym_dtackn : !ym_dtackn_legacy) begin
            $display("FEATURE_FAIL inactive YM read ACK leaked target=%0d addr=%06x",model_legacy,address); $fatal(1);
        end
        @(negedge cpu_clk); // retain address through the post-S6 hold
    end
endtask

task feature_wait_fifo_empty_model;
    input model_legacy;
    output [15:0] status;
    integer poll;
    begin
        status=0; poll=0;
        while(poll<64 && status[9:8]!==2'b10) begin
            feature_cpu_read_model(model_legacy,23'h600002,status);
            poll=poll+1;
        end
        if(status[9:8]!==2'b10) begin
            $display("FEATURE_FAIL FIFO did not report empty on target=%0d status=%04x H/V=%0d/%0d",model_legacy,status,
                model_legacy ? uut_ym_legacy.l106 : uut_ym.l106,model_legacy ? uut_ym_legacy.l105 : uut_ym.l105); $fatal(1);
        end
    end
endtask

task feature_trace_source_descriptor;
    input integer x;
    input integer y;
    input integer line_variant;
    integer sx,sy,word,tile,tx,ty,nib,palette,bsx,bsy,bword,btile,btx,bty,bnib,bpalette;
    integer ah,bh,av,bv,layer,apalette,pal_slot,window_selected,sprite_selected;
    reg [24:0] expected;
    begin
        if(line_variant!=0) begin
            ah=feature_hscroll[(y&255)*2]; bh=feature_hscroll[(y&255)*2+1];
            av=feature_vsram[((x>>4)&31)*2]; bv=feature_vsram[(((x>>4)&31)*2)+1];
        end else begin ah=feature_hscroll[0]; bh=feature_hscroll[1]; av=feature_vsram[0]; bv=feature_vsram[1]; end
        sx=(x-ah)&511; sy=(y+av)&255;
        word=feature_names_a[((sy>>3)&31)*64+((sx>>3)&63)];
        tile=word&11'h7ff; apalette=(word>>13)&3; tx=sx&7; ty=sy&7;
        if(word&16'h0800) tx=7-tx;
        if(word&16'h1000) ty=7-ty;
        nib=feature_nibble(tile,tx,ty);
        bsx=(x-bh)&511; bsy=(y+bv)&255;
        bword=feature_names_b[((bsy>>3)&31)*64+((bsx>>3)&63)];
        btile=bword&11'h7ff; bpalette=(bword>>13)&3; btx=bsx&7; bty=bsy&7;
        if(bword&16'h0800) btx=7-btx;
        if(bword&16'h1000) bty=7-bty;
        bnib=feature_nibble(btile,btx,bty);
        expected=feature_expected_pixel(x,y,line_variant);
        layer=feature_expected_layer(x,y,line_variant);
        window_selected=(x>=160 || y>=16);
        sprite_selected=(layer==3);
        pal_slot=-1;
        for(palette=0;palette<8;palette=palette+1)
            if(expected[23:0]===feature_rgb_code(palette)) pal_slot=palette;
        $display("FEATURE_SOURCE x/y=%0d/%0d variant=%0d scrollA=%0d,%0d Axy=%0d/%0d Aname=%04x flip=%b%b tile=%0d tex=%0d/%0d nib=%x pal=%0d scrollB=%0d,%0d Bxy=%0d/%0d Bname=%04x flip=%b%b tile=%0d tex=%0d/%0d nib=%x pal=%0d window=%0d spriteSelected=%0d layer=%0d paletteSlot=%0d expected=%07x",
            x,y,line_variant,ah,av,sx,sy,word,word[12],word[11],tile,tx,ty,nib,apalette,bh,bv,bsx,bsy,bword,bword[12],bword[11],btile,btx,bty,bnib,bpalette,
            window_selected,sprite_selected,layer,pal_slot,expected);
    end
endtask

always @(posedge clk48) begin : feature_candidate_boundary_trace
    integer x,y;
    reg [24:0] tuple_pre;
    reg cen_pre,cen2_pre,hs_pre,vs_pre,lhbl_pre,lvbl_pre,de_pre,deh_pre,dev_pre;
    reg [8:0] h_pre,v_pre;
    reg [9:0] rx_pre;
    reg [8:0] ry_pre;
    reg [1:0] q_pre;
    reg [2:0] tick_pre;
    reg ready_pre,enable_pre;
    if(feature_capture && raster_lhbl && raster_lvbl && source_y_sample<2 && source_x_sample<8) begin
        x=source_x_sample; y=source_y_sample;
        tuple_pre={ym_ys,ym_r,ym_g,ym_b}; cen_pre=pxl_cen; cen2_pre=pxl2_cen;
        hs_pre=raster_hs; vs_pre=raster_vs; lhbl_pre=raster_lhbl; lvbl_pre=raster_lvbl; de_pre=raster_lhbl&raster_lvbl;
        deh_pre=ym_de_h; dev_pre=ym_de_v;
        h_pre=uut_ym.l106; v_pre=uut_ym.l105; rx_pre=uut_ym.passive_raster_x; ry_pre=uut_ym.passive_raster_y;
        q_pre=uut_ym.passive_quarter; tick_pre=uut_ym.passive_tick;
        ready_pre=uut_ym.passive_render_ready; enable_pre=uut_ym.passive_pixel_enable;
        $display("FEATURE_CAND_PRE t=%0t ext=%0d/%0d cen=%b/%b HS/VS/LHBL/LVBL/extDE=%b%b%b%b%b vdpDE=%b%b native=%0d/%0d rast=%0d/%0d phase=%0d/%0d ready=%b pixel_en=%b tuple=%07x",
            $time,x,y,cen_pre,cen2_pre,hs_pre,vs_pre,lhbl_pre,lvbl_pre,de_pre,deh_pre,dev_pre,h_pre,v_pre,rx_pre,ry_pre,q_pre,tick_pre,ready_pre,enable_pre,tuple_pre);
        if(cen_pre) feature_trace_source_descriptor(x,y,feature_line_variant);
        #1;
        $display("FEATURE_CAND_POST t=%0t ext_saved=%0d/%0d ext_now=%0d/%0d cen=%b/%b HS/VS/LHBL/LVBL/extDE=%b%b%b%b%b vdpDE=%b%b native=%0d/%0d rast=%0d/%0d phase=%0d/%0d ready=%b pixel_en=%b tuple=%07x",
            $time,x,y,source_x_sample,source_y_sample,pxl_cen,pxl2_cen,raster_hs,raster_vs,raster_lhbl,raster_lvbl,raster_lhbl&raster_lvbl,ym_de_h,ym_de_v,
            uut_ym.l106,uut_ym.l105,uut_ym.passive_raster_x,uut_ym.passive_raster_y,uut_ym.passive_quarter,uut_ym.passive_tick,
            uut_ym.passive_render_ready,uut_ym.passive_pixel_enable,{ym_ys,ym_r,ym_g,ym_b});
    end
end

always @(posedge clk) begin : feature_pristine_boundary_trace
    integer h,v,x;
    reg [24:0] tuple_pre;
    reg cen_pre,cen2_pre;
    if(feature_capture && uut_ym_legacy.l105<2 && uut_ym_legacy.l106>=9'd26 && uut_ym_legacy.l106<=9'd33) begin
        h=uut_ym_legacy.l106; v=uut_ym_legacy.l105; x=h-26;
        tuple_pre={ym_ys_legacy,ym_r_legacy,ym_g_legacy,ym_b_legacy}; cen_pre=pxl_cen; cen2_pre=pxl2_cen;
        $display("FEATURE_OLD_PRE t=%0t native=%0d/%0d x=%0d frameworkCEN=%b/%b external=%0d/%0d LHBL/LVBL=%b%b vdpDE=%b%b tuple=%07x",
            $time,h,v,x,cen_pre,cen2_pre,source_x_sample,source_y_sample,raster_lhbl,raster_lvbl,ym_de_h_legacy,ym_de_v_legacy,tuple_pre);
        #1;
        $display("FEATURE_OLD_POST t=%0t native=%0d/%0d x=%0d frameworkCEN=%b/%b external=%0d/%0d LHBL/LVBL=%b%b vdpDE=%b%b tuple=%07x",$time,
            uut_ym_legacy.l106,uut_ym_legacy.l105,x,pxl_cen,pxl2_cen,source_x_sample,source_y_sample,raster_lhbl,raster_lvbl,
            ym_de_h_legacy,ym_de_v_legacy,{ym_ys_legacy,ym_r_legacy,ym_g_legacy,ym_b_legacy});
    end
end

// Capture the pristine model at its own native H/V sample points. A
// simultaneous legacy tuple on the 48 MHz edge is not coordinate-aligned.
always @(posedge clk) begin : feature_native_legacy_capture
    integer slot, x, y, h;
    #1;
    h=uut_ym_legacy.l106;
    if (feature_capture && !feature_legacy_started &&
        (uut_ym_legacy.l105!=0 || uut_ym_legacy.l106!=0)) feature_legacy_armed=1;
    if (feature_capture && feature_legacy_armed && h==9'd26 && feature_legacy_prev_h!=9'd26 && uut_ym_legacy.l105==0) begin
        if (!feature_legacy_started) begin
            feature_legacy_started=1;
            feature_legacy_native_frames=1;
            feature_legacy_total=0;
            for(slot=0;slot<FEATURE_ROWS;slot=slot+1) begin
                feature_legacy_count[slot]=0;
                feature_legacy_last[slot]=-1;
            end
            $display("FEATURE_LEGACY_ORIGIN native H/V=%0d/%0d",uut_ym_legacy.l106,uut_ym_legacy.l105);
        end else if (!feature_legacy_done) begin
            $display("FEATURE_FAIL pristine selected rows crossed a native frame before completion samples=%0d",feature_legacy_total);
            $fatal(1);
        end
    end
    if (feature_capture && feature_legacy_started && !feature_legacy_done &&
        h==9'd26 && feature_legacy_prev_h!=9'd26) begin
        feature_legacy_row_latched=uut_ym_legacy.l105;
        feature_legacy_row_active=1;
    end
    if (feature_capture && feature_legacy_started && feature_legacy_row_active && !feature_legacy_done &&
        h>=9'd26 && h<=9'd345) begin
        x=h-9'd26; y=feature_legacy_row_latched; slot=feature_row_slot(y);
        if(slot>=0 && x!=feature_legacy_last[slot] && feature_legacy_count[slot]<320) begin
            if(x!=feature_legacy_count[slot]) begin
                $display("FEATURE_FAIL pristine native coordinate discontinuity row=%0d count=%0d x=%0d",y,feature_legacy_count[slot],x);
                $fatal(1);
            end
            feature_legacy[slot][x]={ym_ys_legacy,ym_r_legacy,ym_g_legacy,ym_b_legacy};
            feature_legacy_last[slot]=x;
            feature_legacy_count[slot]=feature_legacy_count[slot]+1;
            feature_legacy_total=feature_legacy_total+1;
            if(feature_legacy_total==FEATURE_ROWS*320) begin
                feature_legacy_done=1;
                if(feature_legacy_native_frames!=1) begin $display("FEATURE_FAIL pristine rows span %0d native frames",feature_legacy_native_frames); $fatal(1); end
                $display("FEATURE_LEGACY_ROWS complete native frames=%0d samples=%0d",feature_legacy_native_frames,feature_legacy_total);
            end
        end
    end
    if (feature_capture && feature_legacy_started && !feature_legacy_state_guarded &&
        h==9'd26 && feature_legacy_prev_h!=9'd26 && uut_ym_legacy.l105==0) begin
        feature_capture_state_guard(1'b1);
        feature_legacy_state_guarded=1;
    end
    if (h==9'd345) feature_legacy_row_active=0;
    feature_legacy_prev_h=h;
end

always @(posedge clk48) begin : feature_external_capture
    integer slot, x, y;
    if (feature_capture && pxl_cen && raster_lhbl && raster_lvbl &&
        source_frame_id==feature_target_frame && source_x_sample<320) begin
        x=source_x_sample; y=source_y_sample; slot=feature_row_slot(y);
        if (slot>=0) begin
            if(x==0 && y==0 && !feature_candidate_state_guarded) begin
                feature_capture_state_guard(1'b0);
                feature_candidate_state_guarded=1;
            end
            if (feature_row_count[slot]>=320 || x!=feature_row_count[slot]) begin
                $display("FEATURE_FAIL coordinate discontinuity row=%0d count=%0d sourceX=%0d",y,feature_row_count[slot],x);
                $fatal(1);
            end
            feature_current[slot][x]={ym_ys,ym_r,ym_g,ym_b};
            feature_row_count[slot]=feature_row_count[slot]+1;
            feature_total_samples=feature_total_samples+1;
            if (feature_row_count[slot]==320) begin
                $display("FEATURE_ROW row=%0d x0=%07x x159=%07x x160=%07x x319=%07x",
                    y,feature_current[slot][0],feature_current[slot][159],feature_current[slot][160],feature_current[slot][319]);
            end
            if (feature_row_count[slot]==320 && feature_total_samples==FEATURE_ROWS*320)
                feature_done=1;
        end
    end
end

// Record scroll-bank load/select state during the same late-blank interval
// in which the native decoder fetches global H-scroll. This is diagnostic:
// semantic expected pixels remain derived only from the fixture descriptors.
always @(posedge ym_clk) begin : feature_candidate_hscroll_fetch
    reg [3:0] load_now;
    reg [1:0] select_now;
    #1;
    load_now={uut_ym.w573,uut_ym.w572,uut_ym.w571,uut_ym.w570};
    select_now={uut_ym.w575,uut_ym.w574};
    if(feature_capture && uut_ym.l105==0 && uut_ym.l106>=9'd470 && uut_ym.l106<=9'd511 &&
       ((load_now!=feature_hs_candidate_load_prev) || (select_now!=feature_hs_candidate_select_prev))) begin
        feature_hs_candidate_events=feature_hs_candidate_events+1;
        if(feature_hs_candidate_events<=128) $display("FEATURE_HSCROLL_FETCH model=candidate t=%0t frame=%0d H/V=%0d/%0d loads=%b selects=%b banks=%02x%02x/%02x%02x effective=%03x serial=%03x vaddr=%05x data=%03x",
            $time,source_frame_id,uut_ym.l106,uut_ym.l105,load_now,select_now,
            uut_ym.l194,uut_ym.l191,uut_ym.l195,uut_ym.l192,uut_ym.w554,uut_ym.vram_serial,uut_ym.vram_address,uut_ym.vram_data);
    end
    feature_hs_candidate_load_prev=load_now;
    feature_hs_candidate_select_prev=select_now;
end

always @(posedge clk) begin : feature_legacy_hscroll_fetch
    reg [3:0] load_now;
    reg [1:0] select_now;
    #1;
    load_now={uut_ym_legacy.w573,uut_ym_legacy.w572,uut_ym_legacy.w571,uut_ym_legacy.w570};
    select_now={uut_ym_legacy.w575,uut_ym_legacy.w574};
    if(feature_capture && uut_ym_legacy.l105==0 && uut_ym_legacy.l106>=9'd470 && uut_ym_legacy.l106<=9'd511 &&
       ((load_now!=feature_hs_legacy_load_prev) || (select_now!=feature_hs_legacy_select_prev))) begin
        feature_hs_legacy_events=feature_hs_legacy_events+1;
        if(feature_hs_legacy_events<=128) $display("FEATURE_HSCROLL_FETCH model=pristine t=%0t frameSerial=%0d H/V=%0d/%0d loads=%b selects=%b banks=%02x%02x/%02x%02x effective=%03x serial=%03x vaddr=%05x data=%03x",
            $time,feature_legacy_native_frames,uut_ym_legacy.l106,uut_ym_legacy.l105,
            load_now,select_now,
            uut_ym_legacy.l194,uut_ym_legacy.l191,uut_ym_legacy.l195,uut_ym_legacy.l192,uut_ym_legacy.w554,
            uut_ym_legacy.vram_serial,uut_ym_legacy.vram_address,uut_ym_legacy.vram_data);
    end
    feature_hs_legacy_load_prev=load_now;
    feature_hs_legacy_select_prev=select_now;
end

// Full pre/post MCLK window around the H-scroll serial transfer. The page-load
// and SC-rise predicates below mirror vram's sequential branch conditions;
// they are observations only and do not alter the fixture or DUT.
always @(posedge ym_clk) begin : feature_candidate_vram_scroll_edges
    integer h, v;
    reg page_pre, sc_rise_pre;
    reg [15:0] addr_pre;
    reg [7:0] ser_addr_pre, ser_page_pre, ser_o_pre, vram_ser_pre, serial_pre, data_pre;
    reg [3:0] load_pre;
    if(feature_capture && !feature_scroll_trace_candidate_done) begin
        h=uut_ym.l106; v=uut_ym.l105;
        if(v==0 && h>=484 && h<=493) begin
            feature_scroll_trace_candidate_started=1;
            feature_scroll_trace_candidate_samples=feature_scroll_trace_candidate_samples+1;
            page_pre=ym_vram.dt && !ym_vram.o_OE && ym_oe;
            sc_rise_pre=!ym_vram.o_SC && ym_sc;
            load_pre={uut_ym.w573,uut_ym.w572,uut_ym.w571,uut_ym.w570};
            addr_pre=ym_vram.addr; ser_addr_pre=ym_vram.addr_ser; ser_page_pre=ym_vram.addr_ser_page;
            ser_o_pre=ym_vram.ser_o; vram_ser_pre=ym_vram.vram_ser; serial_pre=uut_ym.vram_serial; data_pre=uut_ym.vram_data;
            if(page_pre) feature_scroll_trace_candidate_pages=feature_scroll_trace_candidate_pages+1;
            if(sc_rise_pre) feature_scroll_trace_candidate_sc=feature_scroll_trace_candidate_sc+1;
            if(load_pre[0]) feature_scroll_trace_candidate_w570=feature_scroll_trace_candidate_w570+1;
            if(load_pre[1]) feature_scroll_trace_candidate_w571=feature_scroll_trace_candidate_w571+1;
            if(load_pre[2]) feature_scroll_trace_candidate_w572=feature_scroll_trace_candidate_w572+1;
            if(load_pre[3]) feature_scroll_trace_candidate_w573=feature_scroll_trace_candidate_w573+1;
            if(feature_scroll_trace_candidate_samples>256) feature_scroll_trace_candidate_overflow=1;
            else $display("SCROLL_EDGE model=candidate phase=PRE t=%0t H/V=%0d/%0d q/t/d=%0d/%0d/%0d clk=%b%b hclk=%b%b pins=RAS/CAS/WE/OE/SC/SE:%b%b%b%b%b%b dt/oOE/oSC/page/scRise=%b%b%b%b%b AD=%02x addr=%04x serialAddr=%02x/%02x ser_o/vram_ser/SD/YMserial/data=%02x/%02x/%02x/%02x/%02x load570..573=%b banks=%02x%02x/%02x%02x ramfc=%02x%02x%02x%02x",
                $time,h,v,uut_ym.passive_quarter,uut_ym.passive_tick,uut_ym.passive_dwell,
                uut_ym.clk1,uut_ym.clk2,uut_ym.hclk1,uut_ym.hclk2,ym_ras,ym_cas,ym_we0,ym_oe,ym_sc,ym_se0,
                ym_vram.dt,ym_vram.o_OE,ym_vram.o_SC,page_pre,sc_rise_pre,ym_read_data,addr_pre,ser_page_pre,ser_addr_pre,
                ser_o_pre,vram_ser_pre,ym_vram.SD_o,serial_pre,data_pre,load_pre,uut_ym.l194,uut_ym.l191,uut_ym.l195,uut_ym.l192,
                ym_vram.mem[16'h00fc],ym_vram.mem[16'h00fd],ym_vram.mem[16'h00fe],ym_vram.mem[16'h00ff]);
            #1;
            if(feature_scroll_trace_candidate_samples<=256) $display("SCROLL_EDGE model=candidate phase=POST t=%0t H/V=%0d/%0d q/t/d=%0d/%0d/%0d clk=%b%b hclk=%b%b pins=RAS/CAS/WE/OE/SC/SE:%b%b%b%b%b%b dt/oOE/oSC/page/scRise=%b%b%b%b%b AD=%02x addr=%04x serialAddr=%02x/%02x ser_o/vram_ser/SD/YMserial/data=%02x/%02x/%02x/%02x/%02x load570..573=%b banks=%02x%02x/%02x%02x ramfc=%02x%02x%02x%02x",
                $time,uut_ym.l106,uut_ym.l105,uut_ym.passive_quarter,uut_ym.passive_tick,uut_ym.passive_dwell,
                uut_ym.clk1,uut_ym.clk2,uut_ym.hclk1,uut_ym.hclk2,ym_ras,ym_cas,ym_we0,ym_oe,ym_sc,ym_se0,
                ym_vram.dt,ym_vram.o_OE,ym_vram.o_SC,ym_vram.dt && !ym_vram.o_OE && ym_oe,!ym_vram.o_SC && ym_sc,ym_read_data,
                ym_vram.addr,ym_vram.addr_ser_page,ym_vram.addr_ser,ym_vram.ser_o,ym_vram.vram_ser,ym_vram.SD_o,uut_ym.vram_serial,uut_ym.vram_data,
                {uut_ym.w573,uut_ym.w572,uut_ym.w571,uut_ym.w570},uut_ym.l194,uut_ym.l191,uut_ym.l195,uut_ym.l192,
                ym_vram.mem[16'h00fc],ym_vram.mem[16'h00fd],ym_vram.mem[16'h00fe],ym_vram.mem[16'h00ff]);
        end else if(feature_scroll_trace_candidate_started && v==0 && h>493) begin
            feature_scroll_trace_candidate_done=1;
            $display("SCROLL_TRACE_SUMMARY model=candidate samples=%0d page_load=%0d sc_rise=%0d w570/w571/w572/w573=%0d/%0d/%0d/%0d overflow=%b coverage=%b range=H484..493 V0",
                feature_scroll_trace_candidate_samples,feature_scroll_trace_candidate_pages,feature_scroll_trace_candidate_sc,
                feature_scroll_trace_candidate_w570,feature_scroll_trace_candidate_w571,feature_scroll_trace_candidate_w572,feature_scroll_trace_candidate_w573,
                feature_scroll_trace_candidate_overflow,
                (feature_scroll_trace_candidate_pages>0 && feature_scroll_trace_candidate_sc>0 && feature_scroll_trace_candidate_w570>0 &&
                 feature_scroll_trace_candidate_w571>0 && feature_scroll_trace_candidate_w572>0 && feature_scroll_trace_candidate_w573>0 && !feature_scroll_trace_candidate_overflow));
        end
    end
end

always @(posedge clk) begin : feature_pristine_vram_scroll_edges
    integer h, v;
    reg page_pre, sc_rise_pre;
    reg [15:0] addr_pre;
    reg [7:0] ser_addr_pre, ser_page_pre, ser_o_pre, vram_ser_pre, serial_pre, data_pre;
    reg [3:0] load_pre;
    if(feature_capture && !feature_scroll_trace_legacy_done) begin
        h=uut_ym_legacy.l106; v=uut_ym_legacy.l105;
        if(v==0 && h>=484 && h<=493) begin
            feature_scroll_trace_legacy_started=1;
            feature_scroll_trace_legacy_samples=feature_scroll_trace_legacy_samples+1;
            page_pre=ym_vram_legacy.dt && !ym_vram_legacy.o_OE && ym_oe_legacy;
            sc_rise_pre=!ym_vram_legacy.o_SC && ym_sc_legacy;
            load_pre={uut_ym_legacy.w573,uut_ym_legacy.w572,uut_ym_legacy.w571,uut_ym_legacy.w570};
            addr_pre=ym_vram_legacy.addr; ser_addr_pre=ym_vram_legacy.addr_ser; ser_page_pre=ym_vram_legacy.addr_ser_page;
            ser_o_pre=ym_vram_legacy.ser_o; vram_ser_pre=ym_vram_legacy.vram_ser; serial_pre=uut_ym_legacy.vram_serial; data_pre=uut_ym_legacy.vram_data;
            if(page_pre) feature_scroll_trace_legacy_pages=feature_scroll_trace_legacy_pages+1;
            if(sc_rise_pre) feature_scroll_trace_legacy_sc=feature_scroll_trace_legacy_sc+1;
            if(load_pre[0]) feature_scroll_trace_legacy_w570=feature_scroll_trace_legacy_w570+1;
            if(load_pre[1]) feature_scroll_trace_legacy_w571=feature_scroll_trace_legacy_w571+1;
            if(load_pre[2]) feature_scroll_trace_legacy_w572=feature_scroll_trace_legacy_w572+1;
            if(load_pre[3]) feature_scroll_trace_legacy_w573=feature_scroll_trace_legacy_w573+1;
            if(feature_scroll_trace_legacy_samples>256) feature_scroll_trace_legacy_overflow=1;
            else $display("SCROLL_EDGE model=pristine phase=PRE t=%0t H/V=%0d/%0d q/t/d=NA clk=%b%b hclk=%b%b pins=RAS/CAS/WE/OE/SC/SE:%b%b%b%b%b%b dt/oOE/oSC/page/scRise=%b%b%b%b%b AD=%02x addr=%04x serialAddr=%02x/%02x ser_o/vram_ser/SD/YMserial/data=%02x/%02x/%02x/%02x/%02x load570..573=%b banks=%02x%02x/%02x%02x ramfc=%02x%02x%02x%02x",
                $time,h,v,
                uut_ym_legacy.clk1,uut_ym_legacy.clk2,uut_ym_legacy.hclk1,uut_ym_legacy.hclk2,ym_ras_legacy,ym_cas_legacy,ym_we0_legacy,ym_oe_legacy,ym_sc_legacy,ym_se0_legacy,
                ym_vram_legacy.dt,ym_vram_legacy.o_OE,ym_vram_legacy.o_SC,page_pre,sc_rise_pre,ym_read_data_legacy,addr_pre,ser_page_pre,ser_addr_pre,
                ser_o_pre,vram_ser_pre,ym_vram_legacy.SD_o,serial_pre,data_pre,load_pre,uut_ym_legacy.l194,uut_ym_legacy.l191,uut_ym_legacy.l195,uut_ym_legacy.l192,
                ym_vram_legacy.mem[16'h00fc],ym_vram_legacy.mem[16'h00fd],ym_vram_legacy.mem[16'h00fe],ym_vram_legacy.mem[16'h00ff]);
            #1;
            if(feature_scroll_trace_legacy_samples<=256) $display("SCROLL_EDGE model=pristine phase=POST t=%0t H/V=%0d/%0d q/t/d=NA clk=%b%b hclk=%b%b pins=RAS/CAS/WE/OE/SC/SE:%b%b%b%b%b%b dt/oOE/oSC/page/scRise=%b%b%b%b%b AD=%02x addr=%04x serialAddr=%02x/%02x ser_o/vram_ser/SD/YMserial/data=%02x/%02x/%02x/%02x/%02x load570..573=%b banks=%02x%02x/%02x%02x ramfc=%02x%02x%02x%02x",
                $time,uut_ym_legacy.l106,uut_ym_legacy.l105,
                uut_ym_legacy.clk1,uut_ym_legacy.clk2,uut_ym_legacy.hclk1,uut_ym_legacy.hclk2,
                ym_ras_legacy,ym_cas_legacy,ym_we0_legacy,ym_oe_legacy,ym_sc_legacy,ym_se0_legacy,
                ym_vram_legacy.dt,ym_vram_legacy.o_OE,ym_vram_legacy.o_SC,ym_vram_legacy.dt && !ym_vram_legacy.o_OE && ym_oe_legacy,!ym_vram_legacy.o_SC && ym_sc_legacy,ym_read_data_legacy,
                ym_vram_legacy.addr,ym_vram_legacy.addr_ser_page,ym_vram_legacy.addr_ser,ym_vram_legacy.ser_o,ym_vram_legacy.vram_ser,ym_vram_legacy.SD_o,uut_ym_legacy.vram_serial,uut_ym_legacy.vram_data,
                {uut_ym_legacy.w573,uut_ym_legacy.w572,uut_ym_legacy.w571,uut_ym_legacy.w570},uut_ym_legacy.l194,uut_ym_legacy.l191,uut_ym_legacy.l195,uut_ym_legacy.l192,
                ym_vram_legacy.mem[16'h00fc],ym_vram_legacy.mem[16'h00fd],ym_vram_legacy.mem[16'h00fe],ym_vram_legacy.mem[16'h00ff]);
        end else if(feature_scroll_trace_legacy_started && v==0 && h>493) begin
            feature_scroll_trace_legacy_done=1;
            $display("SCROLL_TRACE_SUMMARY model=pristine samples=%0d page_load=%0d sc_rise=%0d w570/w571/w572/w573=%0d/%0d/%0d/%0d overflow=%b coverage=%b range=H484..493 V0",
                feature_scroll_trace_legacy_samples,feature_scroll_trace_legacy_pages,feature_scroll_trace_legacy_sc,
                feature_scroll_trace_legacy_w570,feature_scroll_trace_legacy_w571,feature_scroll_trace_legacy_w572,feature_scroll_trace_legacy_w573,
                feature_scroll_trace_legacy_overflow,
                (feature_scroll_trace_legacy_pages>0 && feature_scroll_trace_legacy_sc>0 && feature_scroll_trace_legacy_w570>0 &&
                 feature_scroll_trace_legacy_w571>0 && feature_scroll_trace_legacy_w572>0 && feature_scroll_trace_legacy_w573>0 && !feature_scroll_trace_legacy_overflow));
        end
    end
end

task feature_set_byte;
    input [15:0] logical_addr;
    input [7:0] value;
    reg [15:0] p;
    begin
        p=physical_addr(logical_addr);
        ym_vram.mem[p]=value; ym_vram_legacy.mem[p]=value;
    end
endtask

task feature_set_word;
    input [15:0] logical_addr;
    input [15:0] value;
    begin
        feature_set_byte(logical_addr,value[7:0]);
        feature_set_byte(logical_addr+16'd1,value[15:8]);
    end
endtask

task feature_initialize_scene;
    integer i,j,k,row,col,base,idx,tile,pix,byteaddr,slot;
    reg [7:0] packed_byte;
    reg [15:0] nameword, satword;
    reg [15:0] sat_status;
    begin
        feature_capture=0; feature_done=0; feature_total_samples=0;
        feature_legacy_armed=0; feature_legacy_started=0; feature_legacy_done=0; feature_legacy_total=0;
        feature_legacy_row_active=0; feature_legacy_row_latched=-1; feature_legacy_prev_h=-1; feature_legacy_native_frames=0;
        feature_row_y[0]=0; feature_row_y[1]=1; feature_row_y[2]=7; feature_row_y[3]=8;
        feature_row_y[4]=15; feature_row_y[5]=16; feature_row_y[6]=111; feature_row_y[7]=112;
        feature_row_y[8]=216; feature_row_y[9]=221; feature_row_y[10]=223;
        for(i=0;i<FEATURE_ROWS;i=i+1) begin
            feature_row_count[i]=0; feature_row_last[i]=-1;
            feature_legacy_count[i]=0; feature_legacy_last[i]=-1;
            for(j=0;j<320;j=j+1) begin feature_current[i][j]=25'h1ffffff; feature_legacy[i][j]=25'h1ffffff; end
        end
        for(i=0;i<65536;i=i+1) begin ym_vram.mem[i]=0; ym_vram_legacy.mem[i]=0; end
        for(i=0;i<40;i=i+1) begin feature_vsram[i]=0; uut_ym.vsram[i]=0; uut_ym_legacy.vsram[i]=0; end
        for(i=0;i<64;i=i+1) begin feature_cram[i]=0; uut_ym.color_ram[i]=0; uut_ym_legacy.color_ram[i]=0; end
        for(tile=0;tile<16;tile=tile+1) for(row=0;row<8;row=row+1) for(col=0;col<8;col=col+1)
            feature_pixels[tile][row][col]=feature_nibble(tile,col,row);
        // The native pixel stream reads semantic p0..p7 from packed bytes
        // {p2,p3}, {p0,p1}, {p6,p7}, {p4,p5}.
        for(tile=0;tile<16;tile=tile+1) for(row=0;row<8;row=row+1) begin
            base=tile*32+row*4;
            packed_byte={feature_pixels[tile][row][2],feature_pixels[tile][row][3]}; feature_set_byte(base,packed_byte);
            packed_byte={feature_pixels[tile][row][0],feature_pixels[tile][row][1]}; feature_set_byte(base+1,packed_byte);
            packed_byte={feature_pixels[tile][row][6],feature_pixels[tile][row][7]}; feature_set_byte(base+2,packed_byte);
            packed_byte={feature_pixels[tile][row][4],feature_pixels[tile][row][5]}; feature_set_byte(base+3,packed_byte);
        end
        // Fill every table cell, preserving logical descriptors separately
        // from the physical DRAM address swizzle.
        for(row=0;row<32;row=row+1) for(col=0;col<64;col=col+1) begin
            idx=row*64+col;
            feature_names_a[idx]=feature_name_word(0,row,col);
            feature_names_b[idx]=feature_name_word(1,row,col);
            feature_names_w[idx]=feature_name_word(2,row,col);
            feature_set_word(16'he000+idx*2,feature_names_a[idx]);
            feature_set_word(16'hc000+idx*2,feature_names_b[idx]);
            feature_set_word(16'ha000+idx*2,feature_names_w[idx]);
        end
        // Known palette values are frozen from the pristine fixture's
        // palette-to-DAC table; each semantic slot is visually distinct.
        for(i=0;i<4;i=i+1) for(j=1;j<16;j=j+1) begin
            slot=(i*3+j-1)&7;
            feature_cram[i*16+j]=feature_cram_code(slot);
            uut_ym.color_ram[i*16+j]=feature_cram[i*16+j];
            uut_ym_legacy.color_ram[i*16+j]=feature_cram[i*16+j];
        end
        feature_vsram[0]=11'd3; feature_vsram[1]=11'd9;
        uut_ym.vsram[0]=feature_vsram[0]; uut_ym_legacy.vsram[0]=feature_vsram[0];
        for(i=1;i<40;i=i+1) begin
            if ((i&1)==0) feature_vsram[i]=11'd4+((i/2)&7);
            else feature_vsram[i]=11'd9+((i/2)&7);
            uut_ym.vsram[i]=feature_vsram[i]; uut_ym_legacy.vsram[i]=feature_vsram[i];
        end
        for(i=0;i<40;i=i+1) begin
            if(uut_ym.vsram[i]!==feature_vsram[i] || uut_ym_legacy.vsram[i]!==feature_vsram[i]) begin
                $display("FEATURE_FAIL VSRAM descriptor guard index=%0d candidate=%03x pristine=%03x expected=%03x",i,uut_ym.vsram[i],uut_ym_legacy.vsram[i],feature_vsram[i]); $fatal(1);
            end
        end
        // Global H-scroll: A=+5, B=-3. The alternate line profile is
        // filled with per-line offsets and two-cell V-scroll columns below.
        // Global-scroll mode below uses 5/-3 directly. For R11=07 the line
        // offsets are aligned to 16 pixels so two-cell V scroll boundaries
        // remain explicit (x=0,16,32...) without a fine-H partial cell.
        feature_hscroll[0]=16'd5; feature_hscroll[1]=16'h03fd;
        for(i=1;i<256;i=i+1) begin
            feature_hscroll[i*2]=((i%3)+1)*16;
            feature_hscroll[i*2+1]=(16'h0400-(((i%3)+2)*16))&16'h03ff;
        end
        for(i=0;i<512;i=i+1) feature_set_word(16'hfc00+i*2,feature_hscroll[i]);
        if ({ym_vram.mem[physical_addr(16'hfc00)],ym_vram.mem[physical_addr(16'hfc01)],
             ym_vram.mem[physical_addr(16'hfc02)],ym_vram.mem[physical_addr(16'hfc03)]} !==
            {8'h05,8'h00,8'hfd,8'h03} ||
            {ym_vram_legacy.mem[physical_addr(16'hfc00)],ym_vram_legacy.mem[physical_addr(16'hfc01)],
             ym_vram_legacy.mem[physical_addr(16'hfc02)],ym_vram_legacy.mem[physical_addr(16'hfc03)]} !==
            {8'h05,8'h00,8'hfd,8'h03}) begin
            $display("FEATURE_FAIL global Hscroll table FC00/FC02 not 0005/03fd"); $fatal(1);
        end
        if ({ym_vram.mem[physical_addr(16'he000)],ym_vram.mem[physical_addr(16'he001)],
             ym_vram.mem[physical_addr(16'heffe)],ym_vram.mem[physical_addr(16'hefff)],
             ym_vram.mem[physical_addr(16'hc000)],ym_vram.mem[physical_addr(16'hc001)],
             ym_vram.mem[physical_addr(16'ha000)],ym_vram.mem[physical_addr(16'ha001)]} !==
            {feature_names_a[0][7:0],feature_names_a[0][15:8],feature_names_a[2047][7:0],feature_names_a[2047][15:8],
             feature_names_b[0][7:0],feature_names_b[0][15:8],feature_names_w[0][7:0],feature_names_w[0][15:8]} ||
            {ym_vram_legacy.mem[physical_addr(16'he000)],ym_vram_legacy.mem[physical_addr(16'he001)],
             ym_vram_legacy.mem[physical_addr(16'heffe)],ym_vram_legacy.mem[physical_addr(16'hefff)]} !==
            {feature_names_a[0][7:0],feature_names_a[0][15:8],feature_names_a[2047][7:0],feature_names_a[2047][15:8]}) begin
            $display("FEATURE_FAIL scene table guard bytes do not match semantic descriptors"); $fatal(1);
        end
        if ({ym_vram.mem[physical_addr(16'h0020)],ym_vram.mem[physical_addr(16'h0021)],
             ym_vram.mem[physical_addr(16'h0022)],ym_vram.mem[physical_addr(16'h0023)]} !==
            {feature_pixels[1][0][2],feature_pixels[1][0][3],feature_pixels[1][0][0],feature_pixels[1][0][1],
             feature_pixels[1][0][6],feature_pixels[1][0][7],feature_pixels[1][0][4],feature_pixels[1][0][5]}) begin
            $display("FEATURE_FAIL tile image bytes do not match packed semantic pattern"); $fatal(1);
        end
        if ({ym_vram.mem[physical_addr(16'h0100)],ym_vram.mem[physical_addr(16'h0101)],ym_vram.mem[physical_addr(16'h0102)],ym_vram.mem[physical_addr(16'h0103)]} !== 32'hca0bc00b ||
            {ym_vram_legacy.mem[physical_addr(16'h0100)],ym_vram_legacy.mem[physical_addr(16'h0101)],ym_vram_legacy.mem[physical_addr(16'h0102)],ym_vram_legacy.mem[physical_addr(16'h0103)]} !== 32'hca0bc00b) begin
            $display("FEATURE_FAIL literal tile8 row0 sentinel at0100..0103 current=%02x%02x%02x%02x pristine=%02x%02x%02x%02x",
                ym_vram.mem[physical_addr(16'h0100)],ym_vram.mem[physical_addr(16'h0101)],ym_vram.mem[physical_addr(16'h0102)],ym_vram.mem[physical_addr(16'h0103)],
                ym_vram_legacy.mem[physical_addr(16'h0100)],ym_vram_legacy.mem[physical_addr(16'h0101)],ym_vram_legacy.mem[physical_addr(16'h0102)],ym_vram_legacy.mem[physical_addr(16'h0103)]); $fatal(1);
        end
        if ({ym_vram.mem[physical_addr(16'h008c)],ym_vram.mem[physical_addr(16'h008d)],ym_vram.mem[physical_addr(16'h008e)],ym_vram.mem[physical_addr(16'h008f)]} !== 32'h12301230 ||
            {ym_vram_legacy.mem[physical_addr(16'h008c)],ym_vram_legacy.mem[physical_addr(16'h008d)],ym_vram_legacy.mem[physical_addr(16'h008e)],ym_vram_legacy.mem[physical_addr(16'h008f)]} !== 32'h12301230) begin
            $display("FEATURE_FAIL literal tile4 row3 sentinel at008c..008f current=%02x%02x%02x%02x pristine=%02x%02x%02x%02x",
                ym_vram.mem[physical_addr(16'h008c)],ym_vram.mem[physical_addr(16'h008d)],ym_vram.mem[physical_addr(16'h008e)],ym_vram.mem[physical_addr(16'h008f)],
                ym_vram_legacy.mem[physical_addr(16'h008c)],ym_vram_legacy.mem[physical_addr(16'h008d)],ym_vram_legacy.mem[physical_addr(16'h008e)],ym_vram_legacy.mem[physical_addr(16'h008f)]); $fatal(1);
        end

        feature_cpu_write_both(23'h600002,16'h8f02);
        feature_cpu_write_both(23'h600002,16'h8238); // A at E000
        feature_cpu_write_both(23'h600002,16'h8406); // B at C000
        feature_cpu_write_both(23'h600002,16'h8328); // window at A000
        feature_cpu_write_both(23'h600002,16'h8540); // SAT at 8000
        feature_cpu_write_both(23'h600002,16'h8700); // backdrop index 0
        feature_cpu_write_both(23'h600002,16'h8b00); // global H scroll
        feature_cpu_write_both(23'h600002,16'h8d3f); // H-scroll at FC00
        feature_cpu_write_both(23'h600002,16'h9001); // 64x32 planes
        feature_cpu_write_both(23'h600002,16'h918a); // right window begins at x160
        feature_cpu_write_both(23'h600002,16'h9282); // full-width window starts at y16
        feature_cpu_write_both(23'h600002,16'h8c81); // H40
        $display("FEATURE_R0_BEFORE current=%02x pristine=%02x fields=%b%b%b%b%b%b%b%b/%b%b%b%b%b%b%b%b",
            {uut_ym.reg_80_b7,uut_ym.reg_80_b6,uut_ym.reg_lcb,uut_ym.reg_ie1,uut_ym.reg_80_b3,uut_ym.reg_80_b2,uut_ym.reg_m3,uut_ym.reg_80_b0},
            {uut_ym_legacy.reg_80_b7,uut_ym_legacy.reg_80_b6,uut_ym_legacy.reg_lcb,uut_ym_legacy.reg_ie1,uut_ym_legacy.reg_80_b3,uut_ym_legacy.reg_80_b2,uut_ym_legacy.reg_m3,uut_ym_legacy.reg_80_b0},
            uut_ym.reg_80_b7,uut_ym.reg_80_b6,uut_ym.reg_lcb,uut_ym.reg_ie1,uut_ym.reg_80_b3,uut_ym.reg_80_b2,uut_ym.reg_m3,uut_ym.reg_80_b0,
            uut_ym_legacy.reg_80_b7,uut_ym_legacy.reg_80_b6,uut_ym_legacy.reg_lcb,uut_ym_legacy.reg_ie1,uut_ym_legacy.reg_80_b3,uut_ym_legacy.reg_80_b2,uut_ym_legacy.reg_m3,uut_ym_legacy.reg_80_b0);
        feature_cpu_write_both(23'h600002,16'h8006); // deliberate R0 Mode 5 display semantics
        repeat(8) tick();
        feature_guard_r0(8'h00);
        feature_cpu_write_both(23'h600002,16'h8144); // Mode5 + display
        timeout=0;
        while ((!uut_ym.passive_render_ready || !uut_ym.passive_geometry_supported) && timeout<2*TEST_FRAME_LINES*TEST_LINE_PIXELS*8) begin tick(); timeout=timeout+1; end
        if (!uut_ym.passive_render_ready || !uut_ym.passive_geometry_supported) begin
            $display("FEATURE_FAIL renderer did not prime T/W/N/A=%0d/%0d/%0d/%0d H/V=%0d/%0d",uut_ym.passive_line_pixels,
                uut_ym.passive_active_pixels,uut_ym.passive_frame_lines,uut_ym.passive_active_lines,uut_ym.l106,uut_ym.l105); $fatal(1);
        end
        $display("FEATURE_MMR_AUDIT pseudoR1=%02x/%02x actualR1=%02x/%02x b1=%b/%b R12=%02x/%02x bases=%x/%x/%x/%x:%x/%x/%x/%x win=%b/%02x/%b/%02x:%b/%02x/%b/%02x expected=44/7/6/14/3f/81/1/10/1/2",
            {uut_ym.reg_81_b7,uut_ym.reg_disp,uut_ym.reg_ie0,uut_ym.reg_m1,uut_ym.reg_m2,uut_ym.reg_m5,uut_ym.reg_m3,uut_ym.reg_81_b0},
            {uut_ym_legacy.reg_81_b7,uut_ym_legacy.reg_disp,uut_ym_legacy.reg_ie0,uut_ym_legacy.reg_m1,uut_ym_legacy.reg_m2,uut_ym_legacy.reg_m5,uut_ym_legacy.reg_m3,uut_ym_legacy.reg_81_b0},
            {uut_ym.reg_81_b7,uut_ym.reg_disp,uut_ym.reg_ie0,uut_ym.reg_m1,uut_ym.reg_m2,uut_ym.reg_m5,uut_ym.reg_81_b1,uut_ym.reg_81_b0},
            {uut_ym_legacy.reg_81_b7,uut_ym_legacy.reg_disp,uut_ym_legacy.reg_ie0,uut_ym_legacy.reg_m1,uut_ym_legacy.reg_m2,uut_ym_legacy.reg_m5,uut_ym_legacy.reg_81_b1,uut_ym_legacy.reg_81_b0},
            uut_ym.reg_81_b1,uut_ym_legacy.reg_81_b1,
            {uut_ym.reg_rs0,uut_ym.reg_8c_b6,uut_ym.reg_8c_b5,uut_ym.reg_8c_b4,uut_ym.reg_ste,uut_ym.reg_lsm1,uut_ym.reg_lsm0,uut_ym.reg_rs1},
            {uut_ym_legacy.reg_rs0,uut_ym_legacy.reg_8c_b6,uut_ym_legacy.reg_8c_b5,uut_ym_legacy.reg_8c_b4,uut_ym_legacy.reg_ste,uut_ym_legacy.reg_lsm1,uut_ym_legacy.reg_lsm0,uut_ym_legacy.reg_rs1},
            uut_ym.reg_sa,uut_ym.reg_sb,uut_ym.reg_wd,uut_ym.reg_hs,uut_ym_legacy.reg_sa,uut_ym_legacy.reg_sb,uut_ym_legacy.reg_wd,uut_ym_legacy.reg_hs,
            uut_ym.reg_rigt,uut_ym.reg_whp,uut_ym.reg_down,uut_ym.reg_wvp,uut_ym_legacy.reg_rigt,uut_ym_legacy.reg_whp,uut_ym_legacy.reg_down,uut_ym_legacy.reg_wvp);
        if ({uut_ym.reg_81_b7,uut_ym.reg_disp,uut_ym.reg_ie0,uut_ym.reg_m1,uut_ym.reg_m2,uut_ym.reg_m5,uut_ym.reg_81_b1,uut_ym.reg_81_b0}!==8'h44 ||
            {uut_ym_legacy.reg_81_b7,uut_ym_legacy.reg_disp,uut_ym_legacy.reg_ie0,uut_ym_legacy.reg_m1,uut_ym_legacy.reg_m2,uut_ym_legacy.reg_m5,uut_ym_legacy.reg_81_b1,uut_ym_legacy.reg_81_b0}!==8'h44 ||
            uut_ym.reg_sa!==4'h7 || uut_ym_legacy.reg_sa!==4'h7 ||
            uut_ym.reg_sb!==4'h6 || uut_ym_legacy.reg_sb!==4'h6 ||
            uut_ym.reg_wd!==6'h14 || uut_ym_legacy.reg_wd!==6'h14 ||
            uut_ym.reg_hs!==7'h3f || uut_ym_legacy.reg_hs!==7'h3f ||
            uut_ym.reg_rigt!==1'b1 || uut_ym_legacy.reg_rigt!==1'b1 ||
            uut_ym.reg_whp!==5'd10 || uut_ym_legacy.reg_whp!==5'd10 ||
            uut_ym.reg_down!==1'b1 || uut_ym_legacy.reg_down!==1'b1 ||
            uut_ym.reg_wvp!==5'd2 || uut_ym_legacy.reg_wvp!==5'd2 ||
            {uut_ym.reg_rs0,uut_ym.reg_8c_b6,uut_ym.reg_8c_b5,uut_ym.reg_8c_b4,uut_ym.reg_ste,uut_ym.reg_lsm1,uut_ym.reg_lsm0,uut_ym.reg_rs1}!==8'h81 ||
            {uut_ym_legacy.reg_rs0,uut_ym_legacy.reg_8c_b6,uut_ym_legacy.reg_8c_b5,uut_ym_legacy.reg_8c_b4,uut_ym_legacy.reg_ste,uut_ym_legacy.reg_lsm1,uut_ym_legacy.reg_lsm0,uut_ym_legacy.reg_rs1}!==8'h81) begin
            $display("FEATURE_FAIL MMR current R1fields=%b%b%b%b%b%b b0=%b R12=%b%b%b%b%b%b%b%b bases=%x/%x/%x/%x win=%b/%02x/%b/%02x; pristine R1fields=%b%b%b%b%b%b b0=%b R12=%b%b%b%b%b%b%b%b bases=%x/%x/%x/%x win=%b/%02x/%b/%02x",
                uut_ym.reg_81_b7,uut_ym.reg_disp,uut_ym.reg_ie0,uut_ym.reg_m1,uut_ym.reg_m2,uut_ym.reg_m5,uut_ym.reg_81_b0,
                uut_ym.reg_rs0,uut_ym.reg_8c_b6,uut_ym.reg_8c_b5,uut_ym.reg_8c_b4,uut_ym.reg_ste,uut_ym.reg_lsm1,uut_ym.reg_lsm0,uut_ym.reg_rs1,
                uut_ym.reg_sa,uut_ym.reg_sb,uut_ym.reg_wd,uut_ym.reg_hs,uut_ym.reg_rigt,uut_ym.reg_whp,uut_ym.reg_down,uut_ym.reg_wvp,
                uut_ym_legacy.reg_81_b7,uut_ym_legacy.reg_disp,uut_ym_legacy.reg_ie0,uut_ym_legacy.reg_m1,uut_ym_legacy.reg_m2,uut_ym_legacy.reg_m5,uut_ym_legacy.reg_81_b0,
                uut_ym_legacy.reg_rs0,uut_ym_legacy.reg_8c_b6,uut_ym_legacy.reg_8c_b5,uut_ym_legacy.reg_8c_b4,uut_ym_legacy.reg_ste,uut_ym_legacy.reg_lsm1,uut_ym_legacy.reg_lsm0,uut_ym_legacy.reg_rs1,
                uut_ym_legacy.reg_sa,uut_ym_legacy.reg_sb,uut_ym_legacy.reg_wd,uut_ym_legacy.reg_hs,uut_ym_legacy.reg_rigt,uut_ym_legacy.reg_whp,uut_ym_legacy.reg_down,uut_ym_legacy.reg_wvp); $fatal(1);
        end
        // CPU-visible SAT writes populate the YM's internal SAT cache; they
        // are intentionally not replaced by direct DRAM initialization.
        feature_sat_words[0]=16'h0080; feature_sat_words[1]=16'h0101;
        feature_sat_words[2]=16'h8008; feature_sat_words[3]=16'h007c;
        feature_sat_words[4]=16'h015d; feature_sat_words[5]=16'h0100;
        feature_sat_words[6]=16'ha00a; feature_sat_words[7]=16'h01bc;
        feature_cpu_write_both(23'h600002,16'h4000); feature_cpu_write_both(23'h600002,16'h0002);
        feature_cpu_write_both(23'h600000,16'h0080); feature_cpu_write_both(23'h600000,16'h0101);
        feature_cpu_write_both(23'h600000,16'h8008); feature_cpu_write_both(23'h600000,16'h007c);
        feature_cpu_write_both(23'h600000,16'h015d); feature_cpu_write_both(23'h600000,16'h0100);
        feature_cpu_write_both(23'h600000,16'ha00a); feature_cpu_write_both(23'h600000,16'h01bc);
        timeout=0;
        while ((uut_ym.sat[0]!==21'h040081 || uut_ym.sat[1]!==21'h0ae880 ||
                uut_ym_legacy.sat[0]!==21'h040081 || uut_ym_legacy.sat[1]!==21'h0ae880) &&
                timeout<2*TEST_FRAME_LINES*TEST_LINE_PIXELS*8) begin tick(); timeout=timeout+1; end
        feature_wait_fifo_empty_model(1'b0,sat_status);
        feature_wait_fifo_empty_model(1'b1,sat_status);
        // Empty status retires queued writes; allow the registered serial/VRAM
        // write tail to settle before checking the physical bytes.
        repeat(32) tick();
        $display("FEATURE_SAT cpu bytes=%04x/%04x %04x/%04x %04x/%04x %04x/%04x cache candidate=%06x/%06x pristine=%06x/%06x",
            {ym_vram.mem[physical_addr(16'h8001)],ym_vram.mem[physical_addr(16'h8000)]},
            {ym_vram.mem[physical_addr(16'h8003)],ym_vram.mem[physical_addr(16'h8002)]},
            {ym_vram.mem[physical_addr(16'h8005)],ym_vram.mem[physical_addr(16'h8004)]},
            {ym_vram.mem[physical_addr(16'h8007)],ym_vram.mem[physical_addr(16'h8006)]},
            {ym_vram.mem[physical_addr(16'h8009)],ym_vram.mem[physical_addr(16'h8008)]},
            {ym_vram.mem[physical_addr(16'h800b)],ym_vram.mem[physical_addr(16'h800a)]},
            {ym_vram.mem[physical_addr(16'h800d)],ym_vram.mem[physical_addr(16'h800c)]},
            {ym_vram.mem[physical_addr(16'h800f)],ym_vram.mem[physical_addr(16'h800e)]},uut_ym.sat[0],uut_ym.sat[1],uut_ym_legacy.sat[0],uut_ym_legacy.sat[1]);
        if (uut_ym.sat[0]!==21'h040081 || uut_ym.sat[1]!==21'h0ae880 ||
            uut_ym_legacy.sat[0]!==21'h040081 || uut_ym_legacy.sat[1]!==21'h0ae880) begin
            $display("FEATURE_FAIL CPU SAT writes/cache did not materialize"); $fatal(1);
        end
        for(i=0;i<8;i=i+1) begin
            $display("FEATURE_SAT_WORD i=%0d expected=%04x current=%04x pristine=%04x",i,feature_sat_words[i],
                {ym_vram.mem[physical_addr(16'h8000+i*2+1)],ym_vram.mem[physical_addr(16'h8000+i*2)]},
                {ym_vram_legacy.mem[physical_addr(16'h8000+i*2+1)],ym_vram_legacy.mem[physical_addr(16'h8000+i*2)]});
            if ({ym_vram.mem[physical_addr(16'h8000+i*2+1)],ym_vram.mem[physical_addr(16'h8000+i*2)]}!==feature_sat_words[i] ||
                {ym_vram_legacy.mem[physical_addr(16'h8000+i*2+1)],ym_vram_legacy.mem[physical_addr(16'h8000+i*2)]}!==feature_sat_words[i]) begin
                $display("FEATURE_FAIL CPU SAT word index=%0d expected=%04x current=%04x pristine=%04x",i,feature_sat_words[i],
                    {ym_vram.mem[physical_addr(16'h8000+i*2+1)],ym_vram.mem[physical_addr(16'h8000+i*2)]},
                    {ym_vram_legacy.mem[physical_addr(16'h8000+i*2+1)],ym_vram_legacy.mem[physical_addr(16'h8000+i*2)]}); $fatal(1);
            end
        end
    end
endtask

task feature_capture_frame;
    integer timeout, i, j, target;
    integer native_mismatches, semantic_mismatches, endpoint_errors;
    integer native_details, semantic_details, endpoint_details;
    integer row_native[0:10], row_semantic[0:10], layer_native[0:4], layer_semantic[0:4];
    reg [24:0] expected;
    begin
        feature_guard_r0(feature_line_variant ? 8'h02 : 8'h01);
        for(i=0;i<FEATURE_ROWS;i=i+1) begin feature_row_count[i]=0; feature_row_last[i]=-1; end
        feature_total_samples=0; feature_done=0;
        feature_legacy_armed=0; feature_legacy_started=0; feature_legacy_done=0; feature_legacy_total=0;
        feature_legacy_row_active=0; feature_legacy_row_latched=-1; feature_legacy_prev_h=-1; feature_legacy_native_frames=0;
        feature_candidate_state_guarded=0; feature_legacy_state_guarded=0;
        feature_capture_state_failures=0;
        feature_hs_candidate_events=0; feature_hs_legacy_events=0;
        feature_hs_candidate_load_prev=0; feature_hs_legacy_load_prev=0;
        feature_hs_candidate_select_prev=0; feature_hs_legacy_select_prev=0;
        feature_scroll_trace_candidate_started=0; feature_scroll_trace_candidate_done=0;
        feature_scroll_trace_legacy_started=0; feature_scroll_trace_legacy_done=0;
        feature_scroll_trace_candidate_samples=0; feature_scroll_trace_legacy_samples=0;
        feature_scroll_trace_candidate_pages=0; feature_scroll_trace_legacy_pages=0;
        feature_scroll_trace_candidate_sc=0; feature_scroll_trace_legacy_sc=0;
        feature_scroll_trace_candidate_w570=0; feature_scroll_trace_candidate_w571=0;
        feature_scroll_trace_candidate_w572=0; feature_scroll_trace_candidate_w573=0;
        feature_scroll_trace_legacy_w570=0; feature_scroll_trace_legacy_w571=0;
        feature_scroll_trace_legacy_w572=0; feature_scroll_trace_legacy_w573=0;
        feature_scroll_trace_candidate_overflow=0; feature_scroll_trace_legacy_overflow=0;
        for(i=0;i<FEATURE_ROWS;i=i+1) begin feature_legacy_count[i]=0; feature_legacy_last[i]=-1; end
        feature_target_frame=source_frame_id+1;
        timeout=0;
        while((!feature_done || !feature_legacy_done) && timeout<3*TEST_FRAME_LINES*TEST_LINE_PIXELS*8) begin
            if(source_frame_id>=feature_target_frame && !feature_capture) begin
                feature_capture=1;
                feature_capture_start_time=$time;
                $display("FEATURE_CAPTURE_ARM targetFrame=%0d sourceFrame=%0d elapsedSinceSetup=%0t geometry=%0d/%0d",feature_target_frame,source_frame_id,$time-feature_setup_time,TEST_LINE_PIXELS,TEST_FRAME_LINES);
            end
            tick(); timeout=timeout+1;
        end
        feature_capture=0;
        if(!feature_done || feature_total_samples!=FEATURE_ROWS*320 || !feature_legacy_done || feature_legacy_total!=FEATURE_ROWS*320) begin
            $display("FEATURE_FAIL capture incomplete frame=%0d target=%0d candidate=%0d pristine=%0d",source_frame_id,feature_target_frame,feature_total_samples,feature_legacy_total); $fatal(1);
        end
        native_mismatches=0; semantic_mismatches=0; endpoint_errors=0;
        native_details=0; semantic_details=0; endpoint_details=0;
        for(i=0;i<FEATURE_ROWS;i=i+1) begin row_native[i]=0; row_semantic[i]=0; end
        for(i=0;i<5;i=i+1) begin layer_native[i]=0; layer_semantic[i]=0; end
        for(i=0;i<FEATURE_ROWS;i=i+1) begin
            if(feature_row_count[i]!=320 || feature_legacy_count[i]!=320) begin
                $display("FEATURE_FAIL row capture incomplete row=%0d counts=%0d/%0d",feature_row_y[i],feature_row_count[i],feature_legacy_count[i]); $fatal(1);
            end
            if(feature_current[i][0][23:0]===0 || feature_current[i][319][23:0]===0) begin
                endpoint_errors=endpoint_errors+1;
                if(endpoint_details<8) begin
                    $display("FEATURE_ENDPOINT_FAIL row=%0d candidate=%07x/%07x pristine=%07x/%07x expected=%07x/%07x",
                        feature_row_y[i],feature_current[i][0],feature_current[i][319],feature_legacy[i][0],feature_legacy[i][319],
                        feature_expected_pixel(0,feature_row_y[i],feature_line_variant),feature_expected_pixel(319,feature_row_y[i],feature_line_variant));
                    endpoint_details=endpoint_details+1;
                end
            end
        end
        for(i=0;i<FEATURE_ROWS;i=i+1) begin
            for(j=0;j<320;j=j+1) begin
                if(feature_current[i][j]!==feature_legacy[i][j]) begin
                    native_mismatches=native_mismatches+1;
                    row_native[i]=row_native[i]+1;
                    target=feature_expected_layer(j,feature_row_y[i],feature_line_variant);
                    if(target<0 || target>4) target=4;
                    layer_native[target]=layer_native[target]+1;
                    if(native_details<8) begin
                        $display("FEATURE_NATIVE_DIFF row=%0d x=%0d tuple=%07x/%07x",feature_row_y[i],j,feature_current[i][j],feature_legacy[i][j]);
                        native_details=native_details+1;
                    end
                end
                expected=feature_expected_pixel(j,feature_row_y[i],feature_line_variant);
                if(feature_current[i][j]!==expected) begin
                    semantic_mismatches=semantic_mismatches+1;
                    row_semantic[i]=row_semantic[i]+1;
                    target=feature_expected_layer(j,feature_row_y[i],feature_line_variant);
                    if(target<0 || target>4) target=4;
                    layer_semantic[target]=layer_semantic[target]+1;
                    if(semantic_details<8) begin
                        $display("FEATURE_SEMANTIC_DIFF row=%0d x=%0d expected=%07x candidate=%07x",feature_row_y[i],j,expected,feature_current[i][j]);
                        semantic_details=semantic_details+1;
                    end
                end
            end
        end
        if(feature_csv_fd!=0) begin
            for(i=0;i<FEATURE_ROWS;i=i+1) for(j=0;j<320;j=j+1) begin
                expected=feature_expected_pixel(j,feature_row_y[i],feature_line_variant);
                target=feature_expected_layer(j,feature_row_y[i],feature_line_variant);
                $fdisplay(feature_csv_fd,"PIXEL,%0d,%0d,%0d,%0d,%0d,%07x,%07x,%07x,%0d,%0d,%0d",
                    feature_line_variant ? 2 : 1,feature_target_frame,feature_legacy_native_frames,feature_row_y[i],j,
                    feature_current[i][j],feature_legacy[i][j],expected,target,row_native[i],row_semantic[i]);
            end
            for(i=0;i<FEATURE_ROWS;i=i+1) $fdisplay(feature_csv_fd,"ROW,%0d,0,0,%0d,-1,,,,,%0d,%0d",feature_line_variant ? 2 : 1,feature_row_y[i],row_native[i],row_semantic[i]);
            for(i=0;i<5;i=i+1) $fdisplay(feature_csv_fd,"LAYER,%0d,0,0,-1,-1,,,,%0d,%0d,%0d",feature_line_variant ? 2 : 1,i,layer_native[i],layer_semantic[i]);
            $fflush(feature_csv_fd);
        end
        $display("FEATURE_COMPARE totals samples=%0d native_differences=%0d semantic_differences=%0d black_endpoint_rows=%0d capture_state_failures=%0d first_details=%0d/%0d/%0d",
            FEATURE_ROWS*320,native_mismatches,semantic_mismatches,endpoint_errors,feature_capture_state_failures,native_details,semantic_details,endpoint_details);
        for(i=0;i<FEATURE_ROWS;i=i+1) $display("FEATURE_ROW_COUNTS y=%0d samples=%0d/%0d native=%0d semantic=%0d",feature_row_y[i],feature_row_count[i],feature_legacy_count[i],row_native[i],row_semantic[i]);
        for(i=0;i<5;i=i+1) $display("FEATURE_LAYER_COUNTS layer=%0d native=%0d semantic=%0d",i,layer_native[i],layer_semantic[i]);
        $display("FEATURE_HSCROLL_FETCH_COUNTS candidate=%0d pristine=%0d window=V0/H470..511; first active origin traced separately",feature_hs_candidate_events,feature_hs_legacy_events);
        if(native_mismatches!=0 || semantic_mismatches!=0 || endpoint_errors!=0 || feature_capture_state_failures!=0) begin
            for(i=0;i<FEATURE_ROWS;i=i+1) begin
                if(feature_current[i][0]!==feature_legacy[i][0] || feature_current[i][0]!==feature_expected_pixel(0,feature_row_y[i],feature_line_variant)) begin
                    feature_trace_source_descriptor(0,feature_row_y[i],feature_line_variant);
                end
            end
            $display("FEATURE_FAIL all-row comparison failed; see bounded details and totals above"); $fatal(1);
        end
        feature_sprite_visible=0; feature_window_visible=0; feature_a_visible=0; feature_b_visible=0;
        feature_palette_mask=0; feature_top_sprite=0; feature_bottom_sprite=0;
        for(i=0;i<FEATURE_ROWS;i=i+1) for(j=0;j<320;j=j+1) begin
            expected=feature_expected_pixel(j,feature_row_y[i],feature_line_variant);
            if(expected[23:0]!=0) begin
                case(feature_expected_layer(j,feature_row_y[i],feature_line_variant))
                    0: feature_a_visible=feature_a_visible+1;
                    1: feature_b_visible=feature_b_visible+1;
                    2: feature_window_visible=feature_window_visible+1;
                    3: begin
                        feature_sprite_visible=feature_sprite_visible+1;
                        if(feature_row_y[i]==0 && j<4) feature_top_sprite=feature_top_sprite+1;
                        if(feature_row_y[i]==221 && j>=316) feature_bottom_sprite=feature_bottom_sprite+1;
                    end
                endcase
                for(target=0;target<8;target=target+1) if(expected[23:0]==feature_rgb_code(target)) feature_palette_mask=feature_palette_mask | (1<<target);
            end
        end
        if(feature_sprite_visible==0 || feature_top_sprite==0 || feature_bottom_sprite==0 ||
           feature_window_visible==0 || feature_a_visible==0 || feature_b_visible==0 ||
           $countones(feature_palette_mask)<4) begin
            $display("FEATURE_FAIL semantic coverage sprite/window/A/B=%0d/%0d/%0d/%0d",feature_sprite_visible,feature_window_visible,feature_a_visible,feature_b_visible); $fatal(1);
        end
        $display("FEATURE_COVERAGE rows=%0d samples=%0d sprites=%0d top/bottom=%0d/%0d window=%0d scrollA/B=%0d/%0d paletteMask=%02x",FEATURE_ROWS,feature_total_samples,
            feature_sprite_visible,feature_top_sprite,feature_bottom_sprite,feature_window_visible,feature_a_visible,feature_b_visible,feature_palette_mask);
    end
endtask

task run_features_profile;
    integer timeout, i, line_scroll_differences;
    begin
        feature_csv_fd=$fopen("feature-tuples.csv","w");
        if(feature_csv_fd==0) begin $display("FEATURE_FAIL cannot open feature-tuples.csv"); $fatal(1); end
        $fdisplay(feature_csv_fd,"record,variant,candidate_frame,pristine_frame,y,x,candidate,pristine,expected,layer,row_native_total,row_semantic_total");
        feature_initialize_scene();
        feature_setup_time=$time;
        feature_capture_frame();
        // Compact line/2-cell scroll variant: same scene and renderer lock,
        // install its aligned H offsets, then change R11 and capture a second
        // physical frame. The first global capture used 5/-3 at FC00/FC02.
        feature_hscroll[0]=16'd16; feature_hscroll[1]=16'h03e0;
        feature_set_word(16'hfc00,feature_hscroll[0]);
        feature_set_word(16'hfc02,feature_hscroll[1]);
        if ({ym_vram.mem[physical_addr(16'hfc00)],ym_vram.mem[physical_addr(16'hfc01)],
             ym_vram.mem[physical_addr(16'hfc02)],ym_vram.mem[physical_addr(16'hfc03)]} !==
            {feature_hscroll[0][7:0],feature_hscroll[0][15:8],feature_hscroll[1][7:0],feature_hscroll[1][15:8]} ||
            {ym_vram_legacy.mem[physical_addr(16'hfc00)],ym_vram_legacy.mem[physical_addr(16'hfc01)],
             ym_vram_legacy.mem[physical_addr(16'hfc02)],ym_vram_legacy.mem[physical_addr(16'hfc03)]} !==
            {feature_hscroll[0][7:0],feature_hscroll[0][15:8],feature_hscroll[1][7:0],feature_hscroll[1][15:8]}) begin
            $display("FEATURE_FAIL line Hscroll descriptor FC00/FC02 mismatch current=%02x%02x/%02x%02x pristine=%02x%02x/%02x%02x",
                ym_vram.mem[physical_addr(16'hfc01)],ym_vram.mem[physical_addr(16'hfc00)],ym_vram.mem[physical_addr(16'hfc03)],ym_vram.mem[physical_addr(16'hfc02)],
                ym_vram_legacy.mem[physical_addr(16'hfc01)],ym_vram_legacy.mem[physical_addr(16'hfc00)],ym_vram_legacy.mem[physical_addr(16'hfc03)],ym_vram_legacy.mem[physical_addr(16'hfc02)]); $fatal(1);
        end
        $display("FEATURE_HSCROLL line profile FC00/FC02=%04x/%04x",feature_hscroll[0],feature_hscroll[1]);
        feature_cpu_write_both(23'h600002,16'h8b07);
        feature_line_variant=1;
        timeout=0;
        while(!uut_ym.passive_render_ready && timeout<2*TEST_FRAME_LINES*TEST_LINE_PIXELS*8) begin tick(); timeout=timeout+1; end
        if(!uut_ym.passive_render_ready) begin $display("FEATURE_FAIL line-scroll variant did not remain/reacquire ready"); $fatal(1); end
        feature_setup_time=$time;
        feature_capture_frame();
        line_scroll_differences=0;
        for(i=0;i<320;i=i+1) begin
            if(feature_expected_pixel(i,7,1)!==feature_expected_pixel(i,7,0)) line_scroll_differences=line_scroll_differences+1;
            if(feature_expected_pixel(i,8,1)!==feature_expected_pixel(i,8,0)) line_scroll_differences=line_scroll_differences+1;
        end
        if(line_scroll_differences==0 || feature_hscroll[14]==feature_hscroll[16] ||
           feature_vsram[0]==feature_vsram[2] || feature_vsram[2]==feature_vsram[4]) begin
            $display("FEATURE_FAIL line/column scroll stimulus is semantically vacuous lineDiff=%0d H=%04x/%04x V=%03x/%03x/%03x",
                line_scroll_differences,feature_hscroll[14],feature_hscroll[16],feature_vsram[0],feature_vsram[2],feature_vsram[4]); $fatal(1);
        end
        for(i=0;i<2;i=i+1) begin
            if(feature_current[2][15+i*16]!==feature_expected_pixel(15+i*16,7,1) ||
               feature_current[2][16+i*16]!==feature_expected_pixel(16+i*16,7,1) ||
               feature_current[3][15+i*16]!==feature_expected_pixel(15+i*16,8,1) ||
               feature_current[3][16+i*16]!==feature_expected_pixel(16+i*16,8,1)) begin
                $display("FEATURE_FAIL line-scroll edge oracle x=%0d/%0d y=7/8 got=%07x/%07x/%07x/%07x",15+i*16,16+i*16,
                    feature_current[2][15+i*16],feature_current[2][16+i*16],feature_current[3][15+i*16],feature_current[3][16+i*16]); $fatal(1);
            end
        end
        if(feature_cpu_current_accepts!=25 || feature_cpu_legacy_accepts!=25) begin
            $display("FEATURE_FAIL isolated CPU transaction count candidate/pristine=%0d/%0d expected25 each",feature_cpu_current_accepts,feature_cpu_legacy_accepts); $fatal(1);
        end
        $display("FEATURE_PROFILE PASS geometry=%0d lines=%0d width=%0d SAT-cache=%06x/%06x CPU-acks=%0d/%0d lineScrollDiffs=%0d",TEST_GEOMETRY_384_260,TEST_FRAME_LINES,TEST_LINE_PIXELS,uut_ym.sat[0],uut_ym.sat[1],feature_cpu_current_accepts,feature_cpu_legacy_accepts,line_scroll_differences);
        $fclose(feature_csv_fd);
        feature_csv_fd=0;
    end
endtask
