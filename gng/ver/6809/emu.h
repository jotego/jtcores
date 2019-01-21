/* Structures and defines for Larry's Arcade Emulator */
/* Written by Larry Bank */
/* Copyright 1998 BitBank Software, Inc. */
/* Project started 1/7/98 */

// #define PORTABLE /* Used for compiling no ASM code into the project */


/* Pending interrupt bits */
#define INT_NMI  1
#define INT_FIRQ 2
#define INT_IRQ  4

/* Memory map emulation offsets */
#define MEM_ROM   0x00000 /* Offset to first bank (ROM) */
#define MEM_RAM   0x10000 /* Offset to second bank (RAM) */
#define MEM_FLAGS 0x20000 /* Offset to flags in memory map */

/* Definitions for external memory read and write routines */
typedef unsigned char (*MEMRPROC)(unsigned short);
typedef void (*MEMWPROC)(unsigned short, unsigned char);

/* Structure to pass to CPU emulator with memory handler routines */
typedef struct tagEMUHANDLERS
{
   MEMRPROC pfn_read;
   MEMWPROC pfn_write;

} EMUHANDLERS;

/* 6809 registers */
typedef struct tagREGS6809
{
    unsigned short usRegX;
    unsigned short usRegY;
    unsigned short usRegU;
    unsigned short usRegS;
    unsigned short usRegPC;
    union
       {
       unsigned short usRegD;
       struct
          {
          unsigned char ucRegB; /* On a big-endian machine, reverse A & B */
          unsigned char ucRegA;
          };
       };
    unsigned char ucRegCC;
    unsigned char ucRegDP;
} REGS6809;


/* MC6809 Emulator */
void EXEC6809(char *, REGS6809 *, EMUHANDLERS *, int *, unsigned char *);
void RESET6809(char *, REGS6809 *);
// void AEXEC6809(char *, REGS6809 *, EMUHANDLERS *, int *, unsigned char *);
// void ARESET6809(char *, REGS6809 *);
