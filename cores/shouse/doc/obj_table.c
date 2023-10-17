#include <stdio.h>

int main() {
	static const int sprite_size[4] = { 16, 8, 32, 4 };
	for( int attr2=0; attr2<=0x1f;attr2+=2) {
		int sizey = sprite_size[(attr2 & 0x06) >> 1];
		int ty = (attr2 & 0x18) & (~(sizey - 1));
		printf("%2d %d -> %2d\n", sizey, (attr2>>3)&3, ty);
	}
	return 0;
}
