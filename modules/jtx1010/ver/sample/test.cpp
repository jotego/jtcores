#include "verilated_vcd_c.h"
#include "UUT.h"
#include "UUT___024root.h"
#include "UUT_jtx1010.h"
#include "tracker.h"
#include "wavewritter.h"

#include <fstream>
#include <vector>
#include <stdexcept>
#include <cstdlib>

using namespace std;

typedef vector<char> rom_t;

size_t get_file_length(ifstream &file);
const int CH=16;

class Sim {
	Event *cur;
	long int ticks;
	const int scale; // number of clock cycles per cen. Minimum 2
	bool tracker_en;
	vluint64_t dump_start;
public:
	UUT& uut;
	Tracker& tracker;
	WaveWritter wav;
	WaveWritter *chwav[CH];
	VerilatedVcdC* tracer;
	int ticks_48kHz, clk, channel, rom_mask, cen_cnt;
	bool keep;
	rom_t rom;
	vluint64_t semi, simtime, finish_time;
	enum SaveWaveforms {
		SaveAll,
		DontSave
	};
	Sim(UUT& _uut, Tracker& _tracker, string& wavfilename, SaveWaveforms save);
	~Sim();
	void prepare_tracer();
	void read_rom();
	void apply_rom_data();
	void advance_half_period();
	void set_default_inputs();
	void run_simulation();
	int time2ticks(vluint64_t time_in_ps) { return int(time_in_ps/(2L*semi)); }
	bool done();
	void clock(int n);
	void reset();
	void update_wav();
	bool program();
	void save_waveforms();
	void clock_enable();
	void SetDumpStart(vluint64_t _start);
	void enable_dump_if_needed();
	// per-channel waveforms
	void update_chwav();
	void make_channel_wav(const string& basename);
};

const int SAMPLE_RATE=48048;

Sim::Sim(UUT& _uut, Tracker& _tracker, string& wavfilename, SaveWaveforms save) :
	uut(_uut), wav(wavfilename,SAMPLE_RATE,false),
	tracker(_tracker), scale(2)
{
	keep = save==SaveAll;
	semi = (vluint64_t)31250/scale; // in ps (scale*16 MHz)
	simtime = 0;
	tracker.ScaleTime(scale);
	finish_time = 2000; // in ms
	ticks_48kHz = 333*scale; // slightly faster (48048 Hz)
	clk=0;
	cen_cnt=scale;
	channel = 7;
	ticks = 0;
	cur = NULL;
	make_channel_wav(wavfilename);
	read_rom();
	set_default_inputs();
	tracer=NULL;
	dump_start = 0;
	if(keep) prepare_tracer();
	reset();
	tracker.RebaseTime(ticks/scale);
	cur = tracker.Current();
}

void Sim::make_channel_wav(const string& filename) {
	string basename = filename;
	if( auto k=filename.find_last_of("."); k!=string::npos ) {
		basename = filename.substr(0,k);
	}
	for(int k=0;k<CH;k++) {
		stringstream ss;
		ss << basename << "-" << setw(2) << setfill('0') << k << ".wav";
		chwav[k] = new WaveWritter(ss.str(),SAMPLE_RATE,false);
	}
}

void Sim::read_rom() {
	ifstream file("rom.bin",ios::binary);
	if(!file) throw runtime_error("Cannot open rom.bin");

	auto file_len = get_file_length(file);
	rom.resize(file_len);
	file.read(rom.data(),rom.size());
	rom_mask = file_len-1;
	printf("Read %ld bytes for rom.bin. Mask = $%X\n",file_len,rom_mask);
}

size_t get_file_length(ifstream &file) {
	file.seekg(0,ios::end);
	auto len = file.tellg();
	file.seekg(0,ios::beg);
	return len;
}

void Sim::set_default_inputs() {
	uut.rst       = 0;
	uut.clk       = 0;
	uut.cen       = 1;
	uut.addr      = 0;
	uut.we        = 0;
	uut.cs        = 1;
	uut.din       = 0;
	uut.rom_data  = 0;
}

void Sim::prepare_tracer() {
    Verilated::traceEverOn(true);
    tracer = new VerilatedVcdC;
    uut.trace( tracer, 99 );
    tracer->open("test.vcd");
}

Sim::~Sim() {
	delete tracer;
	tracer = NULL;
	for( int k=0; k<CH; k++ ) {
		delete chwav[k];
		chwav[k] = NULL;
	}
}

void Sim::SetDumpStart(vluint64_t _start) {
	if(_start!=0) {
		keep = false;
		dump_start = _start;
	}
}

void Sim::reset() {
	tracker_en = false;
	uut.rst = 1;
	clock(ticks_48kHz);
	uut.rst = 0;
	clock(ticks_48kHz);
	tracker_en = true;
	tracker.Reset();
}

void Sim::run_simulation() {
	while( !done() ) {
		clock(ticks_48kHz);
		update_wav();
		update_chwav();
		enable_dump_if_needed();
	}
}

void Sim::enable_dump_if_needed() {
	if(keep || dump_start==0) return;
	if(simtime/1'000'000'000 >=dump_start) keep = true;
}

bool Sim::done() {
	bool is_tracker_over = cur==NULL;
	bool is_timeout = simtime/1'000'000'000 >= finish_time;
	if(is_timeout) printf("timeout at line %d\n",tracker.GetLine());
	if(is_tracker_over) {
		bool channels_active = uut.jtx1010->keyon!=0;
		if(channels_active) is_tracker_over = false;
	}
	return is_tracker_over || is_timeout;
}

void Sim::clock(int n) {
	n <<= 1;
	while( n-- > 0 ) {
		apply_rom_data();
		uut.eval();
		advance_half_period();
		if( uut.contextp()->gotFinish() ) return;
		if( keep ) tracer->dump(simtime);
		if(n&1) {
			ticks++;
			clock_enable();
		}
		if( (n&7) == 7 && tracker_en) {
			if( program() ) {
				cur = tracker.Next();
				if(cur==NULL) {
					printf("Reached EOF at line %d\n",tracker.GetLine());
				}
			}
		}
	}
}

void Sim::clock_enable() {
	uut.cen = 0;
	cen_cnt--;
	if(cen_cnt==0)	 {
		uut.cen = 1;
		cen_cnt=scale;
	}
}

void Sim::apply_rom_data() {
	if(uut.rom_cs==0) return;
	uut.rom_data = rom[uut.rom_addr & rom_mask];
}

void Sim::advance_half_period() {
	clk++;
	uut.clk = clk&1;
	simtime += semi;
}

bool Sim::program() {
	uut.we = 0;
	if(cur==NULL) return false;
	if(ticks>=cur->ticks) {
		uut.addr = cur->addr;
		uut.din  = cur->data;
		uut.we   = 1;
		return true;
	}
	return false;
}

void Sim::update_wav() {
    int16_t snd[2];
    snd[0] = uut.left;
    snd[1] = uut.right;
    wav.write(snd);
}

void Sim::update_chwav() {
	for(int k=0; k<CH; k++) {
		int16_t snd[2];
		snd[0] = uut.jtx1010->sim_sample[k];
		snd[1] = snd[0];
		chwav[k]->write(snd);
	}
}

class Args{
	int argc, k;
	char **argv;
public:
	vluint64_t finish_time, dump_start;
	char *filename;
	string wavfilename;
	bool keep;
	Args(int _argc, char *_argv[]);
	void parse_dash_arg();
	void collect_args();
	void check_args();
	void make_wav_filename();
};

Args::Args(int _argc, char *_argv[]) {
	argc = _argc;
	argv = _argv;
	finish_time = 300;
	keep = false;
	dump_start=0;

	collect_args();
	check_args();
	make_wav_filename();
}

void Args::collect_args() {
	filename=NULL;
	for(k=1;k<argc;) {
		if(argv[k]=="") { k++; continue; }
		if(argv[k][0]=='-') {
			parse_dash_arg();
			continue;
		}
		filename = argv[k];
		k++;
	}
}

void Args::parse_dash_arg() {
	string s(argv[k]);
	if(s=="-t" || s=="--time") {
		if(k>=argc) {
			printf("Expecting value after --time\n");
			exit(1);
		}
		finish_time = strtol(argv[k+1],NULL,0);
		k+=2;
		return;
	}
	if(s=="-w" || s=="--keep") {
		keep = true;
		k++;
		if(k>=argc) return;
		if(argv[k][0]>='0' && argv[k][0]<='9') {
			dump_start = strtol(argv[k],NULL,0);
			k++;
		}
		return;
	}
}

void Args::check_args() {
	if(filename==NULL) {
		printf("usage: %s <file-name.yml>\n",argv[0]);
		exit(1);
	}
}

void Args::make_wav_filename() {
	string fn(filename);
	auto last_dot = fn.find_last_of(".");
	if(last_dot==string::npos) {
		wavfilename = fn;
	} else {
		wavfilename = fn.substr(0,last_dot)+".wav";
	}
}

int main(int argc, char *argv[]) {
    VerilatedContext context;
    context.commandArgs(argc, argv);
    Args args(argc,argv);
    Tracker tracker(args.filename);
    UUT uut{&context};
    auto keep = args.keep ? Sim::SaveAll : Sim::DontSave;
    Sim sim(uut,tracker,args.wavfilename,keep);
    sim.finish_time = args.finish_time;
    sim.SetDumpStart(args.dump_start);
    sim.run_simulation();
    return 0;
};