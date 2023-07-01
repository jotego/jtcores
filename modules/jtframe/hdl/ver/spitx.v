//////////////////////////////////////////////////////////////
// Sends the ROM data via SPI
// After the ROM, it will send a 10 pattern for the OSD image
// define LOAD_ROM to send ROM data, OSD will be sent after it
// if LOAD_ROM is not defined, only the OSD data will be sent
// if SIMULATE_OSD is defined, the enable OSD command will be sent
// at the end too

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
        cnt       <= 3'h0;
        spi_clk   <= 1'b0;
        databuf   <= 8'h0;
        data_sent <= 1'b0;
    end else begin
        if( send ) begin
            cnt <= ~3'h0;
            databuf <= datain;
            spi_clk <= 1'b0;
        end
        else begin
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
    output  reg SPI_SS3,
    output  SPI_SS4,
    output  reg CONF_DATA0,
    output  reg spi_done
);
parameter filename="../../../rom/JT1942.rom";
parameter TX_LEN           = 1024*1024,
          TX_OFFSET        = 0;     // offset at which transmission starts

integer file, tx_cnt, file_len;
assign SPI_SS4=1'b1;

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
    file_len=$fseek( file, TX_OFFSET, 0 );
    file_len=$fread( rom_buffer, file );
    $display("INFO: Read %s for SPI transmission (%0d bytes).",filename, file_len);
    if( file_len == 0 ) begin
        $display("ERROR: ROM file is empty.");
        $finish;
    end
    if( TX_LEN < file_len ) begin
        $display("INFO: Only the first %0d bytes of ROM will be downloaded",TX_LEN);
    end
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

integer state, next, slow;
reg hold;

localparam CLKSPEED=24; // MiST is probably 28MHz or CLKSPEED=17.857
    // 8 is the fastest for 48MHz SDRAM access

initial begin
    clk = 0;
    forever #(CLKSPEED) clk = ~clk;
end

// Define LOAD_RANDOM_DLY to delay the start of the load process
`ifndef LOAD_RANDOM_DLY
`define LOAD_RANDOM_DLY 0
`endif

`ifndef JTFRAME_SIM_LOAD_EXTRA
localparam WAIT=0;
`else
localparam WAIT=`JTFRAME_SIM_LOAD_EXTRA;
`endif

always @(posedge clk or posedge rst)
if( rst ) begin
    tx_cnt <= 4000+`LOAD_RANDOM_DLY;
    state <= 0;
    SPI_SS2  <= 1'b1;
    SPI_SS3  <= 1'b1;
    spi_done <= 1'b0;
    send     <= 1'b0;
    hold     <= 1'b1;
    slow     <= 0;
end
else begin
    if( !hold ) begin
        state <= state + 1;
    end
    send    <= 1'b0;
    case( state )
        default: if(data_sent) hold <= 1'b0;
        0: begin
            SPI_SS2 <= 1'b0;
            if( tx_cnt )
                tx_cnt <= tx_cnt-1; // wait for SDRAM to be ready
            else begin
                SPI_SS2 <= 1'b1;
                hold <= 1'b0;
            end
        end
        // send DOWNLOAD signal
        1: begin
            $display("ROM loading starts (%1d ns)",$time());
            SPI_SS2 <= 1'b0;
            data <= UIO_FILE_TX;
            send <= 1'b1;
            hold <= 1'b1;
        end
        3: begin
            data <= 8'h1;
            send <= 1'b1;
            hold <= 1'b1;
        end
        // send DATA signal
        5: begin
            SPI_SS2 <= 1'b1;
        end

        6: begin
            SPI_SS2 <= 1'b0;
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
            if( tx_cnt==file_len || tx_cnt== TX_LEN ) begin
                state <= 10;
                hold  <= 1'b0;
            end
            else begin
                if( WAIT ) begin
                    slow <= WAIT;
                    state <= 100;
                end else begin
                    hold <= 1'b0;
                    state <= 8;
                end
            end
        end
        100: begin
            slow <= slow-1;
            if( !slow ) begin
                hold <= 1'b0;
                state <= 8;
            end
        end
        // finish DOWNLOAD signal
        10: SPI_SS2 <= 1'b1;
        11: begin
            $display("ROM loading finished (%1d bytes, %1d ns)", file_len, $time);
            SPI_SS2 <= 1'b0;
            data <= UIO_FILE_TX;
            send <= 1'b1;
            hold <= 1'b1;
        end
        13: begin
            data <= 8'h0; // Toggle down downloading signal
            send <= 1'b1;
            hold <= 1'b1;
            SPI_SS3  <= 1'b1;
        end
        // Send OSD image
        15: begin
            hold     <= 1'b0;
            spi_done <= 1'b1;
            SPI_SS2  <= 1'b1; // load over
        end
        16: begin // write command
            SPI_SS3  <= 1'b0;
            data     <= 8'h20;
            send     <= 1'b1;
            hold     <= 1'b1;
            tx_cnt   <= 0;
        end
        18: begin
            data   <= 8'hAA;
            send   <= 1'b1;
            hold   <= 1'b1;
            tx_cnt <= tx_cnt+1;
        end
        19: if( data_sent ) begin
            if( tx_cnt!=2047 ) state <= 18;
            hold <= 1'b0;
        end
`ifndef SIMULATE_OSD
        20: begin // OSD over
            hold    <= 1'b1;
            SPI_SS3 <= 1'b1;
        end
`else
        20: SPI_SS3 <= 1'b1;    // send new command
        21: SPI_SS3 <= 1'b0;
        22: begin
            data <= 8'h41;
            send <= 1'b1;
        end
        23: begin
            hold <= 1'b1;
        end
`endif
    endcase
end
endmodule // spitx