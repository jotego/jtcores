#include <iostream>
#include <iomanip>
#include <cstring>
#include <istream>
#include <fstream>
#include <stdexcept>
#include <string>
#include <sstream>
#include <algorithm>
#include <vector>

using namespace std;

class Event;

class Tracker {
	friend bool test1();

	string line;
	istream *filein;
	int linecnt;
	// iterating through the events:
	vector<Event*> events;
	int cur;
	string setname;

	void abort(const string& msg);
	void parse();
	void parse_line();
	istream& read_line();
	Tracker(const string& ss);
	void read_meta_data();
	void trim_left();
public:
	Tracker(char *filename);
	~Tracker();
	int TotalLines() { return linecnt; }
	int GetLine()    { return cur; }
	void RebaseTime(long int base);
	void ScaleTime(int factor);
	void Reset();
	string& GetSetName() { return setname; }
	Event *Current();
	Event *Next();
};

class Event {
public:
	long int ticks;
	int addr, data;
	Event();
};

Tracker::Tracker(const string& ss) {
	auto copy = new stringstream(ss);
	filein = copy;
	parse();
}

Tracker::Tracker(char *filename) {
	filein = new fstream(filename);
	if(!filein) throw runtime_error("Cannot open csv file");
	parse();
}

void Tracker::parse() {
	linecnt=0;
	cur=0;
	events.clear();
	events.reserve(512*1024);
	while(read_line()) {
		parse_line();
	}
}

istream& Tracker::read_line() {
	linecnt++;
	getline(*filein,line);
	if(!filein) line="";
	return *filein;
}

void Tracker::parse_line() {
	if(line.size()==0) return;
	if(line[0]=='#' ) {
		read_meta_data();
		return;
	}
	auto ev = new Event();
	auto cnt = sscanf(line.c_str(),"%X,%X,%ld",&ev->addr,&ev->data,&ev->ticks);
	if(cnt!=3) abort("Malformed line in CSV file");
	events.push_back(ev);
}

void Tracker::read_meta_data() {
	trim_left();
	auto k=line.find_first_of(" \t\n");
	if(k==string::npos && line.size()==0) {
		setname="";
	} else {
		setname=line.substr(0,k);
	}
}

void Tracker::trim_left() {
	int k=0;
	bool trim=false;
	for(k=0;k<line.size();k++) {
		if(line[k]==' ' || line[k]=='#') {
			trim = true;
			continue;
		}
		break;
	}
	if(trim) line=line.substr(k);
}

Tracker::~Tracker() {
	for( auto e : events ) delete e;
	events.clear();
	delete filein;
	filein=NULL;
}

void Tracker::abort(const string& msg) {
	stringstream ss;
	ss << msg << "\n at line " << linecnt << "\n" << line << "\n";
	throw runtime_error(ss.str());
}

Event::Event() {
	ticks=0;
	addr=data=0;
}

void Tracker::RebaseTime(long int base) {
	if(events.size()==0) return;
	Reset();
	auto zero = events[0]->ticks;
	for(auto e : events ) {
		e->ticks -= zero;
		e->ticks += base;
		if(e->ticks<0) throw runtime_error("event ticks are not monotonic");
	}
}

void Tracker::ScaleTime(int factor) {
	for(auto e : events ) {
		e->ticks *= factor;
	}
}

void Tracker::Reset() {
	cur = 0;
}

Event* Tracker::Current() {
	if(cur<events.size()) return events[cur];
	return NULL;
}

Event* Tracker::Next() {
	if(cur<events.size()) {
		cur++;
	} else {
		cur = events.size();
	}
	return Current();
}