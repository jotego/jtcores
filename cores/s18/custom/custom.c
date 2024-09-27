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

void fill_char(short code, short prio) {
	short int* vram = CRAM;
	short int* max  = CRAM+(0xE00>>1);
	short clr = code;
	if(prio!=0) clr|=0x8000;
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

// layer=0 -> foreground
// layer=1 -> background
void set_page(short layer, short page ) {
	short int* vram = CRAM+(0xe80>>1);
	if(layer==1) {
		vram++;
		bg_page = page;
	} else {
		fg_page = page;
	}
	*vram = page;
}

void fill_gray_palette() {
	/* PAL xbgrBBBB,GGGGRRRR
	   x optionally used for bright/dimmed */
	short int* pal = PAL;
	short int rgb[] = {
		0x0000, 0x0111, 0x0444, 0x0777,
		0x0AAA, 0x0CCC, 0x0EEE, 0x7FFF
	};
	for(int k=0;k<0x400*4/2;)
		for( int j=0;j<8;j++) {
			pal[k]=rgb[j];
			k++;
		}
}

// prints on the text layer
void print_at( unsigned char *str, int col, int row, unsigned short prio ) {
	unsigned short int* vram = CRAM;
	unsigned short int* max  = CRAM+(0xE00>>1);
	col += 24;
	vram += col; // & 0x3f;
	vram += (row&0x1f)<<6;
	if (prio!=0) prio=0x8000;
	for( int k=0; str[k]!=0 && vram<max; k++ ) {
		*vram++ = prio | str[k];
	}
}

// prints on the foreground layer
void print_page( unsigned short page, unsigned char *str, int col, int row, unsigned short prio ) {
	unsigned short int* vram = VRAM+(page&0xf)*64*32;
	unsigned short int* max  = VRAM+(0x400*4/2);
	col += 24;
	vram += col; // & 0x3f;
	vram += (row&0x1f)<<6;
	if (prio!=0) prio=0x8000;
	for( int k=0; str[k]!=0 && vram<max; k++ ) {
		*vram++ = prio | str[k];
	}
}

void enable_video() {
	unsigned char *io = (unsigned char*)IO;
	io[(0xe<<1)+1] = 2; // VDP disabled, S16 video enabled
}

void char_test(unsigned short prio) {
	fill_char(SOLID,prio);
	fill_vram(BLANK,0);
	print_at("FIXED LAYER",10,12,prio);
	print_at(prio==0 ? "PRIORITY OFF" : "PRIORITY ON",10,13,prio);
}

void fg_test(unsigned short prio) {
	fill_char(BLANK,0);
	fill_page(fg_page&0xf,SOLID,prio);
	fill_page(bg_page&0xf,BLANK,0);
	short pg = fg_page & 0xf;
	print_page(pg, "FOREGROUND",10,12,prio);
	print_page(pg, prio==0 ? "PRIORITY OFF" : "PRIORITY ON",10,13,prio);
}

void bg_test(unsigned short prio) {
	fill_char(BLANK,0);
	fill_page(fg_page&0xf,BLANK,0);
	fill_page(bg_page&0xf,SOLID,prio);
	short bg = bg_page & 0xf;
	print_page(bg,"BACKGROUND",10,12,prio);
	print_page(bg,prio==0 ? "PRIORITY OFF" : "PRIORITY ON",10,13,prio);
}

void __attribute__((interrupt)) vblank() {
	frame_cnt++;
	switch(frame_cnt&0x1f) {
	case 0x00: char_test(0); break;
	case 0x10: char_test(1); break;
	}
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
	enable_interrupts();
	enable_video();
	set_page(0,0x0123);
	set_page(1,0x89AB);
	clear_cram();
	fill_vram(BLANK,0);
	fill_gray_palette();
	const short int pause=1;
	while(1) {
		// wait(pause);
	// 	// char_test(1);
	// 	// wait(pause);
	// 	fg_test(0);
	// 	wait(pause);
	// 	// fg_test(1);
	// 	// wait(pause);
	// 	bg_test(0);
	// 	wait(pause);
	// 	// bg_test(1);
	// 	// wait(pause);
	}
	return 0;
}

