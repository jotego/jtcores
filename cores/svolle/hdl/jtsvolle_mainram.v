/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-10-2026 */

module jtsvolle_mainram(
    input             rst, clk, rpunch,
    input      [19:1] cpu_addr,
    input      [15:0] cpu_dout,
    input      [1:0]  cpu_dsn,
    input             cpu_cs, cpu_we,
    output     [16:1] ram_addr,
    output     [15:0] ram_din,
    output     [1:0]  ram_dsn,
    output            ram_cs, ram_we,
    input             ram_ok,
    output reg        busy
);

reg [14:0] clear_addr;
reg [1:0] state;
wire [15:0] clear_data;

assign ram_addr = busy ? {1'b1,clear_addr} :
                 rpunch && cpu_addr[19:16]==4'h4 ? {1'b1,cpu_addr[15:1]} :
                 {3'd0,cpu_addr[13:1]};
assign ram_cs = busy ? state==1 : cpu_cs;
assign ram_we = busy ? state==1 : cpu_we;
assign ram_dsn = busy ? 2'b00 : cpu_dsn;
assign ram_din = busy ? clear_data : cpu_dout;

`ifdef SIMULATION
reg [15:0] initial_data[0:32767];
integer i, file_handle, byte_count;
initial begin
    for(i=0;i<32768;i=i+1) initial_data[i]=16'hffff;
    file_handle=$fopen("bitmap.bin","rb");
    if(file_handle!=0) begin
        byte_count=$fread(initial_data,file_handle);
        $fclose(file_handle);
        $display("SVOLLE bitmap restore: %0d bytes",byte_count);
    end
end
assign clear_data = initial_data[clear_addr];
`else
assign clear_data = 16'hffff;
`endif

always @(posedge clk) begin
    if(rst) begin
        busy <= rpunch;
        clear_addr <= 0;
        state <= 0;
    end else if(busy) begin
        case(state)
            0: state <= 1;
            1: if(ram_ok) state <= 2;
            2: if(!ram_ok) begin
                if(&clear_addr) busy <= 0;
                else begin
                    clear_addr <= clear_addr+15'd1;
                    state <= 0;
                end
            end
            default: state <= 0;
        endcase
    end
end

endmodule
