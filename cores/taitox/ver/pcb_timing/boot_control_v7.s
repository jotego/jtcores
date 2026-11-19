/* Taito X P0-039A, Superman CPU timing probe: v7 lower-window discriminator.
 *
 * This retains the reviewed v5 boot/control path and adds a finite, paced
 * A10 PicoROM read heartbeat after successful boot qualification. It does not
 * execute timing kernels or change the core RTL.
 */

        .cpu 68000

        .equ    WORKRAM,       0x00f00000
        .equ    WORKRAM_END,   0x00f04000
        .equ    IRQ2_COUNT,    0x00f00000
        .equ    IRQ4_COUNT,    0x00f00002
        .equ    IRQ6_COUNT,    0x00f00004
        .equ    PALETTE,       0x00b00000
        .equ    BACKDROP,      0x00b003e0  /* palette word 0x1f0 */
        .equ    YRAM,          0x00d00000
        .equ    OBJECT_RAM,    0x00e00000
        .equ    OBJECT_CODE_SRC, 0x00e00000
        .equ    OBJECT_ATTR_SRC, 0x00e00400
        .equ    OBJECT_CODE,   0x00e02000  /* active page, second LUT word */
        .equ    OBJECT_XCOLOR, 0x00e02400  /* active page, palette + X word */
        .equ    CONTROL,       0x00d00600
        .equ    CCHIP_IRQ_ACK, 0x00300000 /* /IPL2CLRCS, W5100307A sheet 2 */
        .equ    WATCHDOG,      0x00400000 /* /W.D.TCLRCS, W5100307A sheet 2 */
        .equ    VBL_IRQ_ACK,   0x00600000 /* /IPL1CLRCS, W5100307A sheet 2 */

        .section .vectors,"a"
        .long   WORKRAM_END-2
        .long   start
        .rept   24
        .long   fatal                  /* vectors 2..25 */
        .endr
        .long   irq2                   /* vector 26, IPL1 / level 2 / VBL */
        .long   fatal                  /* vector 27 */
        .long   irq4                   /* vector 28, IPL2 / level 4 / C-chip */
        .long   fatal                  /* vector 29 */
        .long   irq6                   /* vector 30, IPL1+IPL2 / level 6 */
        .long   fatal                  /* vector 31, level 7 */

        .section .text
        .globl  start, irq2, irq4, irq6, fatal

/* No stack or RAM variables are used until the full 16 KiB work RAM passes. */
start:
        move.w  #0x2700,%sr
        move.b  (0x0001be02).l,%d7  /* PicoROM marker 0x01: reset after SR */
        move.w  #0x0010,WATCHDOG   /* start watchdog petting before init */
        move.b  (0x0001be04).l,%d7  /* PicoROM marker 0x02: watchdog write passed */
        move.w  #0x7fff,BACKDROP    /* white: entry/backdrop path reached */
        move.b  (0x0001be06).l,%d7  /* PicoROM marker 0x03: backdrop write passed */
        lea     WORKRAM,%a0
        move.w  #0x0fff,%d1            /* 4096 longwords = 16 KiB */
ram_fill:
        move.l  %a0,%d2
        eori.l  #0xa55a3cc3,%d2
        move.l  %d2,(%a0)+
        dbra    %d1,ram_fill
        move.w  #0x0010,WATCHDOG

        lea     WORKRAM,%a0
        move.w  #0x0fff,%d1
ram_check:
        move.l  %a0,%d2
        eori.l  #0xa55a3cc3,%d2
        cmp.l   (%a0)+,%d2
        bne     fatal
        dbra    %d1,ram_check
        move.w  #0x0010,WATCHDOG

        lea     WORKRAM,%a0
        move.w  #0x0fff,%d1
ram_inverse_fill:
        move.l  %a0,%d2
        eori.l  #0xa55a3cc3,%d2
        not.l   %d2
        move.l  %d2,(%a0)+
        dbra    %d1,ram_inverse_fill
        move.w  #0x0010,WATCHDOG

        lea     WORKRAM,%a0
        move.w  #0x0fff,%d1
ram_inverse_check:
        move.l  %a0,%d2
        eori.l  #0xa55a3cc3,%d2
        not.l   %d2
        cmp.l   (%a0)+,%d2
        bne     fatal
        dbra    %d1,ram_inverse_check
        move.w  #0x0010,WATCHDOG

        lea     WORKRAM_END-2,%sp
        clr.l   IRQ2_COUNT           /* clears IRQ2 and IRQ4 counters */
        clr.l   IRQ6_COUNT           /* clears IRQ6 and result/scratch area */
        move.b  (0x0001be20).l,%d7  /* PicoROM stage 0x10: RAM passed */

/* Clear the X1-001 sprite/Y RAM and palette to a repeatable control screen. */
        lea     YRAM,%a0
        move.w  #0x01ff,%d1
        move.w  #0x0080,%d0
yram_clear:
        move.w  %d0,(%a0)+
        dbra    %d1,yram_clear
        move.w  #0x0010,WATCHDOG
        move.w  #0x00ff,%d1
        moveq   #0,%d0
yram_scroll_clear:
        move.w  %d0,(%a0)+
        dbra    %d1,yram_scroll_clear

        lea     OBJECT_RAM,%a0
        move.w  #0x1fff,%d1
object_clear:
        clr.w   (%a0)+
        dbra    %d1,object_clear
        move.w  #0x0010,WATCHDOG

/* Keep every unused sprite outside both X1-001 buffers and the 416-pixel MAME
   screen / 384-pixel FPGA active area. X = 0xf0 - 0x100 wraps to 496 and -16. */
        lea     OBJECT_XCOLOR,%a0
        lea     OBJECT_ATTR_SRC,%a1
        move.w  #0x01ff,%d1
        move.w  #0x01f0,%d0
object_hide:
        move.w  %d0,(%a0)+
        move.w  %d0,(%a1)+
        dbra    %d1,object_hide

        lea     PALETTE,%a0
        move.w  #0x01ff,%d1
        moveq   #0,%d0
palette_clear:
        move.w  %d0,(%a0)+
        dbra    %d1,palette_clear

/* Eight saturated palette groups color the two rows of sample tiles. */
        lea     PALETTE+0x0020,%a0
        move.w  #0x7c00,%d0          /* red */
        bsr     palette_group
        lea     PALETTE+0x0040,%a0
        move.w  #0x03e0,%d0          /* green */
        bsr     palette_group
        lea     PALETTE+0x0060,%a0
        move.w  #0x001f,%d0          /* blue */
        bsr     palette_group
        lea     PALETTE+0x0080,%a0
        move.w  #0x7fff,%d0          /* white */
        bsr     palette_group
        lea     PALETTE+0x00a0,%a0
        move.w  #0x4210,%d0          /* gray */
        bsr     palette_group
        lea     PALETTE+0x00c0,%a0
        move.w  #0x03ff,%d0          /* cyan */
        bsr     palette_group
        lea     PALETTE+0x00e0,%a0
        move.w  #0x7c1f,%d0          /* magenta */
        bsr     palette_group
        lea     PALETTE+0x0100,%a0
        move.w  #0x7fe0,%d0          /* yellow */
        bsr     palette_group
        move.w  #0x001f,BACKDROP     /* blue until IRQ qualification completes */

/* One object tile per cell, codes 1..32. Mirror both LUT banks because the
   PCB may copy the source bank to the active bank at frame end. */
        lea     OBJECT_CODE,%a0
        lea     OBJECT_XCOLOR,%a1
        lea     YRAM,%a2
        lea     OBJECT_CODE_SRC,%a3
        lea     OBJECT_ATTR_SRC,%a4
        moveq   #1,%d0               /* object code */
        moveq   #8,%d2               /* X */
        moveq   #1,%d3               /* palette group */
        move.w  #0x009e,%d5          /* Y for first row */
        move.w  #31,%d1
object_tiles:
        move.w  %d3,%d4
        lsl.w   #8,%d4
        lsl.w   #3,%d4               /* palette occupies word bits 15:11 */
        or.w    %d2,%d4
        move.w  %d4,(%a1)+           /* palette + 9-bit X coordinate */
        move.w  %d4,(%a4)+           /* mirror source buffer for frame-end copy */
        move.w  %d0,(%a0)+           /* 14-bit sprite code in second LUT word */
        move.w  %d0,(%a3)+
        move.w  %d5,(%a2)+           /* visible with Superman's +0x0e Y offset */
        addq.w  #1,%d0
        addq.w  #1,%d3
        cmpi.w  #9,%d3
        bne.s   1f
        moveq   #1,%d3
1:
        addi.w  #16,%d2
        cmpi.w  #264,%d2
        bne.s   2f
        moveq   #8,%d2
        move.w  #0x00ae,%d5          /* second row */
2:
        dbra    %d1,object_tiles

/* Disable the background-column layer; leave sprite orientation unchanged. */
        move.w  #0x0010,CONTROL
        clr.w   CONTROL+2
        clr.w   CONTROL+4
        clr.w   CONTROL+6

        move.b  (0x0001be22).l,%d7  /* PicoROM stage 0x11: video initialized */
        move.w  #0x0010,WATCHDOG   /* service before enabling board IRQs */
        move.w  #0x0010,VBL_IRQ_ACK /* clear stale/pending VBL latch */
        move.w  #0x0010,CCHIP_IRQ_ACK /* clear stale/pending C-chip latch */
        move.w  #0x2000,%sr         /* count levels 2, 4 and 6 */

/* Qualify VBL traffic (IRQ2 or IRQ6). IRQ4 is tallied separately. Service the
   watchdog while polling; each handler acknowledges its decoded source. */
irq_qualify:
        move.w  #0x0010,WATCHDOG
        tst.w   IRQ4_COUNT
        beq.s   no_irq4_seen
        move.w  #0x03ff,BACKDROP    /* cyan: C-chip IRQ4 observed */
no_irq4_seen:
        move.w  IRQ2_COUNT,%d0
        add.w   IRQ6_COUNT,%d0
        cmpi.w  #32,%d0
        blo.s   irq_qualify

        tst.w   IRQ4_COUNT
        bne.s   irq4_seen
        tst.w   IRQ2_COUNT
        beq.s   irq_only6
        tst.w   IRQ6_COUNT
        beq.s   irq_only2
        move.w  #0x7fff,BACKDROP    /* white: both levels observed */
        bra.s   irq_qualified
irq_only2:
        move.w  #0x03e0,BACKDROP    /* green: IRQ2 observed */
        bra.s   irq_qualified
irq_only6:
        move.w  #0x7c00,BACKDROP    /* red: IRQ6 observed */
        bra.s   irq_qualified
irq4_seen:
        move.w  #0x03ff,BACKDROP    /* cyan: level 4 also observed */
irq_qualified:
        move.b  (0x0001be24).l,%d7  /* PicoROM stage 0x12: 32 IRQs observed */

/* Sixteen finite transport reads. At 8 MHz, two DBRA intervals (65,535 and
   16,383 taken branches plus exit cycles) are nominally 102.4 ms total. IRQ
   handling adds small variable overhead. Service watchdog between intervals. */
        moveq   #15,%d6             /* exactly 16 reads */
heartbeat:
        move.w  #0xffff,%d0
heartbeat_delay_a:
        dbra    %d0,heartbeat_delay_a
        move.w  #0x0010,WATCHDOG
        move.w  #0x3fff,%d0
heartbeat_delay_b:
        dbra    %d0,heartbeat_delay_b
        move.b  (0x0001be08).l,%d7  /* PicoROM heartbeat marker 0x04 */
        dbra    %d6,heartbeat
        move.w  #0x4210,BACKDROP    /* gray: all 16 heartbeat reads completed */

/* No further transport bytes after the finite heartbeat. */
idle:
        move.w  #0x0010,WATCHDOG
        bra.s   idle

/* Palette write: D0 color, A0 first pen, sixteen pens per group. */
palette_group:
        movem.l %d1/%d0,-(%sp)
        move.w  #15,%d1
3:
        move.w  %d0,(%a0)+
        dbra    %d1,3b
        movem.l (%sp)+,%d1/%d0
        rts

/* The IRQ handlers preserve the foreground registers by using none. */
irq2:
        move.w  #0x0010,VBL_IRQ_ACK
        move.w  #0x0010,WATCHDOG
        addq.w  #1,IRQ2_COUNT
        rte

irq4:
        move.w  #0x0010,CCHIP_IRQ_ACK
        move.w  #0x0010,WATCHDOG
        addq.w  #1,IRQ4_COUNT
        rte

irq6:
        move.w  #0x0010,VBL_IRQ_ACK
        move.w  #0x0010,CCHIP_IRQ_ACK
        move.w  #0x0010,WATCHDOG
        addq.w  #1,IRQ6_COUNT
        rte

fatal:
        move.w  #0x2700,%sr
        move.w  #0x7c1f,BACKDROP    /* magenta: fatal, distinct from IRQ6 red */
        move.b  (0x0001be3e).l,%d7  /* PicoROM fatal marker 0x1f */
fatal_loop:
        bra.s   fatal_loop
