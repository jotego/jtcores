#include <iostream>
#include <fstream>
#include <sstream>

using namespace std;

void write( char *line, ofstream& of) {
	unsigned int x;
	string aux(line);
	stringstream xt(aux);
	xt >> hex >> x;
	char low = x&255;
	of.write( &low, 1);
	unsigned char high = x>>8;
	of.write( (char*)&high, 1);	
}

int main() {
	ofstream of("JTGNG.rom",ofstream::binary);
	ifstream fin("gng.hex");
	int addr=0;
	while( !fin.eof() && addr<32*1024*1024) {
		char line[100];
		int next;
		fin.getline(line,99);
		if( line[0]=='@' ) {
			string aux(&line[1]);
			stringstream xt(aux);
			xt >> hex >> next;
		}
		else next=-1;
		if( next==-1 || addr==next ) {
			write( line, of );
			addr++;
		}
		else {
			cout << "Avanza hasta " << hex << next << endl;
			while( addr < next ) {
				char zero=0;
				of.write( &zero,1 );
				addr++;
			}
		}
		// cout << addr << endl;
	}
	return 0;
}