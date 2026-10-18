`timescale 1ns/1ps
module test;
    reg [4:0] psize=1,ppop=0;
    reg transparency=0,source_is_register=0;
    reg [15:0] pmask=0,source_pixel=0,dest_pixel=0;
    reg [3:0] src_addr_lo=0,dst_addr_lo=0;
    wire [31:0] alu_a,alu_b,alu_result;
    wire [3:0] alu_op;
    wire alu_borrow,alu_n,alu_z,alu_v;
    wire valid,transparent,alu_req;
    wire [15:0] visible_source,result_pixel,write_mask,write_pixel;
    jttms10_pixel dut(
        .psize(psize),.ppop(ppop),.transparency(transparency),.pmask(pmask),
        .source_is_register(source_is_register),.src_addr_lo(src_addr_lo),
        .dst_addr_lo(dst_addr_lo),.source_pixel(source_pixel),
        .dest_pixel(dest_pixel),.alu_a(alu_a),.alu_b(alu_b),.alu_op(alu_op),
        .alu_req(alu_req),
        .alu_result(alu_result),.alu_borrow(alu_borrow),.valid(valid),
        .visible_source(visible_source),.result_pixel(result_pixel),
        .write_mask(write_mask),.write_pixel(write_pixel),.transparent(transparent)
    );
    jttms10_alu shared_alu(.a(alu_a),.b(alu_b),.op(alu_op),.cin(1'b0), .split16(1'b0),
        .result(alu_result),.n(alu_n),.z(alu_z),.c(alu_borrow),.v(alu_v));

    integer checks=0;
    integer mask,sp,dp,s,d,r,w,wm,trans,good;
    task check;
    begin
        mask=(1<<psize)-1;
        if (psize==16) mask=16'hffff;
        if (!(psize==1 || psize==2 || psize==4 || psize==8 || psize==16)) mask=0;
        good=(mask!=0) && (ppop<16 || (ppop<=21 && psize>=4));
        sp=(pmask >> src_addr_lo) & mask;
        dp=(pmask >> dst_addr_lo) & mask;
        s=(source_pixel & mask) & (source_is_register ? mask : ~sp);
        d=(dest_pixel & mask) & ~dp;
        r=0;
        case (ppop)
            0:r=s;
            1:r=s & d;
            2:r=s & ~d;
            3:r=0;
            4:r=s | ~d;
            5:r=~(s^d);
            6:r=~d;
            7:r=~(s|d);
            8:r=s|d;
            9:r=d;
            10:r=s^d;
            11:r=~s & d;
            12:r=-1;
            13:r=~s | d;
            14:r=~(s&d);
            15:r=~s;
            16:r=d+s;
            17:r=((d+s)>mask) ? mask : (d+s);
            18:r=d-s;
            19:r=(d<s) ? 0 : (d-s);
            20:r=(d>s) ? d : s;
            21:r=(d<s) ? d : s;
            default:r=0;
        endcase
        r=r & mask;
        trans=good && transparency && ((r & ~dp)==0);
        wm=(good && !trans) ? (mask & ~dp) : 0;
        w=(dest_pixel & ~wm) | (r & wm);
        #1;
        if (valid !== (good!=0) || alu_req !== ((good!=0) && ppop>=16) ||
            visible_source !== s[15:0] ||
            result_pixel !== r[15:0] || transparent !== (trans!=0) ||
            write_mask !== wm[15:0] || write_pixel !== w[15:0])
            $fatal(1,"pixel mismatch size=%0d op=%0d reg=%0d src=%04x dst=%04x pm=%04x sa=%0d da=%0d T=%0d got v/s/r/t/wm/w=%b/%04x/%04x/%b/%04x/%04x expected %b/%04x/%04x/%b/%04x/%04x",
                psize,ppop,source_is_register,source_pixel,dest_pixel,pmask,
                src_addr_lo,dst_addr_lo,transparency,valid,visible_source,
                result_pixel,transparent,write_mask,write_pixel,good!=0,
                s[15:0],r[15:0],trans!=0,wm[15:0],w[15:0]);
        if (ppop>=16 && ppop<=21 && good) begin
            if (alu_a !== s || alu_b !== d ||
                alu_op !== ((ppop<=17) ? 4'd1 : 4'd3))
                $fatal(1,"arithmetic did not use shared ALU operands/op");
        end
        checks=checks+1;
    end
    endtask
    integer si,op,regsrc,t,sa,da,k;
    initial begin
        // Every defined/reserved PPOP over every legal pixel width, both
        // source types, all aligned source and destination lanes, and T modes.
        for (si=0;si<5;si=si+1) begin
            case (si)
                0:psize=1; 1:psize=2; 2:psize=4;
                3:psize=8; default:psize=16;
            endcase
            for (op=0;op<32;op=op+1) begin
                ppop=op;
                for (regsrc=0;regsrc<2;regsrc=regsrc+1) begin
                    source_is_register=regsrc;
                    for (t=0;t<2;t=t+1) begin
                        transparency=t;
                        for (sa=0;sa<16;sa=sa+psize) begin
                            src_addr_lo=sa;
                            for (da=0;da<16;da=da+psize) begin
                                dst_addr_lo=da;
                                for (k=0;k<4;k=k+1) begin
                                    case (k)
                                        0:pmask=0;
                                        1:pmask=16'h5aa5;
                                        2:pmask=16'hffff;
                                        default:pmask=$random;
                                    endcase
                                    source_pixel=$random;
                                    dest_pixel=$random;
                                    check();
                                end
                            end
                        end
                    end
                end
            end
            // Explicit unsigned arithmetic boundaries and mask-before-T.
            pmask=0; src_addr_lo=0; dst_addr_lo=0;
            source_is_register=1; transparency=0;
            for (op=16;op<=21;op=op+1) begin
                ppop=op; source_pixel=(1<<psize)-1;
                dest_pixel=1; check();
                source_pixel=1; dest_pixel=0; check();
                source_pixel=(1<<psize)-1;
                dest_pixel=(1<<psize)-1; check();
            end
            ppop=0; transparency=1; pmask=16'hffff;
            source_pixel=16'hffff; dest_pixel=16'ha5a5; check();
        end
        // Undefined pixel widths do not silently acquire an operation.
        psize=3; ppop=0; check();
        psize=0; ppop=17; check();
        $display("jttms10_pixel PASS (%0d cases)",checks); $finish;
    end
endmodule
