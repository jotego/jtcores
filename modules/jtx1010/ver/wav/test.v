module test;

`include "test_tasks.vh"

wire        rst, clk;
reg  [ 3:0] ch;
reg  [ 4:0] st;
reg  [ 7:0] cfg, cfg_data;
reg  [15:0] keyon;
wire        keyoff;
reg         ch2_kon;
wire [11:0] wav_addr, env_addr;
reg  [ 7:0] wav_data, env_data;
wire signed [15:0] wav_l, wav_r;

wire zero = {ch,st}==0;

localparam [ 4:0] WAVID=5,ENVID=9;
localparam [15:0] PITCH=16'h140;
localparam [ 7:0] ENV  = 8'hC0;

initial begin
    wav_data = 0;
    env_data = 0;
    ch2_kon  = 0;
    @(negedge rst);
    repeat(20) begin
        @(posedge cen);
        assert_msg(wav_l==0,"sound output must be zero");
        assert_msg(wav_r==0,"sound output must be zero");
    end
    @(negedge cen) ch2_kon=1;
    repeat(700) begin
        @(posedge zero);
    end
    pass();
end

always @* begin // wav/env data
    // simple attack-sustain-decay
    env_data = env_addr[6:5] == 0 ? {2{env_addr[3:0]}} :
               env_addr[6:5] != 3 ? 8'hff : {2{~env_addr[3:0]}};
    wav_data = {4'd0,wav_addr[3:0]};
    if(wav_addr[11-:5]!=WAVID) wav_data = 0;
    if(env_addr[11-:5]!=ENVID) env_data = 0;
end

always @* begin // cfg regs
    cfg = 8'd6;
    cfg[0] = ch2_kon;
    case(st[2:0])
        0: cfg_data = cfg;
        1: cfg_data = {3'd0,WAVID};
        2: cfg_data = PITCH[ 7:0];
        3: cfg_data = PITCH[15:8];
        4: cfg_data = ENV;
        5: cfg_data = {3'd0,ENVID};
        default: cfg_data = 0;
    endcase
    if(ch!=2) begin
        cfg_data = 0;
        cfg = 0;
    end
end

reg [16:0] env_cnt2, wav_cnt2, wav2_l, wav2_r;

always @(posedge clk) begin
    if(cen && ch==2 && st==31) begin
        env_cnt2 <= uut.env_cnt;
        wav_cnt2 <= uut.wav_cnt;
        wav2_l   <= wav_l;
        wav2_r   <= wav_r;
    end
end

always @(posedge clk) begin
    if(rst) begin
        keyon <= 0;
    end else if(cen) begin
        if(ch==2 && st==31) keyon[2] <= ch2_kon;
    end
end

always @(posedge clk) begin
    if(rst) begin
        {ch,st} <= 9'd0;
    end else if(cen) begin
        {ch,st} <= {ch,st}+9'd1;
    end
end

jtx1010_wav uut(
    .clk        ( clk       ),
    .cen        ( cen       ),
    .ch         ( ch        ),
    .st         ( st        ),
    .cfg        ( cfg       ),
    .keyon      ( keyon     ),
    .keyoff     ( keyoff    ),
    .cfg_data   ( cfg_data  ),

    .wav_addr   ( wav_addr  ),
    .wav_data   ( wav_data  ),
    .env_addr   ( env_addr  ),
    .env_data   ( env_data  ),

    .wav_l      ( wav_l     ),
    .wav_r      ( wav_r     )
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( cen           )
);

endmodule
