/* Display hello world on MoonWalker's board */

#define RAM  ((short int*)0Xff000)
#define ORAM ((short int*)0x440000)
#define VRAM ((short int*)0x400000) /* 16kB */
#define CRAM ((short int*)0x410000) /*  4kB */
#define PAL  ((short int*)0X840000) /*  4kB */
#define IO   ((short int*)0xE40000)

// some GFX codes
#define SOLID  ((short)2)
#define BLANK  ((short)0)

// page codes
#define BLANK_LOPRIO_PAGE	((short)0)
#define BLANK_HIPRIO_PAGE	((short)1)
#define OPAQUE_LOPRIO_PAGE	((short)2)
#define OPAQUE_HIPRIO_PAGE	((short)3)
#define BG_LOPRIO_PAGE		((short)4)
#define BG_HIPRIO_PAGE		((short)5)
#define FG_LOPRIO_PAGE		((short)6)
#define FG_HIPRIO_PAGE		((short)7)

#define FOREGROUND ((short)0)
#define BACKGROUND ((short)1)

#define RGB(r,g,b) (((((b>>1)&0xf)<<8)|(((g>>1)&0xf)<<4)|((r>>1)&0xf) | ((b&0x1)<<14)|((g&0x1)<<13)|((r&0x1)<<12)))

#define RED  RGB(18,4,4)
#define BLUE RGB(4,4,18)

int main();
void vblank();

__attribute__((section(".data"))) volatile int frame_cnt=0;
__attribute__((section(".data"))) short fg_page=0;
__attribute__((section(".data"))) short bg_page=0;

__attribute__((section(".vectors"))) const unsigned int vectors[] = {
	0x00000000,	/* initial stack pointer */
	(unsigned int)main,
	0x00000000,	/* 2: access fault */
	0x00000000,	/* 3: address error */
	0x00000000,	/* 4: illegal instruction */
	0x00000000,	/* 5: divide by zero */
	0x00000000,	/* 6: CHK, CHK2 instructions */
	0x00000000,	/* 7: FTRAP instructions */
	0x00000000,	/* 8: Privilege violation */
	0x00000000,	/* 9: trace */
	0x00000000,	/*10: Line 1010 */
	0x00000000,	/*11: Line 1111 */
	0x00000000,	/*12: reserved */
	0x00000000,	/*13: coprocessor protocol violation */
	0x00000000,	/*14: format error */
	0x00000000,	/*15: unintialized interrupt */
	0x00000000,	/*16: reserved */
	0x00000000,	/*17: reserved */
	0x00000000,	/*18: reserved */
	0x00000000,	/*19: reserved */
	0x00000000,	/*20: reserved */
	0x00000000,	/*21: reserved */
	0x00000000,	/*22: reserved */
	0x00000000,	/*23: reserved */
	0x00000000,	/*24: spurious interrupt */
	0x00000000,	/*25: level 1 interrupt */
	0x00000000,	/*26: level 2 interrupt */
	0x00000000,	/*27: level 3 interrupt */
	(unsigned int)vblank 	/*28: level 4 interrupt */
};

void clear_cram() {
	short int* vram = CRAM;
	short int* max  = CRAM+0x800;
	for(;vram<max;) *vram++=0;
}

void enable_video( short en ) {
	unsigned char *io = (unsigned char*)IO;
	io[(0xe<<1)+1] = en!=0 ? 2 : 0; // VDP disabled, S16 video enabled
}

void fill_char(short code, short color, short prio) {
	short int* vram = CRAM;
	short int* max  = CRAM+(0xE00>>1);
	short clr = code;
	if(prio!=0) clr|=0x8000;
	clr |= (color&7)<<9;
	for(short row=0;row<29;row++) {
		short col=0;
		for(;col<24;col++) *vram++ = 0;
		for(;col<64;col++) *vram++ = clr; // visible area
	}
}

void fill_vram(short code, short prio) {
	short int* vram = VRAM;
	short clr = code & 0x7fff;
	if(prio!=0) clr|=0x8000;
	for(int k=0;k<0x4000;k++) vram[k] = clr;
}

void fill_page(short page, short code, short prio) {
	short int* vram = VRAM+(page&0xf)*64*32;
	short clr = code & 0x7fff;
	if(prio!=0) clr |= 0x8000;
	for(int k=0;k<64*32;k++) vram[k] = clr;
}

// prints on the text layer
void print_at( unsigned char *str, int col, int row, unsigned short prio ) {
	unsigned short int* vram = CRAM;
	unsigned short int* max  = CRAM+(0xE00>>1);
	col += 24;
	vram += col; // & 0x3f;
	vram += (row&0x1f)<<6;
	if (prio!=0) prio=0x8000;
	unsigned short color = 2 << 9;
	prio |= color;
	for( int k=0; str[k]!=0 && vram<max; k++ ) {
		*vram++ = prio | str[k];
	}
}

// prints on a tilemap page
void print_page( unsigned short page, unsigned char *str, int col, int row, unsigned short prio ) {
	unsigned short int* vram = VRAM+(page&0xf)*64*32;
	unsigned short int* max  = VRAM+16*64*32;
	col += 24;
	vram += col; // & 0x3f;
	vram += (row&0x1f)<<6;
	if (prio!=0) prio=0x8000;
	for( int k=0; str[k]!=0 && vram<max; k++ ) {
		*vram++ = prio | str[k];
	}
}

void setup_pages() {
	fill_page(BLANK_LOPRIO_PAGE, 0,0);
	fill_page(BLANK_HIPRIO_PAGE, 0,1);
	fill_page(OPAQUE_LOPRIO_PAGE,2,0);
	fill_page(OPAQUE_HIPRIO_PAGE,2,1);
	fill_page(BG_LOPRIO_PAGE,2,0);
	fill_page(BG_HIPRIO_PAGE,2,1);
	fill_page(FG_LOPRIO_PAGE,2,0);
	fill_page(FG_HIPRIO_PAGE,2,1);

	print_page(FG_LOPRIO_PAGE,"FOREGROUND",10, 9,0);
	print_page(FG_LOPRIO_PAGE,"PRIO LOW",  10,11,0);

	print_page(FG_HIPRIO_PAGE,"FOREGROUND",10, 9,1);
	print_page(FG_HIPRIO_PAGE,"PRIO HI",   10,11,1);

	print_page(BG_LOPRIO_PAGE,"BACKGROUND",10,10,0);
	print_page(BG_LOPRIO_PAGE,"PRIO LOW",  10,11,0);

	print_page(BG_HIPRIO_PAGE,"BACKGROUND",10,10,1);
	print_page(BG_HIPRIO_PAGE,"PRIO HI",   10,11,1);
}

// use BACKGROUND/FOREGROUND macros for layer argument
void set_page(short layer, short page ) {
	short int* vram = CRAM+(0xe80>>1);
	if(layer==BACKGROUND) {
		vram++;
		bg_page = page;
	} else {
		fg_page = page;
	}
	*vram = page;
}

void fill_palette() {
	/* PAL xbgrBBBB,GGGGRRRR
	   x optionally used for bright/dimmed */
	short int* pal = PAL;
	short int gray[] = {
		0x0000, 0x0111, 0x0444, 0x0777,
		0x0AAA, 0x0CCC, 0x0EEE, 0x7FFF
	};
	// set all palettes to gray first
	for(int k=0;k<0x400*4/2;) {
		for( int j=0;j<8;j++) {
			pal[k]=gray[j];
			k++;
		}
	}
	//
	short int rgb[] = {
		// 0, used by FG/BG for opaque block (set reddish)
		RGB(0,  0, 0), RGB(18, 4, 4), RGB(31,31,31), RGB(31,31,31),
		RGB(31,31,31), RGB(31,31,31), RGB(31,31,31), RGB(31,31,31),
		// 1, used by FG/BG when displaying characters
		RGB(0,  0, 0),  RGB(31,31,31), RGB(31,31,31), RGB(28,28,28),
		RGB(20,20,20), RGB( 7, 7, 7), RGB(16,16,16), RGB(22,22,22),
		// 2, entries 0-63 selectable on text layer
		RGB(0,  0, 0), RGB(31,31,31), RGB(31,31,31), RGB(28,28,28),
		RGB(20,20,20), RGB( 7, 7, 7), RGB(16,16,16), RGB(22,22,22),
		// 3, greenish for opaque block
		RGB(0,  0, 0), RGB( 4,18, 4), RGB(31,31,31), RGB(28,28,28),
		RGB(20,20,20), RGB( 7, 7, 7), RGB(16,16,16), RGB(22,22,22)
	};
	pal=PAL;
	for( int j=0;j<8*4;  j++ ) pal[j]=rgb[j];
}

// the compiler generates calls to memcpy
void *memcpy(void *dest, const void *src, int n) {
    char *d = dest;
    const char *s = src;
    while (n--) {
        *d++ = *s++;
    }
    return dest;
}

void char_test(unsigned short prio, short fg_opaque, short bg_opaque) {
	short fill_tile = fg_opaque!=0 || bg_opaque!=0 ? BLANK : SOLID;
	fill_char(fill_tile,3,prio);
	// set the scroll color
	short int* pal = PAL;
	if(bg_opaque!=0) { pal[1] = BLUE; print_at("BACKG.",10,10,prio); }
	if(fg_opaque!=0) { pal[1] = RED;  print_at("FOREG.",10, 9,prio); }

	set_page(BACKGROUND, bg_opaque ?  OPAQUE_LOPRIO_PAGE : BLANK_LOPRIO_PAGE);
	set_page(FOREGROUND, fg_opaque ?  OPAQUE_LOPRIO_PAGE : BLANK_LOPRIO_PAGE);
	print_at("FIXED LAYER",10,8,prio);
	print_at(prio==0 ? "PRIO OFF" : "PRIO ON",10,11,prio);
}

void fg_test(unsigned short prio) {
	short int* pal = PAL;
	pal[1] = RED;
	set_page(BACKGROUND,BLANK_LOPRIO_PAGE);
	set_page(FOREGROUND,prio==1 ? FG_HIPRIO_PAGE : FG_LOPRIO_PAGE);
}

void bg_test(unsigned short prio) {
	short int* pal = PAL;
	pal[1] = BLUE;
	set_page(FOREGROUND,BLANK_LOPRIO_PAGE);
	set_page(BACKGROUND,prio==1 ? BG_HIPRIO_PAGE : BG_LOPRIO_PAGE);
}

void __attribute__((interrupt)) vblank() {
	__asm__ ( // stack all registers
		"movem.l %%d0-%%d7/%%a0-%%a6,-(%%a7)"
	);
	static short test_sel=0;
	static char  coin_l=0xff;
	short int* io = IO;
	frame_cnt++;
	switch(test_sel) {
		// solid text with transparent background
		case 0: char_test(0,0,0); break;
		case 1: char_test(1,0,0); break;
		// transparent text with solid background
		case 2: char_test(0,1,0); break;
		case 3: char_test(1,1,0); break;
		case 4: char_test(0,0,1); break;
		case 5: char_test(1,0,1); break;
		// background tests
		case 6: fill_char(0,0,0); fg_test(0); break;
		case 7: fg_test(1); break;
		case 8: bg_test(0); break;
		case 9: bg_test(1); break;
	}
	char coin = io[4];
	if( (coin&1)==0 && (coin_l&1)==1 ) test_sel = test_sel>9 ? 0 : test_sel+1;
	// if( (frame_cnt&0x1f)==0) test_sel = test_sel>9 ? 0 : test_sel+1;
	coin_l = coin;
	__asm__ ( // recover all registers
		"movem.l (%%a7)+,%%d0-%%d7/%%a0-%%a6"
	);
}

void enable_interrupts() {
	__asm__ volatile (
		"move.w %%sr,%%d0 ;"
		"andi.w #0xf8ff, %%d0 ;"
		"ori.w  #0x0300, %%d0 ;"
		"move.w %%d0,%%sr ;"
		"ori.w #0x2000,%%sr ;"
		:
		:
		: "d0", "cc"
	);
}

// void wait(int frames) {
// 	while(frames--) {
// 		int frame_l = frame_cnt;
// 		while( frame_l==frame_cnt );
// 	}
// }

int main() {
	/*  same configuration as Shadow Dancer
		This cannot go in a function as the RAM access is not ready
		until the mapper is configured
		Compile with -O1 to avoid getting SP used here
		Do not compile with -O2 or -O3 as it will remove the initialization code
	*/
	volatile short *mapper = (short *)0xfe0020;
	*mapper++=0x02;
	*mapper++=0x00;
	*mapper++=0x0c;
	*mapper++=0xc0;
	*mapper++=0x00;
	*mapper++=0x1f;
	*mapper++=0x00;
	*mapper++=0xff;
	*mapper++=0x04;
	*mapper++=0x44;
	*mapper++=0x0d;
	*mapper++=0x40;
	*mapper++=0x00;
	*mapper++=0x84;
	*mapper++=0x00;
	*mapper++=0xe4;
	set_page(0,0);
	set_page(1,0);
	setup_pages();
	clear_cram();
	fill_palette();
	enable_video(1);
	enable_interrupts();
	while(1);
	return 0;
}

