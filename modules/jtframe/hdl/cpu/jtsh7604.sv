`ifndef VERILATOR_KEEP_CPU
/* verilator tracing_off */
`endif
/*
 * SH7604 to JTFRAME cache wrapper.
 *
 * SH7604 exposes a native asynchronous bus and BUS_STB, a BSC request marker
 * that rises when a new external bus beat is presented.
 *
 * jtframe_cache_mux expects a latched request/acknowledge interface instead.
 * This wrapper turns each BUS_STB edge into cache_cs plus cache_rd/cache_wr.
 * WAIT_N stays low until cache_ok acknowledges the request, so the native A,
 * DO and WE_N registers remain stable and can be forwarded directly to the
 * cache interface without re-latching and comparing the full bus.
 *
 * For CPS3, the wrapper can also pass the decryption keys into the SH7604
 * cache path so opcode fetches from SIMM flash are decrypted there while BIOS
 * reads can still be handled externally.
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
    input      [31:0]  cps3_key1,
    input      [31:0]  cps3_key2,

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
    wire        cpu_bus_stb;
    wire        cpu_bus_dbus_rd;
    wire        cpu_wr_req = ~RD_WR_N;
    wire        bus_stb_rise;
    wire        cps3_valid_key = |{cps3_key1, cps3_key2};
    wire        cps3_bios_rd = cps3_valid_key && cpu_a[26:19] == 8'h00 && !cpu_rd_n && !cpu_bus_dbus_rd;
    wire [31:0] cpu_din_sh = cps3_bios_rd ?
        (cps3_swap16_dword(cpu_din) ^ cps3_mask({5'd0, cpu_a[26:2], 2'b00}, cps3_key1, cps3_key2)) :
        cpu_din;
    wire [31:0] cpu_din_hold = req_rd_l ? cpu_din_l : cpu_din_sh;

    reg         req_active;
    reg         req_done;
    reg         req_rd_l;
    reg         bus_stb_l;
    reg [31:0]  cpu_din_l;

    function automatic [15:0] cps3_rotate_left16(input [15:0] val, input integer n);
        cps3_rotate_left16 = (val << n) | (val >> (16 - n));
    endfunction

    function automatic [31:0] cps3_swap16_dword(input [31:0] val);
        cps3_swap16_dword = {val[23:16], val[31:24], val[7:0], val[15:8]};
    endfunction

    function automatic [15:0] cps3_rotxor(input [15:0] val, input [15:0] xorval);
        reg [15:0] res;
        begin
            res = val + cps3_rotate_left16(val, 2);
            res = cps3_rotate_left16(res, 4) ^ (res & (val ^ xorval));
            cps3_rotxor = res;
        end
    endfunction

    function automatic [31:0] cps3_mask(input [31:0] address, input [31:0] key1, input [31:0] key2);
        reg [31:0] addr_x;
        reg [15:0] val;
        begin
            addr_x = address ^ key1;
            val = addr_x[15:0] ^ 16'hffff;
            val = cps3_rotxor(val, key2[15:0]);
            val = val ^ addr_x[31:16] ^ 16'hffff;
            val = cps3_rotxor(val, key2[31:16]);
            val = val ^ addr_x[15:0] ^ key2[15:0];
            cps3_mask = {val, val};
        end
    endfunction

    assign bus_stb_rise = cpu_bus_stb & ~bus_stb_l;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            req_active <= 1'b0;
            req_done   <= 1'b0;
            req_rd_l   <= 1'b0;
            bus_stb_l  <= 1'b0;
            cpu_din_l  <= 32'd0;
        end
        else begin
            bus_stb_l <= cpu_bus_stb;

            if (bus_stb_rise) begin
                req_active <= 1'b1;
                req_done   <= 1'b0;
                req_rd_l   <= ~cpu_wr_req;
            end
            else if (cache_ok && req_active) begin
                req_active <= 1'b0;
                req_done   <= 1'b1;
            end

            if (cache_ok && req_active && req_rd_l) begin
                cpu_din_l <= cpu_din_sh;
            end

            if (!cpu_bus_stb) begin
                req_done <= 1'b0;
            end
        end
    end

    assign cache_cs   = req_active;
    assign cache_we   = req_active & cpu_wr_req;
    assign cache_rd   = req_active & ~cpu_wr_req;
    assign cache_wr   = req_active & cpu_wr_req;
    assign cache_addr = cpu_a[26:1];
    assign cache_din  = cpu_do;
    assign cache_dsn  = cpu_we;

    assign WAIT_N = req_active ? cache_ok : (req_done || !cpu_bus_stb);

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
        .DI        ( cpu_din_hold ),
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
        .BUS_STB   ( cpu_bus_stb ),
        .BUS_DBUS_RD ( cpu_bus_dbus_rd ),

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

        .CPS3_DECRYPT ( cps3_valid_key ),
        .CPS3_KEY1    ( cps3_key1 ),
        .CPS3_KEY2    ( cps3_key2 )
    );

    assign A        = cpu_a;
    assign cpu_dout = cpu_do;
    assign WE_N     = cpu_we;
    assign RD_N     = cpu_rd_n;

endmodule
