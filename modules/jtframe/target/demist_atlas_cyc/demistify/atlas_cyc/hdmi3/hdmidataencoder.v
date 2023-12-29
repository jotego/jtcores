//---------------------------------------------------------------------------
//-- (c) 2016 Alexey Spirkov
//-- I am happy for anyone to use this for non-commercial use.
//-- If my verilog/vhdl/c files are used commercially or otherwise sold,
//-- please contact me for explicit permission at me _at_ alsp.net.
//-- This applies for source and binary form and derived works.
//
//-- Audio and infoframe packet generation mechanizms based on Charlie Cole 2015 
//-- design of HDMI output for Neo Geo MVS

module hdmidataencoder 
#(parameter FREQ, FS, CTS, N) 
(
	input		i_pixclk,
	input		i_hSync,
	input		i_vSync,
	input		i_blank,
	input [15:0] 	i_audioL,
	input [15:0] 	i_audioR,	
	output [3:0] 	o_d0,
	output [3:0] 	o_d1,
	output [3:0] 	o_d2,
	output		o_data
);

`define AUDIO_TIMER_ADDITION	FS/1000
`define AUDIO_TIMER_LIMIT	FREQ/1000

localparam [191:0] channelStatus = (FS == 48000)?192'hc202004004:(FS == 44100)?192'hc200004004:192'hc203004004;
localparam [55:0] audioRegenPacket = {N[7:0], N[15:8], 8'h00, CTS[7:0], CTS[15:8], 16'h0000};

reg [23:0] audioPacketHeader;
reg [55:0] audioSubPacket[3:0];
reg [7:0] channelStatusIdx;
reg [16:0] audioTimer;
reg [16:0] ctsTimer;
reg [1:0] samplesHead;
reg [3:0] dataChannel0;
reg [3:0] dataChannel1;
reg [3:0] dataChannel2;
reg [23:0] packetHeader;
reg [55:0] subpacket[3:0];
reg [7:0] bchHdr;
reg [7:0] bchCode [3:0];
reg [4:0] dataOffset;
reg tercData;
reg [25:0] audioRAvgSum;
reg [25:0] audioLAvgSum;
reg [15:0] audioRAvg;
reg [15:0] audioLAvg;
reg [10:0] audioAvgCnt;
reg [15:0] counterX;
reg firstHSyncChange;
reg oddLine;
reg prevHSync;
reg prevBlank;
reg allowGeneration;

initial
begin
	audioPacketHeader=0;
	audioSubPacket[0]=0;
	audioSubPacket[1]=0;
	audioSubPacket[2]=0;
	audioSubPacket[3]=0;
	channelStatusIdx=0;
	audioTimer=0;
	samplesHead=0;
	ctsTimer = 0;
	dataChannel0=0;
	dataChannel1=0;
	dataChannel2=0;
	packetHeader=0;
	subpacket[0]=0;
	subpacket[1]=0;
	subpacket[2]=0;
	subpacket[3]=0;
	bchHdr=0;
	bchCode[0]=0;
	bchCode[1]=0;
	bchCode[2]=0;
	bchCode[3]=0;
	dataOffset=0;
	tercData=0;
	oddLine=0;
	counterX=0;
	prevHSync = 0;
	prevBlank = 0;
	firstHSyncChange = 0;
	allowGeneration = 0;
	audioRAvg = 0;
	audioLAvg = 0;
	audioRAvgSum = 0;
	audioLAvgSum = 0;
	audioAvgCnt = 1;
end

function [7:0] ECCcode;	// Cycles the error code generator
	input [7:0] code;
	input bita;
	input passthroughData;
	begin
		ECCcode = (code<<1) ^ (((code[7]^bita) && passthroughData)?(1+(1<<6)+(1<<7)):0);
	end
endfunction

task ECCu;
	output outbit;
	inout [7:0] code;
	input bita;
	input passthroughData;
	begin
		outbit <= passthroughData?bita:code[7];
		code <= ECCcode(code, bita, passthroughData);
	end
endtask

task ECC2u;
	output outbita;
	output outbitb;
	inout [7:0] code;
	input bita;
	input bitb;
	input passthroughData;
	begin
		outbita <= passthroughData?bita:code[7];
		outbitb <= passthroughData?bitb:(code[6]^(((code[7]^bita) && passthroughData)?1'b1:1'b0));
		code <= ECCcode(ECCcode(code, bita, passthroughData), bitb, passthroughData);
	end
endtask

task SendPacket;
	inout [32:0] pckHeader;
	inout [55:0] pckData0;
	inout [55:0] pckData1;
	inout [55:0] pckData2;
	inout [55:0] pckData3;
	input firstPacket;
begin
	dataChannel0[0]=i_hSync;
	dataChannel0[1]=i_vSync;
	dataChannel0[3]=(!firstPacket || dataOffset)?1'b1:1'b0;
	ECCu(dataChannel0[2], bchHdr, pckHeader[0], dataOffset<24?1'b1:1'b0);
	ECC2u(dataChannel1[0], dataChannel2[0], bchCode[0], pckData0[0], pckData0[1], dataOffset<28?1'b1:1'b0);
	ECC2u(dataChannel1[1], dataChannel2[1], bchCode[1], pckData1[0], pckData1[1], dataOffset<28?1'b1:1'b0);
	ECC2u(dataChannel1[2], dataChannel2[2], bchCode[2], pckData2[0], pckData2[1], dataOffset<28?1'b1:1'b0);
	ECC2u(dataChannel1[3], dataChannel2[3], bchCode[3], pckData3[0], pckData3[1], dataOffset<28?1'b1:1'b0);
	pckHeader<=pckHeader[23:1];
	pckData0<=pckData0[55:2];
	pckData1<=pckData1[55:2];
	pckData2<=pckData2[55:2];
	pckData3<=pckData3[55:2];
	dataOffset<=dataOffset+5'b1;
end
endtask

task InfoGen;
	inout [16:0] _timer;
begin
	if (_timer >= CTS) begin
		packetHeader<=24'h000001;	// audio clock regeneration packet
		subpacket[0]<=audioRegenPacket;
		subpacket[1]<=audioRegenPacket;
		subpacket[2]<=audioRegenPacket;
		subpacket[3]<=audioRegenPacket;
		_timer <= _timer - CTS + 1;
	end else begin
		if (!oddLine) begin
			packetHeader<=24'h0D0282;	// infoframe AVI packet	
			// Byte0: Checksum (256-(S%256))%256
			// Byte1: 10 = 0(Y1:Y0=0 RGB)(A0=1 active format valid)(B1:B0=00 No bar info)(S1:S0=00 No scan info)
			// Byte2: 19 = (C1:C0=0 No colorimetry)(M1:M0=1 4:3)(R3:R0=9 4:3 center)
			// Byte3: 00 = 0(SC1:SC0=0 No scaling)
			// Byte4: 00 = 0(VIC6:VIC0=0 custom resolution)
			// Byte5: 00 = 0(PR5:PR0=0 No repeation)
			subpacket[0]<=56'h00000000191046;
			subpacket[1]<=56'h00000000000000;
		end else begin
			packetHeader<=24'h0A0184;	// infoframe audio packet
			// Byte0: Checksum (256-(S%256))%256
			// Byte1: 11 = (CT3:0=1 PCM)0(CC2:0=1 2ch)
			// Byte2: 00 = 000(SF2:0=0 As stream)(SS1:0=0 As stream)
			// Byte3: 00 = LPCM doesn't use this
			// Byte4-5: 00 Multichannel only (>2ch)
			subpacket[0]<=56'h00000000001160;
			subpacket[1]<=56'h00000000000000;
		end
		subpacket[2]<=56'h00000000000000;
		subpacket[3]<=56'h00000000000000;
	end			
end
endtask

task AproximateAudio;
begin
	audioLAvgSum <= audioLAvgSum + i_audioL;
	audioRAvgSum <= audioRAvgSum + i_audioR;
	audioLAvg <= audioLAvgSum/audioAvgCnt;
	audioRAvg <= audioRAvgSum/audioAvgCnt;
	audioAvgCnt <= audioAvgCnt + 1;
end
endtask

task AudioGen;
begin
	// Buffer up an audio sample
	// Don't add to the audio output if we're currently sending that packet though
	if (!( allowGeneration && counterX >= 32 && counterX < 64)) begin
		if (audioTimer>=`AUDIO_TIMER_LIMIT) begin
			audioTimer<=audioTimer-`AUDIO_TIMER_LIMIT+`AUDIO_TIMER_ADDITION;
			audioPacketHeader<=audioPacketHeader|24'h000002|((channelStatusIdx==0?24'h100100:24'h000100)<<samplesHead);
			audioSubPacket[samplesHead]<=((audioLAvg<<8)|(audioRAvg<<32)
								|((^audioLAvg)?56'h08000000000000:56'h0)	// parity bit for left channel
								|((^audioRAvg)?56'h80000000000000:56'h0))	// parity bit for right channel
								^(channelStatus[channelStatusIdx]?56'hCC000000000000:56'h0); // And channel status bit and adjust parity
			if (channelStatusIdx<191)
				channelStatusIdx<=channelStatusIdx+8'd1;
			else
				channelStatusIdx<=0;
			samplesHead<=samplesHead+2'd1;
			audioLAvgSum <= 0;
			audioRAvgSum <= 0;
			audioAvgCnt <= 1;
		end else begin
			audioTimer<=audioTimer+`AUDIO_TIMER_ADDITION;
			AproximateAudio();
		end
	end else begin
		audioTimer<=audioTimer+`AUDIO_TIMER_ADDITION;
		AproximateAudio();		
		samplesHead<=0;
	end
end
endtask

task SendPackets;
	inout dataEnable;
begin
	if (counterX<32) begin
		// Send first data packet (Infoframe or audio clock regen)
		dataEnable<=1;
		SendPacket(packetHeader, subpacket[0], subpacket[1], subpacket[2], subpacket[3], 1);
	end else if (counterX<64)	begin
		// Send second data packet (audio data)
		SendPacket(audioPacketHeader, audioSubPacket[0], audioSubPacket[1], audioSubPacket[2], audioSubPacket[3], 0);
	end else begin
		dataEnable<=0;
	end
end
endtask

always @(posedge i_pixclk)
begin
	
	AudioGen();

	// Send 2 packets each line
	if(allowGeneration) begin
		SendPackets(tercData);
	end else begin
		tercData<=0;
   end 	

	ctsTimer <= ctsTimer + 1;	

	if((prevBlank == 0) && (i_blank == 1)) 
		firstHSyncChange <= 1;
	
	if((prevBlank == 1) && (i_blank == 0)) 
		allowGeneration <= 0;

	if(prevHSync != i_hSync) begin
		if(firstHSyncChange) begin
			InfoGen(ctsTimer);
		   oddLine <= ! oddLine;
		   counterX  <= 0;
			allowGeneration <= 1;
		end else begin
		   counterX  <= counterX + 1;	
		end
		firstHSyncChange <= !firstHSyncChange;
	end else 
		counterX  <= counterX + 1;	
	
	prevBlank <= i_blank;
	prevHSync <= i_hSync;
end

assign o_d0 = dataChannel0;
assign o_d1 = dataChannel1;
assign o_d2 = dataChannel2;
assign o_data = tercData;

endmodule