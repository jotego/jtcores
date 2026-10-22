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

    integer cfg_fd, cfg_rc, check_fd;
    integer expected_retires, expected_fault, fault_ir;
    integer pause_on_ack, pause_addr_filter, pause_write_filter, pause_ack_write;
    integer expected_requests;
    reg [15:0] pixel_size, convdp, convsp, control, pmask;
    reg [31:0] entry, pause_ack_addr;
    reg [15:0] check_ir;
    reg [31:0] check_pc, check_st, check_flags_mask, check_flags_value;
    integer check_st_valid;
    integer check_wvp_valid, check_wvp, check_regs, check_mem;
    integer check_index, check_size;
    reg [31:0] check_reg_value, check_addr, check_data;

    jttms10 u_cpu (
        .rst(rst), .clk(clk), .cen(cen), .grid_ready(1'b1),
        .cache_flush(1'b0),
        .psize(pixel_size), .convdp(convdp),
        .convsp(convsp), .control(control), .pmask(pmask),
        .wvp_set(wvp_set),
        .irq_req(1'b0), .irq_vector(32'd0),
        .nmi_req(1'b0), .nmi_nostack(1'b0),
        .halt_req(1'b0), .emu_run(1'b1),
        .nmi_clear(), .emu_ack(),
        .mem_req(mem_req), .mem_we(mem_we), .mem_pixel(mem_pixel), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_size(mem_size), .mem_iaq(mem_iaq),
        .mem_program(),
        .mem_rdata(mem_rdata), .mem_ack(mem_ack),
        .peek_req(), .peek_consume(), .peek_ack(1'b0), .peek_hit(1'b0),
        .peek_data(16'd0),
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
        cfg_fd = $fopen("case.cfg", "r");
        if (cfg_fd == 0) $fatal(1, "missing case.cfg");
        cfg_rc = $fscanf(cfg_fd,
            "%h %d %d %h %d %d %h %d %d %d %h %h %h %h %h",
            entry, expected_retires, expected_fault, fault_ir,
            pause_on_ack, pause_addr_filter, pause_ack_addr,
            pause_write_filter, pause_ack_write, expected_requests,
            pixel_size, convdp, convsp, control, pmask);
        if (cfg_rc != 15) $fatal(1, "malformed case.cfg header (%0d fields)", cfg_rc);
        if (expected_retires < 1 ||
            expected_fault < 0 || expected_fault > 1 ||
            pause_on_ack < 0 || pause_on_ack > 1 ||
            pause_addr_filter < 0 || pause_addr_filter > 1 ||
            pause_write_filter < 0 || pause_write_filter > 1 ||
            pause_ack_write < 0 || pause_ack_write > 1 ||
            expected_requests < -1 || expected_requests > 65535)
            $fatal(1, "invalid case.cfg control value");
        if (pixel_size != 1 && pixel_size != 2 && pixel_size != 4 &&
            pixel_size != 8 && pixel_size != 16)
            $fatal(1, "invalid pixel size in case.cfg");
        check_fd = cfg_fd;
        for (i=0; i<1024; i=i+1) words[i] = 16'h0300;
        for (i=0; i<32; i=i+1) begin
            vector_target[i] = 0;
            vector_valid[i] = 0;
        end
        $readmemh("program.mem", words, entry >> 4);
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
        @(negedge clk) rst = 0;
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
                if (vector_index == 0) read_field = entry;
                else if (vector_valid[vector_index])
                    read_field = vector_target[vector_index];
                else $fatal(1, "uninitialized trap vector %0d", vector_index);
            end else begin
                if (size < 1 || size > 32 || address + {26'd0, size} > 32'd16384)
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
            if (size < 1 || size > 32 || address + {26'd0, size} > 32'd16384)
                $fatal(1, "invalid write size %0d at bit address %h", size, address);
            for (bit_index=0; bit_index<32; bit_index=bit_index+1) begin
                if (bit_index < size) begin
                    physical = address + bit_index;
                    words[physical >> 4][physical[3:0]] = data[bit_index];
                end
            end
        end
    endtask

    task automatic check_retire(input integer step);
        integer rc, reg_i, mem_i;
        begin
            rc = $fscanf(check_fd, "%h %h %d %h %h %h %d %d %d %d",
                check_ir, check_pc, check_st_valid, check_st,
                check_flags_mask, check_flags_value,
                check_wvp_valid, check_wvp, check_regs, check_mem);
            if (rc != 10 || check_st_valid < 0 || check_st_valid > 1 ||
                check_regs < 0 || check_mem < 0 ||
                check_wvp_valid < 0 || check_wvp_valid > 1 ||
                check_wvp < 0 || check_wvp > 1)
                $fatal(1, "missing/malformed checkpoint %0d", step);
            if (ir !== check_ir)
                $fatal(1, "step %0d IR %h expected %h", step, ir, check_ir);
            if (pc !== check_pc)
                $fatal(1, "step %0d PC %h expected %h", step, pc, check_pc);
            if (check_st_valid != 0 && st !== check_st)
                $fatal(1, "step %0d ST %h expected %h", step, st, check_st);
            if ((st & check_flags_mask) !== (check_flags_value & check_flags_mask))
                $fatal(1, "step %0d flags in ST %h mask %h expected %h", step,
                       st, check_flags_mask, check_flags_value);
            if (check_wvp_valid != 0 && wvp_seen !== check_wvp[0])
                $fatal(1, "step %0d WVP %b expected %b", step,
                       wvp_seen, check_wvp[0]);
            for (reg_i = 0; reg_i < check_regs; reg_i = reg_i + 1) begin
                rc = $fscanf(check_fd, "%d %h", check_index, check_reg_value);
                if (rc != 2 || check_index < 0 || check_index > 31)
                    $fatal(1, "malformed register checkpoint at step %0d", step);
                if (u_cpu.u_regs.ram0[check_index] !== check_reg_value)
                    $fatal(1, "step %0d register %0d %h expected %h", step,
                           check_index, u_cpu.u_regs.ram0[check_index], check_reg_value);
            end
            for (mem_i = 0; mem_i < check_mem; mem_i = mem_i + 1) begin
                rc = $fscanf(check_fd, "%h %d %h", check_addr, check_size, check_data);
                if (rc != 3 || check_size < 1 || check_size > 32)
                    $fatal(1, "malformed memory checkpoint at step %0d", step);
                if (read_field(check_addr, check_size[5:0]) !== check_data)
                    $fatal(1, "step %0d memory @%h/%0d %h expected %h", step,
                           check_addr, check_size, read_field(check_addr, check_size[5:0]),
                           check_data);
            end
            if (step == expected_retires-1) begin
                rc = $fscanf(check_fd, "%h", check_ir);
                if (rc != -1) $fatal(1, "extra or malformed checkpoint data in case.cfg");
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
                        $fatal(1, "memory request changed before ack");
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
        if (retired == expected_retires && expected_fault == 0) begin
            if (pause_on_ack != 0 && (!pause_done || !ack_while_paused))
                $fatal(1, "memory ack was not observed while enable was low");
            if (expected_requests >= 0 && request_count != expected_requests)
                $fatal(1, "memory request count %0d, expected %0d",
                       request_count, expected_requests);
            $display("TEST_RESULT: PASS (%0d instructions, %0d memory requests)",
                     retired, request_count);
            $finish;
        end
    end

    always @(posedge clk) begin
        if (!rst && pause_on_ack != 0) begin
            if (mem_ack && !cen) ack_while_paused <= 1;
            if (!pause_done && bus_state == BUS_ACK &&
                (pause_addr_filter == 0 || held_addr==pause_ack_addr) &&
                (pause_write_filter == 0 || held_we==pause_ack_write[0])) begin
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
        if (expected_fault == 0 || retired != expected_retires ||
            ir !== fault_ir[15:0])
            $fatal(1, "unexpected fault: retired=%0d IR=%h PC=%h", retired, ir, pc);
        $display("TEST_RESULT: PASS (expected illegal opcode %h)", ir);
        $finish;
    end

    always @(posedge clk) begin
        if (!rst && fault && expected_fault == 0)
            $fatal(1, "CPU fault, IR %h PC %h", ir, pc);
    end

    initial begin
        repeat (5000) @(posedge clk);
        $fatal(1, "timeout after %0d retired instructions", retired);
    end
endmodule

`default_nettype wire
