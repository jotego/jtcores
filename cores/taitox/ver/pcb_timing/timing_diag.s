/* Superman P0-039A frame-paced timing diagnostic. */
        .cpu 68000

        .equ WORKRAM,     0x00f00000
        .equ WORKRAM_END, 0x00f04000

        .section .vectors,"a"
        .long   WORKRAM_END-2
        .long   timing_start
        .rept   24
        .long   timing_fatal
        .endr
        .long   timing_irq2                /* vector 26, IRQ2 / VBL */
        .long   timing_fatal               /* vector 27, IRQ3 */
        .long   timing_irq4                /* vector 28, IRQ4 / C-chip */
        .long   timing_fatal               /* vector 29, IRQ5 */
        .long   timing_irq6                /* vector 30, IRQ6 */
        .long   timing_fatal

        .section .text
        .globl timing_start, timing_irq2, timing_irq4, timing_irq6, timing_fatal, timing_main
        .globl timing_baseline, timing_read1, timing_read2, timing_read4
        .globl timing_write1, timing_write2, timing_write4, timing_idle
        .extern timing_irq_tick, timing_next_pc, timing_next_data, timing_redirect, timing_clear_d0

/* Keep startup stackless until work RAM has passed two complementary passes. */
timing_start:
        move.w  #0x2700,%sr
        move.w  #0x0010,0x00400000          /* begin watchdog service before RAM tests */
        move.b  (0x0001be02).l,%d7         /* reset entry marker */
        lea     WORKRAM,%a0
        move.w  #0x0fff,%d1
1:
        move.l  %a0,%d2
        eori.l  #0xa55a3cc3,%d2
        move.l  %d2,(%a0)+
        dbra    %d1,1b
        move.w  #0x0010,0x00400000
        lea     WORKRAM,%a0
        move.w  #0x0fff,%d1
2:
        move.l  %a0,%d2
        eori.l  #0xa55a3cc3,%d2
        cmp.l   (%a0)+,%d2
        bne     timing_fatal
        dbra    %d1,2b
        move.w  #0x0010,0x00400000
        lea     WORKRAM_END-2,%sp
        move.b  (0x0001be20).l,%d7         /* RAM qualification passed */
        jsr     timing_main
3:
        bra.s   3b

/* timing_main has selected the first kernel and initialized all state. */
        .globl timing_start_first
timing_start_first:
        move.w  #0x01f0,%d2                /* deterministic write-data word */
        move.w  #0x2000,%sr
        movea.l timing_next_data,%a0
        movea.l timing_next_pc,%a1
        moveq   #0,%d0
        jmp     (%a1)

/* Vector wrappers pass the actual source; saved SR contains the old IPL. */
timing_irq2:
        move.w  #0x2700,%sr                /* keep shared ISR state nonreentrant */
        move.l  %d0,-(%sp)
        move.l  %d1,-(%sp)
        moveq   #2,%d1
        bra.s   timing_irq_common
timing_irq4:
        move.w  #0x2700,%sr
        move.l  %d0,-(%sp)
        move.l  %d1,-(%sp)
        moveq   #4,%d1
        bra.s   timing_irq_common
timing_irq6:
        move.w  #0x2700,%sr
        move.l  %d0,-(%sp)
        move.l  %d1,-(%sp)
        moveq   #6,%d1
timing_irq_common:
        movem.l %d1-%d7/%a0-%a6,-(%sp)
        /* Clear the source latch before C work; all writes are outside kernels. */
        cmpi.w  #2,%d1
        beq.s   timing_ack2
        cmpi.w  #4,%d1
        beq.s   timing_ack4
        move.w  #0x3000,0x00300000          /* IRQ6 acknowledges both lines */
        move.w  #0x0010,0x00600000
        bra.s   timing_ack_done
timing_ack2:
        move.w  #0x0010,0x00600000
        bra.s   timing_ack_done
timing_ack4:
        move.w  #0x3000,0x00300000
timing_ack_done:
        move.w  #0x0010,0x00400000          /* board watchdog service */
        move.l  %d1,-(%sp)                 /* GCC m68k arguments use 32-bit slots */
        move.l  %d0,-(%sp)
        jsr     timing_irq_tick
        addq.l  #8,%sp
        movem.l (%sp)+,%d1-%d7/%a0-%a6
        move.l  (%sp)+,%d1                 /* restore interrupted D1 */
        move.l  (%sp)+,%d0                 /* restore interrupted D0 before optional reset */
        tst.w   timing_clear_d0
        beq.s   23f
        clr.w   timing_clear_d0
        clr.l   %d0
23:
        tst.w   timing_redirect
        beq.s   12f
        clr.w   timing_redirect
        movea.l timing_next_data,%a0
        move.l  timing_next_pc,2(%sp)      /* resume at selected kernel/idle */
12:
        rte

timing_fatal:
        move.w  #0x2700,%sr
        move.w  #0x7c1f,0x00b003e0          /* magenta backdrop: fatal */
        move.b  (0x0001be3e).l,%d7         /* fatal marker */
4:
        bra.s   4b

/* All kernels are 12 bytes; four slots plus the common count/branch. */
        .balign 2
timing_baseline:
5:
        move.w  %d1,%d1
        move.w  %d1,%d1
        move.w  %d1,%d1
        move.w  %d1,%d1
        addq.l  #1,%d0
        bra.s   5b
timing_read1:
6:
        move.w  (%a0),%d1
        move.w  %d1,%d1
        move.w  %d1,%d1
        move.w  %d1,%d1
        addq.l  #1,%d0
        bra.s   6b
timing_read2:
7:
        move.w  (%a0),%d1
        move.w  (%a0),%d1
        move.w  %d1,%d1
        move.w  %d1,%d1
        addq.l  #1,%d0
        bra.s   7b
timing_read4:
8:
        move.w  (%a0),%d1
        move.w  (%a0),%d1
        move.w  (%a0),%d1
        move.w  (%a0),%d1
        addq.l  #1,%d0
        bra.s   8b
timing_write1:
9:
        move.w  %d2,(%a0)
        move.w  %d1,%d1
        move.w  %d1,%d1
        move.w  %d1,%d1
        addq.l  #1,%d0
        bra.s   9b
timing_write2:
10:
        move.w  %d2,(%a0)
        move.w  %d2,(%a0)
        move.w  %d1,%d1
        move.w  %d1,%d1
        addq.l  #1,%d0
        bra.s   10b
timing_write4:
11:
        move.w  %d2,(%a0)
        move.w  %d2,(%a0)
        move.w  %d2,(%a0)
        move.w  %d2,(%a0)
        addq.l  #1,%d0
        bra.s   11b
timing_idle:
13:
        bra.s   13b

/* 12 IRQ-masked DBRA brackets. Marker addresses encode pair identity in
   low-nine physical address bits; they are all distinct and avoid boot IDs. */
        .globl timing_fixed_suite
timing_fixed_suite:
        move.w  #0x2700,%sr
        /* N=0, three repetitions */
        move.b  (0x0001bc40).l,%d1
        move.b  (0x0001bc42).l,%d1
        move.b  (0x0001bc44).l,%d1
        move.b  (0x0001bc46).l,%d1
        move.b  (0x0001bc48).l,%d1
        move.b  (0x0001bc4a).l,%d1
        /* N=128 */
        move.w  #127,%d0
        move.b  (0x0001bc4c).l,%d1
14:     dbra    %d0,14b
        move.b  (0x0001bc4e).l,%d1
        move.w  #127,%d0
        move.b  (0x0001bc50).l,%d1
15:     dbra    %d0,15b
        move.b  (0x0001bc52).l,%d1
        move.w  #127,%d0
        move.b  (0x0001bc54).l,%d1
16:     dbra    %d0,16b
        move.b  (0x0001bc56).l,%d1
        /* N=256 */
        move.w  #255,%d0
        move.b  (0x0001bc58).l,%d1
17:     dbra    %d0,17b
        move.b  (0x0001bc5a).l,%d1
        move.w  #255,%d0
        move.b  (0x0001bc5c).l,%d1
18:     dbra    %d0,18b
        move.b  (0x0001bc5e).l,%d1
        move.w  #255,%d0
        move.b  (0x0001bc60).l,%d1
19:     dbra    %d0,19b
        move.b  (0x0001bc62).l,%d1
        /* N=512 */
        move.w  #511,%d0
        move.b  (0x0001bc64).l,%d1
20:     dbra    %d0,20b
        move.b  (0x0001bc66).l,%d1
        move.w  #511,%d0
        move.b  (0x0001bc68).l,%d1
21:     dbra    %d0,21b
        move.b  (0x0001bc6a).l,%d1
        move.w  #511,%d0
        move.b  (0x0001bc6c).l,%d1
22:     dbra    %d0,22b
        move.b  (0x0001bc6e).l,%d1
        rts

        .section .buildmeta,"a"
        .balign 4
        .globl timing_image_crc32, timing_suite_crc32
timing_image_crc32:
        .long 0
timing_suite_crc32:
        .long 0
        .section .note.GNU-stack,"",@progbits
