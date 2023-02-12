#include <iostream>
#include <iomanip>

using namespace std;

int main() {
    int x;
    cin >> hex >> x;
    do {
        cout << hex << (x&0xff) << '\n';
        x >>= 8;
        cout << hex << (x&0xff) << '\n';
        cin >> hex >> x;
    }while( !cin.eof() );
    return 0;
}