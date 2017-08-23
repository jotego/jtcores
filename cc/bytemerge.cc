#include <fstream>
#include <iostream>

using namespace std;

int main(int argc, char *argv[]) {
	if( argc != 4 ) {
		cerr << "Incorrect number of parameters (" << argc << ")\n";
		return 1;
	}
	ifstream files[2];
	for (int i = 0; i < 2; ++i)
	{
		files[i].open(argv[i+1], ios::in | ios::binary );
		if( !files[i] ) {
			cerr << "Error opnening file " << argv[i+1] << "\n";
			return 2;
		}
	}
	ofstream of(argv[3], ios::out | ios::binary );
	unsigned char *buf[2];
	buf[0] = new unsigned char[1024];
	buf[1] = new unsigned char[1024];
	uint16_t *mix = new uint16_t[1024];
	//int k=0;
	do{
		//cout << "K=" << k++ << endl;
		streamsize sz=1024;
		for (int i = 0; i < 2; ++i)
		{
			files[i].read( (char*)buf[i], sz);
			if( !files[i] && files[i].gcount()!=1024 ) {				
				if( files[i].gcount()==0 ) goto done;
				cerr << "File size is not multiple of 1024 bytes";
				cerr << "gcount == " << files[i].gcount() << "\n";
				return 3;
			}
		}
		for (int i = 0; i < 1024; ++i)
		{
			mix[i] = (buf[1][i]<<8) | buf[0][i];
		}
		of.write( (char*)mix,sz<<1);
	}while( !files[0].eof() && !files[1].eof() );
done:
	delete []buf[0];
	delete []buf[1];
	delete []mix;
	return 0;
}