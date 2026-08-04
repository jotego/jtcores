#include <fstream>
#include <map>
#include <sstream>
#include <stdexcept>

#include "cabinet.h"
#include "sim_utils.h"

using namespace std;

static const map<string, unsigned>& actions() {
    static const map<string, unsigned> table = {
        {"coin", 0x000001}, {"service", 0x000002}, {"1p", 0x000004}, {"2p", 0x000008},
        {"right", 0x000010}, {"left", 0x000020}, {"down", 0x000040}, {"up", 0x000080},
        {"b1", 0x000100}, {"b2", 0x000200}, {"b3", 0x000400}, {"test", 0x000800},
        {"reset", 0x001000}, {"2coin", 0x002000}, {"2right", 0x004000}, {"2left", 0x008000},
        {"2down", 0x010000}, {"2up", 0x020000}, {"2b1", 0x040000}, {"2b2", 0x080000},
        {"2b3", 0x100000}
    };
    return table;
}

static vector<string> words(const string& line) {
    vector<string> result;
    istringstream stream(line);
    for( string word; stream >> word; ) result.push_back(word);
    return result;
}

static CabinetFrame parse_frame(const vector<string>& tokens, size_t start, int line_no) {
    CabinetFrame frame;
    for( ; start < tokens.size(); start++ ) {
        const string token = lower(tokens[start]);
        if( token.rfind("dipsw=", 0) == 0 ) {
            if( frame.has_dipsw ) throw runtime_error("duplicate dipsw entry at cabinet line " + to_string(line_no));
            frame.dipsw = parse_hex(token.substr(6), "dipsw value");
            frame.has_dipsw = true;
            continue;
        }
        if( token.rfind("cheat=", 0) == 0 ) {
            const string name = token.substr(6);
            if( !valid_identifier(name) ) throw runtime_error("invalid cheat name at cabinet line " + to_string(line_no));
            frame.cheats.push_back(name);
            continue;
        }
        if( token == "tracing_on" ) {
            if( frame.tracing_on ) throw runtime_error("duplicate tracing_on entry at cabinet line " + to_string(line_no));
            frame.tracing_on = true;
            continue;
        }
        if( token == "dump" ) {
            if( frame.dump ) throw runtime_error("duplicate dump entry at cabinet line " + to_string(line_no));
            frame.dump = true;
            continue;
        }
        const auto action = actions().find(token);
        if( action == actions().end() ) {
            throw runtime_error("unknown cabinet action '" + tokens[start] + "' at line " + to_string(line_no));
        }
        frame.inputs |= action->second;
    }
    return frame;
}

static uint64_t duration(const vector<string>& tokens, size_t& start, uint64_t frame_count, int line_no, bool& absolute) {
    absolute = false;
    const string& first = tokens.front();
    if( first[0] == '=' ) {
        absolute = true;
        const uint64_t final_frame = parse_number(first.substr(1), "final frame");
        if( final_frame + 1 < frame_count ) {
            throw runtime_error("final frame is before the current frame at cabinet line " + to_string(line_no));
        }
        start = 1;
        return final_frame - frame_count + 1;
    }
    char *end;
    const long number = strtol(first.c_str(), &end, 0);
    if( *end == 0 ) {
        if( number < 0 ) throw runtime_error("negative frame count at cabinet line " + to_string(line_no));
        start = 1;
        return static_cast<uint64_t>(number);
    }
    start = 0;
    return 1;
}

static bool same_frame(const CabinetFrame& a, const CabinetFrame& b) {
    return a.inputs == b.inputs && a.cheats == b.cheats && a.has_dipsw == b.has_dipsw &&
        a.tracing_on == b.tracing_on && a.dump == b.dump && a.dipsw == b.dipsw;
}

static void append_run(vector<CabinetRun>& runs, const CabinetFrame& frame, uint64_t count) {
    if( count == 0 ) return;
    if( !runs.empty() && same_frame(runs.back().frame, frame) ) {
        runs.back().count += count;
    } else {
        runs.push_back({frame, count});
    }
}

static uint64_t run_count(const vector<CabinetRun>& runs) {
    uint64_t count = 0;
    for( const auto& run : runs ) count += run.count;
    return count;
}

CabinetScript::CabinetScript(const char *filename) {
    ifstream input(filename);
    if( !input ) throw runtime_error("could not open cabinet input file " + string(filename));
    parse(input, filename);
}

CabinetScript::CabinetScript(istream& input, const string& source_name) {
    parse(input, source_name);
}

void CabinetScript::parse(istream& input, const string&) {
    vector<CabinetRun> loop;
    bool looping = false;
    string line;
    int line_no = 0;
    while( getline(input, line) ) {
        line_no++;
        const auto comment = line.find('#');
        if( comment != string::npos ) line.resize(comment);
        const vector<string> tokens = words(line);
        if( tokens.empty() ) continue;
        const string keyword = lower(tokens.front());
        if( keyword == "loop" ) {
            if( tokens.size() != 1 || looping ) throw runtime_error("invalid loop at cabinet line " + to_string(line_no));
            loop.clear();
            looping = true;
            continue;
        }
        if( keyword == "repeat" ) {
            if( !looping || tokens.size() != 2 ) throw runtime_error("invalid repeat at cabinet line " + to_string(line_no));
            const uint64_t repeats = parse_number(tokens[1], "repeat count");
            if( repeats == 0 ) throw runtime_error("repeat count must be positive at cabinet line " + to_string(line_no));
            if( !loop.empty() ) segments.push_back({loop, repeats});
            frames += run_count(loop) * repeats;
            looping = false;
            loop.clear();
            continue;
        }
        size_t start = 0;
        bool absolute = false;
        const uint64_t current_frames = frames + (looping ? run_count(loop) : 0);
        const uint64_t repeats = duration(tokens, start, current_frames, line_no, absolute);
        const CabinetFrame frame = parse_frame(tokens, start, line_no);
        if( absolute && repeats > 1 ) {
            CabinetFrame idle;
            if( looping ) append_run(loop, idle, repeats - 1);
            else {
                segments.push_back({{{idle, repeats - 1}}, 1});
                frames += repeats - 1;
            }
            append_run(looping ? loop : segments.back().runs, frame, 1);
            if( !looping ) frames++;
        } else {
            if( looping ) append_run(loop, frame, repeats);
            else {
                if( repeats > 0 ) segments.push_back({{{frame, repeats}}, 1});
                frames += repeats;
            }
        }
    }
    if( looping ) throw runtime_error("cabinet script ends with an unclosed loop");
}

bool CabinetScript::done() const {
    return segment_position >= segments.size();
}

const CabinetFrame& CabinetScript::next() {
    if( done() ) throw out_of_range("cabinet script has no more frames");
    Segment& segment = segments[segment_position];
    CabinetRun& run = segment.runs[run_position];
    if( run_remaining == 0 ) run_remaining = run.count;
    const CabinetFrame& frame = run.frame;
    if( --run_remaining == 0 ) {
        run_position++;
        if( run_position == segment.runs.size() ) {
            run_position = 0;
            segment_repeat++;
            if( segment_repeat == segment.repeats ) {
                segment_repeat = 0;
                segment_position++;
            }
        }
    }
    return frame;
}

uint64_t CabinetScript::frame_count() const {
    return frames;
}
