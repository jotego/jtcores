#include "Vprot.h"
#include <cstdlib>
#include <cstdio>

using namespace std;

int collision( int v0, int v1, int v2 ) {
	int data = -v0;
	data = ((data / 8 - 4) & 0x1f) * 0x40;
	data += ((v1 + v2 - 6) / 8 + 12) & 0x3f;
	return data;
}

int sim( Vprot &uut, int v0, int v1, int v2) {
	uut.v0 = v0;
	uut.v1 = v1;
	uut.v2 = v2;
	uut.eval();
	int x=uut.vcalc;
	if(x&0x8000) x|=0xffff<<16;
	return x;
}

void test(Vprot &uut) {
	int v0, v1, v2;
	bool diff=false;

	for( int k=-9; k<9; k++ ) {
		// v0 = rand()%(32767>>1);
		// v1 = rand()%(32767>>1);
		// v2 = rand()%(32767>>1);
		v0 = k;
		v1 = 0x77;
		v2 = 0x6;
		int data = collision(v0,v1,v2);
		int prot = sim(uut, v0,v1,v2);
		// diff = data!=prot;
		diff=true;
		if(diff) {
			printf("#%d, %d <-> %d %c\n",k,data,prot,diff?'*':' ');
			printf("\t%d,%d,%d\n",v0,v1,v2);
			printf("\t%X,%X,%X,%X\n",v0,v1,v2,data);
			// break;
		}
	}
	if(!diff) {
		puts("PASS");
	}
}

int main(int argc, char *argv[]) {
    VerilatedContext context;
    context.commandArgs(argc, argv);
    Vprot uut{&context};
    test(uut);
    return 0;
}