module IKA87AD_flag (
    input   wire            i_MRST_n,
    input   wire            i_EMUCLK,
    input   wire            i_SETTICK,
    input   wire            i_RSTTICK,

    input   wire            i_IRQ,
    input   wire            i_IS_ENABLED,
    input   wire    [4:0]   i_IRQ_CODE_UNIQUE,
    input   wire    [4:0]   i_IRQ_CODE_TO_BE_ACKD,
    input   wire            i_MULTI_IRQ_ENABLED,
    input   wire            i_MANUAL_ACK,
    input   wire            i_AUTO_ACK,

    output  reg             o_IFLAGREG
);

always @(posedge i_EMUCLK) begin
    if(!i_MRST_n) o_IFLAGREG <= 1'b0;
    else begin 
        if(i_RSTTICK) begin
            if(o_IFLAGREG) begin
                if(i_MANUAL_ACK) begin //manual ack
                    if(i_IRQ_CODE_TO_BE_ACKD == i_IRQ_CODE_UNIQUE) o_IFLAGREG <= 1'b0; //manual ack
                end
                else begin //auto ack
                    if(i_IS_ENABLED && !i_MULTI_IRQ_ENABLED) begin
                        if(i_AUTO_ACK) o_IFLAGREG <= 1'b0; //auto ack
                    end
                end
            end
        end
        else begin
            if(i_SETTICK) if(i_IRQ) o_IFLAGREG <= 1'b1;
        end
    end
end

endmodule

module IKA87AD_irqsampler (
    input   wire            i_MRST_n,
    input   wire            i_EMUCLK,
    input   wire            i_CNTTICK,

    input   wire            i_IS,
    output  reg             o_DET
);

reg     [5:0]   sample_tick_cntr;
always @(posedge i_EMUCLK) begin
    if(!i_MRST_n) sample_tick_cntr <= 6'd0;
    else begin if(i_CNTTICK) begin
        sample_tick_cntr <= sample_tick_cntr == 6'd35 ? 6'd0 : sample_tick_cntr + 6'd1;
    end end
end

reg     [2:0]   is_sr;
always @(posedge i_EMUCLK) begin
    if(!i_MRST_n) is_sr <= 3'b000;
    else begin if(sample_tick_cntr == 6'd35 && i_CNTTICK) begin
        is_sr[0] <= i_IS;
        is_sr[2:1] <= is_sr[1:0];
    end end
end

reg             det, det_z;
always @(posedge i_EMUCLK) begin
    if(!i_MRST_n) begin
        det <= 1'b0; det_z <= 1'b0; o_DET <= 1'b0;
    end
    else begin if(i_CNTTICK) begin
        det <= is_sr == 3'b111;
        det_z <= det;

        if({det, det_z} == 2'b10) o_DET <= 1'b1;
        else o_DET <= 1'b0;
    end end
end

endmodule

module IKA87AD_nedet (
    input   wire            i_MRST_n,
    input   wire            i_EMUCLK,
    input   wire            i_TICK,
    input   wire            i_IN,
    output  reg             o_NEDET
);

reg     [1:0]   sampler;
always @(posedge i_EMUCLK) begin
    if(!i_MRST_n) begin 
        sampler <= 2'b00;
        o_NEDET <= 1'b0;
    end
    else begin if(i_TICK) begin
        sampler[0] <= i_IN;
        sampler[1] <= sampler[0];

        if(sampler == 2'b10 && i_IN == 1'b0) o_NEDET <= 1'b1;
        else o_NEDET <= 1'b0;
    end end
end

endmodule