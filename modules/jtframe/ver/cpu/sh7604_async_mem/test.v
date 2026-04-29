`timescale 1ns / 1ps

module test(
    input              clk,
    input              rst,
    input      [23:0]  dbg_addr,
    output     [31:0]  dbg_data,
    output             status_valid,
    output     [31:0]  status_code,
    output     [31:0]  cpu_din_mon,
    output             ce_r,
    output             ce_f,

    output     [26:0]  A,
    output     [31:0]  cpu_dout,
    output             BS_N,
    output             CS0_N,
    output             CS1_N,
    output             CS2_N,
    output             CS3_N,
    output             RD_WR_N,
    output             CE_N,
    output             OE_N,
    output     [ 3:0]  WE_N,
    output             RD_N,
    output             IVECF_N,
    output             RFS,
    output             BGR_N,
    output             WAIT_N,

    output             cache_cs,
    output             cache_rd,
    output             cache_wr,
    output     [26:1]  cache_addr,
    output     [31:0]  cache_din,
    output     [ 3:0]  cache_dsn,
    output             cache_ok
);

wire [31:0] mem_dout;
reg  [ 1:0] ce_ctr;

assign ce_r       = ce_ctr == 2'd0;
assign ce_f       = ce_ctr == 2'd2;
assign cpu_din_mon = mem_dout;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ce_ctr <= 2'd0;
    end else begin
        ce_ctr <= ce_ctr + 2'd1;
    end
end

jtsh7604 #(
    .UBC_DISABLE            ( 1'b1      ),
    .SCI_DISABLE            ( 1'b1      ),
    .WDT_DISABLE            ( 1'b1      ),
    .BUS_AREA_TIMIMG        ( 4'h0      ),
    .BUS_SIZE_BYTE_DISABLE  ( 1'b0      ),
    .BUS_SIZE_WORD_DISABLE  ( 1'b0      ),
    .MD_CFG                 ( 6'b010100 )
) u_cpu(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .ce_r       ( ce_r       ),
    .ce_f       ( ce_f       ),
    .nmi_n      ( 1'b1       ),
    .irl_n      ( 4'hf       ),
    .cpu_din    ( mem_dout   ),
    .cache_ok   ( cache_ok   ),

    .A          ( A          ),
    .cpu_dout   ( cpu_dout   ),
    .BS_N       ( BS_N       ),
    .CS0_N      ( CS0_N      ),
    .CS1_N      ( CS1_N      ),
    .CS2_N      ( CS2_N      ),
    .CS3_N      ( CS3_N      ),
    .RD_WR_N    ( RD_WR_N    ),
    .CE_N       ( CE_N       ),
    .OE_N       ( OE_N       ),
    .WE_N       ( WE_N       ),
    .RD_N       ( RD_N       ),
    .IVECF_N    ( IVECF_N    ),
    .RFS        ( RFS        ),
    .BGR_N      ( BGR_N      ),
    .WAIT_N     ( WAIT_N     ),

    .cache_cs   ( cache_cs   ),
    .cache_we   (            ),
    .cache_rd   ( cache_rd   ),
    .cache_wr   ( cache_wr   ),
    .cache_addr ( cache_addr ),
    .cache_din  ( cache_din  ),
    .cache_dsn  ( cache_dsn  )
);

sh7604_async_sram u_mem(
    .clk          ( clk          ),
    .rst          ( rst          ),
    .cache_cs     ( cache_cs     ),
    .cache_rd     ( cache_rd     ),
    .cache_wr     ( cache_wr     ),
    .cache_addr   ( cache_addr   ),
    .cache_din    ( cache_din    ),
    .cache_dsn    ( cache_dsn    ),
    .cache_dout   ( mem_dout     ),
    .cache_ok     ( cache_ok     ),
    .dbg_addr     ( dbg_addr     ),
    .dbg_data     ( dbg_data     ),
    .status_valid ( status_valid ),
    .status_code  ( status_code  )
);

endmodule

module sh7604_async_sram(
    input              clk,
    input              rst,
    input              cache_cs,
    input              cache_rd,
    input              cache_wr,
    input      [26:1]  cache_addr,
    input      [31:0]  cache_din,
    input      [ 3:0]  cache_dsn,
    output     [31:0]  cache_dout,
    output reg         cache_ok,
    input      [23:0]  dbg_addr,
    output     [31:0]  dbg_data,
    output reg         status_valid,
    output reg [31:0]  status_code
);

localparam integer MEM_BYTES = 16 * 1024 * 1024;

reg [7:0] mem [0:MEM_BYTES-1];
integer   fd, pos, ch;

wire [23:0] word_addr = {cache_addr[23:2], 2'b00};
wire [23:0] dbg_word_addr = {dbg_addr[23:2], 2'b00};
wire        ram_cs  = cache_addr[26:25] == 2'b00;
wire        stat_cs = cache_addr[26:25] == 2'b11;

assign cache_dout = {mem[word_addr], mem[word_addr + 24'd1],
                     mem[word_addr + 24'd2], mem[word_addr + 24'd3]};
assign dbg_data   = {mem[dbg_word_addr], mem[dbg_word_addr + 24'd1],
                     mem[dbg_word_addr + 24'd2], mem[dbg_word_addr + 24'd3]};

initial begin
    for (pos = 0; pos < MEM_BYTES; pos = pos + 1) begin
        mem[pos] = 8'h00;
    end

    fd = $fopen("sh7604_mem.bin", "rb");
    if (fd == 0) begin
        $display("ERROR: cannot open sh7604_mem.bin");
        $finish;
    end

    pos = 0;
    ch = $fgetc(fd);
    while (ch >= 0 && pos < MEM_BYTES) begin
        mem[pos] = ch[7:0];
        pos = pos + 1;
        ch = $fgetc(fd);
    end
    $fclose(fd);
    $display("Loaded %0d bytes into SH7604 async SRAM", pos);
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cache_ok     <= 1'b0;
        status_valid <= 1'b0;
        status_code  <= 32'd0;
    end else begin
        cache_ok     <= cache_cs & (cache_rd | cache_wr) & (ram_cs | stat_cs);
        status_valid <= 1'b0;

        if (cache_cs && cache_wr && ram_cs) begin
            if (!cache_dsn[3]) mem[word_addr]          <= cache_din[31:24];
            if (!cache_dsn[2]) mem[word_addr + 24'd1] <= cache_din[23:16];
            if (!cache_dsn[1]) mem[word_addr + 24'd2] <= cache_din[15: 8];
            if (!cache_dsn[0]) mem[word_addr + 24'd3] <= cache_din[ 7: 0];
        end

        if (cache_cs && cache_wr && stat_cs && !cache_ok) begin
            status_valid <= 1'b1;
            status_code  <= cache_din;
        end
    end
end

endmodule
