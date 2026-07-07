module jttoki_cabal_adpcm(
    input             rst,
    input             clk,
    input             cen,

    input       [7:0] cpu_dout,
    input             addr_we,
    input             addr_hi,
    input             ctl_we,

    output     [15:0] rom_addr,
    output            rom_cs,
    input       [7:0] rom_data,
    input             rom_ok,

    output signed [11:0] snd
);

reg  [15:0] current, end_addr;
reg  [ 3:0] pcm_nibble;
reg         high_nibble, playing;
wire [ 7:0] dec_data;
wire        sample, msm_rst;

assign rom_addr = current;
assign rom_cs   = playing;
assign dec_data = { rom_data[7], rom_data[5], rom_data[3], rom_data[1],
                    rom_data[6], rom_data[4], rom_data[2], rom_data[0] };
assign msm_rst  = rst | ~playing;

always @(posedge clk) begin
    if (rst) begin
        current     <= 16'd0;
        end_addr    <= 16'd0;
        pcm_nibble  <= 4'd0;
        high_nibble <= 1'b1;
        playing     <= 1'b0;
    end else begin
        if (addr_we) begin
            if (addr_hi) begin
                end_addr <= {cpu_dout, 8'd0};
            end else begin
                current     <= {cpu_dout, 8'd0};
                high_nibble <= 1'b1;
            end
        end

        if (ctl_we) begin
            case (cpu_dout)
                8'd0: playing <= 1'b0;
                8'd1: playing <= 1'b1;
                default:;
            endcase
        end

        if (playing && sample && rom_ok) begin
            pcm_nibble  <= high_nibble ? dec_data[7:4] : dec_data[3:0];
            high_nibble <= ~high_nibble;
            if (!high_nibble) begin
                current <= current + 16'd1;
                if (current + 16'd1 >= end_addr)
                    playing <= 1'b0;
            end
        end
    end
end

jt5205 #(.INTERPOL(0)) u_msm5205(
    .rst    ( msm_rst        ),
    .clk    ( clk            ),
    .cen    ( cen            ),
    .sel    ( 2'b10          ),
    .din    ( pcm_nibble     ),
    .sound  ( snd            ),
    .irq    ( sample         ),
    .sample (                ),
    .vclk_o (                )
);

endmodule
