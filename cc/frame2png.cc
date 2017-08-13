#include <png++/png.hpp>
#include <iostream>
#include <fstream>

using namespace std;

int main(int argc,char *argv[]) {
	const int width=256*2, height=256*2;
	png::image<png::rgb_pixel> image(width,height);
	ifstream fin(argv[1]);
	int line=0,x=0;
	while( !fin.eof() && line<height ) {
		char rgbi[4];		
		fin.read(rgbi,4);
		if( fin.eof() ) break;
		int aux = ((((rgbi[3]<<8)|rgbi[2])<<8)|rgbi[1]<<8)|rgbi[0];		
		if( aux==(int)0xffffffff || x>=width ) { 
			x=0; 
			line+=2;
			// cout << hex << aux;
		}
		else {
			for( int k=0; k<2; k++ ) {
				image[line+k][x] = png::rgb_pixel( rgbi[0], rgbi[1], rgbi[2] );
				image[line+k][x+1] = png::rgb_pixel( rgbi[0], rgbi[1], rgbi[2] );
			}
			x+=2;
		}
	}
			
	image.write("output.png");
}