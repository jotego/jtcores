#include <iostream>

static const int raiga_jumppoints_00[0x100] =
{
	0x6669,    -1,    -1,    -1,    -1,    -1,    -1,    -1,
		-1,    -1,    -1,    -1,    -1,    -1,0x4a46,    -1,
		-1,0x6704,    -2,    -1,    -1,    -1,    -1,    -1,
		-1,    -2,    -1,    -1,    -1,    -1,    -1,    -1,
		-1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,
		-2,    -1,    -1,    -1,    -1,0x4e75,    -1,    -1,
		-1,    -2,    -1,0x4e71,0x60fc,    -1,0x7288,    -1,
		-1,    -1,    -1,    -1,    -1,    -1,    -1,    -1
};

/* these are used the rest of the time */
static const int raiga_jumppoints_other[0x100] =
{
	0x5457,0x494e,0x5f4b,0x4149,0x5345,0x525f,0x4d49,0x5941,
	0x5241,0x5349,0x4d4f,0x4a49,    -1,    -1,    -1,    -1,
		-1,    -1,    -2,0x594f,    -1,0x4e75,    -1,    -1,
		-1,    -2,    -1,    -1,0x4e75,    -1,0x5349,    -1,
		-1,    -1,    -1,0x4e75,    -1,0x4849,    -1,    -1,
		-2,    -1,    -1,0x524f,    -1,    -1,    -1,    -1,
		-1,    -2,    -1,    -1,    -1,    -1,    -1,    -1,
		-1,    -1,    -1,    -1,    -1,    -1,    -1,    -1
};

void dump_table(const char *, const int *lut);

int main() {
	printf("// initial\n");
	dump_table("bootup", raiga_jumppoints_00);
	printf("// gameplay\n");
	dump_table("gameplay", raiga_jumppoints_other);
}

void dump_table(const char *name, const int *lut) {
	for( int k=0; k<0100;k++) {
		int jumppoint = lut[k];
		if(jumppoint!=-1) {
			printf("8'o%o: %s <= 16'h%04X;\n",k,name,((unsigned)jumppoint)&0xffff);
		}
	}
}