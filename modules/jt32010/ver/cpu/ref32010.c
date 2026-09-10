/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Reference model for the TMS320C10, ported line-for-line from MAME 0.289
 * src/devices/cpu/tms320c1x/tms320c1x.cpp so that it can act as an oracle for
 * the jt32010 RTL. It is deliberately a transcription, not a tidy-up: where
 * MAME does something surprising, this does the same surprising thing.
 *
 * Reads a program image (one 16-bit word per line, hex) and prints one trace
 * line per instruction, showing the machine state *before* that instruction
 * runs.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#define OV_FLAG   0x8000
#define OVM_FLAG  0x4000
#define INTM_FLAG 0x2000
#define ARP_REG   0x0100
#define DP_REG    0x0001

static uint16_t ROM[4096];
static uint16_t RAM[256];
static uint16_t PC, STR, Treg, AR[2], STACK[4];
static uint32_t ACC, ALU, Preg, oldacc;
static uint16_t opcode, prev_opcode;
static uint16_t memaccess;
static int      INTF;
static long     icount;          /* instructions retired, drives BIO and IN */
static long     in_seq;
static long     mcycles;   /* machine cycles, per MAME's opcode table */

#define OV   (STR & OV_FLAG)
#define OVM  (STR & OVM_FLAG)
#define INTM (STR & INTM_FLAG)
#define ARP  ((STR & ARP_REG) >> 8)
#define DP   ((STR & DP_REG) << 7)

#define OPH  ((opcode >> 8) & 0xff)
#define OPL  (opcode & 0xff)
#define DMA_DP  (DP | (OPL & 0x7f))
#define DMA_DP1 (0x80 | OPL)
#define IND  (AR[ARP] & 0xff)

/* The test harness drives BIO from the instruction counter and the IN ports
 * from a fixed sequence, so that the RTL bench can reproduce both exactly. */
static int      toaplan_mode = 0;
static int      tp_bio(void);
static uint16_t tp_in(int port);
static void     tp_out(int port, uint16_t val);

static int      bio_in(void){
    if(toaplan_mode) return tp_bio();
    return (int)(icount & 1);
}
static uint16_t port_in(int port){
    if(toaplan_mode) return tp_in(port);
    (void)port;
    { uint16_t v = (uint16_t)(0x1234 + in_seq*0x5678); in_seq++; return v; }
}
static void port_out(int port, uint16_t val){
    if(toaplan_mode) tp_out(port, val);
    else { (void)port; (void)val; }
}

static uint16_t rd_ram(uint16_t a){ a &= 0xff; return (a <= 0x8f) ? RAM[a] : 0; }
static void     wr_ram(uint16_t a, uint16_t v){ a &= 0xff; if(a <= 0x8f) RAM[a] = v; }

static void CLR(uint16_t f)      { STR &= ~f; STR |= 0x1efe; }
static void SET_FLAG(uint16_t f) { STR |=  f; STR |= 0x1efe; }

static void CALC_ADD_OVF(int32_t addval){
    if((int32_t)(~(oldacc ^ (uint32_t)addval) & (oldacc ^ ACC)) < 0){
        SET_FLAG(OV_FLAG);
        if(OVM) ACC = ((int32_t)oldacc < 0) ? 0x80000000u : 0x7fffffffu;
    }
}
static void CALC_SUB_OVF(int32_t subval){
    if((int32_t)((oldacc ^ (uint32_t)subval) & (oldacc ^ ACC)) < 0){
        SET_FLAG(OV_FLAG);
        if(OVM) ACC = ((int32_t)oldacc < 0) ? 0x80000000u : 0x7fffffffu;
    }
}
static uint16_t POP_STACK(void){
    uint16_t d = STACK[3];
    STACK[3]=STACK[2]; STACK[2]=STACK[1]; STACK[1]=STACK[0];
    return d & 0xfff;
}
static void PUSH_STACK(uint16_t d){
    STACK[0]=STACK[1]; STACK[1]=STACK[2]; STACK[2]=STACK[3];
    STACK[3] = d & 0xfff;
}
static void UPDATE_AR(void){
    if(OPL & 0x30){
        uint16_t t = AR[ARP];
        if(OPL & 0x20) t++;
        if(OPL & 0x10) t--;
        AR[ARP] = (AR[ARP] & 0xfe00) | (t & 0x01ff);
    }
}
static void UPDATE_ARP(void){
    if(~OPL & 0x08){ if(OPL & 0x01) SET_FLAG(ARP_REG); else CLR(ARP_REG); }
}
static void getdata(uint8_t shift, uint8_t signext){
    memaccess = (OPL & 0x80) ? IND : DMA_DP;
    ALU = rd_ram(memaccess);
    if(signext) ALU = (uint32_t)(int32_t)(int16_t)ALU;
    ALU <<= shift;
    if(OPL & 0x80){ UPDATE_AR(); UPDATE_ARP(); }
}
static void putdata(uint16_t data){
    memaccess = (OPL & 0x80) ? IND : DMA_DP;
    if(OPL & 0x80){ UPDATE_AR(); UPDATE_ARP(); }
    wr_ram(memaccess, data);
}
static void putdata_sar(uint8_t idx){
    memaccess = (OPL & 0x80) ? IND : DMA_DP;
    if(OPL & 0x80){ UPDATE_AR(); UPDATE_ARP(); }
    wr_ram(memaccess, AR[idx]);
}
static void putdata_sst(uint16_t data){
    memaccess = (OPL & 0x80) ? IND : DMA_DP1;
    if(OPL & 0x80){ UPDATE_AR(); }
    wr_ram(memaccess, data);
}

static void ext_irq(void){
    /* Ext_IRQ(): only taken when INTM is clear. Masks further interrupts,
     * pushes the address of the instruction that was about to run, and
     * vectors to 0x0002. */
    if(INTM) return;
    INTF = 0;
    SET_FLAG(INTM_FLAG);
    PUSH_STACK(PC);
    PC = 2;
}

/* MAME will not service an interrupt straight after MPY, MPYK or EINT. */
static int int_blocked(void){
    uint16_t h = (prev_opcode >> 8) & 0xff;
    return (h == 0x6d) || ((h & 0xe0) == 0x80) || (prev_opcode == 0x7f82);
}

/* ------------------------------------------------------------------------
 * Toaplan TP-009 DSP subsystem: the window into host memory, the polled BIO
 * handshake, and the interlock that halts the host CPU.
 * From toaplan/toaplan_dsp.cpp and wardner_state::dsp_host_*_cb.
 * ---------------------------------------------------------------------- */
#define TP_WORK 0
#define TP_OBJ  1
#define TP_PAL  2
#define TP_NONE 3

static uint16_t tp_ram[3][2048];
static int      tp_sel      = TP_NONE;
static uint16_t tp_addr     = 0;      /* word index */
static int      tp_bio_line = 0;
static int      tp_execute  = 0;
static int      tp_halt     = 0;      /* host CPU halted */
static FILE    *tp_log      = NULL;

static int tp_bio(void){ return tp_bio_line; }

static void tp_decode(uint16_t data){
    /* Wardner: seg = data & 0xe000 with 0x6000 folded onto 0x7000. Because
     * 0x7000 & 0xe000 is itself 0x6000, both share the same top three bits.
     * offset = (data & 0x07ff) << 1, i.e. the word index is data & 0x7ff. */
    switch((data >> 13) & 7){
    case 3:  tp_sel = TP_WORK; break;   /* 0x6000 / 0x7000 */
    case 4:  tp_sel = TP_OBJ;  break;   /* 0x8000 */
    case 5:  tp_sel = TP_PAL;  break;   /* 0xa000 */
    default: tp_sel = TP_NONE; break;
    }
    tp_addr = data & 0x07ff;
}

static uint16_t tp_in(int port){
    uint16_t v = 0;
    if(port == 1){
        /* a window pointing at no host RAM reads back as zero */
        if(tp_sel != TP_NONE) v = tp_ram[tp_sel][tp_addr];
        if(tp_log) fprintf(tp_log, "r %d %04x %04x\n", tp_sel, tp_addr, v);
    }
    return v;
}

static void tp_out(int port, uint16_t val){
    switch(port){
    case 0:
        tp_decode(val);
        if(tp_log) fprintf(tp_log, "p %d %04x\n", tp_sel, tp_addr);
        break;
    case 1:
        if(tp_sel != TP_NONE){
            tp_ram[tp_sel][tp_addr] = val;
            if(tp_log) fprintf(tp_log, "w %d %04x %04x\n", tp_sel, tp_addr, val);
        }
        /* a zero into work RAM word 0 or 1 arms the host release */
        if(tp_sel == TP_WORK && tp_addr < 2 && val == 0) tp_execute = 1;
        break;
    case 3:
        if(val & 0x8000) tp_bio_line = 0;
        if(val == 0){
            if(tp_execute){ tp_halt = 0; tp_execute = 0; }
            tp_bio_line = 1;
        }
        if(tp_log) fprintf(tp_log, "c %04x %d %d %d\n",
                           val, tp_bio_line, tp_execute, tp_halt);
        break;
    default: break;
    }
}

static void reset_cpu(void){
    PC=0; ACC=0; INTF=0; ALU=0; Preg=0; Treg=0;
    AR[0]=AR[1]=0; STACK[0]=STACK[1]=STACK[2]=STACK[3]=0;
    opcode=0; prev_opcode=0x7f80; oldacc=0; memaccess=0; STR=0;
    CLR(OV_FLAG|ARP_REG|DP_REG);
    SET_FLAG(OVM_FLAG|INTM_FLAG);
}

/* MAME's cycle table, collapsed: everything is one machine cycle except the
 * entries below, and a conditional branch costs one more when it is taken. */
static int cyc_of(uint16_t w, int taken){
    uint16_t h = (w >> 8) & 0xff;
    if(h == 0x67 || h == 0x7d) return 3;                 /* TBLR / TBLW */
    if((h >= 0x40 && h <= 0x4f) || h == 0xf8 || h == 0xf9) return 2;
    if(h == 0x7f){ uint8_t l = w & 0x1f;
        if(l==0x0c||l==0x0d||l==0x1c||l==0x1d) return 2; }
    if(h==0xf4||h==0xf5||h==0xf6||(h>=0xfa&&h<=0xff)) return taken ? 2 : 1;
    return 1;
}

static void execute_one(void){
    uint16_t o;
    uint16_t pc_before;
    opcode = ROM[PC & 0xfff];
    pc_before = PC;
    PC++;
    o = OPH;

    if(o <= 0x0f){ /* ADD */
        oldacc = ACC; getdata(o & 0xf, 1); ACC += ALU; CALC_ADD_OVF(ALU);
    } else if(o <= 0x1f){ /* SUB */
        oldacc = ACC; getdata(o & 0xf, 1); ACC -= ALU; CALC_SUB_OVF(ALU);
    } else if(o <= 0x2f){ /* LAC */
        getdata(o & 0x0f, 1); ACC = ALU;
    } else if(o == 0x30 || o == 0x31){ putdata_sar(o & 1);
    } else if(o == 0x38){ getdata(0,0); AR[0] = ALU & 0xffff;
    } else if(o == 0x39){ getdata(0,0); AR[1] = ALU & 0xffff;
    } else if(o >= 0x40 && o <= 0x47){ ALU = port_in(o & 7); putdata(ALU & 0xffff);
    } else if(o >= 0x48 && o <= 0x4f){ getdata(0,0); port_out(o & 7, ALU & 0xffff);
    } else if(o == 0x50){ putdata(ACC & 0xffff);
    } else if(o >= 0x58 && o <= 0x5f){ ALU = ACC << (o & 7); putdata((ALU>>16) & 0xffff);
    } else if(o == 0x60){ /* ADDH */
        uint16_t oldh, newh;
        oldacc = ACC; getdata(0,0);
        oldh = (uint16_t)(ACC >> 16);
        newh = (uint16_t)(oldh + (uint16_t)ALU);
        ACC = (ACC & 0xffff) | ((uint32_t)newh << 16);
        if((int16_t)(~(oldh ^ (uint16_t)ALU) & (oldh ^ newh)) < 0){
            SET_FLAG(OV_FLAG);
            if(OVM) ACC = (ACC & 0xffff) |
                          ((uint32_t)(((int16_t)oldh < 0) ? 0x8000 : 0x7fff) << 16);
        }
    } else if(o == 0x61){ oldacc=ACC; getdata(0,0); ACC += ALU; CALC_ADD_OVF(ALU);
    } else if(o == 0x62){ oldacc=ACC; getdata(16,0); ACC -= ALU; CALC_SUB_OVF(ALU);
    } else if(o == 0x63){ oldacc=ACC; getdata(0,0); ACC -= ALU; CALC_SUB_OVF(ALU);
    } else if(o == 0x64){ /* SUBC */
        oldacc = ACC; getdata(15,0);
        ALU = (uint32_t)((int32_t)ACC - (int32_t)ALU);
        if((int32_t)((oldacc ^ ALU) & (oldacc ^ ACC)) < 0) SET_FLAG(OV_FLAG);
        if((int32_t)ALU >= 0) ACC = (ALU << 1) + 1; else ACC = ACC << 1;
    } else if(o == 0x65){ getdata(0,0); ACC = (ALU & 0xffff) << 16;
    } else if(o == 0x66){ getdata(0,0); ACC = ALU & 0xffff;
    } else if(o == 0x67){ /* TBLR */
        ALU = ROM[ACC & 0xfff]; putdata(ALU & 0xffff); STACK[0] = STACK[1];
    } else if(o == 0x68){ if(OPL & 0x80){ UPDATE_AR(); UPDATE_ARP(); }
    } else if(o == 0x69){ getdata(0,0); wr_ram(memaccess+1, ALU & 0xffff);
    } else if(o == 0x6a){ getdata(0,0); Treg = ALU & 0xffff;
    } else if(o == 0x6b){ oldacc=ACC; getdata(0,0); Treg = ALU & 0xffff;
                          wr_ram(memaccess+1, ALU & 0xffff);
                          ACC += Preg; CALC_ADD_OVF(Preg);
    } else if(o == 0x6c){ oldacc=ACC; getdata(0,0); Treg = ALU & 0xffff;
                          ACC += Preg; CALC_ADD_OVF(Preg);
    } else if(o == 0x6d){ getdata(0,0);
                          Preg = (uint32_t)((int32_t)(int16_t)(ALU & 0xffff) * (int32_t)(int16_t)Treg);
                          if(Preg == 0x40000000u) Preg = 0xc0000000u;
    } else if(o == 0x6e){ if(OPL & 1) SET_FLAG(DP_REG); else CLR(DP_REG);
    } else if(o == 0x6f){ getdata(0,0); if(ALU & 1) SET_FLAG(DP_REG); else CLR(DP_REG);
    } else if(o == 0x70){ AR[0] = OPL;
    } else if(o == 0x71){ AR[1] = OPL;
    } else if(o == 0x78){ getdata(0,0); ACC = (ACC & 0xffff0000u) | ((ACC ^ ALU) & 0xffff);
    } else if(o == 0x79){ getdata(0,0); ACC &= ALU;
    } else if(o == 0x7a){ getdata(0,0); ACC = (ACC & 0xffff0000u) | ((ACC | ALU) & 0xffff);
    } else if(o == 0x7b){ /* LST */
        if(OPL & 0x80) opcode |= 0x0008;
        getdata(0,0);
        ALU &= (uint32_t)(~INTM_FLAG) & 0xffff;
        STR &= INTM_FLAG; STR |= (uint16_t)ALU; STR |= 0x1efe;
    } else if(o == 0x7c){ putdata_sst(STR);
    } else if(o == 0x7d){ getdata(0,0); /* TBLW: program space is ROM */ STACK[0]=STACK[1];
    } else if(o == 0x7e){ ACC = OPL;
    } else if(o == 0x7f){
        switch(OPL & 0x1f){
        case 0x00: break;                                   /* NOP  */
        case 0x01: SET_FLAG(INTM_FLAG); break;              /* DINT */
        case 0x02: CLR(INTM_FLAG); break;                   /* EINT */
        case 0x08: if((int32_t)ACC < 0){ ACC = (uint32_t)(-(int32_t)ACC);
                       if(OVM && ACC == 0x80000000u) ACC--; } break;   /* ABS */
        case 0x09: ACC = 0; break;                          /* ZAC  */
        case 0x0a: CLR(OVM_FLAG); break;                    /* ROVM */
        case 0x0b: SET_FLAG(OVM_FLAG); break;               /* SOVM */
        case 0x0c: PUSH_STACK(PC); PC = ACC & 0xfff; break; /* CALA */
        case 0x0d: PC = POP_STACK(); break;                 /* RET  */
        case 0x0e: ACC = Preg; break;                       /* PAC  */
        case 0x0f: oldacc=ACC; ACC += Preg; CALC_ADD_OVF(Preg); break;  /* APAC */
        case 0x10: oldacc=ACC; ACC -= Preg; CALC_SUB_OVF(Preg); break;  /* SPAC */
        case 0x1c: PUSH_STACK(ACC & 0xffff); break;         /* PUSH */
        case 0x1d: ACC = POP_STACK(); break;                /* POP  */
        default: break;
        }
    } else if(o >= 0x80 && o <= 0x9f){ /* MPYK */
        int16_t k = (int16_t)((uint16_t)(opcode << 3)) >> 3;
        Preg = (uint32_t)((int32_t)(int16_t)Treg * (int32_t)k);
    } else if(o == 0xf4){ /* BANZ */
        uint16_t t;
        if(AR[ARP] & 0x01ff) PC = ROM[PC & 0xfff] & 0xffff; else PC++;
        t = AR[ARP]; t--;
        AR[ARP] = (AR[ARP] & 0xfe00) | (t & 0x01ff);
    } else if(o == 0xf5){ if(OV){ CLR(OV_FLAG); PC = ROM[PC & 0xfff]; } else PC++;
    } else if(o == 0xf6){ if(bio_in()) PC = ROM[PC & 0xfff]; else PC++;
    } else if(o == 0xf8){ PC++; PUSH_STACK(PC); PC = ROM[(PC-1) & 0xfff];
    } else if(o == 0xf9){ PC = ROM[PC & 0xfff];
    } else if(o == 0xfa){ if((int32_t)ACC <  0) PC = ROM[PC & 0xfff]; else PC++;
    } else if(o == 0xfb){ if((int32_t)ACC <= 0) PC = ROM[PC & 0xfff]; else PC++;
    } else if(o == 0xfc){ if((int32_t)ACC >  0) PC = ROM[PC & 0xfff]; else PC++;
    } else if(o == 0xfd){ if((int32_t)ACC >= 0) PC = ROM[PC & 0xfff]; else PC++;
    } else if(o == 0xfe){ if(ACC != 0) PC = ROM[PC & 0xfff]; else PC++;
    } else if(o == 0xff){ if(ACC == 0) PC = ROM[PC & 0xfff]; else PC++;
    }
    PC &= 0xfff;
    /* a conditional branch was taken if PC did not simply step past the operand */
    mcycles += cyc_of(opcode, (PC & 0xfff) != ((pc_before + 2) & 0xfff));
    prev_opcode = opcode;
}

int main(int argc, char **argv){
    FILE *f; char line[64]; int n = 0; long steps, i, irq_period = 0;
    if(argc < 3){ fprintf(stderr, "usage: ref32010 <prog.hex> <steps> [irq_period]\n"); return 2; }
    f = fopen(argv[1], "r");
    if(!f){ perror(argv[1]); return 2; }
    while(n < 4096 && fgets(line, sizeof line, f)) ROM[n++] = (uint16_t)strtoul(line, NULL, 16);
    fclose(f);
    steps = strtol(argv[2], NULL, 10);
    if(argc > 3 && !strcmp(argv[3], "toaplan")) toaplan_mode = 1;
    else if(argc > 3 && !strcmp(argv[3], "toaplanfree"))  toaplan_mode = 2;
    else if(argc > 3 && !strcmp(argv[3], "toaplantrace")) toaplan_mode = 3;
    else if(argc > 3) irq_period = strtol(argv[3], NULL, 10);

    if(toaplan_mode == 2 || toaplan_mode == 3){
        /* Free run: the run bit stays asserted and the DSP is simply let go for
         * a fixed number of instructions, whether or not it ever releases the
         * host. Real command data would come from the Z80, so with synthetic
         * data the code may loop forever - which is itself worth comparing. */
        long k, insns = (argc > 4) ? strtol(argv[4], NULL, 10) : 20000;
        long hseed    = (argc > 5) ? strtol(argv[5], NULL, 10) : 0;
        tp_log = stdout;
        reset_cpu();
        for(k = 0; k < 2048; k++){
            tp_ram[TP_WORK][k] = (uint16_t)(k * 0x1234 + hseed * 0x5f5f);
            tp_ram[TP_OBJ][k]  = (uint16_t)(k * 0x0055 + hseed * 0x1111);
            tp_ram[TP_PAL][k]  = (uint16_t)(k * 0x0007 + hseed * 0x2222);
        }
        if(toaplan_mode == 3) tp_log = NULL;   /* trace instead of transactions */
        INTF = 1; tp_halt = 1;
        for(k = 0; k < insns; k++){
            if(INTF && !int_blocked()) ext_irq();
            if(toaplan_mode == 3)
                printf("%03x %04x %08x %08x %04x %04x %04x %04x %03x %03x %03x %03x\n",
                       PC & 0xfff, ROM[PC & 0xfff], ACC, Preg, Treg, AR[0], AR[1],
                       STR, STACK[0]&0xfff, STACK[1]&0xfff, STACK[2]&0xfff, STACK[3]&0xfff);
            execute_one();
            icount++;
        }
        return 0;
    }

    if(toaplan_mode){
        long act, k, acts = (argc > 4) ? strtol(argv[4], NULL, 10) : 4;
        long hseed = (argc > 5) ? strtol(argv[5], NULL, 10) : 0;
        tp_log = stdout;
        reset_cpu();
        /* deterministic host memory, matched by the bench */
        for(k = 0; k < 2048; k++){
            tp_ram[TP_WORK][k] = (uint16_t)(k * 0x1234 + hseed * 0x5f5f);
            tp_ram[TP_OBJ][k]  = (uint16_t)(k * 0x0055 + hseed * 0x1111);
            tp_ram[TP_PAL][k]  = (uint16_t)(k * 0x0007 + hseed * 0x2222);
        }
        for(act = 0; act < acts; act++){
            printf("A %ld\n", act);
            /* the host raises the run bit: interrupt the DSP, stop the host */
            INTF   = 1;
            tp_halt = 1;
            for(k = 0; k < steps && tp_halt; k++){
                if(INTF && !int_blocked()) ext_irq();
                execute_one();
                icount++;
            }
            if(tp_halt){ printf("X stuck after %ld instructions\n", k); return 1; }
            printf("H %ld\n", act);
            /* the host is running again; the DSP keeps going until the run bit
             * is cleared. The program issues no further transactions here, so
             * the exact length of this tail does not affect the log. */
            for(k = 0; k < 200; k++){
                if(INTF && !int_blocked()) ext_irq();
                execute_one();
                icount++;
            }
            printf("E %ld\n", act);
        }
        return 0;
    }
    reset_cpu();
    for(i = 0; i < steps; i++){
        if(INTF && !int_blocked()) ext_irq();
        printf("%03x %04x %08x %08x %04x %04x %04x %04x %03x %03x %03x %03x\n",
               PC & 0xfff, ROM[PC & 0xfff], ACC, Preg, Treg, AR[0], AR[1], STR,
               STACK[0]&0xfff, STACK[1]&0xfff, STACK[2]&0xfff, STACK[3]&0xfff);
        execute_one();
        if(irq_period && (icount % irq_period) == 13) INTF = 1;
        icount++;
    }
    fprintf(stderr, "machine_cycles %ld instructions %ld\n", mcycles, icount);
    return 0;
}
