// taken and tweaked from MiSTer sys/
module i2c_master
(
	input        CLK,

	input        I2C_START,
	input        I2C_READ,
	input  [6:0] I2C_ADDR,
	input  [7:0] I2C_SUBADDR,
	input  [7:0] I2C_WDATA,
	output [7:0] I2C_RDATA,
	output reg   I2C_END = 1,
	output reg   I2C_ACK = 0,

	//I2C bus
	inout        I2C_SCL,
	inout        I2C_SDA
);


//	Clock Setting
parameter CLK_Freq = 50_000_000;	//	50 MHz
parameter I2C_Freq = 400_000;		//	400 KHz

localparam I2C_FreqX2 = I2C_Freq*2;

reg         I2C_CLOCK;
reg  [31:0] cnt;
wire [31:0] cnt_next = cnt + I2C_FreqX2;

always @(posedge CLK) begin
	cnt <= cnt_next;
	if(cnt_next >= CLK_Freq) begin
		cnt <= cnt_next - CLK_Freq;
		I2C_CLOCK <= ~I2C_CLOCK;
	end
end

reg        SCLK;
reg [15:0] SDO;
reg  [0:7] rdata;

reg  [6:0] SD_COUNTER;
reg [0:42] SD;

assign I2C_SCL = (SCLK | I2C_CLOCK) ? 1'bZ : 1'b0;
assign I2C_SDA = SDO[15] ? 1'bZ : 1'b0;

initial begin
	SD_COUNTER = 'b1111111;
	SD   = {40'hFFFFFFFFFF, 3'b111};
	SCLK = 1;
	SDO  = 16'hFFFF;
end

assign I2C_RDATA = rdata;

always @(posedge CLK) begin
	reg old_clk;
	reg old_st;
	reg rd;
	reg sda_in;

	old_clk <= I2C_CLOCK;
	old_st  <= I2C_START;
	sda_in <= I2C_SDA;

	// delay to make sure SDA changed while SCL is stabilized at low
	if(old_clk && ~I2C_CLOCK && ~SD_COUNTER[6]) SDO[0] <= SD[SD_COUNTER[5:0]];
	SDO[15:1] <= SDO[14:0];

	if(~old_st && I2C_START) begin
		SCLK <= 1;
		SDO  <= 16'hFFFF;
		I2C_ACK  <= 0;
		I2C_END  <= 0;
		rd   <= I2C_READ;
		if(I2C_READ) SD[0:42] <= {2'b10, I2C_ADDR, 1'b0, 1'b1, I2C_SUBADDR, 3'b110, I2C_ADDR, 1'b1, 1'b1, 8'b11111111, 4'b1011};
		else         SD[0:31] <= {2'b10, I2C_ADDR, 1'b0, 1'b1, I2C_SUBADDR, 1'b1, I2C_WDATA, 4'b1011};
		SD_COUNTER <= 0;
	end else begin
		if(~old_clk && I2C_CLOCK && ~SD_COUNTER[6]) begin
			SD_COUNTER <= SD_COUNTER + 6'd1;
			case(SD_COUNTER)
			      01: SCLK <= 0;
			      10: I2C_ACK <= ~sda_in;
			      19: I2C_ACK <= ~sda_in;
						20: if (rd) SCLK <= 1; // repeated start
						21: if (rd) SCLK <= 0;
			      28: if (~rd) I2C_ACK  <= ~sda_in;
						29: if (~rd) SCLK <= 1;
			      30: if (rd) I2C_ACK <= ~sda_in;
			      32: if (~rd) begin
							I2C_END  <= 1;
							SD_COUNTER <= 64;
						end
						40: SCLK <= 1;
						42: begin
							I2C_END <= 1;
							SD_COUNTER <= 64;
						end
						64: SCLK <= 1;
						default: ;
			endcase

			if(SD_COUNTER >= 31 && SD_COUNTER <= 38) rdata[SD_COUNTER[5:0]-31] <= sda_in;
		end
	end
end

endmodule