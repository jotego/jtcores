// Counts memory and port activity by region, to attribute long stalls.
module probe;
integer wr_rom=0, wr_work=0, wr_obj=0, wr_pal=0, wr_snd=0, wr_bank=0, wr_other=0;
integer io_rd=0, io_wr=0, halted=0;
integer rd_rom=0, rd_work=0, rd_obj=0, rd_pal=0, rd_snd=0, rd_bank=0;
reg mrd_l=0;
// sound CPU activity
integer s_m1n=0, s_rom=0, s_shr_rd=0, s_shr_wr=0, s_ram=0, s_io=0;
reg s_m1l=0, s_mrd_l=0, s_mwr_l=0, s_io_l=0;
reg [15:0] s_pc_min=16'hffff, s_pc_max=0;
reg mreq_l=0, iord_l2=0;
reg [15:0] first_addr=0, last_addr=0;
integer nwr=0;
always @(posedge tb_main.clk) begin
    if( !tb_main.rst ) begin
        // one count per bus cycle
        mreq_l <= tb_main.u_main.mreq & tb_main.u_main.wr;
        if( (tb_main.u_main.mreq & tb_main.u_main.wr) && !mreq_l ) begin
            nwr = nwr + 1;
            last_addr = tb_main.u_main.A;
            if( nwr == 1 ) first_addr = tb_main.u_main.A;
            case( tb_main.u_main.A[15:12] )
                4'h7: wr_work = wr_work + 1;
                4'h8: wr_obj  = wr_obj  + 1;
                4'ha: wr_pal  = wr_pal  + 1;
                4'hc: wr_snd  = wr_snd  + 1;
                default: wr_other = wr_other + 1;
            endcase
        end
        // reads by region: a wait on the sound CPU would show up as a stream
        // of reads from the shared RAM at C000-C7FF
        mrd_l <= tb_main.u_main.mreq & tb_main.u_main.rd;
        if( (tb_main.u_main.mreq & tb_main.u_main.rd) && !mrd_l ) begin
            if( tb_main.u_main.A < 16'h7000 ) rd_rom = rd_rom + 1;
            else case( tb_main.u_main.A[15:12] )
                4'h7: rd_work = rd_work + 1;
                4'h8: rd_obj  = rd_obj  + 1;
                4'ha: rd_pal  = rd_pal  + 1;
                4'hc: rd_snd  = rd_snd  + 1;
                default: rd_bank = rd_bank + 1;
            endcase
        end
        iord_l2 <= tb_main.u_main.iorq & tb_main.u_main.rd;
        if( (tb_main.u_main.iorq & tb_main.u_main.rd) && !iord_l2 ) io_rd = io_rd + 1;
        if( tb_main.dsp_halt ) halted = halted + 1;

        // The sound CPU boots by writing FF to C000 and 00 to C002, then
        // spins until the main CPU puts AA into C002. Watch for that byte.
        if( (tb_main.u_main.mreq & tb_main.u_main.wr) && !mreq_l
            && tb_main.u_main.A == 16'hc002 ) begin
            $display("  main CPU wrote %02x to C002 at %0t ms",
                     tb_main.u_main.cpu_dout, $time/1000000000);
        end

        // --- the sound CPU, counted the same way
        s_m1l <= tb_main.u_snd.dbg_m1;
        if( tb_main.u_snd.dbg_m1 && !s_m1l ) begin
            s_m1n = s_m1n + 1;
            if( tb_main.u_snd.A < s_pc_min ) s_pc_min = tb_main.u_snd.A;
            if( tb_main.u_snd.A > s_pc_max ) s_pc_max = tb_main.u_snd.A;
        end
        s_mrd_l <= tb_main.u_snd.mreq & tb_main.u_snd.rd;
        if( (tb_main.u_snd.mreq & tb_main.u_snd.rd) && !s_mrd_l ) begin
            if( !tb_main.u_snd.A[15] )                     s_rom    = s_rom + 1;
            else if( tb_main.u_snd.A[15:11]==5'b11000 )    s_shr_rd = s_shr_rd + 1;
            else                                           s_ram    = s_ram + 1;
        end
        s_mwr_l <= tb_main.u_snd.mreq & tb_main.u_snd.wr;
        if( (tb_main.u_snd.mreq & tb_main.u_snd.wr) && !s_mwr_l )
            if( tb_main.u_snd.A[15:11]==5'b11000 ) s_shr_wr = s_shr_wr + 1;
        s_io_l <= tb_main.u_snd.iorq;
        if( tb_main.u_snd.iorq && !s_io_l ) s_io = s_io + 1;
    end
end
task report;
begin
    $display("  memory writes  : work=%0d obj=%0d pal=%0d shared=%0d other=%0d (total %0d)",
             wr_work, wr_obj, wr_pal, wr_snd, wr_other, nwr);
    $display("  port reads     : %0d", io_rd);
    $display("  memory reads   : rom=%0d work=%0d obj=%0d pal=%0d shared=%0d banked=%0d",
             rd_rom, rd_work, rd_obj, rd_pal, rd_snd, rd_bank);
    $display("  clocks halted by the DSP: %0d", halted);
    $display("  first write addr %04x, last %04x", first_addr, last_addr);
    $display("  sound CPU: M1 fetches=%0d rom reads=%0d local ram=%0d",
             s_m1n, s_rom, s_ram);
    $display("             shared RAM reads=%0d writes=%0d, any I/O cycles=%0d",
             s_shr_rd, s_shr_wr, s_io);
    $display("             PC range seen %04x..%04x", s_pc_min, s_pc_max);
end
endtask
endmodule
