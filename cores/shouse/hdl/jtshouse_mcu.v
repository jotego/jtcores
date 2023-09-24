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
    Date: 24-9-2023 */

// Port 4 configured as output --> use as address bus
// Port 6 configured as output

module jtshouse_mcu(
    input              clk,
    input              rstn,
    input              cen,

    // cabinet I/O
    input       [1:0]  start_button,
    input       [1:0]  coin_input,
    input       [6:0]  joystick1,
    input       [6:0]  joystick2,
    input       [7:0]  dipsw,
    input              service,
    input              dip_test,

    // PROM programming
    input      [11:0]  prog_addr,
    input      [ 7:0]  prog_data,
    input              prog_we,

    output     [19:0]  pcm_addr,
    input      [ 7:0]  pcm_data,
    output reg         pcm_cs,
    input              pcm_ok,
    output             bus_busy
);

wire        vma, rnw, intram_we;
reg         port_cs, ram_cs, triram_cs,
            dip_cs,  cab_cs;

wire [15:0] A;
wire [ 7:0] mcu_dout, ram_dout;
reg  [ 7:0] mcu_din, cab_dout;
reg  [15:0] lt;         // DAC control
reg  [ 2:0] bank;
reg  [ 1:0] pcm_msb;

assign bus_busy    = pcm_cs & ~pcm_ok;
assign mcu_irqmain =  p6_dout[1];
assign intram_we   = ram_cs & ~rnw;
assign pcm_addr    = {bank, bank==0 ? ~pcm_msb[1] : pcm_msb[1], pcm_msb[0], A[15],A[13:0]};

// Address decoder
always @(*) begin
    rom_cs    = 0;
    pcm_cs    = 0;
    ram_cs    = 0;
    swio_cs   = 0;
    triram_cs = 0;
    port_cs   = 0;
    if( vma ) begin
        port_cs = A[15:12]==4'h0;
        swio_cs = A[15:12]==4'h1;
        reg_cs  = A[15:12]==4'hd & ~rnw;
        rom_cs  = A[15:12]==4'hf &  rnw;

        dip_cs  = swio_cs && A[11:10]==0;
        cab_cs  = swio_cs && A[11:10]==1;
    end
end

// Ports
reg [7:0] ports[0:31];

always @* begin
    mcu_din =   rom_cs  ? rom_data :
                pcm_cs  ? pcm_data :
                dip_cs  ? dipsw    :
                cab_cs  ? cab_dout :
end

always @(posedge clk, negedge rstn ) begin
    if( !rstn ) begin
        p6_dout <= 8'd0;
        bank    <= 0;
        lt      <= 0;
        cab_dout<= 0;
    end else begin
        cab_dout <= A[0] ? { start_button[1], joystick2 }:
                           { start_button[0], joystick1 };
        if( reg_cs ) case(A[1:0])
            0: lt[ 7:0] <= mcu_dout;
            1: lt[15:8] <= mcu_dout;
            2: begin
                pcm_msb <= mcu_dout[1:0];
                case( mcu_dout[7:2] )
                    6'd1<<0: bank <= 0;
                    6'd1<<1: bank <= 1;
                    6'd1<<2: bank <= 2;
                    6'd1<<3: bank <= 3;
                    6'd1<<4: bank <= 4;
                    6'd1<<5: bank <= 5;
                    default: bank <= 0;
                endcase
            end
        endcase
        ports[A[4:0]] <= mcu_dout;
        if( port_cs && A[5:0]==6'h17 ) p6_dout <= mcu_dout;
    end
end

`ifdef SIMULATION
always @(posedge port_cs) begin
    if( A[5:0] !=6'h17 && vma ) begin
        if( rnw )
            $display("WARNING: Access to non-supported MCU port %X", A );
        else
            $display("WARNING: Write to non-supported MCU port %X, data = %X", A, mcu_dout );
    end
end
`endif

wire halted;

m6801 u_6801(
    .rst        ( ~rstn     ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .rw         ( rnw       ),
    .vma        ( vma       ),
    .address    ( A         ),
    .data_in    ( mcu_din   ),
    .data_out   ( mcu_dout  ),
    .halt       ( mcu_halt  ),
    .halted     ( halted    ),
    .irq        ( 1'b0      ),
    .nmi        ( 1'b1      ),
    .irq_icf    ( 1'b0      ),
    .irq_ocf    ( 1'b0      ),
    .irq_tof    ( 1'b0      ),
    .irq_sci    ( 1'b0      )
);

jtframe_ram #(.AW(8)) u_intram(
    .clk    ( clk       ),
    .cen    ( cen       ),
    .data   ( mcu_dout  ),
    .addr   ( A[7:0]    ),
    .we     ( intram_we ),
    .q      ( ram_dout  )
);

jtframe_prom #(.AW(12)) u_intram(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( prog_data ),
    .we     ( prog_we   ),
    .wr_addr( prog_addr ),
    .rd_addr( A[11:0]   ),
    .q      ( rom_data  )
);

endmodule
