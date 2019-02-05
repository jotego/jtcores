module spitx(
    input   rst,
    input   SPI_DO,
    output  SPI_SCK,
    output  reg SPI_DI,
    output  reg SPI_SS2,
    output  SPI_SS3,
    output  SPI_SS4,
    output  reg CONF_DATA0,
    output  reg spi_done
);

parameter filename="../../../rom/JT1942.rom";
parameter TX_LEN           = 242688;

integer file, tx_cnt;
assign SPI_SS3=1'b0;
assign SPI_SS4=1'b0;

localparam UIO_FILE_TX      = 8'h53;
localparam UIO_FILE_TX_DAT  = 8'h54;
localparam UIO_FILE_INDEX   = 8'h55;

reg [7:0] rom_buffer[0:TX_LEN-1];

initial begin
    file=$fopen(filename,"rb");
    if( file==0 ) begin
        $display("ERROR: could not open file ", filename );
        $finish;
    end
    tx_cnt=$fread( rom_buffer, file );
    if( tx_cnt != TX_LEN ) begin
        $display("ERROR: ", filename," was expected to be of length %d", TX_LEN );
        $finish;
    end
    $fclose(file);
end

integer spi_st, next, buff_cnt;
reg spi_clkgate;
reg clk_24;

initial begin
    clk_24 = 0;
    forever #20.833 clk_24 = ~clk_24;
end

localparam SPI_INIT=0, SPI_TX=1, SPI_SET=2, SPI_END=3, SPI_UNSET=4;
assign SPI_SCK = clk_24 /*& spi_clkgate*/;
reg [15:0] spi_buffer;

always @(posedge SPI_SCK or posedge rst) begin
    if( rst ) begin 
        tx_cnt <= 3000;
        spi_st <= 0;
        spi_buffer <= { UIO_FILE_TX, 8'hff };
        spi_clkgate <= 1'b1;
        SPI_SS2 <= 1'b1;
        buff_cnt <= 15;
        spi_done <= 1'b0;       
    end
    else
    case( spi_st )
        SPI_INIT: begin
            if( tx_cnt ) tx_cnt <= tx_cnt-1; // wait for SDRAM to be ready
        else begin
            SPI_SS2 <= 1'b0;
            SPI_DI <= spi_buffer[buff_cnt];
            if( buff_cnt==0 ) begin
                $display("SPI transfer begins");
                spi_st <= SPI_SET;
            end
            else
                buff_cnt <= buff_cnt-1;
            end
        end
        SPI_SET: begin
            SPI_SS2 <= 1'b1;
            spi_buffer[7:0] <= UIO_FILE_TX_DAT;
            spi_st <= SPI_TX;
            buff_cnt <= 7;
        end
        SPI_TX: begin
            SPI_SS2 <= 1'b0;
            SPI_DI <= spi_buffer[buff_cnt];
            if( buff_cnt ) begin
                spi_clkgate <= 1'b1;
                buff_cnt <= buff_cnt-1;
            end
            else begin
                tx_cnt <= tx_cnt + 1;
                // $display("tx_cnt %X",tx_cnt);
                if(tx_cnt==TX_LEN) begin
                    SPI_SS2 <= 1'b1;
                    spi_st <= SPI_UNSET;
                end
                else begin
                    buff_cnt <= 7;
                    spi_buffer[7:0] <= rom_buffer[tx_cnt];
                end
                if(tx_cnt>TX_LEN) spi_st <= SPI_END;
            end
        end
        SPI_END: begin
            spi_done <= 1'b1;
            spi_clkgate <= 1'b0;
        end
        SPI_UNSET: begin
            spi_buffer <= {UIO_FILE_TX, 8'd0};
            buff_cnt <= 15;
            spi_st <= SPI_TX;
        end
    endcase
end

always @(spi_done)
    if(spi_done) begin
        $display("ROM loading completed");
        `ifdef DUMP
        $dumpon;
        `endif
    end

endmodule // spitx