`timescale 1ns/1ps
// Pin-level synchronous Cell RAM model with variable initial/burst WAIT.
module cell_ram_model #(parameter HW=9, VW=8)(
    input clk, stall,
    input [21:16] cr_addr,
    inout [15:0] cr_adq,
    output cr_wait,
    input cr_advn, cr_cre,
    input [1:0] cr_cen,
    input cr_oen, cr_wen,
    input [1:0] cr_dsn,
    output write_beat, read_beat,
    output reg [21:0] address=0,
    output [15:0] write_data
);
localparam AW=HW+VW+1;
reg active=0, config_access=0, latency_phase=0;
reg [2:0] latency=0;
wire selected, read_clk, store;
wire [AW-1:0] ram_addr;
wire [15:0] ram_data;
assign selected=!cr_cen[0];
assign cr_wait=selected && active && cr_advn && latency==0 && !stall;
assign write_beat=cr_wait && !config_access && cr_oen && !cr_wen;
assign read_beat=cr_wait && !config_access && !cr_oen && cr_wen;
assign cr_adq=read_beat ? ram_data : 16'hzzzz;
assign write_data=cr_adq;
assign ram_addr={address[21],address[20-:VW],address[HW-1:0]};
assign read_clk=~clk;
assign store=write_beat && cr_dsn==0;

// Reading on the opposite edge models data becoming valid before the next
// memory clock edge. The DUT still uses the real synchronous line RAMs.
jtframe_dual_ram #(.DW(16),.AW(AW)) u_ram(
    .clk0(clk), .addr0(ram_addr), .data0(write_data), .we0(store), .q0(),
    .clk1(read_clk), .addr1(ram_addr), .data1(16'd0), .we1(1'b0), .q1(ram_data)
);
always @(posedge clk) begin
    if(!selected) begin
        active<=0;
        latency<=0;
    end else if(!cr_advn) begin
        address<={cr_addr,cr_adq};
        config_access<=cr_cre;
        active<=1;
        latency<=latency_phase ? 4 : 3;
        latency_phase<=~latency_phase;
    end else if(latency!=0) begin
        latency<=latency-1'd1;
    end else if(write_beat || read_beat) begin
        address<=address+1'd1;
    end
end
endmodule
