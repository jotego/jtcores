module jtseicro_snd(
    input             rst, clk, audio_cen,
    input             bdir, bc1,
    input       [7:0] cpu_dout,
    output      [7:0] cpu_din,
    input       [7:0] debug_dip,
    output            irq_en, flip,
    output reg        mcu_reset, mcu_run,
    output      [9:0] psg,
    output            sample
);

wire [7:0] portb_out;
wire portb_oe;
reg [7:0] portb;

`ifdef NOMAIN
reg [7:0] scene_portb[0:0];
initial begin
    $readmemh("seicro_portb.hex",scene_portb);
    portb = scene_portb[0];
    $display("SEICRO_SCENE_PORTB=%02x",portb);
end
`endif

assign irq_en = portb[0];
assign flip = portb[1];

always @(posedge clk) begin
    if(rst) begin
`ifndef NOMAIN
        portb <= 0;
`endif
        mcu_reset <= 0;
        mcu_run <= 0;
    end else begin
        mcu_reset <= 0;
        if(portb_oe) begin
            portb <= portb_out;
            if(!portb[2] && portb_out[2]) begin
                mcu_reset <= 1;
                mcu_run <= 1;
            end
        end
    end
end

`ifndef NOSOUND
jt49_bus u_ay8910(
    .rst_n   ( ~rst                        ),
    .clk     ( clk                         ),
    .clk_en  ( audio_cen                   ),
    .bdir    ( bdir                        ),
    .bc1     ( bc1                         ),
    .din     ( cpu_dout                    ),
    .dout    ( cpu_din                     ),
    .sel     ( 1'b1                        ),
    .sound   ( psg                         ),
    .sample  ( sample                      ),
    .A       (                             ),
    .B       (                             ),
    .C       (                             ),
    .IOA_in  ( 8'hff                       ),
    .IOA_out (                             ),
    .IOA_oe  (                             ),
    .IOB_in  ( {debug_dip[7:4],portb[3:0]} ),
    .IOB_out ( portb_out                   ),
    .IOB_oe  ( portb_oe                    )
);
`else
assign portb_out = 0;
assign portb_oe = 0;
assign cpu_din = 8'hff;
assign psg = 0;
assign sample = 0;
`endif

endmodule
