        .text
        .org 0
        .long 0x108000
        .long start
        .rept 62
        .long fatal
        .endr
        .org 0x400
start:  move.w #0x2700,%sr
        lea 0x108000,%sp
        move.w #0x0,(0x1c0400).l
        move.b (0x1be03).l,%d5
        move.b (0x1b819).l,%d7
        move.w #0x5a5a,%d2
| baseline none 0x104000 rep 0
        lea 0x104000,%a0
        move.w #255,%d0
        move.b (0x1bc41).l,%d5
1:      move.w %d1,%d1
        move.w %d1,%d1
        move.w %d1,%d1
        move.w %d1,%d1
        dbra %d0,1b
        move.b (0x1bc43).l,%d5
| baseline none 0x104000 rep 1
        lea 0x104000,%a0
        move.w #255,%d0
        move.b (0x1bc45).l,%d5
1:      move.w %d1,%d1
        move.w %d1,%d1
        move.w %d1,%d1
        move.w %d1,%d1
        dbra %d0,1b
        move.b (0x1bc47).l,%d5
| baseline none 0x104000 rep 2
        lea 0x104000,%a0
        move.w #255,%d0
        move.b (0x1bc49).l,%d5
1:      move.w %d1,%d1
        move.w %d1,%d1
        move.w %d1,%d1
        move.w %d1,%d1
        dbra %d0,1b
        move.b (0x1bc4b).l,%d5
        move.w #0x0,(0x1c0400).l
        cmpi.b #1,(0x1b809).l
        bne.s 3f
2:      move.w #2105,%d3
4:      move.b (0x1b819).l,%d1
        cmp.b %d7,%d1
        bne.s 7f
        dbra %d3,4b
        move.w #0x0,(0x1c0400).l
        bra.s 2b
7:      move.b %d1,%d7
        move.b (0x1bc01).l,%d1
3:
| rom read.w 0xf000 rep 0
        lea 0xf000,%a0
        move.w #255,%d0
        move.b (0x1bc4d).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc4f).l,%d5
| rom read.w 0xf000 rep 1
        lea 0xf000,%a0
        move.w #255,%d0
        move.b (0x1bc51).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc53).l,%d5
| rom read.w 0xf000 rep 2
        lea 0xf000,%a0
        move.w #255,%d0
        move.b (0x1bc55).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc57).l,%d5
        move.w #0x0,(0x1c0400).l
        cmpi.b #1,(0x1b809).l
        bne.s 3f
2:      move.w #2105,%d3
4:      move.b (0x1b819).l,%d1
        cmp.b %d7,%d1
        bne.s 7f
        dbra %d3,4b
        move.w #0x0,(0x1c0400).l
        bra.s 2b
7:      move.b %d1,%d7
        move.b (0x1bc01).l,%d1
3:
| ram write.w 0x104100 rep 0
        lea 0x104100,%a0
        move.w #255,%d0
        move.b (0x1bc59).l,%d5
1:      move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        dbra %d0,1b
        move.b (0x1bc5b).l,%d5
| ram write.w 0x104100 rep 1
        lea 0x104100,%a0
        move.w #255,%d0
        move.b (0x1bc5d).l,%d5
1:      move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        dbra %d0,1b
        move.b (0x1bc5f).l,%d5
| ram write.w 0x104100 rep 2
        lea 0x104100,%a0
        move.w #255,%d0
        move.b (0x1bc61).l,%d5
1:      move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        dbra %d0,1b
        move.b (0x1bc63).l,%d5
        move.w #0x0,(0x1c0400).l
        cmpi.b #1,(0x1b809).l
        bne.s 3f
2:      move.w #2105,%d3
4:      move.b (0x1b819).l,%d1
        cmp.b %d7,%d1
        bne.s 7f
        dbra %d3,4b
        move.w #0x0,(0x1c0400).l
        bra.s 2b
7:      move.b %d1,%d7
        move.b (0x1bc01).l,%d1
3:
| tile_rd read.w 0x600000 rep 0
        lea 0x600000,%a0
        move.w #255,%d0
        move.b (0x1bc65).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc67).l,%d5
| tile_rd read.w 0x600000 rep 1
        lea 0x600000,%a0
        move.w #255,%d0
        move.b (0x1bc69).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc6b).l,%d5
| tile_rd read.w 0x600000 rep 2
        lea 0x600000,%a0
        move.w #255,%d0
        move.b (0x1bc6d).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc6f).l,%d5
        move.w #0x0,(0x1c0400).l
        cmpi.b #1,(0x1b809).l
        bne.s 3f
2:      move.w #2105,%d3
4:      move.b (0x1b819).l,%d1
        cmp.b %d7,%d1
        bne.s 7f
        dbra %d3,4b
        move.w #0x0,(0x1c0400).l
        bra.s 2b
7:      move.b %d1,%d7
        move.b (0x1bc01).l,%d1
3:
| tile_wr write.w 0x600000 rep 0
        lea 0x600000,%a0
        move.w #255,%d0
        move.b (0x1bc71).l,%d5
1:      move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        dbra %d0,1b
        move.b (0x1bc73).l,%d5
| tile_wr write.w 0x600000 rep 1
        lea 0x600000,%a0
        move.w #255,%d0
        move.b (0x1bc75).l,%d5
1:      move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        dbra %d0,1b
        move.b (0x1bc77).l,%d5
| tile_wr write.w 0x600000 rep 2
        lea 0x600000,%a0
        move.w #255,%d0
        move.b (0x1bc79).l,%d5
1:      move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        dbra %d0,1b
        move.b (0x1bc7b).l,%d5
        move.w #0x0,(0x1c0400).l
        cmpi.b #1,(0x1b809).l
        bne.s 3f
2:      move.w #2105,%d3
4:      move.b (0x1b819).l,%d1
        cmp.b %d7,%d1
        bne.s 7f
        dbra %d3,4b
        move.w #0x0,(0x1c0400).l
        bra.s 2b
7:      move.b %d1,%d7
        move.b (0x1bc01).l,%d1
3:
| objram read.w 0x180000 rep 0
        lea 0x180000,%a0
        move.w #255,%d0
        move.b (0x1bc7d).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc7f).l,%d5
| objram read.w 0x180000 rep 1
        lea 0x180000,%a0
        move.w #255,%d0
        move.b (0x1bc81).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc83).l,%d5
| objram read.w 0x180000 rep 2
        lea 0x180000,%a0
        move.w #255,%d0
        move.b (0x1bc85).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc87).l,%d5
        move.w #0x0,(0x1c0400).l
        cmpi.b #1,(0x1b809).l
        bne.s 3f
2:      move.w #2105,%d3
4:      move.b (0x1b819).l,%d1
        cmp.b %d7,%d1
        bne.s 7f
        dbra %d3,4b
        move.w #0x0,(0x1c0400).l
        bra.s 2b
7:      move.b %d1,%d7
        move.b (0x1bc01).l,%d1
3:
| pal read.w 0x140000 rep 0
        lea 0x140000,%a0
        move.w #255,%d0
        move.b (0x1bc89).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc8b).l,%d5
| pal read.w 0x140000 rep 1
        lea 0x140000,%a0
        move.w #255,%d0
        move.b (0x1bc8d).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc8f).l,%d5
| pal read.w 0x140000 rep 2
        lea 0x140000,%a0
        move.w #255,%d0
        move.b (0x1bc91).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc93).l,%d5
        move.w #0x0,(0x1c0400).l
        cmpi.b #1,(0x1b809).l
        bne.s 3f
2:      move.w #2105,%d3
4:      move.b (0x1b819).l,%d1
        cmp.b %d7,%d1
        bne.s 7f
        dbra %d3,4b
        move.w #0x0,(0x1c0400).l
        bra.s 2b
7:      move.b %d1,%d7
        move.b (0x1bc01).l,%d1
3:
        move.b (0x1be25).l,%d5
idle:   move.w #0x0,(0x1c0400).l
        move.w #0x3fff,%d0
4:      dbra %d0,4b
        bra.s idle
fatal:  move.b (0x1be3f).l,%d5
5:      move.w #0x0,(0x1c0400).l
        move.w #0x3fff,%d0
6:      dbra %d0,6b
        bra.s 5b
