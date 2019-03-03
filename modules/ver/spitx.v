`timescale 1 ns / 1 ps

module spitx_sub(
    input       rst,
    input       clk,
    output reg  spi_clk,
    input       [7:0] datain,
    input       send,  // send strobe
    output reg  data_sent,
    output      spi_ser
);

reg [2:0] cnt;
reg [7:0] databuf;

assign spi_ser = databuf[7];

always @(posedge clk)
    if ( rst ) begin
        spi_clk   <= 1'b0;
        databuf   <= 8'h0;
        data_sent <= 1'b0;
    end else begin
        if( send ) begin
            cnt <= ~3'h0;
            databuf <= datain;
            spi_clk <= 1'b0;
        end
        if( !spi_clk ) begin
            spi_clk   <= 1'b1;
            data_sent <= 1'b0;
        end else if(cnt!=3'h0 ) begin
            databuf <= { databuf[7:0], 1'b0 };
            spi_clk <= 1'b0;
            cnt <= cnt - 3'h1;
            if( cnt==3'd1 ) data_sent <= 1'b1;
        end
    end
endmodule

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
module spitx(
    input   rst,
    input   SPI_DO,
    output  SPI_SCK,
    output  SPI_DI,
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
reg send;

initial begin
    file=$fopen(filename,"rb");
    if( file==0 ) begin
        $display("ERROR: %m\n\tcould not open file %s", filename );
        $finish;
    end
    tx_cnt=$fread( rom_buffer, file );
    if( tx_cnt != TX_LEN ) begin
        $display("ERROR: %m\n\t%s", filename," was expected to be of length %d", TX_LEN );
        $finish;
    end
    $display("INFO: Read %s for SPI transmission.",filename);
    $fclose(file);
end

reg clk;
wire data_sent;
reg [7:0] data;

spitx_sub u_sub(
    .rst       ( rst          ),
    .clk       ( clk          ),
    .spi_clk   ( SPI_SCK      ),
    .datain    ( data         ),
    .send      ( send         ),  // send strobe
    .data_sent ( data_sent    ),
    .spi_ser   ( SPI_DI       )
);

integer state, next;
reg hold;

localparam clkspeed=8; // MiST is probably 28MHz or clkspeed=17.857

initial begin
    clk = 0;
    forever #(clkspeed) clk = ~clk;
end

always @(posedge clk or posedge rst)
if( rst ) begin
    tx_cnt <= 8000;
    state <= 0;
    SPI_SS2 <= 1'b0;
    spi_done <= 1'b0;
    send     <= 1'b0;
    hold     <= 1'b1;
end
else begin
    if( !hold ) begin
        state <= state + 1;
    end
    SPI_SS2 <= 1'b0;
    send    <= 1'b0;
    case( state )
        0: begin
            if( tx_cnt )
                tx_cnt <= tx_cnt-1; // wait for SDRAM to be ready
            else begin
                SPI_SS2 <= 1'b1;
                hold <= 1'b0;
            end
        end
        // send DOWNLOAD signal
        1: begin
            $display("ROM loading starts");
            data <= UIO_FILE_TX;
            send <= 1'b1;
            hold <= 1'b1;
        end
        2,4,7,12: if(data_sent) hold <= 1'b0;
        3: begin
            data <= 8'h1;
            send <= 1'b1;
            hold <= 1'b1;
        end
        // send DATA signal
        5: SPI_SS2 <= 1'b1;
        6: begin
            data <= UIO_FILE_TX_DAT;
            send <= 1'b1;
            hold <= 1'b1;
        end
        // send actual data:
        8: begin
            data <= rom_buffer[tx_cnt];
            send <= 1'b1;
            hold <= 1'b1;
            tx_cnt <= tx_cnt + 1;
        end
        9: if( data_sent ) begin
            if( tx_cnt!=TX_LEN ) state <= 8;
            hold <= 1'b0;
        end
        // finish DOWNLOAD signal
        10: SPI_SS2 <= 1'b1;
        11: begin
            $display("ROM loading finished");
            data <= UIO_FILE_TX;
            send <= 1'b1;
            hold <= 1'b1;
        end
        13: begin
            data <= 8'h0; // Toggle down downloading signal
            send <= 1'b1;
            hold <= 1'b1;
            spi_done <= 1'b1;
        end
    endcase
end

endmodule // spitx