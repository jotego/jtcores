module TC0140SYT(
    input             clk,
    input             ce_12m,
    input             ce_4m,

    input             RESn,

    // 68000 interface
    input       [3:0] MDin,
    output reg  [3:0] MDout,

    input             MA1,

    input             MCSn,
    input             MWRn,
    input             MRDn,

    // Z80 interface
    input             MREQn,
    input             RDn,
    input             WRn,

    input      [15:0] A,
    input       [3:0] Din,
    output reg  [3:0] Dout,

    output            ROUTn,
    output            ROMCS0n,
    output            ROMCS1n,
    output            RAMCSn,
    output            ROMA14,
    output            ROMA15,

    // YM
    output            OPXn,
    input             YAOEn, // not a real signal, on F2 boards these go to the audio ROMs
    input             YBOEn,
    input      [23:0] YAA,
    input      [23:0] YBA,
    output      [7:0] YAD,
    output      [7:0] YBD,

    // Peripheral?
    output            CSAn,
    output            CSBn,

    output      [2:0] IOA,
    output            IOC,

    // ROM interface
    output reg [26:0] sdr_address,
    input      [15:0] sdr_data,
    output reg        sdr_req,
    input             sdr_ack
);

reg [2:0] rom_bank;
reg [3:0] slave_idx, master_idx;
reg [3:0] status_reg;
reg       reset_reg;
reg nmi_enabled;
reg [15:0] slave_data;
reg [15:0] master_data;

wire bank_req = A[15:14] == 2'b01; // 0x4000-0x7fff
assign ROMCS0n = bank_req ? rom_bank[2] : A[15] | A[14]; // 0x0000 - 0x7fff
assign ROMCS1n = ~(bank_req & rom_bank[2]); // FIXME - guessing
assign RAMCSn = ~A[15] | ~A[14] | A[13];

assign ROMA14 = bank_req ? rom_bank[0] : 1'b0;
assign ROMA15 = bank_req ? rom_bank[1] : 1'b0;
assign OPXn = ~(A[15:8] == 8'he0);

assign ROUTn = RESn & ~reset_reg; // FIXME: don't think this is correct, software reset out

wire slave_access = (A[15:8] == 8'he2) & ~MREQn;
wire master_access = ~MCSn;
reg prev_slave_access;
reg prev_master_access;

always_ff @(posedge clk) begin
    prev_slave_access <= slave_access;
    prev_master_access <= master_access;
    if (~RESn) begin
        rom_bank <= 3'b000;
        status_reg <= 0;
    end else begin
        if (slave_access & ~prev_slave_access) begin
            if (~WRn) begin
                if (A[0]) begin
                    case(slave_idx)
                        0: begin
                            master_data[3:0] <= Din;
                            slave_idx <= slave_idx + 1;
                        end
                        1: begin
                            master_data[7:4] <= Din;
                            slave_idx <= slave_idx + 1;
                            status_reg[2] <= 1;
                        end
                        2: begin
                            master_data[11:8] <= Din;
                            slave_idx <= slave_idx + 1;
                        end
                        3: begin
                            master_data[15:12] <= Din;
                            slave_idx <= slave_idx + 1;
                            status_reg[3] <= 1;
                        end
                        5: begin
                            nmi_enabled <= 0;
                        end
                        6: begin
                            nmi_enabled <= 1;
                        end

                        default: begin
                        end
                    endcase
                end else begin
                    slave_idx <= Din;
                end
            end

            if (~RDn & A[0]) begin
                case(slave_idx)
                    0: begin
                        Dout <= slave_data[3:0];
                        slave_idx <= slave_idx + 1;
                    end
                    1: begin
                        Dout <= slave_data[7:4];
                        slave_idx <= slave_idx + 1;
                        status_reg[0] <= 0;
                    end
                    2: begin
                        Dout <= slave_data[11:8];
                        slave_idx <= slave_idx + 1;
                    end
                    3: begin
                        Dout <= slave_data[15:12];
                        slave_idx <= slave_idx + 1;
                        status_reg[1] <= 0;
                    end
                    4: begin
                        Dout <= status_reg;
                    end
                    default: begin
                    end
                endcase
            end
        end

        if (A[15:8] == 8'hf2 && ~WRn && ~MREQn) begin
            rom_bank <= Din[2:0];
        end


        if (master_access & ~prev_master_access) begin
            if (~MWRn & ~MA1) begin
                master_idx <= MDin;
            end

            if (MA1) begin
                if (~MWRn) begin
                    case(master_idx)
                        0: begin
                            slave_data[3:0] <= MDin;
                            master_idx <= master_idx + 1;
                        end
                        1: begin
                            slave_data[7:4] <= MDin;
                            master_idx <= master_idx + 1;
                            status_reg[0] <= 1;
                        end
                        2: begin
                            slave_data[11:8] <= MDin;
                            master_idx <= master_idx + 1;
                        end
                        3: begin
                            slave_data[15:12] <= MDin;
                            master_idx <= master_idx + 1;
                            status_reg[1] <= 1;
                        end
                        4: begin
                            reset_reg <= MDin[0];
                        end

                        default: begin
                        end
                    endcase
                end

                if (~MRDn) begin
                    case(master_idx)
                        0: begin
                            MDout <= master_data[3:0];
                            master_idx <= master_idx + 1;
                        end
                        1: begin
                            MDout <= master_data[7:4];
                            master_idx <= master_idx + 1;
                            status_reg[2] <= 0;
                        end
                        2: begin
                            MDout <= master_data[11:8];
                            master_idx <= master_idx + 1;
                        end
                        3: begin
                            MDout <= master_data[15:12];
                            master_idx <= master_idx + 1;
                            status_reg[3] <= 0;
                        end
                        4: begin
                            MDout <= status_reg;
                        end
                        default: begin
                        end
                    endcase
                end
            end
        end
    end
end

// ROM interface

reg [15:0] cha_data, chb_data;
reg [23:0] cha_addr, chb_addr;
reg cha_request_pending = 0;
reg chb_request_pending = 0;
reg cha_oe_n, chb_oe_n;
reg [1:0] request_active = 0;

wire cha_oe_edge = ~YAOEn & cha_oe_n;
wire chb_oe_edge = ~YBOEn & chb_oe_n;

assign YAD = cha_addr[0] ? cha_data[15:8] : cha_data[7:0];
assign YBD = chb_addr[0] ? chb_data[15:8] : chb_data[7:0];

always_ff @(posedge clk) begin
    cha_oe_n <= YAOEn;
    chb_oe_n <= YBOEn;

    if (cha_oe_edge) begin
        cha_addr <= YAA;
        if (cha_addr[23:1] != YAA[23:1]) begin
            cha_request_pending <= 1;
        end
    end

    if (chb_oe_edge) begin
        chb_addr <= YBA;
        if (chb_addr[23:1] != YBA[23:1]) begin
            chb_request_pending <= 1;
        end
    end


    if (sdr_req == sdr_ack) begin
        if (request_active == 2) begin
            chb_data <= sdr_data;
            request_active <= 0;
        end else if (request_active == 1) begin
            cha_data <= sdr_data;
            request_active <= 0;
        end else begin
            if (cha_request_pending) begin
                cha_request_pending <= 0;
                request_active <= 1;
                sdr_address <= ADPCMA_ROM_SDR_BASE[26:0] + { 3'd0, cha_addr[23:1], 1'b0 };
                sdr_req <= ~sdr_req;
            end else if (chb_request_pending) begin
                chb_request_pending <= 0;
                request_active <= 2;
                sdr_address <= ADPCMB_ROM_SDR_BASE[26:0] + { 3'd0, chb_addr[23:1], 1'b0 };
                sdr_req <= ~sdr_req;
            end
        end
    end
end

endmodule
