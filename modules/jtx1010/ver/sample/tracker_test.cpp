#include "tracker.h"
#include <cstdio>

using namespace std;

bool test1();
bool test2();

int main() {
	bool pass = test1();
	if(!pass) {
		printf("FAIL\n");
	}
	return 0;
}


bool test1() {
	string test_yml(R"(# setname filename
0x22f,0x00,396684
0x224,0x10,396799
)");
	Tracker tracker(test_yml);
	if( auto setname = tracker.GetSetName(); setname!="setname" ) {
		printf("Setname not read correctly. Got '%s'\n",setname.c_str());
		return false;
	}
	if( auto len=tracker.events.size();len!=2 ) {
		printf("Expected 2 elements, got %ld\n",len);
		return false;
	}
	if( auto addr = tracker.events[1]->addr; addr!= 0x224 ) {
		printf("Wrong address for entry 1. Got %d\n",addr);
		return false;
	}
	if( auto ticks = tracker.events[1]->ticks; ticks!= 396799 ) {
		printf("Wrong ticks for entry 1. Got %ld\n",ticks);
		return false;
	}
	printf("test1 PASS\n");
	return true;
}