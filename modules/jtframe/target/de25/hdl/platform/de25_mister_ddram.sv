// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps

module de25_mister_ddram #(
    parameter logic [31:0] PHYSICAL_OFFSET = 32'h8000_0000,
    parameter int DATA_WIDTH = 64,
    parameter int ADDRESS_WIDTH = 29
) (
    input  logic        reset,
    input  logic  [7:0] core_burstcount,
    input  logic [ADDRESS_WIDTH-1:0] core_address,
    output logic        core_busy,
    output logic [DATA_WIDTH-1:0] core_readdata,
    output logic        core_readdatavalid,
    input  logic        core_read,
    input  logic [DATA_WIDTH-1:0] core_writedata,
    input  logic [(DATA_WIDTH/8)-1:0] core_byteenable,
    input  logic        core_write,
    input  logic        av_waitrequest,
    input  logic [DATA_WIDTH-1:0] av_readdata,
    input  logic        av_readdatavalid,
    output logic  [7:0] av_burstcount,
    output logic [31:0] av_address,
    output logic [DATA_WIDTH-1:0] av_writedata,
    output logic [(DATA_WIDTH/8)-1:0] av_byteenable,
    output logic        av_read,
    output logic        av_write
);

    assign core_busy          = reset | av_waitrequest;
    assign core_readdata      = av_readdata;
    assign core_readdatavalid = av_readdatavalid;
    assign av_burstcount      = core_burstcount;
    // DDRAM_ADDR is an Avalon 64-bit word address. Preserve MiSTer's complete
    // 0x20000000 through 0x3fffffff byte-addressed DDR window and translate it
    // to 0xa0000000 through 0xbfffffff in the DE25-Nano HPS address space.
    // Addition, rather than masking or ORing, keeps the two 256 MiB halves
    // distinct and matches the translation used by Main's /dev/mem backend.
    localparam int ADDRESS_SHIFT = $clog2(DATA_WIDTH / 8);
    wire [31:0] core_byte_address =
        {{(32-ADDRESS_WIDTH){1'b0}}, core_address} << ADDRESS_SHIFT;
    assign av_address         = PHYSICAL_OFFSET + core_byte_address;
    assign av_writedata       = core_writedata;
    assign av_byteenable      = core_byteenable;
    assign av_read            = core_read & ~reset;
    assign av_write           = core_write & ~reset;

endmodule
