        .text
        .org 0
        .long 0x84000
        .long start
        .rept 62
        .long fatal
        .endr
        .org 0x400
start:  move.w #0x2700,%sr
        lea 0x84000,%sp
        move.w #0x0,(0xa0080).l
        move.w #0x0,(0xa0020).l   | punkshot_0a0020_w: RMRD (bit 3)=0 so 0x10xxxx/0x11xxxx hit RAM, sound IRQ (bit 2) low
        move.b (0x1be02).l,%d5
        move.b (0x1b818).l,%d7
        move.w #0x5a5a,%d2
| baseline none 0x80000 rep 0
        lea 0x80000,%a0
        move.w #255,%d0
        move.b (0x1bc40).l,%d5
1:      move.w %d1,%d1
        move.w %d1,%d1
        move.w %d1,%d1
        move.w %d1,%d1
        dbra %d0,1b
        move.b (0x1bc42).l,%d5
| baseline none 0x80000 rep 1
        lea 0x80000,%a0
        move.w #255,%d0
        move.b (0x1bc44).l,%d5
1:      move.w %d1,%d1
        move.w %d1,%d1
        move.w %d1,%d1
        move.w %d1,%d1
        dbra %d0,1b
        move.b (0x1bc46).l,%d5
| baseline none 0x80000 rep 2
        lea 0x80000,%a0
        move.w #255,%d0
        move.b (0x1bc48).l,%d5
1:      move.w %d1,%d1
        move.w %d1,%d1
        move.w %d1,%d1
        move.w %d1,%d1
        dbra %d0,1b
        move.b (0x1bc4a).l,%d5
        move.w #0x0,(0xa0080).l
        cmpi.b #1,(0x1b808).l
        bne.s 3f
2:      move.w #1578,%d3
4:      move.b (0x1b818).l,%d1
        cmp.b %d7,%d1
        bne.s 7f
        dbra %d3,4b
        move.w #0x0,(0xa0080).l
        bra.s 2b
7:      move.b %d1,%d7
        move.b (0x1bc00).l,%d1
3:
| rom read.w 0x1f000 rep 0
        lea 0x1f000,%a0
        move.w #255,%d0
        move.b (0x1bc4c).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc4e).l,%d5
| rom read.w 0x1f000 rep 1
        lea 0x1f000,%a0
        move.w #255,%d0
        move.b (0x1bc50).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc52).l,%d5
| rom read.w 0x1f000 rep 2
        lea 0x1f000,%a0
        move.w #255,%d0
        move.b (0x1bc54).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc56).l,%d5
        move.w #0x0,(0xa0080).l
        cmpi.b #1,(0x1b808).l
        bne.s 3f
2:      move.w #1578,%d3
4:      move.b (0x1b818).l,%d1
        cmp.b %d7,%d1
        bne.s 7f
        dbra %d3,4b
        move.w #0x0,(0xa0080).l
        bra.s 2b
7:      move.b %d1,%d7
        move.b (0x1bc00).l,%d1
3:
| ram write.w 0x80100 rep 0
        lea 0x80100,%a0
        move.w #255,%d0
        move.b (0x1bc58).l,%d5
1:      move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        dbra %d0,1b
        move.b (0x1bc5a).l,%d5
| ram write.w 0x80100 rep 1
        lea 0x80100,%a0
        move.w #255,%d0
        move.b (0x1bc5c).l,%d5
1:      move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        dbra %d0,1b
        move.b (0x1bc5e).l,%d5
| ram write.w 0x80100 rep 2
        lea 0x80100,%a0
        move.w #255,%d0
        move.b (0x1bc60).l,%d5
1:      move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        dbra %d0,1b
        move.b (0x1bc62).l,%d5
        move.w #0x0,(0xa0080).l
        cmpi.b #1,(0x1b808).l
        bne.s 3f
2:      move.w #1578,%d3
4:      move.b (0x1b818).l,%d1
        cmp.b %d7,%d1
        bne.s 7f
        dbra %d3,4b
        move.w #0x0,(0xa0080).l
        bra.s 2b
7:      move.b %d1,%d7
        move.b (0x1bc00).l,%d1
3:
| tile_rd read.w 0x100100 rep 0
        lea 0x100100,%a0
        move.w #255,%d0
        move.b (0x1bc64).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc66).l,%d5
| tile_rd read.w 0x100100 rep 1
        lea 0x100100,%a0
        move.w #255,%d0
        move.b (0x1bc68).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc6a).l,%d5
| tile_rd read.w 0x100100 rep 2
        lea 0x100100,%a0
        move.w #255,%d0
        move.b (0x1bc6c).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc6e).l,%d5
        move.w #0x0,(0xa0080).l
        cmpi.b #1,(0x1b808).l
        bne.s 3f
2:      move.w #1578,%d3
4:      move.b (0x1b818).l,%d1
        cmp.b %d7,%d1
        bne.s 7f
        dbra %d3,4b
        move.w #0x0,(0xa0080).l
        bra.s 2b
7:      move.b %d1,%d7
        move.b (0x1bc00).l,%d1
3:
| tile_wr write.w 0x100100 rep 0
        lea 0x100100,%a0
        move.w #255,%d0
        move.b (0x1bc70).l,%d5
1:      move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        dbra %d0,1b
        move.b (0x1bc72).l,%d5
| tile_wr write.w 0x100100 rep 1
        lea 0x100100,%a0
        move.w #255,%d0
        move.b (0x1bc74).l,%d5
1:      move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        dbra %d0,1b
        move.b (0x1bc76).l,%d5
| tile_wr write.w 0x100100 rep 2
        lea 0x100100,%a0
        move.w #255,%d0
        move.b (0x1bc78).l,%d5
1:      move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        move.w %d2,(%a0)
        dbra %d0,1b
        move.b (0x1bc7a).l,%d5
        move.w #0x0,(0xa0080).l
        cmpi.b #1,(0x1b808).l
        bne.s 3f
2:      move.w #1578,%d3
4:      move.b (0x1b818).l,%d1
        cmp.b %d7,%d1
        bne.s 7f
        dbra %d3,4b
        move.w #0x0,(0xa0080).l
        bra.s 2b
7:      move.b %d1,%d7
        move.b (0x1bc00).l,%d1
3:
| obj read.w 0x110400 rep 0
        lea 0x110400,%a0
        move.w #255,%d0
        move.b (0x1bc7c).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc7e).l,%d5
| obj read.w 0x110400 rep 1
        lea 0x110400,%a0
        move.w #255,%d0
        move.b (0x1bc80).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc82).l,%d5
| obj read.w 0x110400 rep 2
        lea 0x110400,%a0
        move.w #255,%d0
        move.b (0x1bc84).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc86).l,%d5
        move.w #0x0,(0xa0080).l
        cmpi.b #1,(0x1b808).l
        bne.s 3f
2:      move.w #1578,%d3
4:      move.b (0x1b818).l,%d1
        cmp.b %d7,%d1
        bne.s 7f
        dbra %d3,4b
        move.w #0x0,(0xa0080).l
        bra.s 2b
7:      move.b %d1,%d7
        move.b (0x1bc00).l,%d1
3:
| pal read.w 0x90000 rep 0
        lea 0x90000,%a0
        move.w #255,%d0
        move.b (0x1bc88).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc8a).l,%d5
| pal read.w 0x90000 rep 1
        lea 0x90000,%a0
        move.w #255,%d0
        move.b (0x1bc8c).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc8e).l,%d5
| pal read.w 0x90000 rep 2
        lea 0x90000,%a0
        move.w #255,%d0
        move.b (0x1bc90).l,%d5
1:      move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        move.w (%a0),%d1
        dbra %d0,1b
        move.b (0x1bc92).l,%d5
        move.w #0x0,(0xa0080).l
        cmpi.b #1,(0x1b808).l
        bne.s 3f
2:      move.w #1578,%d3
4:      move.b (0x1b818).l,%d1
        cmp.b %d7,%d1
        bne.s 7f
        dbra %d3,4b
        move.w #0x0,(0xa0080).l
        bra.s 2b
7:      move.b %d1,%d7
        move.b (0x1bc00).l,%d1
3:
        move.b (0x1be24).l,%d5
idle:   move.w #0x0,(0xa0080).l
        move.w #0x3fff,%d0
4:      dbra %d0,4b
        bra.s idle
fatal:  move.b (0x1be3e).l,%d5
5:      move.w #0x0,(0xa0080).l
        move.w #0x3fff,%d0
6:      dbra %d0,6b
        bra.s 5b
