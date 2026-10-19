`timescale 1ns/1ps
`default_nettype none

module test;
    reg clk = 0;
    reg rst = 1;
    reg cen = 1;
    always #5 clk = ~clk;

    wire        mem_req, mem_we, mem_iaq, mem_pixel, wvp_set, retire, fault;
    wire [31:0] mem_addr, mem_wdata, pc, st;
    wire [5:0]  mem_size;
    wire [15:0] ir;
    reg  [31:0] mem_rdata = 0;
    reg         mem_ack = 0;
    reg         wvp_seen = 0;

    `include "expected.svh"

    jttms10 u_cpu (
        .rst(rst), .clk(clk), .cen(cen),
        .psize(PIXEL_SIZE), .convdp(CONVDP),
        .convsp(CONVSP), .control(CONTROL), .pmask(PMASK),
        .wvp_set(wvp_set),
        .irq_req(1'b0), .irq_vector(32'd0),
        .nmi_req(1'b0), .nmi_nostack(1'b0),
        .halt_req(1'b0), .emu_run(1'b1),
        .nmi_clear(), .emu_ack(),
        .mem_req(mem_req), .mem_we(mem_we), .mem_pixel(mem_pixel), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_size(mem_size), .mem_iaq(mem_iaq),
        .mem_program(), .mem_fast(),
        .mem_rdata(mem_rdata), .mem_ack(mem_ack), .mem_cached(1'b0), .mem_busy(1'b0), .mem_phase(3'd0), .mem_slot(1'b1),
        .pc(pc), .st(st), .ir(ir), .retire(retire), .fault(fault)
    );

    // Backing store has 1024 physical 16-bit words. All public addresses
    // are bit addresses; the reset vector is handled at its high address.
    reg [15:0] words [0:1023];
    reg [31:0] vector_target [0:31];
    reg vector_valid [0:31];
    integer i, data_fd, data_at, data_count, data_index, data_rc;
    integer vector_fd, vector_number, vector_rc;
    reg [15:0] init_word;
    reg [31:0] init_vector;
    initial begin
        for (i=0; i<1024; i=i+1) words[i] = 16'h0300;
        for (i=0; i<32; i=i+1) begin
            vector_target[i] = 0;
            vector_valid[i] = 0;
        end
        $readmemh("program.mem", words, ENTRY >> 4);
        data_fd = $fopen("memory_init.txt", "r");
        if (data_fd == 0) $fatal(1, "missing memory_init.txt");
        while ($fscanf(data_fd, "%h %d", data_at, data_count) == 2) begin
            for (data_index=0; data_index<data_count; data_index=data_index+1) begin
                data_rc = $fscanf(data_fd, "%h", init_word);
                if (data_rc != 1) $fatal(1, "truncated memory_init.txt");
                words[(data_at >> 4) + data_index] = init_word;
            end
        end
        $fclose(data_fd);
        vector_fd = $fopen("vector_init.txt", "r");
        if (vector_fd == 0) $fatal(1, "missing vector_init.txt");
        while ($fscanf(vector_fd, "%d %h", vector_number, init_vector) == 2) begin
            if (vector_number < 1 || vector_number > 31)
                $fatal(1, "invalid trap vector number %0d", vector_number);
            vector_target[vector_number] = init_vector;
            vector_valid[vector_number] = 1;
        end
        $fclose(vector_fd);
        repeat (5) @(posedge clk);
        rst <= 0;
    end

    function automatic [31:0] read_field(input [31:0] address, input [5:0] size);
        integer bit_index;
        integer vector_index;
        reg [31:0] physical;
        begin
            read_field = 0;
            if (size == 6'd32 && address >= 32'hfffffc00 &&
                address <= 32'hffffffe0 && address[4:0] == 0) begin
                vector_index = (32'hffffffe0 - address) >> 5;
                if (vector_index == 0) read_field = ENTRY;
                else if (vector_valid[vector_index])
                    read_field = vector_target[vector_index];
                else $fatal(1, "uninitialized trap vector %0d", vector_index);
            end else begin
                if (size < 1 || size > 32 || address + size > 32'd16384)
                    $fatal(1, "invalid read size %0d at bit address %h", size, address);
                for (bit_index=0; bit_index<32; bit_index=bit_index+1) begin
                    if (bit_index < size) begin
                        physical = address + bit_index;
                        read_field[bit_index] = words[physical >> 4][physical[3:0]];
                    end
                end
            end
        end
    endfunction

    task automatic write_field(input [31:0] address, input [5:0] size,
                               input [31:0] data);
        integer bit_index;
        reg [31:0] physical;
        begin
            if (size < 1 || size > 32 || address + size > 32'd16384)
                $fatal(1, "invalid write size %0d at bit address %h", size, address);
            for (bit_index=0; bit_index<32; bit_index=bit_index+1) begin
                if (bit_index < size) begin
                    physical = address + bit_index;
                    words[physical >> 4][physical[3:0]] = data[bit_index];
                end
            end
        end
    endtask

    // Held request, one-cycle ack. The latency varies per transaction, so
    // instruction fetch and reset-vector reads exercise the stall path.
    localparam [1:0] BUS_IDLE=0, BUS_WAIT=1, BUS_ACK=2, BUS_DRAIN=3;
    reg [1:0] bus_state = BUS_IDLE;
    reg [31:0] held_addr = 0, held_wdata = 0;
    reg [5:0] held_size = 0;
    reg held_we = 0, held_iaq = 0, held_pixel = 0;
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
                    held_pixel <= mem_pixel;
                    wait_left <= 1 + (request_count % 3);
                    request_count <= request_count + 1;
                    bus_state <= BUS_WAIT;
                end
                BUS_WAIT: begin
                    if (!mem_req || mem_addr !== held_addr ||
                        mem_size !== held_size || mem_we !== held_we ||
                        mem_iaq !== held_iaq || mem_pixel !== held_pixel ||
                        (held_we && mem_wdata !== held_wdata))
                        $fatal(1, "memory request changed before ack: ir=%04h ua=%03h held=%08h/%0d/%0d/%08h current=%0d:%08h/%0d/%0d/%08h", ir,u_cpu.u_ctrl.uaddr,held_addr,held_size,held_we,held_wdata,mem_req,mem_addr,mem_size,mem_we,mem_wdata);
                    if (wait_left == 0) bus_state <= BUS_ACK;
                    else wait_left <= wait_left - 1;
                end
                BUS_ACK: begin
                    if (held_we) write_field(held_addr, held_size, held_wdata);
                    else mem_rdata <= read_field(held_addr, held_size);
                    mem_ack <= 1;
                    bus_state <= BUS_DRAIN;
                end
                BUS_DRAIN: if (!mem_req) bus_state <= BUS_IDLE;
                default: bus_state <= BUS_IDLE;
            endcase
        end
    end

    reg pause_done = 0;
    always @(posedge clk) begin
        if (rst) wvp_seen <= 0;
        else if (wvp_set) wvp_seen <= 1;
    end
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
            if (!pause_done && bus_state == BUS_ACK &&
                (!PAUSE_ADDR_FILTER || held_addr==PAUSE_ACK_ADDR) &&
                (!PAUSE_WRITE_FILTER || held_we==PAUSE_ACK_WRITE)) begin
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
        // Liveness budget scales with program length now that multiply uses
        // TI machine-state timing. Exact latency is checked in ver/timing;
        // this generous architectural watchdog must not truncate long tests.
        repeat (5000 + 512*EXPECTED_RETIRES) @(posedge clk);
        $fatal(1, "timeout after %0d retired instructions", retired);
    end
endmodule

`default_nettype wire
