//*********************************************************
//    HD63701V0 Compatible Processor Core
//
//    By Jose Tejada 2019-2020
//
//*********************************************************

module jt63701(
    input           rst,
    input           clk,
    input           cen,

    input           haltn,
    output          ba,     // Bus Available
    input           nmi,    // NMI  (active high) 
    input           irq,    // IRQ1 (active high)
    output          wr,     // CS2. High for writting
    output  [15:0]  AD,     //  AS ? {PO4,PO3}
    output  [ 7:0]  dout,   // ~AS ? {PO3}
    input   [ 7:0]  din,    //       {PI3}

    input   [ 7:0]  p1_din,
    output  [ 7:0]  p1_dout,

    input   [ 4:0]  p2_din,
    output  [ 4:0]  p2_dout,

    input   [ 7:0]  p6_din,
    output  [ 7:0]  p6_dout,
    // ROM Access
    output  [13:0]  rom_addr,
    input   [ 7:0]  rom_data,
    output          rom_cs,
    input           rom_ok
);

// Built-In Instruction ROM
reg         halted_n;
assign      rom_cs = (AD[15:14]==2'b11);     // $C000-$FFFF
assign      ba = rom_cs || !halted_n;   // Safe to stop when accessing the internal PROM
assign      rom_addr = AD[13:0];

// Built-In WorkRAM
parameter BIRAM_START = 16'h40;
parameter BIRAM_END   = 16'h13F;
wire        en_biram = AD>=BIRAM_START && AD<=BIRAM_END;
wire [7:0]  biramd;
wire        biram_we = en_biram & wr;
// HD63701_BIRAM biram( CLKx2, AD, wr, dout, en_biram, biramd );

jtframe_ram #(.AW(8)) u_biram( // built-in RAM
    .clk    ( clk         ),
    .cen    ( cen_fall    ),
    .data   ( dout        ),
    .addr   ( AD[7:0]     ),
    .we     ( biram_we    ),
    .q      ( biramd      )
);


// Built-In I/O Ports
wire      en_biio;
wire [7:0] biiod;
HD63701_IOPort iopt(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .mcu_ad     ( AD        ),
    .mcu_wr     ( wr        ),
    .mcu_do     ( dout      ),
    .en_io      ( en_biio   ),
    .iod        ( biiod     ),
    .PI1        ( p1_din    ),
    .PI2        ( p2_din    ),
    .PI6        ( p6_din    ),
    .PO1        ( p1_dout   ),
    .PO2        ( p2_dout   ),
    .PO6        ( p6_dout   )
);

// Built-In Timer
wire        irq2;
wire [3:0]  irq2v;
wire        en_bitim;
wire [7:0]  bitimd;
HD63701_Timer timer( //rst, clk, AD, wr, dout, irq2, irq2v, en_bitim, bitimd );
    .rst         ( rst           ),
    .clk         ( clk           ),
    .cen_rise2   ( cen_rise2     ),
    .cen_fall2   ( cen_fall2     ),
    .mcu_ad      ( AD            ),
    .mcu_wr      ( wr            ),
    .mcu_do      ( dout          ),
    .mcu_irq2    ( irq2          ),
    .mcu_irq2v   ( irq2v         ),
    .en_timer    ( en_bitim      ),
    .timerd      ( bitimd        )
);


// Built-In Devices Data Selector
wire [7:0] biddi;
HD63701_BIDSEL bidsel(
  biddi,
  rom_cs, rom_data,
  en_biram, biramd,
  en_biio , biiod, 
  en_bitim, bitimd,
  din
);

wire [6:0] phase;

// Halt procedure
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        halted_n <= 1'b1;
    end else begin
        if( !haltn && rom_cs ) halted_n <= 1'b0; // only halt when accessing the ROM
        if( haltn ) halted_n <= 1'b1;
    end
end

reg waitn;

always @(posedge clk, posedge rst) begin : romcs_edge
    reg last_romcs;
    last_romcs <= rom_cs;
    if( rst )
        waitn <= 1'b1;
    else begin
        if( rom_cs && !last_romcs ) waitn<=1'b0;
        else if( rom_ok ) waitn <= 1'b1;
    end
end

reg core_cen0, core_cen1;

always @(negedge clk) begin
    core_cen0 <= cen_fall & waitn & halted_n;
    core_cen1 <= cen_rise & waitn & halted_n;
end

HD63701_Core core (  
  .rst      ( rst       ),
  .clk      ( clk       ),
  .cen_fall ( core_cen0 ),
  .cen_rise ( core_cen1 ),
  
  .NMI      ( nmi       ),
  .IRQ      ( irq       ),
  .IRQ2     ( irq2      ),
  .IRQ2V    ( irq2v     ),
  
  .RW       ( wr        ),
  .AD       ( AD        ),
  .DO       ( dout      ),
  .DI       ( biddi     ),
  
  .PH       ( phase[5:0]),
  // unused
  .MC(),
  .REG_D(),
  .REG_X(),
  .REG_S(),
  .REG_C()
);
assign phase[6] = irq2;

endmodule


module HD63701_BIDSEL(
  output [7:0] o,

  input e0, input [7:0] d0,
  input e1, input [7:0] d1,
  input e2, input [7:0] d2,
  input e3, input [7:0] d3,

  input [7:0] dx
);

assign o =  e0 ? d0 :
        e1 ? d1 :
        e2 ? d2 :
        e3 ? d3 :
        dx;

endmodule

/*
module HD63701_BIRAM(
  input             mcu_clx2,
  input      [15:0] mcu_ad,
  input             mcu_wr,
  input      [ 7:0] mcu_do,
  output            en_biram,
  output reg [ 7:0] biramd
);

assign en_biram = (mcu_ad[15: 7]==9'b1);  // $0080-$00FF
wire [6:0] biad = mcu_ad[6:0];

reg [7:0] bimem[0:127];
always @( posedge mcu_clx2 ) begin
  if (en_biram & mcu_wr) bimem[biad] <= mcu_do;
  else biramd <= bimem[biad];
end

endmodule
*/

module HD63701_IOPort (
    input              rst,
    input              clk,
    input       [15:0] mcu_ad,
    input              mcu_wr,
    input        [7:0] mcu_do,

    output             en_io,
    output reg   [7:0] iod,

    input        [7:0] PI1,
    input        [4:0] PI2,
    input        [7:0] PI6,

    output reg   [7:0] PO1,
    output reg   [4:0] PO2,
    output reg   [7:0] PO6
);

    always @( posedge clk or posedge rst ) begin
        if (rst) begin
                PO1 <= 8'hFF;
                PO2 <= 5'h1F;
                PO6 <= 8'hFF;
            end else begin
            if (mcu_wr) begin
                case( mcu_ad )
                    16'h02: PO1 <= mcu_do;
                    16'h03: PO2 <= mcu_do[4:0];
                    16'h17: PO6 <= mcu_do;
                endcase
            end
        end
    end

    assign en_io = (mcu_ad==16'h2)|(mcu_ad==16'h3)|(mcu_ad==16'h17);

    always @(*) begin
        case( mcu_ad[4:0] )
            5'h02:   iod = PI1;
            5'h03:   iod = {3'b111,PI2};
            5'h17:   iod = PI6;
            default: iod = 8'hff;
        endcase
    end
endmodule


module HD63701_Timer(
    input           rst,
    input           clk,
    input           cen_rise2,
    input           cen_fall2,
    input    [15:0] mcu_ad,
    input           mcu_wr,
    input    [ 7:0] mcu_do,

    output          mcu_irq2,
    output   [ 3:0] mcu_irq2v,

    output          en_timer,
    output   [ 7:0] timerd
);

reg        oci, oce;
reg [15:0] ocr, icr;
reg [16:0] frc;
reg [ 7:0] frt;
reg [ 7:0] rmc, rg5;

always @( posedge clk or posedge rst ) begin
    if (rst) begin
        oce <= 0;
        ocr <= 16'hFFFF;
        icr <= 16'hFFFF;
        frc <= 0;
        frt <= 0;
        rmc <= 8'h40;
        rg5 <= 0;
    end else if(cen_rise2) begin
        frc <= frc+1;
        if (mcu_wr) begin
            case (mcu_ad)
                16'h05: rg5 <= mcu_do;
                16'h08: oce <= mcu_do[3];
                16'h09: frt <= mcu_do;
                16'h0A: frc <= {frt,mcu_do,1'h0};
                16'h0B: ocr[15:8] <= mcu_do;
                16'h0C: ocr[ 7:0] <= mcu_do;
                16'h0D: icr[15:8] <= mcu_do;
                16'h0E: icr[ 7:0] <= mcu_do;
                16'h14: rmc <= {mcu_do[7:6],6'h0};
                default:;
            endcase
        end
    end
end

always @( posedge clk or posedge rst ) begin
    if (rst) begin
        oci <= 0;
    end else if(cen_fall2) begin
        case (mcu_ad)
            16'h0B: oci <= 0;
            16'h0C: oci <= 0;
            default: if (frc[16:1]==ocr) oci <= 1'b1;
        endcase
    end
end

assign mcu_irq2  = oci & oce;
assign mcu_irq2v = 4'h4;

assign en_timer = (mcu_ad==16'h05)|((mcu_ad>=16'h8)&(mcu_ad<=16'hE))|(mcu_ad==16'h14);

assign   timerd = (mcu_ad==16'h05) ? rg5 :
            (mcu_ad==16'h08) ? {1'b0,oci,2'b10,oce,3'b000}:
            (mcu_ad==16'h09) ? frc[16:9] :
            (mcu_ad==16'h0A) ? frc[ 8:1] :
            (mcu_ad==16'h0B) ? ocr[15:8] :
            (mcu_ad==16'h0C) ? ocr[ 7:0] :
            (mcu_ad==16'h0D) ? icr[15:8] :
            (mcu_ad==16'h0E) ? icr[ 7:0] :
            (mcu_ad==16'h14) ? rmc :
            8'h0;

endmodule

