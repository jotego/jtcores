        .cpu 68000

        .section .vectors,"a"
        .long   0x00ff8000
        .long   start
        .rept   24
        .long   fatal
        .endr
        .long   vblank                     /* autovector 2 */

        .section .text
        .globl  start, vblank, measured_loop, start_measurement, fatal
        .globl  kernel_rom_start, kernel_rom_end
        .globl  kernel_rom_w0, kernel_rom_w1, kernel_rom_w2, kernel_rom_w4
        .globl  kernel_rom_0, kernel_rom_1, kernel_rom_2, kernel_rom_4
        .globl  kernel_rom_w0, kernel_rom_w1, kernel_rom_w2, kernel_rom_w4
        .globl  firmware_image_crc32, firmware_suite_crc32
        .globl  kernel_ram_start, kernel_ram_end
        .globl  enter_hot_reload, hot_stub_start, hot_stub_end
        .extern firmware_main, display_main, display_tick, configure_case

/* Stackless address-dependent RAM fill/read/compliment test. */
start:
        move.w  #0x2700,%sr
        lea     0x00ff0000,%a0
        move.w  #0x3fff,%d1
ram_fill:
        move.l  %a0,%d2
        eori.l  #0xa55a3cc3,%d2
        move.l  %d2,(%a0)+
        dbra    %d1,ram_fill

        lea     0x00ff0000,%a0
        move.w  #0x3fff,%d1
ram_check:
        move.l  %a0,%d2
        eori.l  #0xa55a3cc3,%d2
        cmp.l   (%a0)+,%d2
        bne     fatal
        dbra    %d1,ram_check

        lea     0x00ff0000,%a0
        move.w  #0x3fff,%d1
ram_invfill:
        move.l  %a0,%d2
        eori.l  #0xa55a3cc3,%d2
        not.l   %d2
        move.l  %d2,(%a0)+
        dbra    %d1,ram_invfill

        lea     0x00ff0000,%a0
        move.w  #0x3fff,%d1
ram_invcheck:
        move.l  %a0,%d2
        eori.l  #0xa55a3cc3,%d2
        not.l   %d2
        cmp.l   (%a0)+,%d2
        bne     fatal
        dbra    %d1,ram_invcheck

        move.b  (0x0003be20).l,%d7         /* PicoROM boot marker 10 */
        lea     0x00ff8000,%sp
        move.w  #0x0c00,0x00800030         /* release PPU reset; unlock coin inputs */
        jmp     firmware_main

fatal:
        move.w  #0x2700,%sr
        move.w  #0x00de,0x00ff0000
fatal_loop:
        bra.s   fatal_loop

/* D0 is the measured loop counter and is intentionally not saved. */
vblank:
        movem.l %d1/%a0/%a1,-(%sp)
        movea.l 0x00ff0048,%a1             /* target selected outside measurement */
        move.w  0x00ff004c,%d1
        move.w  %d1,(%a1)                  /* equal-cost CPS-A write every VBlank */
        cmpi.w  #CASE_COUNT,0x00ff0020
        beq     vb_display
        tst.w   0x00ff003a
        bne.s   vb_record
        move.w  #1,0x00ff003a            /* discard pending startup VBlank */
        clr.l   %d0
        bra     vb_return

vb_record:
        movea.l 0x00ff0024,%a0             /* sequential raw record pointer */
        move.l  %d0,(%a0)+
        move.l  %a0,0x00ff0024
        clr.l   %d0
        addq.w  #1,0x00ff0022
        cmpi.w  #9,0x00ff0022
        bne     vb_return                 /* identical path for all case samples */
        clr.w   0x00ff0022
        addq.w  #1,0x00ff0020             /* advance case */
        cmpi.w  #CASE_COUNT,0x00ff0020
        beq.s   vb_finish
        moveq   #0,%d1
        move.w  0x00ff0020,%d1
        move.l  %d1,-(%sp)
        jsr     configure_case
        addq.l  #4,%sp
        movem.l (%sp)+,%d1/%a0/%a1
        move.l  0x00ff0030,2(%sp)          /* install next kernel entry */
        movea.l 0x00ff0034,%a0             /* next fixed data address */
        clr.l   %d0
        rte

vb_finish:
        move.b  (0x0003be24).l,%d7         /* optional PicoROM suite-complete marker */
        movem.l (%sp)+,%d1/%a0/%a1
        move.l  #display_main,2(%sp)       /* replace interrupted PC */
        rte

vb_display:
        addq.w  #1,0x00ff003e             /* post-suite host polling tick */
        movem.l %d0/%d1/%a0/%a1,-(%sp)
        jsr     display_tick
        movem.l (%sp)+,%d0/%d1/%a0/%a1
vb_return:
        movem.l (%sp)+,%d1/%a0/%a1
        rte

start_measurement:
        move.w  #0x2000,%sr
        movea.l 0x00ff0034,%a0
        movea.l 0x00ff0030,%a1
        moveq   #0,%d0
        move.w  #0x01ff,%d2
        jmp     (%a1)

measured_loop:
        moveq   #0,%d0
measure_again:
        addq.l  #1,%d0
        bra.s   measure_again

/* Four equal-sized 12-byte kernels; only slots 0..3 perform a bus read. */
        .balign 2
kernel_ram_start:
kernel_rom_start:
kernel_rom_0:
1:
        move.w  %d1,%d1
        move.w  %d1,%d1
        move.w  %d1,%d1
        move.w  %d1,%d1
        addq.l  #1,%d0
        bra.s   1b
kernel_rom_1:
2:
        move.w  (%a0),%d1
        move.w  %d1,%d1
        move.w  %d1,%d1
        move.w  %d1,%d1
        addq.l  #1,%d0
        bra.s   2b
kernel_rom_2:
3:
        move.w  (%a0),%d1
        move.w  (%a0),%d1
        move.w  %d1,%d1
        move.w  %d1,%d1
        addq.l  #1,%d0
        bra.s   3b
kernel_rom_4:
4:
        move.w  (%a0),%d1
        move.w  (%a0),%d1
        move.w  (%a0),%d1
        move.w  (%a0),%d1
        addq.l  #1,%d0
        bra.s   4b
kernel_rom_end:

/* Four matched write kernels; each active operation is one MOVE.W write. */
        .balign 2
kernel_rom_w0:
5:
        move.w  %d1,%d1
        move.w  %d1,%d1
        move.w  %d1,%d1
        move.w  %d1,%d1
        addq.l  #1,%d0
        bra.s   5b
kernel_rom_w1:
6:
        move.w  %d2,(%a0)
        move.w  %d1,%d1
        move.w  %d1,%d1
        move.w  %d1,%d1
        addq.l  #1,%d0
        bra.s   6b
kernel_rom_w2:
7:
        move.w  %d2,(%a0)
        move.w  %d2,(%a0)
        move.w  %d1,%d1
        move.w  %d1,%d1
        addq.l  #1,%d0
        bra.s   7b
kernel_rom_w4:
8:
        move.w  %d2,(%a0)
        move.w  %d2,(%a0)
        move.w  %d2,(%a0)
        move.w  %d2,(%a0)
        addq.l  #1,%d0
        bra.s   8b
kernel_ram_end:

/* The host requests this only after results have been collected.  The CPU
   copies the entire wait loop to work RAM before acknowledging READY.  All
   interrupt handlers and vector fetches remain masked until the new reset
   vector is loaded after an authenticated GO. */
enter_hot_reload:
        move.w  #0x2700,%sr
        lea     hot_stub_start(%pc),%a0
        lea     hot_stub_end(%pc),%a2
        lea     0x00ff9000,%a1
1:
        move.b  (%a0)+,(%a1)+
        cmpa.l  %a2,%a0
        bne.s   1b
        jmp     0x00ff9000

/* Relocatable, stackless code: relative branches and absolute RAM/I/O
   operands only.  The sole ROM reads before GO are PicoROM status/RX bytes. */
hot_stub_start:
        move.b  (0x0003bea4).l,%d0        /* TX 'R': RAM wait is live */
        move.b  (0x00ff0043).l,%d5        /* low byte of ARM RX sequence */
hot_wait_end:
        move.b  (0x0003b808).l,%d0
        cmpi.b  #1,%d0
        bne.s   hot_wait_begin
        move.b  (0x0003b818).l,%d1
        cmp.b   %d5,%d1
        beq.s   hot_wait_end
        move.b  %d1,%d5
        cmpi.b  #'?',(0x0003bc00).l
        bne.s   hot_wait_end
        move.b  (0x0003be96).l,%d0        /* TX 'K': RAM heartbeat */
        bra.s   hot_wait_end
hot_wait_begin:
        move.b  (0x0003b808).l,%d0
        cmpi.b  #1,%d0
        bne.s   hot_wait_begin
        cmpi.b  #'P',(0x0003b800).l
        bne.s   hot_wait_begin
        cmpi.b  #'I',(0x0003b802).l
        bne.s   hot_wait_begin
        cmpi.b  #'C',(0x0003b804).l
        bne.s   hot_wait_begin
        cmpi.b  #'O',(0x0003b806).l
        bne.s   hot_wait_begin
        moveq   #0,%d5                 /* fresh CommsStart resets RX seq */
        move.b  (0x0003beae).l,%d0        /* TX 'W': still waiting in work RAM */
hot_reset_packet:
        lea     0x00ff7010,%a2          /* 'G' followed by eight-byte nonce */
        moveq   #9,%d3
hot_wait_rx:
        cmpi.b  #1,(0x0003b808).l
        bne.s   hot_wait_begin
        move.b  (0x0003b818).l,%d1
        cmp.b   %d5,%d1
        beq.s   hot_wait_rx
        move.b  %d1,%d5
        move.b  (0x0003bc00).l,%d0
        cmp.b   (%a2)+,%d0
        bne.s   hot_reset_packet
        subq.w  #1,%d3
        bne.s   hot_wait_rx
        lea     0x00ff7020,%a3
        moveq   #8,%d3
hot_get_marker:
        cmpi.b  #1,(0x0003b808).l
        bne.s   hot_wait_begin
        move.b  (0x0003b818).l,%d1
        cmp.b   %d5,%d1
        beq.s   hot_get_marker
        move.b  %d1,%d5
        move.b  (0x0003bc00).l,(%a3)+
        subq.w  #1,%d3
        bne.s   hot_get_marker
        lea     0x00ff7020,%a3
        lea     0x0003fff8,%a4         /* both physical lanes, last 4 bytes each */
        moveq   #8,%d3
hot_check_marker:
        cmpm.b  (%a3)+,(%a4)+
        bne.s   hot_reset_packet
        subq.w  #1,%d3
        bne.s   hot_check_marker
        movea.l (0x00000000).l,%sp
        movea.l (0x00000004).l,%a0
        jmp     (%a0)
hot_stub_end:

        .section .buildmeta,"a"
        .balign 4
firmware_image_crc32:
        .long   0
firmware_suite_crc32:
        .long   0

        .section .note.GNU-stack,"",@progbits
