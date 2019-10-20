#include <iostream>

using namespace std;

int main() {
    while( !cin.eof() ){
        char c[2];
        cin.read(c,2);
        if(cin.eof()) break;
        cout.write(&c[1],1);
    };
    return 0;
}