module test;
    reg clk=0, rs_ext=0, rd_ext=0, wa_ext=0, we=0;
    reg [4:0] rs=0, rd=0, wa=0;
    reg [31:0] wd=0;
    wire [31:0] qs, qd;
    reg [31:0] expected [0:63];
    reg valid [0:63];
    reg [31:0] prior_qs, prior_qd;
    bit have_prior=0;
    integer cycles=0, i, j;
    reg [31:0] rng=32'h34010ace;
    reg [5:0] sidx,didx,widx;
    reg [31:0] sold,dold;
    reg svalid,dvalid;

    jttms10_regs dut(.clk(clk),.rs(rs),.rd(rd),.wa(wa),
        .rs_ext(rs_ext),.rd_ext(rd_ext),.wa_ext(wa_ext),
        .we(we),.wd(wd),.qs(qs),.qd(qd));

    function automatic [5:0] canon(input bit ext, input [4:0] idx);
        canon = ext ? {1'b1,idx} :
                (idx[3:0]==4'hf ? 6'd15 : {1'b0,idx});
    endfunction
    function automatic [31:0] next_rng(input [31:0] x);
        next_rng = x * 32'd1664525 + 32'd1013904223;
    endfunction
    task automatic cycle(input bit se,input [4:0] si,
                         input bit de,input [4:0] di,
                         input bit wr,input bit we_in,input [4:0] wi,
                         input [31:0] data);
      begin
        rs_ext=se; rs=si; rd_ext=de; rd=di;
        wa_ext=wr; wa=wi; we=we_in; wd=data;
        sidx=canon(se,si); didx=canon(de,di); widx=canon(wr,wi);
        sold=expected[sidx]; dold=expected[didx];
        svalid=valid[sidx]; dvalid=valid[didx];
        #2;
        if (have_prior && (qs !== prior_qs || qd !== prior_qd))
          $fatal(1,"async read change before clock at cycle %0d",cycles);
        clk=1;
        #1;
        if(svalid && qs !== sold)
          $fatal(1,"source read cycle=%0d logical=%0d physical=%0d got=%h exp=%h",
                 cycles,{se,si},sidx,qs,sold);
        if(dvalid && qd !== dold)
          $fatal(1,"destination read cycle=%0d logical=%0d physical=%0d got=%h exp=%h",
                 cycles,{de,di},didx,qd,dold);
        prior_qs=qs; prior_qd=qd; have_prior=1;
        if(we_in) begin expected[widx]=data; valid[widx]=1; end
        #2; clk=0; cycles=cycles+1;
      end
    endtask

    initial begin
      for(i=0;i<64;i=i+1) begin expected[i]=0; valid[i]=0; end
      // Initialize all 64 logical addresses. Architectural 31 intentionally
      // aliases 15, while scratch 47 and 63 must retain independent values.
      for(i=0;i<64;i=i+1)
        cycle(i>=32,i[4:0], i>=32,i[4:0],
              i>=32,1'b1,i[4:0],32'hcafe0000+i);
      // Both synchronous read ports traverse every logical address in opposite
      // directions; this also checks mirroring and retention after writes.
      for(i=0;i<64;i=i+1)
        cycle(i>=32,i[4:0],(63-i)>=32,(63-i)&31,
              1'b0,1'b0,5'd0,32'd0);
      // Directed aliases and same-cycle read/write must return OLD data.
      cycle(0,5'd15,0,5'd31,0,1,5'd31,32'h15153131);
      cycle(0,5'd31,1,5'd15,1,1,5'd15,32'h47474747);
      cycle(1,5'd31,0,5'd15,1,1,5'd31,32'h63636363);
      cycle(1,5'd15,1,5'd31,0,1,5'd15,32'h15151515);
      cycle(0,5'd31,1,5'd15,0,0,5'd0,0);
      cycle(1,5'd31,0,5'd31,0,0,5'd0,0);
      // Deterministic mixed-port pressure, including same-address collisions.
      for(j=0;j<512;j=j+1) begin
        rng=next_rng(rng);
        cycle(rng[5],rng[4:0],rng[11],rng[10:6],
              rng[17],rng[18],rng[16:12],rng ^ 32'h5eeda55a);
      end
      $display("PASS RF64 cycles=%0d all logical addresses, both reads, aliases, collisions",cycles);
      $finish;
    end
endmodule
