///////////////////////////////////////////////////////////////////////////
/*
MIT License

Copyright (c) 2022 Antonio Sánchez (@TheSonders)
THE EXPERIMENT GROUP (@agnuca @Nabateo @subcriticalia)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

 ULPI<->PS2
Convertidor de teclado USB a teclado PS2.
Por el momento sólo admite teclados low speed.
Comunicación con el USB a través del chip TUSB1210 usando protocolo ULPI.
Genera las señales PS/2 a 15000 baudios que simulan las teclas pulsadas/soltadas.
 
 USO DEL MÓDULO:
 -Señal de entrada de reloj 60MHz (generada por el TUSB)
 -Interfaz ULPI.
 -Señales de salida PS/2 (CLK y DTA)
 -Señales de entrada del estado deseado para los 3 leds del teclado USB
 -ATENCIÓN: Para usar en la Arrow DECA es necesario desfasar el reloj
	de entrada -30º (menos treinta grados) con respecto al reloj del pin H11
 
 Antonio Sánchez (@TheSonders)
 Referencias:
 -Ben Eater Youtube Video:
     https://www.youtube.com/watch?v=wdgULBpRoXk
 -USB Specification Revision 2.0
 -ULPI Specification Revision 1.1
 -TUSB1210 Datasheet
 -https://usb.org/sites/default/files/hut1_22.pdf
 -https://crccalc.com/
 -https://www.perytech.com/USB-Enumeration.htm
*/
///////////////////////////////////////////////////////////////////////////

`define DIRAsInput      1
`define DIRAsOutput     0

// RECEPTION STM
`define STM_UNCONNECTED 0
`define STM_IDLE        1
`define STM_PID         2
`define STM_DATAFIELD   3

// TUSB1210 REGISTER MAP
`define VENDOR_ID_LO			8'h00
`define VENDOR_ID_HI			8'h01
`define PRODUCT_ID_LO			8'h02
`define PRODUCT_ID_HI			8'h03
`define FUNC_CTRL   			8'h04
`define FUNC_CTRL_SET   		8'h05
`define FUNC_CTRL_CLR   		8'h06
`define IFC_CTRL   				8'h07
`define IFC_CTRL_SET   			8'h08
`define IFC_CTRL_CLR   			8'h09
`define OTG_CTRL   				8'h0A
`define OTG_CTRL_SET   			8'h0B
`define OTG_CTRL_CLR   			8'h0C
`define USB_INT_EN_RISE   		8'h0D
`define USB_INT_EN_RISE_SET		8'h0E
`define USB_INT_EN_RISE_CLR		8'h0F
`define USB_INT_EN_FALL   		8'h10
`define USB_INT_EN_FALL_SET 	8'h11
`define USB_INT_EN_FALL_CLR 	8'h12
`define USB_INT_STS   			8'h13
`define USB_INT_LATCH   		8'h14
//`define DEBUG   				8'h15
`define SCRATCH_REG   			8'h16
`define SCRATCH_REG_SET   		8'h17
`define SCRATCH_REG_CLR   		8'h18
`define ACCESS_EXT_REG_SET		8'h2F
`define VENDOR_SPECIFIC1   		8'h3D
`define VENDOR_SPECIFIC2   		8'h80
`define VENDOR_SPECIFIC1_STS	8'h83
`define VENDOR_SPECIFIC1_LATCH  8'h84
`define VENDOR_SPECIFIC3   		8'h85
`define VENDOR_SPECIFIC3_SET   	8'h86
`define VENDOR_SPECIFIC3_CLR   	8'h87

// ULPI COMMANDS
`define TX_NOOP         8'h00
`define TX_WR_CTRL      8'h84
`define TX_WR_INT_RISE  8'h8D
`define TX_WR_INT_FALL  8'h90
`define TX_WR_OTG       8'h8A

// ULPI CONSTANTS
`define CTRL_RESET      8'h66
`define CTRL_OPMODE     8'h46
`define CTRL_CHIRP      8'h40
`define DIS_INTERRUPTS  8'h00
`define ENA_PULLDOWNS   8'h66 //Pulldown and CPEN enabled


module ULPI_PS2
    (input wire clk,            //60MHz
    //Top Core
    input wire LedNum,			//Aún en depuración
    input wire LedCaps,			//conectar estas 3 señales
    input wire LedScroll,		//a lógica 0
    output reg PS2data=0,
	output reg PS2clock=0,
    //TUSB1210
    input wire FAULT_n,     //Overcurrent
    inout wire [7:0]DATA,
    input wire NXT,
    input wire DIR,
    output reg STP=0,
    output wire RESET_n,    //Fixed to High
    output wire CS         //Fixed to High
	 );
	 
`define CLK_MULT        60000   //(CLK / 1000)
`define PS2_PRES        1999    //(CLK / 15000 baud / 2)-1

assign DATA[7:0]=(DIR==`DIRAsInput)?8'hZ:TX_Shift[7:0];
assign RESET_n=1'b1;
assign CS=1'b1;

`define PID_Out         8'hE1
`define PID_In          8'h69
`define PID_Setup       8'h2D
`define PID_Data0       8'hC3
`define PID_Data1       8'h4B
`define PID_ACK         8'hD2
`define PID_NAK         8'h5A
`define PID_SOF         8'hA5

`define TX_Out         8'h41
`define TX_In          8'h49
`define TX_Setup       8'h4D
`define TX_Data0       8'h43
`define TX_Data1       8'h4B
`define TX_ACK         8'h42
`define TX_NAK         8'h4A
`define TX_SOF         8'h45

////////////////////////////////////////////////////////////
//                      TOP LAYER                         //
////////////////////////////////////////////////////////////
// Máquina de estados general.
// -Detectar la presencia de un device y determinar su velocidad.
// -Reiniciar el Device
// -Setup de la dirección del device
// -Forzar el device a modo BOOT
// -Solicitar (paquete IN) periódicamente el estado de las teclas
// -Un device en modo BOOT devuelve NAK si dicho estado no ha cambiado
// 
////////////////////////////////////////////////////////////
// Estados del dispositivo:
// Detached->Powered->Default->Address->Configured
//          Attach   Reset   SetAddress  SetConfig
// En cualquier momento, por inactividad del bus (3ms) entra en Suspended
// Para evitar el Suspended mandar KA (Keep Alive)

`define TL_PowerON             5'd0              
`define TL_ULPI_IntRise        5'd1
`define TL_ULPI_IntFall        5'd2
`define TL_ULPI_EnaPulls       5'd3
`define TL_Unconnected         5'd4
`define TL_Send_Reset          5'd5
`define TL_ULPI_SetMode        5'd6
`define TL_SetConfig           5'd7
`define TL_SendSETUPConfig     5'd8
`define TL_KeepAlive           5'd9
`define TL_SendSETUPAddress    5'd10
`define TL_SetAddress          5'd11
`define TL_WaitResponse        5'd12
`define TL_IN00                5'd13
`define TL_SEND_ACK00          5'd14
`define TL_IN20_CONFIG         5'd15
`define TL_SEND_ACK20_CONFIG   5'd16
`define TL_IN21                5'd17
`define TL_VerifyData          5'd18
`define TL_SendSETUPProtocol   5'd19
`define TL_SetProtocol         5'd20
`define TL_IN20_PROTOCOL       5'd21
`define TL_SEND_ACK20_PROTOCOL 5'd22
`define TL_SEND_DATA0_REPORT   5'd23
`define TL_SEND_OUT20_REPORT   5'd24
`define TL_SEND_DATA1_REPORT   5'd25
`define TL_IN20_REPORT         5'd26
`define TL_IN_DATA1_REPORT     5'd27
`define TL_SEND_ACK_DATA1      5'd28
`define TL_Wait                5'd29
`define TL_DelayRetry          5'd30
`define TL_KeepAlive2          5'd31

`define LEDS    {LedScroll,LedCaps,LedNum}

//Suprimimos los CRC
//Usamos device address y endpoint fijos para
//emplear paquetes precalculados
reg [4:0]TL_STM=`TL_PowerON;
reg [4:0]TL_ResponseOK=`TL_PowerON;
reg [4:0]TL_Fail=`TL_PowerON;
reg [95:0]TX_Shift=0;
reg [95:0]  Packet_IN20 ={5'h15,4'h0,7'h02,`TX_In};
reg [95:0]  Packet_IN21 ={5'h03,4'h1,7'h02,`TX_In};
reg [95:0]  Packet_IN00 ={5'h02,4'h0,7'h00,`TX_In};
reg [95:0]Packet_SETUP  ={5'h02,4'h0,7'h00,`TX_Setup};
reg [95:0]Packet_SETUP2 ={5'h15,4'h0,7'h02,`TX_Setup};
reg [95:0]Packet_SET_ADDRESS ={16'h16EB,64'h0000000000020500,`TX_Data0};
reg [95:0]Packet_SET_CONFIG  ={16'h2527,64'h0000000000010900,`TX_Data0};
reg [95:0]Packet_SET_PROTOCOL={16'hE0C6,64'h0000000000000B21,`TX_Data0};
reg [95:0]Packet_SET_REPORT  ={16'h709D,64'h0001000002000921,`TX_Data0};
reg [95:0]Packet_OUT20       ={5'h15,4'h0,7'h02,`TX_Out};
reg [95:0]Packet_LEDS_000    ={16'hBF40,8'h00,`TX_Data1};
reg [95:0]Packet_LEDS_001    ={16'h7F81,8'h01,`TX_Data1};
reg [95:0]Packet_LEDS_010    ={16'h7EC1,8'h02,`TX_Data1};
reg [95:0]Packet_LEDS_011    ={16'hBE00,8'h03,`TX_Data1};
reg [95:0]Packet_LEDS_100    ={16'h7C41,8'h04,`TX_Data1};
reg [95:0]Packet_LEDS_101    ={16'hBC80,8'h05,`TX_Data1};
reg [95:0]Packet_LEDS_110    ={16'hBDC0,8'h06,`TX_Data1};
reg [95:0]Packet_LEDS_111    ={16'h7D01,8'h07,`TX_Data1};
reg [95:0]Packet_ACK = {`TX_ACK};
reg [95:0]Packet_SOF = {5'h08,11'd263,`TX_SOF};

reg [95:0]ULPI_Reset    ={`CTRL_RESET,`TX_WR_CTRL};
reg [95:0]ULPI_OpMode   ={`CTRL_OPMODE,`TX_WR_CTRL};
reg [95:0]ULPI_IntRise  ={`DIS_INTERRUPTS,`TX_WR_INT_RISE};
reg [95:0]ULPI_IntFall  ={`DIS_INTERRUPTS,`TX_WR_INT_FALL};
reg [95:0]ULPI_EnaPulls ={`ENA_PULLDOWNS,`TX_WR_OTG};
reg [95:0]ULPI_NonDrivin={`CTRL_CHIRP,`TX_WR_CTRL};

reg [8:0] TXLeftBits=0;
reg [3:0]TimeOut=0;
reg [2:0]LatchLEDS=0;
reg [2:0]Stuff_Count=0;

////////////////////////////////////////////////////////////
//                    PS2 CONVERSION                      //
//////////////////////////////////////////////////////////// 
`define LEFT_CTRL   0
`define LEFT_SHIFT  1
`define LEFT_ALT    2
`define LEFT_GUI    3
`define RIGHT_CTRL  4
`define RIGHT_SHIFT 5
`define RIGHT_ALT   6
`define RIGHT_GUI   7
`define Release_Key 8'hF0
`define StopBit     1'b1
`define StartBit    1'b0
`define NextChar    PS2_signal[8:1]

reg PS2Busy=0;
reg [7:0]Cpy_Rmodifiers=8'h00;
reg [32:0]PS2_signal=0;
reg [6:0]PS2TX_STM=0;
reg [5:0]PS2_STM=0;
reg PS2_buffer_busy=0;
reg ParityBit=0;
reg [$clog2(`PS2_PRES)-1:0]PS2_Prescaler=0;
reg [7:0]Rmodifiers=0;
reg [47:0]RollOver=0;
reg [47:0]Cpy_RollOver=0;
reg AddKey=0;
reg SendKey=0;
reg prev_DIR=0; 


always @(posedge clk)begin
	if (StartTimer==1) StartTimer<=0;
	if (TXLeftBits==0 && (TimerEnd==1 || NewInPacket==1))begin
    case (TL_STM)
        `TL_PowerON:begin
			PS2clock<=1;
            PS2data<=1;
				SetTimer(1);
				SendPacket(ULPI_Reset,16);
				TL_STM<=`TL_ULPI_EnaPulls;
        end
        `TL_ULPI_EnaPulls:begin
			SendPacket(ULPI_EnaPulls,16);
           TL_STM<=`TL_Unconnected; 
        end
        `TL_Unconnected:begin ListenIfConnected:
            TimeOut<=0;
            LatchLEDS<=0;
            if (INDECODE_STM==`STM_IDLE)begin
                TL_STM<=`TL_Send_Reset;
            end        
        end
        `TL_Send_Reset:begin SendRESETToDevice:
            SendReset;
            TL_STM<=`TL_ULPI_SetMode;
            SetTimer(20);
        end
        `TL_ULPI_SetMode:begin
            SetTimer(1);
            SendPacket(ULPI_OpMode,16);
            TL_STM<=`TL_SendSETUPAddress;
        end
        `TL_Wait: begin
            SetTimer(1);
            TL_STM<=`TL_WaitResponse;
        end
        `TL_DelayRetry:begin
            TL_STM<=TL_Fail;
        end
        `TL_WaitResponse: begin
            if (TimerEnd==1 || 
                (TL_Fail!=`TL_IN21 && RECEIVED_PID !=`PID_ACK && RECEIVED_PID!=`PID_Data1))begin
                if (TimeOut==15) begin
                    TL_STM<=`TL_PowerON;
                end
                else begin
                    TimeOut<=TimeOut+4'd1;
						  SendPacket(Packet_SOF,24);
                    SetTimer(1);
                    TL_STM<=`TL_DelayRetry;
                end
            end
            else begin
                TimeOut<=0;
                SetTimer(0);
                TL_STM<=TL_ResponseOK;
            end
        end
        `TL_SendSETUPAddress:begin 
            SendPacket(Packet_SETUP,24);
            TL_STM<=`TL_SetAddress;
        end
        `TL_SetAddress:begin 
            SendPacket(Packet_SET_ADDRESS,88);
            Wait_Response(`TL_SendSETUPAddress,`TL_IN00);
        end
        `TL_SEND_OUT20_REPORT: begin
            SetTimer(0);
            SendPacket(Packet_OUT20,24);
            TL_STM<=`TL_SEND_DATA1_REPORT;
        end
        `TL_SEND_DATA1_REPORT:begin
            Wait_Response(`TL_SEND_OUT20_REPORT,`TL_IN20_REPORT);
            case (`LEDS)
                0: SendPacket (Packet_LEDS_000,32);
                1: SendPacket (Packet_LEDS_001,32);
                2: SendPacket (Packet_LEDS_010,32);
                3: SendPacket (Packet_LEDS_011,32);
                4: SendPacket (Packet_LEDS_100,32);
                5: SendPacket (Packet_LEDS_101,32);
                6: SendPacket (Packet_LEDS_110,32);
                7: SendPacket (Packet_LEDS_111,32);
            endcase
        end
        `TL_SEND_ACK00,`TL_SEND_ACK20_CONFIG,
        `TL_SEND_ACK20_PROTOCOL,`TL_SEND_ACK_DATA1:begin
				SetTimer(1);
				SendPacket(Packet_ACK,8);
				if (TL_STM==`TL_SEND_ACK00)TL_STM<=`TL_SendSETUPConfig;
				else if (TL_STM==`TL_SEND_ACK20_CONFIG) TL_STM<=`TL_SendSETUPProtocol;
				else if (TL_STM==`TL_SEND_ACK_DATA1)begin
					TL_STM<=`TL_KeepAlive;
					LatchLEDS<=`LEDS;
				end
				else begin
					TL_STM<=`TL_IN21;
				end
        end
        `TL_IN00:begin
                SetTimer(0);
                SendPacket(Packet_IN00,24);
                Wait_Response(`TL_IN00,`TL_SEND_ACK00);
        end
        `TL_SendSETUPConfig,`TL_SendSETUPProtocol:begin 
                SendPacket(Packet_SETUP2,24);
                if (TL_STM==`TL_SendSETUPProtocol)TL_STM<=`TL_SetProtocol;
                else TL_STM<=`TL_SetConfig;
        end
        `TL_SetConfig:begin 
                SendPacket(Packet_SET_CONFIG,88);
                Wait_Response(`TL_SendSETUPConfig,`TL_IN20_CONFIG);
        end
        `TL_SetProtocol:begin 
                SendPacket(Packet_SET_PROTOCOL,88);
                Wait_Response(`TL_SendSETUPProtocol,`TL_IN20_PROTOCOL);
        end
        `TL_IN20_REPORT:begin
                SendPacket(Packet_IN20,24);
                SetTimer(0);
                Wait_Response(`TL_IN20_REPORT,`TL_SEND_ACK_DATA1);
        end
        `TL_IN20_CONFIG,`TL_IN20_PROTOCOL: begin
            SendPacket(Packet_IN20,24);
            SetTimer(0);
            if (TL_STM==`TL_IN20_PROTOCOL)
                Wait_Response(`TL_IN20_PROTOCOL,`TL_SEND_ACK20_PROTOCOL);
            else 
                Wait_Response(`TL_IN20_CONFIG,`TL_SEND_ACK20_CONFIG);
        end
        `TL_IN21:begin
                SetTimer(0);
                SendPacket(Packet_IN21,24);
                Wait_Response(`TL_IN21,`TL_VerifyData);
        end
        `TL_SEND_DATA0_REPORT:begin
            SendPacket(Packet_SET_REPORT,88);
            Wait_Response(`TL_KeepAlive,`TL_SEND_OUT20_REPORT);
        end
        `TL_KeepAlive:begin
            if (`LEDS!=LatchLEDS)begin
                TL_STM<=`TL_SEND_DATA0_REPORT;
                SendPacket(Packet_SETUP2,24);
                SetTimer(0);
            end
            else begin
                TL_STM<=`TL_KeepAlive2;
                SendPacket(Packet_SOF,24);
                SetTimer(1);
            end
        end
        `TL_KeepAlive2:begin
            if (PS2Busy==1)TL_STM<=`TL_KeepAlive2;
            else TL_STM<=`TL_IN21;
            SendPacket(Packet_SOF,24);
            SetTimer(1);  
        end
        `TL_VerifyData: begin
            SetTimer(1); 
            TL_STM<=`TL_KeepAlive;
            if (RECEIVED_PID==`PID_Data0 || RECEIVED_PID==`PID_Data1) begin
                SendPacket(Packet_ACK,8);
                if (RECEIVED_DATA[39:32]!=8'h01)begin
                    Rmodifiers<=RECEIVED_DATA[23:16];
                    RollOver<=RECEIVED_DATA[79:32];
                    PS2Busy<=1;
                end
            end
        end
    endcase
    end //TXLeftBits==0,TimerEnd==1,NewInPacket==1
    
////////////////////////////////////////////////////////////
//                 TRANSMISION ULPI                       //
////////////////////////////////////////////////////////////
	prev_DIR<=DIR;
	if (prev_DIR==`DIRAsOutput && DIR==`DIRAsOutput)begin
		if (TXLeftBits==1) begin
			if (STP==0)STP<=1;
			TX_Shift[7:0]<=`TX_NOOP;
			TXLeftBits<=0;
		end
		if (NXT==1) begin
			if (TXLeftBits>1)begin
				TX_Shift<={`TX_NOOP,TX_Shift[95:8]};
				TXLeftBits<=TXLeftBits-9'd1;
			end
		end
		if (STP==1)STP<=0;
    end  
////////////////////////////////////////////////////////////
//                    PS2 CONVERSION                      //
////////////////////////////////////////////////////////////
    if (PS2_buffer_busy==0)begin
        if (PS2Busy==1 && TL_STM!=`TL_VerifyData) begin
            case (PS2_STM)
                1,3,5,7,9,11,13,15: begin
                    PS2_STM<=PS2_STM+6'd1;
                    Cpy_Rmodifiers<={Cpy_Rmodifiers[0],Cpy_Rmodifiers[7:1]};
                    Rmodifiers<={Rmodifiers[0],Rmodifiers[7:1]};
                end
                0: begin
                    PS2_STM<=PS2_STM+6'd1;
                    if(Cpy_Rmodifiers[0]!=Rmodifiers[0])begin    
                        Cpy_Rmodifiers[0]<=Rmodifiers[0];
                        if (Cpy_Rmodifiers[0]==1) begin
                            Add_PS2_Buffer(24'h00F014);
                        end
                        else begin
                            Add_PS2_Buffer(24'h000014);
                        end
                    end
                end
                2: begin
                    PS2_STM<=PS2_STM+6'd1;
                    if(Cpy_Rmodifiers[0]!=Rmodifiers[0])begin
                        Cpy_Rmodifiers[0]<=Rmodifiers[0];
                        if (Cpy_Rmodifiers[0]==1) begin
                            Add_PS2_Buffer(24'h00F012);
                        end
                        else begin
                            Add_PS2_Buffer(24'h000012);
                        end
                    end
                end
                4: begin
                    PS2_STM<=PS2_STM+6'd1;
                    if(Cpy_Rmodifiers[0]!=Rmodifiers[0])begin
                        Cpy_Rmodifiers[0]<=Rmodifiers[0];
                        if (Cpy_Rmodifiers[0]==1) begin
                            Add_PS2_Buffer(24'h00F011);
                        end
                        else begin
                            Add_PS2_Buffer(24'h000011);
                        end
                    end
                end
                6: begin
                    PS2_STM<=PS2_STM+6'd1;
                    if(Cpy_Rmodifiers[0]!=Rmodifiers[0])begin
                        Cpy_Rmodifiers[0]<=Rmodifiers[0];
                        if (Cpy_Rmodifiers[0]==1) begin
                            Add_PS2_Buffer(24'hE0F01F);
                        end
                        else begin
                            Add_PS2_Buffer(24'h00E01F);
                        end
                    end
                end
                8: begin
                    PS2_STM<=PS2_STM+6'd1;
                    if(Cpy_Rmodifiers[0]!=Rmodifiers[0])begin
                        Cpy_Rmodifiers[0]<=Rmodifiers[0];
                        if (Cpy_Rmodifiers[0]==1) begin
                            Add_PS2_Buffer(24'hE0F014);
                        end
                        else begin
                            Add_PS2_Buffer(24'h00E014);
                        end
                    end
                end
                10: begin
                    PS2_STM<=PS2_STM+6'd1;
                    if(Cpy_Rmodifiers[0]!=Rmodifiers[0])begin
                        Cpy_Rmodifiers[0]<=Rmodifiers[0];
                        if (Cpy_Rmodifiers[0]==1) begin
                            Add_PS2_Buffer(24'h00F059);
                        end
                        else begin
                            Add_PS2_Buffer(24'h000059);
                        end
                    end
                end
                12: begin
                    PS2_STM<=PS2_STM+6'd1;
                    if(Cpy_Rmodifiers[0]!=Rmodifiers[0])begin
                        Cpy_Rmodifiers[0]<=Rmodifiers[0];
                        if (Cpy_Rmodifiers[0]==1) begin
                            Add_PS2_Buffer(24'hE0F011);
                        end
                        else begin
                            Add_PS2_Buffer(24'h00E011);
                        end
                    end
                end
                14: begin
                    PS2_STM<=PS2_STM+6'd1;
                    if(Cpy_Rmodifiers[0]!=Rmodifiers[0])begin
                        Cpy_Rmodifiers[0]<=Rmodifiers[0];
                        if (Cpy_Rmodifiers[0]==1) begin
                            Add_PS2_Buffer(24'hE0F027);
                        end
                        else begin
                            Add_PS2_Buffer(24'h00E027);
                        end
                    end
                end
                17,20,23,26,29,32:begin PS2_STM<=PS2_STM+6'd1;end //Wait for memory
                16,19,22,25,28,31:begin
                    PS2_STM<=PS2_STM+6'd1;
                    if (Cpy_RollOver[7:0]!=RollOver[7:0])begin
                        SendKey<=1;
                        if (Cpy_RollOver[7:0]==0) begin// Add key
                            Cpy_RollOver[7:0]<=RollOver[7:0];
                            PS2MemoryAdd<=RollOver[7:0];
                            AddKey<=1;
                        end
                        else begin //Remove key
                            Cpy_RollOver<={8'h00,Cpy_RollOver[47:8]};
                            PS2MemoryAdd<=Cpy_RollOver[7:0];
                            AddKey<=0;
                        end
                    end
                    else SendKey<=0;
                end
                18,21,24,27,30,33:begin
                    PS2_STM<=PS2_STM+6'd1;
                    Cpy_RollOver<={Cpy_RollOver[7:0],Cpy_RollOver[47:8]};
                    RollOver<={RollOver[7:0],RollOver[47:8]};
                    if (SendKey==1 && PS2Code[7:0]!=0)begin //Invalid keys
                        if (AddKey==1)begin
                            Add_PS2_Buffer({8'h0,PS2Code});
                        end
                        else begin
                            Add_PS2_Buffer({PS2Code[15:8],8'hF0,PS2Code[7:0]});
                        end
                    end
                end
                34: begin
                    PS2_STM<=0;
                    PS2Busy<=0;
                end
            endcase
         end
    end
////////////////////////////////////////////////////////////
//                    PS2 TRANSMISION                     //
////////////////////////////////////////////////////////////  
    else begin
        if (PS2_Prescaler==0) begin
        PS2_Prescaler<=`PS2_PRES;
        case(PS2TX_STM) 
            0,24: begin
                if (`NextChar==0) begin
                    PS2_signal<={11'b0,PS2_signal[32:11]};
                    PS2TX_STM<=PS2TX_STM+7'd24;
                end
                else begin
                    ParityBit<=1;
                    PS2TX_STM<=PS2TX_STM+7'd1;
                    PS2data<=`StartBit;
                end
            end
            48: begin
                if (`NextChar==0) begin
                    PS2_buffer_busy<=0;
                    PS2TX_STM<=0;
                end
                else begin
                    ParityBit<=1;
                    PS2TX_STM<=PS2TX_STM+7'd1;
                    PS2data<=`StartBit;
                end
            end
            18,42,66: begin
                PS2clock<=1;
                PS2data<=ParityBit;
                PS2TX_STM<=PS2TX_STM+7'd1;
            end
            23,47: PS2TX_STM<=PS2TX_STM+7'd1;
            71: begin
                PS2_buffer_busy<=0;
                PS2TX_STM<=0;
                PS2data<=1;
            end
            default: begin
                if (PS2TX_STM[0]==0) begin
                    PS2clock<=1;
                    PS2data<=PS2_signal[0];
                    PS2TX_STM<=PS2TX_STM+7'd1;
                end
                else begin
                    PS2clock<=0;
                    PS2_signal<={1'b0,PS2_signal[32:1]};
                    ParityBit<=ParityBit^PS2data;
                    PS2TX_STM<=PS2TX_STM+7'd1;
                end
            end
        endcase
        end
        else PS2_Prescaler<=PS2_Prescaler-11'd1;
    end 
end 

////////////////////////////////////////////////////////////
//                   RECEPCION ULPI                       //
////////////////////////////////////////////////////////////
//El PHY cambia las señales en el flanco negativo

reg [1:0]INDECODE_STM=`STM_UNCONNECTED;
reg [7:0]RECEIVED_PID=0;
reg [95:0]RECEIVED_DATA=0;
reg NewInPacket=0;
reg [6:0]NewDelayPacket=0;


`define RXEvent         DATA[5:4]
`define LineState       DATA[1:0]
`define RXAttached      2'b00
`define RXError         2'b11
`define RXActive        2'b01

always @(posedge clk)begin
    if (NewInPacket==1) NewInPacket<=0;
	 if (NewDelayPacket>0) begin
		if (NewDelayPacket==127) begin
			NewInPacket<=1;
			NewDelayPacket<=0;
		end
		else NewDelayPacket<=NewDelayPacket+1;
	 end
	 if (prev_DIR==DIR)begin
        if (DIR==`DIRAsInput)begin
            if (NXT==1) begin NewData:
                if (INDECODE_STM==`STM_PID)begin
                    RECEIVED_PID<=DATA;
                    INDECODE_STM<=`STM_DATAFIELD;
                end
                else begin
                    RECEIVED_DATA<={DATA,RECEIVED_DATA[95:8]};
                end
            end
            else begin NewCommand:
                case (INDECODE_STM)
                    `STM_UNCONNECTED:begin
                        if (`RXEvent==`RXAttached)begin
                            INDECODE_STM<=`STM_IDLE;
                        end
                    end
                    `STM_IDLE:begin
                        if (`RXEvent==`RXActive)begin
                            RECEIVED_DATA<=0;
                            RECEIVED_PID<=0;
                            INDECODE_STM<=`STM_PID;
                        end
                    end
                    `STM_DATAFIELD:begin
                        if (`RXEvent==`RXAttached) begin
                            INDECODE_STM<=`STM_IDLE;
									 NewDelayPacket<=1;
                        end
                    end
                endcase
            end
        end
        else begin DirAsOutput:
            if (INDECODE_STM==`STM_DATAFIELD)begin
                INDECODE_STM<=`STM_IDLE;
					 NewDelayPacket<=1;
            end
        end
	end
end

////////////////////////////////////////////////////////////
//                    PS2 MEMORY TABLE                    //
////////////////////////////////////////////////////////////  
reg [15:0]PS2Memory[0:127];
reg [6:0]PS2MemoryAdd=0;
reg [15:0]PS2Code=0;
initial 
	$readmemh ("USB_PS2_CONVERSION.txt",PS2Memory);
    
always @(posedge clk)begin
    PS2Code<=PS2Memory[PS2MemoryAdd];
end    

////////////////////////////////////////////////////////////
//                     TAREAS (TASK)                      //
//////////////////////////////////////////////////////////// 
task Add_PS2_Buffer(input [23:0]sig);
    begin
    PS2_buffer_busy<=1;
    PS2_signal<=
        {`StopBit,`StopBit,sig[7:0],`StartBit,`StopBit,`StopBit,sig[15:8],`StartBit,`StopBit,`StopBit,sig[23:16],`StartBit};
    end
endtask

task Wait_Response(input [4:0]InCaseFail,input [4:0]InCaseOK);
    begin
    TL_Fail<=InCaseFail;
    TL_ResponseOK<=InCaseOK;
    TL_STM<=`TL_Wait;
    end
endtask

task SendReset;
    begin
    SendPacket(ULPI_NonDrivin,16);
    end
endtask

task SendPacket(input [95:0]Packet,input [9:0] PacketSize);
    begin
      TX_Shift<=Packet;
		TXLeftBits<=(PacketSize/8)+1;
    end
endtask

task SetTimer(input integer milliseconds);
    begin
        TimerPreload<=`CLK_MULT*milliseconds;
        StartTimer<=1;
    end
endtask

////////////////////////////////////////////////////////////
//                Temporizador auxiliar                   //
//////////////////////////////////////////////////////////// 
reg [21:0] TimerPreload=0;
reg StartTimer=0;
wire TimerEnd=(rTimerEnd & ~StartTimer);
reg rTimerEnd=0;
reg PrevStartTimer=0;
reg [21:0]Counter=0;

always @(posedge clk)begin
    PrevStartTimer<=StartTimer;
    if (StartTimer && !PrevStartTimer)begin
        Counter<=TimerPreload;
        rTimerEnd<=0;
    end
    else if (Counter==0) begin
        rTimerEnd<=1;
    end
    else Counter<=Counter-22'd1;
end    
endmodule 
