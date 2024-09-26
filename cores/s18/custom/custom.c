/* Display hello world on MoonWalker's board */

#define RAM  ((short int*)0Xff000)
#define ORAM ((short int*)0x440000)
#define VRAM ((short int*)0x400000) /* 16kB */
#define PAL  ((short int*)0X840000) /*  4kB */
#define IO   ((short int*)0xE40000)

int main();

__attribute__((section(".vectors"))) const unsigned int vectors[] = {
	0x00000000,	/* initial stack pointer */
	(unsigned int)main
};

void clear_vram() {
	short int* vram = VRAM;
	for(int k=0;k<0x4000;k++) vram[k]=0;
}

void fill_gray_palette() {
	/* PAL xbgrBBBB,GGGGRRRR
	   x optionally used for bright/dimmed */
	short int* pal = PAL;
	short int rgb[] = {
		0x0000, 0x0111, 0x0444, 0x0777,
		0x0AAA, 0x0CCC, 0x0EEE, 0x7FFF
	};
	for(int k=0;k<0x1000/8;k++)
		for( int j=0;j<8;j++)
			pal[k]=rgb[j];
}

int main() {
	/*  same configuration as Shadow Dancer
		This cannot go in a function as the RAM access is not ready
		until the mapper is configured
		Compile with -O1 to avoid getting SP used here
		Do not compile with -O2 or -O3 as it will remove the initialization code
	*/
	short *mapper = (short *)0xfe0020;
	// set up the stack pointer ()
	// __asm__ volatile (
	// 	"move.l #0x1000000,%a7"
	// );
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
	clear_vram();
	fill_gray_palette();
	while(1);
	return 0;
}

