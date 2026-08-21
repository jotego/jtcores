/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off CASEOVERLAP */
module IKA87AD(
    //clock
    input   wire                i_EMUCLK,
    input   wire                i_MCUCLK_PCEN,

    //system control
    input   wire                i_RESET_n,
    input   wire                i_STOP_n,

    //M1/IO cycle output(mode0/1 open drain, negative logic output)
    output  wire                o_M1_n,
    output  wire                o_IO_n,

    //R/W control and output enables
    output  wire                o_ALE,
    output  wire                o_RD_n,
    output  wire                o_WR_n,

    //full address and data input/output port
    output  wire    [15:0]      o_A,
    input   wire    [7:0]       i_DI,
    output  wire    [7:0]       o_DO,
    output  wire                o_PD_DO_OE, //port D multiplexed ADDR/DATA output output enable
    output  wire                o_D_nA_SEL, //port D multiplexed ADDR/DATA select signal 
    output  wire                o_DO_OE, //data bus output enable

    //memory structure config register
    output  wire    [7:0]       o_REG_MM, //MM register

    //interrupt control
    input   wire                i_NMI_n,
    input   wire                i_INT1,
    input   wire                i_INT2_n, //PC3

    //timer control
    input   wire                i_TI, //PC3
    output  wire                o_TO, //PC4
    output  wire                o_TO_PCEN, //TO output positive edge clock enable
    output  wire                o_TO_NCEN, //TO output negative edge clock enable

    //event counter control
    input   wire                i_CI, //PC5

    //port A I/O and output enables
    input   wire    [7:0]       i_PA_I,
    output  wire    [7:0]       o_PA_O,
    output  wire    [7:0]       o_PA_OE, //bitwise direction control

    //port B I/O and output enables
    input   wire    [7:0]       i_PB_I,
    output  wire    [7:0]       o_PB_O,
    output  wire    [7:0]       o_PB_OE,

    //port C I/O and output enables
    input   wire    [7:0]       i_PC_I,
    output  wire    [7:0]       o_PC_O,
    output  wire    [7:0]       o_PC_OE,
    output  wire    [7:0]       o_REG_MCC, //port C alternative function select

    //port D I/O and output enables
    input   wire    [7:0]       i_PD_I,
    output  wire    [7:0]       o_PD_O,
    output  wire                o_PD_OE, //can set only a bytewise direction

    //port F I/O and output enables
    input   wire    [7:0]       i_PF_I,
    output  wire    [7:0]       o_PF_O,
    output  wire    [7:0]       o_PF_OE,

    //AN4-7 digital edge detector
    input   wire    [3:0]       i_ANx_DIGITAL,

    //ADC interface
    output  wire    [2:0]       o_ANx_ANALOG_CH,   //adc channel select, from 0 to 7
    input   wire    [7:0]       i_ANx_ANALOG_DATA, //adc data input
    output  wire                o_ANx_ANALOG_RD_n  //conversion data read strobe
);

//include mnemonic list
import IKA87AD_mnemonics::*;

//hardware stop mode release wait time
localparam HARD_STOP_RELEASE_WAIT = 20'd78;

///////////////////////////////////////////////////////////
//////  CLOCK AND RESET
////

wire            emuclk = i_EMUCLK;
wire            mcuclk_pcen = i_MCUCLK_PCEN;
wire            mrst_n = i_RESET_n;



///////////////////////////////////////////////////////////
//////  OPCODE DECODER
////

logic   [2:0]   opcode_page; //page indicator
logic   [7:0]   reg_OPCODE; //opcode register

//disassembler
logic   [1:0]   reg_FULL_OPCODE_cntr;
logic   [7:0]   reg_FULL_OPCODE_debug[0:3]; //wtf

//opcode decoder
wire    [7:0]   mcrom_sa;
IKA87AD_opdec u_opdec (
    .i_OPCODE                   (reg_OPCODE                 ),
    .i_OPCODE_PAGE              (opcode_page                ),
    .o_MCROM_SA                 (mcrom_sa                   )
);



///////////////////////////////////////////////////////////
//////  MICROCODE OUTPUT SIGNALS
////

//microcode ROM control/raw output
wire            mcrom_read_tick; //BRAM read tick
wire    [17:0]  mcrom_data; //ROM output, registered

//modified control output
logic   [17:0]  mc_ctrl_output; //combinational

//fixed fields
wire    [1:0]   mc_type             = mc_ctrl_output[17:16];
wire            mc_alter_flag       = mcrom_data[15];
wire            mc_jmp_to_next_inst = mcrom_data[14];

//bus control signals
wire    [1:0]   mc_next_bus_acc     = mc_ctrl_output[1:0];

//MICROCODE TYPE 0 FIELDS
wire    [3:0]   mc_t0_src           = mc_ctrl_output[13:10];
wire    [3:0]   mc_t0_dst           = mc_ctrl_output[9:6];
wire    [3:0]   mc_t0_deu_op        = mc_ctrl_output[5:2];

//MICROCODE TYPE 1 FIELDS
wire    [3:0]   mc_t1_src           = mc_ctrl_output[13:10];
wire    [3:0]   mc_t1_dst           = mc_ctrl_output[9:6];
wire    [3:0]   mc_t1_aeu_op        = mc_ctrl_output[5:2];

//MICROCODE TYPE 2 FIELDS
wire    [2:0]   mc_t2_atype_sel     = mc_ctrl_output[12:10];
wire            mc_t2_carry_ctrl    = mc_ctrl_output[9];
wire            mc_t2_irq_ctrl      = mc_ctrl_output[8];
wire    [1:0]   mc_t2_reg_exchg     = mc_ctrl_output[7:6];
wire            mc_t2_cpu_susp      = mc_ctrl_output[5];
wire    [2:0]   mc_t2_skip_ctrl     = mc_ctrl_output[4:2];

//MICROCODE TYPE 3 FIELDS
wire            mc_t3_ird           = mc_ctrl_output[6];
wire            mc_t3_cond_pc_dec   = mc_ctrl_output[5];
wire    [2:0]   mc_t3_bra_on_alu    = mc_ctrl_output[4:2];

//ALU FIELDS
wire    [3:0]   arith_code = opcode_page == 3'd0 ? {reg_OPCODE[0], reg_OPCODE[6:4]} : {reg_OPCODE[3], reg_OPCODE[6:4]};
wire            is_arith_eval_op = arith_code > 4'h9; //is an arithmetic code the evaluation operation like GT, NE, OFF, ON, EQ, NE?
wire            is_arith_mov     = arith_code == 4'h0;
wire    [3:0]   shift_code = {reg_OPCODE[7], reg_OPCODE[2], reg_OPCODE[5:4]}; //w_d_tt(word, direction R/L, type)

//END OF INSTRUCTION
wire            mc_end_of_instruction = mc_next_bus_acc == RD4 && !(mc_type == MCTYPE3 && mc_t3_ird);



///////////////////////////////////////////////////////////
//////  TIMING GENERATOR
////

logic           halt_flag, soft_stop_flag, hard_stop_flag;
wire            sr_stop = halt_flag | soft_stop_flag | hard_stop_flag;

logic   [11:0]  timing_sr;
logic   [1:0]   current_bus_acc;

wire    opcode_tick = timing_sr[11] & current_bus_acc == RD4 & mcuclk_pcen;
wire    rw_tick = timing_sr[8] & current_bus_acc != RD4 & mcuclk_pcen;
wire    cycle_tick = opcode_tick | rw_tick;

assign  mcrom_read_tick = (timing_sr[8] | timing_sr[11]) & mcuclk_pcen;

wire    opcode_inlatch_tick = timing_sr[6] & current_bus_acc == RD4 & mcuclk_pcen;
wire    md_inlatch_tick  = timing_sr[6] & current_bus_acc == RD3 & mcuclk_pcen;
wire    md_outlatch_tick = timing_sr[2] & current_bus_acc == WR3 & mcuclk_pcen;
wire    full_opcode_inlatch_tick_debug = timing_sr[6] & (current_bus_acc == RD4 | current_bus_acc == RD3) & mcuclk_pcen;

always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        timing_sr <= 12'b000_100_000_000;
        current_bus_acc <= RD4;
    end
    else begin if(mcuclk_pcen) begin
        if(current_bus_acc == RD4) begin
            if(timing_sr[11]) begin
                current_bus_acc <= mc_next_bus_acc;
                timing_sr <= {timing_sr[10:0], timing_sr[11]};
            end
            else if(timing_sr[10]) begin if(!sr_stop) timing_sr <= {timing_sr[10:0], timing_sr[11]}; end
            else timing_sr <= {timing_sr[10:0], timing_sr[11]};
        end
        else begin
            if(timing_sr[8]) begin
                current_bus_acc <= mc_next_bus_acc;
                timing_sr[8:0] <= {timing_sr[7:0], timing_sr[8]};
            end
            else timing_sr[8:0] <= {timing_sr[7:0], timing_sr[8]};
        end
    end end
end



///////////////////////////////////////////////////////////
//////  INTERRUPT HANDLER
////

//interrupt related registers
wire    [10:0]  irq_mask_n; //interrupt mask register: (MSB)empty, full, adc, ncntrcin, cntr1, cntr0, pint1, nint2, timer1, timer0(LSB), 1'b1
logic           irq_enabled;

//interrupt sources(wire)
wire            is_NMI, is_TIMER0, is_TIMER1, is_pINT1, is_nINT2, is_CNTR0, is_CNTR1, is_nCNTRCIN, is_ADC; //implemented
wire            is_BUFFULL, is_BUFEMPTY; //not yet implemented

assign is_BUFFULL = 1'b0;
assign is_BUFEMPTY = 1'b0;

wire    [10:0]  is = {is_BUFEMPTY, is_BUFFULL, is_ADC, is_nCNTRCIN, is_CNTR1, is_CNTR0, is_nINT2, is_pINT1, is_TIMER1, is_TIMER0, is_NMI};

//interrupt sampler, note that interrupt sampler uses an independent divided clock
IKA87AD_irqsampler u_nmi_sampler   (mrst_n, emuclk, mcuclk_pcen, ~i_NMI_n, is_NMI);
IKA87AD_irqsampler u_pint1_sampler (mrst_n, emuclk, mcuclk_pcen, i_INT1, is_pINT1);
IKA87AD_irqsampler u_nint2_sampler (mrst_n, emuclk, mcuclk_pcen, ~i_INT2_n, is_nINT2);

//interrupt flags
wire    [10:0]  iflag; //interrupt flag
wire    [6:0]   eflag; //exception flag

assign iflag[10:9] = 2'b00; //not implemented

/*
wire            iflag_NMI       = iflag[0]; //nNMI physical pin input, takes maximum 10us to suppress glitch
wire            iflag_TIMER0    = iflag[1]; //timer 0/1 match interrupt
wire            iflag_TIMER1    = iflag[2]; 
wire            iflag_pINT1     = iflag[3]; //INT1, nINT2 physical pin input, takes 12+2 mcuclk cycles to suppress glitch
wire            iflag_nINT2     = iflag[4]; 
wire            iflag_CNTR0     = iflag[5]; //timer/event counter 0/1 match interrupt
wire            iflag_CNTR1     = iflag[6]; 
wire            iflag_nCNTRCIN  = iflag[7]; //falling edge of the timer/event countr input (CI input) or timer output (TO) -> from the datasheet
wire            iflag_ADC       = iflag[8]; //adc conversion complete
wire            iflag_BUFFULL   = iflag[9]; //UART buffer full/empty
wire            iflag_BUFEMPTY  = iflag[10];
*/

//softi/hardi processing cycle
wire            softi_proc_cyc = opcode_page == 3'd0 && reg_OPCODE == 8'h72;
wire            hardi_proc_cyc = opcode_page == 3'd0 && reg_OPCODE == 8'h73;

//A user should ack an iflag manually when both interrupt sources belonging to a same irq level are not masked
wire            iflag_manual_ack = mc_type == MCTYPE2 && mc_t2_skip_ctrl[2:1] == 2'b11; 

//An iflag is acknowledged when the HARDI instruction starts
wire            iflag_auto_ack = hardi_proc_cyc && mc_end_of_instruction;

//interrupt priority
wire    [5:0]   masked_irq =   { iflag[0] & irq_mask_n[0],
                                (iflag[1] & irq_mask_n[1]) | (iflag[2] & irq_mask_n[2]),
                                (iflag[3] & irq_mask_n[3]) | (iflag[4] & irq_mask_n[4]),
                                (iflag[5] & irq_mask_n[5]) | (iflag[6] & irq_mask_n[6]),
                                (iflag[7] & irq_mask_n[7]) | (iflag[8] & irq_mask_n[8]),
                                (iflag[9] & irq_mask_n[9]) | (iflag[10] & irq_mask_n[10])};

logic   [2:0]   irq_lv;
always_comb begin
    casez(masked_irq)
        6'b1?????: irq_lv = 3'd7; //NMI
        6'b01????: irq_lv = 3'd6;
        6'b001???: irq_lv = 3'd5;
        6'b0001??: irq_lv = 3'd4;
        6'b00001?: irq_lv = 3'd3;
        6'b000001: irq_lv = 3'd2;
        6'b000000: irq_lv = 3'd1; //spurious interrupt
        default  : irq_lv = 3'd0;
    endcase
end

//NMI interrupt flag set/reset
IKA87AD_flag u_nmi          (mrst_n, emuclk, mcuclk_pcen, cycle_tick, is[0],          1'b1, 5'd0, reg_OPCODE[4:0], 
                                          1'b0,             1'b0, iflag_auto_ack && irq_lv == 3'd7, iflag[0]);

//Timer0/1 interrupt flag set/reset
IKA87AD_flag u_timer0       (mrst_n, emuclk, mcuclk_pcen, cycle_tick, is[1], irq_mask_n[1], 5'd1, reg_OPCODE[4:0], 
                            &{irq_mask_n[2:1]}, iflag_manual_ack, iflag_auto_ack && irq_lv == 3'd6, iflag[1]);
IKA87AD_flag u_timer1       (mrst_n, emuclk, mcuclk_pcen, cycle_tick, is[2], irq_mask_n[2], 5'd2, reg_OPCODE[4:0], 
                            &{irq_mask_n[2:1]}, iflag_manual_ack, iflag_auto_ack && irq_lv == 3'd6, iflag[2]);

//Pin interrupt flag set/reset
IKA87AD_flag u_int1         (mrst_n, emuclk, mcuclk_pcen, cycle_tick, is[3], irq_mask_n[3], 5'd3, reg_OPCODE[4:0], 
                            &{irq_mask_n[4:3]}, iflag_manual_ack, iflag_auto_ack && irq_lv == 3'd5, iflag[3]);
IKA87AD_flag u_int2         (mrst_n, emuclk, mcuclk_pcen, cycle_tick, is[4], irq_mask_n[4], 5'd4, reg_OPCODE[4:0], 
                            &{irq_mask_n[4:3]}, iflag_manual_ack, iflag_auto_ack && irq_lv == 3'd5, iflag[4]);

//Event counter
IKA87AD_flag u_cntr0        (mrst_n, emuclk, mcuclk_pcen, cycle_tick, is[5], irq_mask_n[5], 5'd5, reg_OPCODE[4:0], 
                            &{irq_mask_n[6:5]}, iflag_manual_ack, iflag_auto_ack && irq_lv == 3'd4, iflag[5]);
IKA87AD_flag u_cntr1        (mrst_n, emuclk, mcuclk_pcen, cycle_tick, is[6], irq_mask_n[6], 5'd6, reg_OPCODE[4:0], 
                            &{irq_mask_n[6:5]}, iflag_manual_ack, iflag_auto_ack && irq_lv == 3'd4, iflag[6]);

//CI input/ADC
IKA87AD_flag u_ci           (mrst_n, emuclk, mcuclk_pcen, cycle_tick, is[7], irq_mask_n[7], 5'd7, reg_OPCODE[4:0], 
                            &{irq_mask_n[8:7]}, iflag_manual_ack, iflag_auto_ack && irq_lv == 3'd3, iflag[7]);
IKA87AD_flag u_adc          (mrst_n, emuclk, mcuclk_pcen, cycle_tick, is[8], irq_mask_n[8], 5'd8, reg_OPCODE[4:0], 
                            &{irq_mask_n[8:7]}, iflag_manual_ack, iflag_auto_ack && irq_lv == 3'd3, iflag[8]);

//interrupt generation
logic   [2:0]   irq_lv_z;
logic           irq_pending;
wire            irq_det = (irq_pending & irq_lv < 3'd7 & irq_enabled) | (irq_pending & irq_lv == 3'd7);
always_ff @(posedge emuclk) if(mcuclk_pcen) begin
    irq_lv_z <= irq_lv;
end

always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        irq_pending <= 1'b0;
    end
    else begin
        if(irq_pending) begin
            if(mcuclk_pcen) if(iflag_auto_ack) irq_pending <= 1'b0; 
        end
        else begin
            if(mcuclk_pcen) if((irq_lv != 3'd1) && (irq_lv != irq_lv_z)) irq_pending <= 1'b1;
        end
    end
end

//1st(RD4) cycle of the special hardi insturction
logic           force_exec_hardi;
always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        force_exec_hardi <= 1'b0; 
    end
    else begin if(cycle_tick) begin
        if(irq_det && mc_end_of_instruction) force_exec_hardi <= 1'b1;
        else force_exec_hardi <= 1'b0;
    end end
end
    
//interrupt enable(1), disable(0)
always_ff @(posedge emuclk) begin
    if(!mrst_n) irq_enabled <= 1'b0; 
    else begin if(cycle_tick) begin
        if(hardi_proc_cyc) irq_enabled <= 1'b0;
        else begin
            if(mc_type == MCTYPE2 && mc_t2_irq_ctrl == 1'b1) irq_enabled <= ~reg_OPCODE[4];
        end
    end end
end

//interrupt routine address
logic   [15:0]  irq_addr;
wire    [15:0]  spurious_irq_addr;
always_comb begin
    if(softi_proc_cyc) irq_addr = 16'h0060; //SOFTI
    else begin
        case(irq_lv)
            3'd7: irq_addr = 16'h0004; //NMI
            3'd6: irq_addr = 16'h0008; //TIMER
            3'd5: irq_addr = 16'h0010; //INT PIN
            3'd4: irq_addr = 16'h0018; //COUNTER RELATED
            3'd3: irq_addr = 16'h0020; //ADC
            3'd2: irq_addr = 16'h0028; //SERIAL INTERFACE
            3'd1: irq_addr = spurious_irq_addr; //no interrupt
            3'd0: irq_addr = spurious_irq_addr; //no interrupt
        endcase
    end
end

//interrupt flag selector
logic           nmi_n_z;
always_ff @(posedge emuclk) if(mcuclk_pcen) begin
    nmi_n_z <= i_NMI_n;
end

logic           iflag_muxed;
always_comb begin
    case(reg_OPCODE[4:0])
        5'h00: iflag_muxed = nmi_n_z;
        5'h01: iflag_muxed = iflag[1];
        5'h02: iflag_muxed = iflag[2];
        5'h03: iflag_muxed = iflag[3];
        5'h04: iflag_muxed = iflag[4];
        5'h05: iflag_muxed = iflag[5];
        5'h06: iflag_muxed = iflag[6];
        5'h07: iflag_muxed = iflag[7];
        5'h08: iflag_muxed = iflag[8];
        5'h09: iflag_muxed = iflag[9];
        5'h0A: iflag_muxed = iflag[10];
        5'h0B: iflag_muxed = eflag[0];
        5'h0C: iflag_muxed = eflag[1];
        5'h10: iflag_muxed = eflag[2];
        5'h11: iflag_muxed = eflag[3];
        5'h12: iflag_muxed = eflag[4];
        5'h13: iflag_muxed = eflag[5];
        5'h14: iflag_muxed = eflag[6];
        default: iflag_muxed = 1'b0;
    endcase
end




///////////////////////////////////////////////////////////
//////  SUSPENSION CONTROL
////

//stop pin sync chain
logic   [1:0]       stop_sync;
always @(posedge emuclk) if(mcuclk_pcen) stop_sync <= {stop_sync[0], ~i_STOP_n};

//halt/stop detection
wire                soft_halt_det = mc_type == MCTYPE2 && mc_t2_cpu_susp && reg_OPCODE[7] == 1'b0;
wire                soft_stop_det = mc_type == MCTYPE2 && mc_t2_cpu_susp && reg_OPCODE[7] == 1'b1;
wire                hard_stop_det = mc_end_of_instruction && stop_sync[1];
wire                susp_det = soft_halt_det | soft_stop_det | hard_stop_det;

//force exec nop
logic           force_exec_nop;
always_ff @(posedge emuclk) begin
    if(!mrst_n) force_exec_nop <= 1'b0;
    else begin if(cycle_tick) begin
        if(mc_end_of_instruction) force_exec_nop <= susp_det;
    end end
end

//hardware stop mode release counter, counts up to 780,000
logic   [19:0]      hstop_osc_wait;
logic               hstop_osc_unstable, hstop_osc_unstable_z;
always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        hstop_osc_unstable <= 1'b0;
        hstop_osc_unstable_z <= 1'b0;
    end
    else begin
        if(mcuclk_pcen) begin
            hstop_osc_unstable_z <= hstop_osc_unstable;

            if(stop_sync[1]) begin
                hstop_osc_unstable <= 1'b1;
            end
            else begin
                if(hstop_osc_wait == HARD_STOP_RELEASE_WAIT) begin
                    hstop_osc_unstable <= 1'b0;
                end
            end
        end
    end

    if(mcuclk_pcen) begin
        if(stop_sync) begin
            hstop_osc_wait <= 20'd0;
        end
        else begin
            if(hstop_osc_wait != HARD_STOP_RELEASE_WAIT) begin
                hstop_osc_wait <= hstop_osc_wait + 20'd1;
            end
        end
    end
end

//halt and stop, can be halt insturction without stopping chip's oscillator, this core will stop the timing generator
wire            release_soft_stop;
always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        halt_flag <= 1'b0;
        soft_stop_flag <= 1'b0;
        hard_stop_flag <= 1'b0;
    end
    else begin
        if(halt_flag) begin
            if(mcuclk_pcen) if((irq_lv != 3'd1) && (irq_lv != irq_lv_z)) halt_flag <= 1'b0;
        end
        else begin
            if(cycle_tick) if(soft_halt_det) halt_flag <= 1'b1;
        end
        
        if(soft_stop_flag) begin
            if(mcuclk_pcen) if(release_soft_stop) soft_stop_flag <= 1'b0;
        end
        else begin
            if(cycle_tick) if(soft_stop_det) soft_stop_flag <= 1'b1;
        end

        //According to the datasheet on page 178, if RST is asserted before the oscillator has stabilized,
        //the CPU core will start the program from 0x0000 without waiting for stabilization. I emulated that.
        if(hard_stop_flag) begin
            if(mcuclk_pcen) hard_stop_flag <= hstop_osc_unstable == 1'b0 && hstop_osc_unstable_z == 1'b1 ? 1'b0 : 1'b1; //release stop
        end
        else begin
            if(cycle_tick) if(mc_end_of_instruction) hard_stop_flag <= stop_sync[1];
        end
    end
end



///////////////////////////////////////////////////////////
//////  MICROCODE ENGINE
////

//opcode page indicator
always_ff @(posedge emuclk) begin
    if(!mrst_n) opcode_page <= 3'd0;
    else begin
        if(cycle_tick) if(mc_next_bus_acc == RD4) begin
            if(opcode_page == 3'd0) begin
                     if(reg_OPCODE == 8'h48) opcode_page <= 3'd1;
                else if(reg_OPCODE == 8'h60) opcode_page <= 3'd2;
                else if(reg_OPCODE == 8'h64) opcode_page <= 3'd3;
                else if(reg_OPCODE == 8'h70) opcode_page <= 3'd4;
                else if(reg_OPCODE == 8'h74) opcode_page <= 3'd5;
            end
            else begin
                opcode_page <= 3'd0; //2-byte opcode ended, reset opcode page
            end
        end
    end
end

//microsequencer
localparam WAIT_FOR_DECODING = 1'b0;
localparam RUNNING = 1'b1;
logic           deu_muldiv_busy;      //halt microsequencer 
logic           mseq_state;     //microsequencer state
logic   [2:0]   mseq_cntr;      //microsequencer counter, registered output
logic   [2:0]   mseq_cntr_next; //microsequencer counter, "next" combinational output
always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        mseq_state <= WAIT_FOR_DECODING;
        mseq_cntr <= 3'd0;
    end
    else begin
        if(mcrom_read_tick) begin
            if(cycle_tick) begin
                if(mc_next_bus_acc == RD4) begin
                    mseq_state <= WAIT_FOR_DECODING;
                    mseq_cntr <= mseq_cntr;
                end
                else begin
                    mseq_cntr <= mseq_cntr_next;
                end
            end
            else begin
                if(current_bus_acc == RD4 && mseq_state == WAIT_FOR_DECODING) begin
                    mseq_state <= RUNNING;
                    mseq_cntr <= mcrom_sa[2:0];
                end
            end
        end
    end
end

always_comb begin
    if(mc_type == MCTYPE3 && mc_t3_bra_on_alu != 3'd0 ) begin
        if(is_arith_eval_op || arith_code == 4'h0) mseq_cntr_next = mseq_cntr + mc_t3_bra_on_alu + 3'd1; //eval op + 00(move)
        else mseq_cntr_next = mseq_cntr + 3'd1;
    end
    else begin
        if(!deu_muldiv_busy) mseq_cntr_next = mseq_cntr + 3'd1;
        else mseq_cntr_next = mseq_cntr;
    end
end

logic   [7:0]   mcrom_addr;
always_comb begin
    if(mseq_state == WAIT_FOR_DECODING) mcrom_addr = mcrom_sa;
    else mcrom_addr = mc_end_of_instruction ? IRD : {mcrom_sa[7:3], mseq_cntr_next};
end



///////////////////////////////////////////////////////////
//////  MICROCODE ROM
////

IKA87AD_microcode u_microcode (
    .i_CLK                      (emuclk                     ),
    .i_MCROM_READ_TICK          (mcrom_read_tick            ),
    .i_MCROM_ADDR               (mcrom_addr                 ),
    .o_MCROM_DATA               (mcrom_data                 )
);

/*
    MICROCODE TYPE DESCRIPTION

    0. DATA EXECUTION CONTROL
    00_X_X_XXXX_XXXX_XXXX_XX

    D[17:16]: instruction type bit
    D[15]: FLAG bit
    D[14]: SKIP bit
    D[13:10] source
        0000: (b) r         
        0001: (b) r2
        0010: (b) r1
        0011: (w) rp2
        0100: (w) rp
        0101: (w) rp1
        0110: (b/w) SRTMP
        0111: (w) PSW
        1000: (w) MD(word, memory data high+low)
        1001: (b) MD0
        1010: 
        1011: (w) ALU aux register
        1100: (b) A
        1101:
        1110: (w) EA
        1111: 
    D[9:6] destination, decoded by the external circuit
        0000: (b) r         
        0001: (b) r2
        0010: (b) r1
        0011: (w) rp2
        0100: (w) rp
        0101: (w) rp1
        0110: (b/w) SRTMP
        0111: (w) PSW
        1000: (w) MD(word, memory data high+low)
        1001: (b) MD0
        1010: (b) MD1
        1011: 
        1100: (b) A 
        1101: (b) C 
        1110: (w) EA
        1111: (w) BC
    D[5:2] ALU operation type:
        0000: bypass
        0001: NEG
        0010: INC
        0011: DEC

        0100: ROT(decode 0x48 page ALU operations)
        0101: SHFT
        011X: DAA

        100X: MUL
        101X: DIV
        11XX: common ALU operations(bitwise/arithmetic)
    D[1:0] current bus transaction type :
        00: IDLE
        01: 3-state read
        10: 3-state write
        11: 4-state read

    *automatically decoded by external logic


    1. ADDRESS EXECUTION CONTROL
    01_X_X_XXXX_XXXX_XXXX_XX
    D[17:16]: instruction type bit
    D[15]: FLAG bit
    D[14]: SKIP bit
    D[13:10] source
        0000: (w) ADDR_TA
        0001: (w) ADDR_FA   
        0010: (w) ADDR_REL_S
        0011: (w) ADDR_REL_L
        0100: (w) *ADDR_INT, interrupt address, including software interrupt
        0101: (w) *RPA_OFFSET, rpa2/rpa3 A, B, EA, byte addend select
        0110: (w) RPA
        0111: (w) RPA2
        1000: (w/b) AAUX
        1001: 
        1010: (w) EA
        1011: (w) BC
        1100: (w) DE
        1101: (w) HL
        1110: (w) SP
        1111: (w) PC
    D[9:6] destination
        0110: (w) RPA
        1001: (w) MD
        1010: (w) MA
        1111: (w) PC 
    D[5:2] ALU operation type:
        0000: bypass
        0001: add
        0010: rpa increment/decrement
        0011: rpa3 increment
        0100: (-A)push operation on the bus: aeu out=A-1, ma out=A-1
        0101: (A+)pop operation on the bus: aeu out=A+1, ma out=A
        0110: double increment
        0111: decrement
        1000: conditional decrement
    D[1:0] current bus transaction type :
        00: IDLE
        01: 3-state read
        10: 3-state write
        11: 4-state read


    2. BOOKKEEPING OPERATION
    10_X_X_-_XXX_X_X_XX_X_XXX_XX
    D[17:16]: instruction type bit
    D[15]: FLAG bit
    D[14]: SKIP bit
    D[13]: reserved
    D[12:10]: address type select
        000: NOP
        001: IA(immediate address)
        010: WA(WA offset)
        011: OFF(rpa offset)
        100: SRNUM D[5:0]
        101: SR2NUM {D[7],D[2:0]}
        110: SR3NUM D[0]
        111: SR4NUM D[0]
    D[9]: CARRY MOD
    D[8]: INTERRUPT E/D
    D[7:6]: EXCHANGE
        00: NOP
        01: EXX
        10: EXA
        11: EXH
    D[5]: CPU control - suspension
    D[4:2]: SKIP control
        000: NOP
        001: reserved
        010: reserved
        011: BTST_WA
        100: SK
        101: SKN
        110: SKIT
        111: SKNIT
    D[1:0] current bus transaction type :
        00: IDLE
        01: 3-state read
        10: 3-state write
        11: 4-state read

    3. SPECIAL OPERATION
    11_X_X_-----_X_-_XXX_-_X_XX
    D[17:16]: instruction type bit
    D[15]: FLAG bit
    D[14]: SKIP bit
    D[13:7]: reserved
    D[6]: 1st cycle of 2-byte instruction
    D[5]: conditional PC decrement(BLOCK)
    D[4:2]: conditional branch on ALU type, branch+ steps
    D[1:0] current bus transaction type :
        00: IDLE
        01: 3-state read
        10: 3-state write
        11: 4-state read

    nop = 11_0_0_00000_0_0_000_0_0_XX
*/



///////////////////////////////////////////////////////////
//////  GPR RW ADDRESS REMAPPER
////

/*
    COMMON READ BUS

    aaa = register address
    w = word mode
    s = byte select (valid only if the w is 0)

    aaa w s
    000_0_0:   0   V (b) //GPRBUS_xV_b
    000_0_1:   0   A (b) //GPRBUS_xA_b
    000_1_X:   V   A (w) //GPRBUS_VA_w
    001_0_0:   0   B (b) //GPRBUS_xB_b
    001_0_1:   0   C (b) //GPRBUS_xC_b
    001_1_X:   B   C (w) //GPRBUS_BC_w
    010_0_0:   0   D (b) //GPRBUS_xD_b
    010_0_1:   0   E (b) //GPRBUS_xE_b
    010_1_X:   D   E (w) //GPRBUS_DE_w
    011_0_0:   0   H (b) //GPRBUS_xH_b
    011_0_1:   0   L (b) //GPRBUS_xL_b
    011_1_X:   H   L (w) //GPRBUS_HL_w
    10X_0_0:   0 EAH (b) //GPRBUS_EH_b
    10X_0_1:   0 EAL (b) //GPRBUS_EL_b
    10X_1_X:   E   A (w) //GPRBUS_EA_w
    11X_0_0:   0 SPH (b)
    11X_0_1:   0 SPL (b)
    11X_1_X:   S   P (w) //GPRBUS_SP_w
*/

//Type r decoder
function automatic logic [4:0] dec_gpr_r(input logic [2:0] opcode);
    case(opcode)
        3'b000: dec_gpr_r = GPRBUS_xV_b;
        3'b001: dec_gpr_r = GPRBUS_xA_b;
        3'b010: dec_gpr_r = GPRBUS_xB_b;
        3'b011: dec_gpr_r = GPRBUS_xC_b;
        3'b100: dec_gpr_r = GPRBUS_xD_b;
        3'b101: dec_gpr_r = GPRBUS_xE_b;
        3'b110: dec_gpr_r = GPRBUS_xH_b;
        3'b111: dec_gpr_r = GPRBUS_xL_b;
    endcase
endfunction

//Type r1 decoder
function automatic logic [4:0] dec_gpr_r1(input logic [2:0] opcode);
    case(opcode)
        3'b000: dec_gpr_r1 = GPRBUS_EH_b;
        3'b001: dec_gpr_r1 = GPRBUS_EL_b;
        3'b010: dec_gpr_r1 = GPRBUS_xB_b;
        3'b011: dec_gpr_r1 = GPRBUS_xC_b;
        3'b100: dec_gpr_r1 = GPRBUS_xD_b;
        3'b101: dec_gpr_r1 = GPRBUS_xE_b;
        3'b110: dec_gpr_r1 = GPRBUS_xH_b;
        3'b111: dec_gpr_r1 = GPRBUS_xL_b;
    endcase
endfunction

//Type r2 decoder
function automatic logic [4:0] dec_gpr_r2(input logic [1:0] opcode);
    case(opcode)
        2'b00: dec_gpr_r2 = GPRBUS_xV_b; //not specified
        2'b01: dec_gpr_r2 = GPRBUS_xA_b;
        2'b10: dec_gpr_r2 = GPRBUS_xB_b;
        2'b11: dec_gpr_r2 = GPRBUS_xC_b;
    endcase
endfunction

//Type rp2 decoder
function automatic logic [4:0] dec_gpr_rp2(input logic [6:4] opcode);
    case(opcode)
        3'b000:  dec_gpr_rp2 = GPRBUS_SP_w;
        3'b001:  dec_gpr_rp2 = GPRBUS_BC_w;
        3'b010:  dec_gpr_rp2 = GPRBUS_DE_w;
        3'b011:  dec_gpr_rp2 = GPRBUS_HL_w;
        3'b100:  dec_gpr_rp2 = GPRBUS_EA_w;
        default: dec_gpr_rp2 = GPRBUS_EA_w; //not specified
    endcase
endfunction

//Type rp1 decoder
function automatic logic [4:0] dec_gpr_rp1(input logic [2:0] opcode);
    case(opcode)
        3'b000:  dec_gpr_rp1 = GPRBUS_VA_w;
        3'b001:  dec_gpr_rp1 = GPRBUS_BC_w;
        3'b010:  dec_gpr_rp1 = GPRBUS_DE_w;
        3'b011:  dec_gpr_rp1 = GPRBUS_HL_w;
        3'b100:  dec_gpr_rp1 = GPRBUS_EA_w;
        default: dec_gpr_rp1 = GPRBUS_EA_w; //not specified
    endcase
endfunction

//Type rp decoder
function automatic logic [4:0] dec_gpr_rp(input logic [1:0] opcode);
    case(opcode)
        2'b00: dec_gpr_rp = GPRBUS_SP_w;
        2'b01: dec_gpr_rp = GPRBUS_BC_w;
        2'b10: dec_gpr_rp = GPRBUS_DE_w;
        2'b11: dec_gpr_rp = GPRBUS_HL_w;
    endcase
endfunction

//Type rpa decoder
function automatic logic [4:0] dec_gpr_rpa(input logic [2:0] opcode);
    case(opcode)
        3'b000:  dec_gpr_rpa = GPRBUS_VA_w; //not specified
        3'b001:  dec_gpr_rpa = GPRBUS_BC_w;
        3'b010:  dec_gpr_rpa = GPRBUS_DE_w;
        3'b011:  dec_gpr_rpa = GPRBUS_HL_w;
        3'b100:  dec_gpr_rpa = GPRBUS_DE_w;
        3'b101:  dec_gpr_rpa = GPRBUS_HL_w;
        3'b110:  dec_gpr_rpa = GPRBUS_DE_w;
        3'b111:  dec_gpr_rpa = GPRBUS_HL_w;
    endcase
endfunction

//Type rpa2 decoder
function automatic logic [4:0] dec_gpr_rpa2(input logic [2:0] opcode);
    case(opcode)
        3'b011:  dec_gpr_rpa2 = GPRBUS_DE_w;
        3'b100:  dec_gpr_rpa2 = GPRBUS_HL_w;
        3'b101:  dec_gpr_rpa2 = GPRBUS_HL_w;
        3'b110:  dec_gpr_rpa2 = GPRBUS_HL_w;
        3'b111:  dec_gpr_rpa2 = GPRBUS_HL_w;
        default: dec_gpr_rpa2 = GPRBUS_DE_w; //not specified
    endcase
endfunction

//Type rpa2 offset decoder
function automatic logic [4:0] dec_gpr_rpa2_offset(input logic [1:0] opcode);
    case(opcode)
        2'b00:   dec_gpr_rpa2_offset = GPRBUS_xA_b;
        2'b01:   dec_gpr_rpa2_offset = GPRBUS_xB_b;
        2'b10:   dec_gpr_rpa2_offset = GPRBUS_EA_w;
        default: dec_gpr_rpa2_offset = GPRBUS_EA_w; //not specified
    endcase
endfunction

//GPR rw address
logic   [4:0]   gpr_rw_addr;
always_comb begin
    gpr_rw_addr = 5'h1F; //SP word

    if(mc_type == MCTYPE0) begin
        //GPR output can be routed to only one ALU port
        //To avoid hardware interlocks, uCode guarantees there are no collisions
        //Direct DST/SRC assignments to A and EA use separate A/EA read buses
        //unique if
             if(mc_t0_dst == T0_DST_R || mc_t0_src == T0_SRC_R)
            gpr_rw_addr = dec_gpr_r(reg_OPCODE[2:0]);
        else if(mc_t0_dst == T0_DST_R2 || mc_t0_src == T0_SRC_R2)
            gpr_rw_addr = dec_gpr_r2(reg_OPCODE[1:0]);
        else if(mc_t0_dst == T0_DST_R1 || mc_t0_src == T0_SRC_R1)
            gpr_rw_addr = dec_gpr_r1(reg_OPCODE[2:0]);
        else if(mc_t0_dst == T0_DST_RP2 || mc_t0_src == T0_SRC_RP2)
            gpr_rw_addr = dec_gpr_rp2(reg_OPCODE[6:4]);
        else if(mc_t0_dst == T0_DST_RP || mc_t0_src == T0_SRC_RP)
            gpr_rw_addr = dec_gpr_rp(reg_OPCODE[1:0]);
        else if(mc_t0_dst == T0_DST_RP1 || mc_t0_src == T0_SRC_RP1)
            gpr_rw_addr = dec_gpr_rp1(reg_OPCODE[2:0]);
        else if(mc_t0_dst == T0_DST_C)
            gpr_rw_addr = GPRBUS_xC_b;
        else if(mc_t0_dst == T0_DST_BC)
            gpr_rw_addr = GPRBUS_BC_w;
        else
            gpr_rw_addr = 5'h1F;
    end
    else if(mc_type == MCTYPE1) begin
        //unique if
             if(mc_t1_src == T1_SRC_RPA_OFFSET)
            gpr_rw_addr = dec_gpr_rpa2_offset(reg_OPCODE[1:0]);
        else if(mc_t1_dst == T1_DST_RPA || mc_t1_src == T1_SRC_RPA)
            gpr_rw_addr = dec_gpr_rpa(reg_OPCODE[2:0]);
        else if(mc_t1_src == T1_SRC_RPA2)
            gpr_rw_addr = dec_gpr_rpa2(reg_OPCODE[2:0]);
        else if(mc_t1_src == T1_SRC_EA)
            gpr_rw_addr = GPRBUS_EA_w;
        else if(mc_t1_src == T1_SRC_BC)
            gpr_rw_addr = GPRBUS_BC_w;
        else if(mc_t1_src == T1_SRC_DE)
            gpr_rw_addr = GPRBUS_DE_w;
        else if(mc_t1_src == T1_SRC_HL)
            gpr_rw_addr = GPRBUS_HL_w;
        else if(mc_t1_src == T1_SRC_SP)
            gpr_rw_addr = GPRBUS_SP_w;
        else
            gpr_rw_addr = 5'h1F;
    end
end



///////////////////////////////////////////////////////////
//////  REGISTER WRITE ENABLES
////

//GPR write: write enables
logic           is_dst_gpr;  //when one of the GPR is selected as a destination...
logic           is_padj;     //when the current AEU command is post-adjust(inc/dec)...
logic           is_push_pop; //when AEU is running push/pop operation...
always_comb begin
    is_dst_gpr = 1'b0;
    if(mc_type == MCTYPE0) begin
        if(mc_t0_dst == T0_DST_R   || mc_t0_dst == T0_DST_R2 || mc_t0_dst == T0_DST_R1  ||
           mc_t0_dst == T0_DST_RP2 || mc_t0_dst == T0_DST_RP || mc_t0_dst == T0_DST_RP1 ||
           mc_t0_dst == T0_DST_C   || mc_t0_dst == T0_DST_BC)
            is_dst_gpr = 1'b1;
    end
    else if(mc_type == MCTYPE1) begin
        if(mc_t1_dst == T1_DST_RPA)
            is_dst_gpr = 1'b1;
    end

    is_padj = mc_type == MCTYPE1 && (mc_t1_aeu_op == T1_AEU_PINC || mc_t1_aeu_op == T1_AEU_RPA_ADJ || mc_t1_aeu_op == T1_AEU_RPA3_ADJ);
    is_push_pop = mc_type == MCTYPE1 && mc_t1_src == T1_SRC_SP && (mc_t1_aeu_op == T1_AEU_PUSH || mc_t1_aeu_op == T1_AEU_POP);
end

//general purpose registers
wire            reg_V_wr    = (is_dst_gpr && (gpr_rw_addr == GPRBUS_VA_w || gpr_rw_addr == GPRBUS_xV_b));

wire            reg_B_wr    = (is_dst_gpr && (gpr_rw_addr == GPRBUS_BC_w || gpr_rw_addr == GPRBUS_xB_b)) ||
                              (is_padj    &&  gpr_rw_addr == GPRBUS_BC_w);
wire            reg_C_wr    = (is_dst_gpr && (gpr_rw_addr == GPRBUS_BC_w || gpr_rw_addr == GPRBUS_xC_b)) ||
                              (is_padj    &&  gpr_rw_addr == GPRBUS_BC_w);
wire            reg_D_wr    = (is_dst_gpr && (gpr_rw_addr == GPRBUS_DE_w || gpr_rw_addr == GPRBUS_xD_b)) ||
                              (is_padj    &&  gpr_rw_addr == GPRBUS_DE_w);
wire            reg_E_wr    = (is_dst_gpr && (gpr_rw_addr == GPRBUS_DE_w || gpr_rw_addr == GPRBUS_xE_b)) ||
                              (is_padj    &&  gpr_rw_addr == GPRBUS_DE_w);
wire            reg_H_wr    = (is_dst_gpr && (gpr_rw_addr == GPRBUS_HL_w || gpr_rw_addr == GPRBUS_xH_b)) ||
                              (is_padj    &&  gpr_rw_addr == GPRBUS_HL_w);
wire            reg_L_wr    = (is_dst_gpr && (gpr_rw_addr == GPRBUS_HL_w || gpr_rw_addr == GPRBUS_xL_b)) ||
                              (is_padj    &&  gpr_rw_addr == GPRBUS_HL_w);

//special cases(including accumulators)
logic           deu_muldiv_ea_wr;

wire            reg_A_wr    = (is_dst_gpr && (gpr_rw_addr == GPRBUS_VA_w || gpr_rw_addr == GPRBUS_xA_b)) ||
                              (mc_type == MCTYPE0 && mc_t0_dst == T0_DST_A);
wire            reg_EAL_wr  = (is_dst_gpr && (gpr_rw_addr == GPRBUS_EA_w || gpr_rw_addr == GPRBUS_EL_b)) ||
                              (mc_type == MCTYPE0 && mc_t0_dst == T0_DST_EA) ||
                               deu_muldiv_ea_wr;
wire            reg_EAH_wr  = (is_dst_gpr && (gpr_rw_addr == GPRBUS_EA_w || gpr_rw_addr == GPRBUS_EH_b)) ||
                              (mc_type == MCTYPE0 && mc_t0_dst == T0_DST_EA) ||
                               deu_muldiv_ea_wr;
wire            reg_SP_wr   = (is_dst_gpr  && (gpr_rw_addr == GPRBUS_SP_w)) ||
                              (is_push_pop &&  gpr_rw_addr == GPRBUS_SP_w);

//PC write
wire            reg_PC_wr   = (mc_type == MCTYPE1 && mc_t1_dst == T1_DST_PC);

//special register write
wire            reg_SRTMP_wr= (mc_type == MCTYPE0 && mc_t0_dst == T0_DST_SRTMP);

//status register(flag restoration)
wire            reg_PSW_wr  = (mc_type == MCTYPE0 && mc_t0_dst == T0_DST_PSW);

//Bus related registers, MA=Memory Address, MD=Memory Data
wire            reg_MA_wr   = (mc_type == MCTYPE1 && mc_t1_dst == T1_DST_MA);

//T0_DST_MDR is a word write to MD like T0_DST_MD, but with the two bytes
//exchanged; see the MD IO control block below.
wire            md_wr_swap  = (mc_type == MCTYPE0 && mc_t0_dst == T0_DST_MDR);

wire            reg_MD0_wr  = (mc_type == MCTYPE0 && mc_t0_dst == T0_DST_MD ||
                               mc_type == MCTYPE0 && mc_t0_dst == T0_DST_MDR ||
                               mc_type == MCTYPE0 && mc_t0_dst == T0_DST_MD0 ||
                               mc_type == MCTYPE1 && mc_t1_dst == T1_DST_MD);
wire            reg_MD1_wr  = (mc_type == MCTYPE0 && mc_t0_dst == T0_DST_MD ||
                               mc_type == MCTYPE0 && mc_t0_dst == T0_DST_MDR ||
                               mc_type == MCTYPE0 && mc_t0_dst == T0_DST_MD1 ||
                               mc_type == MCTYPE1 && mc_t1_dst == T1_DST_MD);



///////////////////////////////////////////////////////////
//////  DEU/AEU CONTROL/OUTPUT
////

//DEU output
logic   [15:0]  deu_output; //ALU output
logic   [15:0]  deu_aux_output; //ALU temp register


//DEU control
wire            deu_mul_start = mc_type == MCTYPE0 && mc_t0_deu_op == T0_DEU_MUL;
wire            deu_div_start = mc_type == MCTYPE0 && mc_t0_deu_op == T0_DEU_DIV;

//Data Execution Unit data size flag
wire            deu_dsize  = (is_dst_gpr && (gpr_rw_addr[1])) || //word/byte select
                             (mc_type == MCTYPE0 && mc_t0_dst == T0_DST_EA)  ||
                             (mc_type == MCTYPE0 && mc_t0_dst == T0_DST_MD)  ||
                             (mc_type == MCTYPE0 && mc_t0_dst == T0_DST_MDR) ||
                             deu_muldiv_ea_wr;

//AEU output
logic   [15:0]  aeu_output, aeu_ma_output;




///////////////////////////////////////////////////////////
//////  GENERAL PURPOSE REGISTERS
////

logic   [15:0]  gpr_RDBUS;
logic   [15:0]  gpr_WRBUS;

//register pair select switch
logic           flag_EXX, flag_EXA, flag_EXH;
wire            sel_BCDE = flag_EXX;
wire            sel_VAEA = flag_EXA;
wire            sel_HL = flag_EXX ^ flag_EXH;
always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        flag_EXX <= 1'b0;
        flag_EXA <= 1'b0;
        flag_EXH <= 1'b0;
    end
    else begin if(cycle_tick) begin
        if(mc_type == MCTYPE2)
            case(mc_t2_reg_exchg)
                2'b00: ;
                2'b01: flag_EXX <= ~flag_EXX;
                2'b10: flag_EXA <= ~flag_EXA;
                2'b11: flag_EXH <= ~flag_EXH;
            endcase
    end end
end

//register pairs and write control
logic   [7:0]   regpair_EAH[0:1], regpair_EAL[0:1], 
                regpair_V[0:1]  , regpair_A[0:1]  , 
                regpair_B[0:1]  , regpair_C[0:1]  ,
                regpair_D[0:1]  , regpair_E[0:1]  , 
                regpair_H[0:1]  , regpair_L[0:1]  ;
always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        ////GPRs remain in undefined status after reset
        //regpair_EAH[0] <= 8'h00; regpair_EAH[1] <= 8'h00;
        //regpair_EAL[0] <= 8'h00; regpair_EAL[1] <= 8'h00;
        //regpair_V[0]   <= 8'h00; regpair_V[1]   <= 8'h00;
        //regpair_A[0]   <= 8'h00; regpair_A[1]   <= 8'h00;
        //regpair_B[0]   <= 8'h00; regpair_B[1]   <= 8'h00;
        //regpair_C[0]   <= 8'h00; regpair_C[1]   <= 8'h00;
        //regpair_D[0]   <= 8'h00; regpair_D[1]   <= 8'h00;
        //regpair_E[0]   <= 8'h00; regpair_E[1]   <= 8'h00;
        //regpair_H[0]   <= 8'h00; regpair_H[1]   <= 8'h00;
        //regpair_L[0]   <= 8'h00; regpair_L[1]   <= 8'h00;
    end
    else begin
        if(cycle_tick) begin
            if(reg_EAH_wr) regpair_EAH[sel_VAEA] <= gpr_WRBUS[15:8];
            if(reg_EAL_wr) regpair_EAL[sel_VAEA] <= gpr_WRBUS[ 7:0];
            if(reg_V_wr)   regpair_V[sel_VAEA]   <= gpr_WRBUS[15:8];
            if(reg_A_wr)   regpair_A[sel_VAEA]   <= gpr_WRBUS[ 7:0];
            if(reg_B_wr)   regpair_B[sel_BCDE]   <= gpr_WRBUS[15:8];
            if(reg_C_wr)   regpair_C[sel_BCDE]   <= gpr_WRBUS[ 7:0];
            if(reg_D_wr)   regpair_D[sel_BCDE]   <= gpr_WRBUS[15:8];
            if(reg_E_wr)   regpair_E[sel_BCDE]   <= gpr_WRBUS[ 7:0];
            if(reg_H_wr)   regpair_H[sel_HL]     <= gpr_WRBUS[15:8];
            if(reg_L_wr)   regpair_L[sel_HL]     <= gpr_WRBUS[ 7:0];
        end
    end
end

//register pair output selectors
wire    [7:0]   reg_EAH = regpair_EAH[sel_VAEA];
wire    [7:0]   reg_EAL = regpair_EAL[sel_VAEA]; 
wire    [7:0]   reg_V = regpair_V[sel_VAEA]; 
wire    [7:0]   reg_A = regpair_A[sel_VAEA]; 
wire    [7:0]   reg_B = regpair_B[sel_BCDE]; 
wire    [7:0]   reg_C = regpair_C[sel_BCDE]; 
wire    [7:0]   reg_D = regpair_D[sel_BCDE]; 
wire    [7:0]   reg_E = regpair_E[sel_BCDE]; 
wire    [7:0]   reg_H = regpair_H[sel_HL]; 
wire    [7:0]   reg_L = regpair_L[sel_HL];



///////////////////////////////////////////////////////////
//////  PC/SP/MA
////

//PC, SP, MA registers with auto increment/decrement feature
logic   [15:0]  reg_PC, reg_SP, reg_MA;
logic           pc_hold, sp_autocnt;
logic   [15:0]  next_pc;
assign  spurious_irq_addr = reg_PC;

//address source selector
logic   [1:0]   ao_src;
wire    [15:0]  ao = ao_src[1] ? (ao_src[0] ? reg_MA : reg_SP) : reg_PC;

//this block defines the operation of the PC/MA registers
always_ff @(posedge emuclk) begin
    //ADDRESS OUTPUT SOURCE SELECT
    if(!mrst_n) begin
        ao_src <= PC;
        pc_hold <= 1'b0;
        sp_autocnt <= 1'b0;
    end
    else begin if(cycle_tick) begin
        if(mc_end_of_instruction) begin
            ao_src <= PC;
            pc_hold <= 1'b0;
            sp_autocnt <= 1'b0;
        end
        else begin
            if(reg_MA_wr) begin
                ao_src <= (is_push_pop) ? SP : MA;
                pc_hold <= 1'b1;
                sp_autocnt <= is_push_pop;
            end
            else if(mc_next_bus_acc == IDLE) pc_hold <= 1'b1;
        end end
    end

    //REGISTERS
    if(!mrst_n) begin
        reg_PC <= 16'hFFFF;
        reg_SP <= 16'h0000; //undefined after reset
        reg_MA <= 16'h0000;
    end
    else begin
        if(cycle_tick) begin
            //Program Counter load/auto increment conditions
            if(reg_PC_wr) reg_PC <= aeu_output;
            else reg_PC <= next_pc;

            //Stack Pointer load condition
            if(reg_SP_wr) reg_SP <= mc_type == MCTYPE1 ? aeu_output : deu_output;
            else begin
                if(sp_autocnt) begin
                    //unique if
                           if(current_bus_acc == RD3) reg_SP <= reg_SP + 16'h0001;
                      else if(mc_next_bus_acc == WR3) reg_SP <= reg_SP - 16'h0001;
                      else                            reg_SP <= reg_SP;
                end
            end

            //Memory Address load/auto inc conditions
            if(reg_MA_wr) reg_MA <= aeu_ma_output;
            else begin
                if(current_bus_acc == RD3 || current_bus_acc == WR3) begin //if there was a 3cyc read/write access,
                    if(ao_src == MA) reg_MA <= reg_MA == 16'hFFFF ? 16'h0000 : reg_MA + 16'h0001;
                    else reg_MA <= reg_MA;
                end
                else reg_MA <= reg_MA;
            end
        end
        else if(opcode_inlatch_tick) begin
            reg_MA <= reg_PC;
        end
    end
end

always_comb begin
    if(pc_hold) begin
        if(mc_type == MCTYPE3 && mc_t3_cond_pc_dec && reg_C != 8'hFF) next_pc = reg_PC - 16'h0001;
        else next_pc = reg_PC;
    end
    else begin
        if(force_exec_hardi | force_exec_nop) next_pc = reg_PC;
        else begin
            if(current_bus_acc == RD4 || current_bus_acc == RD3) next_pc = reg_PC + 16'h0001;
            else next_pc = reg_PC;
        end
    end
end

//Arbitrarily made registers: unsure the original chip has them
logic   [7:0]   reg_MD[0:3]; //memory data
always_comb reg_MD[2] = 8'h00; //unused addresses
always_comb reg_MD[3] = 8'h00;

logic   [15:0]  reg_DAUX; //DEU DIV aux
logic   [15:0]  reg_AAUX; //AEU aux

//Processor Status Word flags
logic           flag_Z, flag_SK, flag_C, flag_HC, flag_L1, flag_L0;
wire    [7:0]   reg_PSW = {1'b0, flag_Z, flag_SK, flag_HC, flag_L1, flag_L0, 1'b0, flag_C};



///////////////////////////////////////////////////////////
//////  GPR READ AND WRITE BUS
////

//read bus
always_comb begin
    casez(gpr_rw_addr)
        5'b000_0_0: gpr_RDBUS = {8'h00, reg_V};
        5'b000_0_1: gpr_RDBUS = {8'h00, reg_A};
        5'b000_1_?: gpr_RDBUS = {reg_V, reg_A};
        5'b001_0_0: gpr_RDBUS = {8'h00, reg_B};
        5'b001_0_1: gpr_RDBUS = {8'h00, reg_C};
        5'b001_1_?: gpr_RDBUS = {reg_B, reg_C};
        5'b010_0_0: gpr_RDBUS = {8'h00, reg_D};
        5'b010_0_1: gpr_RDBUS = {8'h00, reg_E};
        5'b010_1_?: gpr_RDBUS = {reg_D, reg_E};
        5'b011_0_0: gpr_RDBUS = {8'h00, reg_H};
        5'b011_0_1: gpr_RDBUS = {8'h00, reg_L};
        5'b011_1_?: gpr_RDBUS = {reg_H, reg_L};
        5'b10?_0_0: gpr_RDBUS = {8'h00, reg_EAH};
        5'b10?_0_1: gpr_RDBUS = {8'h00, reg_EAL};
        5'b10?_1_?: gpr_RDBUS = {reg_EAH, reg_EAL};
        5'b11?_0_0: gpr_RDBUS = {8'h00, reg_SP[15:8]};
        5'b11?_0_1: gpr_RDBUS = {8'h00, reg_SP[7:0]};
        5'b11?_1_?: gpr_RDBUS = {reg_SP};  
        default:    gpr_RDBUS = 16'h0000; //unreachable: the cases above cover all 32 encodings
    endcase
end

//write bus
always_comb begin
         if(mc_type == MCTYPE0) gpr_WRBUS = deu_dsize ? deu_output : {2{deu_output[7:0]}};
    else if(mc_type == MCTYPE1) gpr_WRBUS = aeu_output;
    else                        gpr_WRBUS = deu_output;
end




///////////////////////////////////////////////////////////
//////  SPECIAL REGISTERS
////

/*
    SPECIAL REGISTER LIST

    rw 0x00 PA   - port A rw data
    rw 0x01 PB   - port B rw data
    rw 0x02 PC   - port C rw data
    rw 0x03 PD   - port D rw data
    rw 0x05 PF   - port F rw data
     w 0x06 MKH  - Mask High(D[7:1])
     w 0x07 MKL  - Mask Low(D[1:0])
    rw 0x08 ANM  - ADC Mode(D[4:0], 0x00 after reset)
    rw 0x09 SMH  - Serial Mode High(0x00 after reset) 
     w 0x0A SML  - Serial Mode Low(0x48 after reset)
    rw 0x0B EOM  - Timer/event counter output mode
     w 0x0C ETMM - Timer/event counter mode
    rw 0x0D TMM  - Timer mode
     w 0x10 MM   - Memory mapping(piggyback model only)
     w 0x11 MCC  - Mode control C register
     w 0x12 MA   - port A direction
     w 0x13 MB   - port B direction
     w 0x14 MC   - port C direction
     w 0x17 MF   - port F direction
     w 0x18 TXB  - tx buffer
    r  0x19 RXB  - rx buffer
     w 0x1A TM0  - timer A register
     w 0x1B TM1  - timer B register
    r  0x20 CR0  - conversion result 0
    r  0x21 CR1  - conversion result 1
    r  0x22 CR2  - conversion result 2
    r  0x23 CR3  - conversion result 3
     w 0x28 ZCM  - zero crossing detector mode
    
    <----register here can't be accessed by sr/sr1/sr2 fields---->
     w 0x30 ETM0 - event counter register 0
     w 0x31 ETM1 - event counter register 1
    r  0x32 ECNT - event counter
    r  0x33 ECPT - event counter capture register
*/

logic   [5:0]   spr_rw_addr; //special register address
logic   [15:0]  reg_SRTMP; //special register data temporary

logic   [7:0]   spr_PAO, spr_PBO, spr_PCO, spr_PDO, spr_PFO; //port related registers, undefined after reset, see page 180
logic   [7:0]   spr_MA, spr_MB, spr_MC, spr_MF, spr_MM, spr_MCC;

logic   [6:0]   spr_MKL; //intrq disable register low ; ncntrcin, cntr1, cntr0, pint1, nint2, timer1, timer0, -
logic   [2:0]   spr_MKH; //intrq disable register high; -, -, -, -, -, empty, full, adc

logic   [4:0]   spr_ANM; //ADC settings

//logic   [7:0]   spr_SMH, spr_SML; //serial interface settings
//logic   [1:0]   spr_ZCM; //zero crossing detector bias mode select

logic   [7:0]   spr_EOM;
logic   [7:0]   spr_ETMM;
logic   [7:0]   spr_TMM;
logic   [7:0]   spr_TM0, spr_TM1; //undefined after reset, see page 180

logic   [15:0]  spr_ETM0, spr_ETM1; //undefined after reset, see page 180

logic   [7:0]   spr_CR[0:3];

function automatic logic [7:0] di_masked(input logic [7:0] i, o, oe);
    int b;
    for(b=0;b<8;b++) di_masked[b] = oe[b] ? o[b] : i[b];
endfunction

//temporary special purpose register
always_ff @(posedge emuclk) if(cycle_tick) begin
    case(spr_rw_addr) 
        6'h00: reg_SRTMP <= {8'h00, di_masked(i_PA_I, o_PA_O, o_PA_OE)};
        6'h01: reg_SRTMP <= {8'h00, di_masked(i_PB_I, o_PB_O, o_PB_OE)};
        6'h02: reg_SRTMP <= {8'h00, di_masked(i_PC_I, o_PC_O, o_PC_OE)};
        6'h03: reg_SRTMP <= {8'h00, di_masked(i_PD_I, o_PD_O, {8{o_PD_OE}})}; 
        6'h05: reg_SRTMP <= {8'h00, di_masked(i_PF_I, o_PF_O, o_PF_OE)};
        6'h08: reg_SRTMP <= {8'h00, {3'b000, spr_ANM}};
        //6'h09: reg_SRTMP <= {8'h00, spr_SMH};
        6'h0B: reg_SRTMP <= {8'h00, spr_EOM};
        6'h0D: reg_SRTMP <= {8'h00, spr_TMM};
        6'h19: reg_SRTMP <= {8'h00, 8'h00}; //RxB, not implemented
        6'h20: reg_SRTMP <= {8'h00, spr_CR[0]};
        6'h21: reg_SRTMP <= {8'h00, spr_CR[1]};
        6'h22: reg_SRTMP <= {8'h00, spr_CR[2]};
        6'h23: reg_SRTMP <= {8'h00, spr_CR[3]};
        6'h32: reg_SRTMP <= 16'h0000; //ECNT, not yet implemented
        6'h33: reg_SRTMP <= 16'h0000; //ECPT, not yet implemented
        default: reg_SRTMP <= 16'h0000;
    endcase
end

//write to SPR
always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        spr_PAO <= 8'h00; spr_PBO <= 8'h00; spr_PCO <= 8'h00; spr_PDO <= 8'h00; spr_PFO <= 8'h00;
        spr_MA  <= 8'hFF; spr_MB  <= 8'hFF; spr_MC  <= 8'hFF; spr_MF  <= 8'hFF; spr_MM  <= 8'h00;
        spr_MCC <= 8'h00;
        spr_MKL <= 7'b1111111; spr_MKH <= 3'b111;
        spr_ANM <= 5'h00;
        //spr_SMH <= 8'h00; spr_SML <= 8'h48;
        spr_EOM <= 8'h00;
        spr_ETMM <= 8'h00;
        spr_TMM <= 8'hFF;
        spr_TM0 <= 8'h00; spr_TM1 <= 8'h00; //see page 79
        //spr_ZCM <= 2'b11; //see page 59
        spr_ETM0 <= 16'h0000; spr_ETM1 <= 16'h0000;
    end
    else begin 
        if(cycle_tick) if(reg_SRTMP_wr)
            case(spr_rw_addr) 
                6'h00: spr_PAO  <= gpr_WRBUS[7:0];
                6'h01: spr_PBO  <= gpr_WRBUS[7:0];
                6'h02: spr_PCO  <= gpr_WRBUS[7:0];
                6'h03: spr_PDO  <= gpr_WRBUS[7:0];
                6'h05: spr_PFO  <= gpr_WRBUS[7:0];
                6'h06: spr_MKH  <= gpr_WRBUS[2:0];
                6'h07: spr_MKL  <= gpr_WRBUS[7:1];
                6'h08: spr_ANM  <= gpr_WRBUS[4:0];
                //6'h09: spr_SMH <= gpr_WRBUS[7:0];
                //6'h0A: spr_SML <= gpr_WRBUS[7:0];
                6'h0B: spr_EOM  <= gpr_WRBUS[7:0];
                6'h0C: spr_ETMM <= gpr_WRBUS[7:0];
                6'h0D: spr_TMM  <= gpr_WRBUS[7:0];
                6'h10: spr_MM   <= gpr_WRBUS[7:0];
                6'h11: spr_MCC  <= gpr_WRBUS[7:0];
                6'h12: spr_MA   <= gpr_WRBUS[7:0];
                6'h13: spr_MB   <= gpr_WRBUS[7:0];
                6'h14: spr_MC   <= gpr_WRBUS[7:0];
                6'h17: spr_MF   <= gpr_WRBUS[7:0];
                //6'h18: ; //TxB, not implemented
                6'h1A: spr_TM0  <= gpr_WRBUS[7:0];
                6'h1B: spr_TM1  <= gpr_WRBUS[7:0];
                //6'h28: spr_ZCM <= gpr_WRBUS[2:1];
                6'h30: spr_ETM0 <= gpr_WRBUS[15:0];
                6'h31: spr_ETM1 <= gpr_WRBUS[15:0];
                default: ;
            endcase  
        else if(mcuclk_pcen) begin
            if(release_soft_stop) spr_TMM <= 8'hFF;
        end
    end
end

assign irq_mask_n = ~{spr_MKH, spr_MKL, 1'b0};
assign o_REG_MM = spr_MM;
assign o_REG_MCC = spr_MCC;



///////////////////////////////////////////////////////////
//////  BUS CONTROLLER
////

//multiplexed addr/data selector
logic           addr_data_sel;
assign o_D_nA_SEL = addr_data_sel;
always_ff @(posedge emuclk) begin
    if(!mrst_n) addr_data_sel <= 1'b0; //reset
    else begin
        if(cycle_tick) addr_data_sel <= 1'b0; //reset
        else begin
            if(current_bus_acc != IDLE) if(timing_sr[2]) addr_data_sel <= 1'b1;
        end
    end
end

//opcode latch
always_ff @(posedge emuclk) begin
    if(!mrst_n) reg_OPCODE <= 8'h00;
    else begin
        //Opcode register load
        if(opcode_inlatch_tick) begin
                 if(force_exec_hardi) reg_OPCODE <= 8'h73;
            else if(force_exec_nop)   reg_OPCODE <= 8'h00;
            else                      reg_OPCODE <= i_DI;
        end
    
        //Full opcode register for the disassembler
        if(cycle_tick) begin if(mc_end_of_instruction) reg_FULL_OPCODE_cntr <= 2'd0; end
        else if(full_opcode_inlatch_tick_debug) begin
            reg_FULL_OPCODE_debug[reg_FULL_OPCODE_cntr] <= force_exec_hardi ? 8'h73 : i_DI;
            reg_FULL_OPCODE_cntr <= reg_FULL_OPCODE_cntr + 2'd1;
        end
    end
end

//Memory Data(MD) IO control
/*
    Writes to the MD register operate like a stack. Any data coming from the
    DEU/AEU or the external bus is pushed on top of the previously stored data.

        DOUT   <-  MAX TOS
        MD[1]         ^  (push/write)
        MD[0]  <-  TOS (reset after the current instruction completes)

    A word write therefore drives MD[1](the high byte) onto the bus first. That
    is what PUSH/CALL/SOFTI want, because they write down the stack: high byte
    at SP-1, then low byte at SP-2. Stores that walk *up* through memory need the
    opposite order((word)<-low, (word+1)<-high), so their microcode selects
    T0_DST_MDR, which loads the two halves exchanged.
*/

logic   [1:0]   md_tos; //top of the stack
logic   [2:0]   aaux_we; //immediate address latching sequence
logic   [1:0]   spr_atype; //special register address type

//continuous assignment
always_comb aaux_we[0] = mc_type == MCTYPE2 && mc_t2_atype_sel == T2_ATYPE_WORD;

always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        md_tos <= 2'd0;
        aaux_we[2:1] <= 2'b00;
        spr_atype <= 2'b00;
    end
    else begin
        //unique if
        if(cycle_tick) begin
            if(mc_end_of_instruction) begin
                md_tos <= 2'd0;
                aaux_we[2:1] <= 2'b00;
            end
            else begin
                //poke aaux at every microcode cycle
                aaux_we[1] <= (mc_type == MCTYPE2 && mc_t2_atype_sel == T2_ATYPE_BYTE) ||
                              (mc_type == MCTYPE2 && mc_t2_atype_sel == T2_ATYPE_IRO) ||
                              (mc_type == MCTYPE2 && mc_t2_atype_sel == T2_ATYPE_SR);
                aaux_we[2] <= aaux_we[0];

                //update special purpose register address decode type
                if(mc_type == MCTYPE2 && mc_t2_atype_sel >= T2_ATYPE_SR) spr_atype <= mc_t2_atype_sel[1:0];
                
                if(current_bus_acc != WR3) begin
                    //all MD registers are working individually
                    if(reg_MD1_wr) reg_MD[1] <= md_wr_swap ? gpr_WRBUS[7:0]  : gpr_WRBUS[15:8];
                    if(reg_MD0_wr) reg_MD[0] <= md_wr_swap ? gpr_WRBUS[15:8] : gpr_WRBUS[7:0];

                    //give it a priority
                         if(reg_MD1_wr) md_tos <= 2'd2;
                    else if(reg_MD0_wr) md_tos <= 2'd1;
                end
                else begin
                    md_tos <= md_tos - 2'd1;
                end
            end
        end
        else if(md_outlatch_tick) begin
            //all MD registers are working individually
            if(reg_MD1_wr) reg_MD[1] <= md_wr_swap ? gpr_WRBUS[7:0]  : gpr_WRBUS[15:8];
            if(reg_MD0_wr) reg_MD[0] <= md_wr_swap ? gpr_WRBUS[15:8] : gpr_WRBUS[7:0];

            //give it a priority
                 if(reg_MD1_wr) md_tos <= 2'd2;
            else if(reg_MD0_wr) md_tos <= 2'd1;
        end
        else if(md_inlatch_tick) begin
            //latch the bus data only when the current data type is NOT specified
            if(aaux_we == 3'b000)
                case(md_tos)
                    2'd0: begin reg_MD[0] <= i_DI; md_tos <= md_tos + 2'd1; end
                    2'd1: begin reg_MD[1] <= i_DI; md_tos <= md_tos + 2'd1; end
                    2'd2:                          md_tos <= md_tos;
                    2'd3:                          md_tos <= md_tos;
                endcase
            else
                case(aaux_we)
                    3'b001:  begin reg_AAUX[7:0] <= i_DI; reg_AAUX[15:8] <= reg_V; end
                    3'b010:  begin reg_AAUX[7:0] <= i_DI; reg_AAUX[15:8] <= reg_V; end
                    3'b100:  begin                        reg_AAUX[15:8] <= i_DI;  end
                    default: begin reg_AAUX <= reg_AAUX; end
                endcase
        end
        else ; //make sure the unique-if statement convers all possible conditions
    end
end

//special register address
always_comb begin
    case(spr_atype)
        2'b00 : spr_rw_addr = reg_AAUX[5:0];
        2'b01 : spr_rw_addr = {2'b00, reg_OPCODE[7], reg_OPCODE[2:0]};
        2'b10 : spr_rw_addr = {5'b11000, reg_OPCODE[0]};
        2'b11 : spr_rw_addr = {5'b11001, reg_OPCODE[0]};
    endcase
end

//full data output
wire    [7:0]   md_out_byte_data = reg_MD[md_tos - 2'd1];

//address high, multiplexed address low/byte data output
//wire    [7:0]   addr_hi_out = ao[15:8];
//wire    [7:0]   addr_lo_data_out = addr_data_sel ? md_out_byte_data : ao[7:0];

//address/data output
assign  o_A = ao;
assign  o_DO = md_out_byte_data;

//ALE, /RD, /WR
logic           ale_out, rd_out, wr_out, pd_do_oe, do_oe, m1, io;

//bus control signal
assign o_ALE = ale_out;
assign o_RD_n = ~rd_out;
assign o_WR_n = ~wr_out;

assign o_PD_DO_OE = pd_do_oe; //port D multiplexed addr/data output output enable
assign o_DO_OE = do_oe; //data output enable
assign o_M1_n = ~m1;
assign o_IO_n = ~io;

always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        ale_out <= 1'b0;
        rd_out <= 1'b0;
        wr_out <= 1'b0;
        pd_do_oe <= 1'b0;
        do_oe <= 1'b0;
        m1 <= 1'b0;
        io <= 1'b0;
    end
    else begin
        if(mcuclk_pcen) begin
            if(cycle_tick) begin
                if(mc_end_of_instruction && (irq_det | susp_det)) begin
                    ale_out <= 1'b0;
                    pd_do_oe <= 1'b0;
                end
                else begin
                    if(mc_next_bus_acc != IDLE) begin
                        ale_out <= 1'b1;
                        pd_do_oe <= 1'b1;
                        
                        if(mc_next_bus_acc == RD4 && !(mc_type == MCTYPE3 && mc_t3_ird == 1'b1)) m1 <= 1'b1;
                        //if(mc_end_of_instruction && mc_next_bus_acc == RD4) m1 <= 1'b1;
                        if(mc_next_bus_acc == RD3 || mc_next_bus_acc == WR3) io <= 1'b1;
                    end
                end
            end
            else begin
                if(!(force_exec_hardi | force_exec_nop)) begin
                    //ALE off
                    if(timing_sr[1]) ale_out <= 1'b0;

                    //PD data OE off
                    if(current_bus_acc == RD3 || current_bus_acc == RD4) begin
                        if(timing_sr[2]) pd_do_oe <= 1'b0;
                    end

                    //RD control
                    if(current_bus_acc == RD4) begin
                        if(timing_sr[2]) rd_out <= 1'b1;
                        else if(timing_sr[8]) rd_out <= 1'b0;
                    end
                    else if(current_bus_acc == RD3) begin
                        if(timing_sr[2]) rd_out <= 1'b1;
                        else if(timing_sr[6]) rd_out <= 1'b0;
                    end
                    else rd_out <= 1'b0;

                    //M1/IO control
                    if(timing_sr[2]) m1 <= 1'b0;
                    if(timing_sr[2]) io <= 1'b0;
                end

                //WR control
                if(current_bus_acc == WR3) begin
                    if(timing_sr[2]) begin
                        wr_out <= 1'b1;
                        do_oe <= 1'b1;
                        io <= 1'b0;
                    end
                    else if(timing_sr[6]) wr_out <= 1'b0;
                    else if(timing_sr[8]) do_oe <= 1'b0;
                end
                else wr_out <= 1'b0;
            end
        end
    end
end



///////////////////////////////////////////////////////////
//////  DEU/AEU READ PORT MULTIPLEXERS
////

//Data Execution Unit port A and B
logic   [15:0]  deu_pa, deu_pb; 
always_comb begin
    deu_pa = 16'h0000; deu_pb = 16'h0000;
    case(mc_t0_src)
        T0_SRC_R      : deu_pb = gpr_RDBUS; //{8'h00, reg_R};
        T0_SRC_R2     : deu_pb = gpr_RDBUS; //{8'h00, reg_R2};
        T0_SRC_R1     : deu_pb = gpr_RDBUS; //{8'h00, reg_R1};
        T0_SRC_RP2    : deu_pb = gpr_RDBUS; //reg_RP2;
        T0_SRC_RP     : deu_pb = gpr_RDBUS; //reg_RP;
        T0_SRC_RP1    : deu_pb = gpr_RDBUS; //reg_RP1;
        T0_SRC_SRTMP  : deu_pb = reg_SRTMP;
        T0_SRC_PSW    : deu_pb = reg_PSW;
        T0_SRC_MD     : deu_pb = {reg_MD[1], reg_MD[0]};
        T0_SRC_MD0    : deu_pb = {8'h00, reg_MD[0]};
        T0_SRC_A      : deu_pb = {8'h00, reg_A};
        T0_SRC_EA     : deu_pb = {reg_EAH, reg_EAL};
        T0_SRC_DAUX    : deu_pb = reg_DAUX;
        default       : deu_pb = 16'h0000;
    endcase

    case(mc_t0_dst)
        T0_DST_R      : deu_pa = gpr_RDBUS; //{8'h00, reg_R};
        T0_DST_R2     : deu_pa = gpr_RDBUS; //{8'h00, reg_R2};
        T0_DST_R1     : deu_pa = gpr_RDBUS; //{8'h00, reg_R1};
        T0_DST_RP2    : deu_pa = gpr_RDBUS; //reg_RP2;
        T0_DST_RP     : deu_pa = gpr_RDBUS; //reg_RP;
        T0_DST_RP1    : deu_pa = gpr_RDBUS; //reg_RP1;
        T0_DST_SRTMP  : deu_pa = reg_SRTMP;
        T0_DST_PSW    : deu_pa = reg_PSW;
        T0_DST_MD     : deu_pa = {reg_MD[1], reg_MD[0]};
        T0_DST_MD0    : deu_pa = {8'h00, reg_MD[0]};
        T0_DST_MD1    : deu_pa = {8'h00, reg_MD[1]};
        T0_DST_A      : deu_pa = {8'h00, reg_A};
        T0_DST_C      : deu_pa = gpr_RDBUS;
        T0_DST_EA     : deu_pa = {reg_EAH, reg_EAL};
        T0_DST_BC     : deu_pa = gpr_RDBUS;
        default       : deu_pa = 16'h0000;
    endcase
end

//Address Execution Unit port A and B
logic   [15:0]   rpa2_offset;
always_comb begin
    //rpa2 addend select
    case(reg_OPCODE[2:0])
        3'b011: rpa2_offset = {8'h00, reg_AAUX[7:0]};
        3'b100: rpa2_offset = gpr_RDBUS;
        3'b101: rpa2_offset = gpr_RDBUS;
        3'b110: rpa2_offset = gpr_RDBUS;
        3'b111: rpa2_offset = {8'h00, reg_AAUX[7:0]};
        default: rpa2_offset =  gpr_RDBUS; //not specified
    endcase
end

logic   [15:0]  aeu_pa, aeu_pb; 
always_comb begin
    aeu_pa = 16'h0000; aeu_pb = 16'h0000;
    case(mc_t1_src)
        T1_SRC_A_TA       : aeu_pb = {8'h00, 2'b10, reg_OPCODE[4:0], 1'b0};
        T1_SRC_A_FA       : aeu_pb = {5'b00001, reg_OPCODE[2:0], reg_AAUX[7:0]};
        T1_SRC_A_REL_S    : aeu_pb = {{11{reg_OPCODE[5]}}, reg_OPCODE[4:0]}; //sign extension
        T1_SRC_A_REL_L    : aeu_pb = {{8{reg_OPCODE[0]}}, reg_AAUX[7:0]};
        T1_SRC_A_INT      : aeu_pb = irq_addr; //selected externally
        T1_SRC_RPA_OFFSET : aeu_pb = rpa2_offset;
        T1_SRC_RPA        : aeu_pb = gpr_RDBUS;
        T1_SRC_RPA2       : aeu_pb = gpr_RDBUS;
        T1_SRC_AAUX       : aeu_pb = reg_AAUX;
        T1_SRC_EA         : aeu_pb = gpr_RDBUS;
        T1_SRC_BC         : aeu_pb = gpr_RDBUS;
        T1_SRC_DE         : aeu_pb = gpr_RDBUS;
        T1_SRC_HL         : aeu_pb = gpr_RDBUS;
        T1_SRC_SP         : aeu_pb = gpr_RDBUS;
        T1_SRC_PC         : aeu_pb = reg_PC;
        default           : aeu_pb = 16'h0000;
    endcase

    case(mc_t1_dst)
        T1_DST_RPA        : aeu_pa = gpr_RDBUS;
        T1_DST_MD         : aeu_pa = {reg_MD[1], reg_MD[0]};
        T1_DST_MA         : aeu_pa = reg_MA;
        T1_DST_PC         : aeu_pa = reg_PC;
        default           : aeu_pa = 16'h0000;
    endcase
end




///////////////////////////////////////////////////////////
//////  DEU
////

//Full adder with nibble, byte, word outputs
logic   [15:0]  deu_add_op0, deu_add_op1;
logic           deu_add_ci;
logic           deu_add_borrow;
wire    [4:0]   deu_add_na = deu_add_op0[3:0] + deu_add_op1[3:0] + deu_add_ci;
wire    [8:0]   deu_add_ba = deu_add_op0[7:0] + deu_add_op1[7:0] + deu_add_ci;
wire    [16:0]  deu_add_wa = deu_add_op0 + deu_add_op1 + deu_add_ci;
wire    [15:0]  deu_add_out = deu_add_wa[15:0];
wire            deu_add_nco = deu_add_na[4];
wire            deu_add_bco = deu_add_ba[8];
wire            deu_add_wco = deu_add_wa[16];


//Shifter and bit rotator
logic   [15:0]  deu_sh_out;
logic           deu_sh_out_co;
always_comb begin
    deu_sh_out = 16'h0000;
    
    casez(shift_code)
        //4'b0000: begin  deu_sh_out[7:0] = {1'b0, deu_pa[7:1]};   //SLRC, skip condition: CARRY
        //                deu_sh_out_co   = deu_pa[0]; end
        //4'b0001: begin  deu_sh_out[7:0] = {flag_C, deu_pa[7:1]}; //no instruction specified (RLR)
        //                deu_sh_out_co   = deu_pa[0]; end 
        4'b00?0: begin  deu_sh_out[7:0] = {1'b0, deu_pa[7:1]};   //SLR
                        deu_sh_out_co   = deu_pa[0]; end
        4'b00?1: begin  deu_sh_out[7:0] = {flag_C, deu_pa[7:1]}; //RLR
                        deu_sh_out_co   = deu_pa[0]; end 
        //4'b0100: begin  deu_sh_out[7:0] = {deu_pa[6:0], 1'b0};   //SLLC, skip condition: CARRY
        //                deu_sh_out_co   = deu_pa[7]; end
        //4'b0101: begin  deu_sh_out[7:0] = {deu_pa[6:0], flag_C}; //no instruction specified (RLL)
        //                deu_sh_out_co   = deu_pa[7]; end
        4'b01?0: begin  deu_sh_out[7:0] = {deu_pa[6:0], 1'b0};   //SLL
                        deu_sh_out_co   = deu_pa[7]; end
        4'b01?1: begin  deu_sh_out[7:0] = {deu_pa[6:0], flag_C}; //RLL
                        deu_sh_out_co   = deu_pa[7]; end
        //4'b1000: begin  deu_sh_out    = {1'b0, deu_pa[15:1]};    //no instruction specified (DSLR)
        //                deu_sh_out_co = deu_pa[0]; end
        //4'b1001: begin  deu_sh_out    = {flag_C, deu_pa[15:1]};  //no instruction specified (DRLR)
        //                deu_sh_out_co = deu_pa[0]; end
        4'b10?0: begin  deu_sh_out    = {1'b0, deu_pa[15:1]};    //DSLR
                        deu_sh_out_co = deu_pa[0]; end
        4'b10?1: begin  deu_sh_out    = {flag_C, deu_pa[15:1]};  //DRLR
                        deu_sh_out_co = deu_pa[0]; end
        //4'b1100: begin  deu_sh_out    = {deu_pa[14:0], 1'b0};    //no instruction specified (DSLL)
        //                deu_sh_out_co = deu_pa[15]; end
        //4'b1101: begin  deu_sh_out    = {deu_pa[14:0], flac_C};  //no instruction specified (DRLL)
        //                deu_sh_out_co = deu_pa[15]; end 
        4'b11?0: begin  deu_sh_out    = {deu_pa[14:0], 1'b0};    //DSLL
                        deu_sh_out_co = deu_pa[15]; end
        4'b11?1: begin  deu_sh_out    = {deu_pa[14:0], flag_C};  //DRLL
                        deu_sh_out_co = deu_pa[15]; end
        default: begin  deu_sh_out    = 16'h0000;
                        deu_sh_out_co = 1'b0; end
    endcase
end


//Multiplier/divider sequencer
logic   [4:0]   deu_muldiv_cntr;
always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        deu_muldiv_cntr <= 5'd31;
        deu_muldiv_busy <= 1'b0;
    end
    else begin if(cycle_tick) begin
        if(deu_muldiv_cntr == 5'd31) begin
            //unique if
            if(deu_mul_start) begin
                deu_muldiv_cntr <= 5'd16;
                deu_muldiv_busy <= 1'b1;
            end
            else if(deu_div_start) begin
                deu_muldiv_cntr <= 5'd0;
                deu_muldiv_busy <= 1'b1;
            end
            else ; //make sure the unique-if statement covers all possible conditions
        end
        else begin
                 if(deu_muldiv_cntr == 5'd15) deu_muldiv_busy <= 1'b0;
            else if(deu_muldiv_cntr == 5'd22) deu_muldiv_busy <= 1'b0;

                 if(deu_muldiv_cntr == 5'd15) deu_muldiv_cntr <= 5'd31;
            else if(deu_muldiv_cntr == 5'd23) deu_muldiv_cntr <= 5'd31;
            else                              deu_muldiv_cntr <= deu_muldiv_cntr + 5'd1;
        end
    end end
end

logic   [7:0]   deu_muldiv_r2_temp;
always_ff @(posedge emuclk) if(cycle_tick) begin
    if(mc_type == MCTYPE0 && (mc_t0_deu_op == T0_DEU_MUL || mc_t0_deu_op == T0_DEU_DIV)) deu_muldiv_r2_temp <= gpr_RDBUS[7:0];
end

logic           deu_mul_aux_wr, deu_div_aux_wr, deu_rot_aux_wr;
always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        reg_DAUX <= 16'h0000;
    end
    else begin if(cycle_tick) begin
        if(deu_mul_aux_wr || deu_div_aux_wr || deu_rot_aux_wr) reg_DAUX <= deu_aux_output;
        else if(deu_muldiv_busy && deu_muldiv_cntr[4]) reg_DAUX <= reg_DAUX << 1; //shift {8'h00, reg_A} right one bit every clock for mul
    end end
end

wire    [15:0]  deu_mul_op0 = {reg_EAH, reg_EAL};
wire    [15:0]  deu_mul_op1 = deu_muldiv_r2_temp[deu_muldiv_cntr[2:0]] ? reg_DAUX : 16'h0000;

wire    [15:0]  deu_div_op0 = reg_DAUX;
wire    [15:0]  deu_div_op1 = ~{8'h00, deu_muldiv_r2_temp}; //subtract the op1

wire    [31:0]  div_not_subtracted = {reg_DAUX, {reg_EAH, reg_EAL}};
wire    [31:0]  div_subtracted = {deu_add_out, {reg_EAH, reg_EAL}};
wire    [31:0]  deu_div_next = deu_muldiv_cntr == 5'd31 ? {15'd0, {reg_EAH, reg_EAL}, 1'b0} :
                                                          deu_add_wco ? {div_subtracted[30:0], 1'b1} : {div_not_subtracted[30:0], 1'b0};
wire    [7:0]   deu_div_rem  = deu_add_wco ? deu_add_out[7:0] : reg_DAUX[7:0];


//Main ALU
always_comb begin
    /*
        PORT A = SRC1/DST
        PORT B = SRC2
    */

    //maintain current destination register's data, if the port is not altered
    deu_add_op0 = deu_pa; deu_add_op1 = 16'd0; deu_add_ci = 1'b0; //FA inputs
    deu_add_borrow = 1'b0;

    deu_output = deu_add_out; //result output

    deu_aux_output = deu_add_out; //AUX register data output
    deu_rot_aux_wr = 1'b0; //AUX register write
    deu_mul_aux_wr = 1'b0;
    deu_div_aux_wr = 1'b0;

    deu_muldiv_ea_wr = 1'b0;

    if(!deu_muldiv_busy) begin
        casez(mc_t0_deu_op)
            T0_DEU_MOV: begin //move, FA PORT B -> out
                deu_output = deu_pb;
                //deu_add_op0 = 16'h0000; deu_add_op1 = deu_pb;
            end
            T0_DEU_NEG: begin //negative number, 2's complement of FA PORT A
                deu_output = deu_add_out;
                deu_add_op0 = ~deu_pa; deu_add_op1 = 16'd0; deu_add_ci = 1'b1;
            end
            T0_DEU_INC: begin //increment by 1, add 1 to FA PORT A
                deu_output = deu_add_out;
                deu_add_op0 = deu_pa; deu_add_op1 = 16'h0001; deu_add_ci = 1'b0;            
            end
            T0_DEU_DEC: begin //decrement by 1, sub 1 from FA PORT A
                deu_output = deu_add_out;
                deu_add_op0 = deu_pa; deu_add_op1 = 16'hFFFF; deu_add_ci = 1'b0;
                deu_add_borrow = 1'b1;
            end
            T0_DEU_ROT: begin //digit roatation
                /*                                RRD                                  RLD */
                deu_output     = reg_OPCODE[0] ? {8'h00, deu_pb[3:0], deu_pa[7:4]} : {8'h00, deu_pa[3:0], deu_pb[3:0]}; //to MD
                deu_aux_output = reg_OPCODE[0] ? {8'h00, deu_pb[7:4], deu_pa[3:0]} : {8'h00, deu_pb[7:4], deu_pa[7:4]}; //to TEMP->A
                deu_rot_aux_wr = 1'b1;
            end
            T0_DEU_SHFT: begin //bit shift and rotation
                deu_output = deu_sh_out;
            end
            T0_DEU_DAA, 4'b011?: begin //decimal adjust
                deu_output = deu_add_out;
                deu_add_op0 = deu_pa; deu_add_ci = 1'b0;
                if(flag_HC) begin
                    if(flag_C == 1'b0 && deu_pa[7:4] <= 4'h9) deu_add_op1 = 16'h0006;
                    else deu_add_op1 = 16'h0066;
                end
                else begin
                    if(deu_pa[3:0] <= 4'h9) begin
                        if(flag_C == 1'b0 && deu_pa[7:4] <= 4'h9) deu_add_op1 = 16'h0000;
                        else deu_add_op1 = 16'h0060;
                    end
                    else begin
                        if(flag_C == 1'b0 && deu_pa[7:4] <= 4'h9) deu_add_op1 = 16'h0006;
                        else deu_add_op1 = 16'h0066;
                    end
                end
            end
            T0_DEU_MUL, 4'b100?: begin
                deu_output = deu_add_out;
                deu_add_op0 = 16'd0; deu_add_op1 = 16'd0; deu_add_ci = 1'b0;  //reset EA
                deu_mul_aux_wr = 1'b1;
                deu_aux_output = {8'h00, reg_A};
            end
            T0_DEU_DIV, 4'b101?: begin
                {deu_aux_output, deu_output} = deu_div_next;
                deu_add_op0 = deu_div_op0; //reg EA
                deu_add_op1 = deu_div_op1; //-r2
                deu_add_ci = 1'b1; //-r2

                deu_div_aux_wr = 1'b1;
            end
            T0_DEU_COMOP, 4'b11??: begin
                case(arith_code)
                    DEU_OP_MOV:
                        deu_output = deu_pb;
                    DEU_OP_AND:
                        deu_output = deu_pa & deu_pb;
                    DEU_OP_OR:
                        deu_output = deu_pa | deu_pb;
                    DEU_OP_XOR:
                        deu_output = deu_pa ^ deu_pb;
                    DEU_OP_ADD: begin
                        deu_output = deu_add_out;
                        deu_add_op0 = deu_pa; deu_add_op1 = deu_pb; deu_add_ci = 1'b0; end
                    DEU_OP_ADDWC: begin
                        deu_output = deu_add_out;
                        deu_add_op0 = deu_pa; deu_add_op1 = deu_pb; deu_add_ci = flag_C; end
                    DEU_OP_SUB: begin
                        deu_output = deu_add_out;
                        deu_add_op0 = deu_pa; deu_add_op1 = ~deu_pb; deu_add_ci = 1'b1; 
                        deu_add_borrow = 1'b1; end
                    DEU_OP_SUBWB: begin
                        deu_output = deu_add_out;
                        deu_add_op0 = deu_pa; deu_add_op1 = ~deu_pb; deu_add_ci = ~flag_C; 
                        deu_add_borrow = 1'b1; end

                    DEU_OP_SK_ANDNZ: begin
                        deu_output = deu_pa;
                        deu_aux_output = deu_pa & deu_pb; end
                    DEU_OP_SK_ANDZ: begin
                        deu_output = deu_pa;
                        deu_aux_output = deu_pa & deu_pb; end
                    DEU_OP_SK_ADDNC: begin
                        deu_output = deu_add_out;
                        deu_add_op0 = deu_pa; deu_add_op1 = deu_pb; deu_add_ci = 1'b0; end
                    DEU_OP_SK_SUBNB: begin
                        deu_output = deu_add_out;
                        deu_add_op0 = deu_pa; deu_add_op1 = ~deu_pb; deu_add_ci = 1'b1; 
                        deu_add_borrow = 1'b1; end
                    DEU_OP_SK_NE: begin
                        deu_output = deu_pa;
                        deu_aux_output = deu_add_out;
                        deu_add_op0 = deu_pa; deu_add_op1 = ~deu_pb; deu_add_ci = 1'b1; 
                        deu_add_borrow = 1'b1; end
                    DEU_OP_SK_EQ: begin
                        deu_output = deu_pa;
                        deu_aux_output = deu_add_out;
                        deu_add_op0 = deu_pa; deu_add_op1 = ~deu_pb; deu_add_ci = 1'b1; 
                        deu_add_borrow = 1'b1; end
                    DEU_OP_SK_GT: begin 
                        deu_output = deu_pa;
                        deu_aux_output = deu_add_out; //PA-PB-1, adding the inverted PB without carry has the same effect
                        deu_add_op0 = deu_pa; deu_add_op1 = ~deu_pb; deu_add_ci = 1'b0; 
                        deu_add_borrow = 1'b1; end
                    DEU_OP_SK_LT: begin
                        deu_output = deu_pa;
                        deu_aux_output = deu_add_out;
                        deu_add_op0 = deu_pa; deu_add_op1 = ~deu_pb; deu_add_ci = 1'b1;
                        deu_add_borrow = 1'b1; end
                endcase
            end
        endcase
    end
    else begin //if the DEU is processing mul/div
        if(deu_muldiv_cntr[4]) begin //multiply
            deu_output = deu_add_out;
            deu_add_op0 = deu_mul_op0; //reg EA
            deu_add_op1 = deu_mul_op1; //A * r2, shifted and masked
            deu_add_ci = 1'b0;

            deu_muldiv_ea_wr = 1'b1;
        end
        else begin //divide
            deu_output = deu_div_next[15:0];
            deu_add_op0 = deu_div_op0;  //reg EA
            deu_add_op1 = deu_div_op1;  //-r2
            deu_add_ci = 1'b1;

            deu_muldiv_ea_wr = 1'b1;
            deu_div_aux_wr = 1'b1; //alu_muldiv_cntr[3:0] == 4'd15 ? 1'b0 : 1'b1;
            
            deu_aux_output = deu_muldiv_cntr[3:0] == 4'd15 ? {8'h00, deu_div_rem} : deu_div_next[31:16];
        end
    end
end



///////////////////////////////////////////////////////////
//////  AEU
////

//16-bit adder
logic   [15:0]  aeu_add_op0, aeu_add_op1;
wire    [15:0]  aeu_add_out = aeu_add_op0 + aeu_add_op1;
always_comb begin
    /*
        PORT A = SRC1/DST
        PORT B = SRC2
    */

    aeu_add_op0 = aeu_pa; aeu_add_op1 = aeu_pb;

    casez(mc_t1_aeu_op)
        T1_AEU_ADD: begin
            aeu_output = aeu_add_out;
            aeu_ma_output = aeu_add_out;
            aeu_add_op0 = aeu_pa; aeu_add_op1 = aeu_pb;
        end
        T1_AEU_RPA_ADJ: begin
            aeu_output = aeu_add_out;
            aeu_ma_output = aeu_pb;
            aeu_add_op0 = aeu_pb; 
            casez(reg_OPCODE[2:1])
                2'b10 : aeu_add_op1 = 16'h0001;
                2'b11 : aeu_add_op1 = 16'hFFFF;
                default: aeu_add_op1 = 16'h0000;
            endcase
        end
        T1_AEU_RPA3_ADJ: begin
            aeu_output = aeu_add_out;
            aeu_ma_output = aeu_pb;
            aeu_add_op0 = aeu_pb; 
            casez(reg_OPCODE[2:1])
                2'b10  : aeu_add_op1 = 16'h0002;
                2'b11  : aeu_add_op1 = 16'hFFFE; //not specified, (-2?)
                default: aeu_add_op1 = 16'h0000;
            endcase
        end
        T1_AEU_PINC: begin
            aeu_output = aeu_add_out;
            aeu_ma_output = aeu_pb;
            aeu_add_op0 = aeu_pb;
            aeu_add_op1 = 16'h0001; //post-increment
        end 
        T1_AEU_DINC: begin
            aeu_output = aeu_add_out;
            aeu_ma_output = aeu_add_out;
            aeu_add_op0 = aeu_pa; 
            aeu_add_op1 = 16'h0002; //double increment
        end
        T1_AEU_DEC: begin
            aeu_output = aeu_add_out;
            aeu_ma_output = aeu_add_out;
            aeu_add_op0 = aeu_pa; 
            aeu_add_op1 = 16'hFFFF; //decrement
        end
        T1_AEU_PUSH: begin
            aeu_output = aeu_add_out;
            aeu_ma_output = aeu_add_out;
            aeu_add_op0 = aeu_pb; 
            aeu_add_op1 = 16'hFFFF; //decrement
        end
        T1_AEU_POP, T1_AEU_MOV, 4'b1???: begin //move, FA PORT B -> out
            aeu_output = aeu_pb;
            aeu_ma_output = aeu_pb;
        end
    endcase
end



///////////////////////////////////////////////////////////
//////  FLAG GENERATOR
////

//Since the flags are generated by an ALU-type microcode operation,
//they may be asserted during execution, potentially interrupting
//the current microcode flow. A two-stage DFF is used to update the
//flags *after* the current instruction completes.

//combinational
logic           z_comb, c_comb, hc_comb, sk_comb;

//temporary latch
logic           z_temp, c_temp, hc_temp, sk_temp;

//Z flag (combinational)
always_comb begin
    z_comb = flag_Z;
    if(mc_type == MCTYPE0) begin
        if(mc_t0_deu_op == T0_DEU_COMOP) begin
            //unique if
                 if(is_arith_eval_op)   z_comb = deu_dsize ? deu_aux_output == 16'h0000 : deu_aux_output[7:0] == 8'h00;
            else if(is_arith_mov)       z_comb = flag_Z;
            else                        z_comb = deu_dsize ? deu_output == 16'h0000 : deu_output[7:0] == 8'h00;
        end
        else if(mc_t0_deu_op == T0_DEU_DAA) z_comb = deu_dsize ? deu_output == 16'h0000 : deu_output[7:0] == 8'h00;
        else if(mc_t0_deu_op == T0_DEU_INC) z_comb = deu_dsize ? deu_output == 16'h0000 : deu_output[7:0] == 8'h00;
        else if(mc_t0_deu_op == T0_DEU_DEC) z_comb = deu_dsize ? deu_output == 16'h0000 : deu_output[7:0] == 8'h00;
    end
end

always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        z_temp <= 1'b0;
        flag_Z <= 1'b0; //reset
    end
    else begin if(cycle_tick) begin
        if(reg_PSW_wr) begin flag_Z <= gpr_WRBUS[6]; z_temp <= gpr_WRBUS[6]; end
        else begin
            if(mc_alter_flag) begin
                if(mc_end_of_instruction) begin 
                    flag_Z <= z_comb; z_temp <= z_comb; 
                end
                else z_temp <= z_comb;
            end
            else begin
                if(mc_end_of_instruction) flag_Z <= z_temp;
            end
        end
    end end
end

//Raw carry/borrow out of the adder, before deciding whether it reaches CY.
//INR/DCR/INRW/DCRW skip on carry/borrow but must NOT update CY(the datasheet
//lists only Z, SK, HC, L1, L0 for them), so their skip condition is taken from
//here while c_comb below leaves CY alone.
wire            deu_add_carry = deu_dsize ? deu_add_wco ^ deu_add_borrow : deu_add_bco ^ deu_add_borrow;

//C flag (combinational)
always_comb begin
    c_comb = flag_C;
    if(mc_type == MCTYPE0) begin
        if(mc_t0_deu_op == T0_DEU_COMOP)
            case(arith_code)
                DEU_OP_ADD      : c_comb = deu_dsize ? deu_add_wco ^ deu_add_borrow : deu_add_bco ^ deu_add_borrow; //ADD
                DEU_OP_ADDWC    : c_comb = deu_dsize ? deu_add_wco ^ deu_add_borrow : deu_add_bco ^ deu_add_borrow; //ADC
                DEU_OP_SUB      : c_comb = deu_dsize ? deu_add_wco ^ deu_add_borrow : deu_add_bco ^ deu_add_borrow; //SUB
                DEU_OP_SUBWB    : c_comb = deu_dsize ? deu_add_wco ^ deu_add_borrow : deu_add_bco ^ deu_add_borrow; //SBB
                DEU_OP_SK_ADDNC : c_comb = deu_dsize ? deu_add_wco ^ deu_add_borrow : deu_add_bco ^ deu_add_borrow; //ADDNC
                DEU_OP_SK_SUBNB : c_comb = deu_dsize ? deu_add_wco ^ deu_add_borrow : deu_add_bco ^ deu_add_borrow; //SUBNB
                DEU_OP_SK_NE    : c_comb = deu_dsize ? deu_add_wco ^ deu_add_borrow : deu_add_bco ^ deu_add_borrow; //SNE
                DEU_OP_SK_EQ    : c_comb = deu_dsize ? deu_add_wco ^ deu_add_borrow : deu_add_bco ^ deu_add_borrow; //SEQ
                DEU_OP_SK_GT    : c_comb = deu_dsize ? deu_add_wco ^ deu_add_borrow : deu_add_bco ^ deu_add_borrow; //SGT
                DEU_OP_SK_LT    : c_comb = deu_dsize ? deu_add_wco ^ deu_add_borrow : deu_add_bco ^ deu_add_borrow; //SLT
                default         : c_comb = flag_C;
            endcase
        //INC/DEC deliberately absent: they skip on carry/borrow but leave CY as
        //it was. See deu_add_carry above.
        else if(mc_t0_deu_op == T0_DEU_SHFT)
            c_comb = deu_sh_out_co;
        else if(mc_t0_deu_op == T0_DEU_DAA) 
            c_comb = deu_dsize ? deu_add_wco ^ deu_add_borrow : deu_add_bco ^ deu_add_borrow; 
    end
    else if(mc_type == MCTYPE2) begin
        if(mc_t2_carry_ctrl == 1'b1) c_comb = reg_OPCODE[0];
    end
end

always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        c_temp <= 1'b0;
        flag_C <= 1'b0; //reset
    end
    else begin if(cycle_tick) begin
        if(reg_PSW_wr) begin flag_C <= gpr_WRBUS[0]; c_temp <= gpr_WRBUS[0]; end
        else begin
            if(mc_alter_flag) begin
                if(mc_end_of_instruction) begin flag_C <= c_comb; c_temp <= c_comb; end
                else c_temp <= c_comb;
            end
            else begin
                if(mc_end_of_instruction) flag_C <= c_temp;
            end
        end
    end end
end

//HC flag (combinational)
always_comb begin
    hc_comb = flag_HC;
    if(mc_type == MCTYPE0) begin
        if(mc_t0_deu_op == T0_DEU_COMOP)
            case(arith_code)
                DEU_OP_ADD      : hc_comb = deu_add_nco ^ deu_add_borrow; //ADD
                DEU_OP_ADDWC    : hc_comb = deu_add_nco ^ deu_add_borrow; //ADC
                DEU_OP_SUB      : hc_comb = deu_add_nco ^ deu_add_borrow; //SUB
                DEU_OP_SUBWB    : hc_comb = deu_add_nco ^ deu_add_borrow; //SBB
                DEU_OP_SK_ADDNC : hc_comb = deu_add_nco ^ deu_add_borrow; //ADDNC
                DEU_OP_SK_SUBNB : hc_comb = deu_add_nco ^ deu_add_borrow; //SUBNB
                DEU_OP_SK_NE    : hc_comb = deu_add_nco ^ deu_add_borrow; //SNE
                DEU_OP_SK_EQ    : hc_comb = deu_add_nco ^ deu_add_borrow; //SEQ
                DEU_OP_SK_GT    : hc_comb = deu_add_nco ^ deu_add_borrow; //SGT
                DEU_OP_SK_LT    : hc_comb = deu_add_nco ^ deu_add_borrow; //SLT
                default         : hc_comb = flag_HC;
            endcase
        else if(mc_t0_deu_op == T0_DEU_DAA)
            hc_comb = deu_add_nco ^ deu_add_borrow;
        else if(mc_t0_deu_op == T0_DEU_INC)
            hc_comb = deu_add_nco ^ deu_add_borrow;
        else if(mc_t0_deu_op == T0_DEU_DEC)
            hc_comb = deu_add_nco ^ deu_add_borrow;
    end
end

always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        hc_temp <= 1'b0;
        flag_HC <= 1'b0; //reset
    end
    else begin if(cycle_tick) begin
        if(reg_PSW_wr) begin flag_HC <= gpr_WRBUS[4]; hc_temp <= gpr_WRBUS[4]; end
        else begin
            if(mc_alter_flag) begin
                if(mc_end_of_instruction) begin flag_HC <= hc_comb; hc_temp <= hc_comb; end
                else hc_temp <= hc_comb;
            end
            else begin
                if(mc_end_of_instruction) flag_HC <= hc_temp;
            end
        end
    end end
end

//SKIP flag
logic           skip_flag;
always_comb begin
    case(reg_OPCODE[2:0])
        3'b010: skip_flag = flag_C;
        3'b011: skip_flag = flag_HC;
        3'b100: skip_flag = flag_Z;
        default: skip_flag = 1'b0;
    endcase
end
always_comb begin
    sk_comb = 1'b0;
    if(mc_alter_flag) begin
        if(opcode_page == 3'd0 && reg_OPCODE == 8'hB9) sk_comb = 1'b1; //RETS, skip unconditionally

        if(mc_type == MCTYPE0) begin
            if(mc_t0_deu_op == T0_DEU_COMOP)
                case(arith_code)
                    DEU_OP_SK_ADDNC : sk_comb = ~c_comb; //ADDNC(skip condition: NO CARRY)
                    DEU_OP_SK_SUBNB : sk_comb = ~c_comb; //SUBNB(skip condition: NO BORROW)
                    DEU_OP_SK_GT    : sk_comb = ~c_comb; //SGT(skip condition: NO BORROW)
                    DEU_OP_SK_LT    : sk_comb =  c_comb; //SLT(skip condition: BORROW)
                    DEU_OP_SK_ANDNZ : sk_comb = ~z_comb; //AND(skip condition: NO ZERO)
                    DEU_OP_SK_ANDZ  : sk_comb =  z_comb; //AND(skip condition: ZERO)
                    DEU_OP_SK_NE    : sk_comb = ~z_comb; //SNE(skip condition: NO ZERO)
                    DEU_OP_SK_EQ    : sk_comb =  z_comb; //SEQ(skip condition: ZERO)
                    default: sk_comb = 1'b0;
                endcase

            else if(mc_t0_deu_op == T0_DEU_SHFT)
                case(shift_code)
                    4'b0000: sk_comb = c_comb; //SLRC, skip condition: CARRY
                    4'b0100: sk_comb = c_comb; //SLLC, skip condition: CARRY
                    default: sk_comb = 1'b0;
                endcase
            else if(mc_t0_deu_op == T0_DEU_INC)
                sk_comb = deu_add_carry; //skip on carry, but CY is not updated
            else if(mc_t0_deu_op == T0_DEU_DEC)
                sk_comb = deu_add_carry; //skip on borrow, but CY is not updated
        end
        else if(mc_type == MCTYPE2)
            case(mc_t2_skip_ctrl)
                T2_SKIP_BTST  : sk_comb =  reg_MD[0][reg_OPCODE[2:0]]; //BTST_WA
                T2_SKIP_SK    : sk_comb =  skip_flag;   //SK
                T2_SKIP_SKN   : sk_comb = ~skip_flag;   //SKN
                T2_SKIP_SKIT  : sk_comb =  iflag_muxed; //SKIT
                T2_SKIP_SKNIT : sk_comb = ~iflag_muxed; //SKNIT
                default: sk_comb = 1'b0;
            endcase
    end
end

always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        sk_temp <= 1'b0;
        flag_SK <= 1'b0; //reset
    end
    else begin if(cycle_tick) begin
        if(reg_PSW_wr) begin flag_SK <= gpr_WRBUS[5]; sk_temp <= gpr_WRBUS[5]; end
        else begin
            if(mc_alter_flag) begin
                if(mc_end_of_instruction) begin flag_SK <= sk_comb; sk_temp <= sk_comb; end
                else sk_temp <= sk_comb;
            end
            else begin
                if(mc_jmp_to_next_inst) begin flag_SK <= sk_comb; sk_temp <= sk_comb; end
                else begin if(mc_end_of_instruction) flag_SK <= sk_temp; end
            end
        end
    end end
end

//The L1/0 flag should be asserted at the end of the final microcode step
//(with mc_alter_flag) to avoid interfering with the execution of the
//current microcode.

//L1 flag, MVI A
//L0 flag, MVI L, LXI HL
wire            flag_l1_set_cond =  opcode_page == 3'd0 && reg_OPCODE == 8'h69;    //MVI A
wire            flag_l0_set_cond = (opcode_page == 3'd0 && reg_OPCODE == 8'h6F) || //MVI L
                                   (opcode_page == 3'd0 && reg_OPCODE == 8'h34);   //LXI HL
always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        flag_L1 <= 1'b0; //reset
        flag_L0 <= 1'b0;
    end
    else begin if(mcrom_read_tick) begin
        if(reg_PSW_wr) flag_L1 <= gpr_WRBUS[3];
        else begin
            if(!flag_l1_set_cond) begin
                if(softi_proc_cyc || hardi_proc_cyc) flag_L1 <= flag_L1; //do not update during an interrupt cycle..
                else flag_L1 <= 1'b0; //otherwise, reset
            end
            else begin
                if(mc_alter_flag) flag_L1 <= 1'b1;
            end
        end

        if(reg_PSW_wr) flag_L0 <= gpr_WRBUS[2];
        else begin
            if(!flag_l0_set_cond) begin
                if(softi_proc_cyc || hardi_proc_cyc) flag_L0 <= flag_L0;
                else flag_L0 <= 1'b0;
            end
            else begin
                if(mc_alter_flag) flag_L0 <= 1'b1;
            end
        end
    end end
end



///////////////////////////////////////////////////////////
//////  MICROCODE FLOW CONTROL
////

//Next bus access; assert RD3 when the operation mode is RPA2/3, DE/HL+byte, so
//that the IRO step fetches the displacement byte.
//
//This is decoded straight from mcrom_data rather than from the mc_type/
//mc_t2_atype_sel aliases, for two reasons. Those aliases are slices of
//mc_ctrl_output, so reading them here would make this block feed itself. And the
//displacement fetch has to survive the skip path below: an instruction that is
//skipped must still consume all of its bytes, or the displacement is fetched as
//the next opcode.
wire    [1:0]   mc_next_bus_acc_raw = (mcrom_data[17:16] == MCTYPE2 &&
                                       mcrom_data[12:10] == T2_ATYPE_IRO &&
                                       (reg_OPCODE[0] & reg_OPCODE[1])) ? RD3 : mcrom_data[1:0];

//"patch" the microcode output to modify the running flow.
always_comb begin
    if(|{flag_SK, flag_L1, flag_L0} && !(softi_proc_cyc | hardi_proc_cyc)) begin
        //When the skip condition is met, mask the microcode output as a NOP.
        //At the end of the opcode/data fetch cycle, force next_bus_acc to "RD4"
        //to fetch the next instruction.
        if(mc_jmp_to_next_inst)
            mc_ctrl_output = {MCTYPE2, 1'b0, 1'b0, T2_NOP, RD4};
        else
            mc_ctrl_output = {MCTYPE2, 1'b0, 1'b0, T2_NOP, mc_next_bus_acc_raw};
    end
    else begin
        //unique if
        //stop the microsequencer during mul/div calculation
        if(deu_muldiv_busy)
            mc_ctrl_output = {MCTYPE2, 1'b0, 1'b0, T2_NOP, IDLE};

        //default(no patch other than the bus access above)
        else
            mc_ctrl_output = {mcrom_data[17:2], mc_next_bus_acc_raw};
    end
end



///////////////////////////////////////////////////////////
//////  I/O PORTS
////

//port output enables
assign o_PA_OE = ~spr_MA;
assign o_PB_OE = ~spr_MB;
assign o_PC_OE = ~spr_MC;
assign o_PD_OE = spr_MM[0];
assign o_PF_OE = ~spr_MF;

//port data
assign o_PA_O = spr_PAO;
assign o_PB_O = spr_PBO;
assign o_PC_O = spr_PCO;
assign o_PD_O = spr_PDO;
assign o_PF_O = spr_PFO;



///////////////////////////////////////////////////////////
//////  DIV3 TICK GENERATOR
////

logic   [1:0]   div3_tick_cntr;
wire            div3_tick = div3_tick_cntr == 2'd2 && mcuclk_pcen;
always_ff @(posedge emuclk) begin
    if(!mrst_n) div3_tick_cntr <= 2'd0;
    else begin if(mcuclk_pcen) begin
        div3_tick_cntr <= div3_tick_cntr == 2'd2 ? 2'd0 : div3_tick_cntr + 2'd1;
    end end
end



///////////////////////////////////////////////////////////
//////  ADC DATA ACQUISITION CONTROL
////

logic   [4:0]   current_adc_mode;
logic   [7:0]   adc_state_cntr;
logic   [2:0]   adc_ch;
logic           adc_strobe_n;

assign o_ANx_ANALOG_CH = current_adc_mode[0] ? current_adc_mode[3:1] : adc_ch;
assign o_ANx_ANALOG_RD_n = adc_strobe_n;
assign is_ADC = current_adc_mode[4] ? div3_tick_cntr == 2'd2 && adc_state_cntr == 8'd127 && adc_ch[1:0] == 2'b11: 
                                      div3_tick_cntr == 2'd2 && adc_state_cntr == 8'd175 && adc_ch[1:0] == 2'b11;

always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        current_adc_mode <= 5'b00000;
        adc_state_cntr <= 8'd0;
        adc_ch <= 3'd0;
    end
    else begin if(div3_tick) begin
        if(( current_adc_mode[4] && adc_state_cntr == 8'd143) || 
           (~current_adc_mode[4] && adc_state_cntr == 8'd191)) begin

            //make a copy of the current ANM reg value
            current_adc_mode <= spr_ANM;

            //scan mode/single ch mode select
            if(spr_ANM[0] != current_adc_mode[0]) adc_ch <= {spr_ANM[3], 2'b00}; //if the mode has been changed, initialize the counter
            else adc_ch[1:0] <= adc_ch[1:0] == 2'b11 ? 2'b00 : adc_ch[1:0] + 2'b01; //count up

            //reset the adc state counter
            adc_state_cntr <= 8'd0;
        end
        else begin
            adc_state_cntr <= adc_state_cntr + 8'd1;
        end

        //data acquisition control
        if(adc_state_cntr == 8'd0) adc_strobe_n <= 1'b0;
        else if(adc_state_cntr == 8'd127) begin
            adc_strobe_n <= current_adc_mode[4] ? 1'b1 : 1'b0;
            if(current_adc_mode[4]) spr_CR[adc_ch[1:0]] <= i_ANx_ANALOG_DATA;
        end
        else if(adc_state_cntr == 8'd175) begin
            adc_strobe_n <= current_adc_mode[4] ? 1'b0 : 1'b1;
            if(~current_adc_mode[4]) spr_CR[adc_ch[1:0]] <= i_ANx_ANALOG_DATA;
        end
    end end
end



///////////////////////////////////////////////////////////
//////  TIMER
////

//tick from an external source
wire            ti_nedet;
IKA87AD_nedet nedet_ti (mrst_n, emuclk, div3_tick, i_TI, ti_nedet);

//make timer ticks
logic   [1:0]   timer_prescaler;
logic   [6:0]   timer_div_cntr;
wire            timer_tick   = timer_prescaler == 2'd2 & mcuclk_pcen; //fs/3 tick
wire            timer_div12  = timer_div_cntr[1:0] == 2'd3;
wire            timer_div384 = timer_div_cntr == 7'd127;
always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        timer_prescaler <= 2'd0;
        timer_div_cntr <= 7'd0;
    end
    else begin if(mcuclk_pcen) begin
        if(hard_stop_flag || (soft_stop_flag && !iflag[0])) begin //stop timer
            timer_prescaler <= timer_prescaler;
            timer_div_cntr <= timer_div_cntr;
        end
        else begin
            timer_prescaler <= timer_prescaler == 2'd2 ? 2'd0 : timer_prescaler + 2'd1;
            if(timer_prescaler == 2'd2) timer_div_cntr <= timer_div_cntr == 7'd127 ? 7'd0 : timer_div_cntr + 7'd1;
        end
    end end
end

//timer 0/1
logic   [7:0]   timer0, timer1; //timer registers
logic           tmff; 
logic           timer0_cnt, timer1_cnt, tmff_toggle; //timer0/1 and tmff ticks
wire            timer0_match = timer0_cnt & (timer0 == spr_TM0) & (spr_rw_addr != 6'h1A); //this tick pokes the next DFFs
wire            timer1_match = timer1_cnt & (timer1 == spr_TM1) & (spr_rw_addr != 6'h1B);
wire            tmff_pcen = tmff_toggle & (tmff == 1'b0) & timer_tick; //TMFF postive edge clock enable
wire            tmff_ncen = (tmff_toggle & (tmff == 1'b1) & timer_tick) | 
                            ((spr_TMM[1:0] == 2'b11) & (tmff == 1'b1) & timer_tick); //TMFF negative edge clock enable
assign is_TIMER0 = ~soft_stop_flag & timer0_match & timer_tick;
assign is_TIMER1 = ~soft_stop_flag & timer1_match & timer_tick;
assign release_soft_stop = soft_stop_flag & timer1_match & timer_tick; //release soft stop
assign o_TO = tmff;
assign o_TO_PCEN = tmff_pcen;
assign o_TO_NCEN = tmff_ncen;
always_comb begin
    case(spr_TMM[3:2])
        2'b00: timer0_cnt = timer_div12;
        2'b01: timer0_cnt = timer_div384;
        2'b10: timer0_cnt = ti_nedet;
        2'b11: timer0_cnt = 1'b0;
    endcase

    case(spr_TMM[6:5])
        2'b00: timer1_cnt = timer_div12;
        2'b01: timer1_cnt = timer_div384;
        2'b10: timer1_cnt = ti_nedet;
        2'b11: timer1_cnt = timer0_match;
    endcase

    case(spr_TMM[1:0])
        2'b00: tmff_toggle = timer0_match;
        2'b01: tmff_toggle = timer1_match;
        2'b10: tmff_toggle = 1'b1; //toggle at every timer_tick(fs/3)
        2'b11: tmff_toggle = 1'b0; //reset
    endcase
end

always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        timer0 <= 8'h01;
        timer1 <= 8'h01;
        tmff <= 1'b0;
    end
    else if(soft_stop_flag && !iflag[0]) begin //timer 0 and 1 can be used as a soft stop release wait timer, NMI triggered
        timer0 <= 8'h01;
        timer1 <= 8'h01;
    end
    else begin if(timer_tick) begin //use timer tick(fs/3)
        //define timer 0 behavior
        if(spr_TMM[4]) timer0 <= 8'h01;
        else begin
            if(timer0_cnt) begin
                if(timer0 == spr_TM0 && spr_rw_addr != 6'h1A) timer0 <= 8'h01; //no comparison is performed while updating TM0, see datasheet p79
                else timer0 <= timer0 == 8'hFF ? 8'h00 : timer0 + 8'h01;
            end
        end

        //define timer 1 behavior
        if(spr_TMM[7]) timer1 <= 8'h01;
        else begin
            if(timer1_cnt) begin
                if(timer1 == spr_TM1 && spr_rw_addr != 6'h1B) timer1 <= 8'h01; //no comparison is performed while updating TM1
                else timer1 <= timer1 == 8'hFF ? 8'h00 : timer1 + 8'h01;
            end
        end

        //define tmff behavior
        if(spr_TMM[1:0] == 2'b11) tmff <= 1'b0;
        else begin
            if(tmff_toggle) tmff <= ~tmff;
        end
    end end
end



///////////////////////////////////////////////////////////
//////  EVENT COUNTER
////

//tick from an external source
logic   [1:0]   ci_sampler;
logic           ci_nedet, ci_state;
always_ff @(posedge emuclk) begin
    if(!mrst_n) begin 
        ci_sampler <= 2'b00;
        ci_nedet <= 1'b0;
        ci_state <= 1'b0;
    end
    else begin if(div3_tick) begin
        ci_sampler[0] <= i_CI;
        ci_sampler[1] <= ci_sampler[0];

        if(ci_sampler == 2'b10 && i_CI == 1'b0) ci_nedet <= 1'b1;
        else ci_nedet <= 1'b0;

        if(ci_sampler == 2'b10 && i_CI == 1'b0) ci_state <= 1'b0;
        else if(ci_sampler == 2'b01 && i_CI == 1'b1) ci_state <= 1'b1;
        else ci_state <= ci_state;
    end end
end

//event counter
logic           event_cntr_cnt;
always_comb begin
    case(spr_ETMM[1:0])
        2'b00: event_cntr_cnt = timer_div12;
        2'b01: event_cntr_cnt = timer_div12 & ci_state;
        2'b10: event_cntr_cnt = ci_nedet;
        2'b11: event_cntr_cnt = ci_nedet & tmff;
    endcase
end

logic   [15:0]  event_cntr;
wire    [16:0]  event_cntr_next = event_cntr + 16'd1;
wire            cntr0_match = event_cntr_cnt & (event_cntr_next[15:0] == spr_ETM0) & (spr_rw_addr != 6'h30);
wire            cntr1_match = event_cntr_cnt & (event_cntr_next[15:0] == spr_ETM1) & (spr_rw_addr != 6'h31);
assign is_CNTR0 = cntr0_match & timer_tick;
assign is_CNTR1 = cntr1_match & timer_tick;
assign is_nCNTRCIN = ci_nedet;
wire            fs_OV = event_cntr_next[16] & event_cntr_cnt & timer_tick;
always_ff @(posedge emuclk) begin
    if(!mrst_n) begin
        event_cntr <= 16'd0;
    end
    else begin if(timer_tick) begin 
        case(spr_ETMM[3:2])
            2'b00: event_cntr <= 16'd0;
            2'b01: event_cntr <= event_cntr_cnt ? event_cntr_next[15:0] : event_cntr;
            2'b10: begin
                if(spr_ETMM[1]) begin
                    if(tmff_ncen) event_cntr <= 16'd0;
                    else event_cntr <= event_cntr_cnt ? event_cntr_next[15:0] : event_cntr;
                end
                else begin
                    if(ci_nedet) event_cntr <= 16'd0;
                    else event_cntr <= event_cntr_cnt ? event_cntr_next[15:0] : event_cntr;
                end
            end
            2'b11: begin
                if(event_cntr_cnt) begin
                    if(event_cntr_next[15:0] == spr_ETM1) event_cntr <= 16'd0;
                    else event_cntr <= event_cntr_next[15:0];
                end
            end 
        endcase
    end end
end



///////////////////////////////////////////////////////////
//////  MISC FLAGS
////

//ER(serial IO error)
assign eflag[0] = 1'b0; //not implemented

//OV(event counter overflow)
IKA87AD_flag u_nedet_ov     (mrst_n, emuclk, mcuclk_pcen, cycle_tick, fs_OV, 1'b1, 5'd12, reg_OPCODE[4:0], 
                            1'b1, iflag_manual_ack, 1'b0, eflag[1]);

//AN7-4(negative edge)
wire    [3:0]   fs_ANx;
IKA87AD_nedet u_nedet_an7 (mrst_n, emuclk, div3_tick, i_ANx_DIGITAL[3], fs_ANx[3]);
IKA87AD_nedet u_nedet_an6 (mrst_n, emuclk, div3_tick, i_ANx_DIGITAL[2], fs_ANx[2]);
IKA87AD_nedet u_nedet_an5 (mrst_n, emuclk, div3_tick, i_ANx_DIGITAL[1], fs_ANx[1]);
IKA87AD_nedet u_nedet_an4 (mrst_n, emuclk, div3_tick, i_ANx_DIGITAL[0], fs_ANx[0]);

IKA87AD_flag u_eflag_an7    (mrst_n, emuclk, mcuclk_pcen, cycle_tick, fs_ANx[3], 1'b1, 5'd16, reg_OPCODE[4:0], 
                            1'b1, iflag_manual_ack, 1'b0, eflag[2]);
IKA87AD_flag u_eflag_an6    (mrst_n, emuclk, mcuclk_pcen, cycle_tick, fs_ANx[2], 1'b1, 5'd17, reg_OPCODE[4:0], 
                            1'b1, iflag_manual_ack, 1'b0, eflag[3]);
IKA87AD_flag u_eflag_an5    (mrst_n, emuclk, mcuclk_pcen, cycle_tick, fs_ANx[1], 1'b1, 5'd18, reg_OPCODE[4:0], 
                            1'b1, iflag_manual_ack, 1'b0, eflag[4]);
IKA87AD_flag u_eflag_an4    (mrst_n, emuclk, mcuclk_pcen, cycle_tick, fs_ANx[0], 1'b1, 5'd19, reg_OPCODE[4:0], 
                            1'b1, iflag_manual_ack, 1'b0, eflag[5]);

//SB(first boot flag)
assign eflag[6] = 1'b1; //not implemented

endmodule