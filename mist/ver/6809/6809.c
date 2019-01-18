/*******************************************************************/
/* 6809 CPU emulator written by Larry Bank                         */
/* Copyright 1998 BitBank Software, Inc.                           */
/*                                                                 */
/* This code was written from scratch using the 6809 data from     */
/* the Motorola databook "8-BIT MICROPROCESSOR & PERIPHERAL DATA". */
/*                                                                 */
/* Change history:                                                 */
/* 1/7/98 Wrote it - Larry B.                                      */
/*******************************************************************/
#include <string.h>
#include "emu.h"

#define F_CARRY     1
#define F_OVERFLOW  2
#define F_ZERO      4
#define F_NEGATIVE  8
#define F_IRQMASK   16
#define F_HALFCARRY 32
#define F_FIRQMASK  64

#define SET_V8(a,b,r) regs->ucRegCC |= (((a^b^r^(r>>1))&0x80)>>6)
#define SET_V16(a,b,r) regs->ucRegCC |= (((a^b^r^(r>>1))&0x8000)>>14)
/* Some statics */
EMUHANDLERS *mem_handlers09;
unsigned char *m_map09;

/* Instruction timing for single-byte opcodes */
unsigned char c6809Cycles[256] = {
      6,0,0,6,6,0,6,6,6,6,6,0,6,6,3,6,          /* 00-0F */
      0,0,2,4,0,0,5,9,0,2,3,0,3,2,8,6,          /* 10-1F */
      3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,          /* 20-2F */
      4,4,4,4,5,5,5,5,0,5,3,6,9,11,0,19,        /* 30-3F */
      2,0,0,2,2,0,2,2,2,2,2,0,2,2,0,2,          /* 40-4F */
      2,0,0,2,2,0,2,2,2,2,2,0,2,2,0,2,          /* 50-5F */
      6,0,0,6,6,0,6,6,6,6,6,0,6,6,3,6,          /* 60-6F */
      7,0,0,7,7,0,7,7,7,7,7,0,7,7,4,7,          /* 70-7F */
      2,2,2,4,2,2,2,0,2,2,2,2,4,7,3,0,          /* 80-8F */
      4,4,4,6,4,4,4,4,4,4,4,4,6,7,5,5,          /* 90-9F */
      4,4,4,6,4,4,4,4,4,4,4,4,6,7,5,5,          /* A0-AF */
      5,5,5,7,5,5,5,5,5,5,5,5,7,8,6,6,          /* B0-BF */
      2,2,2,4,2,2,2,0,2,2,2,2,3,0,3,0,          /* C0-CF */
      4,4,4,6,4,4,4,4,4,4,4,4,5,5,5,5,          /* D0-DF */
      4,4,4,6,4,4,4,4,4,4,4,4,5,5,5,5,          /* E0-EF */
      5,5,5,7,5,5,5,5,5,5,5,5,6,6,6,6};         /* F0-FF */

/* Instruction timing for the two-byte opcodes */
unsigned char c6809Cycles2[256] = {
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,          /* 00-0F */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,          /* 10-1F */
      0,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,          /* 20-2F */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,20,         /* 30-3F */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,          /* 40-4F */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,          /* 50-5F */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,          /* 60-6F */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,          /* 70-7F */
      0,0,0,5,0,0,0,0,0,0,0,0,5,0,4,0,          /* 80-8F */
      0,0,0,7,0,0,0,0,0,0,0,0,7,0,6,6,          /* 90-9F */
      0,0,0,7,0,0,0,0,0,0,0,0,7,0,6,6,          /* A0-AF */
      0,0,0,8,0,0,0,0,0,0,0,0,8,0,7,7,          /* B0-BF */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,          /* C0-CF */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,6,          /* D0-DF */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,6,6,          /* E0-EF */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,7,7};         /* F0-FF */

/* Negative and zero flags for quicker flag settings */
unsigned char c6809NZ[256]={
      4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,          /* 00-0F */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,          /* 10-1F */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,          /* 20-2F */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,          /* 30-3F */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,          /* 40-4F */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,          /* 50-5F */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,          /* 60-6F */
      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,          /* 70-7F */
      8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,          /* 80-8F */
      8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,          /* 90-9F */
      8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,          /* A0-AF */
      8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,          /* B0-BF */
      8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,          /* C0-CF */
      8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,          /* D0-DF */
      8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,          /* E0-EF */
      8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8};         /* F0-FF */

void TRACE6809(REGS6809 *);
//#define TRACE

unsigned char M6809ReadByte(unsigned char *, unsigned short);
unsigned short M6809ReadWord(unsigned char *, unsigned short);
__inline void M6809PUSHB(unsigned char *, REGS6809 *, unsigned char);
__inline void M6809PUSHBU(unsigned char *, REGS6809 *, unsigned char);
__inline void M6809PUSHW(unsigned char *, REGS6809 *, unsigned short);
__inline void M6809PUSHWU(unsigned char *, REGS6809 *, unsigned short);
__inline unsigned char M6809PULLB(unsigned char *, REGS6809 *);
__inline unsigned short M6809PULLW(unsigned char *, REGS6809 *);
__inline unsigned char M6809PULLBU(unsigned char *, REGS6809 *);
__inline unsigned short M6809PULLWU(unsigned char *, REGS6809 *);

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : RESET6809(char *, REGS6809 *)                              *
 *                                                                          *
 *  PURPOSE    : Get the 6809 after a reset.                                *
 *                                                                          *
 ****************************************************************************/
void RESET6809(char *mem, REGS6809 *regs)
{
   m_map09 = mem;
   memset(regs, 0, sizeof(REGS6809)); /* Start with a clean slate at reset */
   regs->usRegPC = m_map09[MEM_ROM+0xfffe] * 256 + m_map09[MEM_ROM+0xffff]; /* Start execution at reset vector */
   regs->ucRegCC = 0x50; /* Start with IRQ and FIRQ disabled */

} /* RESET6809() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809PSHS(char *, REGS6809 *, char, int *, short)          *
 *                                                                          *
 *  PURPOSE    : Push multiple registers onto the S stack.                  *
 *                                                                          *
 ****************************************************************************/
void  M6809PSHS(unsigned char *m_map09, REGS6809 *regs, unsigned char ucTemp, int *iClocks, unsigned short PC)
{
int i = 0;

   if (ucTemp & 0x80)
      {
      M6809PUSHW(m_map09, regs, PC);
      i += 2;
      }
   if (ucTemp & 0x40)
      {
      M6809PUSHW(m_map09, regs, regs->usRegU);
      i += 2;
      }
   if (ucTemp & 0x20)
      {
      M6809PUSHW(m_map09, regs, regs->usRegY);
      i += 2;
      }
   if (ucTemp & 0x10)
      {
      M6809PUSHW(m_map09, regs, regs->usRegX);
      i += 2;
      }
   if (ucTemp & 0x8)
      {
      M6809PUSHB(m_map09, regs, regs->ucRegDP);
      i++;
      }
   if (ucTemp & 0x4)
      {
      M6809PUSHB(m_map09, regs, regs->ucRegB);
      i++;
      }
   if (ucTemp & 0x2)
      {
      M6809PUSHB(m_map09, regs, regs->ucRegA);
      i++;
      }
   if (ucTemp & 0x1)
      {
      M6809PUSHB(m_map09, regs, regs->ucRegCC);
      i++;
      }
    *iClocks -= i; /* Add extra clock cycles (1 per byte) */

} /* M6809PSHS() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809PSHU(char *, REGS6809 *, char, int *, short)          *
 *                                                                          *
 *  PURPOSE    : Push multiple registers onto the U stack.                  *
 *                                                                          *
 ****************************************************************************/
void  M6809PSHU(unsigned char *m_map09, REGS6809 *regs, unsigned char ucTemp, int *iClocks, unsigned short PC)
{
int i = 0;

   if (ucTemp & 0x80)
      {
      M6809PUSHWU(m_map09, regs, PC);
      i += 2;
      }
   if (ucTemp & 0x40)
      {
      M6809PUSHWU(m_map09, regs, regs->usRegS);
      i += 2;
      }
   if (ucTemp & 0x20)
      {
      M6809PUSHWU(m_map09, regs, regs->usRegY);
      i += 2;
      }
   if (ucTemp & 0x10)
      {
      M6809PUSHWU(m_map09, regs, regs->usRegX);
      i += 2;
      }
   if (ucTemp & 0x8)
      {
      M6809PUSHBU(m_map09, regs, regs->ucRegDP);
      i++;
      }
   if (ucTemp & 0x4)
      {
      M6809PUSHBU(m_map09, regs, regs->ucRegB);
      i++;
      }
   if (ucTemp & 0x2)
      {
      M6809PUSHBU(m_map09, regs, regs->ucRegA);
      i++;
      }
   if (ucTemp & 0x1)
      {
      M6809PUSHBU(m_map09, regs, regs->ucRegCC);
      i++;
      }
   *iClocks -= i; /* Add extra clocks (1 per byte) */

} /* M6809PSHU() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809PULS(char *, REGS6809 *, char, int *)                 *
 *                                                                          *
 *  PURPOSE    : Pull multiple registers from the S stack.                  *
 *                                                                          *
 ****************************************************************************/
void  M6809PULS(unsigned char *m_map09, REGS6809 *regs, unsigned char ucTemp, int *iClocks, unsigned short *PC)
{
int i=0;

   if (ucTemp & 0x1)
      {
      regs->ucRegCC = M6809PULLB(m_map09, regs);
      i++;
      }
   if (ucTemp & 0x2)
      {
      regs->ucRegA = M6809PULLB(m_map09, regs);
      i++;
      }
   if (ucTemp & 0x4)
      {
      regs->ucRegB = M6809PULLB(m_map09, regs);
      i++;
      }
   if (ucTemp & 0x8)
      {
      regs->ucRegDP = M6809PULLB(m_map09, regs);
      i++;
      }
   if (ucTemp & 0x10)
      {
      regs->usRegX = M6809PULLW(m_map09, regs);
      i += 2;
      }
   if (ucTemp & 0x20)
      {
      regs->usRegY = M6809PULLW(m_map09, regs);
      i += 2;
      }
   if (ucTemp & 0x40)
      {
      regs->usRegU = M6809PULLW(m_map09, regs);
      i += 2;
      }
   if (ucTemp & 0x80)
      {
      *PC = M6809PULLW(m_map09, regs);
      i += 2;
      }
    *iClocks -= i; /* Extra clocks (1 per byte) */
} /* M6809PULS() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809PULU(char *, REGS6809 *, char, int *)                 *
 *                                                                          *
 *  PURPOSE    : Pull multiple registers from the U stack.                  *
 *                                                                          *
 ****************************************************************************/
void  M6809PULU(unsigned char *m_map09, REGS6809 *regs, unsigned char ucTemp, int *iClocks, unsigned short *PC)
{
int i=0;

   if (ucTemp & 0x1)
      {
      regs->ucRegCC = M6809PULLBU(m_map09, regs);
      i++;
      }
   if (ucTemp & 0x2)
      {
      regs->ucRegA = M6809PULLBU(m_map09, regs);
      i++;
      }
   if (ucTemp & 0x4)
      {
      regs->ucRegB = M6809PULLBU(m_map09, regs);
      i++;
      }
   if (ucTemp & 0x8)
      {
      regs->ucRegDP = M6809PULLBU(m_map09, regs);
      i++;
      }
   if (ucTemp & 0x10)
      {
      regs->usRegX = M6809PULLWU(m_map09, regs);
      i += 2;
      }
   if (ucTemp & 0x20)
      {
      regs->usRegY = M6809PULLWU(m_map09, regs);
      i += 2;
      }
   if (ucTemp & 0x40)
      {
      regs->usRegS = M6809PULLWU(m_map09, regs);
      i += 2;
      }
   if (ucTemp & 0x80)
      {
      *PC = M6809PULLWU(m_map09, regs);
      i += 2;
      }
   *iClocks -= i; /* Extra clocks (1 per byte) */

} /* M6809PULU() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809TFREXG(REGS6809 *, char, short *, BOOL)               *
 *                                                                          *
 *  PURPOSE    : Transfer or exchange two registers.                        *
 *                                                                          *
 ****************************************************************************/
void M6809TFREXG(REGS6809 *regs, unsigned char ucPostByte, unsigned short *PC, int bExchange)
{
unsigned short usTemp, *psSReg, *psDReg;
unsigned char ucTemp, *pcSReg, *pcDReg;

   ucTemp = ucPostByte & 0x88;
   if (ucTemp == 0x80 || ucTemp == 0x08)
      ucTemp = 0; /* PROBLEM! */

   switch(ucPostByte & 0xf0) /* Get source register */
      {
      case 0x00: /* D */
         psSReg = &regs->usRegD;
         break;
      case 0x10: /* X */
         psSReg = &regs->usRegX;
         break;
      case 0x20: /* Y */
         psSReg = &regs->usRegY;
         break;
      case 0x30: /* U */
         psSReg = &regs->usRegU;
         break;
      case 0x40: /* S */
         psSReg = &regs->usRegS;
         break;
      case 0x50: /* PC */
         psSReg = PC;
         break;
      case 0x80: /* A */
         pcSReg = &regs->ucRegA;
         break;
      case 0x90: /* B */
         pcSReg = &regs->ucRegB;
         break;
      case 0xA0: /* CC */
         pcSReg = &regs->ucRegCC;
         break;
      case 0xB0: /* DP */
         pcSReg = &regs->ucRegDP;
         break;
      default: /* Illegal */
         pcSReg = NULL;
         break;
      }
   switch(ucPostByte & 0xf) /* Get destination register */
      {
      case 0x00: /* D */
         psDReg = &regs->usRegD;
         break;
      case 0x1: /* X */
         psDReg = &regs->usRegX;
         break;
      case 0x2: /* Y */
         psDReg = &regs->usRegY;
         break;
      case 0x3: /* U */
         psDReg = &regs->usRegU;
         break;
      case 0x4: /* S */
         psDReg = &regs->usRegS;
         break;
      case 0x5: /* PC */
         psDReg = PC;
         break;
      case 0x8: /* A */
         pcDReg = &regs->ucRegA;
         break;
      case 0x9: /* B */
         pcDReg = &regs->ucRegB;
         break;
      case 0xA: /* CC */
         pcDReg = &regs->ucRegCC;
         break;
      case 0xB: /* DP */
         pcDReg = &regs->ucRegDP;
         break;
      default: /* illegal */
         psSReg = NULL;
         break;
      }

/* Perform the exchange or transfer */
    if (ucPostByte & 8)  /* 8 bit exchange */
       {
       if (bExchange)
          {
          ucTemp = *pcSReg;
          *pcSReg = *pcDReg;
          *pcDReg = ucTemp;
          }
       else /* Transfer */
          *pcDReg = *pcSReg;
       }
    else  /* 16 bit exchange */
       {
       if (bExchange)
          {
          usTemp = *psSReg;
          *psSReg = *psDReg;
          *psDReg = usTemp;
          }
       else /* transfer */
          *psDReg = *psSReg;
       }

} /* M6809TFREXG() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809PostByte(REGS6809 *, char *, char, int *)             *
 *                                                                          *
 *  PURPOSE    : Calculate the EA for indexed addressing mode.              *
 *                                                                          *
 ****************************************************************************/
__inline unsigned short M6809PostByte(REGS6809 *regs, unsigned char *m_map09, unsigned short *PC, int *iClocks)
{
register unsigned char ucPostByte;
signed char sByte;
unsigned short *pReg, usAddr;
signed short sTemp;

   ucPostByte = M6809ReadByte(m_map09, (*PC)++);
/* Isolate register is used for the indexed operation */
   switch(ucPostByte & 0x60)
      {
      case 0:
         pReg = &regs->usRegX;
         break;
      case 0x20:
         pReg = &regs->usRegY;
         break;
      case 0x40:
         pReg = &regs->usRegU;
         break;
      case 0x60:
         pReg = &regs->usRegS;
         break;
      }

   if (ucPostByte & 0x80) /* Complex stuff */
      {
      switch (ucPostByte & 0xf)
         {
         case 0: /* EA = ,reg+ */
            usAddr = *pReg;
            *pReg += 1;
            *iClocks -= 2;
            break;
         case 1: /* EA = ,reg++ */
            usAddr = *pReg;
            *pReg += 2;
            *iClocks -= 3;
            break;
         case 2: /* EA = ,-reg */
            *pReg -= 1;
            usAddr = *pReg;
            *iClocks -= 2;
            break;
         case 3: /* EA = ,--reg */
            *pReg -= 2;
            usAddr = *pReg;
            *iClocks -= 3;
            break;
         case 4: /* EA = ,reg */
            usAddr = *pReg;
            break;
         case 5: /* EA = ,reg + B */
            usAddr = *pReg + (signed short)(signed char)regs->ucRegB;
            *iClocks -= 1;
            break;
         case 6: /* EA = ,reg + A */
            usAddr = *pReg + (signed short)(signed char)regs->ucRegA;
            *iClocks -= 1;
            break;
         case 7: /* illegal */
            usAddr = 0;
            break;
         case 8: /* EA = ,reg + 8-bit offset */
            usAddr = *pReg + (signed short)(signed char)M6809ReadByte(m_map09, (*PC)++);
            *iClocks -= 1;
            break;
         case 9: /* EA = ,reg + 16-bit offset */
            usAddr = *pReg + (signed short)M6809ReadWord(m_map09, *PC);
            *PC += 2;
            *iClocks -= 4;
            break;
         case 0xA: /* illegal */
            usAddr = 0;
            break;
         case 0xB: /* EA = ,reg + D */
            *iClocks -= 4;
            usAddr = *pReg + regs->usRegD;
            break;
         case 0xC: /* EA = PC + 8-bit offset */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, (*PC)++);
            usAddr = *PC + sTemp;
            *iClocks -= 1;
            break;
         case 0xD: /* EA = PC + 16-bit offset */
            sTemp =  M6809ReadWord(m_map09, *PC);
            *PC += 2;
            usAddr = *PC + sTemp;
            *iClocks -= 5;
            break;
         case 0xe: /* Illegal */
            usAddr = 0;
            break;
         case 0xF: /* EA = [,address] */
            *iClocks -= 5;
            usAddr = M6809ReadWord(m_map09, *PC);
            *PC += 2;
            break;
         } /* switch */
      if (ucPostByte & 0x10) /* Indirect addressing */
         {
         usAddr = M6809ReadWord(m_map09, usAddr);
         *iClocks -= 3;
         }
      }
   else /* Just a 5 bit signed offset + register */
      {
      sByte = ucPostByte & 0x1f;
      if (sByte > 15) /* Two's complement 5-bit value */
         sByte -= 32;
      usAddr = *pReg + (signed short)sByte;
      *iClocks -= 1;
      }

   return usAddr; /* Return the effective address */

} /* M6809PostByte() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809INC(REGS6809 *, char)                                 *
 *                                                                          *
 *  PURPOSE    : Perform an increment and update flags.                     *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809INC(REGS6809 *regs, unsigned char ucByte)
{
   ucByte++;
   regs->ucRegCC &= ~(F_ZERO | F_OVERFLOW | F_NEGATIVE);
   regs->ucRegCC |= c6809NZ[ucByte];
   if (ucByte == 0x80 || ucByte == 0)
      regs->ucRegCC |= F_OVERFLOW;
   return ucByte;

} /* M6809INC() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809DEC(REGS6809 *, char)                                 *
 *                                                                          *
 *  PURPOSE    : Perform a decrement and update flags.                      *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809DEC(REGS6809 *regs, unsigned char ucByte)
{
   ucByte--;
   regs->ucRegCC &= ~(F_ZERO | F_OVERFLOW | F_NEGATIVE);
   regs->ucRegCC |= c6809NZ[ucByte];
   if (ucByte == 0x7f || ucByte == 0xff)
      regs->ucRegCC |= F_OVERFLOW;
   return ucByte;

} /* M6809DEC() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809SUB(REGS6809 *, char, char)                           *
 *                                                                          *
 *  PURPOSE    : Perform a 8-bit subtraction and update flags.              *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809SUB(REGS6809 *regs, unsigned char ucByte1, unsigned char ucByte2)
{
register unsigned short sTemp;
   sTemp = (unsigned short)ucByte1 - (unsigned short)ucByte2;
   regs->ucRegCC &= ~(F_ZERO | F_CARRY | F_OVERFLOW | F_NEGATIVE);
   regs->ucRegCC |= c6809NZ[sTemp & 0xff];
   if (sTemp & 0x100)
       regs->ucRegCC |= F_CARRY;
   SET_V8(ucByte1, ucByte2, sTemp);
//   if ((sTemp ^ ucByte1 ^ ucByte2 ^ (sTemp>>1)) & 0x80)
//      regs->ucRegCC |= F_OVERFLOW;
   return (unsigned char)(sTemp & 0xff);

} /* M6809SUB() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809SUB16(REGS6809 *, short, short)                       *
 *                                                                          *
 *  PURPOSE    : Perform a 16-bit subtraction and update flags.             *
 *                                                                          *
 ****************************************************************************/
__inline unsigned short M6809SUB16(REGS6809 *regs, unsigned short usWord1, unsigned short usWord2)
{
register unsigned long lTemp;
   lTemp = (unsigned long)usWord1 - (unsigned long)usWord2;
   regs->ucRegCC &= ~(F_ZERO | F_CARRY | F_OVERFLOW | F_NEGATIVE);
   if ((lTemp & 0xffff)== 0) /* DEBUG - probably don't need this */
      regs->ucRegCC |= F_ZERO;
   if (lTemp & 0x8000)
       regs->ucRegCC |= F_NEGATIVE;
   if (lTemp & 0x10000)
       regs->ucRegCC |= F_CARRY;
   SET_V16(usWord1, usWord2, lTemp);
//   if ((lTemp ^ usWord1 ^ usWord2 ^ (lTemp>>1)) & 0x8000)
//      regs->ucRegCC |= F_OVERFLOW;
   return (unsigned short)(lTemp & 0xffff);

} /* M6809SUB16() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809ADD(REGS6809 *, char, char)                           *
 *                                                                          *
 *  PURPOSE    : Perform a 8-bit addition and update flags.                 *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809ADD(REGS6809 *regs, unsigned char ucByte1, unsigned char ucByte2)
{
register unsigned short sTemp;
   sTemp = (unsigned short)ucByte1 + (unsigned short)ucByte2;
   regs->ucRegCC &= ~(F_HALFCARRY | F_CARRY | F_OVERFLOW | F_NEGATIVE | F_ZERO);
   regs->ucRegCC |= c6809NZ[sTemp & 0xff];
   if (sTemp & 0x100)
       regs->ucRegCC |= F_CARRY;
   SET_V8(ucByte1, ucByte2, sTemp);
//   if ((sTemp ^ ucByte1 ^ ucByte2 ^ (sTemp>>1)) & 0x80)
//      regs->ucRegCC |= F_OVERFLOW;
   if ((sTemp ^ ucByte1 ^ ucByte2) & 0x10)
      regs->ucRegCC |= F_HALFCARRY;
   return (unsigned char)(sTemp & 0xff);

} /* M6809ADD() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809ADD16(REGS6809 *, short, short)                       *
 *                                                                          *
 *  PURPOSE    : Perform a 16-bit addition and update flags.                *
 *                                                                          *
 ****************************************************************************/
__inline unsigned short M6809ADD16(REGS6809 *regs, unsigned short usWord1, unsigned short usWord2)
{
register unsigned long lTemp;
   lTemp = (unsigned long)usWord1 + (unsigned long)usWord2;
   regs->ucRegCC &= ~(F_ZERO | F_CARRY | F_OVERFLOW | F_NEGATIVE);
   if ((lTemp & 0xffff)== 0)
      regs->ucRegCC |= F_ZERO;
   if (lTemp & 0x8000)
       regs->ucRegCC |= F_NEGATIVE;
   if (lTemp & 0x10000)
       regs->ucRegCC |= F_CARRY;
   SET_V16(usWord1, usWord2, lTemp);
//   if ((lTemp ^ usWord1 ^ usWord2 ^ (lTemp>>1)) & 0x8000)
//      regs->ucRegCC |= F_OVERFLOW;
   return (unsigned short)(lTemp & 0xffff);

} /* M6809ADD16() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809ADC(REGS6809 *, char, char)                           *
 *                                                                          *
 *  PURPOSE    : Perform a 8-bit addition with carry.                       *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809ADC(REGS6809 *regs, unsigned char ucByte1, unsigned char ucByte2)
{
register unsigned short sTemp;
   sTemp = (unsigned short)ucByte1 + (unsigned short)ucByte2 + (regs->ucRegCC & 1);
   regs->ucRegCC &= ~(F_HALFCARRY | F_ZERO | F_CARRY | F_OVERFLOW | F_NEGATIVE);
   regs->ucRegCC |= c6809NZ[sTemp & 0xff];
   if (sTemp & 0x100)
       regs->ucRegCC |= F_CARRY;
   SET_V8(ucByte1, ucByte2, sTemp);
//   if ((sTemp ^ ucByte1 ^ ucByte2 ^ (sTemp>>1)) & 0x80)
//      regs->ucRegCC |= F_OVERFLOW;
   if ((sTemp ^ ucByte1 ^ ucByte2) & 0x10)
      regs->ucRegCC |= F_HALFCARRY;
   return (unsigned char)(sTemp & 0xff);

} /* M6809ADC() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809SBC(REGS6809 *, char, char)                           *
 *                                                                          *
 *  PURPOSE    : Perform a 8-bit subtraction with carry and update flags.   *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809SBC(REGS6809 *regs, unsigned char ucByte1, unsigned char ucByte2)
{
register unsigned short sTemp;
   sTemp = (unsigned short)ucByte1 - (unsigned short)ucByte2 - (regs->ucRegCC & 1);
   regs->ucRegCC &= ~(F_ZERO | F_CARRY | F_OVERFLOW | F_NEGATIVE);
   regs->ucRegCC |= c6809NZ[sTemp & 0xff];
   if (sTemp & 0x100)
       regs->ucRegCC |= F_CARRY;
   SET_V8(ucByte1, ucByte2, sTemp);
//   if ((sTemp ^ ucByte1 ^ ucByte2 ^ (sTemp>>1)) & 0x80)
//      regs->ucRegCC |= F_OVERFLOW;
   return (unsigned char)(sTemp & 0xff);

} /* M6809SBC() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809CMP(REGS6809 *, char, char)                           *
 *                                                                          *
 *  PURPOSE    : Perform a 8-bit comparison.                                *
 *                                                                          *
 ****************************************************************************/
__inline void M6809CMP(REGS6809 *regs, unsigned char ucByte1, unsigned char ucByte2)
{
register unsigned short sTemp;
   sTemp = (unsigned short)ucByte1 - (unsigned short)ucByte2;
   regs->ucRegCC &= ~(F_ZERO | F_CARRY | F_OVERFLOW | F_NEGATIVE);
   regs->ucRegCC |= c6809NZ[sTemp & 0xff];
   if (sTemp & 0x100)
       regs->ucRegCC |= F_CARRY;
//   if ((sTemp ^ ucByte1 ^ ucByte2 ^ (sTemp>>1)) & 0x80)
//      regs->ucRegCC |= F_OVERFLOW;
   SET_V8(ucByte1, ucByte2, sTemp);

} /* M6809CMP() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809CMP16(REGS6809 *, char, char)                         *
 *                                                                          *
 *  PURPOSE    : Perform a 16-bit comparison.                               *
 *                                                                          *
 ****************************************************************************/
__inline void M6809CMP16(REGS6809 *regs, unsigned short usWord1, unsigned short usWord2)
{
register unsigned long lTemp;
   lTemp = (unsigned long)usWord1 - (unsigned long)usWord2;
   regs->ucRegCC &= ~(F_ZERO | F_CARRY | F_OVERFLOW | F_NEGATIVE);
   if (lTemp == 0)
      regs->ucRegCC |= F_ZERO;
   if (lTemp & 0x8000)
       regs->ucRegCC |= F_NEGATIVE;
   if (lTemp & 0x10000)
       regs->ucRegCC |= F_CARRY;
   SET_V16(usWord1, usWord2, lTemp);
//   if ((lTemp ^ usWord1 ^ usWord2 ^ (lTemp>>1)) & 0x8000)
//      regs->ucRegCC |= F_OVERFLOW;

} /* M6809CMP16() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809LSR(REGS6809 *, char)                                 *
 *                                                                          *
 *  PURPOSE    : Perform a logical shift right and update flags.            *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809LSR(REGS6809 *regs, unsigned char ucByte)
{

   regs->ucRegCC &= ~(F_ZERO | F_CARRY | F_NEGATIVE);
   if (ucByte & 0x01)
      regs->ucRegCC |= F_CARRY;
   ucByte >>= 1;
   if (ucByte == 0)
      regs->ucRegCC |= F_ZERO;
   return ucByte;

} /* M6809LSR() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809ASR(REGS6809 *, char)                                 *
 *                                                                          *
 *  PURPOSE    : Perform a arithmetic shift right and update flags.         *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809ASR(REGS6809 *regs, unsigned char ucByte)
{

   regs->ucRegCC &= ~(F_ZERO | F_CARRY | F_NEGATIVE);
   if (ucByte & 0x01)
      regs->ucRegCC |= F_CARRY;
   ucByte = ucByte & 0x80 | ucByte >>1;
   regs->ucRegCC |= c6809NZ[ucByte];

   return ucByte;

} /* M6809ASR() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809ASL(REGS6809 *, char)                                 *
 *                                                                          *
 *  PURPOSE    : Perform a arithmetic shift left and update flags.          *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809ASL(REGS6809 *regs, unsigned char ucByte)
{
unsigned short usOld = (unsigned short)ucByte;

   regs->ucRegCC &= ~(F_ZERO | F_CARRY | F_OVERFLOW | F_NEGATIVE);
   if (ucByte & 0x80)
      regs->ucRegCC |= F_CARRY;
   ucByte <<=1;
   regs->ucRegCC |= c6809NZ[ucByte];
   if ((usOld ^ ucByte) & 0x80)
      regs->ucRegCC |= F_OVERFLOW;
   return ucByte;

} /* M6809ASL() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809ROL(REGS6809 *, char)                                 *
 *                                                                          *
 *  PURPOSE    : Perform a rotate left and update flags.                    *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809ROL(REGS6809 *regs, unsigned char ucByte)
{
unsigned char ucOld = ucByte;
unsigned char uc;

   uc = regs->ucRegCC & 1; /* Preserve old carry flag */
   regs->ucRegCC &= ~(F_ZERO | F_CARRY | F_OVERFLOW | F_NEGATIVE);
   if (ucByte & 0x80)
      regs->ucRegCC |= F_CARRY;
   ucByte = ucByte <<1 | uc;
   regs->ucRegCC |= c6809NZ[ucByte];
   if ((ucOld ^ ucByte) & 0x80)
      regs->ucRegCC |= F_OVERFLOW;
   return ucByte;

} /* M6809ROL() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809EOR(REGS6809 *, char, char)                           *
 *                                                                          *
 *  PURPOSE    : Perform an exclusive or and update flags.                  *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809EOR(REGS6809 *regs, unsigned char ucByte1, char ucByte2)
{
register unsigned char ucTemp;

   regs->ucRegCC &= ~(F_ZERO | F_OVERFLOW | F_NEGATIVE);
   ucTemp = ucByte1 ^ ucByte2;
   regs->ucRegCC |= c6809NZ[ucTemp];
   return ucTemp;

} /* M6809EOR() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809OR(REGS6809 *, char, char)                           *
 *                                                                          *
 *  PURPOSE    : Perform an inclusive or and update flags.                  *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809OR(REGS6809 *regs, unsigned char ucByte1, char ucByte2)
{
register unsigned char ucTemp;

   regs->ucRegCC &= ~(F_ZERO | F_OVERFLOW | F_NEGATIVE);
   ucTemp = ucByte1 | ucByte2;
   regs->ucRegCC |= c6809NZ[ucTemp];
   return ucTemp;

} /* M6809OR() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809AND(REGS6809 *, char, char)                           *
 *                                                                          *
 *  PURPOSE    : Perform an AND and update flags.                           *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809AND(REGS6809 *regs, unsigned char ucByte1, char ucByte2)
{
register unsigned char ucTemp;

   regs->ucRegCC &= ~(F_ZERO | F_OVERFLOW | F_NEGATIVE);
   ucTemp = ucByte1 & ucByte2;
   regs->ucRegCC |= c6809NZ[ucTemp];
   return ucTemp;

} /* M6809AND() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809COM(REGS6809 *, char)                                 *
 *                                                                          *
 *  PURPOSE    : Perform a 1's complement and update flags.                 *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809COM(REGS6809 *regs, unsigned char ucByte)
{

   regs->ucRegCC &= ~(F_ZERO | F_OVERFLOW | F_NEGATIVE);
   regs->ucRegCC |= F_CARRY;
   ucByte = ~ucByte;
   regs->ucRegCC |= c6809NZ[ucByte];
   return ucByte;

} /* M6809COM() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809NEG(REGS6809 *, char)                                 *
 *                                                                          *
 *  PURPOSE    : Perform a 2's complement and update flags.                 *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809NEG(REGS6809 *regs, unsigned char ucByte)
{

   regs->ucRegCC &= ~(F_CARRY | F_ZERO | F_OVERFLOW | F_NEGATIVE);
   if (ucByte == 0x80)
      regs->ucRegCC |= F_OVERFLOW;
   ucByte = ~ucByte + 1;
   if (ucByte == 0)
      regs->ucRegCC |= F_ZERO;
   if (ucByte & 0x80)
      regs->ucRegCC |= F_NEGATIVE | F_CARRY;
   return ucByte;

} /* M6809NEG() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809ROR(REGS6809 *, char)                                 *
 *                                                                          *
 *  PURPOSE    : Perform a rotate right and update flags.                   *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809ROR(REGS6809 *regs, unsigned char ucByte)
{
unsigned char uc;

   uc = regs->ucRegCC & 1; /* Preserve old carry flag */
   regs->ucRegCC &= ~(F_ZERO | F_CARRY | F_NEGATIVE);
   if (ucByte & 0x01)
      regs->ucRegCC |= F_CARRY;
   ucByte = ucByte >> 1 | uc << 7;
   regs->ucRegCC |= c6809NZ[ucByte];
   return ucByte;

} /* M6809ROR() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809WriteByte(char *, short, char)                        *
 *                                                                          *
 *  PURPOSE    : Write a byte to memory, check for hardware.                *
 *                                                                          *
 ****************************************************************************/
__inline void M6809WriteByte(unsigned char *m_map09, unsigned short usAddr, unsigned char ucByte)
{
unsigned char c;

   switch(c = m_map09[usAddr+MEM_FLAGS]) /* If special flag (ROM or hardware) */
      {
      case 0: /* Normal RAM */
         m_map09[usAddr+MEM_RAM] = ucByte;
         break;
      case 1: /* Normal ROM - nothing to do */
         c = 0;
         break;
      default: /* Call special handler routine for this address */
         (mem_handlers09[c-2].pfn_write)(usAddr, ucByte);
         break;
      }

} /* M6809WriteByte() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809WriteWord(char *, short, short)                       *
 *                                                                          *
 *  PURPOSE    : Write a word to memory, check for hardware.                *
 *                                                                          *
 ****************************************************************************/
__inline void M6809WriteWord(unsigned char *m_map09, unsigned short usAddr, unsigned short usWord)
{
unsigned char c;

/* Doubling the code size to ensure that it gets inlined */
   switch(c = m_map09[usAddr+MEM_FLAGS]) /* If special flag (ROM or hardware) */
      {
      case 0: /* Normal RAM */
         m_map09[usAddr+MEM_RAM] = usWord >> 8;
         break;
      case 1: /* Normal ROM - nothing to do */
         c = 0;
         break;
      default: /* Call special handler routine for this address */
         (mem_handlers09[c-2].pfn_write)(usAddr, (unsigned char)(usWord >> 8));
         break;
      }
/* Check flags again in case someone is doing something tricky */
   usAddr++;
   switch(c = m_map09[usAddr+MEM_FLAGS]) /* If special flag (ROM or hardware) */
      {
      case 0: /* Normal RAM */
         m_map09[usAddr+MEM_RAM] = usWord & 0xff;
         break;
      case 1: /* Normal ROM - nothing to do */
         c = 0;
         break;
      default: /* Call special handler routine for this address */
         (mem_handlers09[c-2].pfn_write)(usAddr, (unsigned char)(usWord & 0xff));
         break;
      }
} /* M6809WriteWord() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809FlagsNZ16(M6809REGS *, short)                         *
 *                                                                          *
 *  PURPOSE    : Set appropriate flags for 16 bit value.                    *
 *                                                                          *
 ****************************************************************************/
__inline void M6809FlagsNZ16(REGS6809 *regs, unsigned short usWord)
{
    regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE);
    if (usWord == 0)
       regs->ucRegCC |= F_ZERO;
    if (usWord & 0x8000)
       regs->ucRegCC |= F_NEGATIVE;

} /* M6809FlagsNZ16() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809ReadByte(char *, short)                               *
 *                                                                          *
 *  PURPOSE    : Read a byte from memory, check for hardware.               *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809ReadByte(unsigned char *m_map09, unsigned short usAddr)
{
unsigned char c;
   switch(c = m_map09[usAddr+MEM_FLAGS]) /* If special flag (ROM or hardware) */
      {
      case 0: /* Normal RAM */
         return m_map09[usAddr+MEM_RAM]; /* Just return it */
         break;
      case 1: /* Normal ROM */
         return m_map09[usAddr+MEM_ROM]; /* Just return it */
         break;
      default: /* Call special handler routine for this address */
         return (mem_handlers09[c-2].pfn_read)(usAddr);
         break;
      }

} /* M6809ReadByte() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809ReadWord(char *, short)                               *
 *                                                                          *
 *  PURPOSE    : Read a word from memory, check for hardware.               *
 *                                                                          *
 ****************************************************************************/
__inline unsigned short M6809ReadWord(unsigned char *m_map09, unsigned short usAddr)
{
unsigned char c;
unsigned short usWord;

/* Doubling the code size to ensure that it gets inlined */
   switch(c = m_map09[usAddr+MEM_FLAGS]) /* If special flag (ROM or hardware) */
      {
      case 0: /* Normal RAM */
         usWord = m_map09[usAddr+MEM_RAM] << 8; /* Just return it */
         break;
      case 1: /* Normal ROM */
         usWord = m_map09[usAddr+MEM_ROM] << 8; /* Just return it */
         break;
      default: /* Call special handler routine for this address */
         usWord = (mem_handlers09[c-2].pfn_read)(usAddr) << 8;
         break;
      }
   usAddr++;
/* Re-check flags in case someone is doing something tricky */
   switch(c = m_map09[usAddr+MEM_FLAGS]) /* If special flag (ROM or hardware) */
      {
      case 0: /* Normal RAM */
         usWord += m_map09[usAddr+MEM_RAM]; /* Just return it */
         break;
      case 1: /* Normal ROM */
         usWord += m_map09[usAddr+MEM_ROM]; /* Just return it */
         break;
      default: /* Call special handler routine for this address */
         usWord += (mem_handlers09[c-2].pfn_read)(usAddr);
         break;
      }
    return usWord;

} /* M6809ReadWord() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809PUSHB(char *, REGS6809 *, char)                       *
 *                                                                          *
 *  PURPOSE    : Push a byte to the 'S' stack.                              *
 *                                                                          *
 ****************************************************************************/
__inline void M6809PUSHB(unsigned char *m_map09, REGS6809 *regs, unsigned char ucByte)
{
unsigned char c;

   switch(c = m_map09[--regs->usRegS + MEM_FLAGS]) /* If special flag (ROM or hardware) */
      {
      case 0: /* Normal RAM */
         m_map09[regs->usRegS + MEM_RAM] = ucByte;
         break;
      case 1: /* Normal ROM - nothing to do */
         break;
      default: /* Call special handler routine for this address */
         (mem_handlers09[c-2].pfn_write)(regs->usRegS, ucByte);
         break;
      }

} /* M6809PUSHB() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809PUSHBU(char *, REGS6809 *, char)                      *
 *                                                                          *
 *  PURPOSE    : Push a byte to the 'U' stack.                              *
 *                                                                          *
 ****************************************************************************/
__inline void M6809PUSHBU(unsigned char *m_map09, REGS6809 *regs, unsigned char ucByte)
{

   M6809WriteByte(m_map09, --regs->usRegU, ucByte);

} /* M6809PUSHBU() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809PUSHW(char *, REGS6809 *)                             *
 *                                                                          *
 *  PURPOSE    : Push a word to the 'S' stack.                              *
 *                                                                          *
 ****************************************************************************/
__inline void M6809PUSHW(unsigned char *m_map09, REGS6809 *regs, unsigned short usWord)
{

unsigned char c;

   switch(c = m_map09[--regs->usRegS + MEM_FLAGS]) /* If special flag (ROM or hardware) */
      {
      case 0: /* Normal RAM */
         m_map09[regs->usRegS + MEM_RAM] = usWord & 0xff;
         break;
      case 1: /* Normal ROM - nothing to do */
         break;
      default: /* Call special handler routine for this address */
         (mem_handlers09[c-2].pfn_write)(regs->usRegS, (unsigned char)(usWord & 0xff));
         break;
      }
/* Check the flags again in case someone is trying to be tricky */
   switch(c = m_map09[--regs->usRegS + MEM_FLAGS]) /* If special flag (ROM or hardware) */
      {
      case 0: /* Normal RAM */
         m_map09[regs->usRegS + MEM_RAM] = usWord >> 8;
         break;
      case 1: /* Normal ROM - nothing to do */
         break;
      default: /* Call special handler routine for this address */
         (mem_handlers09[c-2].pfn_write)(regs->usRegS, (unsigned char)(usWord >> 8));
         break;
      }

} /* M6809PUSHW() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809PUSHWU(char *, REGS6809 *)                            *
 *                                                                          *
 *  PURPOSE    : Push a word to the 'U' stack.                              *
 *                                                                          *
 ****************************************************************************/
__inline void M6809PUSHWU(unsigned char *m_map09, REGS6809 *regs, unsigned short usWord)
{

   M6809WriteByte(m_map09, --regs->usRegU, (unsigned char)(usWord & 0xff));
   M6809WriteByte(m_map09, --regs->usRegU, (unsigned char)(usWord >> 8));

} /* M6809PUSHWU() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809PULLB(char *, REGS6809 *)                             *
 *                                                                          *
 *  PURPOSE    : Pull a byte from the 'S' stack.                            *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809PULLB(unsigned char *m_map09, REGS6809 *regs)
{
unsigned char c;
   switch(c = m_map09[regs->usRegS+MEM_FLAGS]) /* If special flag (ROM or hardware) */
      {
      case 0: /* Normal RAM */
         return m_map09[regs->usRegS++ + MEM_RAM]; /* Just return it */
         break;
      case 1: /* Normal ROM */
         return m_map09[regs->usRegS++ + MEM_ROM]; /* Just return it */
         break;
      default: /* Call special handler routine for this address */
         return (mem_handlers09[c-2].pfn_read)(regs->usRegS++);
         break;
      }

} /* M6809PULLB() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809PULLW(char *, REGS6809 *)                             *
 *                                                                          *
 *  PURPOSE    : Pull a word from the 'S' stack.                            *
 *                                                                          *
 ****************************************************************************/
__inline unsigned short M6809PULLW(unsigned char *m_map09, REGS6809 *regs)
{
unsigned char c, hi, lo;

   switch(c = m_map09[regs->usRegS+MEM_FLAGS]) /* If special flag (ROM or hardware) */
      {
      case 0: /* Normal RAM */
         hi = m_map09[regs->usRegS++ + MEM_RAM]; /* Just return it */
         break;
      case 1: /* Normal ROM */
         hi = m_map09[regs->usRegS++ + MEM_ROM]; /* Just return it */
         break;
      default: /* Call special handler routine for this address */
         hi = (mem_handlers09[c-2].pfn_read)(regs->usRegS++);
         break;
      }
/* I'll check the flag again in case someone is trying to be tricky */
   switch(c = m_map09[regs->usRegS+MEM_FLAGS]) /* If special flag (ROM or hardware) */
      {
      case 0: /* Normal RAM */
         lo = m_map09[regs->usRegS++ + MEM_RAM]; /* Just return it */
         break;
      case 1: /* Normal ROM */
         lo = m_map09[regs->usRegS++ + MEM_ROM]; /* Just return it */
         break;
      default: /* Call special handler routine for this address */
         lo = (mem_handlers09[c-2].pfn_read)(regs->usRegS++);
         break;
      }
   return (hi * 256 + lo);

} /* M6809PULLW() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809PULLBU(char *, REGS6809 *)                            *
 *                                                                          *
 *  PURPOSE    : Pull a byte from the 'U' stack.                            *
 *                                                                          *
 ****************************************************************************/
__inline unsigned char M6809PULLBU(unsigned char *m_map09, REGS6809 *regs)
{

   return M6809ReadByte(m_map09, regs->usRegU++);

} /* M6809PULLBU() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : M6809PULLWU(char *, REGS6809 *)                            *
 *                                                                          *
 *  PURPOSE    : Pull a word from the 'U' stack.                            *
 *                                                                          *
 ****************************************************************************/
__inline unsigned short M6809PULLWU(unsigned char *m_map09, REGS6809 *regs)
{
unsigned char hi, lo;

   hi = M6809ReadByte(m_map09, regs->usRegU++);
   lo = M6809ReadByte(m_map09, regs->usRegU++);
   return (hi * 256 + lo);

} /* M6809PULLWU() */

/****************************************************************************
 *                                                                          *
 *  FUNCTION   : EXEC6809(char *, REGS6809 *, EMUHANDLERS *, int *, char *) *
 *                                                                          *
 *  PURPOSE    : Emulate the M6809 microprocessor for N clock cycles.       *
 *                                                                          *
 ****************************************************************************/
void EXEC6809(char *mem, REGS6809 *regs, EMUHANDLERS *emuh, int *iClocks, unsigned char *ucIRQs)
{
unsigned short PC;  /* Current Program Counter address */
unsigned char ucOpcode;
register unsigned short usAddr; /* Temp address */
register unsigned char ucTemp;
register unsigned short usTemp;
register signed short sTemp;
int oldPC; // DEBUG
   mem_handlers09 = emuh; /* Assign to static for faster execution */
   m_map09 = mem; /* ditto */

   PC = regs->usRegPC;
   while (*iClocks > 0) /* Execute for the amount of time alloted */
      {
      /*--- First check for any pending IRQs ---*/
      if (*ucIRQs)
         {
         if (*ucIRQs & INT_NMI) /* NMI is highest priority */
            {
            M6809PUSHW(m_map09, regs, PC);
            M6809PUSHW(m_map09, regs, regs->usRegU);
            M6809PUSHW(m_map09, regs, regs->usRegY);
            M6809PUSHW(m_map09, regs, regs->usRegX);
            M6809PUSHB(m_map09, regs, regs->ucRegDP);
            M6809PUSHB(m_map09, regs, regs->ucRegB);
            M6809PUSHB(m_map09, regs, regs->ucRegA);
            regs->ucRegCC |= 0x80; /* Set bit indicating machine state on stack */
            M6809PUSHB(m_map09, regs, regs->ucRegCC);
            regs->ucRegCC |= F_FIRQMASK | F_IRQMASK; /* Mask interrupts during service routine */
            *iClocks -= 19;
            PC = M6809ReadWord(m_map09, 0xfffc);
            *ucIRQs &= ~INT_NMI; /* clear this bit */
            goto doexecute;
            }
         if (*ucIRQs & INT_FIRQ && (regs->ucRegCC & F_FIRQMASK) == 0) /* Fast IRQ is next priority */
            {
            M6809PUSHW(m_map09, regs, PC);
            regs->ucRegCC &= 0x7f; /* Clear bit indicating machine state on stack */
            M6809PUSHB(m_map09, regs, regs->ucRegCC);
            *ucIRQs &= ~INT_FIRQ; /* clear this bit */
            regs->ucRegCC |= F_FIRQMASK | F_IRQMASK; /* Mask interrupts during service routine */
            *iClocks -= 10;
            PC = M6809ReadWord(m_map09, 0xfff6);
            goto doexecute;
            }
         if (*ucIRQs & INT_IRQ && (regs->ucRegCC & F_IRQMASK) == 0) /* IRQ is lowest priority */
            {
            M6809PUSHW(m_map09, regs, PC);
            M6809PUSHW(m_map09, regs, regs->usRegU);
            M6809PUSHW(m_map09, regs, regs->usRegY);
            M6809PUSHW(m_map09, regs, regs->usRegX);
            M6809PUSHB(m_map09, regs, regs->ucRegDP);
            M6809PUSHB(m_map09, regs, regs->ucRegB);
            M6809PUSHB(m_map09, regs, regs->ucRegA);
            regs->ucRegCC |= 0x80; /* Set bit indicating machine state on stack */
            M6809PUSHB(m_map09, regs, regs->ucRegCC);
            regs->ucRegCC |= F_IRQMASK; /* Mask interrupts during service routine */
            PC = M6809ReadWord(m_map09, 0xfff8);
            *ucIRQs &= ~INT_IRQ; /* clear this bit */
            *iClocks -= 19;
            goto doexecute;
            }
         }
doexecute:
#ifdef TRACE
      regs->usRegPC = PC;
      TRACE6809(regs);
#endif
      oldPC = PC;
      ucOpcode = M6809ReadByte(m_map09, PC++);
      *iClocks -= c6809Cycles[ucOpcode]; /* Subtract execution time */
      switch (ucOpcode)
         {
         case 0x00: /* NEG - direct page addressing */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            M6809WriteByte(m_map09, usAddr, M6809NEG(regs, M6809ReadByte(m_map09, usAddr)));
            break;

         case 0x03: /* COM - direct page addressing */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            M6809WriteByte(m_map09, usAddr, M6809COM(regs, M6809ReadByte(m_map09, usAddr)));
            break;

         case 0x04: /* LSR - direct page addressing */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809LSR(regs, ucTemp));
            break;

         case 0x06: /* ROR - direct page addressing */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809ROR(regs, ucTemp));
            break;

         case 0x07: /* ASR - direct page addressing */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809ASR(regs, ucTemp));
            break;

         case 0x08: /* ASL - direct page addressing */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809ASL(regs, ucTemp));
            break;

         case 0x09: /* ROL - direct page addressing */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809ROL(regs, ucTemp));
            break;

         case 0x0A: /* DEC - direct page addressing */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809DEC(regs, ucTemp));
            break;

         case 0x0C: /* INC - direct page addressing */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809INC(regs, ucTemp));
            break;

         case 0x0D: /* TST - direct page addressing */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[ucTemp];
            break;

         case 0x0E: /* JMP - direct page addressing */
            PC = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            break;

         case 0x0F: /* CLR - direct page addressing */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            M6809WriteByte(m_map09, usAddr, 0);
            regs->ucRegCC &= ~(F_NEGATIVE | F_OVERFLOW | F_CARRY);
            regs->ucRegCC |= F_ZERO; /* clear N,V,C, set Z */
            break;

         case 0x10: /* Prefix byte, (word versions of instructions) */
            ucOpcode = M6809ReadByte(m_map09, PC++); /* Second half of opcode */
            *iClocks -= c6809Cycles2[ucOpcode]; /* Subtract execution time */
            switch (ucOpcode)
               {
               case 0x21: /* LBRN */
                  PC += 2;  /* Skip the offset */
                  break;

               case 0x22: /* LBHI */
                  sTemp = (signed short)M6809ReadWord(m_map09, PC);
                  PC += 2;
                  if (!(regs->ucRegCC & (F_CARRY | F_ZERO)))
                     {
                     *iClocks -= 1; /* Extra clock if branch taken */
                     PC += sTemp;
                     }
                  break;

               case 0x23: /* LBLS */
                  sTemp = (signed short)M6809ReadWord(m_map09, PC);
                  PC += 2;
                  if (regs->ucRegCC & (F_CARRY | F_ZERO))
                     {
                     *iClocks -= 1; /* Extra clock if branch taken */
                     PC += sTemp;
                     }
                  break;

               case 0x24: /* LBCC */
                  sTemp = (signed short)M6809ReadWord(m_map09, PC);
                  PC += 2;
                  if (!(regs->ucRegCC & F_CARRY))
                     {
                     *iClocks -= 1; /* Extra clock if branch taken */
                     PC += sTemp;
                     }
                  break;

               case 0x25: /* LBCS */
                  sTemp = (signed short)M6809ReadWord(m_map09, PC);
                  PC += 2;
                  if (regs->ucRegCC & F_CARRY)
                     {
                     *iClocks -= 1; /* Extra clock if branch taken */
                     PC += sTemp;
                     }
                  break;

               case 0x26: /* LBNE */
                  sTemp = (signed short)M6809ReadWord(m_map09, PC);
                  PC += 2;
                  if (!(regs->ucRegCC & F_ZERO))
                     {
                     *iClocks -= 1; /* Extra clock if branch taken */
                     PC += sTemp;
                     }
                  break;

               case 0x27: /* LBEQ */
                  sTemp = (signed short)M6809ReadWord(m_map09, PC);
                  PC += 2;
                  if (regs->ucRegCC & F_ZERO)
                     {
                     *iClocks -= 1; /* Extra clock if branch taken */
                     PC += sTemp;
                     }
                  break;

               case 0x28: /* LBVC */
                  sTemp = (signed short)M6809ReadWord(m_map09, PC);
                  PC += 2;
                  if (!(regs->ucRegCC & F_OVERFLOW))
                     {
                     *iClocks -=1; /* Extra clock if branch taken */
                     PC += sTemp;
                     }
                  break;

               case 0x29: /* LBVS */
                  sTemp = (signed short)M6809ReadWord(m_map09, PC);
                  PC += 2;
                  if (regs->ucRegCC & F_OVERFLOW)
                     {
                     *iClocks -= 1; /* Extra clock if branch taken */
                     PC += sTemp;
                     }
                  break;

               case 0x2A: /* LBPL */
                  sTemp = (signed short)M6809ReadWord(m_map09, PC);
                  PC += 2;
                  if (!(regs->ucRegCC & F_NEGATIVE))
                     {
                     *iClocks -= 1; /* Extra clock if branch taken */
                     PC += sTemp;
                     }
                  break;

               case 0x2B: /* LBMI */
                  sTemp = (signed short)M6809ReadWord(m_map09, PC);
                  PC += 2;
                  if (regs->ucRegCC & F_NEGATIVE)
                     {
                     *iClocks -= 1; /* Extra clock if branch taken */
                     PC += sTemp;
                     }
                  break;

               case 0x2C: /* LBGE */
                  sTemp = (signed short)M6809ReadWord(m_map09, PC);
                  PC += 2;
                  if (!((regs->ucRegCC & F_NEGATIVE) ^ (regs->ucRegCC & F_OVERFLOW)<<2))
                     {
                     *iClocks -= 1; /* Extra clock if branch taken */
                     PC += sTemp;
                     }
                  break;

               case 0x2D: /* LBLT */
                  sTemp = (signed short)M6809ReadWord(m_map09, PC);
                  PC += 2;
                  if ((regs->ucRegCC & F_NEGATIVE) ^ (regs->ucRegCC & F_OVERFLOW)<<2)
                     {
                     *iClocks -= 1; /* Extra clock if branch taken */
                     PC += sTemp;
                     }
                  break;

               case 0x2E: /* LBGT */
                  sTemp = (signed short)M6809ReadWord(m_map09, PC);
                  PC += 2;
                  if (!((regs->ucRegCC & F_NEGATIVE) ^ (regs->ucRegCC & F_OVERFLOW)<<2 || regs->ucRegCC & F_ZERO))
                     {
                     *iClocks -= 1; /* Extra clock if branch taken */
                     PC += sTemp;
                     }
                  break;

               case 0x2F: /* LBLE */
                  sTemp = (signed short)M6809ReadWord(m_map09, PC);
                  PC += 2;
                  if ((regs->ucRegCC & F_NEGATIVE) ^ (regs->ucRegCC & F_OVERFLOW)<<2 || regs->ucRegCC & F_ZERO)
                     {
                     *iClocks -= 1; /* Extra clock if branch taken */
                     PC += sTemp;
                     }
                  break;

               case 0x3F: /* SWI2 */
                  regs->ucRegCC |= 0x80; /* Entire machine state stacked */
                  M6809PUSHW(m_map09, regs, PC);
                  M6809PUSHW(m_map09, regs, regs->usRegU);
                  M6809PUSHW(m_map09, regs, regs->usRegY);
                  M6809PUSHW(m_map09, regs, regs->usRegX);
                  M6809PUSHW(m_map09, regs, regs->ucRegDP);
                  M6809PUSHW(m_map09, regs, regs->ucRegA);
                  M6809PUSHW(m_map09, regs, regs->ucRegB);
                  M6809PUSHW(m_map09, regs, regs->ucRegCC);
                  PC = M6809ReadWord(m_map09, 0xfff4);
                  break;

               case 0x83: /* CMPD - immediate*/
                  usTemp = M6809ReadWord(m_map09, PC);
                  PC += 2;
                  M6809CMP16(regs, regs->usRegD, usTemp);
                  break;

               case 0x8C: /* CMPY - immediate */
                  usTemp = M6809ReadWord(m_map09, PC);
                  PC += 2;
                  M6809CMP16(regs, regs->usRegY, usTemp);
                  break;

               case 0x8E: /* LDY - immediate */
                  regs->usRegY = M6809ReadWord(m_map09, PC);
                  PC += 2;
                  M6809FlagsNZ16(regs, regs->usRegY);
                  regs->ucRegCC &= ~F_OVERFLOW;
                  break;

               case 0x93: /* CMPD - direct */
                  usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
                  usTemp = M6809ReadWord(m_map09, usAddr);
                  M6809CMP16(regs, regs->usRegD, usTemp);
                  break;

               case 0x9c: /* CMPY - direct */
                  usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
                  usTemp = M6809ReadWord(m_map09, usAddr);
                  M6809CMP16(regs, regs->usRegY, usTemp);
                  break;

               case 0x9E: /* LDY - direct */
                  usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
                  regs->usRegY = M6809ReadWord(m_map09, usAddr);
                  M6809FlagsNZ16(regs, regs->usRegY);
                  regs->ucRegCC &= ~F_OVERFLOW;
                  break;

               case 0x9F: /* STY - direct */
                  usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
                  M6809WriteWord(m_map09, usAddr, regs->usRegY);
                  M6809FlagsNZ16(regs, regs->usRegY);
                  regs->ucRegCC &= ~F_OVERFLOW;
                  break;

               case 0xA3: /* CMPD - indexed */
                  usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
                  usTemp = M6809ReadWord(m_map09, usAddr);
                  M6809CMP16(regs, regs->usRegD, usTemp);
                  break;
               case 0xAC: /* CMPY - indexed */
                  usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
                  usTemp = M6809ReadWord(m_map09, usAddr);
                  M6809CMP16(regs, regs->usRegY, usTemp);
                  break;
               case 0xAE: /* LDY - indexed */
                  usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
                  regs->usRegY = M6809ReadWord(m_map09, usAddr);
                  M6809FlagsNZ16(regs, regs->usRegY);
                  regs->ucRegCC &= ~F_OVERFLOW;
                  break;
               case 0xAF: /* STY - indexed */
                  usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
                  M6809WriteWord(m_map09, usAddr, regs->usRegY);
                  M6809FlagsNZ16(regs, regs->usRegY);
                  regs->ucRegCC &= ~F_OVERFLOW;
                  break;
               case 0xB3: /* CMPD - extended */
                  usAddr = M6809ReadWord(m_map09, PC);
                  PC += 2;
                  usTemp = M6809ReadWord(m_map09, usAddr);
                  M6809CMP16(regs, regs->usRegD, usTemp);
                  break;
               case 0xBC: /* CMPY - extended */
                  usAddr = M6809ReadWord(m_map09, PC);
                  PC += 2;
                  usTemp = M6809ReadWord(m_map09, usAddr);
                  M6809CMP16(regs, regs->usRegY, usTemp);
                  break;
               case 0xBE: /* LDY - extended */
                  usAddr = M6809ReadWord(m_map09, PC);
                  PC += 2;
                  regs->usRegY = M6809ReadWord(m_map09, usAddr);
                  M6809FlagsNZ16(regs, regs->usRegY);
                  regs->ucRegCC &= ~F_OVERFLOW;
                  break;
               case 0xBF: /* STY - extended */
                  usAddr = M6809ReadWord(m_map09, PC);
                  PC += 2;
                  M6809WriteWord(m_map09, usAddr, regs->usRegY);
                  M6809FlagsNZ16(regs, regs->usRegY);
                  regs->ucRegCC &= ~F_OVERFLOW;
                  break;
               case 0xCE: /* LDS - immediate */
                  regs->usRegS = M6809ReadWord(m_map09, PC);
                  PC += 2;
                  M6809FlagsNZ16(regs, regs->usRegS);
                  regs->ucRegCC &= ~F_OVERFLOW;
                  break;
               case 0xDE: /* LDS - direct */
                  usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
                  regs->usRegS = M6809ReadWord(m_map09, usAddr);
                  M6809FlagsNZ16(regs, regs->usRegS);
                  regs->ucRegCC &= ~F_OVERFLOW;
                  break;
               case 0xDF: /* STS - direct */
                  usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
                  M6809WriteWord(m_map09, usAddr, regs->usRegS);
                  M6809FlagsNZ16(regs, regs->usRegS);
                  regs->ucRegCC &= ~F_OVERFLOW;
                  break;
               case 0xEE: /* LDS - indexed */
                  usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
                  regs->usRegS = M6809ReadWord(m_map09, usAddr);
                  M6809FlagsNZ16(regs, regs->usRegS);
                  regs->ucRegCC &= ~F_OVERFLOW;
                  break;
               case 0xEF: /* STS - indexed */
                  usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
                  M6809WriteWord(m_map09, usAddr, regs->usRegS);
                  M6809FlagsNZ16(regs, regs->usRegS);
                  regs->ucRegCC &= ~F_OVERFLOW;
                  break;
               case 0xFE: /* LDS - extended */
                  usAddr = M6809ReadWord(m_map09, PC);
                  PC += 2;
                  regs->usRegS = M6809ReadWord(m_map09, usAddr);
                  M6809FlagsNZ16(regs, regs->usRegS);
                  regs->ucRegCC &= ~F_OVERFLOW;
                  break;
               case 0xFF: /* STS - extended */
                  usAddr = M6809ReadWord(m_map09, PC);
                  PC += 2;
                  M6809WriteWord(m_map09, usAddr, regs->usRegS);
                  M6809FlagsNZ16(regs, regs->usRegS);
                  regs->ucRegCC &= ~F_OVERFLOW;
                  break;

               default: /* Illegal opcode */
                  *iClocks = 0;
                  break;
               } /* 0x10 opcode switch */
            break;

         case 0x11: /* two byte opcodes */
            ucOpcode = M6809ReadByte(m_map09, PC++); /* Get second half of opcode */
            *iClocks -= c6809Cycles2[ucOpcode]; /* Subtract execution time */
            switch (ucOpcode)
               {
               case 0x3F: /* SWI3 */
                  regs->ucRegCC |= 0x80; /* Set entire flag to indicate whole machine state on stack */
                  M6809PUSHW(m_map09, regs, PC);
                  M6809PUSHW(m_map09, regs, regs->usRegU);
                  M6809PUSHW(m_map09, regs, regs->usRegY);
                  M6809PUSHW(m_map09, regs, regs->usRegX);
                  M6809PUSHW(m_map09, regs, regs->ucRegDP);
                  M6809PUSHW(m_map09, regs, regs->ucRegA);
                  M6809PUSHW(m_map09, regs, regs->ucRegB);
                  M6809PUSHW(m_map09, regs, regs->ucRegCC);
                  PC = M6809ReadWord(m_map09, 0xfff2);
                  break;
               case 0x83: /* CMPU - immediate */
                  usTemp = M6809ReadWord(m_map09, PC);
                  PC += 2;
                  M6809CMP16(regs, regs->usRegU, usTemp);
                  break;
               case 0x8C: /* CMPS - immediate */
                  usTemp = M6809ReadWord(m_map09, PC);
                  PC += 2;
                  M6809CMP16(regs, regs->usRegS, usTemp);
                  break;
               case 0x93: /* CMPU - direct */
                  usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
                  usTemp = M6809ReadWord(m_map09, usAddr);
                  M6809CMP16(regs, regs->usRegU, usTemp);
                  break;
               case 0x9C: /* CMPS - direct */
                  usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
                  usTemp = M6809ReadWord(m_map09, usAddr);
                  M6809CMP16(regs, regs->usRegS, usTemp);
                  break;
               case 0xA3: /* CMPU - indexed */
                  usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
                  usTemp = M6809ReadWord(m_map09, usAddr);
                  M6809CMP16(regs, regs->usRegU, usTemp);
                  break;
               case 0xAC: /* CMPS - indexed */
                  usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
                  usTemp = M6809ReadWord(m_map09, usAddr);
                  M6809CMP16(regs, regs->usRegS, usTemp);
                  break;
               case 0xB3: /* CMPU - extended */
                  usAddr = M6809ReadWord(m_map09, PC);
                  PC += 2;
                  usTemp = M6809ReadWord(m_map09, usAddr);
                  M6809CMP16(regs, regs->usRegU, usTemp);
                  break;
               case 0xBC: /* CMPS - extended */
                  usAddr = M6809ReadWord(m_map09, PC);
                  PC += 2;
                  usTemp = M6809ReadWord(m_map09, usAddr);
                  M6809CMP16(regs, regs->usRegS, usTemp);
                  break;

               default: /* Illegal opcode */
                  *iClocks = 0;
                  break;
               } /* 0x11 opcode switch */
            break;
         case 0x12: /* NOP */
            break;

         case 0x13: /* SYNC */
            break;

         case 0x16: /* LBRA - relative jump */
            sTemp = (signed short)M6809ReadWord(m_map09, PC);
            PC += sTemp + 2;
            break;

         case 0x17: /* LBSR - relative call */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809PUSHW(m_map09, regs, PC);
            PC += usAddr;
            break;

         case 0x19: /* DAA */
            {
            unsigned char msn, lsn;
            unsigned short cf = 0;
            msn=regs->ucRegA & 0xf0; lsn=regs->ucRegA & 0x0f;
            if( lsn>0x09 || regs->ucRegCC&0x20 ) cf |= 0x06;
            if( msn>0x80 && lsn>0x09 ) cf |= 0x60;
            if( msn>0x90 || regs->ucRegCC&0x01 ) cf |= 0x60;
            usTemp = cf + regs->ucRegA;
            regs->ucRegCC &= ~(F_CARRY | F_NEGATIVE | F_ZERO | F_OVERFLOW);
            if (usTemp & 0x100)
               regs->ucRegCC |= F_CARRY;
            regs->ucRegA = (unsigned char)usTemp;
            regs->ucRegCC |= c6809NZ[regs->ucRegA];
            }
            break;

         case 0x1A: /* ORCC */
            regs->ucRegCC |= M6809ReadByte(m_map09, PC++);
            break;

         case 0x1C: /* ANDCC */
            regs->ucRegCC &= M6809ReadByte(m_map09, PC++);
            break;

         case 0x1D: /* SEX */
            regs->ucRegA = (regs->ucRegB & 0x80) ? 0xFF : 0x00;
            M6809FlagsNZ16(regs, regs->usRegD);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0x1E: /* EXG */
            ucTemp = M6809ReadByte(m_map09, PC++); /* Get postbyte */
            M6809TFREXG(regs, ucTemp, &PC, 1);
            break;

         case 0x1F: /* TFR */
            ucTemp = M6809ReadByte(m_map09, PC++); /* Get postbyte */
            M6809TFREXG(regs, ucTemp, &PC, 0);
            break;

         /* Relative conditional branches */
         case 0x20: /* BRA */
            PC += (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            break;

         case 0x21: /* BRN - another NOP */
            PC++; /* skip the offset */
            break;

         case 0x22: /* BHI */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            if (!(regs->ucRegCC & (F_CARRY | F_ZERO)))
               PC += sTemp;
            break;

         case 0x23: /* BLS */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            if (regs->ucRegCC & (F_CARRY | F_ZERO))
               PC += sTemp;
            break;

         case 0x24: /* BCC */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            if (!(regs->ucRegCC & F_CARRY))
               PC += sTemp;
            break;

         case 0x25: /* BCS */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            if (regs->ucRegCC & F_CARRY)
               PC += sTemp;
            break;

         case 0x26: /* BNE */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            if (!(regs->ucRegCC & F_ZERO))
               PC += sTemp;
            break;

         case 0x27: /* BEQ */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            if (regs->ucRegCC & F_ZERO)
               PC += sTemp;
            break;

         case 0x28: /* BVC */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            if (!(regs->ucRegCC & F_OVERFLOW))
               PC += sTemp;
            break;

         case 0x29: /* BVS */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            if (regs->ucRegCC & F_OVERFLOW)
               PC += sTemp;
            break;

         case 0x2A: /* BPL */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            if (!(regs->ucRegCC & F_NEGATIVE))
               PC += sTemp;
            break;

         case 0x2B: /* BMI */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            if (regs->ucRegCC & F_NEGATIVE)
               PC += sTemp;
            break;

         case 0x2C: /* BGE */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            if (!((regs->ucRegCC & F_NEGATIVE) ^ (regs->ucRegCC & F_OVERFLOW)<<2))
               PC += sTemp;
            break;

         case 0x2D: /* BLT */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            if ((regs->ucRegCC & F_NEGATIVE) ^ (regs->ucRegCC & F_OVERFLOW)<<2)
               PC += sTemp;
            break;

         case 0x2E: /* BGT */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            if (!((regs->ucRegCC & F_NEGATIVE) ^ (regs->ucRegCC & F_OVERFLOW)<<2 || regs->ucRegCC & F_ZERO))
               PC += sTemp;
            break;

         case 0x2F: /* BLE */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            if ((regs->ucRegCC & F_NEGATIVE) ^ (regs->ucRegCC & F_OVERFLOW)<<2 || regs->ucRegCC & F_ZERO)
               PC += sTemp;
            break;

         case 0x30: /* LEAX */
            regs->usRegX = M6809PostByte(regs, m_map09, &PC, iClocks);
            regs->ucRegCC &= ~F_ZERO;
            if (regs->usRegX == 0)
               regs->ucRegCC |= F_ZERO;
            break;

         case 0x31: /* LEAY */
            regs->usRegY = M6809PostByte(regs, m_map09, &PC, iClocks);
            regs->ucRegCC &= ~F_ZERO;
            if (regs->usRegY == 0)
               regs->ucRegCC |= F_ZERO;
            break;

         case 0x32: /* LEAS */
            regs->usRegS = M6809PostByte(regs, m_map09, &PC, iClocks);
            break;

         case 0x33: /* LEAU - indexed */
            regs->usRegU = M6809PostByte(regs, m_map09, &PC, iClocks);
            break;

         case 0x34: /* PSHS - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++); /* Get the flags byte */
            M6809PSHS(m_map09, regs, ucTemp, iClocks, PC);
            break;

         case 0x35: /* PULS - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++); /* Get the flags byte */
            M6809PULS(m_map09, regs, ucTemp, iClocks, &PC);
            break;

         case 0x36: /* PSHU - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++); /* Get the flags byte */
            M6809PSHU(m_map09, regs, ucTemp, iClocks, PC);
            break;

         case 0x37: /* PULU - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++); /* Get the flags byte */
            M6809PULU(m_map09, regs, ucTemp, iClocks, &PC);
            break;

         case 0x39: /* RTS */
            PC = M6809PULLW(m_map09, regs);
            break;

         case 0x3A: /* ABX */
            regs->usRegX += regs->ucRegB;
            break;

         case 0x3B: /* RTI */
            regs->ucRegCC = M6809PULLB(m_map09, regs);
            if (regs->ucRegCC & 0x80) /* Entire machine state stacked? */
               {
               *iClocks -= 9;
               regs->ucRegA = M6809PULLB(m_map09, regs);
               regs->ucRegB = M6809PULLB(m_map09, regs);
               regs->ucRegDP= M6809PULLB(m_map09, regs);
               regs->usRegX = M6809PULLW(m_map09, regs);
               regs->usRegY = M6809PULLW(m_map09, regs);
               regs->usRegU = M6809PULLW(m_map09, regs);
               }
            PC = M6809PULLW(m_map09, regs);
            break;

         case 0x3C: /* CWAI */
            regs->ucRegCC &= M6809ReadByte(m_map09, PC++);
            break;

         case 0x3D: /* MUL */
            usTemp = regs->ucRegA * regs->ucRegB;
            if (usTemp)
               regs->ucRegCC &= ~F_ZERO;
            else
               regs->ucRegCC |= F_ZERO;
            if (usTemp & 0x80)
               regs->ucRegCC |= F_CARRY;
            else
               regs->ucRegCC &= ~F_CARRY;
            regs->usRegD = usTemp;
            break;

         case 0x3F: /* SWI */
            regs->ucRegCC |= 0x80; /* Indicate whole machine state is stacked */
            M6809PUSHW(m_map09, regs, PC);
            M6809PUSHW(m_map09, regs, regs->usRegU);
            M6809PUSHW(m_map09, regs, regs->usRegY);
            M6809PUSHW(m_map09, regs, regs->usRegX);
            M6809PUSHB(m_map09, regs, regs->ucRegDP);
            M6809PUSHB(m_map09, regs, regs->ucRegB);
            M6809PUSHB(m_map09, regs, regs->ucRegA);
            M6809PUSHB(m_map09, regs, regs->ucRegCC);
            regs->ucRegCC |= 0x50;  /* Disable further interrupts */
            PC = M6809ReadWord(m_map09, 0xfffa);
            break;

         case 0x40: /* NEGA */
            regs->ucRegA = M6809NEG(regs, regs->ucRegA);
            break;

         case 0x43: /* COMA */
            regs->ucRegA = M6809COM(regs, regs->ucRegA);
            break;

         case 0x44: /* LSRA */
            regs->ucRegA = M6809LSR(regs, regs->ucRegA);
            break;

         case 0x46: /* RORA */
            regs->ucRegA = M6809ROR(regs, regs->ucRegA);
            break;

         case 0x47: /* ASRA */
            regs->ucRegA = M6809ASR(regs, regs->ucRegA);
            break;

         case 0x48: /* ASLA */
            regs->ucRegA = M6809ASL(regs, regs->ucRegA);
            break;

         case 0x49: /* ROLA */
            regs->ucRegA = M6809ROL(regs, regs->ucRegA);
            break;

         case 0x4A: /* DECA */
            regs->ucRegA = M6809DEC(regs, regs->ucRegA);
            break;

         case 0x4C: /* INCA */
            regs->ucRegA = M6809INC(regs, regs->ucRegA);
            break;

         case 0x4D: /* TSTA */
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegA];
            break;

         case 0x4F: /* CLRA */
            regs->ucRegA = 0;
            regs->ucRegCC &= ~(F_NEGATIVE | F_OVERFLOW | F_CARRY);
            regs->ucRegCC |= F_ZERO;
            break;

         case 0x50: /* NEGB */
            regs->ucRegB = M6809NEG(regs, regs->ucRegB);
            break;

         case 0x53: /* COMB */
            regs->ucRegB = M6809COM(regs, regs->ucRegB);
            break;

         case 0x54: /* LSRB */
            regs->ucRegB = M6809LSR(regs, regs->ucRegB);
            break;

         case 0x56: /* RORB */
            regs->ucRegB = M6809ROR(regs, regs->ucRegB);
            break;

         case 0x57: /* ASRB */
            regs->ucRegB = M6809ASR(regs, regs->ucRegB);
            break;

         case 0x58: /* ASLB */
            regs->ucRegB = M6809ASL(regs, regs->ucRegB);
            break;

         case 0x59: /* ROLB */
            regs->ucRegB = M6809ROL(regs, regs->ucRegB);
            break;

         case 0x5A: /* DECB */
            regs->ucRegB = M6809DEC(regs, regs->ucRegB);
            break;

         case 0x5C: /* INCB */
            regs->ucRegB = M6809INC(regs, regs->ucRegB);
            break;

         case 0x5D: /* TSTB */
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegB];
            break;

         case 0x5F: /* CLRB */
            regs->ucRegB = 0;
            regs->ucRegCC &= ~(F_NEGATIVE | F_OVERFLOW | F_CARRY);
            regs->ucRegCC |= F_ZERO;
            break;

         case 0x60: /* NEG - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809NEG(regs, ucTemp));
            break;

         case 0x63: /* COM - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809COM(regs, ucTemp));
            break;

         case 0x64: /* LSR - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809LSR(regs, ucTemp));
            break;

         case 0x66: /* ROR - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809ROR(regs, ucTemp));
            break;

         case 0x67: /* ASR - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809ASR(regs, ucTemp));
            break;

         case 0x68: /* ASL - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809ASL(regs, ucTemp));
            break;

         case 0x69: /* ROL - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809ROL(regs, ucTemp));
            break;

         case 0x6A: /* DEC - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809DEC(regs, ucTemp));
            break;

         case 0x6C: /* INC - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809WriteByte(m_map09, usAddr, M6809INC(regs, ucTemp));
            break;

         case 0x6D: /* TST - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[M6809ReadByte(m_map09, usAddr)];
            break;

         case 0x6E: /* JMP - indexed */
            PC = M6809PostByte(regs, m_map09, &PC, iClocks);
            break;

         case 0x6F: /* CLR - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            M6809WriteByte(m_map09, usAddr, 0);
            regs->ucRegCC &= ~(F_OVERFLOW | F_CARRY | F_NEGATIVE);
            regs->ucRegCC |= F_ZERO;
            break;

         case 0x70: /* NEG - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteByte(m_map09, usAddr, M6809NEG(regs, M6809ReadByte(m_map09, usAddr)));
            break;

         case 0x73: /* COM - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteByte(m_map09, usAddr, M6809COM(regs, M6809ReadByte(m_map09, usAddr)));
            break;

         case 0x74: /* LSR - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteByte(m_map09, usAddr, M6809LSR(regs, M6809ReadByte(m_map09, usAddr)));
            break;

         case 0x76: /* ROR - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteByte(m_map09, usAddr, M6809ROR(regs, M6809ReadByte(m_map09, usAddr)));
            break;

         case 0x77: /* ASR - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteByte(m_map09, usAddr, M6809ASR(regs, M6809ReadByte(m_map09, usAddr)));
            break;

         case 0x78: /* ASL - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteByte(m_map09, usAddr, M6809ASL(regs, M6809ReadByte(m_map09, usAddr)));
            break;

         case 0x79: /* ROL - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteByte(m_map09, usAddr, M6809ROL(regs, M6809ReadByte(m_map09, usAddr)));
            break;

         case 0x7A: /* DEC - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteByte(m_map09, usAddr, M6809DEC(regs, M6809ReadByte(m_map09, usAddr)));
            break;

         case 0x7C: /* INC - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteByte(m_map09, usAddr, M6809INC(regs, M6809ReadByte(m_map09, usAddr)));
            break;

         case 0x7D: /* TST - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[ucTemp];
            break;

         case 0x7E: /* JMP - extended */
            PC = M6809ReadWord(m_map09, PC);
            break;

         case 0x7F: /* CLR - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteByte(m_map09, usAddr, 0);
            regs->ucRegCC &= ~(F_CARRY | F_OVERFLOW | F_NEGATIVE);
            regs->ucRegCC |= F_ZERO;
            break;

         case 0x80: /* SUBA - immediate */
            regs->ucRegA = M6809SUB(regs, regs->ucRegA, M6809ReadByte(m_map09, PC++));
            break;

         case 0x81: /* CMPA - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            M6809CMP(regs, regs->ucRegA, ucTemp);
            break;

         case 0x82: /* SBCA - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            regs->ucRegA = M6809SBC(regs, regs->ucRegA, ucTemp);
            break;

         case 0x83: /* SUBD - immediate */
            usTemp = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->usRegD = M6809SUB16(regs, regs->usRegD, usTemp);
            break;

         case 0x84: /* ANDA - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            regs->ucRegA = M6809AND(regs, regs->ucRegA, ucTemp);
            break;

         case 0x85: /* BITA - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            M6809AND(regs, regs->ucRegA, ucTemp);
            break;

         case 0x86: /* LDA - immediate */
            regs->ucRegA = M6809ReadByte(m_map09, PC++);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegA];
            break;

         case 0x88: /* EORA - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            regs->ucRegA = M6809EOR(regs, regs->ucRegA, ucTemp);
            break;

         case 0x89: /* ADCA - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            regs->ucRegA = M6809ADC(regs, regs->ucRegA, ucTemp);
            break;

         case 0x8A: /* ORA - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            regs->ucRegA = M6809OR(regs, regs->ucRegA, ucTemp);
            break;

         case 0x8B: /* ADDA - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            regs->ucRegA = M6809ADD(regs, regs->ucRegA, ucTemp);
            break;

         case 0x8C: /* CMPX - immediate */
            usTemp = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809CMP16(regs, regs->usRegX, usTemp);
            break;

         case 0x8D: /* BSR */
            sTemp = (signed short)(signed char)M6809ReadByte(m_map09, PC++);
            M6809PUSHW(m_map09, regs, PC);
            PC += sTemp;
            break;

         case 0x8E: /* LDX - immediate */
            usTemp = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->usRegX = usTemp;
            M6809FlagsNZ16(regs, usTemp);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0x90: /* SUBA - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegA = M6809SUB(regs, regs->ucRegA, ucTemp);
            break;

         case 0x91: /* CMPA - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809CMP(regs, regs->ucRegA, ucTemp);
            break;

         case 0x92: /* SBCA - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegA = M6809SBC(regs, regs->ucRegA, ucTemp);
            break;

         case 0x93: /* SUBD - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            usTemp = M6809ReadWord(m_map09, usAddr);
            regs->usRegD = M6809SUB16(regs, regs->usRegD, usTemp);
            break;

         case 0x94: /* ANDA - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegA = M6809AND(regs, regs->ucRegA, ucTemp);
            break;

         case 0x95: /* BITA - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809AND(regs, regs->ucRegA, ucTemp);
            break;

         case 0x96: /* LDA - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            regs->ucRegA = M6809ReadByte(m_map09, usAddr);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegA];
            break;

         case 0x97: /* STA - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            M6809WriteByte(m_map09, usAddr, regs->ucRegA);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegA];
            break;

         case 0x98: /* EORA - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegA = M6809EOR(regs, regs->ucRegA, ucTemp);
            break;

         case 0x99: /* ADCA - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegA = M6809ADC(regs, regs->ucRegA, ucTemp);
            break;

         case 0x9A: /* ORA - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegA = M6809OR(regs, regs->ucRegA, ucTemp);
            break;

         case 0x9B: /* ADDA - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegA = M6809ADD(regs, regs->ucRegA, ucTemp);
            break;

         case 0x9C: /* CMPX - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            usTemp = M6809ReadWord(m_map09, usAddr);
            M6809CMP16(regs, regs->usRegX, usTemp);
            break;

         case 0x9D: /* JSR - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            M6809PUSHW(m_map09, regs, PC);
            PC = usAddr;
            break;

         case 0x9E: /* LDX - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            regs->usRegX = M6809ReadWord(m_map09, usAddr);
            M6809FlagsNZ16(regs, regs->usRegX);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0x9F: /* STX - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++); /* Address of byte to negate */
            M6809WriteWord(m_map09, usAddr, regs->usRegX);
            M6809FlagsNZ16(regs, regs->usRegX);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xA0: /* SUBA - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegA = M6809SUB(regs, regs->ucRegA, ucTemp);
            break;

         case 0xA1: /* CMPA - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809CMP(regs, regs->ucRegA, ucTemp);
            break;

         case 0xA2: /* SBCA - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegA = M6809SBC(regs, regs->ucRegA, ucTemp);
            break;

         case 0xA3: /* SUBD - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            usTemp = M6809ReadWord(m_map09, usAddr);
            regs->usRegD = M6809SUB16(regs, regs->usRegD, usTemp);
            break;

         case 0xA4: /* ANDA - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegA = M6809AND(regs, regs->ucRegA, ucTemp);
            break;

         case 0xA5: /* BITA - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809AND(regs, regs->ucRegA, ucTemp);
            break;

         case 0xA6: /* LDA - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            regs->ucRegA = M6809ReadByte(m_map09, usAddr);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegA];
            break;

         case 0xA7: /* STA - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            M6809WriteByte(m_map09, usAddr, regs->ucRegA);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegA];
            break;

         case 0xA8: /* EORA - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegA = M6809EOR(regs, regs->ucRegA, ucTemp);
            break;

         case 0xA9: /* ADCA - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegA = M6809ADC(regs, regs->ucRegA, ucTemp);
            break;

         case 0xAA: /* ORA - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegA = M6809OR(regs, regs->ucRegA, ucTemp);
            break;

         case 0xAB: /* ADDA - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegA = M6809ADD(regs, regs->ucRegA, ucTemp);
            break;

         case 0xAC: /* CMPX - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            usTemp = M6809ReadWord(m_map09, usAddr);
            M6809CMP16(regs, regs->usRegX, usTemp);
            break;

         case 0xAD: /* JSR - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            M6809PUSHW(m_map09, regs, PC);
            PC = usAddr;
            break;

         case 0xAE: /* LDX - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            regs->usRegX = M6809ReadWord(m_map09, usAddr);
            M6809FlagsNZ16(regs, regs->usRegX);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xAF: /* STX - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            M6809WriteWord(m_map09, usAddr, regs->usRegX);
            M6809FlagsNZ16(regs, regs->usRegX);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xB0: /* SUBA - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->ucRegA = M6809SUB(regs, regs->ucRegA, M6809ReadByte(m_map09, usAddr));
            break;

         case 0xB1: /* CMPA - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809CMP(regs, regs->ucRegA, M6809ReadByte(m_map09, usAddr));
            break;

         case 0xB2: /* SBCA - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->ucRegA = M6809SBC(regs, regs->ucRegA, M6809ReadByte(m_map09, usAddr));
            break;

         case 0xB3: /* SUBD - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->usRegD = M6809SUB16(regs, regs->usRegD, M6809ReadWord(m_map09, usAddr));
            break;

         case 0xB4: /* ANDA - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->ucRegA = M6809AND(regs, regs->ucRegA, M6809ReadByte(m_map09, usAddr));
            break;

         case 0xB5: /* BITA - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809AND(regs, regs->ucRegA, M6809ReadByte(m_map09, usAddr));
            break;

         case 0xB6: /* LDA - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->ucRegA = M6809ReadByte(m_map09, usAddr);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegA];
            break;

         case 0xB7: /* STA - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteByte(m_map09, usAddr, regs->ucRegA);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegA];
            break;

         case 0xB8: /* EORA - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->ucRegA = M6809EOR(regs, regs->ucRegA, M6809ReadByte(m_map09, usAddr));
            break;

         case 0xB9: /* ADCA - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->ucRegA = M6809ADC(regs, regs->ucRegA, M6809ReadByte(m_map09, usAddr));
            break;

         case 0xBA: /* ORA - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->ucRegA = M6809OR(regs, regs->ucRegA, M6809ReadByte(m_map09, usAddr));
            break;

         case 0xBB: /* ADDA - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->ucRegA = M6809ADD(regs, regs->ucRegA, M6809ReadByte(m_map09, usAddr));
            break;

         case 0xBC: /* CMPX - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809CMP16(regs, regs->usRegX, M6809ReadWord(m_map09, usAddr));
            break;

         case 0xBD: /* JSR - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809PUSHW(m_map09, regs, PC);
            PC = usAddr;
            break;

         case 0xBE: /* LDX - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->usRegX = M6809ReadWord(m_map09, usAddr);
            M6809FlagsNZ16(regs, regs->usRegX);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xBF: /* STX - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteWord(m_map09, usAddr, regs->usRegX);
            M6809FlagsNZ16(regs, regs->usRegX);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xC0: /* SUBB - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            regs->ucRegB = M6809SUB(regs, regs->ucRegB, ucTemp);
            break;

         case 0xC1: /* CMPB - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            M6809CMP(regs, regs->ucRegB, ucTemp);
            break;

         case 0xC2: /* SBCB - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            regs->ucRegB = M6809SBC(regs, regs->ucRegB, ucTemp);
            break;

         case 0xC3: /* ADDD - immediate */
            usTemp = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->usRegD = M6809ADD16(regs, regs->usRegD, usTemp);
            break;

         case 0xC4: /* ANDB - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            regs->ucRegB = M6809AND(regs, regs->ucRegB, ucTemp);
            break;

         case 0xC5: /* BITB - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            M6809AND(regs, regs->ucRegB, ucTemp);
            break;

         case 0xC6: /* LDB - immediate */
            regs->ucRegB = M6809ReadByte(m_map09, PC++);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegB];
            break;

         case 0xC8: /* EORB - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            regs->ucRegB = M6809EOR(regs, regs->ucRegB, ucTemp);
            break;

         case 0xC9: /* ADCB - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            regs->ucRegB = M6809ADC(regs, regs->ucRegB, ucTemp);
            break;

         case 0xCA: /* ORB - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            regs->ucRegB = M6809OR(regs, regs->ucRegB, ucTemp);
            break;

         case 0xCB: /* ADDB - immediate */
            ucTemp = M6809ReadByte(m_map09, PC++);
            regs->ucRegB = M6809ADD(regs, regs->ucRegB, ucTemp);
            break;

         case 0xCC: /* LDD - immediate */
            regs->usRegD = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809FlagsNZ16(regs, regs->usRegD);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xCE: /* LDU - immediate */
            regs->usRegU = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809FlagsNZ16(regs, regs->usRegU);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xD0: /* SUBB - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809SUB(regs, regs->ucRegB, ucTemp);
            break;

         case 0xD1: /* CMPB - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809CMP(regs, regs->ucRegB, ucTemp);
            break;

         case 0xD2: /* SBCB - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809SBC(regs, regs->ucRegB, ucTemp);
            break;

         case 0xD3: /* ADDD - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            usTemp = M6809ReadWord(m_map09, usAddr);
            regs->usRegD = M6809ADD16(regs, regs->usRegD, usTemp);
            break;

         case 0xD4: /* ANDB - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809AND(regs, regs->ucRegB, ucTemp);
            break;

         case 0xD5: /* BITB - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809AND(regs, regs->ucRegB, ucTemp);
            break;

         case 0xD6: /* LDB - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            regs->ucRegB = M6809ReadByte(m_map09, usAddr);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegB];
            break;

         case 0xD7: /* STB - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            M6809WriteByte(m_map09, usAddr, regs->ucRegB);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegB];
            break;

         case 0xD8: /* EORB - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809EOR(regs, regs->ucRegB, ucTemp);
            break;

         case 0xD9: /* ADCB - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809ADC(regs, regs->ucRegB, ucTemp);
            break;

         case 0xDA: /* ORB - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809OR(regs, regs->ucRegB, ucTemp);
            break;

         case 0xDB: /* ADDB - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809ADD(regs, regs->ucRegB, ucTemp);
            break;

         case 0xDC: /* LDD - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            regs->usRegD = M6809ReadWord(m_map09, usAddr);
            M6809FlagsNZ16(regs, regs->usRegD);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xDD: /* STD - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            M6809WriteWord(m_map09, usAddr, regs->usRegD);
            M6809FlagsNZ16(regs, regs->usRegD);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xDE: /* LDU - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            regs->usRegU = M6809ReadWord(m_map09, usAddr);
            M6809FlagsNZ16(regs, regs->usRegU);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xDF: /* STU - direct */
            usAddr = regs->ucRegDP * 256 + M6809ReadByte(m_map09, PC++);
            M6809WriteWord(m_map09, usAddr, regs->usRegU);
            M6809FlagsNZ16(regs, regs->usRegU);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xE0: /* SUBB - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809SUB(regs, regs->ucRegB, ucTemp);
            break;

         case 0xE1: /* CMPB - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809CMP(regs, regs->ucRegB, ucTemp);
            break;

         case 0xE2: /* SBCB - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809SBC(regs, regs->ucRegB, ucTemp);
            break;

         case 0xE3: /* ADDD - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            usTemp = M6809ReadWord(m_map09, usAddr);
            regs->usRegD = M6809ADD16(regs, regs->usRegD, usTemp);
            break;

         case 0xE4: /* ANDB - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809AND(regs, regs->ucRegB, ucTemp);
            break;

         case 0xE5: /* BITB - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809AND(regs, regs->ucRegB, ucTemp);
            break;

         case 0xE6: /* LDB - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            regs->ucRegB = M6809ReadByte(m_map09, usAddr);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegB];
            break;

         case 0xE7: /* STB - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            M6809WriteByte(m_map09, usAddr, regs->ucRegB);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegB];
            break;

         case 0xE8: /* EORB - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809EOR(regs, regs->ucRegB, ucTemp);
            break;

         case 0xE9: /* ADCB - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809ADC(regs, regs->ucRegB, ucTemp);
            break;

         case 0xEA: /* ORB - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809OR(regs, regs->ucRegB, ucTemp);
            break;

         case 0xEB: /* ADDB - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809ADD(regs, regs->ucRegB, ucTemp);
            break;

         case 0xEC: /* LDD - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            regs->usRegD = M6809ReadWord(m_map09, usAddr);
            M6809FlagsNZ16(regs, regs->usRegD);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xED: /* STD - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            M6809WriteWord(m_map09, usAddr, regs->usRegD);
            M6809FlagsNZ16(regs, regs->usRegD);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xEE: /* LDU - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            regs->usRegU = M6809ReadWord(m_map09, usAddr);
            M6809FlagsNZ16(regs, regs->usRegU);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xEF: /* STU - indexed */
            usAddr = M6809PostByte(regs, m_map09, &PC, iClocks);
            M6809WriteWord(m_map09, usAddr, regs->usRegU);
            M6809FlagsNZ16(regs, regs->usRegU);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;


         case 0xF0: /* SUBB - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809SUB(regs, regs->ucRegB, ucTemp);
            break;

         case 0xF1: /* CMPB - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809CMP(regs, regs->ucRegB, ucTemp);
            break;

         case 0xF2: /* SBCB - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809SBC(regs, regs->ucRegB, ucTemp);
            break;

         case 0xF3: /* ADDD - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            usTemp = M6809ReadWord(m_map09, usAddr);
            regs->usRegD = M6809ADD16(regs, regs->usRegD, usTemp);
            break;

         case 0xF4: /* ANDB - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809AND(regs, regs->ucRegB, ucTemp);
            break;

         case 0xF5: /* BITB - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            ucTemp = M6809ReadByte(m_map09, usAddr);
            M6809AND(regs, regs->ucRegB, ucTemp);
            break;

         case 0xF6: /* LDB - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->ucRegB = M6809ReadByte(m_map09, usAddr);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegB];
            break;

         case 0xF7: /* STB - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteByte(m_map09, usAddr, regs->ucRegB);
            regs->ucRegCC &= ~(F_ZERO | F_NEGATIVE | F_OVERFLOW);
            regs->ucRegCC |= c6809NZ[regs->ucRegB];
            break;

         case 0xF8: /* EORB - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809EOR(regs, regs->ucRegB, ucTemp);
            break;

         case 0xF9: /* ADCB - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809ADC(regs, regs->ucRegB, ucTemp);
            break;

         case 0xFA: /* ORB - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809OR(regs, regs->ucRegB, ucTemp);
            break;

         case 0xFB: /* ADDB - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            ucTemp = M6809ReadByte(m_map09, usAddr);
            regs->ucRegB = M6809ADD(regs, regs->ucRegB, ucTemp);
            break;

         case 0xFC: /* LDD - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->usRegD = M6809ReadWord(m_map09, usAddr);
            M6809FlagsNZ16(regs, regs->usRegD);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xFD: /* STD - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteWord(m_map09, usAddr, regs->usRegD);
            M6809FlagsNZ16(regs, regs->usRegD);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xFE: /* LDU - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            regs->usRegU = M6809ReadWord(m_map09, usAddr);
            M6809FlagsNZ16(regs, regs->usRegU);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         case 0xFF: /* STU - extended */
            usAddr = M6809ReadWord(m_map09, PC);
            PC += 2;
            M6809WriteWord(m_map09, usAddr, regs->usRegU);
            M6809FlagsNZ16(regs, regs->usRegU);
            regs->ucRegCC &= ~F_OVERFLOW;
            break;

         default: /* Illegal instruction */
            *iClocks = 0;
            break;
         } /* switch */
      } /* while iClocks */

   regs->usRegPC = PC;

} /* EXEC6809() */
