
module TC0030CMD(
    input clk,
    input ce,

    input RESETn,
    input NMIn,
    input INT1n,
    input ASIC_MODESEL,
    input MODE1,
    input [7:0] AN,

    // CPU interface
    input CSn,
    input RW,
    input [7:0] Din,
    output [7:0] Dout,
    input [10:0] A,
    output DTACKn,

    // Ports
    input  [7:0] PAin,
    input  [7:0] PBin,
    input  [7:0] PCin,
    output [7:0] PAout,
    output [7:0] PBout,
    output [7:0] PCout,

    ssbus_if.slave ssb
);


assign DTACKn = 0;
assign PAout = 8'h00;
assign PBout = 8'h00;
assign PCout = 8'h00;

wire ram_n = CSn | A[10];
wire asic_n = CSn | ~A[10];

wire [7:0] ram_data, ram_q;
wire [9:0] ram_addr;
wire ram_wren;

ram_ss_adaptor #(.WIDTH(8), .WIDTHAD(10), .SS_IDX(SSIDX_CCHIP_RAM)) ram_ss(
    .clk,

    .wren_in(~ram_n & ~RW),
    .addr_in(A[9:0]),
    .data_in(Din),

    .wren_out(ram_wren),
    .addr_out(ram_addr),
    .data_out(ram_data),

    .q(ram_q),

    .ssbus(ssb)
);

singleport_ram #(.WIDTH(8), .WIDTHAD(10)) ram(
    .clock(clk),
    .wren(ram_wren),
    .address(ram_addr),
    .data(ram_data),
    .q(ram_q)
);

assign Dout = ~ram_n ? ram_q : ~asic_n ? 8'h01 : 8'h00;

endmodule



