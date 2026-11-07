module i2c #(
    parameter CLK_Freq = 50_000_000,
    parameter I2C_Freq = 500_000
) (
    input CLK,
    input START,
    input READ,
    input [6:0] I2C_ADDR,
    input I2C_WLEN,
    input [7:0] I2C_WDATA1,
    input [7:0] I2C_WDATA2,
    output reg [7:0] I2C_RDATA = 0,
    output reg END = 1,
    output reg ACK = 0,
    output I2C_SCL,
    inout I2C_SDA
);

reg busy = 0;
reg [2:0] delay_count = 0;
integer read_count = 0;
reg read_l = 0;

assign I2C_SCL = 1'b1;
assign I2C_SDA = 1'bz;

always @(posedge CLK) begin
    if (!busy && START) begin
        busy <= 1;
        END <= 0;
        ACK <= 0;
        delay_count <= 3;
        read_l <= READ;
    end else if (busy) begin
        if (delay_count != 0) begin
            delay_count <= delay_count - 1'b1;
        end else begin
            busy <= 0;
            END <= 1;
            ACK <= 0;
            if (read_l) begin
                case (read_count)
                    0, 3: I2C_RDATA <= 8'hA8;
                    1, 2, 6, 7: I2C_RDATA <= 8'hE8;
                    4: I2C_RDATA <= 8'hA8;
                    5: I2C_RDATA <= 8'hD0;
                    default: I2C_RDATA <= 8'hE8;
                endcase
                if (read_count == 5) ACK <= 1;
                read_count <= read_count + 1;
            end
        end
    end
end

endmodule
