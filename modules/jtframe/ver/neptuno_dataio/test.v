module test;

reg  SPI_SCK, SPI_SS2, SPI_DI;
wire SPI_DO;
reg [7:0] tx_data;
reg sdram_init;
wire downloading;

reg  clk_sys;
wire clk_rom = clk_sys;

initial begin
    SPI_SCK = 0;
    forever #10 SPI_SCK = ~SPI_SCK;
end

initial begin
    clk_sys = 0;
    forever #7 clk_sys = ~clk_sys;
end

initial begin
    SPI_SS2 = 1;

    tx_data = 8'h10; // request data
    #100;
    sdram_init = 1;
    #100;
    SPI_SS2 = 0;
    #85;
    SPI_SS2 = 1;

    tx_data = 8'h14; // request config string
    #100;
    SPI_SS2 = 0;

    #50000;
    $finish;
end

initial begin
    $dumpfile("test.fst");
    $dumpvars;
end

reg [7:0] tx_byte;
assign SPI_DI = tx_byte[7];

always @(posedge  SPI_SCK, posedge  SPI_SS2) begin
    if( SPI_SS2 ) begin
        tx_byte <= tx_data;
    end else begin
        tx_byte <= tx_byte << 1;
    end
end

reg [7:0] rx_in, last_rx;
reg [2:0] rx_cnt;

always @(posedge  SPI_SCK) begin
    rx_in <= {  rx_in[6:0],SPI_DO };
    rx_cnt <= SPI_SS2 ? 0 : (rx_cnt+1);
    if( rx_cnt==0 ) last_rx <= rx_in;
end

wire [9:0] cfg_addr;
wire [7:0] cfg_dout;

jtframe_ram #(.synfile("cfgstr.hex")) u_cfgstr(
    .clk    ( SPI_SCK   ),
    .cen    ( 1'b1      ),
    .data   (           ),
    .addr   ( cfg_addr  ),
    .we     ( 1'b0      ),
    .q      ( cfg_dout  )
);

// Neptuno
reg [7:0] nept_din;
reg       dwn_done;
always @(posedge clk_sys) begin
    if( sdram_init ) begin
        nept_din <= 8'hff;
        dwn_done <= 0;
    end else begin
        if( downloading ) begin
            dwn_done <= 1;
        end
        nept_din <= dwn_done ? /*~joystick1[7:0]*/ 8'hff : 8'h3f;
    end
end

data_io  u_datain (
    .SPI_SCK            ( SPI_SCK           ),
    .SPI_SS2            ( SPI_SS2           ),
    .SPI_DI             ( SPI_DI            ),
    .SPI_DO             ( SPI_DO            ),

    .data_in            ( nept_din          ),
    .conf_addr          ( cfg_addr          ),
    .conf_chr           ( cfg_dout          ),
    .status             (                   ),
    .core_mod           (                   ),

    .clk_sys            ( clk_rom           ),
    .ioctl_download     ( downloading       ),
    .ioctl_addr         (                   ),
    .ioctl_dout         (                   ),
    .ioctl_wr           (                   ),
    .ioctl_index        (                   ),
    // Unused
    .config_buffer_o    (                   )
);

endmodule