`ifndef VERILATOR_KEEP_CPU
/* verilator tracing_off */
`endif
/*
 * SH7604 to JTFRAME cache wrapper.
 *
 * SH7604 exposes a native asynchronous bus: byte address A[26:0], active-low
 * area strobes, RD_N/RD_WR_N direction controls, WE_N byte strobes, DO write
 * data, DI read data, and WAIT_N for wait-state insertion.
 *
 * jtframe_cache_mux expects a latched request/acknowledge interface instead.
 * This wrapper turns each native bus cycle into cache_cs plus cache_rd/cache_wr,
 * latches A[26:1] as cache_addr, mirrors DO to cache_din, mirrors active-low
 * WE_N to cache_dsn, and holds WAIT_N low until cache_ok acknowledges the
 * request. Requests are accepted only while BS_N is active, and a one-clock
 * pending stage gives the SH7604 BSC/cache path time to present stable write
 * data before cache_cs is asserted.
 */
module jtsh7604 #(
    parameter bit UBC_DISABLE = 1'b0,
    parameter bit SCI_DISABLE = 1'b0,
    parameter bit WDT_DISABLE = 1'b0,
    parameter bit [3:0] BUS_AREA_TIMIMG = 4'd0,
    parameter bit BUS_SIZE_BYTE_DISABLE = 1'b0,
    parameter bit BUS_SIZE_WORD_DISABLE = 1'b0,
    parameter bit [5:0] MD_CFG = 6'b010100
)(
    input              rst,
    input              clk,
    input              ce_r,
    input              ce_f,
    input              nmi_n,
    input      [3:0]   irl_n,
    input      [31:0]  cpu_din,

    input              cache_ok,

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
    output     [3:0]   WE_N,
    output             RD_N,
    output             IVECF_N,
    output             RFS,
    output             BGR_N,
    output             WAIT_N,

    output             cache_cs,
    output             cache_we,
    output             cache_rd,
    output             cache_wr,
    output     [26:1]  cache_addr,
    output     [31:0]  cache_din,
    output     [3:0]   cache_dsn
);

    wire [26:0] cpu_a;
    wire [31:0] cpu_do;
    wire [3:0]  cpu_we;
    wire        cpu_rd_n;
    wire        cpu_wr_n = RD_WR_N;
    wire        cpu_req;
    wire        cpu_wr_req;

    reg         req_busy;
    reg         req_seen;
    reg         req_pending;
    reg         cache_wr_r;
    reg [26:1]  cache_addr_r;
    reg [1:0]   cache_addr_lsb_r;
    reg [31:0]  cache_din_r;
    reg [3:0]   cache_dsn_r;

    assign cpu_req    = ~BS_N & (~cpu_rd_n | ~cpu_wr_n);
    assign cpu_wr_req = ~BS_N & ~cpu_wr_n;

    wire sig_changed = (cache_addr_r != cpu_a[26:1]) ||
                       (cache_addr_lsb_r != cpu_a[1:0])  ||
                       (cache_wr_r   != cpu_wr_req)   ||
                       (cpu_wr_req   && cache_dsn_r != cpu_we) ||
                       (cpu_wr_req   && (cache_din_r != cpu_do));

    wire req_ready   = ~req_busy || cache_ok;
    wire req_start   = cpu_req && req_ready && !req_pending && (~req_seen || sig_changed);
    wire req_launch  = req_pending && cpu_req;
    wire req_active  = req_busy;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            req_busy     <= 1'b0;
            req_seen     <= 1'b0;
            req_pending  <= 1'b0;
            cache_wr_r   <= 1'b0;
            cache_addr_r <= '0;
            cache_addr_lsb_r <= 2'b00;
            cache_din_r  <= '0;
            cache_dsn_r  <= 4'hf;
        end
        else begin
            if (cache_ok && req_busy) begin
                req_busy <= 1'b0;
                if (!cpu_req) begin
                    req_seen <= 1'b0;
                end
            end
            else if (!cpu_req && !req_busy) begin
                req_seen <= 1'b0;
            end

            if (req_launch) begin
                req_pending  <= 1'b0;
                req_seen     <= 1'b1;
                req_busy     <= 1'b1;
                cache_wr_r   <= cpu_wr_req;
                cache_addr_r <= cpu_a[26:1];
                cache_addr_lsb_r <= cpu_a[1:0];
                cache_din_r  <= cpu_do;
                cache_dsn_r  <= cpu_we;
            end
            else if (req_start) begin
                req_pending <= 1'b1;
            end
            else if (req_pending && !cpu_req) begin
                req_pending <= 1'b0;
            end
        end
    end

    assign cache_cs   = req_active;
    assign cache_we   = req_active & cache_wr_r;
    assign cache_rd   = req_active & ~cache_wr_r;
    assign cache_wr   = req_active & cache_wr_r;
    assign cache_addr = cache_addr_r;
    assign cache_din  = cache_din_r;
    assign cache_dsn  = cache_dsn_r;

    assign WAIT_N = req_active ? cache_ok : ~(req_pending || req_start);

    SH7604 #(
        .UBC_DISABLE      ( UBC_DISABLE      ),
        .SCI_DISABLE      ( SCI_DISABLE      ),
        .WDT_DISABLE      ( WDT_DISABLE      ),
        .BUS_AREA_TIMIMG  ( BUS_AREA_TIMIMG  ),
        .BUS_SIZE_BYTE_DISABLE( BUS_SIZE_BYTE_DISABLE ),
        .BUS_SIZE_WORD_DISABLE( BUS_SIZE_WORD_DISABLE )
    ) u_cpu(
        .CLK       ( clk       ),
        .RST_N     ( ~rst      ),
        .CE_R      ( ce_r      ),
        .CE_F      ( ce_f      ),
        .EN        ( 1'b1      ),

        .RES_N     ( ~rst      ),
        .NMI_N     ( nmi_n     ),
        .IRL_N     ( irl_n     ),

        .A         ( cpu_a     ),
        .DI        ( cpu_din   ),
        .DO        ( cpu_do    ),
        .BS_N      ( BS_N      ),
        .CS0_N     ( CS0_N     ),
        .CS1_N     ( CS1_N     ),
        .CS2_N     ( CS2_N     ),
        .CS3_N     ( CS3_N     ),
        .RD_WR_N   ( RD_WR_N   ),
        .CE_N      ( CE_N      ),
        .OE_N      ( OE_N      ),
        .WE_N      ( cpu_we    ),
        .RD_N      ( cpu_rd_n  ),
        .IVECF_N   ( IVECF_N   ),
        .RFS       ( RFS       ),

        .EA        ( 27'd0     ),
        .EDI       (           ),
        .EDO       ( 32'd0     ),
        .EBS_N     ( 1'b1      ),
        .ECS0_N    ( 1'b1      ),
        .ECS1_N    ( 1'b1      ),
        .ECS2_N    ( 1'b1      ),
        .ECS3_N    ( 1'b1      ),
        .ERD_WR_N  ( 1'b1      ),
        .ECE_N     ( 1'b1      ),
        .EOE_N     ( 1'b1      ),
        .EWE_N     ( 4'hf      ),
        .ERD_N     ( 1'b1      ),
        .EIVECF_N  ( 1'b1      ),

        .WAIT_N    ( WAIT_N    ),
        .BRLS_N    ( 1'b1      ),
        .BGR_N     ( BGR_N     ),

        .DREQ0     ( 1'b0      ),
        .DACK0     (           ),
        .DREQ1     ( 1'b0      ),
        .DACK1     (           ),

        .FTOA      (           ),
        .FTOB      (           ),
        .FTCI      ( 1'b0      ),
        .FTI       ( 1'b0      ),

        .RXD       ( 1'b0      ),
        .TXD       (           ),
        .SCKO      (           ),
        .SCKI      ( 1'b0      ),

        .WDTOVF_N  (           ),

        .MD        ( MD_CFG    ),
        .FAST      ( 1'b0      ),

        .CPS3_DECRYPT ( 1'b0   ),
        .CPS3_KEY1    ( 32'd0  ),
        .CPS3_KEY2    ( 32'd0  )
    );

    assign A        = cpu_a;
    assign cpu_dout = cpu_do;

endmodule
