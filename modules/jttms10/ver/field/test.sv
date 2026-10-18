`timescale 1ns/1ps

module test;
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst = 1;
    reg req = 0;
    reg we = 0, reverse = 0;
    reg [31:0] addr = 0, wdata = 0;
    reg [5:0] size = 0;
    wire ack;
    wire [31:0] rdata;
    wire word_req, word_we, word_lock;
    wire [31:0] word_addr;
    wire [15:0] word_wdata;
    reg [15:0] word_rdata = 0;
    reg word_ack = 0;
    reg word_restart = 0;

    jttms10_field dut(
        .clk(clk), .rst(rst), .req(req), .we(we), .addr(addr),
        .wdata(wdata), .size(size),.reverse(reverse), .ack(ack), .rdata(rdata),
        .word_req(word_req), .word_we(word_we), .word_lock(word_lock),
        .word_addr(word_addr),
        .word_wdata(word_wdata), .word_rdata(word_rdata), .word_ack(word_ack),
        .word_restart(word_restart)
    );

    reg [15:0] mem [0:15];
    reg reference_bits [0:255];
    reg busy = 0;
    reg held_we;
    reg held_lock;
    reg [31:0] held_addr;
    reg [15:0] held_wdata;
    reg pending_rmw = 0;
    reg [31:0] pending_rmw_addr;
    integer delay_left = 0;
    integer transactions = 0;
    integer restart_reads = 0, restart_writes = 0;
    integer i, j, offset, width, watchdog, direction, covered_bits, word_bit;
    reg check_order=0, expected_descend=0;
    reg [31:0] expected_word_addr=0, requested_addr=0;
    reg [5:0] requested_size=0;
    reg [31:0] restart_addr=128;
    reg [31:0] data, expected;

    // A registered word responder with changing waits. Every accepted
    // request must keep its address, direction and data until acknowledgement.
    always @(posedge clk) begin
        if (rst) begin
            word_ack <= 0;
            word_rdata <= 0;
            busy <= 0;
            pending_rmw <= 0;
            delay_left <= 0;
            restart_reads <= 0;
            restart_writes <= 0;
        end else if (word_ack) begin
            word_ack <= 0;
        end else if (word_restart) begin
            // HOLD discards the previous lock. The pending partial write is
            // canceled at this edge, so its next physical cycle must read.
            if (word_req || word_we || word_lock || !pending_rmw)
                $fatal(1, "restart did not cancel pending partial write");
            pending_rmw <= 0;
        end else if (!busy && word_req) begin
            if (word_addr[3:0] !== 4'd0 || word_addr > 32'd240)
                $fatal(1, "unaligned or out-of-range word address %h", word_addr);
            if(check_order) begin
                if(word_addr!==expected_word_addr)
                    $fatal(1,"field word order got=%h expected=%h descending=%b",word_addr,expected_word_addr,expected_descend);
                if(we) begin
                    covered_bits=0;
                    for(word_bit=0;word_bit<32;word_bit=word_bit+1)
                        if(word_bit<requested_size && ((requested_addr+word_bit)&32'hfffffff0)==word_addr)
                            covered_bits=covered_bits+1;
                    if(!word_we && covered_bits==16)
                        $fatal(1,"unnecessary RMW read for a complete field word");
                end
                if(word_we || !we)
                    expected_word_addr<=expected_word_addr+(expected_descend ? 32'hfffffff0 : 32'd16);
            end
            if (pending_rmw) begin
                if (!word_lock || !word_we || word_addr !== pending_rmw_addr)
                    $fatal(1, "partial-word read/write lock broken");
                pending_rmw <= 0;
            end else if (word_lock) begin
                if (word_we || !we)
                    $fatal(1, "lock asserted without a partial-word read");
                pending_rmw <= 1;
                pending_rmw_addr <= word_addr;
            end
            held_we <= word_we;
            held_lock <= word_lock;
            held_addr <= word_addr;
            held_wdata <= word_wdata;
            if (word_addr == restart_addr) begin
                if (word_we) restart_writes <= restart_writes + 1;
                else restart_reads <= restart_reads + 1;
            end
            delay_left <= transactions % 4;
            transactions <= transactions + 1;
            busy <= 1;
        end else if (busy) begin
            if (!word_req || word_we !== held_we ||
                word_lock !== held_lock || word_addr !== held_addr ||
                word_wdata !== held_wdata)
                $fatal(1, "word request changed before acknowledgement");
            if (delay_left != 0)
                delay_left <= delay_left - 1;
            else begin
                word_rdata <= mem[held_addr >> 4];
                if (held_we) mem[held_addr >> 4] <= held_wdata;
                word_ack <= 1;
                busy <= 0;
            end
        end
    end

    task transact;
        input do_write;
        input [31:0] bit_addr, write_data;
        input [5:0] bit_size;
        input [31:0] expected_read;
        begin
            @(negedge clk);
            check_order=1;
            expected_descend=reverse && do_write;
            requested_addr=bit_addr;requested_size=bit_size;
            expected_word_addr={bit_addr[31:4],4'b0};
            if(expected_descend) expected_word_addr=expected_word_addr+((((bit_addr&15)+bit_size-1)>>4)<<4);
            req = 1;
            we = do_write;
            addr = bit_addr;
            wdata = write_data;
            size = bit_size;
            watchdog = 0;
            while (!ack && watchdog < 300) begin
                @(negedge clk);
                watchdog = watchdog + 1;
            end
            if (!ack) $fatal(1, "field request timed out addr=%d size=%d", bit_addr,bit_size);
            if (!do_write && rdata !== expected_read)
                $fatal(1, "read addr=%d size=%d got=%08h expected=%08h",
                    bit_addr,bit_size,rdata,expected_read);
            // ack is held until req falls; changing inputs while held must
            // not launch another architectural request.
            check_order=0;
            addr = 32'hffff_ffff;
            wdata = ~write_data;
            req = 0;
            @(negedge clk);
        end
    endtask

    task compare_memory;
        integer bit_index;
        begin
            for (bit_index = 0; bit_index < 256; bit_index = bit_index + 1)
                if (mem[bit_index >> 4][bit_index & 15] !== reference_bits[bit_index])
                    $fatal(1, "memory changed outside field at bit %0d",bit_index);
        end
    endtask

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            mem[i] = 16'h4a39 ^ (16'h1257 * i);
            for (j = 0; j < 16; j = j + 1)
                reference_bits[16*i+j] = mem[i][j];
        end
        repeat (3) @(negedge clk);
        rst = 0;
        for(direction=0;direction<2;direction=direction+1) begin
        reverse=direction!=0;
        for (offset = 0; offset < 16; offset = offset + 1)
            for (width = 1; width <= 32; width = width + 1) begin
                data = $random;
                for (j = 0; j < width; j = j + 1)
                    reference_bits[32+offset+j] = data[j];
                transact(1,32+offset,data,width[5:0],0);
                compare_memory();
                expected = 0;
                for (j = 0; j < width; j = j + 1)
                    expected[j] = reference_bits[32+offset+j];
                transact(0,32+offset,0,width[5:0],expected);
            end

        end
        reverse=0;

        // HOLD intervenes after the partial read but before its write. An
        // external owner changes the unprotected bits while HOLD is active.
        // The restarted pair must read that new value before merging data.
        @(negedge clk);
        mem[8] = 16'ha0a0;
        req = 1;
        we = 1;
        addr = 32'd131;
        wdata = 32'h15;
        size = 6'd5;
        watchdog = 0;
        while (!(dut.state == dut.WRITE && word_req && word_we && word_lock)
               && watchdog < 100) begin
            @(negedge clk);
            watchdog = watchdog + 1;
        end
        if (watchdog == 100) $fatal(1, "RMW read did not reach pending write");
        word_restart = 1;
        mem[8] = 16'h5f5f; // changed by the temporary external bus owner
        #1;
        if (word_req || word_we || word_lock)
            $fatal(1, "pending stale write visible during restart");
        @(negedge clk);
        word_restart = 0;
        watchdog = 0;
        while (!ack && watchdog < 100) begin
            @(negedge clk);
            watchdog = watchdog + 1;
        end
        if (!ack) $fatal(1, "restarted field write timed out");
        if (restart_reads != 2 || restart_writes != 1)
            $fatal(1, "restart issued %0d reads and %0d writes",restart_reads,restart_writes);
        if (mem[8] !== ((16'h5f5f & ~16'h00f8) | (16'h0015 << 3)))
            $fatal(1, "restart merged stale word, got=%h",mem[8]);
        req = 0;
        @(negedge clk);

        // Descending multiword write: HOLD breaks its first, high partial
        // word. Re-reading foreign changes must not alter later low words.
        @(negedge clk);
        reverse=1;restart_addr=160;restart_reads=0;restart_writes=0;
        mem[8]=16'ha0a0;mem[9]=16'hb0b0;mem[10]=16'hc0c0;
        for(j=0;j<16;j=j+1) begin
            reference_bits[128+j]=(16'ha0a0>>j)&1;
            reference_bits[144+j]=(16'hb0b0>>j)&1;
            reference_bits[160+j]=(16'hc0c0>>j)&1;
        end
        req=1;we=1;addr=131;wdata=32'hd36c9b6d;size=32;watchdog=0;
        while(!(dut.state==dut.WRITE && word_req && word_we && word_lock && word_addr==160) && watchdog<100) begin
            @(negedge clk);watchdog=watchdog+1;
        end
        if(watchdog==100) $fatal(1,"descending RMW did not reach high partial write");
        word_restart=1;mem[10]=16'h5f5f;
        for(j=0;j<16;j=j+1) reference_bits[160+j]=(16'h5f5f>>j)&1;
        for(j=0;j<32;j=j+1) reference_bits[131+j]=wdata[j];
        #1;if(word_req || word_we || word_lock) $fatal(1,"descending stale write survived restart");
        @(negedge clk);word_restart=0;watchdog=0;
        while(!ack && watchdog<300) begin @(negedge clk);watchdog=watchdog+1;end
        if(!ack || restart_reads!=2 || restart_writes!=1)
            $fatal(1,"descending restart read/write coverage failed %0d/%0d",restart_reads,restart_writes);
        compare_memory();req=0;
        @(negedge clk);reverse=0;

        // Reset discards an outstanding read. A new field must still work.
        @(negedge clk);
        req = 1;
        we = 0;
        addr = 32'd47;
        size = 6'd32;
        repeat (3) @(negedge clk);
        rst = 1;
        req = 0;
        @(negedge clk);
        if (word_req || word_lock || ack)
            $fatal(1, "reset did not clear active request");
        rst = 0;
        expected = 0;
        for (j = 0; j < 32; j = j + 1)
            expected[j] = reference_bits[47+j];
        transact(0,32'd47,0,6'd32,expected);
        $display("PASS: 1024 write/read vectors, forward/descending order, both HOLD restarts, waits and reset");
        $finish;
    end
endmodule
