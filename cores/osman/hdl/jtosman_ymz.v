/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-11-2026 */

module jtosman_ymz(
    input                   rst,
    input                   clk,
    input                   cen,
    input                   cs,
    input                   wr,
    input                   rd,
    input                   addr,
    input           [ 7:0]  din,
    output          [ 7:0]  dout,
    output                  ready,
    output reg              rom_cs,
    output reg      [20:0]  rom_addr,
    input           [ 7:0]  rom_data,
    input                   rom_ok,
    output signed   [15:0]  snd_l,
    output signed   [15:0]  snd_r,
    output                  overrun
);

wire [23:0] chip_addr;
wire chip_cs;
reg chip_ok;
reg [7:0] chip_data;
reg [1:0] state;
reg cancelled;

jtymz280b u_chip(
    .rst       ( rst        ),
    .clk       ( clk        ),
    .cen       ( cen        ),
    .cs        ( cs         ),
    .wr        ( wr         ),
    .rd        ( rd         ),
    .addr      ( addr       ),
    .din       ( din        ),
    .dout      ( dout       ),
    .cpu_ready ( ready      ),
    .irq       (            ),
    .rom_addr  ( chip_addr  ),
    .rom_cs    ( chip_cs    ),
    .rom_we    (            ),
    .rom_dout  (            ),
    .rom_data  ( chip_data  ),
    .rom_ok    ( chip_ok    ),
    .snd_l     ( snd_l      ),
    .snd_r     ( snd_r      ),
    .sample    (            ),
    .overrun   ( overrun    )
);

always @(posedge clk) begin
    if(rst) begin
        state <= 0;
        rom_cs <= 0;
        rom_addr <= 0;
        chip_ok <= 0;
        chip_data <= 0;
        cancelled <= 0;
    end else case(state)
        0: if(chip_cs) begin
            rom_addr <= {chip_addr[19:0],chip_addr[20]};
            rom_cs <= 1;
            cancelled <= 0;
            state <= 1;
        end
        1: begin
            if(!chip_cs) cancelled <= 1;
            if(rom_ok) begin
                rom_cs <= 0;
                if(cancelled || !chip_cs) state <= 0;
                else begin
                    chip_data <= rom_data;
                    chip_ok <= 1;
                    state <= 2;
                end
            end
        end
        2: if(!chip_cs) begin
            chip_ok <= 0;
            state <= 0;
        end
        default: state <= 0;
    endcase
end

`ifdef OSMAN_YMZ_TRACE
integer trace_file, trace_reads=0;
reg [7:0] trace_reg=0;
reg trace_overrun=0;
initial trace_file=$fopen("ymz.log","w");
always @(posedge clk) if(!rst && trace_file!=0) begin
    if(cs && wr && ready) begin
        if(!addr) trace_reg <= din;
        else begin
            $fwrite(trace_file,"%0t reg=%02x data=%02x playing=%02x\n",$time,trace_reg,din,u_chip.playing);
            $fflush(trace_file);
        end
    end
    if(rom_cs && rom_ok && trace_reads<16) begin
        trace_reads <= trace_reads+1;
        $fwrite(trace_file,"rom=%06x data=%02x\n",rom_addr,rom_data);
    end
    if(overrun && !trace_overrun) $fwrite(trace_file,"OVERRUN\n");
    trace_overrun <= overrun;
end
`endif

endmodule
