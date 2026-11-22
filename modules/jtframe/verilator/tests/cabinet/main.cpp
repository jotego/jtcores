#include <algorithm>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <unistd.h>
#include <vector>

#include "../../cabinet.h"
#include "../../cheats.h"

using namespace std;

static void check(bool condition, const string& message) {
    if( !condition ) throw runtime_error(message);
}

static vector<CabinetFrame> frames(const string& text) {
    istringstream input(text);
    CabinetScript script(input, "test.cab");
    vector<CabinetFrame> result;
    while( !script.done() ) result.push_back(script.next());
    return result;
}

static void expect_error(const function<void()>& action, const string& text) {
    try {
        action();
    } catch( const exception& error ) {
        check(string(error.what()).find(text) != string::npos,
            "error did not contain '" + text + "': " + error.what());
        return;
    }
    throw runtime_error("expected error containing '" + text + "'");
}

static string write_fixture(const string& suffix, const string& text) {
    const string path = "/tmp/jtframe-cabinet-" + to_string(getpid()) + suffix;
    ofstream output(path);
    if( !output || !(output << text) ) throw runtime_error("cannot create fixture " + path);
    return path;
}

static void test_relative_inputs_and_dips() {
    const vector<CabinetFrame> result = frames("2 coin b1 dipsw=ff cheat=finish-level tracing_on dump\n");
    check(result.size() == 2, "relative duration should create two frames");
    for( const auto& frame : result ) {
        check(frame.inputs == 0x101, "coin and b1 input mask");
        check(frame.has_dipsw && frame.dipsw == 0xff, "unprefixed hexadecimal dipsw");
        check(frame.cheats.size() == 1 && frame.cheats[0] == "finish-level", "cheat event");
        check(frame.tracing_on && frame.dump, "trace and dump events");
    }
    const vector<CabinetFrame> prefixed = frames("dipsw=0xA5\n");
    check(prefixed.size() == 1 && prefixed[0].dipsw == 0xa5, "0x hexadecimal dipsw");
}

static void test_absolute_and_idle_timing() {
    const vector<CabinetFrame> absolute = frames("=5 coin\n");
    check(absolute.size() == 6, "absolute frame includes the startup frame");
    for( size_t k = 0; k < 5; k++ ) check(absolute[k].inputs == 0, "absolute wait must be idle");
    check(absolute[5].inputs == 1, "absolute action must occur at cabinet frame five");

    const vector<CabinetFrame> events = frames("=5 dipsw=ff cheat=finish-level tracing_on dump\n");
    for( size_t k = 0; k < 5; k++ ) {
        check(!events[k].has_dipsw && events[k].cheats.empty() && !events[k].tracing_on && !events[k].dump,
            "absolute cabinet events must not occur early");
    }
    check(events[5].has_dipsw && events[5].dipsw == 0xff, "absolute dipsw event");
    check(events[5].cheats.size() == 1 && events[5].cheats[0] == "finish-level", "absolute cheat event");
    check(events[5].tracing_on && events[5].dump, "absolute trace and dump events");

    const vector<CabinetFrame> idle = frames("3\n");
    check(idle.size() == 3, "blank duration should add idle frames");
    for( const auto& frame : idle ) check(frame.inputs == 0, "blank duration frame must be idle");
}

static void test_loops_and_compact_repeats() {
    const vector<CabinetFrame> loop = frames("loop\ncoin\n1\nrepeat 3\n");
    check(loop.size() == 6, "loop should repeat its body three times");
    for( size_t k = 0; k < loop.size(); k++ ) {
        check(loop[k].inputs == (k % 2 == 0 ? 1U : 0U), "loop body ordering");
    }

    istringstream input("loop\ncoin\nrepeat 100000000\n");
    CabinetScript compact(input, "large.cab");
    check(compact.frame_count() == 100000000ULL, "large repeat frame count");
    check(compact.next().inputs == 1, "large repeat first frame");
}

static void test_cabinet_errors() {
    expect_error([] { frames("=2 coin\n=1 b1\n"); }, "before the current frame");
    expect_error([] { frames("-1 coin\n"); }, "negative frame count");
    expect_error([] { frames("dipsw=not-hex\n"); }, "dipsw value");
    expect_error([] { frames("coin mystery\n"); }, "unknown cabinet action");
    expect_error([] { frames("loop\ncoin\n"); }, "unclosed loop");
    expect_error([] { frames("repeat 2\n"); }, "invalid repeat");
    expect_error([] { frames("coin tracing_on tracing_on\n"); }, "duplicate tracing_on");
}

static void test_run_iterator_matches_frames() {
    const string text="2\n=5 coin\nloop\nb1\n2\nrepeat 3\n";
    const auto expected=frames(text);
    istringstream input(text);
    CabinetScript compact(input,"runs.cab");
    check(compact.next().inputs==expected[0].inputs,"mixed iterator initial frame");
    size_t position=1;
    while(!compact.done()) {
        const auto run=compact.next_run();
        for(uint64_t n=0;n<run.count;n++,position++)
            check(run.frame.inputs==expected.at(position).inputs,"compact run must match frame iterator");
    }
    check(position==expected.size(),"compact run total");
    istringstream long_input("1000000000 coin\n");
    CabinetScript long_run(long_input,"long.cab");
    check(long_run.next_run().count==1000000000ULL && long_run.done(),"long hold is not expanded");
}

// Golden vectors are shared with the Go reader in jtutil/regression/cab.go
static string describe_runs(const string& path) {
    ostringstream out;
    try {
        CabinetScript script(path.c_str());
        out << "capture ";
        if( script.has_capture() ) out << script.capture_first(); else out << '-';
        out << "\nframes " << script.frame_count() << '\n';
        vector<CabinetRun> runs;
        while( !script.done() ) {
            const CabinetRun run = script.next_run();
            const CabinetFrame& a = run.frame;
            if( !runs.empty() ) {
                const CabinetFrame& b = runs.back().frame;
                if( a.inputs == b.inputs && a.cheats == b.cheats && a.has_dipsw == b.has_dipsw && a.dipsw == b.dipsw &&
                    a.tracing_on == b.tracing_on && a.dump == b.dump ) {
                    runs.back().count += run.count;
                    continue;
                }
            }
            runs.push_back(run);
        }
        for( const auto& run : runs ) {
            const CabinetFrame& f = run.frame;
            out << run.count << ' ' << hex << f.inputs << ' ';
            if( f.has_dipsw ) out << f.dipsw; else out << '-';
            out << dec << ' ' << (f.tracing_on ? 't' : '-') << (f.dump ? 'd' : '-') << ' ';
            if( f.cheats.empty() ) out << '-';
            for( size_t k = 0; k < f.cheats.size(); k++ ) out << (k ? "," : "") << f.cheats[k];
            out << '\n';
        }
    } catch( const CabinetError& error ) {
        return "error " + to_string(error.line()) + "\n";
    }
    return out.str();
}

static void test_vectors(const string& folder) {
    vector<string> cabs;
    for( const auto& entry : filesystem::directory_iterator(folder) ) {
        if( entry.path().extension() == ".cab" ) cabs.push_back(entry.path().string());
    }
    sort(cabs.begin(), cabs.end());
    check(cabs.size() > 20, "too few golden vectors in " + folder);
    for( const auto& cab : cabs ) {
        const string expect_path = cab.substr(0, cab.size() - 4) + ".expect";
        ifstream expect_file(expect_path);
        check(expect_file.good(), "missing " + expect_path);
        ostringstream expected;
        expected << expect_file.rdbuf();
        const string got = describe_runs(cab);
        check(got == expected.str(), cab + ": expected\n" + expected.str() + "got\n" + got);
    }
}

static void test_capture_api() {
    istringstream input("capture 2\n=250\n");
    CabinetScript script(input, "capture.cab");
    check(script.has_capture() && script.capture_first() == 2, "capture value");
    check(script.frame_count() == 251, "capture adds no frames");
    check(CabinetScript::CAPTURE_PERIOD == 100, "capture period");
    expect_error([] { frames("1\ncapture 1\n"); }, "at cabinet line 2");
    expect_error([] { frames("capture 3\n=2\n"); }, "at cabinet line 1");
}

static void test_cheat_database() {
    const string path = write_fixture(".yaml",
        "cabal:\n"
        "  - name: finish-level\n"
        "    mame: \"Finish Current Level Now!\"\n"
        "    sdram:\n"
        "      - { bank: 0, offset: 0x100049, byte-mask: 0x01, data: 0x01 }\n"
        "machine:\n"
        "  - name: boss\n"
        "    sdram:\n"
        "      - { bank: 1, offset: 16, byte-mask: 3, data: 0x1234 }\n");
    CheatDatabase database(path);
    remove(path.c_str());
    check(database.target_count() == 2 && database.definition_count() == 2, "cheat definition counts");
    const vector<CheatWrite>* finish = database.find("cabal", "finish-level");
    check(finish != nullptr && finish->size() == 1, "find cabal cheat");
    check((*finish)[0].offset == 0x100049 && (*finish)[0].byte_mask == 1, "cheat write fields");
    check(database.find("cabal", "missing") == nullptr, "unknown cheat lookup");
    check(database.find("missing", "finish-level") == nullptr, "unknown target lookup");
}

static void test_cheat_errors() {
    const string bad_write = write_fixture("-bad-write.yaml",
        "cabal:\n  - name: bad\n    sdram:\n      - { bank: 0, offset: 0, data: 1 }\n");
    expect_error([&] { CheatDatabase database(bad_write); }, "incomplete SDRAM cheat write");
    remove(bad_write.c_str());

    const string duplicate = write_fixture("-duplicate.yaml",
        "cabal:\n  - name: same\n    sdram:\n      - { bank: 0, offset: 0, byte-mask: 1, data: 1 }\n"
        "  - name: same\n    sdram:\n      - { bank: 0, offset: 1, byte-mask: 1, data: 1 }\n");
    expect_error([&] { CheatDatabase database(duplicate); }, "duplicate cheat name");
    remove(duplicate.c_str());
}

int main(int argc, char *argv[]) {
    try {
        test_vectors(argc > 1 ? argv[1] : "vectors");
        test_capture_api();
        test_relative_inputs_and_dips();
        test_absolute_and_idle_timing();
        test_loops_and_compact_repeats();
        test_cabinet_errors();
        test_run_iterator_matches_frames();
        test_cheat_database();
        test_cheat_errors();
        cout << "PASS\n";
        return 0;
    } catch( const exception& error ) {
        cerr << "FAIL: " << error.what() << '\n';
        return 1;
    }
}
