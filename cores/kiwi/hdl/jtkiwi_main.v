/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 17-9-2022 */

module jtkiwi_main(
    input               rst,
    input               clk,
    input               cen6,
    input               LVBL,
    input               colprom_en,

    // Video devices
    output reg          vram_cs,
    output reg          vctrl_cs,
    output reg          vflag_cs,
    output reg          pal_cs,
    input      [ 7:0]   pal_dout,
    input      [ 7:0]   vram_dout,
    input      [ 8:0]   hcnt,

    output     [12:0]   cpu_addr,
    output     [ 7:0]   cpu_dout,
    output              cpu_rnw,

    // Sub CPU (sound)
    output reg          snd_rstn,
    //      access to RAM
    input      [12:0]   shr_addr,
    input      [ 7:0]   shr_din,
    input               sub_rnw,
    input               shr_cs,
    output reg          mshramen,
    output     [ 7:0]   shr_dout,

    input               dip_pause,

    // Banked RAM (TNZS)
    input               banked_ram,
    input      [ 7:0]   bram_data,
    output reg [14:0]   bram_addr,
    output reg          bram_cs,
    input               bram_ok,
    // ROM interface
    output     [16:0]   rom_addr,
    output reg          rom_cs,
    input      [ 7:0]   rom_data,
    // Debug
    input      [ 7:0]   debug_bus,
    output     [ 7:0]   st_dout
);
`ifndef NOMAIN
wire        irq_ack, mreq_n, m1_n, iorq_n, rd_n, wr_n,
            rfsh_n, int_n, ram_we, cpu_cen;
reg  [ 7:0] din;
wire [ 7:0] dout, ram_dout;
reg  [ 2:0] bank;
wire [15:0] A;
reg         ram_cs, bank_cs,
            sshramen, dev_busy, obj_vram_en;
wire        mem_acc;

assign cpu_rnw  = wr_n | ~cpu_cen;
assign cpu_addr = A[12:0];
assign cpu_dout = dout;
assign irq_ack  = /*!m1_n &&*/ !iorq_n; // The original PCB just uses iorq_n,
    // the orthodox way to do it is to use m1_n too
assign ram_we   = mshramen & ~wr_n;
assign rom_addr = { A[15] ? bank : {2'd0, A[14]}, A[13:0] };
assign st_dout  = { 3'd0, ~snd_rstn, 1'd0, bank };
assign mem_acc  = ~mreq_n & rfsh_n;

`ifdef SIMULATION
wire rombank_cs = rom_cs && A[15:12]>=8;
`endif

always @(posedge clk, posedge rst) begin
    if ( rst ) begin
        bram_cs   <= 0;
        rom_cs    <= 0;
        vram_cs   <= 0;
        ram_cs    <= 0;
        vctrl_cs  <= 0;
        vflag_cs  <= 0;
        bank_cs   <= 0;
        pal_cs    <= 0;
        bram_addr <= 0;
    end else begin
        bram_cs  <= 0;
        rom_cs   <= mem_acc && A[15:12]  < 4'hc;
        vram_cs  <= mem_acc && A[15:13] == 3'b110; // C,D
        ram_cs   <= mem_acc && A[15:12] == 4'he; // A[12:0] used in Insector X (?)
        vctrl_cs <= mem_acc && A[15:10] == 6'b1111_00; // internal RAM and config registers
        vflag_cs <= mem_acc && A[15: 9] == 7'b1111_010 && !wr_n; // config registers
        bank_cs  <= mem_acc && A[15: 9] == 7'b1111_011 && !wr_n; // f6xx/f7xx
        pal_cs   <= mem_acc && A[15:11] == 5'h1f && !colprom_en;
        if( mem_acc && banked_ram && bank<2 && A[15:12]>=8 && A[15:12]<4'hc ) begin
            rom_cs  <= 0;
            bram_cs <= 1;
            bram_addr <= { bank[0], A[13:0] };
        end
    end
end

always @* begin
    obj_vram_en = mem_acc && (
       (A[15:11]==5'b11110 && !A[9]) ||
       A[15:10]==6'b111100 ||
       A[15:13]==3'b110 );
    dev_busy = (sshramen & ram_cs) || (obj_vram_en && hcnt[1:0]!=0) || (bram_cs&&!bram_ok);
end

always @(posedge clk) begin
    din <= rom_cs  ? rom_data  :
        ram_cs  ? ram_dout  :
        bram_cs ? bram_data :
        (vram_cs | vctrl_cs) ? vram_dout :
        pal_cs  ? pal_dout  : 8'h00;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank     <= 0;
        snd_rstn <= 0;
    end else begin
        if( bank_cs ) begin
            bank <= dout[2:0];
            snd_rstn <= dout[4];
`ifdef SIMULATION
            if( !snd_rstn && dout[4] ) $display("Sound CPU reset released");
            if( snd_rstn && !dout[4] ) $display("Sound CPU reset");
`endif
        end
    end
end

`ifdef SIMULATION
    integer line_cnt=1;

    always @(negedge ram_cs, posedge rst) begin
        if( rst )
            line_cnt <= 1;
        else
            line_cnt <= line_cnt+1;
    end
`endif

jtframe_ff u_irq(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .cen    ( 1'b1      ),
    .din    ( 1'b1      ),
    .q      (           ),
    .qn     ( int_n     ),
    .set    ( 1'b0      ),
    .clr    ( irq_ack   ),
    .sigedge( ~LVBL & dip_pause  )
);

// To do: add dev_busy to match the wait signal
// when accessing the VRAM
jtframe_z80_devwait #(.RECOVERY(0)) u_gamecpu(
    .rst_n    ( ~rst   ),
    .clk      ( clk    ),
    .cen      ( cen6   ),
    .cpu_cen  ( cpu_cen),
`ifdef NOINT
    .int_n    ( 1'b1   ),
`else
    .int_n    ( int_n  ),
`endif
    .nmi_n    ( 1'b1   ),
    .busrq_n  ( 1'b1   ),
    .m1_n     ( m1_n   ),
    .mreq_n   ( mreq_n ),
    .iorq_n   ( iorq_n ),
    .rd_n     ( rd_n   ),
    .wr_n     ( wr_n   ),
    .rfsh_n   ( rfsh_n ),
    .halt_n   (        ),
    .busak_n  (        ),
    .A        ( A      ),
    .din      ( din    ),
    .dout     ( dout   ),
    .rom_cs   ( rom_cs ),
    .rom_ok   ( 1'b1   ),
    .dev_busy ( dev_busy )
);

// first come, first served
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mshramen <= 0;
        sshramen <= 0;
    end else begin
        // Main CPU drives the RAM
        if( ram_cs && !sshramen )
            mshramen <= 1;
        if( !ram_cs ) mshramen <= 0;
        // Sub CPU drives the RAM
        if( shr_cs && !mshramen && !ram_cs )
            sshramen <= 1;
        if( !shr_cs ) sshramen <= 0;
    end
end

jtframe_dual_ram #(.AW(13),.DUMPFILE("mainmem")) u_comm(
    .clk0   ( clk        ),
    .clk1   ( clk        ),
    // Main CPU
    .addr0  ( A[12:0]    ),
    .data0  ( dout       ),
    .we0    ( ram_we     ),
    .q0     ( ram_dout   ),
    // MCU
    .addr1  ( shr_addr   ),
    .data1  ( shr_din    ),
    .we1    ( sshramen & ~sub_rnw ),
    .q1     ( shr_dout   )
`ifdef JTFRAME_DUAL_RAM_DUMP
    ,.dump   ( LVBL       )
`endif
);
`else // NOMAIN
    initial begin
        rom_cs   = 0;
        rom_addr = 0;
        vram_cs  = 0;
        vflag_cs = 0;
        vctrl_cs = 0;
        pal_cs   = 0;
        snd_rstn = 0;
        mshramen = 0;
    end
    assign cpu_rnw  = 1;
    assign cpu_addr = 1;
    assign cpu_dout = 0;
    assign shr_dout = 0;
    assign st_dout  = 0;
`endif
endmodule