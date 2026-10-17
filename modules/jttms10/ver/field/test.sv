`timescale 1ns/1ps

module test;
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst = 1;
    reg req = 0;
    reg we = 0;
    reg [31:0] addr = 0, wdata = 0;
    reg [5:0] size = 0;
    wire ack;
    wire [31:0] rdata;
    wire word_req, word_we, word_lock;
    wire [31:0] word_addr;
    wire [15:0] word_wdata;
    reg [15:0] word_rdata = 0;
    reg word_ack = 0;

    jttms10_field dut(
        .clk(clk), .rst(rst), .req(req), .we(we), .addr(addr),
        .wdata(wdata), .size(size), .ack(ack), .rdata(rdata),
        .word_req(word_req), .word_we(word_we), .word_lock(word_lock),
        .word_addr(word_addr),
        .word_wdata(word_wdata), .word_rdata(word_rdata), .word_ack(word_ack)
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
    integer i, j, offset, width, watchdog;
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
        end else if (word_ack) begin
            word_ack <= 0;
        end else if (!busy && word_req) begin
            if (word_addr[3:0] !== 4'd0 || word_addr > 32'd240)
                $fatal(1, "unaligned or out-of-range word address %h", word_addr);
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
        $display("PASS: 512 writes, 513 reads, all offsets/sizes, waits and reset");
        $finish;
    end
endmodule
