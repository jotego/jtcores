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
    Date: 17-5-2023 */

module jtngp_flash(
    input             rst,
    input             clk,

    input      [ 2:0] dev_type, // see below
    // interface to CPU
    input      [20:1] cpu_addr,
    input             cpu_cs,
    input             cpu_we,
    input      [15:0] cpu_dout,
    output     [15:0] cpu_din,
    output            rdy,      // rdy / ~bsy pin
    output            cpu_ok,   // read data available

    // interface to SDRAM
    output reg [20:1] cart_addr,
    output reg        cart_we,
    output reg        cart_cs,
    input             cart_ok,
    input      [15:0] cart_data,
    output reg [15:0] cart_din
);

localparam [2:0] DEV_2F = 0, //   2 or 4 MB
                 DEV_2C = 1, //   1 MB
                 DEV_AB = 2; // <=512 kB

localparam [2:0] READ     = 0,
                 PROG1    = 1,
                 PROG2    = 3,
                 CMD      = 2,
                 AUTOPROG = 7,
                 PROTECT  = 6;

localparam [2:0] BA_64K = 3'b000,
                 BA_32K = 3'b100,
                 BA_16K = 3'b110,
                 BA_8K  = 3'b111;

reg  [ 2:0] st;
reg  [20:0] ba_addr, eff_addr, prog_ba, prog_addr;
reg  [ 2:0] ba_size, prog_size;
reg  [ 7:0] cmd, id_data;
wire        cpu_cswe, we_edge;
reg         cswe_l, id;
// cartridge access
reg  [ 1:0] erase_st;
reg  [ 2:0] prog_st;
reg  [ 7:0] prog_data;
reg         erase_start, prog_start, erase_bsy, prog_bsy,
            ba_full, rd_bsy;
wire        last;

assign last = &{ cart_addr[15:13] | prog_size, cart_addr[12:0] };
assign cpu_din = id ? {2{id_data}} : cart_data;
assign cpu_ok  = id | cart_ok;
assign cpu_cswe = cpu_cs && cpu_we;
assign we_edge  = cpu_cswe && !cswe_l;
assign rdy      = ~|{erase_bsy,prog_bsy,rd_bsy};

always @* begin
    case( cpu_addr[1:0] )
        0: id_data = 8'h98; // manufacturer ID
        1: id_data = dev_type == DEV_AB ? 8'hAB :
                     dev_type == DEV_2C ? 8'h2C : 8'h2F;
        2: id_data = 2;
        3: id_data = 8'h80;
    endcase
end

always @* begin
    // gate unused bits depending on the memory type
    eff_addr = cpu_addr;
    case( dev_type )
        DEV_AB: eff_addr[20:19] = 0;
        DEV_2C: eff_addr[20] = 0;
        default:;
    endcase
    // get the block starting address
    ba_addr = { eff_addr[20:13], 13'd0 };
    ba_size = BA_64K;
    case( dev_type )
        DEV_AB:  ba_full = ~&eff_addr[18:16];
        DEV_2C:  ba_full = ~&eff_addr[19:16];
        DEV_2F:  ba_full = ~&eff_addr[20:16];
        default: ba_full = 1;
    endcase

    if( ba_full ) begin
        ba_addr[15:13] = 0;
    end else begin
        casez(eff_addr[15:13])
            3'b0??: begin // 7_0000 ~ 7_7FFF
                ba_addr[14:13]=0;
                ba_size = BA_32K;
            end
            3'b100: begin // 7_8000 ~ 7_9FFF
                ba_size = BA_8K;
            end
            3'b101: begin // 7_A000 ~ 7_BFFF
                ba_size = BA_8K;
            end
            3'b11?: begin // 7_C000 ~ 7_FFFF
                ba_addr[13]=0;
                ba_size = BA_16K;
            end
        endcase
    end
end

always @(posedge clk, posedge rst ) begin
    if( rst ) begin
        cart_addr <= 0;
        cart_we   <= 0;
        cart_cs   <= 0;
        cart_din  <= 0;
        erase_bsy <= 0;
        prog_bsy  <= 0;
        erase_st  <= 0;
    end else begin
        if( !erase_bsy && !prog_bsy && !rd_bsy ) begin
            if( erase_start ) begin
                erase_bsy <= 1;
                cart_addr <= prog_addr;
                cart_din  <= 8'hff;
                cart_we   <= 1;
                erase_st  <= 0;
            end
            if( prog_start ) begin
                prog_bsy <= 1;
                prog_st  <= 0;
            end
            if( cpu_cs && !cpu_we ) begin // will cpu_we go high after cpu_cs? It could cause an unnecessary read
                cart_addr <= eff_addr;
                { cart_we, cart_cs } <= 1;
                rd_bsy <= 1;
            end
        end else begin
            if( erase_bsy ) begin
                erase_st <= erase_st + 1'd1;
                case( erase_st )
                    0: cart_cs <= 1;
                    2: if( !cart_ok ) erase_st <= 2; else cart_cs <= 0;
                    3: if( last ) { cart_we, erase_bsy } <= 0; else cart_addr[15:0] <= cart_addr[15:0] + 16'd1;
                endcase
            end
            if( prog_bsy ) begin
                prog_st <= prog_st + 1'd1;
                case( prog_st )
                    0: { cart_addr, cart_we, cart_cs } <= { prog_addr, 2'b01 };
                    2: if( !cart_ok ) prog_st <= 2; else begin cart_cs <= 0; cart_din <= cart_data & prog_data; end
                    3: { cart_we, cart_cs } <= 2'b11;
                    4: if( !cart_ok ) prog_st <= 4; else { prog_bsy, cart_we, cart_cs } <= 0;
                endcase
            end
            if( rd_bsy && cart_ok ) { rd_bsy, cart_cs } <= 0;
        end
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st          <= READ;
        cmd         <= 0;
        id          <= 0;
        erase_start <= 0;
        prog_start  <= 0;
        prog_data   <= 0;
        prog_addr   <= 0;
        cswe_l      <= 0;
    end else begin
        erase_start <= 0;
        prog_start  <= 0;
        cswe_l      <= cpu_cswe;

        if( we_edge ) begin
            case( st )
                READ: begin
                    st  <= cpu_addr[15:0]=='h5555 && cpu_dout=='haa ? PROG1 : READ;
                    id  <= 0;
                    cmd <= 0;
                end
                PROG1: begin
                    st <= cpu_addr[15:0]=='h2aaa && cpu_dout=='h55 ? PROG2 : READ;
                end
                PROG2: begin
                    if( cpu_dout=='h30 ) begin
                        if( cpu_dout=='h80 ) begin
                            prog_ba    <= ba_addr;
                            prog_size  <= ba_size;
                            erase_start <= 1;   // auto erase
                        end
                    end else if( cpu_addr[15:0]=='h5555 ) begin
                        case( cpu_dout )
                            8'h80: begin
                                cmd <= 8'h80;
                                st  <= CMD;
                            end
                            8'h90: begin // ID read
                                st <= READ;
                                id <= 1;
                            end
                            8'h9a: begin
                                if( cmd==8'h9A ) begin
                                    st <= PROTECT; // ignored
                                end else begin
                                    cmd <= 8'h9a;
                                    st <= CMD;
                                end
                            end
                            8'ha0: begin
                                st <= AUTOPROG;
                            end
                            default: begin
                                st <= READ;
                            end
                        endcase
                    end
                end
                CMD: begin
                    st <= cpu_addr[15:0]=='h5555 && cpu_dout=='haa ? PROG1 : READ;
                end
                AUTOPROG: begin
                    // read data first and apply a logic and to only program
                    // bits set to zero
                    prog_addr  <= eff_addr;
                    prog_data  <= cpu_dout;
                    prog_start <= 1;
                    st <= READ;
                end
                default: begin
                    st <= READ;
                    id <= 0;
                end
            endcase
        end
    end
end

endmodule