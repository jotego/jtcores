`timescale 1ns/1ps
`default_nettype none

module test;
    reg clk = 0;
    reg rst = 1;
    reg cen = 1;
    always #5 clk = ~clk;

    wire        mem_req, mem_we, mem_iaq, retire, fault;
    wire [31:0] mem_addr, mem_wdata, pc, st;
    wire [5:0]  mem_size;
    wire [15:0] ir;
    reg  [31:0] mem_rdata = 0;
    reg         mem_ack = 0;

    jttms10 u_cpu (
        .rst(rst), .clk(clk), .cen(cen),
        .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_size(mem_size), .mem_iaq(mem_iaq),
        .mem_rdata(mem_rdata), .mem_ack(mem_ack),
        .pc(pc), .st(st), .ir(ir), .retire(retire), .fault(fault)
    );

    `include "expected.svh"

    // Test programs fit in the first 256 words above ENTRY. The exception
    // is the architected level-0 reset vector at FFFFFFE0.
    reg [15:0] words [0:255];
    integer i;
    initial begin
        for (i=0; i<256; i=i+1) words[i] = 16'h0300;
        $readmemh("program.mem", words);
        repeat (5) @(posedge clk);
        rst <= 0;
    end

    function automatic [15:0] read_word(input [31:0] address);
        begin
            if (address < ENTRY || address >= ENTRY + 32'd4096 || address[3:0] != 0)
                $fatal(1, "invalid instruction address %h", address);
            read_word = words[(address-ENTRY) >> 4];
        end
    endfunction

    function automatic [31:0] read_field(input [31:0] address, input [5:0] size);
        begin
            if (address == 32'hffffffe0 && size == 6'd32)
                read_field = ENTRY;
            else if (size == 6'd16)
                read_field = {16'd0, read_word(address)};
            else if (size == 6'd32)
                read_field = {read_word(address + 32'd16), read_word(address)};
            else
                $fatal(1, "unsupported read size %0d at %h", size, address);
        end
    endfunction

    // Held request, one-cycle ack. The latency varies per transaction, so
    // instruction fetch and reset-vector reads exercise the stall path.
    localparam [1:0] BUS_IDLE=0, BUS_WAIT=1, BUS_ACK=2, BUS_DRAIN=3;
    reg [1:0] bus_state = BUS_IDLE;
    reg [31:0] held_addr = 0, held_wdata = 0;
    reg [5:0] held_size = 0;
    reg held_we = 0, held_iaq = 0;
    integer wait_left = 0;
    integer request_count = 0;

    always @(posedge clk) begin
        mem_ack <= 0;
        if (rst) begin
            bus_state <= BUS_IDLE;
            request_count <= 0;
        end else begin
            case (bus_state)
                BUS_IDLE: if (mem_req) begin
                    held_addr <= mem_addr;
                    held_wdata <= mem_wdata;
                    held_size <= mem_size;
                    held_we <= mem_we;
                    held_iaq <= mem_iaq;
                    wait_left <= 1 + (request_count % 3);
                    request_count <= request_count + 1;
                    bus_state <= BUS_WAIT;
                end
                BUS_WAIT: begin
                    if (!mem_req || mem_addr !== held_addr ||
                        mem_size !== held_size || mem_we !== held_we ||
                        mem_iaq !== held_iaq ||
                        (held_we && mem_wdata !== held_wdata))
                        $fatal(1, "memory request changed before ack");
                    if (wait_left == 0) bus_state <= BUS_ACK;
                    else wait_left <= wait_left - 1;
                end
                BUS_ACK: begin
                    if (held_we) $fatal(1, "unexpected write at %h", held_addr);
                    mem_rdata <= read_field(held_addr, held_size);
                    mem_ack <= 1;
                    bus_state <= BUS_DRAIN;
                end
                BUS_DRAIN: if (!mem_req) bus_state <= BUS_IDLE;
                default: bus_state <= BUS_IDLE;
            endcase
        end
    end

    reg pause_done = 0;
    reg ack_while_paused = 0;
    integer pause_left = 0;
    reg [31:0] pause_pc = 0;
    integer retired = 0;
    always @(posedge retire) begin
        #1;
        if (fault) $fatal(1, "CPU fault at retire %0d, IR %h", retired, ir);
        check_retire(retired);
        retired = retired + 1;
        if (retired == EXPECTED_RETIRES && !EXPECT_FAULT) begin
            if (PAUSE_ON_ACK && (!pause_done || !ack_while_paused))
                $fatal(1, "memory ack was not observed while enable was low");
            if (EXPECTED_REQUESTS >= 0 && request_count != EXPECTED_REQUESTS)
                $fatal(1, "memory request count %0d, expected %0d",
                       request_count, EXPECTED_REQUESTS);
            $display("TEST_RESULT: PASS (%0d instructions, %0d memory requests)",
                     retired, request_count);
            $finish;
        end
    end

    always @(posedge clk) begin
        if (!rst && PAUSE_ON_ACK) begin
            if (mem_ack && !cen) ack_while_paused <= 1;
            if (!pause_done && bus_state == BUS_ACK) begin
                cen <= 0;
                pause_done <= 1;
                pause_left <= 4;
                pause_pc <= pc;
            end else if (pause_left > 0) begin
                if (pc !== pause_pc || retire)
                    $fatal(1, "PC or retire changed while clock enable was low");
                pause_left <= pause_left - 1;
                if (pause_left == 1) cen <= 1;
            end
        end
    end

    always @(posedge fault) begin
        #1;
        if (!EXPECT_FAULT || retired != EXPECTED_RETIRES || ir !== FAULT_IR)
            $fatal(1, "unexpected fault: retired=%0d IR=%h PC=%h", retired, ir, pc);
        $display("TEST_RESULT: PASS (expected illegal opcode %h)", ir);
        $finish;
    end

    always @(posedge clk) begin
        if (!rst && fault && !EXPECT_FAULT)
            $fatal(1, "CPU fault, IR %h PC %h", ir, pc);
    end

    initial begin
        repeat (5000) @(posedge clk);
        $fatal(1, "timeout after %0d retired instructions", retired);
    end
endmodule

`default_nettype wire
